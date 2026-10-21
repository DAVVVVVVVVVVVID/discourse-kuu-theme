// 话题最底部的「分享」换成分享菜单（2026-10-21，Issue #14）：「复制链接」「保存分享图」，所有话题都换。
// 大家找分享都找这里，原来打开的是 core 的分享窗口（带「邀请」，注册只开放京大邮箱，用不上，一起去掉）。
// - core 没有删底部按钮的 API，同一个 id 也不能重新注册，所以 core 的 share-and-invite 按钮由 CSS 藏起来，
//   这里用同样的优先级、文字注册一个新按钮。同优先级时后注册的排在前面，正好占原来的位置
// - 新按钮也带 share-and-invite 类名：core 的快捷键 Shift+S 点的是 #topic-footer-buttons button.share-and-invite
// - 底部按钮只能是按钮 + 动作，所以点击后用 menu 服务在按钮旁边弹出菜单（手机上从底部弹出）
// - 未登录时不显示，和 core 的规则一样（未登录只显示 anonymousOnly 的按钮）
// - 帖子菜单里每一楼的分享按钮不变（post-share-menu.gjs）
import { apiInitializer } from "discourse/lib/api";
import KuuShareMenuContent from "../components/kuu-share-menu-content.gjs";

// 和 core instance-initializers/topic-footer-buttons.js 的 SHARE_PRIORITY 一致
const SHARE_PRIORITY = 1000;
const BUTTON_ID = "kuu-share";

export default apiInitializer((api) => {
  const menu = api.container.lookup("service:menu");

  api.registerTopicFooterButton({
    id: BUTTON_ID,
    icon: () => settings.post_share_icon,
    priority: SHARE_PRIORITY,
    // 和 core 一样：电脑上的私信只有图标
    label() {
      if (!this.get("topic.isPrivateMessage") || this.site.mobileView) {
        return "footer_nav.share";
      }
    },
    title: "topic.share.help",
    classNames: ["share-and-invite", "kuu-topic-share"],
    dependentKeys: ["topic.isPrivateMessage"],
    action() {
      const trigger = document.getElementById(
        `topic-footer-button-${BUTTON_ID}`
      );
      menu.show(trigger, {
        identifier: "kuu-topic-share",
        component: KuuShareMenuContent,
        data: { topic: this.topic, url: this.topic.url },
        modalForMobile: true,
      });
    },
  });
});
