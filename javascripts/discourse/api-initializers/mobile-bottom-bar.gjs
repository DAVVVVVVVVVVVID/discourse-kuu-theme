// 手机底栏（2026-10-21）
// 首页 | 二手 | 突出的圆形「+」 | 评分 | 我的。只在手机上显示，所有页面都有；
// 写帖子（编辑器打开）时由 CSS 藏起来。原来 FKB Pro 在列表页的悬浮按钮（新建话题、铃铛、
// 「最新 / 新 / 热门」切换）由 CSS 隐藏，换成这个底栏。
// - 挂在 core application 模板的 below-footer 挂载点：所有页面都会渲染；底栏本身 position: fixed
// - 首页：/latest，在不分分类、不分标签的列表页（最新、热门……）时高亮
// - 二手 / 评分：主题设置里的分类（bottom_bar_left_category / bottom_bar_right_category），
//   当前在这个分类（或子分类）或它的帖子里时高亮
// - 「+」：未登录跳到登录页；登录后调用 discourse-kuu-new-topic 插件的 openNewTopic()，
//   和点 core「新建话题」一样（专属分类直接开表单，其他地方弹选择框）。插件没有这个方法时退回普通编辑器
// - 我的：自己的个人主页「总结」页；未登录跳到登录页；在自己的个人页、偏好设置里时高亮
// - 文字和图标都是主题设置（bottom_bar_*_label、bottom_bar_*_icon）
import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { apiInitializer } from "discourse/lib/api";
import DiscourseURL, { userPath } from "discourse/lib/url";
import Category from "discourse/models/category";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const KuuBottomBarItem = <template>
  {{#if @item}}
    <a
      class="kuu-bottom-bar__item {{if @item.active '--active'}}"
      href={{@item.url}}
    >
      {{dIcon @item.icon}}
      <span class="kuu-bottom-bar__label">{{@item.label}}</span>
    </a>
  {{else}}
    <span></span>
  {{/if}}
</template>;

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

  get home() {
    const routeName = this.router.currentRouteName || "";
    const active =
      routeName.startsWith("discovery.") &&
      !this.discovery?.category &&
      !this.discovery?.tag;
    return {
      label: settings.bottom_bar_home_label,
      icon: settings.bottom_bar_home_icon,
      url: "/latest",
      active,
    };
  }

  get left() {
    return this.categoryItem(
      settings.bottom_bar_left_category,
      settings.bottom_bar_left_icon,
      settings.bottom_bar_left_label
    );
  }

  get right() {
    return this.categoryItem(
      settings.bottom_bar_right_category,
      settings.bottom_bar_right_icon,
      settings.bottom_bar_right_label
    );
  }

  get me() {
    const username = this.currentUser?.username;
    const viewing = this.router.currentRoute?.find?.(
      (route) => route.name === "user"
    )?.params?.username;
    return {
      label: settings.bottom_bar_me_label,
      icon: settings.bottom_bar_me_icon,
      url: username ? userPath(`${username}/summary`) : "/login",
      active:
        !!username &&
        !!viewing &&
        viewing.toLowerCase() === username.toLowerCase(),
    };
  }

  get centerIcon() {
    return settings.bottom_bar_center_icon;
  }

  categoryItem(categoryId, icon, label) {
    const category = Category.findById(parseInt(categoryId, 10));
    if (!category) {
      return null;
    }
    const current = this.currentCategory;
    const active =
      !!current &&
      (current.id === category.id ||
        current.parent_category_id === category.id);
    return { label, url: category.url, icon, active };
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
      this.composer.openNewTopic({ category, tags: tag?.id });
    }
  }

  <template>
    {{#if this.site.mobileView}}
      <nav aria-label="快捷导航" class="kuu-bottom-bar">
        <KuuBottomBarItem @item={{this.home}} />
        <KuuBottomBarItem @item={{this.left}} />

        <button
          aria-label="发帖"
          class="kuu-bottom-bar__plus"
          type="button"
          {{on "click" this.newTopic}}
        >
          {{dIcon this.centerIcon}}
        </button>

        <KuuBottomBarItem @item={{this.right}} />
        <KuuBottomBarItem @item={{this.me}} />
      </nav>
    {{/if}}
  </template>
}

export default apiInitializer((api) => {
  api.renderInOutlet("below-footer", KuuMobileBottomBar);
});
