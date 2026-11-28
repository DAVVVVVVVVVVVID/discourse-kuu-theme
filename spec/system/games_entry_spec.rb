# frozen_string_literal: true

RSpec.describe "KUU games entry" do
  let!(:parent_theme) do
    if ENV["KUU_TEST_THEME_PATH"]
      theme = RemoteTheme.import_theme_from_directory(ENV.fetch("KUU_TEST_THEME_PATH"))
      theme.set_default!
      theme
    else
      Theme.find_default
    end
  end
  let!(:component) do
    theme = RemoteTheme.import_theme_from_directory(File.expand_path("../..", __dir__))
    Theme.find_default.child_themes << theme
    theme
  end
  let(:entry) { "a.sidebar-section-link[data-link-name='kuu-games']" }

  before do
    SiteSetting.navigation_menu = "sidebar"
    SiteSetting.default_locale = "zh_CN"
  end

  def configure_entry(enabled:, url:)
    component.update_setting(:games_enabled, enabled)
    component.update_setting(:games_url, url)
    component.save!
    Theme.clear_cache!
  end

  it "keeps the entry hidden by default" do
    visit("/latest")
    expect(page).to have_no_css(entry, visible: :all)
  end

  it "hides an enabled entry when the URL is empty, invalid or unsafe" do
    ["", "not a url", "http://example.com/game", "javascript:alert(1)", "https://name:secret@example.com/"].each do |url|
      configure_entry(enabled: true, url:)
      visit("/latest")
      expect(page).to have_no_css(entry, visible: :all)
    end
  end

  shared_examples "a public game link" do
    it "shows the configured HTTPS destination for visitors" do
      configure_entry(enabled: true, url: "https://example.com/kyoto-daily/")
      component.update_setting(:games_label, "京都一景")
      component.save!
      visit("/latest")
      click_button("toggle-hamburger-menu") if RSpec.current_example.metadata[:mobile]
      expect(page).to have_css("#{entry}[href='https://example.com/kyoto-daily/']", text: "京都一景")
      expect(find(entry)[:rel]).to include("noopener")
      expect(find(entry)[:class]).not_to include("active")
      if ENV["KUU_SCREENSHOTS_DIR"]
        directory = ENV.fetch("KUU_SCREENSHOTS_DIR")
        FileUtils.mkdir_p(directory)
        device = RSpec.current_example.metadata[:mobile] ? "mobile" : "desktop"
        page.driver.with_playwright_page do |browser|
          browser.screenshot(path: File.join(directory, "games-entry-#{device}.jpg"))
        end
      end
    end
  end

  context "when browsing on desktop" do
    include_examples "a public game link"
  end

  context "when browsing on mobile", mobile: true do
    include_examples "a public game link"
  end
end
