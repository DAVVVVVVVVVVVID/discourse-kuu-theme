// 帖子分享图的画法（2026-10-21，Issue #12）：1080×1440（3:4），奶油色底，底部统一是 Logo + 文字 + 二维码。
// 三种样式按 David 确认的参考图（D:\PROJECT\KUU\brand\share\share_mock.py），尺寸、颜色、字号都照抄，
// 只有两处不同：
// - 二维码按 Issue 要求放大到图片宽度的 1/4 以上（参考图里是 220px），底部区域相应加高、上面的封面缩短
// - 普通帖用文字封面时，封面上已经是大字标题，下面不再重复标题，直接写正文开头（和瀑布流的处理一致）
// 这里只管画：图片已经由 kuu-share-data.js 读成同源的 <img>，文字已经拆成 token
import qrcode from "./vendor/qrcode-generator.js";

export const WIDTH = 1080;
export const HEIGHT = 1440;
const M = 56; // 外边距

const NAVY = "#0a2d56";
const SAKURA = "#ed8690";
const MIST = "#c0d1e4";
const CREAM = "#fcf9f2";
const WHITE = "#ffffff";
const GREY = "#6e7580";
const LIGHT = "#e6eaf0";
const RED = "#e5484d";
const GOLD = "#f5a623";
const SILVER = "#b0b8c2";
const BRONZE = "#cd8c5a";
const GREEN = "#1e7b3c";
const GREEN_DOT = "#2e9a52";
const GREEN_BG = "#e6f4ea";

// 中文用设备自带字体：iPhone 苹方、Mac 冬青黑、Android 思源黑体、Windows 微软雅黑
const FONT_FAMILY =
  '"PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC", "Source Han Sans SC", "Microsoft YaHei", sans-serif';

// 二维码的码点区域至少 270px（图片宽度的 1/4），外面再留 2 格白边
const QR_TARGET = 300;
const QR_QUIET_MODULES = 2;
const FOOTER_TOP = HEIGHT - 400;
const CONTENT_BOTTOM = FOOTER_TOP - 40;
const COVER_HEIGHT = 560;

// 不能出现在行首的标点：遇到时让它留在上一行末尾（可以稍微超出一点宽度）
const NO_LINE_START = "，。？！：；、）」』】》〉…—,.?!:;)]}%";
const ELLIPSIS = { text: "…" };

function font(size, bold = false) {
  return `${bold ? 700 : 400} ${size}px ${FONT_FAMILY}`;
}

const segmenter =
  typeof Intl !== "undefined" && Intl.Segmenter
    ? new Intl.Segmenter("zh", { granularity: "grapheme" })
    : null;

// 按字拆开：emoji（包括肤色、组合 emoji）算一个字
function graphemes(text) {
  return segmenter
    ? Array.from(segmenter.segment(text), (s) => s.segment)
    : Array.from(text);
}

// 纯文字转成 token；kuu-share-data.js 处理带 emoji 图片的 HTML 时也用它
export function textTokens(text) {
  return graphemes((text || "").replace(/\s+/g, " ")).map((t) => ({
    text: t,
  }));
}

function tokenWidth(ctx, token, size) {
  return token.image ? size * 1.15 : ctx.measureText(token.text).width;
}

function lineWidth(ctx, line, size) {
  return line.reduce((sum, token) => sum + tokenWidth(ctx, token, size), 0);
}

function truncate(ctx, line, width, size) {
  const ellipsisWidth = tokenWidth(ctx, ELLIPSIS, size);
  while (line.length && lineWidth(ctx, line, size) + ellipsisWidth > width) {
    line.pop();
  }
  while (line.length && line.at(-1).text === " ") {
    line.pop();
  }
  line.push(ELLIPSIS);
}

// 连续的英文字母、数字算一个单词，换行时不拆开
const WORD_CHAR = /^[A-Za-z0-9'’._\-]$/;

function wordUnits(tokens) {
  const units = [];
  let word = null;
  for (const token of tokens) {
    if (token.text && WORD_CHAR.test(token.text)) {
      (word ??= []).push(token);
      continue;
    }
    if (word) {
      units.push(word);
      word = null;
    }
    units.push([token]);
  }
  if (word) {
    units.push(word);
  }
  return units;
}

// 中文按字换行、英文按单词换行（比一整行还长的单词才拆开），最多 maxLines 行，
// 放不下时最后一行末尾加「…」
function wrap(ctx, tokens, width, maxLines, size) {
  const lines = [];
  let line = [];
  let used = 0;
  let full = false;

  const newLine = () => {
    lines.push(line);
    line = [];
    used = 0;
    full = lines.length === maxLines;
  };
  const put = (token) => {
    if (!line.length && token.text === " ") {
      return;
    }
    line.push(token);
    used += tokenWidth(ctx, token, size);
  };

  for (const unit of wordUnits(tokens)) {
    if (full) {
      break;
    }
    const w = lineWidth(ctx, unit, size);

    if (unit.length > 1 && w > width) {
      for (const token of unit) {
        if (line.length && used + tokenWidth(ctx, token, size) > width) {
          newLine();
          if (full) {
            break;
          }
        }
        put(token);
      }
    } else if (
      used + w <= width ||
      !line.length ||
      NO_LINE_START.includes(unit[0].text)
    ) {
      unit.forEach(put);
    } else {
      newLine();
      if (!full) {
        unit.forEach(put);
      }
    }
  }

  if (full) {
    truncate(ctx, lines.at(-1), width, size);
  } else if (line.length) {
    lines.push(line);
  }
  return lines;
}

function drawLine(ctx, line, x, y, size) {
  let cursor = x;
  for (const token of line) {
    if (token.image) {
      ctx.drawImage(token.image, cursor + size * 0.05, y, size, size);
    } else {
      ctx.fillText(token.text, cursor, y);
    }
    cursor += tokenWidth(ctx, token, size);
  }
}

// 画一段文字，返回下一行的 y
function paragraph(
  ctx,
  tokens,
  { x, y, width, size, bold, color, maxLines, lineHeight }
) {
  ctx.font = font(size, bold);
  ctx.fillStyle = color;
  const lines = wrap(ctx, tokens, width, maxLines, size);
  for (const line of lines) {
    drawLine(ctx, line, x, y, size);
    y += lineHeight;
  }
  return y;
}

function singleLine(ctx, text, opts) {
  return paragraph(ctx, textTokens(text), {
    maxLines: 1,
    lineHeight: 0,
    ...opts,
  });
}

function roundRectPath(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

function fillRoundRect(ctx, x, y, w, h, r, color) {
  roundRectPath(ctx, x, y, w, h, r);
  ctx.fillStyle = color;
  ctx.fill();
}

// 像 CSS 的 object-fit: cover，裁成圆角
function drawCoverImage(ctx, image, x, y, w, h, r) {
  const scale = Math.max(w / image.width, h / image.height);
  const sw = w / scale;
  const sh = h / scale;
  ctx.save();
  roundRectPath(ctx, x, y, w, h, r);
  ctx.clip();
  ctx.drawImage(
    image,
    (image.width - sw) / 2,
    (image.height - sh) / 2,
    sw,
    sh,
    x,
    y,
    w,
    h
  );
  ctx.restore();
}

// 封面左上角的标签
function badge(ctx, text, x, y, color) {
  ctx.font = font(30, true);
  const w = ctx.measureText(text).width + 40;
  fillRoundRect(ctx, x, y, w, 56, 12, color);
  // 白边：放在同色的文字封面上也看得清
  ctx.lineWidth = 3;
  ctx.strokeStyle = "rgba(255, 255, 255, 0.85)";
  ctx.stroke();
  ctx.fillStyle = WHITE;
  ctx.textBaseline = "middle";
  ctx.fillText(text, x + 20, y + 29);
  ctx.textBaseline = "top";
}

// 状态小胶囊，左边一个圆点
function pill(ctx, text, x, y, { bg, fg, dot }) {
  ctx.font = font(32, true);
  const h = 54;
  const w = ctx.measureText(text).width + 52 + 26;
  fillRoundRect(ctx, x, y, w, h, h / 2, bg);
  ctx.beginPath();
  ctx.arc(x + 26, y + h / 2, 7, 0, Math.PI * 2);
  ctx.fillStyle = dot;
  ctx.fill();
  ctx.fillStyle = fg;
  ctx.textBaseline = "middle";
  ctx.fillText(text, x + 52, y + h / 2 + 1);
  ctx.textBaseline = "top";
}

// 没有图片时的文字封面：模板图（或品牌色）+ 居中的大号标题，和瀑布流的文字封面一样
function drawTextCover(ctx, cover, titleTokens, x, y, w, h) {
  if (cover.image) {
    drawCoverImage(ctx, cover.image, x, y, w, h, 28);
  } else {
    fillRoundRect(ctx, x, y, w, h, 28, cover.background);
  }
  const size = 64;
  const lineHeight = 90;
  ctx.font = font(size, true);
  const lines = wrap(ctx, titleTokens, w - 160, 4, size);
  let ty = y + (h - lines.length * lineHeight) / 2 + (lineHeight - size) / 2;
  ctx.fillStyle = cover.color;
  for (const line of lines) {
    drawLine(ctx, line, x + (w - lineWidth(ctx, line, size)) / 2, ty, size);
    ty += lineHeight;
  }
}

function drawCover(ctx, data, label, labelColor) {
  const box = [M, M, WIDTH - 2 * M, COVER_HEIGHT];
  if (data.cover) {
    drawCoverImage(ctx, data.cover, ...box, 28);
  } else {
    drawTextCover(ctx, data.textCover, data.titleTokens, ...box);
  }
  if (label) {
    badge(ctx, label, M + 24, M + 24, labelColor);
  }
}

function drawQr(ctx, url, right, top) {
  const qr = qrcode(0, "M");
  qr.addData(url);
  qr.make();
  const n = qr.getModuleCount();
  const cell = Math.max(1, Math.floor(QR_TARGET / n));
  const card = cell * (n + 2 * QR_QUIET_MODULES);
  const x = right - card;

  fillRoundRect(ctx, x, top, card, card, 20, WHITE);
  ctx.fillStyle = NAVY;
  const origin = QR_QUIET_MODULES * cell;
  for (let row = 0; row < n; row++) {
    for (let col = 0; col < n; col++) {
      if (qr.isDark(row, col)) {
        ctx.fillRect(
          x + origin + col * cell,
          top + origin + row * cell,
          cell,
          cell
        );
      }
    }
  }
  return x;
}

function drawFooter(ctx, data) {
  ctx.fillStyle = LIGHT;
  ctx.fillRect(M, FOOTER_TOP, WIDTH - 2 * M, 3);

  const qrLeft = drawQr(ctx, data.url, WIDTH - M, FOOTER_TOP + 32);
  const textRight = qrLeft - 24;

  if (data.logo) {
    drawCoverImage(ctx, data.logo, M, FOOTER_TOP + 56, 110, 110, 24);
  }
  const textX = data.logo ? M + 136 : M;
  singleLine(ctx, data.brand, {
    x: textX,
    y: FOOTER_TOP + 62,
    width: textRight - textX,
    size: 40,
    bold: true,
    color: NAVY,
  });
  singleLine(ctx, data.hint, {
    x: textX,
    y: FOOTER_TOP + 122,
    width: textRight - textX,
    size: 30,
    color: GREY,
  });
  singleLine(ctx, `来自 @${data.author}`, {
    x: M,
    y: FOOTER_TOP + 236,
    width: textRight - M,
    size: 30,
    color: GREY,
  });
}

function drawNormal(ctx, data) {
  drawCover(ctx, data, data.label, NAVY);
  const width = WIDTH - 2 * M;
  let y = M + COVER_HEIGHT + 44;

  if (data.cover) {
    y = paragraph(ctx, data.titleTokens, {
      x: M,
      y,
      width,
      size: 54,
      bold: true,
      color: NAVY,
      maxLines: 2,
      lineHeight: 74,
    });
    y += 12;
  }
  paragraph(ctx, data.excerptTokens, {
    x: M,
    y,
    width,
    size: 34,
    color: GREY,
    maxLines: Math.floor((CONTENT_BOTTOM - y) / 52),
    lineHeight: 52,
  });
}

function drawMarket(ctx, data) {
  drawCover(ctx, data, data.label, SAKURA);
  const width = WIDTH - 2 * M;
  let y = M + COVER_HEIGHT + 44;

  paragraph(ctx, data.nameTokens, {
    x: M,
    y,
    width,
    size: 56,
    bold: true,
    color: NAVY,
    maxLines: 1,
    lineHeight: 0,
  });
  y += 96;

  // 预算区间之类的长价格缩小字号，给右边的状态留位置
  const priceMax = width - 220;
  ctx.font = font(84, true);
  const fullWidth = ctx.measureText(data.price).width;
  const priceSize = Math.max(
    48,
    Math.floor(84 * Math.min(1, priceMax / fullWidth))
  );
  ctx.font = font(priceSize, true);
  ctx.fillStyle = RED;
  ctx.fillText(data.price, M, y + (84 - priceSize) / 2);
  const priceWidth = Math.min(ctx.measureText(data.price).width, priceMax);
  pill(
    ctx,
    data.status.label,
    M + priceWidth + 32,
    y + 18,
    data.status.active
      ? { bg: GREEN_BG, fg: GREEN, dot: GREEN_DOT }
      : { bg: LIGHT, fg: GREY, dot: GREY }
  );
  y += 124;

  if (data.location) {
    singleLine(ctx, data.location, {
      x: M,
      y,
      width,
      size: 32,
      color: GREY,
    });
  }
}

function drawRatings(ctx, data) {
  fillRoundRect(ctx, M, M, WIDTH - 2 * M, 300, 28, NAVY);
  badge(ctx, data.label, M + 36, M + 36, SAKURA);
  paragraph(ctx, data.titleTokens, {
    x: M + 36,
    y: M + 124,
    width: WIDTH - 2 * M - 72,
    size: 72,
    bold: true,
    color: CREAM,
    maxLines: 1,
    lineHeight: 0,
  });
  singleLine(ctx, data.subtitle, {
    x: M + 36,
    y: M + 226,
    width: WIDTH - 2 * M - 72,
    size: 32,
    color: MIST,
  });

  let y = M + 300 + 50;
  if (!data.items.length) {
    singleLine(ctx, "还没有人打分，快来做第一个评分的人", {
      x: M,
      y,
      width: WIDTH - 2 * M,
      size: 36,
      color: GREY,
    });
    return;
  }

  singleLine(ctx, `大家的评分 TOP ${data.items.length}`, {
    x: M,
    y,
    width: WIDTH - 2 * M,
    size: 40,
    bold: true,
    color: NAVY,
  });
  y += 76;

  const gap = 28;
  const col = (WIDTH - 2 * M - 2 * gap) / 3;
  data.items.forEach((item, i) => {
    const x = M + i * (col + gap);
    if (item.image) {
      drawCoverImage(ctx, item.image, x, y, col, col, 20);
    } else {
      fillRoundRect(ctx, x, y, col, col, 20, MIST);
    }

    ctx.beginPath();
    ctx.arc(x + 41, y + 41, 27, 0, Math.PI * 2);
    ctx.fillStyle = [GOLD, SILVER, BRONZE][i];
    ctx.fill();
    ctx.font = font(32, true);
    ctx.fillStyle = WHITE;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(String(i + 1), x + 41, y + 43);
    ctx.textAlign = "left";
    ctx.textBaseline = "top";

    const ny = y + col + 22;
    singleLine(ctx, item.name, {
      x,
      y: ny,
      width: col,
      size: 32,
      bold: true,
      color: NAVY,
    });
    ctx.font = font(40, true);
    ctx.fillStyle = GOLD;
    ctx.fillText("★", x, ny + 54);
    ctx.font = font(42, true);
    ctx.fillStyle = NAVY;
    ctx.fillText(item.score, x + 46, ny + 52);
    const scoreWidth = ctx.measureText(item.score).width;
    ctx.font = font(26);
    ctx.fillStyle = GREY;
    ctx.fillText(`${item.count}人`, x + 46 + scoreWidth + 12, ny + 66);
  });
}

const DRAWERS = {
  normal: drawNormal,
  market: drawMarket,
  ratings: drawRatings,
};

// data 的结构见 kuu-share-data.js 的 buildShareData。返回画好的 <canvas>
export function renderShareImage(data) {
  const canvas = document.createElement("canvas");
  canvas.width = WIDTH;
  canvas.height = HEIGHT;
  const ctx = canvas.getContext("2d");
  ctx.textBaseline = "top";
  ctx.fillStyle = CREAM;
  ctx.fillRect(0, 0, WIDTH, HEIGHT);

  DRAWERS[data.type](ctx, data);
  drawFooter(ctx, data);
  return canvas;
}
