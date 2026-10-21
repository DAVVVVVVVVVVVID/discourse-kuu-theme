import DiscourseRecommendedTheme from "@discourse/lint-configs/eslint-theme";

export default [
  ...DiscourseRecommendedTheme,
  // 原样拷贝的第三方库，不按我们的规则检查
  { ignores: ["javascripts/discourse/lib/vendor/**"] },
];
