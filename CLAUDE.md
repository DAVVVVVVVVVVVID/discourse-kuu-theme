# discourse-kuu-theme（给 Claude Code）

京圈（https://kyotooo.com ，京都大学学生的中文论坛，Discourse 自托管）的主题组件「KUU 自定义组件」。叠加在第三方主题 **FKB Pro** 上。负责人 David，用中文交流。

## 分工

- **这个仓库**：主题组件的开发（CSS、前端 JS、主题设置）。在 WSL 的 `~/discourse/plugins/discourse-kuu-theme` 里开发（和插件放在一起；没有 `plugin.rb`，Discourse 不会把它当插件加载），在这里开 Claude Code
- **KUU 运维项目**（David 的私有仓库 kuu-forum，另一个 Claude Code 会话）：写需求交接、审核 PR、上线、记改动记录。服务器、站点设置、插件部署都归那边
- **插件**各有自己的仓库（discourse-kuu-market、-ratings、-kyoto-email、-new-topic、-rewards），需要插件配合的地方写进 PR，由 KUU 协调
- 需求来源：Notion「京圈运营中心 › 开发计划」和这个仓库的 GitHub Issue

## 上线流程

1. 从 `main` 开分支，改完推上来，开 PR（关联 Issue）
2. **CI 必须通过**（`.github/workflows/discourse-theme.yml`：prettier、eslint、stylelint、类型检查，有测试时跑测试）
3. `main` 受保护：David 批准后合并
4. 合并后 David 在论坛后台「外观 → 组件 → KUU 自定义组件」点「更新」才上线（组件 ID 4，从这个仓库安装）。**合并不等于上线**
5. 上线后让 David 在 iPhone 和电脑上看；KUU 那边记 CHANGELOG

本地检查（提交前跑）：

```bash
pnpm install
pnpm lint          # 全部检查
pnpm lint:fix      # 自动修格式和能自动修的规则
```

## 本地预览

- Discourse 开发环境在 WSL 的 `~/discourse`（http://localhost:3000 ）。**容器、开发服务器、测试数据库、内存是几个会话共用的，先读 `~/.claude/CLAUDE.md` 的公共规则**：容器 / 开发服务器在跑就直接用，不停、不重启（不要 `d/shutdown_dev`）；测试用 `kuu-rspec`（主题用第 7 个测试库）；Playwright 截图用 `flock ~/discourse/tmp/kuu-heavy.lock` 排队
- 本地后台「外观 → 组件 → 安装 → 从 Git 仓库」装这个仓库，或者用官方 `discourse_theme watch .` 同步到本地开发环境（要本地的 API key）。**不要同步到线上论坛**
- 本地没有 FKB Pro 的话也要装上（https://github.com/VaperinaDEV/fkb-pro-theme ），很多样式要在 FKB Pro 下面才对
- 手机效果：浏览器开手机模拟，或者用开发容器里的 Playwright（`/src/node_modules/playwright`，`chromium.launch({ channel: "chromium" })`，`devices["iPhone 13"]`）截图
- **Playwright 用的是 Chromium，和 iPhone Safari 不一样**（见下面的坑），手机相关的改动最后要 David 用 iPhone 真机确认

## 规则

- **不改 FKB Pro 的代码**（第三方、没有许可证）。只在这里叠加样式，选择器要比 FKB Pro 的更具体
- 品牌配色（从 Logo 取样）：藏青 `$kuu-navy` `#0A2D56`、樱花粉 `$kuu-sakura` `#ED8690`、浅雾蓝 `#C0D1E4`、米白 `$kuu-cream` `#FCF9F2`（变量定义在 `common/common.scss` 开头）
- `common/common.scss` 每一段开头写注释：做什么、为什么、日期
- 能做成主题设置的（分类 ID、图标、文字）就做成 `settings.yml` 里的设置，David 在后台能改。**设置名里带 `_icon` 的，图标会被自动打包**；在 JS 里用全局的 `settings.xxx` 读
- 手机端专用的东西用 `site.mobileView` 判断（JS），或者 `html.mobile-view`（CSS）
- 不引入外部脚本和字体

## 现在有什么（2026-10-21）

| 文件 | 内容 |
|---|---|
| `common/common.scss` | 评分帖书签、顶部分类筛选和快捷按钮样式、卡片预览一行、隐藏新话题小蓝点、手机上插件表单全屏、手机底栏、手机分类标签、手机瀑布流 |
| `javascripts/discourse/api-initializers/quick-categories.gjs` | 「全部 ▾」右边的快捷分类按钮（只在电脑上；图标 + 文字，图标和底栏一致） |
| `javascripts/discourse/api-initializers/standalone-categories.gjs` | 二手市场、评分中心做成「独立页面」（设置 `standalone_category_ids`，子分类也算）：侧边栏「类别」里藏掉（按设置生成 CSS，按链接网址藏）、「全部 ▾」下拉里去掉（select-kit `replaceContent`）、侧边栏「话题」正下方加入口（`addCommunitySectionLink` + CSS `order`）；进去以后顶部只显示「‹ 首页」+ 标题（`after-breadcrumbs`，body 加 `kuu-standalone-page`），电脑保留发帖按钮 |
| `javascripts/discourse/lib/kuu-standalone.js` | 哪些分类是独立页面、它们的图标（底栏左右两个分类用底栏的图标） |
| `javascripts/discourse/api-initializers/mobile-bottom-bar.gjs` | 手机底栏：首页、二手、中间「+」发帖、评分、我的；代替 FKB Pro 列表页的悬浮按钮 |
| `javascripts/discourse/api-initializers/mobile-category-tabs.gjs` | 手机顶部分类标签（代替「全部 ▾」下拉框），挂 `after-breadcrumbs` |
| `javascripts/discourse/api-initializers/mobile-waterfall.gjs` | 手机两列瀑布流，挂 `before-topic-list`；同一个列表的 core 表格加 `.kuu-waterfall-source` 类名后由 CSS 藏起来 |
| `javascripts/discourse/components/kuu-waterfall-card.gjs` | 瀑布流卡片（封面、标题、作者、第一楼的赞；文字封面的卡片下面是正文开头 `excerpt` 而不是标题；二手价格状态；评分 / 置顶角标） |
| `javascripts/discourse/lib/kuu-waterfall.js` | 哪些列表用瀑布流、封面选择（文字封面模板以后在 `textCoverFor` 里扩展）、分列高度估算 |
| `javascripts/discourse/api-initializers/post-share-menu.gjs` | 帖子菜单：每一楼的「复制链接」按钮换成分享下拉菜单、回复按钮换图标（`post-menu-buttons` transformer） |
| `javascripts/discourse/api-initializers/user-menu-profile-tab.gjs` | 点头像默认打开「个人资料」栏：core 写死默认是通知，在 `user-menu-tabs-list__after` 放一个空组件，渲染结束时点一下个人资料栏 |
| `javascripts/discourse/api-initializers/open-topic-from-top.js` | 从列表点进帖子一律从第一楼开始：`registerCustomLastUnreadUrlCallback` 让 `lastUnreadUrl` 返回不带楼号的链接（core 和插件的列表链接都用它）。通知等指向某一楼的链接不受影响 |
| `javascripts/discourse/api-initializers/topic-footer-share.js` | 话题最底部的「分享」换成分享菜单（所有话题）：core 的 `share-and-invite` 由 CSS 藏起来，注册同优先级的新按钮，点击用 `menu` 服务弹出菜单。core 分享窗口里的「邀请」随之去掉 |
| `javascripts/discourse/components/kuu-share-menu.gjs` | 帖子菜单里的分享按钮（DMenu） |
| `javascripts/discourse/components/kuu-share-menu-content.gjs` | 分享菜单的内容：复制链接、保存分享图（只在公开帖子）。帖子菜单和话题底部共用 |
| `javascripts/discourse/components/kuu-share-image-modal.gjs` | 「保存分享图」弹窗：生成、显示（data URL，微信里能长按）、电脑下载、Web Share |
| `javascripts/discourse/lib/kuu-share-image.js` | 分享图的 canvas 画法（1080×1440，三种样式，照 David 确认的参考图 `D:\PROJECT\KUU\brand\share\`）、中文换行 |
| `javascripts/discourse/lib/kuu-share-data.js` | 分享图的数据：帖子、二手 `kuu_market_listing`、评分 `/kuu-ratings/boards/:id/items?sort=score`；图片都 fetch 成 blob 再画 |
| `javascripts/discourse/lib/vendor/qrcode-generator.js` | 第三方二维码库（MIT），原样拷贝，eslint / prettier 跳过 |
| `settings.yml` | `standalone_category_ids`、`quick_category_ids`、`bottom_bar_*`、`category_tabs_hidden_ids`、`waterfall_excluded_category_ids`、`text_cover_*`、`post_share_icon`、`post_reply_icon`、`share_image_*` |
| `about.json` | modifier `topic_thumbnail_sizes: [[600, 1200]]`：列表数据里才有图片宽高和小缩略图（瀑布流按原图比例要用）；`serialize_topic_excerpts`：列表里带摘要（FKB Pro 也开了，这里再开一次，不依赖它） |

和插件的配合：
- 底栏的「+」调用 `discourse-kuu-new-topic` 插件的 `service:kuu-new-topic` 的 `openNewTopic({ category, tag })`，没有时退回 `composer.openNewTopic`
- 二手帖在列表里的商品卡片由 `discourse-kuu-market` 插件画；评分主题的卡片由 `discourse-kuu-ratings` 插件画（开发中）
- 手机瀑布流在混合列表里读插件放进列表的字段：二手 `kuu_market_card`（`item_name`、`price`、`free`、`has_photos`）和 `kuu_market_status`，评分 `kuu_rating_board_card.items[0].image_url`（没有时用评分插件的 `kuu_ratings_placeholder_image`）；状态文字用二手插件的 `kuu_market.card_statuses.*`。插件改了这些字段要同步改 `lib/kuu-waterfall.js` 和 `kuu-waterfall-card.gjs`
- 注册等待页的激活码、倒计时由 `discourse-kuu-kyoto-email` 插件负责，这里不管

## 踩过的坑

- **`--d-default-border-radius` 在 FKB Pro 里是 `1em`**，字号大的地方会算出很大的圆角（手机上 88px 的图片变成圆形）。需要小圆角时写固定值（比如 8px）
- **iPhone Safari：flex 容器里的 `<img>` 只靠 `width/height: 100%` 撑满时，会按原图尺寸摆放**，方框里只露出照片一角。图片要 `position: absolute; inset: 0; object-fit: cover`
- **`htmlSafe` 已经过时**，用 `trustHTML`（`@ember/template`），不然后台会出现过时写法的提醒
- **core `composer.openNewTopic({ tags })` 的 `tags` 要逗号分隔的字符串**，传数组时普通用户（非管理员）会报 `reading 'filter'`，编辑器打不开。用管理员测不出来，**涉及发帖的改动要用普通用户测**
- FKB Pro 手机端：列表页的悬浮按钮是 `.list-controls .navigation-container .navigation-controls`（新建话题、铃铛）和 `#navigation-bar`（最新 / 新 / 热门），现在被底栏 CSS 隐藏
- 加到桌面（PWA）后 core 会显示自己的「返回 / 前进」底栏（`html.footer-nav-visible`、`--footer-nav-height`），手机底栏要放在它上面
- 替换 CSS 时注意文件里可能有**几处一模一样的写法**，改之前确认改的是哪一处
- FKB Pro 手机版给「全部 ▾」下拉写了 `display: flex !important`，选择器优先级是 (0,6,1)。要藏它，选择器路径里写全 `.list-controls .container .navigation-container`，再重复写一次类名
- core 的「新建话题」按钮 `#create-topic` 外面包着一层组合按钮 `d-combo-button`，藏 `.navigation-controls` 里其他按钮时要留下包着它的那一层（`:has(#create-topic)`）
- **WSL 里没有 Linux 版 node / pnpm**，检查在开发容器里跑：`docker exec -u discourse discourse_dev bash -lc 'cd /src/plugins/discourse-kuu-theme && pnpm install && pnpm lint'`
- 本地把组件更新到开发环境（本地组件 ID 2）：`d/rails runner 'RemoteTheme.import_theme_from_directory("/src/plugins/discourse-kuu-theme", theme_id: 2)'`（会跳过 node_modules）。**本地分类 ID 和线上不一样**（本地二手 7、评分 5、评分对象 6），本地的主题设置要改成本地 ID。改了 CSS 后页面还是旧样式时，是开发服务器缓存了旧样式表（工作进程收不到清缓存的通知）。**不用重启**：`~/discourse/tmp/discourse-kuu-theme/theme-css.sh` 输出刚导入的样式表地址，Playwright 脚本里用 `page.route` 把 `/stylesheets/common_theme_2_*.css` 的请求改到这个地址（`unread-banner.mjs` 里有写法）。真要重启按 `~/.claude/CLAUDE.md` 用排队锁，并在回复里说明
- （只在开发服务器没在跑时才启动）`d/dev` 要 TTY，后台跑用 `docker exec -u discourse:discourse -w /src discourse_dev bin/dev`
- Playwright 截图不能 `waitUntil: "networkidle"`（Discourse 的长轮询一直不停），等页面元素出现（比如 `.kuu-waterfall`）
- 本地用别的身份测（普通用户、管理员）：启动 `bin/dev` 时加 `-e DISCOURSE_DEV_ALLOW_ANON_TO_IMPERSONATE=1`，然后打开 `/session/用户名/become`
- 不要 `pkill -f` / `kill` 别的会话的进程（`pkill -f bin/dev` 还会把执行它的 shell 自己也匹配上）。前端构建进程 `rolldown.mjs` 被强行停掉后，下次启动会报「already running」
- canvas 只能导出没被「污染」的图：画进分享图的图片都要先 `fetch` 成 blob（`kuu-share-data.js` 的 `loadImage`），外链图读不到就当没有图
- 分享图二维码的检查：`~/discourse/tmp/discourse-kuu-theme/` 里的 qr-check.mjs 用 jsQR 在浏览器里识别（验收标准：整张图缩到 540px 宽、再压成质量 50 的 JPEG 能识别，Issue #16），但**微信实机扫码只能 David 测**
- WSL 内存小（约 5GB），开发服务器、Playwright、别的会话跑的 rspec 同时跑会把容器拖垮（`can't alloc thread`）。截图脚本、测试脚本放在 `~/discourse/tmp/discourse-kuu-theme/`（容器里 `/src/tmp/discourse-kuu-theme/`），跑之前看 `free -m`，用 `flock` 排队；脚本崩了只清理自己启动的 chrome 进程
- 开发库是共用的：为测试改了站点设置、用户设置，测完改回来，在回复里写明
- 站点的 CSP 没有限制 `frame-src`；B 站嵌入播放器在手机上显示「视频失效」（2026-10-20 试过 5 种写法都不行），别再走这条路
