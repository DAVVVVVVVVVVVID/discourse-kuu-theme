// 分享成功后报告给经验值 / 鲸币插件（discourse-kuu-points）的「转发」每日任务（2026-10-22，Issue #32）。
// POST /kuu-points/tasks/share.json：每天只奖励一次，rewarded 为 true 时提示拿到的经验和鲸币。
// 插件没装或关着时接口 404，网络错误也一样：一律悄悄忽略，不影响原来的复制 / 分享提示。
// 同一个页面里当天已经请求过（奖励过 / 今天已经领过 / 404）就不再请求；页面开着过了零点会再请求一次
import { ajax } from "discourse/lib/ajax";

let requestedOn = null;

export async function reportShare({ currentUser, toasts }) {
  const today = new Date().toDateString();
  if (!currentUser || requestedOn === today) {
    return;
  }
  requestedOn = today;
  try {
    const result = await ajax("/kuu-points/tasks/share.json", {
      type: "POST",
    });
    if (result?.rewarded) {
      toasts.success({
        duration: "short",
        data: {
          message: `转发 +${result.xp} 经验 +${result.coins} 鲸币`,
        },
      });
    }
  } catch {
    // 插件没装 / 关着（404）或网络错误：忽略
  }
}
