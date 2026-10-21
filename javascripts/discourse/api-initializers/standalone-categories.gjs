// 二手市场、评分中心做成「独立页面」（2026-10-22，Issue #20）。分类由主题设置 standalone_category_ids 决定（子分类也算），
// 首页混合列表里的二手卡片、评分卡片不变，帖子页不变。
// - 侧边栏「类别」里不显示：core 没有过滤侧边栏分类的钩子（用户自己选过的分类也要藏），
//   所以按分类 ID 生成一段 CSS，按链接网址（/c/slug/ID）藏掉
// - 「全部 ▾」分类下拉里不显示：select-kit 的 replaceContent
// - 侧边栏「话题」下面加入口（图标 + 文字，图标和手机底栏一致）。插件 API 加的链接默认排在 core 链接后面，
//   由 CSS 的 order 挪到「话题」正下方
// - 进入这些分类的列表页后，顶部这一行只显示「‹ 首页」+ 标题（电脑上保留发帖按钮）：
//   挂在 d-navigation.gjs 的 after-breadcrumbs，给 body 加 kuu-standalone-page，其他东西由 CSS 藏起来
import Component from "@glimmer/component";
import bodyClass from "discourse/helpers/body-class";
import { apiInitializer } from "discourse/lib/api";
import Category from "discourse/models/category";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import {
  isStandaloneCategory,
  standaloneCategories,
  standaloneCategoryIdsWithChildren,
  standaloneIcon,
} from "../lib/kuu-standalone.js";

class KuuStandaloneHeader extends Component {
  get category() {
    const { category, tag } = this.args.outletArgs;
    return !tag && isStandaloneCategory(category) ? category : null;
  }

  <template>
    {{#if this.category}}
      {{bodyClass "kuu-standalone-page"}}
      <div class="kuu-standalone-header">
        <a class="kuu-standalone-header__back" href="/latest">
          {{dIcon "chevron-left"}}
          <span>首页</span>
        </a>
        <h1 class="kuu-standalone-header__title">{{this.category.name}}</h1>
      </div>
    {{/if}}
  </template>
}

function hideFromSidebarCategories(ids) {
  if (!ids.length) {
    return;
  }
  const style = document.createElement("style");
  style.id = "kuu-standalone-categories";
  style.textContent = `${ids
    .map(
      (id) =>
        `.sidebar-section[data-section-name="categories"] li:has(> a[href$="/${id}"])`
    )
    .join(",\n")} { display: none; }`;
  document.head.appendChild(style);
}

export default apiInitializer((api) => {
  const site = api.container.lookup("service:site");
  const discovery = api.container.lookup("service:discovery");
  const hiddenIds = standaloneCategoryIdsWithChildren(site);

  hideFromSidebarCategories(hiddenIds);

  api
    .modifySelectKit("category-drop")
    .replaceContent((_component, content) =>
      content.filter((item) => !hiddenIds.includes(item.id))
    );

  for (const category of standaloneCategories()) {
    api.addCommunitySectionLink((BaseCommunitySectionLink) => {
      return class extends BaseCommunitySectionLink {
        get name() {
          return `kuu-standalone-${category.id}`;
        }

        get route() {
          return "discovery.category";
        }

        get model() {
          return `${Category.slugFor(category)}/${category.id}`;
        }

        // 这个分类和它的子分类（比如评分对象）的列表页都算「在这个页面」（Issue #22）。
        // currentWhen 给布尔值时侧边栏直接用它决定高亮；discovery.category 跟着路由变，不在列表页时是空的
        get currentWhen() {
          const current = discovery.category;
          return (
            !!current &&
            (current.id === category.id ||
              current.parent_category_id === category.id)
          );
        }

        get title() {
          return category.name;
        }

        get text() {
          return category.name;
        }

        get prefixValue() {
          return standaloneIcon(category.id);
        }
      };
    });
  }

  api.renderInOutlet("after-breadcrumbs", KuuStandaloneHeader);
});
