// 「保存分享图」弹窗（Issue #12）：在浏览器里画好分享图，用 <img> 显示。
// - 手机：长按图片保存或转发。图片用 data URL，不用 blob URL：微信内置浏览器长按 blob URL 的图片存不下来
// - 电脑：「复制图片」，复制到剪贴板后可以直接粘贴进微信电脑版、QQ、聊天框（Issue #29）。
//   原来的「下载图片」是 <a download href="data:…">，点了会被 core 的全局链接拦截（lib/intercept-click.js）
//   当成站内链接 preventDefault 掉，所以没反应
// - 能分享文件的设备（Web Share）多一个「分享到…」
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import { buildShareData } from "../lib/kuu-share-data.js";
import { renderShareImage } from "../lib/kuu-share-image.js";
import { reportShare } from "../lib/kuu-share-reward.js";

const JPEG_QUALITY = 0.92;

export default class KuuShareImageModal extends Component {
  @service currentUser;
  @service site;
  @service siteSettings;
  @service toasts;

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
      this.canvas = canvas;
      this.imageUrl = canvas.toDataURL("image/jpeg", JPEG_QUALITY);
      this.file = new File([blob], this.filename, { type: "image/jpeg" });
      // 手机上靠长按保存，没有按钮可以挂：图片生成出来就算转发（Issue #32）
      if (this.site.mobileView) {
        reportShare({ currentUser: this.currentUser, toasts: this.toasts });
      }
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("kuu share image", error);
      if (!this.isDestroying) {
        this.failed = true;
      }
    }
  }

  // 剪贴板只普遍支持 PNG，从同一个 canvas 另导出一份。
  // Safari 要求在点击的同一次调用里把 Promise 交给 ClipboardItem，所以这里不能先 await 再 write
  @action
  copyImage() {
    if (!navigator.clipboard?.write || typeof ClipboardItem === "undefined") {
      this.copyFailed("这个浏览器不支持复制图片");
      return;
    }
    const png = new Promise((resolve, reject) =>
      this.canvas.toBlob(
        (blob) => (blob ? resolve(blob) : reject(new Error("png"))),
        "image/png"
      )
    );
    navigator.clipboard
      .write([new ClipboardItem({ "image/png": png })])
      .then(() => {
        this.toasts.success({
          duration: "short",
          data: { message: "已复制，可以直接粘贴" },
        });
        reportShare({ currentUser: this.currentUser, toasts: this.toasts });
      })
      .catch((error) =>
        this.copyFailed(
          error?.name === "NotAllowedError"
            ? "浏览器没有允许复制到剪贴板"
            : "复制没有成功"
        )
      );
  }

  copyFailed(reason) {
    this.toasts.error({
      duration: "long",
      data: {
        message: `${reason}。可以右键图片 →「复制图片」或「另存为」`,
      },
    });
  }

  @action
  async share() {
    try {
      await navigator.share({ files: [this.file] });
      reportShare({ currentUser: this.currentUser, toasts: this.toasts });
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
            <DButton
              class="btn-primary kuu-share-image-modal__copy"
              @action={{this.copyImage}}
              @icon="copy"
              @translatedLabel="复制图片"
            />
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
