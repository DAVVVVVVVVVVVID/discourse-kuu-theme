// 有未读私聊时的顶部提醒（2026-10-22，Issue #24 第 3 条）
// 「你有 N 条未读私信   [去看看] [忽略全部] ×」，横条不是弹窗，挂在 core application 模板的 above-main-container
// （页头下面、页面内容上面，跟着页面滚走，不挡底栏和聊天输入框）。
// - 只算私聊（直接对话频道），不算公共频道；静音的私聊不算。数据来自 chat 插件的 chatChannelsManager，
//   新私信进来时会跟着变
// - 「去看看」：只有一个对话有未读时直接打开它，否则打开私聊列表
// - 「×」：这次关掉（记在内存里），刷新论坛后还有未读就再显示
// - 「忽略全部」：把有未读的私聊都标为已读（chat 插件的 markChannelAsRead，和在聊天里读过一样）
// - 在聊天页面、聊天抽屉展开时不显示；没登录、不能用聊天时不显示
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { apiInitializer } from "discourse/lib/api";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";

// 「×」只关这一次：刷新页面后重新计算
let dismissed = false;

class KuuChatUnreadBanner extends Component {
  @service currentUser;
  @service router;
  @service() chat;
  @service("chat-channels-manager") chatChannelsManager;
  @service("chat-state-manager") chatStateManager;
  @service("chat-api") chatApi;

  @tracked dismissed = dismissed;
  @tracked ignoring = false;

  get unreadChannels() {
    return (this.chatChannelsManager?.directMessageChannels || []).filter(
      (channel) =>
        !channel.currentUserMembership?.muted && this.unreadOf(channel) > 0
    );
  }

  get count() {
    return this.unreadChannels.reduce(
      (sum, channel) => sum + this.unreadOf(channel),
      0
    );
  }

  get show() {
    if (!this.currentUser || !this.chat?.userCanChat || this.dismissed) {
      return false;
    }
    if (this.router.currentRouteName?.startsWith("chat")) {
      return false;
    }
    if (this.chatStateManager?.isDrawerExpanded) {
      return false;
    }
    return this.count > 0;
  }

  unreadOf(channel) {
    const tracking = channel.tracking;
    return Math.max(tracking?.unreadCount || 0, tracking?.mentionCount || 0);
  }

  @action
  open() {
    const channels = this.unreadChannels;
    if (channels.length === 1) {
      this.router.transitionTo("chat.channel", ...channels[0].routeModels);
    } else {
      this.router.transitionTo("chat.direct-messages");
    }
  }

  @action
  close() {
    dismissed = true;
    this.dismissed = true;
  }

  @action
  async ignoreAll() {
    this.ignoring = true;
    try {
      const channels = this.unreadChannels.filter((c) => c.lastMessage?.id);
      await Promise.all(
        channels.map((channel) =>
          this.chatApi.markChannelAsRead(channel.id, channel.lastMessage.id)
        )
      );
      // 服务器也会通过 message bus 推送，先在本地清零，横条马上消失
      channels.forEach((channel) => {
        channel.tracking.unreadCount = 0;
        channel.tracking.mentionCount = 0;
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.ignoring = false;
    }
  }

  <template>
    {{#if this.show}}
      <div class="kuu-chat-unread-banner" role="status">
        <span class="kuu-chat-unread-banner__text">
          {{dIcon "envelope"}}
          你有
          {{this.count}}
          条未读私信
        </span>
        <span class="kuu-chat-unread-banner__actions">
          <DButton
            class="btn-primary btn-small kuu-chat-unread-banner__open"
            @action={{this.open}}
            @translatedLabel="去看看"
          />
          <DButton
            class="btn-flat btn-small kuu-chat-unread-banner__ignore"
            @action={{this.ignoreAll}}
            @disabled={{this.ignoring}}
            @translatedLabel="忽略全部"
          />
          <DButton
            class="btn-flat btn-small kuu-chat-unread-banner__close"
            @action={{this.close}}
            @icon="xmark"
            @translatedAriaLabel="关闭"
            @translatedTitle="这次先不提醒"
          />
        </span>
      </div>
    {{/if}}
  </template>
}

export default apiInitializer((api) => {
  // 没装或关了 chat 插件时不渲染（注入 chat 的服务会出错）
  if (!api.container.lookup("service:chat")) {
    return;
  }
  api.renderInOutlet("above-main-container", KuuChatUnreadBanner);
});
