// 帖子菜单：分享按钮改成下拉菜单，回复按钮换图标（2026-10-21，Issue #12）
// - core 的「复制链接」按钮（post_menu 里的 copyLink；如果后台配置的是 share 也一样）换成
//   分享下拉菜单（components/kuu-share-menu.gjs）：「复制链接」「保存分享图」
// - 分享的图标换成箭头（主题设置 post_share_icon），回复的图标换成气泡（post_reply_icon）。
//   只换帖子菜单里这两个按钮，不用全局的 api.replaceIcon：link、reply 图标别处也在用
// - 话题最底部的「分享」在 topic-footer-share.js（Issue #14）
import PostMenuReplyButton from "discourse/components/post/menu/buttons/reply";
import { apiInitializer } from "discourse/lib/api";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import KuuShareMenu from "../components/kuu-share-menu.gjs";

const KuuPostShareButton = <template>
  <KuuShareMenu
    ...attributes
    @topic={{@post.topic}}
    @triggerClass="btn-flat post-action-menu__copy-link"
    @url={{@post.shareUrl}}
  />
</template>;

// 照抄 core 的回复按钮，只换图标；显示条件、文字都继承 core
class KuuPostReplyButton extends PostMenuReplyButton {
  get icon() {
    return settings.post_reply_icon;
  }

  <template>
    <DButton
      class={{dConcatClass
        "post-action-menu__reply"
        "reply"
        (if this.showLabel "create fade-out")
      }}
      ...attributes
      @action={{@buttonActions.replyToPost}}
      @icon={{this.icon}}
      @label={{if this.showLabel "topic.reply.title"}}
      @title="post.controls.reply"
      @translatedAriaLabel={{i18n
        "post.sr_reply_to"
        post_number=@post.post_number
        username=@post.username
      }}
    />
  </template>
}

export default apiInitializer((api) => {
  api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { buttonKeys } }) => {
      dag.replace(buttonKeys.REPLY, KuuPostReplyButton);

      // 两个都配置了时只留一个分享菜单
      if (dag.has(buttonKeys.COPY_LINK)) {
        dag.replace(buttonKeys.COPY_LINK, KuuPostShareButton);
        dag.delete(buttonKeys.SHARE);
      } else {
        dag.replace(buttonKeys.SHARE, KuuPostShareButton);
      }
    }
  );
});
