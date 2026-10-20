// 手机底栏（2026-10-21）
// 左：二手市场，中：突出的圆形「+」发帖，右：评分中心。只在手机上显示，所有页面都有；
// 写帖子（编辑器打开）时由 CSS 藏起来。原来 FKB Pro 在列表页的悬浮按钮（新建话题、铃铛、
// 「最新 / 新 / 热门」切换）由 CSS 隐藏，换成这个底栏。
// - 挂在 core application 模板的 below-footer 挂载点：所有页面都会渲染；底栏本身 position: fixed
// - 「+」：未登录跳到登录页；登录后调用 discourse-kuu-new-topic 插件的 openNewTopic()，
//   和点 core「新建话题」一样（专属分类直接开表单，其他地方弹选择框）。插件没有这个方法时退回普通编辑器
// - 两边的分类和图标由主题设置决定：bottom_bar_left_category / _icon、bottom_bar_right_category / _icon
// - 当前在这个分类（或它的子分类）时按钮高亮
import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { apiInitializer } from "discourse/lib/api";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import dIcon from "discourse/ui-kit/helpers/d-icon";

class KuuMobileBottomBar extends Component {
  @service site;
  @service currentUser;
  @service discovery;
  @service router;
  @service composer;

  get currentCategory() {
    const fromList = this.discovery?.category;
    if (fromList) {
      return fromList;
    }
    // 帖子页：用帖子所在的分类来高亮（发帖时不预选，弹选择框）
    const categoryId = this.router.currentRoute?.attributes?.category_id;
    return categoryId ? Category.findById(categoryId) : null;
  }

  item(categoryId, icon) {
    const category = Category.findById(parseInt(categoryId, 10));
    if (!category) {
      return null;
    }
    const current = this.currentCategory;
    const active =
      !!current &&
      (current.id === category.id ||
        current.parent_category_id === category.id);
    return { name: category.name, url: category.url, icon, active };
  }

  get left() {
    return this.item(
      settings.bottom_bar_left_category,
      settings.bottom_bar_left_icon
    );
  }

  get right() {
    return this.item(
      settings.bottom_bar_right_category,
      settings.bottom_bar_right_icon
    );
  }

  get centerIcon() {
    return settings.bottom_bar_center_icon;
  }

  @action
  newTopic() {
    if (!this.currentUser) {
      DiscourseURL.routeTo("/login");
      return;
    }

    // 只在帖子列表页带上当前分类 / 标签，和 core「新建话题」按钮一致
    const category = this.discovery?.category;
    const tag = this.discovery?.tag;
    const newTopic = getOwner(this).lookup("service:kuu-new-topic");

    if (typeof newTopic?.openNewTopic === "function") {
      newTopic.openNewTopic({ category, tag });
    } else {
      this.composer.openNewTopic({ category, tags: tag ? [tag.id] : [] });
    }
  }

  <template>
    {{#if this.site.mobileView}}
      <nav class="kuu-bottom-bar" aria-label="快捷导航">
        {{#if this.left}}
          <a
            href={{this.left.url}}
            class="kuu-bottom-bar__item {{if this.left.active '--active'}}"
          >
            {{dIcon this.left.icon}}
            <span class="kuu-bottom-bar__label">{{this.left.name}}</span>
          </a>
        {{else}}
          <span></span>
        {{/if}}

        <button
          type="button"
          class="kuu-bottom-bar__plus"
          aria-label="发帖"
          {{on "click" this.newTopic}}
        >
          {{dIcon this.centerIcon}}
        </button>

        {{#if this.right}}
          <a
            href={{this.right.url}}
            class="kuu-bottom-bar__item {{if this.right.active '--active'}}"
          >
            {{dIcon this.right.icon}}
            <span class="kuu-bottom-bar__label">{{this.right.name}}</span>
          </a>
        {{else}}
          <span></span>
        {{/if}}
      </nav>
    {{/if}}
  </template>
}

export default apiInitializer((api) => {
  api.renderInOutlet("below-footer", KuuMobileBottomBar);
});
