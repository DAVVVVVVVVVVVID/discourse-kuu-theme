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

- Discourse 开发环境在 WSL 的 `~/discourse`（`d/boot_dev`、`d/dev`，http://localhost:3000 ），用完 `d/shutdown_dev`
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
| `javascripts/discourse/api-initializers/quick-categories.gjs` | 「全部 ▾」右边的快捷分类按钮（只在电脑上） |
| `javascripts/discourse/api-initializers/mobile-bottom-bar.gjs` | 手机底栏：首页、二手、中间「+」发帖、评分、我的；代替 FKB Pro 列表页的悬浮按钮 |
| `javascripts/discourse/api-initializers/mobile-category-tabs.gjs` | 手机顶部分类标签（代替「全部 ▾」下拉框），挂 `after-breadcrumbs` |
| `javascripts/discourse/api-initializers/mobile-waterfall.gjs` | 手机两列瀑布流，挂 `before-topic-list`；同一个列表的 core 表格加 `.kuu-waterfall-source` 类名后由 CSS 藏起来 |
| `javascripts/discourse/components/kuu-waterfall-card.gjs` | 瀑布流卡片（封面、标题、作者、第一楼的赞；二手价格状态；评分 / 置顶角标） |
| `javascripts/discourse/lib/kuu-waterfall.js` | 哪些列表用瀑布流、封面选择（文字封面模板以后在 `textCoverFor` 里扩展）、分列高度估算 |
| `settings.yml` | `quick_category_ids`、`bottom_bar_*`、`category_tabs_hidden_ids`、`waterfall_excluded_category_ids`、`text_cover_*` |
| `about.json` | modifier `topic_thumbnail_sizes: [[600, 1200]]`：列表数据里才有图片宽高和小缩略图（瀑布流按原图比例要用） |

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
- **WSL 里没有 Linux 版 node / pnpm**，检查在开发容器里跑：`docker exec -u discourse discourse_dev bash -lc 'cd /src/plugins/discourse-kuu-theme && pnpm install && pnpm lint'`
- 本地把组件更新到开发环境（本地组件 ID 2）：`d/rails runner 'RemoteTheme.import_theme_from_directory("/src/plugins/discourse-kuu-theme", theme_id: 2)'`（会跳过 node_modules）。**本地分类 ID 和线上不一样**（本地二手 7、评分 5），本地的主题设置要改成本地 ID。改了 CSS 后如果页面还是旧样式，重启 `d/dev`
- `d/dev` 要 TTY，后台跑用 `docker exec -u discourse:discourse -w /src discourse_dev bin/dev`
- Playwright 截图不能 `waitUntil: "networkidle"`（Discourse 的长轮询一直不停），等页面元素出现（比如 `.kuu-waterfall`）
- WSL 内存小（约 5GB），开发服务器、Playwright、别的会话跑的 rspec 同时跑会把容器拖垮（`can't alloc thread`），截图脚本崩了要清掉残留的 chrome 进程
- 站点的 CSP 没有限制 `frame-src`；B 站嵌入播放器在手机上显示「视频失效」（2026-10-20 试过 5 种写法都不行），别再走这条路
