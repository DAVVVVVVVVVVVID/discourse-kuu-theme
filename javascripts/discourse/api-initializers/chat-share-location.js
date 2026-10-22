// 聊天里分享位置（2026-10-22，Issue #24 第 2 条）
// 聊天输入框的「+」菜单里加「位置」（和上传图片、GIF 放在一起），私聊和公共频道都能用。
// 点开 kuu-share-location-modal.gjs：当前位置或搜索地点 → 预览 → 确认后才发送。
// 发出去的是一行「📍 地点名」+ Google 地图链接，用 chat 插件的 sendChatMessage 发（和 GIF 一样），
// 在话题串（thread）里点就发到话题串里
import { apiInitializer } from "discourse/lib/api";
import KuuShareLocationModal from "../components/kuu-share-location-modal.gjs";

export default apiInitializer((api) => {
  const modal = api.container.lookup("service:modal");
  if (!api.registerChatComposerButton) {
    return; // 没装 chat 插件
  }

  api.registerChatComposerButton({
    id: "kuu-share-location",
    icon: settings.chat_location_icon,
    // 「+」菜单只认翻译 key（label），文字在 locales/*.yml
    label: themePrefix("chat_share_location"),
    position: "dropdown",
    action(context) {
      const channel = this.draft?.channel || this.args?.channel;
      const isThread = context === "thread";
      modal.show(KuuShareLocationModal, {
        model: {
          isDirectMessage: !!channel?.isDirectMessageChannel,
          send: (message) =>
            api.sendChatMessage(channel.id, {
              message,
              threadId: isThread ? this.draft?.thread?.id : null,
            }),
        },
      });
    },
  });
});
