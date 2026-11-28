# 独立小游戏入口

这个改动只负责论坛入口。游戏源码见 [京都一景 Draft PR #1](https://github.com/HanSuiki/kyotooo-games/pull/1)，不将游戏脚本或照片加载进论坛页面。

## 配置

默认 `games_enabled: false`、`games_url: ""`，更新组件后不会立即显示入口。

游戏公开部署完成后，在主题组件设置中填写：

- `games_url`：所有论坛用户和访客均可直接打开的正式 HTTPS 地址；
- `games_label`：入口文字，默认「小游戏」；
- `games_icon`：图标，默认 `gamepad`；
- `games_enabled`：最后打开开关。

空地址、无效地址、非 HTTPS 地址、包含账号密码的地址都不会显示入口。不要填写仅个人能访问的 ChatGPT 试玩链接。

入口出现在电脑侧栏和手机展开后的社区菜单中。使用 Discourse 原生外链行为，是否新标签页打开遵循用户自己的设置；不占用手机现有的五个底栏按钮。

## 审核与上线

1. 游戏源码 PR 与本主题 PR 分开审核。
2. 部署游戏，确认真实公开地址可用。
3. David 合并主题 PR 后，在论坛后台更新组件。
4. 填写正式地址并启用，分别以访客和普通用户检查电脑侧栏、手机菜单及返回论坛。

关闭 `games_enabled` 即可移除入口。游戏服务与论坛组件可分别更新。

## 本地验证截图

在 FKB Pro 下验证，示例地址为测试保留域名，不会访问或修改线上论坛。

[电脑侧栏](games-entry-desktop.jpg) · [手机社区菜单](games-entry-mobile.jpg)
