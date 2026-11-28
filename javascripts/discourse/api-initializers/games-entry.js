// 独立小游戏入口（2026-11-28）：正式地址由管理员配置，默认关闭。
// 复用原生社区菜单，使电脑侧栏和手机菜单共用入口与外链打开偏好。
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  if (!settings.games_enabled) {
    return;
  }

  let url;
  try {
    url = new URL(settings.games_url.trim());
  } catch {
    return;
  }

  if (url.protocol !== "https:" || url.username || url.password) {
    return;
  }

  api.addCommunitySectionLink((BaseCommunitySectionLink) => {
    return class extends BaseCommunitySectionLink {
      get name() {
        return "kuu-games";
      }

      get href() {
        return url.href;
      }

      get currentWhen() {
        return false;
      }

      get title() {
        return settings.games_label;
      }

      get text() {
        return settings.games_label;
      }

      get prefixValue() {
        return settings.games_icon;
      }
    };
  });
});
