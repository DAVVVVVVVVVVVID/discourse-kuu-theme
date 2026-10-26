// 瀑布流里搭子帖的封面（Issue #37 方案 A「信息卡」）：米白底，从上到下是状态胶囊、标题（最多 3 行）、
// 时间、条件（各最多 2 行，条件为空不显示），底部是成员头像叠放 + 招募中的虚线空位，以及人数。
// 数据：列表里的 topic.kuu_buddy_card（搭子插件给搭子帖带上的）
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { avatarUrl } from "discourse/lib/avatar-utils";
import {
  buddySeats,
  buddyStatusKey,
  buddyStatusLabel,
} from "../lib/kuu-buddy.js";

const MAX_CIRCLES = 5;

export default class KuuWaterfallBuddyCover extends Component {
  get card() {
    return this.args.topic.kuu_buddy_card;
  }

  get statusKey() {
    return buddyStatusKey(this.card.status, this.card.start_reason);
  }

  get statusLabel() {
    return buddyStatusLabel(this.statusKey);
  }

  get seats() {
    const seats = buddySeats({
      members: this.card.members,
      memberCount: this.card.member_count,
      capacity: this.card.capacity,
      status: this.card.status,
      maxCircles: MAX_CIRCLES,
    });
    return {
      ...seats,
      avatars: seats.avatars.map((user) => ({
        id: user.id,
        url: avatarUrl(user.avatar_template, "small"),
      })),
      emptyList: Array.from({ length: seats.empties }, (_, i) => i),
    };
  }

  get recruiting() {
    return this.card.status === "recruiting";
  }

  <template>
    <span class="kuu-wf-buddy">
      <span
        class="kuu-wf-buddy__status --{{this.statusKey}}"
      >{{this.statusLabel}}</span>
      <span class="kuu-wf-buddy__title">{{trustHTML @topic.fancyTitle}}</span>
      {{#if this.card.schedule}}
        <span class="kuu-wf-buddy__kv">
          <span class="kuu-wf-buddy__label">时间</span>{{this.card.schedule}}
        </span>
      {{/if}}
      {{#if this.card.requirements}}
        <span class="kuu-wf-buddy__kv">
          <span
            class="kuu-wf-buddy__label"
          >条件</span>{{this.card.requirements}}
        </span>
      {{/if}}
      <span class="kuu-wf-buddy__seats">
        <span class="kuu-wf-buddy__dots">
          {{#each this.seats.avatars key="id" as |avatar|}}
            <img alt="" class="kuu-wf-buddy__dot" src={{avatar.url}} />
          {{/each}}
          {{#each this.seats.emptyList}}
            <span class="kuu-wf-buddy__dot --empty"></span>
          {{/each}}
        </span>
        <span class="kuu-wf-buddy__count">
          {{this.card.member_count}}
          /
          {{this.card.capacity}}
          人
          {{#if this.seats.full}}
            <em class="--full">已满</em>
          {{else if this.recruiting}}
            <em>还差 {{this.seats.spotsLeft}} 人</em>
          {{/if}}
        </span>
      </span>
    </span>
  </template>
}
