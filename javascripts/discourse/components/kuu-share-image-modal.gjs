// 「保存分享图」弹窗（Issue #12）：在浏览器里画好分享图，用 <img> 显示。
// - 手机：长按图片保存或转发。图片用 data URL，不用 blob URL：微信内置浏览器长按 blob URL 的图片存不下来
// - 电脑：「下载图片」
// - 能分享文件的设备（Web Share）多一个「分享到…」
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import { buildShareData } from "../lib/kuu-share-data.js";
import { renderShareImage } from "../lib/kuu-share-image.js";

const JPEG_QUALITY = 0.92;

export default class KuuShareImageModal extends Component {
  @service site;
  @service siteSettings;

  @tracked imageUrl = null;
  @tracked file = null;
  @tracked failed = false;

  constructor() {
    super(...arguments);
    this.generate();
  }

  get topic() {
    return this.args.model.topic;
  }

  get filename() {
    return `kyotooo-${this.topic.id}.jpg`;
  }

  get canShareFile() {
    return !!this.file && !!navigator.canShare?.({ files: [this.file] });
  }

  get shareIcon() {
    return settings.post_share_icon;
  }

  async generate() {
    try {
      const data = await buildShareData(this.topic, this.siteSettings);
      const canvas = renderShareImage(data);
      const blob = await new Promise((resolve) =>
        canvas.toBlob(resolve, "image/jpeg", JPEG_QUALITY)
      );
      if (this.isDestroying) {
        return;
      }
      this.imageUrl = canvas.toDataURL("image/jpeg", JPEG_QUALITY);
      this.file = new File([blob], this.filename, { type: "image/jpeg" });
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("kuu share image", error);
      if (!this.isDestroying) {
        this.failed = true;
      }
    }
  }

  @action
  async share() {
    try {
      await navigator.share({ files: [this.file] });
    } catch {
      // 用户取消分享
    }
  }

  <template>
    <DModal
      class="kuu-share-image-modal"
      @closeModal={{@closeModal}}
      @title="保存分享图"
    >
      <:body>
        {{#if this.imageUrl}}
          <img
            alt={{this.topic.title}}
            class="kuu-share-image-modal__image"
            src={{this.imageUrl}}
          />
          {{#if this.site.mobileView}}
            <p class="kuu-share-image-modal__hint">长按图片保存或转发</p>
          {{/if}}
        {{else if this.failed}}
          <p class="kuu-share-image-modal__error">生成失败，请稍后再试</p>
        {{else}}
          <div class="kuu-share-image-modal__loading">
            {{dLoadingSpinner}}
            <span>正在生成…</span>
          </div>
        {{/if}}
      </:body>
      <:footer>
        {{#if this.imageUrl}}
          {{#unless this.site.mobileView}}
            <a
              class="btn btn-primary btn-icon-text"
              download={{this.filename}}
              href={{this.imageUrl}}
            >
              {{dIcon "download"}}
              <span class="d-button-label">下载图片</span>
            </a>
          {{/unless}}
          {{#if this.canShareFile}}
            <DButton
              class="btn-default"
              @action={{this.share}}
              @icon={{this.shareIcon}}
              @translatedLabel="分享到…"
            />
          {{/if}}
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
