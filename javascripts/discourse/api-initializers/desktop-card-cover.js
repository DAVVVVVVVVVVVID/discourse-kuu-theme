// 电脑上帖子卡片（FKB Pro 卡片）的封面图完整显示（2026-10-22，Issue #31）
// FKB Pro 把封面放在固定高度的框里、左右贴到卡片边缘、按它的设置裁剪。改成：
// - 放回卡片内容区（和标题、摘要左右对齐），圆角；高度按原图比例，完整显示不裁剪
// - 比 3:4 还瘦长的图，高度到宽度的 4/3 为止，截取中间一段
// - 加载前先按比例占好位置，页面不跳
// 每张卡片的比例用 core 的 topic-list-item-style transformer 写成 CSS 变量 --kuu-cover-ratio
// （原图宽高来自列表数据里的 thumbnails，about.json 的 topic_thumbnail_sizes 让列表带上它），样式在 common.scss。
// 图片地址：FKB Pro 用的是 topic.image_url，缩略图还没生成时它就是原图。用 topic-list-topics-from 换成
// 已经生成好的缩略图里最宽的一张（1024 档或 600 档），都没有就保持原样。
// 只在电脑上；手机瀑布流、二手 / 评分卡片、帖子页不受影响（二手、评分卡片的封面不是 FKB Pro 画的）
import { trustHTML } from "@ember/template";
import { apiInitializer } from "discourse/lib/api";

// 高度最多是宽度的 4/3
const MIN_WIDTH_OVER_HEIGHT = 3 / 4;

function originalSize(topic) {
  const original = topic.thumbnails?.[0];
  return original?.width && original?.height ? original : null;
}

// 生成好的缩略图里挑实际宽度最大的：1024 那档是长边上限，瘦长图的 1024 档反而比 600 档（宽度上限）窄
function thumbnailUrl(topic) {
  // 第一项是原图，后面是生成好的缩略图
  const generated = (topic.thumbnails || [])
    .slice(1)
    .filter((t) => t.url && t.width);
  generated.sort((a, b) => b.width - a.width);
  return generated[0]?.url;
}

export default apiInitializer((api) => {
  const site = api.container.lookup("service:site");
  if (!site.desktopView) {
    return;
  }

  api.registerValueTransformer(
    "topic-list-topics-from",
    ({ value: topics }) => {
      topics.forEach((topic) => {
        const url = thumbnailUrl(topic);
        if (url) {
          topic.image_url = url;
        }
      });
      return topics;
    }
  );

  api.registerValueTransformer(
    "topic-list-item-style",
    ({ value, context: { topic } }) => {
      const size = topic?.image_url && originalSize(topic);
      if (!size) {
        return value;
      }
      const ratio = Math.max(size.width / size.height, MIN_WIDTH_OVER_HEIGHT);
      return [...value, trustHTML(`--kuu-cover-ratio: ${ratio.toFixed(4)};`)];
    }
  );
});
