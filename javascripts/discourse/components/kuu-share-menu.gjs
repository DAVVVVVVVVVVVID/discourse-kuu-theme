// 分享下拉菜单（Issue #12）：「复制链接」「保存分享图」。保存分享图只在公开帖子里有（私信、不公开分类没有）。
// 帖子菜单（post-share-menu.gjs）和评分主题的标题下面共用。
// - @topic：要生成分享图的话题；@url：复制的链接（帖子菜单里是这一楼的链接）
// - @label：按钮上的文字，不传就只有图标；@triggerClass：按钮的类名
// - 复制链接在手机上也直接复制（core 的复制链接按钮在手机上改成弹系统分享）
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { clipboardCopy } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";
import { canShareImage } from "../lib/kuu-share-data.js";
import KuuShareImageModal from "./kuu-share-image-modal.gjs";

export default class KuuShareMenu extends Component {
  @service modal;
  @service toasts;

  get icon() {
    return settings.post_share_icon;
  }

  get canShareImage() {
    return canShareImage(this.args.topic);
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  // 先复制再关菜单：iPhone Safari 只允许在点击后马上写剪贴板
  @action
  async copyLink() {
    await clipboardCopy(getAbsoluteURL(this.args.url));
    await this.dMenu.close();
    this.toasts.success({
      duration: "short",
      data: { message: i18n("post.controls.link_copied") },
    });
  }

  @action
  async saveImage() {
    await this.dMenu.close();
    this.modal.show(KuuShareImageModal, { model: { topic: this.args.topic } });
  }

  <template>
    <DMenu
      ...attributes
      @ariaLabel="分享"
      @icon={{this.icon}}
      @identifier="kuu-share-menu"
      @label={{@label}}
      @modalForMobile={{true}}
      @onRegisterApi={{this.onRegisterApi}}
      @title="分享"
      @triggerClass="kuu-share-menu {{@triggerClass}}"
    >
      <:content>
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
      </:content>
    </DMenu>
  </template>
}
