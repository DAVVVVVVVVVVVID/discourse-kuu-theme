// 手机端瀑布流（Issue #9）的共用逻辑：哪些列表用瀑布流、每张卡片的封面、分列用的高度估算。
// 瀑布流组件（mobile-waterfall.gjs）和隐藏 core 表格的 transformer 都用 waterfallActive，两边结论一致
import { getURLWithCDN } from "discourse/lib/get-url";

// 太高的图裁成 3:4，太宽的图裁成 4:3（小红书也是这个范围）；文字封面固定 3:4
const MAX_RATIO = 4 / 3;
const MIN_RATIO = 3 / 4;
const TEXT_COVER_RATIO = 4 / 3;

// 和 about.json 里的 topic_thumbnail_sizes 一致：列表里多一份宽 600 的缩略图
const THUMBNAIL_MAX_WIDTH = 600;

// 没上传模板图时的占位配色（品牌色），按帖子 ID 轮换
const PLACEHOLDER_PALETTES = [
  { background: "#0a2d56", color: "#fcf9f2" },
  { background: "#c0d1e4", color: "#0a2d56" },
  { background: "#ed8690", color: "#fcf9f2" },
  { background: "#fcf9f2", color: "#0a2d56" },
];

function settingIds(value) {
  return (value || "")
    .split("|")
    .map((id) => parseInt(id, 10))
    .filter(Boolean);
}

// 「二手市场」「评分中心」（和它们的子分类）里保留插件画的卡片，不用瀑布流
export function waterfallActive(category) {
  if (!category) {
    return true;
  }
  const excluded = settingIds(settings.waterfall_excluded_category_ids);
  return (
    !excluded.includes(category.id) &&
    !excluded.includes(category.parent_category_id)
  );
}

export function hiddenTabCategoryIds() {
  return settingIds(settings.category_tabs_hidden_ids);
}

function clampRatio(ratio) {
  return Math.min(MAX_RATIO, Math.max(MIN_RATIO, ratio));
}

function topicImage(topic) {
  const thumbnails = topic.thumbnails;
  if (!thumbnails?.length) {
    // 原图太大时 core 不给 thumbnails，拿不到宽高，按最高的比例放
    return topic.image_url ? { url: topic.image_url, ratio: MAX_RATIO } : null;
  }
  // 第一项是原图
  const [original] = thumbnails;
  const small = thumbnails.find((t) => t.max_width === THUMBNAIL_MAX_WIDTH);
  return {
    url: small?.url || topic.image_url || original.url,
    ratio:
      original.width && original.height
        ? clampRatio(original.height / original.width)
        : MAX_RATIO,
  };
}

// 以后有多种模板时在这里按分类或帖子 ID 选
export function textCoverFor(topic) {
  if (settings.text_cover_image) {
    return {
      image: getURLWithCDN(settings.text_cover_image),
      color: settings.text_cover_text_color,
    };
  }
  return PLACEHOLDER_PALETTES[topic.id % PLACEHOLDER_PALETTES.length];
}

// 返回 { url, ratio }；没有可用的图时返回 { textCover, ratio }
export function coverFor(topic, siteSettings) {
  let image;

  if (topic.kuu_rating_board_card) {
    // 评分主题：第一个评分对象的图，没有时用评分插件的占位图
    const url =
      topic.kuu_rating_board_card.items?.[0]?.image_url ||
      siteSettings.kuu_ratings_placeholder_image;
    image = url ? { url: getURLWithCDN(url), ratio: 1 } : null;
  } else if (topic.kuu_market_card) {
    // 二手帖：有商品照片才用（列表里的话题图片就是第一张照片），否则文字封面
    image = topic.kuu_market_card.has_photos ? topicImage(topic) : null;
  } else {
    image = topicImage(topic);
  }

  return image || { textCover: textCoverFor(topic), ratio: TEXT_COVER_RATIO };
}

// 分列用的卡片高度估算（px）。只看已有的数据，不量 DOM：同样的帖子永远算出同样的高度，
// 加载更多时前面的卡片不会换列
export function estimateCardHeight(topic, cover, cardWidth) {
  const textWidth = cardWidth - 16;
  // 中文一个字约 15px 宽；标题、摘要都最多两行。文字封面下面是摘要（可能没有），其他是标题
  const text = cover.textCover
    ? topic.excerpt || ""
    : topic.kuu_market_card?.item_name || topic.title || "";
  const lines = Math.min(2, Math.ceil((text.length * 15) / textWidth));
  const marketRow = topic.kuu_market_card ? 24 : 0;
  return cardWidth * cover.ratio + 16 + lines * 21 + marketRow + 30;
}
