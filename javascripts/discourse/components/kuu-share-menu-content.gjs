// 分享下拉菜单的内容（Issue #12、#14）：「复制链接」「保存分享图」。保存分享图只在公开帖子里有（私信、不公开分类没有）。
// 帖子菜单里由 kuu-share-menu.gjs 的 DMenu 渲染，话题底部的「分享」按钮由 menu 服务直接弹出（topic-footer-share.js）。
// - @data.topic：要生成分享图的话题；@data.url：复制的链接；@close：关菜单
// - 复制链接在手机上也直接复制（core 的复制链接按钮在手机上改成弹系统分享）
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { clipboardCopy } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";
import { canShareImage } from "../lib/kuu-share-data.js";
import KuuShareImageModal from "./kuu-share-image-modal.gjs";

export default class KuuShareMenuContent extends Component {
  @service modal;
  @service toasts;

  get topic() {
    return this.args.data.topic;
  }

  get canShareImage() {
    return canShareImage(this.topic);
  }

  // 先复制再关菜单：iPhone Safari 只允许在点击后马上写剪贴板
  @action
  async copyLink() {
    await clipboardCopy(getAbsoluteURL(this.args.data.url));
    await this.args.close();
    this.toasts.success({
      duration: "short",
      data: { message: i18n("post.controls.link_copied") },
    });
  }

  @action
  async saveImage() {
    await this.args.close();
    this.modal.show(KuuShareImageModal, { model: { topic: this.topic } });
  }

  <template>
    <DDropdownMenu as |dropdown|>
      <dropdown.item>
        <DButton
          class="btn-transparent kuu-share-menu__copy"
          @action={{this.copyLink}}
          @icon="link"
          @translatedLabel="复制链接"
        />
      </dropdown.item>
      {{#if this.canShareImage}}
        <dropdown.item>
          <DButton
            class="btn-transparent kuu-share-menu__image"
            @action={{this.saveImage}}
            @icon="image"
            @translatedLabel="保存分享图"
          />
        </dropdown.item>
      {{/if}}
    </DDropdownMenu>
  </template>
}
