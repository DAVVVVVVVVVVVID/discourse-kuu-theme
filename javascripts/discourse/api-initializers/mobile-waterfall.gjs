// 手机端帖子列表改成两列瀑布流（2026-10-21，Issue #9）
// - 数据、置顶顺序、加载更多都沿用 core：卡片直接读 core 正在显示的列表（discovery.currentTopicList），
//   core 的 DLoadMore 哨兵还在原来的表格后面，滑到底照常加载，新帖子 push 进同一个数组
// - 挂在 core discovery/topics.gjs 的 before-topic-list 挂载点；同一个列表的 core 表格用
//   topic-list-class transformer 加类名，由 CSS 在手机上藏起来
// - 分列：每张卡片放进当前较矮的一列。高度按数据估算（lib/kuu-waterfall.js），不量 DOM，
//   这样加载更多时前面的卡片不会换列。不用 CSS column-count：那是按列从上到下排，加载更多会乱
// - 「二手市场」「评分中心」分类页不用瀑布流（主题设置 waterfall_excluded_category_ids），
//   保留插件画的卡片；电脑端完全不变
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import { apiInitializer } from "discourse/lib/api";
import KuuWaterfallCard from "../components/kuu-waterfall-card.gjs";
import {
  coverFor,
  estimateCardHeight,
  waterfallActive,
} from "../lib/kuu-waterfall.js";

// 和 common.scss 里 .kuu-waterfall 的间距一致
const GAP = 8;

function showsWaterfall({ site, discovery }, category, topics) {
  return (
    site.mobileView &&
    !!topics &&
    discovery.currentTopicList?.topics === topics &&
    waterfallActive(category)
  );
}

class KuuWaterfall extends Component {
  @service site;
  @service siteSettings;
  @service discovery;

  get topics() {
    return this.discovery.currentTopicList?.topics;
  }

  get show() {
    return (
      showsWaterfall(
        { site: this.site, discovery: this.discovery },
        this.args.outletArgs.category,
        this.topics
      ) && this.topics.length > 0
    );
  }

  @cached
  get columns() {
    const cardWidth = (Math.min(window.innerWidth, 600) - GAP * 3) / 2;
    const columns = [
      { items: [], height: 0 },
      { items: [], height: 0 },
    ];

    for (const topic of this.topics) {
      const cover = coverFor(topic, this.siteSettings);
      const column =
        columns[0].height <= columns[1].height ? columns[0] : columns[1];
      column.items.push({ topic, cover });
      column.height += estimateCardHeight(topic, cover.ratio, cardWidth) + GAP;
    }

    return columns;
  }

  <template>
    {{#if this.show}}
      <div class="kuu-waterfall">
        {{#each this.columns as |column|}}
          <div class="kuu-waterfall__column">
            {{#each column.items key="topic.id" as |item|}}
              <KuuWaterfallCard @item={{item}} />
            {{/each}}
          </div>
        {{/each}}
      </div>
    {{/if}}
  </template>
}

export default apiInitializer((api) => {
  const services = {
    site: api.container.lookup("service:site"),
    discovery: api.container.lookup("service:discovery"),
  };

  api.renderInOutlet("before-topic-list", KuuWaterfall);

  api.registerValueTransformer("topic-list-class", ({ value, context }) =>
    context.listContext === "discovery" &&
    showsWaterfall(services, context.category, context.topics)
      ? [...value, "kuu-waterfall-source"]
      : value
  );
});
