import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { apiInitializer } from "discourse/lib/api";
import { updateColorSchemeCookie } from "discourse/lib/color-scheme-picker";
import cookie, { removeCookie } from "discourse/lib/cookie";
import { currentThemeId } from "discourse/lib/theme-selector";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const BACKUP_COOKIE = "kuu_reading_original_light";
const MODES = ["day", "eye", "night"];
const ICONS = { day: "sun", eye: "leaf", night: "moon" };

class ReadingMode extends Component {
  @service interfaceColor;

  @tracked lightPaletteId = Number(
    document.querySelector("link.light-scheme")?.dataset.schemeId || -1
  );
  @tracked busy = false;
  @tracked error = false;

  get mode() {
    if (this.interfaceColor.darkModeActive) {
      return "night";
    }
    return this.lightPaletteId === settings.eye_comfort_palette_id
      ? "eye"
      : "day";
  }

  get modeIcon() {
    return ICONS[this.mode];
  }

  get currentLabel() {
    return i18n(themePrefix("reading_mode.current"), {
      mode: i18n(themePrefix(`reading_mode.${this.mode}`)),
    });
  }

  get options() {
    return MODES.map((mode) => {
      const unavailable =
        !this.interfaceColor.selectorAvailable ||
        (mode === "eye" && !settings.eye_comfort_palette_id);
      return {
        mode,
        icon: ICONS[mode],
        label: i18n(themePrefix(`reading_mode.${mode}`)),
        selected: this.mode === mode,
        disabled: this.busy || unavailable,
        unavailable,
      };
    });
  }

  // 先加载完整的原生配色表，成功后再替换，失败时保留当前页面。
  async changeLightPalette(id) {
    const current = document.querySelector("link.light-scheme");
    const result = await ajax(
      `/color-scheme-stylesheet/${id}/${currentThemeId()}.json`
    );
    if (
      !current ||
      !result.new_href ||
      (id > 0 && result.color_scheme_id !== id)
    ) {
      throw new Error("Reading palette unavailable");
    }

    const next = current.cloneNode();
    next.media = "not all";
    next.href = result.new_href;
    next.dataset.schemeId = result.color_scheme_id || -1;
    await new Promise((resolve, reject) => {
      const timeout = window.setTimeout(() => finish(false), 15000);
      const finish = (success) => {
        window.clearTimeout(timeout);
        next.onload = next.onerror = null;
        if (success) {
          resolve();
        } else {
          next.remove();
          reject(new Error("Reading palette stylesheet failed to load"));
        }
      };
      next.onload = () => finish(true);
      next.onerror = () => finish(false);
      document.head.appendChild(next);
    });

    next.media = current.media;
    current.replaceWith(next);
    this.lightPaletteId = Number(next.dataset.schemeId);
  }

  @action
  navigateOptions(event) {
    if (!["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)) {
      return;
    }
    const buttons = [
      ...event.currentTarget.querySelectorAll("button:not(:disabled)"),
    ];
    if (!buttons.length) {
      return;
    }
    const current = buttons.indexOf(document.activeElement);
    const index = {
      Home: 0,
      End: buttons.length - 1,
      ArrowDown: (current + 1) % buttons.length,
      ArrowUp: (current - 1 + buttons.length) % buttons.length,
    }[event.key];
    event.preventDefault();
    buttons[index].focus();
  }

  @action
  async selectMode(mode, menu) {
    if (
      this.busy ||
      this.options.find((option) => option.mode === mode)?.disabled
    ) {
      return;
    }
    this.busy = true;
    this.error = false;

    try {
      if (mode === "night") {
        this.interfaceColor.forceDarkMode();
      } else {
        if (
          mode === "eye" &&
          this.lightPaletteId !== settings.eye_comfort_palette_id
        ) {
          const backup = {
            id: this.lightPaletteId,
            cookie: cookie("color_scheme_id") ?? null,
          };
          await this.changeLightPalette(settings.eye_comfort_palette_id);
          cookie(BACKUP_COOKIE, JSON.stringify(backup), {
            path: "/",
            expires: 365,
          });
          updateColorSchemeCookie(settings.eye_comfort_palette_id);
        } else if (
          mode === "day" &&
          this.lightPaletteId === settings.eye_comfort_palette_id
        ) {
          let backup;
          try {
            backup = JSON.parse(cookie(BACKUP_COOKIE) || "null");
          } catch {
            // 旧或损坏的备份回退到主题默认配色。
          }
          const id = Number.isInteger(backup?.id) ? backup.id : -1;
          await this.changeLightPalette(id);
          updateColorSchemeCookie(backup?.cookie || null);
          removeCookie(BACKUP_COOKIE, { path: "/" });
        }
        this.interfaceColor.forceLightMode();
      }
      await menu.close();
    } catch {
      this.error = true;
    } finally {
      this.busy = false;
    }
  }

  <template>
    <li class="header-dropdown-toggle kuu-reading-mode" data-mode={{this.mode}}>
      <DMenu
        @animated={{false}}
        @ariaLabel={{this.currentLabel}}
        @icon={{this.modeIcon}}
        @identifier="kuu-reading-mode"
        @title={{this.currentLabel}}
        @triggerClass="btn-flat icon kuu-reading-mode__trigger"
      >
        <:content as |menu|>
          <div
            aria-busy={{if this.busy "true" "false"}}
            class="kuu-reading-mode__menu"
          >
            <p class="kuu-reading-mode__title">{{i18n
                (themePrefix "reading_mode.title")
              }}</p>
            <div
              aria-label={{i18n (themePrefix "reading_mode.title")}}
              role="menu"
              {{on "keydown" this.navigateOptions}}
            >
              {{#each this.options key="mode" as |option|}}
                <button
                  aria-checked={{if option.selected "true" "false"}}
                  class="btn-flat kuu-reading-mode__option"
                  data-mode={{option.mode}}
                  disabled={{option.disabled}}
                  role="menuitemradio"
                  type="button"
                  {{on "click" (fn this.selectMode option.mode menu)}}
                >
                  {{dIcon option.icon}}
                  <span>{{option.label}}</span>
                  {{#if option.selected}}
                    {{dIcon "check"}}
                  {{else if option.unavailable}}
                    <small>{{i18n
                        (themePrefix "reading_mode.unavailable")
                      }}</small>
                  {{/if}}
                </button>
              {{/each}}
            </div>
            {{#if this.error}}
              <p class="kuu-reading-mode__error" role="alert">{{i18n
                  (themePrefix "reading_mode.error")
                }}</p>
            {{/if}}
          </div>
        </:content>
      </DMenu>
    </li>
  </template>
}

export default apiInitializer((api) => {
  if (!settings.reading_mode_enabled) {
    return;
  }
  api.headerIcons.add("kuu-reading-mode", ReadingMode, { before: "search" });
});
