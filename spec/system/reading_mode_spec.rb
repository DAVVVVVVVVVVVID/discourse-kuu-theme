# frozen_string_literal: true

RSpec.describe "KUU reading mode" do
  let(:directory) { File.expand_path("../..", __dir__) }
  let!(:parent_theme) do
    if ENV["KUU_TEST_THEME_PATH"]
      theme = RemoteTheme.import_theme_from_directory(ENV.fetch("KUU_TEST_THEME_PATH"))
      theme.set_default!
      theme
    else
      Theme.find_default
    end
  end
  let!(:palette_pack) do
    RemoteTheme.import_theme_from_directory(File.join(directory, "extras/reading-mode-palettes"))
  end
  let!(:eye_palette) { palette_pack.color_schemes.find_by!(name: "KUU Eye Comfort") }
  let!(:night_palette) { palette_pack.color_schemes.find_by!(name: "KUU Night") }
  let!(:component) do
    theme = RemoteTheme.import_theme_from_directory(directory)
    theme.update_setting(:eye_comfort_palette_id, eye_palette.id)
    theme.update_setting(:reading_mode_enabled, true)
    theme.save!
    Theme.find_default.child_themes << theme
    theme
  end

  before do
    palette_pack.color_schemes.each { |scheme| scheme.update!(user_selectable: true) }
    Theme.find_default.update!(dark_color_scheme_id: night_palette.id)
    SiteSetting.default_locale = "zh_CN"
    SiteSetting.interface_color_selector = "header"
    Theme.clear_cache!
    # 配色是测试夹具；预先编译，避免首次编译 FKB SCSS 超过浏览器的请求等待时限。
    Stylesheet::Manager.new(theme_id: parent_theme.id).color_scheme_stylesheet_details(
      eye_palette.id,
    )
  end

  def choose(mode)
    unless page.has_css?(".kuu-reading-mode__menu", wait: 0)
      find(".kuu-reading-mode__trigger").click
    end
    find(".kuu-reading-mode__option[data-mode='#{mode}']").click
    expect(page).to have_no_css(".kuu-reading-mode__menu[aria-busy='true']")
  end

  def expect_mode(mode)
    expect(page).to have_css(".kuu-reading-mode[data-mode='#{mode}']")
  end

  def secondary_color
    page.evaluate_script(
      "getComputedStyle(document.documentElement).getPropertyValue('--secondary').trim().toLowerCase()",
    )
  end

  def stored_cookie(name)
    page.driver.with_playwright_page do |browser|
      return browser.context.cookies.find { |item| item["name"] == name }&.fetch("value")
    end
  end

  def capture_mode(mode)
    return unless ENV["KUU_SCREENSHOTS_DIR"]
    directory = ENV.fetch("KUU_SCREENSHOTS_DIR")
    FileUtils.mkdir_p(directory)
    device = RSpec.current_example.metadata[:mobile] ? "mobile" : "desktop"
    find(".kuu-reading-mode__trigger").click
    expect(page).to have_css(".kuu-reading-mode__menu")
    page.driver.with_playwright_page do |browser|
      browser.screenshot(path: File.join(directory, "#{device}-#{mode}.png"))
    end
    page.send_keys(:escape)
  end

  shared_examples "reading mode switching" do
    it "switches instantly, remembers refreshes and restores the original day palette" do
      visit("/latest")
      original_color = secondary_color
      original_background = page.evaluate_script("getComputedStyle(document.body).backgroundColor")
      choose("eye")
      expect_mode("eye")
      expect(secondary_color).to eq("#e8f1e5")
      expect(page).to have_no_css(".kuu-reading-mode__menu")
      expect(page).to have_no_css(".header-color-scheme-toggle")
      if ENV["KUU_TEST_THEME_PATH"]
        expect(page.evaluate_script("getComputedStyle(document.body).backgroundColor")).not_to eq(
          original_background,
        )
      end
      capture_mode("eye")

      visit("/latest")
      expect_mode("eye")
      expect(secondary_color).to eq("#e8f1e5")

      choose("night")
      expect_mode("night")
      expect(secondary_color).to eq("#1c222b")
      capture_mode("night")
      visit("/latest")
      expect_mode("night")
      expect(secondary_color).to eq("#1c222b")

      choose("day")
      expect_mode("day")
      expect(secondary_color).to eq(original_color)
      expect(page.evaluate_script("getComputedStyle(document.body).backgroundColor")).to eq(
        original_background,
      )
      visit("/latest")
      expect_mode("day")
      expect(secondary_color).to eq(original_color)
      expect(stored_cookie("kuu_reading_original_light")).to be_nil
      expect(
        page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"),
      ).to eq(true)
    end

    it "retains the current colors when the palette request fails, then allows retry" do
      visit("/latest")
      original_color = secondary_color
      pattern = %r{/color-scheme-stylesheet/#{eye_palette.id}/}
      page.driver.with_playwright_page do |browser|
        browser.route(
          pattern,
          ->(route, _) { route.fulfill(status: 503, body: "{}", contentType: "application/json") },
        )
        choose("eye")
        expect(page).to have_css(".kuu-reading-mode__error", text: "切换失败")
        expect_mode("day")
        expect(secondary_color).to eq(original_color)
        expect(stored_cookie("kuu_reading_original_light")).to be_nil
        browser.unroute(pattern)
      end
      choose("eye")
      expect_mode("eye")
      expect(secondary_color).to eq("#e8f1e5")
    end
  end

  context "when using desktop" do
    include_examples "reading mode switching"
  end

  context "when using mobile", mobile: true do
    include_examples "reading mode switching"
  end

  it "preserves a signed-in user's custom day palette without updating account preferences" do
    original = ColorScheme.find_by!(name: "Solarized Light")
    user = Fabricate(:user)
    user.user_option.update!(color_scheme_id: original.id)
    sign_in(user)
    visit("/latest")
    original_color = secondary_color
    choose("night")
    expect_mode("night")
    choose("eye")
    expect_mode("eye")
    visit("/latest")
    choose("day")
    expect_mode("day")
    expect(secondary_color).to eq(original_color)
    visit("/latest")
    expect(secondary_color).to eq(original_color)
    expect(user.user_option.reload.color_scheme_id).to eq(original.id)
    expect(stored_cookie("color_scheme_id")).to be_nil
  end

  it "keeps eye comfort and its backup if restoring the day stylesheet fails" do
    visit("/latest")
    original_id = find("link.light-scheme", visible: :all)["data-scheme-id"] || -1
    choose("eye")
    expect_mode("eye")
    backup = stored_cookie("kuu_reading_original_light")
    pattern = %r{/color-scheme-stylesheet/#{original_id}/}
    page.driver.with_playwright_page do |browser|
      browser.route(
        pattern,
        ->(route, _) { route.fulfill(status: 503, body: "{}", contentType: "application/json") },
      )
      choose("day")
      expect(page).to have_css(".kuu-reading-mode__error")
      expect_mode("eye")
      expect(secondary_color).to eq("#e8f1e5")
      expect(stored_cookie("kuu_reading_original_light")).to eq(backup)
      browser.unroute(pattern)
    end
    choose("day")
    expect_mode("day")
  end

  it "keeps the original colors if the new stylesheet cannot load" do
    visit("/latest")
    original_color = secondary_color
    pattern = %r{/stylesheets/color_definitions_}
    page.driver.with_playwright_page do |browser|
      browser.route(pattern, ->(route, _) { route.abort })
      choose("eye")
      expect(page).to have_css(".kuu-reading-mode__error")
      expect_mode("day")
      expect(secondary_color).to eq(original_color)
      expect(page).to have_css("link.light-scheme", count: 1, visible: false)
      browser.unroute(pattern)
    end
  end

  it "disables unavailable modes instead of applying a broken palette" do
    component.update_setting(:eye_comfort_palette_id, 0)
    component.save!
    Theme.find_default.update!(dark_color_scheme_id: nil)
    visit("/latest")
    find(".kuu-reading-mode__trigger").click
    expect(page).to have_css(".kuu-reading-mode__option[data-mode='eye'][disabled]")
    expect(page).to have_css(".kuu-reading-mode__option[data-mode='night'][disabled]")
  end

  it "supports keyboard opening, selection and dismissal" do
    visit("/latest")
    find(".kuu-reading-mode__trigger").send_keys(:enter)
    expect(page).to have_css(".kuu-reading-mode__menu")
    find(".kuu-reading-mode__option[data-mode='day']").send_keys(:down)
    expect(page.evaluate_script("document.activeElement.dataset.mode")).to eq("eye")
    find(".kuu-reading-mode__option[data-mode='eye']").send_keys(:enter)
    expect_mode("eye")
    expect(page).to have_no_css(".kuu-reading-mode__menu")
    find(".kuu-reading-mode__trigger").send_keys(:enter)
    expect(page).to have_css("[role='menuitemradio'][aria-checked='true'][data-mode='eye']")
    page.send_keys(:escape)
    expect(page).to have_no_css(".kuu-reading-mode__menu")
  end

  it "keeps the native selector when the reading mode setting is disabled" do
    component.update_setting(:reading_mode_enabled, false)
    component.save!
    visit("/latest")
    expect(page).to have_no_css(".kuu-reading-mode")
    expect(page).to have_css(".header-color-scheme-toggle")
  end
end
