// 点右上角头像，默认打开「个人资料」那一栏，不是「通知」（2026-10-22，Issue #25）
// core 的用户菜单（components/user-menu/menu.gjs）把默认栏写死成 all-notifications，没有设置或 transformer，
// modifyClass 也改不了构造函数和字段初始值。所以在菜单里的 user-menu-tabs-list__after 挂载点放一个
// 不显示内容的组件：菜单每次打开都会重新渲染它，渲染结束时点一下「个人资料」栏（和用户自己点一样走 core 的切换逻辑）。
// 在同一轮渲染里切换，屏幕上不会先闪一下通知。其他栏照常能切换
import Component from "@glimmer/component";
import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";

class KuuOpenProfileTab extends Component {
  constructor() {
    super(...arguments);
    schedule("afterRender", () => {
      document.getElementById("user-menu-button-profile")?.click();
    });
  }

  <template></template>
}

export default apiInitializer((api) => {
  api.renderInOutlet("user-menu-tabs-list__after", KuuOpenProfileTab);
});
