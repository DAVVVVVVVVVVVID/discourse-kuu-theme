// 帖子分享图（Issue #12）要画的内容：从帖子页已有的数据和插件接口里取，图片读成同源的 <img>。
// - canvas 只能导出没被「污染」的图：所有图片都先 fetch 成 blob 再画，读不到（外链、跨域的 CDN 不给读）
//   就当没有图，普通帖退回文字封面
// - 二手：discourse-kuu-market 放在帖子上的 kuu_market_listing（价格的写法和插件列表卡片的 card_price 一致）
// - 评分主题：discourse-kuu-ratings 的 /kuu-ratings/boards/:id/items?sort=score（已经按平均分从高到低）
import { ajax } from "discourse/lib/ajax";
import { avatarUrl } from "discourse/lib/avatar-utils";
import { emojiUnescape } from "discourse/lib/text";
import { i18n } from "discourse-i18n";
import { buddyStatusKey, buddyStatusLabel } from "./kuu-buddy.js";
import { textTokens } from "./kuu-share-image.js";
import { textCoverFor } from "./kuu-waterfall.js";

const EXCERPT_MAX_TOKENS = 300;
const FALLBACK_TEXT_COVER = { background: "#0a2d56", color: "#fcf9f2" };

// 正文里不算进「正文开头」的部分：引用、图片、链接预览、折叠内容、代码块
const SKIPPED = [
  "aside",
  "blockquote",
  ".lightbox-wrapper",
  ".onebox",
  ".spoiler",
  ".spoiled",
  "details",
  "pre",
  "script",
  "style",
].join(",");
const BLOCK_TAGS = new Set(
  "P DIV LI UL OL H1 H2 H3 H4 H5 H6 BR TR TABLE".split(" ")
);

// 私信、不公开分类（比如管理人员）里的帖子不能生成
export function canShareImage(topic) {
  return !!topic && !topic.isPrivateMessage && !topic.category?.read_restricted;
}

function blobToImage(blob) {
  return new Promise((resolve) => {
    const url = URL.createObjectURL(blob);
    const image = new Image();
    image.onload = () => {
      URL.revokeObjectURL(url);
      resolve(image);
    };
    image.onerror = () => {
      URL.revokeObjectURL(url);
      resolve(null);
    };
    image.src = url;
  });
}

// CDN 上的图片读不到时，再试一次本站同一路径（Discourse 的上传文件在本站也能访问）
async function loadImage(url) {
  if (!url) {
    return null;
  }
  const absolute = new URL(url, window.location.href);
  const candidates = [absolute.href];
  if (absolute.origin !== window.location.origin) {
    candidates.push(window.location.origin + absolute.pathname);
  }

  for (const candidate of candidates) {
    try {
      const response = await fetch(candidate, { credentials: "same-origin" });
      const blob = response.ok && (await response.blob());
      if (blob?.type.startsWith("image/")) {
        const image = await blobToImage(blob);
        if (image) {
          return image;
        }
      }
    } catch {
      // 跨域不给读、网络错误：试下一个，都不行就当没有图
    }
  }
  return null;
}

function collapseSpaces(tokens) {
  const result = [];
  for (const token of tokens) {
    if (token.text === " " && (!result.length || result.at(-1).text === " ")) {
      continue;
    }
    result.push(token);
  }
  while (result.at(-1)?.text === " ") {
    result.pop();
  }
  return result;
}

// HTML（标题或第一楼的 cooked）拆成文字和 emoji 图片的 token。DOMParser 解析出来的文档不会执行脚本
async function htmlTokens(html, maxTokens = Infinity) {
  const doc = new DOMParser().parseFromString(html || "", "text/html");
  doc.body.querySelectorAll(SKIPPED).forEach((el) => el.remove());

  const tokens = [];
  const walk = (node) => {
    for (const child of node.childNodes) {
      if (tokens.length >= maxTokens) {
        return;
      }
      if (child.nodeType === Node.TEXT_NODE) {
        tokens.push(...textTokens(child.textContent));
      } else if (child.nodeType === Node.ELEMENT_NODE) {
        if (child.tagName === "IMG") {
          if (child.classList.contains("emoji")) {
            tokens.push({ imageUrl: child.getAttribute("src") });
          }
          continue;
        }
        walk(child);
        if (BLOCK_TAGS.has(child.tagName)) {
          tokens.push({ text: " " });
        }
      }
    }
  };
  walk(doc.body);

  const limited = tokens.slice(0, maxTokens);
  const urls = [...new Set(limited.map((t) => t.imageUrl).filter(Boolean))];
  const images = new Map(
    await Promise.all(urls.map(async (url) => [url, await loadImage(url)]))
  );

  return collapseSpaces(
    limited.flatMap((token) => {
      if (!token.imageUrl) {
        return [token];
      }
      const image = images.get(token.imageUrl);
      return image ? [{ image }] : [];
    })
  );
}

// 标题里的 emoji 是 :wave: 这种写法，先换成 emoji 图片
function topicTitleTokens(topic) {
  return htmlTokens(emojiUnescape(topic.fancy_title || topic.title));
}

async function firstPostCooked(topic) {
  const loaded = topic.postStream?.posts?.find((p) => p.post_number === 1);
  if (loaded?.cooked) {
    return loaded.cooked;
  }
  const post = await ajax(`/posts/by_number/${topic.id}/1.json`);
  return post.cooked;
}

async function loadTextCover(topic) {
  const cover = textCoverFor(topic);
  if (!cover.image) {
    return cover;
  }
  const image = await loadImage(cover.image);
  return image
    ? { image, color: cover.color }
    : { ...FALLBACK_TEXT_COVER, color: cover.color };
}

// 评分主题（不包括评分分类的说明帖）
function isBoard(topic, siteSettings) {
  const boardCategoryId = parseInt(siteSettings.kuu_ratings_board_category, 10);
  return (
    !!boardCategoryId &&
    topic.category_id === boardCategoryId &&
    topic.category?.topic_id !== topic.id
  );
}

function yen(amount) {
  return `¥${Number(amount).toLocaleString("en-US")}`;
}

function marketPrice(listing) {
  if (listing.kind === "buy") {
    const { budget_min: min, budget_max: max } = listing;
    if (min && max) {
      return min === max
        ? yen(min)
        : `¥${Number(min).toLocaleString("en-US")}–${Number(max).toLocaleString("en-US")}`;
    }
    return max ? `${yen(max)} 以内` : `${yen(min)} 以上`;
  }
  return listing.free ? "赠送" : yen(listing.price);
}

function marketKindLabel(listing) {
  if (listing.kind === "buy") {
    return "求购";
  }
  return listing.free ? "赠送" : "出售";
}

async function normalData(topic) {
  const [cover, titleTokens, excerptTokens] = await Promise.all([
    loadImage(topic.image_url),
    topicTitleTokens(topic),
    firstPostCooked(topic).then((cooked) =>
      htmlTokens(cooked, EXCERPT_MAX_TOKENS)
    ),
  ]);
  return {
    type: "normal",
    label: topic.category?.name,
    cover,
    textCover: cover ? null : await loadTextCover(topic),
    titleTokens,
    excerptTokens,
  };
}

// 和二手插件的列表卡片一样：求购用求购图；出售有照片用第一张（话题图片），没有用占位图
function marketCoverUrl(topic, listing, siteSettings) {
  if (listing.kind === "buy") {
    return siteSettings.kuu_market_buy_image;
  }
  return listing.upload_ids?.length && topic.image_url
    ? topic.image_url
    : siteSettings.kuu_market_placeholder_image;
}

async function marketData(topic, listing, siteSettings) {
  const cover = await loadImage(marketCoverUrl(topic, listing, siteSettings));
  const nameTokens = textTokens(listing.item_name);
  const tradeMethod = listing.trade_method
    ? i18n(`kuu_market.trade_methods.${listing.trade_method}`)
    : null;

  return {
    type: "market",
    label: `二手 · ${marketKindLabel(listing)}`,
    cover,
    textCover: cover ? null : await loadTextCover(topic),
    titleTokens: nameTokens,
    nameTokens,
    price: marketPrice(listing),
    status: {
      key: listing.status,
      label: i18n(`kuu_market.card_statuses.${listing.status}`),
    },
    location: [listing.location && `交易地点：${listing.location}`, tradeMethod]
      .filter(Boolean)
      .join("　　"),
  };
}

async function ratingsData(topic, siteSettings) {
  const { items } = await ajax(`/kuu-ratings/boards/${topic.id}/items.json`, {
    data: { sort: "score" },
  });
  const ratings = items.reduce((sum, item) => sum + item.score_count, 0);
  const top = items.filter((item) => item.score_count > 0).slice(0, 3);
  const placeholder = siteSettings.kuu_ratings_placeholder_image;

  return {
    type: "ratings",
    label: topic.category?.name,
    titleTokens: await topicTitleTokens(topic),
    subtitle: `${items.length} 个评分对象 · ${ratings} 次打分`,
    items: await Promise.all(
      top.map(async (item) => ({
        name: item.title,
        score: item.score_avg.toFixed(1),
        count: item.score_count,
        image: await loadImage(item.image_url || placeholder),
      }))
    ),
  };
}

function shareUrl(topic) {
  const base = (
    settings.share_image_site_url || window.location.origin
  ).replace(/\/+$/, "");
  // 短网址（/t/ID）字少，二维码的格子大，好扫
  return `${base}/t/${topic.id}`;
}

// 返回 kuu-share-image.js 的 renderShareImage 要的数据
// 搭子帖（Issue #37）：discourse-kuu-buddy 放在帖子上的 kuu_buddy_activity（organizer、members、capacity、
// schedule、requirements、status、start_reason…）。成员头像最多读 BUDDY_MAX_AVATARS 张，发起人在最前
const BUDDY_MAX_AVATARS = 8;

async function buddyData(topic, activity) {
  const key = buddyStatusKey(activity.status, activity.start_reason);
  const ended = ["ended", "expired"].includes(activity.status);
  const people = [activity.organizer, ...(activity.members || [])].filter(
    Boolean
  );
  const avatars = await Promise.all(
    people
      .slice(0, BUDDY_MAX_AVATARS)
      .map((user) => loadImage(avatarUrl(user.avatar_template, "large")))
  );
  const organizer = activity.organizer || {};

  return {
    type: "buddy",
    statusKey: ended ? "ended" : key,
    // 已结束、过期一律写「已结束」
    statusLabel: buddyStatusLabel(ended ? "ended" : key),
    titleTokens: await topicTitleTokens(topic),
    organizerName: organizer.name || organizer.username || "",
    organizerAvatar: avatars[0],
    categoryName: topic.category?.name || "",
    schedule: activity.schedule,
    capacity: activity.capacity,
    requirements: activity.requirements,
    memberCount: activity.member_count,
    spotsLeft: activity.spots_left,
    avatars,
    hint:
      activity.status === "recruiting"
        ? settings.share_image_buddy_hint_recruiting
        : settings.share_image_buddy_hint_other,
  };
}

export async function buildShareData(topic, siteSettings) {
  const listing = topic.kuu_market_listing;
  const buddy = topic.kuu_buddy_activity;
  const [content, logo] = await Promise.all([
    buddy
      ? buddyData(topic, buddy)
      : listing
        ? marketData(topic, listing, siteSettings)
        : isBoard(topic, siteSettings)
          ? ratingsData(topic, siteSettings)
          : normalData(topic),
    loadImage(
      siteSettings.site_large_icon_url || siteSettings.site_logo_small_url
    ),
  ]);

  return {
    url: shareUrl(topic),
    author:
      topic.details?.created_by?.username || topic.creator?.username || "",
    brand: settings.share_image_brand,
    hint: settings.share_image_hint,
    logo,
    // 搭子帖的底部提示按状态换，所以内容放在后面覆盖
    ...content,
  };
}
