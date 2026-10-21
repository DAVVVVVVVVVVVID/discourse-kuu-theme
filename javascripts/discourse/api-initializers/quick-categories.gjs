// 顶部分类筛选的快捷按钮（2026-10-21）
// 帖子列表上方「全部 ▾」下拉框右边，放几个特色分类的快捷按钮（默认二手市场、评分中心）。
// - 挂在 core bread-crumbs.gjs 的 bread-crumbs-right 挂载点（渲染成 <li>）
// - 显示哪些分类由主题设置 quick_category_ids 决定，后台可以改
// - 当前就在这个分类（或它的子分类，比如评分对象）时按钮显示为选中，再点一次回到「最新」
// - 只在电脑上显示：手机上底栏（mobile-bottom-bar.gjs）已经有这两个入口（10-21 David 定）
// - 图标 + 文字，不要椭圆边框（10-22，Issue #20）；图标和手机底栏一致（lib/kuu-standalone.js 的 standaloneIcon）
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { apiInitializer } from "discourse/lib/api";
import Category from "discourse/models/category";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { standaloneIcon } from "../lib/kuu-standalone.js";

class KuuQuickCategories extends Component {
  @service site;

  get current() {
    return this.args.outletArgs?.category;
  }

  get items() {
    if (this.site.mobileView) {
      return [];
    }
    const current = this.current;
    return (settings.quick_category_ids || "")
      .split("|")
      .map((id) => Category.findById(parseInt(id, 10)))
      .filter(Boolean)
      .map((category) => {
        const active =
          !!current &&
          (current.id === category.id ||
            current.parent_category_id === category.id);
        return {
          id: category.id,
          name: category.name,
          active,
          url: active ? "/latest" : category.url,
          icon: standaloneIcon(category.id),
        };
      });
  }

  <template>
    {{#if this.items.length}}
      <div class="kuu-quick-cats">
        {{#each this.items as |item|}}
          <a
            class="kuu-quick-cat {{if item.active '--active'}}"
            data-category-id={{item.id}}
            href={{item.url}}
          >
            {{dIcon item.icon}}
            <span>{{item.name}}</span>
          </a>
        {{/each}}
      </div>
    {{/if}}
  </template>
}

export default apiInitializer((api) => {
  api.renderInOutlet("bread-crumbs-right", KuuQuickCategories);
});
