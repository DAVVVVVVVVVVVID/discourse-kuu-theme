// 点进帖子一律从第一楼开始，不跳到上次浏览的位置（2026-10-21，Issue #18）
// core 列表里的帖子链接都用 topic.lastUnreadUrl（/t/slug/id/上次读到的下一楼），core 没有站点设置可以关。
// 用 core 的 registerCustomLastUnreadUrlCallback 让它返回不带楼号的话题链接，core 打开时从第一楼开始。
// 一处改动覆盖所有用 lastUnreadUrl 的地方：
// - 首页 / 分类列表（电脑表格、FKB Pro 卡片的标题和数字、点卡片空白处）、手机瀑布流卡片
// - 二手插件的商品卡片、评分主题的标题（插件也用 lastUnreadUrl）
// - 个人主页的话题列表、标题旁「N 条未读 / 新回复」的徽标、分类页的话题方框、键盘 j / k 切换话题
// 不受影响：通知、私信、搜索结果、书签这些指向某一楼的链接（它们用的是那一楼自己的链接）；
// 「最后活动时间」这类 lastPostUrl 链接照旧跳到最后一楼；阅读进度、未读数照常记录
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.registerCustomLastUnreadUrlCallback((topic) => topic.url);
});
