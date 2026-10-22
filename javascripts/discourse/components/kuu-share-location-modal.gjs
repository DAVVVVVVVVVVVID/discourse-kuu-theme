// 聊天里「分享位置」的小窗口（Issue #24 第 2 条）：先选地点（当前位置 / 搜索），再预览、确认后才发送。
// - 当前位置不会自动发送：拿到以后同样进预览，名字可以改
// - 确认页写清楚谁会看到这个位置（私聊：对方；频道：频道里的所有人）
// - @model.send(message)：发送（由 chat-share-location.js 传进来，用 chat 插件的 sendChatMessage）
// - @model.isDirectMessage：是不是私聊
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import {
  currentPosition,
  formatCoordinates,
  locationMessage,
  OSM_ATTRIBUTION,
  previewTiles,
  searchPlaces,
} from "../lib/kuu-location.js";

export default class KuuShareLocationModal extends Component {
  @tracked query = "";
  @tracked results = null;
  @tracked place = null;
  @tracked error = null;
  @tracked loading = null; // "locate" | "search" | "send"

  get locating() {
    return this.loading === "locate";
  }

  get searching() {
    return this.loading === "search";
  }

  get pinIcon() {
    return settings.chat_location_icon;
  }

  get locateIcon() {
    return settings.chat_location_current_icon;
  }

  get audience() {
    return this.args.model.isDirectMessage
      ? "对方会看到这个位置"
      : "频道里的所有人都会看到这个位置";
  }

  get tiles() {
    return previewTiles(this.place.lat, this.place.lng).map((tile) => ({
      url: tile.url,
      style: trustHTML(`left: ${tile.left}px; top: ${tile.top}px;`),
    }));
  }

  get coordinates() {
    return formatCoordinates(this.place.lat, this.place.lng);
  }

  @action
  async locate() {
    this.error = null;
    this.loading = "locate";
    try {
      const { lat, lng } = await currentPosition();
      this.place = { name: "我的位置", address: "", lat, lng, editable: true };
    } catch (error) {
      this.error = error.message;
    } finally {
      this.loading = null;
    }
  }

  @action
  updateQuery(event) {
    this.query = event.target.value;
  }

  @action
  async search(event) {
    event?.preventDefault();
    const query = this.query.trim();
    if (!query || this.loading) {
      return;
    }
    this.error = null;
    this.loading = "search";
    try {
      this.results = await searchPlaces(query);
    } catch (error) {
      this.error = error.message;
    } finally {
      this.loading = null;
    }
  }

  @action
  choose(place) {
    this.place = place;
  }

  @action
  updateName(event) {
    this.place = { ...this.place, name: event.target.value };
  }

  @action
  back() {
    this.place = null;
  }

  @action
  async send() {
    if (!this.place.name.trim()) {
      this.place = { ...this.place, name: "我的位置" };
    }
    this.loading = "send";
    try {
      await this.args.model.send(locationMessage(this.place));
      this.args.closeModal();
    } catch {
      this.error = "发送失败，请再试一次";
    } finally {
      this.loading = null;
    }
  }

  <template>
    <DModal
      class="kuu-share-location-modal"
      @closeModal={{@closeModal}}
      @title={{if this.place "确认发送位置" "分享位置"}}
    >
      <:body>
        {{#if this.error}}
          <p class="kuu-share-location-modal__error">{{this.error}}</p>
        {{/if}}

        {{#if this.place}}
          <div class="kuu-share-location-modal__preview">
            <div class="kuu-share-location-modal__map">
              {{#each this.tiles as |tile|}}
                <img alt="" src={{tile.url}} style={{tile.style}} />
              {{/each}}
              <span class="kuu-share-location-modal__marker">{{dIcon
                  this.pinIcon
                }}</span>
            </div>
            {{#if this.place.editable}}
              <label class="kuu-share-location-modal__name-label">
                地点名（会显示在消息里）
                <input
                  class="kuu-share-location-modal__name-input"
                  maxlength="60"
                  type="text"
                  value={{this.place.name}}
                  {{on "input" this.updateName}}
                />
              </label>
            {{else}}
              <p class="kuu-share-location-modal__name">{{this.place.name}}</p>
            {{/if}}
            {{#if this.place.address}}
              <p
                class="kuu-share-location-modal__address"
              >{{this.place.address}}</p>
            {{/if}}
            <p class="kuu-share-location-modal__coords">{{this.coordinates}}</p>
            <p class="kuu-share-location-modal__notice">
              {{dIcon "eye"}}
              {{this.audience}}
            </p>
            <p
              class="kuu-share-location-modal__attribution"
            >{{OSM_ATTRIBUTION}}</p>
          </div>
        {{else}}
          <DButton
            class="btn-default kuu-share-location-modal__locate"
            @action={{this.locate}}
            @disabled={{this.loading}}
            @icon={{this.locateIcon}}
            @translatedLabel="使用我的当前位置"
          />
          {{#if this.locating}}
            <span class="kuu-share-location-modal__loading">{{dLoadingSpinner
                size="small"
              }}
              正在定位…</span>
          {{/if}}

          <form
            class="kuu-share-location-modal__search"
            {{on "submit" this.search}}
          >
            <input
              aria-label="搜索地点"
              class="kuu-share-location-modal__query"
              placeholder="搜索地点，比如：百万遍、京都站"
              type="search"
              value={{this.query}}
              {{on "input" this.updateQuery}}
            />
            <DButton
              class="btn-primary"
              @action={{this.search}}
              @disabled={{this.loading}}
              @translatedLabel="搜索"
            />
          </form>

          {{#if this.searching}}
            <span class="kuu-share-location-modal__loading">{{dLoadingSpinner
                size="small"
              }}
              正在搜索…</span>
          {{else if this.results}}
            {{#if this.results.length}}
              <ul class="kuu-share-location-modal__results">
                {{#each this.results as |result|}}
                  <li>
                    <button
                      class="kuu-share-location-modal__result"
                      type="button"
                      {{on "click" (fn this.choose result)}}
                    >
                      <span
                        class="kuu-share-location-modal__result-name"
                      >{{result.name}}</span>
                      <span
                        class="kuu-share-location-modal__result-address"
                      >{{result.address}}</span>
                    </button>
                  </li>
                {{/each}}
              </ul>
              <p
                class="kuu-share-location-modal__attribution"
              >{{OSM_ATTRIBUTION}}</p>
            {{else}}
              <p
                class="kuu-share-location-modal__empty"
              >没有找到，换个说法试试</p>
            {{/if}}
          {{/if}}
        {{/if}}
      </:body>
      <:footer>
        {{#if this.place}}
          <DButton
            class="btn-primary"
            @action={{this.send}}
            @disabled={{this.loading}}
            @icon="paper-plane"
            @translatedLabel="发送位置"
          />
          <DButton
            class="btn-flat"
            @action={{this.back}}
            @disabled={{this.loading}}
            @translatedLabel="重新选择"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
