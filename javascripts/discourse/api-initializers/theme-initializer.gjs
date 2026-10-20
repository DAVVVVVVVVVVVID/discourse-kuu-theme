// KUU 自定义组件：注册后等待激活邮件的页面（2026-10-19 上线；2026-10-20 激活码 60 秒版待贴）
// 线上：后台 → 外观 → 组件「KUU 自定义组件」→ 编辑 CSS/HTML → 通用（Common）→ JS，整段贴进去。改动后同步回这个文件。
//
// 做什么：
// - 只在注册后的等待页（路由 account-created.index / account-created.resent）最上方显示提示和倒计时
// - 倒计时期间给 <html> 加 kuu-activation-waiting 类，CSS 据此先藏起「重新发送激活邮件」按钮；「修改邮箱」按钮一直在
// - 点了「重新发送」进入 resent 页时，倒计时重新开始
// - 京大邮箱插件的激活码开关（kuu_kyoto_email_activation_code_enabled，前端可读）打开时：
//   邮件里只有 6 位激活码、1–2 分钟就到；倒计时 60 秒，之后放出「重新发送」。
//   插件 417dc90 起重新发送会再发同一个码（没过期的话），所以早点放出按钮也不会让手里的码失效
// - 开关关闭时（发带链接的激活邮件，京大邮箱要扫描链接，5 分钟左右）：倒计时 5 分钟
// - 激活码输入框是插件挂在同一个 outlet 里的（.kuu-kyoto-email-account-created），不归这里管
// - 2026-10-19 版里的 B 站视频 10-20 David 决定去掉
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { apiInitializer } from "discourse/lib/api";

const WAIT_SECONDS_LINK = 5 * 60;
const WAIT_SECONDS_CODE = 60;
const ROUTES = ["account-created.index", "account-created.resent"];

class KuuActivationWait extends Component {
  @service router;
  @service siteSettings;

  waitSeconds = this.siteSettings.kuu_kyoto_email_activation_code_enabled
    ? WAIT_SECONDS_CODE
    : WAIT_SECONDS_LINK;

  @tracked remaining = this.waitSeconds;

  startedAt = Date.now();
  ticker = null;

  constructor() {
    super(...arguments);
    this.router.on("routeDidChange", this.onRouteChange);
    this.ticker = setInterval(this.update, 1000);
    this.update();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    clearInterval(this.ticker);
    this.router.off("routeDidChange", this.onRouteChange);
    document.documentElement.classList.remove("kuu-activation-waiting");
  }

  get codeMode() {
    return this.waitSeconds === WAIT_SECONDS_CODE;
  }

  get done() {
    return this.remaining <= 0;
  }

  get clock() {
    const m = Math.floor(this.remaining / 60);
    const s = String(this.remaining % 60).padStart(2, "0");
    return `${m}:${s}`;
  }

  @action
  onRouteChange(transition) {
    if (transition?.to?.name === "account-created.resent") {
      this.startedAt = Date.now();
    }
    this.update();
  }

  @action
  update() {
    const passed = Math.floor((Date.now() - this.startedAt) / 1000);
    this.remaining = Math.max(0, this.waitSeconds - passed);
    document.documentElement.classList.toggle(
      "kuu-activation-waiting",
      this.remaining > 0
    );
  }

  <template>
    <div class="kuu-activation-wait">
      {{#if this.codeMode}}
        {{#if this.done}}
          <p class="kuu-activation-wait__done">
            还没收到？先看看邮箱的<b>「其他」</b>和<b>垃圾邮件</b>文件夹；还是没有，可以点下面的「重新发送激活电子邮件」，会<b>再发一次同一个激活码</b>，之前那封到了照样能用。
          </p>
        {{else}}
          <p class="kuu-activation-wait__hint">
            激活码正在路上～一般 1–2 分钟就到，记得也看看邮箱的<b>「其他」</b>文件夹。
          </p>
          <div class="kuu-activation-wait__timer">{{this.clock}}</div>
        {{/if}}
      {{else}}
        {{#if this.done}}
          <p class="kuu-activation-wait__done">
            5 分钟到啦！还没收到的话，先看看<b>垃圾邮件</b>文件夹；还是没有，再点下面的「重新发送激活邮件」。
          </p>
        {{else}}
          <p class="kuu-activation-wait__hint">
            激活邮件正在路上～京大邮箱一般要 5 分钟左右才收到，<b>先别点「重新发送」</b>（重发后之前的邮件就失效了）
          </p>
          <div class="kuu-activation-wait__timer">{{this.clock}}</div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}

class KuuActivationWaitGate extends Component {
  @service router;

  get show() {
    return ROUTES.includes(this.router.currentRouteName);
  }

  <template>
    {{#if this.show}}
      <KuuActivationWait />
    {{/if}}
  </template>
}

export default apiInitializer((api) => {
  api.renderInOutlet("above-main-container", KuuActivationWaitGate);
});
