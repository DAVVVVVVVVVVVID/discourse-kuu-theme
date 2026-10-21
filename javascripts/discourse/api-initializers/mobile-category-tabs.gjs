// 手机端顶部分类标签（2026-10-21，Issue #9）
// 代替手机上的「全部 ▾」下拉框：「全部」（/latest）+ 各个一级分类，横向滑动，当前标签下面一条短横线；
// 最右边「⌄」展开成多行显示全部分类，再点收起。
// - 挂在 core d-navigation.gjs 的 after-breadcrumbs 挂载点；有这一行时 CSS 藏掉 core 的下拉框
// - 顺序和后台分类顺序一致（site.categoriesList）；子分类（比如评分对象）不显示；
//   主题设置 category_tabs_hidden_ids 里的分类（默认 3 = 管理人员）不显示，未分类不显示
// - 标签页（/tag/...）不显示，保留 core 的下拉框，不然看不出在哪个标签里
// - 只在手机上显示；电脑上还是下拉框 + 快捷按钮（quick-categories.gjs）
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { apiInitializer } from "discourse/lib/api";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dScrollIntoView from "discourse/ui-kit/modifiers/d-scroll-into-view";
import { isStandaloneCategory } from "../lib/kuu-standalone.js";
import { hiddenTabCategoryIds } from "../lib/kuu-waterfall.js";

const SCROLL_OPTIONS = {
  behavior: "instant",
  block: "nearest",
  inline: "center",
};

class KuuCategoryTabs extends Component {
  @service site;

  @tracked expanded = false;

  get show() {
    const { tag, additionalTags, category } = this.args.outletArgs;
    // 二手 / 评分这些独立页面上顶部换成「‹ 首页」+ 标题（standalone-categories.gjs）
    return (
      this.site.mobileView &&
      !tag &&
      !additionalTags?.length &&
      !isStandaloneCategory(category)
    );
  }

  get current() {
    const category = this.args.outletArgs.category;
    return category?.parentCategory || category;
  }

  get tabs() {
    const hidden = hiddenTabCategoryIds();
    const current = this.current;

    const categories = (this.site.categoriesList || [])
      .filter(
        (category) =>
          !category.parent_category_id &&
          !category.isUncategorizedCategory &&
          !hidden.includes(category.id)
      )
      .map((category) => ({
        id: category.id,
        name: category.name,
        url: category.url,
        active: current?.id === category.id,
      }));

    return [
      { id: "all", name: "全部", url: "/latest", active: !current },
      ...categories,
    ];
  }

  @action
  toggle() {
    this.expanded = !this.expanded;
  }

  @action
  collapse() {
    this.expanded = false;
  }

  <template>
    {{#if this.show}}
      <nav
        aria-label="分类"
        class="kuu-cat-tabs {{if this.expanded '--expanded'}}"
      >
        <ul class="kuu-cat-tabs__list">
          {{#each this.tabs key="id" as |tab|}}
            <li
              class="kuu-cat-tabs__item"
              {{dScrollIntoView tab.active SCROLL_OPTIONS}}
            >
              <a
                aria-current={{if tab.active "page"}}
                class="kuu-cat-tabs__link {{if tab.active '--active'}}"
                href={{tab.url}}
                {{on "click" this.collapse}}
              >{{tab.name}}</a>
            </li>
          {{/each}}
        </ul>
        <button
          aria-expanded={{if this.expanded "true" "false"}}
          aria-label={{if this.expanded "收起分类" "展开全部分类"}}
          class="kuu-cat-tabs__toggle"
          type="button"
          {{on "click" this.toggle}}
        >
          {{dIcon "angle-down"}}
        </button>
      </nav>
    {{/if}}
  </template>
}

export default apiInitializer((api) => {
  api.renderInOutlet("after-breadcrumbs", KuuCategoryTabs);
});
