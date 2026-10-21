// 瀑布流里的一张卡片（Issue #9）：封面（原图比例或文字封面）、标题两行、作者和第一楼的赞。
// 文字封面上已经是大字标题，下面改成正文开头两行（没有摘要就不显示，PR #11 审核 David 定）。
// 二手帖标题换成商品名（标题里本来带着【出售】和价格，和下面的价格、状态重复），
// 下面加价格和状态；评分主题、置顶帖在封面上加角标。
// 整张卡片是一个链接，作者不单独做链接（链接里不能再套链接）
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { or } from "discourse/truth-helpers";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class KuuWaterfallCard extends Component {
  get topic() {
    return this.args.item.topic;
  }

  get cover() {
    return this.args.item.cover;
  }

  get coverStyle() {
    const ratio = `--kuu-wf-ratio: ${(this.cover.ratio * 100).toFixed(2)}%;`;
    const text = this.cover.textCover;
    if (!text) {
      return trustHTML(ratio);
    }
    const background = text.image
      ? `background-image: url("${encodeURI(text.image)}");`
      : `background-color: ${text.background};`;
    return trustHTML(`${ratio} ${background} color: ${text.color};`);
  }

  // 二手帖用纯文字的商品名，其他帖子用 core 处理过 emoji 的标题
  get itemName() {
    return this.topic.kuu_market_card?.item_name;
  }

  get badge() {
    if (this.topic.pinned) {
      return "置顶";
    }
    if (this.topic.kuu_rating_board_card) {
      return "评分";
    }
  }

  get market() {
    const card = this.topic.kuu_market_card;
    if (!card) {
      return;
    }
    const status = this.topic.kuu_market_status;
    return {
      price: card.price,
      free: card.free,
      status,
      statusLabel: i18n(`kuu_market.card_statuses.${status}`),
      ended: !["selling", "buying"].includes(status),
    };
  }

  get url() {
    return this.topic.linked_post_number
      ? this.topic.urlForPostNumber(this.topic.linked_post_number)
      : this.topic.lastUnreadUrl;
  }

  <template>
    <a
      class="kuu-wf-card {{if this.market.ended '--ended'}}"
      data-topic-id={{this.topic.id}}
      href={{this.url}}
    >
      <span
        class="kuu-wf-card__cover {{if this.cover.textCover '--text'}}"
        style={{this.coverStyle}}
      >
        {{#if this.cover.textCover}}
          <span class="kuu-wf-card__cover-title">
            <span class="kuu-wf-card__cover-text">
              {{#if this.itemName}}
                {{this.itemName}}
              {{else}}
                {{trustHTML this.topic.fancyTitle}}
              {{/if}}
            </span>
          </span>
        {{else}}
          <img alt="" decoding="async" loading="lazy" src={{this.cover.url}} />
        {{/if}}
        {{#if this.badge}}
          <span class="kuu-wf-card__badge">{{this.badge}}</span>
        {{/if}}
      </span>

      <span class="kuu-wf-card__body">
        {{#if this.cover.textCover}}
          {{#if this.topic.hasExcerpt}}
            <span class="kuu-wf-card__excerpt">
              {{trustHTML this.topic.escapedExcerpt}}
            </span>
          {{/if}}
        {{else}}
          <span class="kuu-wf-card__title">
            {{#if this.itemName}}
              {{this.itemName}}
            {{else}}
              {{trustHTML this.topic.fancyTitle}}
            {{/if}}
          </span>
        {{/if}}

        {{#if this.market}}
          <span class="kuu-wf-card__market">
            <span class="kuu-wf-card__price {{if this.market.free '--free'}}">
              {{this.market.price}}
            </span>
            <span
              class="kuu-wf-card__status kuu-market-status-{{this.market.status}}"
            >
              {{this.market.statusLabel}}
            </span>
          </span>
        {{/if}}

        <span class="kuu-wf-card__meta">
          <span class="kuu-wf-card__author">
            {{dAvatar this.topic.creator imageSize="small" hideTitle=true}}
            <span class="kuu-wf-card__username">
              {{or this.topic.creator.name this.topic.creator.username}}
            </span>
          </span>
          <span class="kuu-wf-card__likes">
            {{dIcon "d-unliked"}}
            {{this.topic.op_like_count}}
          </span>
        </span>
      </span>
    </a>
  </template>
}
