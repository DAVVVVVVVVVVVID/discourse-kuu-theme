// 「独立页面」分类（2026-10-22，Issue #20）：二手市场、评分中心不再当普通分类，侧边栏有专门入口、
// 进去以后顶部只显示「‹ 首页」和标题。哪些分类是独立页面由主题设置 standalone_category_ids 决定，
// 它们的子分类（比如评分对象）也算
import Category from "discourse/models/category";

export function standaloneCategoryIds() {
  return (settings.standalone_category_ids || "")
    .split("|")
    .map((id) => parseInt(id, 10))
    .filter(Boolean);
}

// 设置里的分类和它们的子分类
export function standaloneCategoryIdsWithChildren(site) {
  const ids = standaloneCategoryIds();
  const children = (site.categories || [])
    .filter((category) => ids.includes(category.parent_category_id))
    .map((category) => category.id);
  return [...ids, ...children];
}

export function isStandaloneCategory(category) {
  if (!category) {
    return false;
  }
  const ids = standaloneCategoryIds();
  return ids.includes(category.id) || ids.includes(category.parent_category_id);
}

// 图标和手机底栏一致：底栏左右两个分类用底栏的图标，其他独立页面分类用文件夹
export function standaloneIcon(categoryId) {
  if (categoryId === parseInt(settings.bottom_bar_left_category, 10)) {
    return settings.bottom_bar_left_icon;
  }
  if (categoryId === parseInt(settings.bottom_bar_right_category, 10)) {
    return settings.bottom_bar_right_icon;
  }
  return "folder";
}

export function standaloneCategories() {
  return standaloneCategoryIds()
    .map((id) => Category.findById(id))
    .filter(Boolean);
}
