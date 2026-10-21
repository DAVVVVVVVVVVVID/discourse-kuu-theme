// 帖子菜单里的分享按钮 + 下拉菜单（Issue #12）。菜单内容在 kuu-share-menu-content.gjs，和话题底部的「分享」共用。
// - @topic：要生成分享图的话题；@url：复制的链接（这一楼的链接）
// - @triggerClass：按钮的类名
import { hash } from "@ember/helper";
import DMenu from "discourse/float-kit/components/d-menu";
import KuuShareMenuContent from "./kuu-share-menu-content.gjs";

const KuuShareMenu = <template>
  <DMenu
    ...attributes
    @ariaLabel="分享"
    @component={{KuuShareMenuContent}}
    @data={{hash topic=@topic url=@url}}
    @icon={{settings.post_share_icon}}
    @identifier="kuu-share-menu"
    @modalForMobile={{true}}
    @title="分享"
    @triggerClass="kuu-share-menu {{@triggerClass}}"
  />
</template>;

export default KuuShareMenu;
