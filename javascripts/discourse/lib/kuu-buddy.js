// 搭子帖（discourse-kuu-buddy）在瀑布流卡片和分享图里共用的逻辑（2026-10-26，Issue #37）
import { i18n } from "discourse-i18n";

// 状态：recruiting / started / started_full（人满自动开始）/ ended / expired
export function buddyStatusKey(status, startReason) {
  return status === "started" && startReason === "full"
    ? "started_full"
    : status;
}

// 和搭子插件 kuu_buddy.card_statuses 一样；插件的翻译拿不到时（比如插件关着）用这里的
const FALLBACK_LABELS = {
  recruiting: "招募中",
  started: "活动开始",
  started_full: "人满·活动开始",
  ended: "已结束",
  expired: "已过期",
};

// 文字用搭子插件的列表卡片短文案
export function buddyStatusLabel(key) {
  const label = i18n(`kuu_buddy.card_statuses.${key}`);
  return label.startsWith("[") ? FALLBACK_LABELS[key] || key : label;
}

// 成员头像叠放：发起人在最前，后面按加入顺序；招募中时在后面画虚线空位。
// 圆一共最多 maxCircles 个，多出来的不画。返回 { avatars, empties, spotsLeft, full }
export function buddySeats({
  members,
  memberCount,
  capacity,
  status,
  maxCircles,
}) {
  const avatars = (members || []).slice(0, maxCircles);
  const spotsLeft = Math.max(capacity - memberCount, 0);
  const empties =
    status === "recruiting"
      ? Math.min(spotsLeft, maxCircles - avatars.length)
      : 0;
  return {
    avatars,
    empties: Math.max(empties, 0),
    spotsLeft,
    full: memberCount >= capacity,
  };
}
