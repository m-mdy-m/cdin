local T = require "harness"

T.stub("renderer", {
  font = {
    load = function(path, size)
      return {
        path = path,
        size = size,
        add_fallback = function() end,
        get_width = function() return 0 end,
        get_height = function() return 10 end,
      }
    end,
  },
  draw_text = function() end,
})
T.stub("system", {
  -- no fallback font files in the test environment
  get_file_info = function() return nil end,
  get_time = function() return 0 end,
  fuzzy_match = function() return nil end,
  list_dir = function() return {} end,
})

local common = require "core.utils.common"
local config = require "core.config"
local themes = require "core.themes"
local style = require "core.style"

local default_theme = require "themes.default"
local dracula_theme = require "themes.dracula"

-- ── config contract ─────────────────────────────────────────────────
T.eq(config.theme, "default", "config.theme defaults to 'default'")
T.ok(config.direction == "auto" or config.direction == "ltr"
  or config.direction == "rtl", "config.direction is auto/ltr/rtl")
T.eq(type(config.shaping_enabled), "boolean", "config.shaping_enabled is boolean")

-- ── style loads with the default theme applied ──────────────────────
T.eq(type(style.set_theme), "function", "style.set_theme exists")
T.eq(style.theme_name, "default", "style starts on default theme")
T.eq(style.background, { common.color(default_theme.background) },
  "style.background is the default theme color")
T.eq(style.syntax.keyword, { common.color(default_theme.syntax.keyword) },
  "style.syntax.keyword is the default theme color")

-- ── switch to dracula ───────────────────────────────────────────────
local ok = style.set_theme("dracula")
T.eq(ok, true, "set_theme('dracula') returns true")
T.eq(style.theme_name, "dracula", "theme_name updated")
T.eq(style.background, { common.color(dracula_theme.background) },
  "background now dracula")
T.neq(style.background, { common.color(default_theme.background) },
  "background differs from default")
T.eq(style.accent, { common.color(dracula_theme.accent) }, "accent now dracula")
T.eq(style.syntax.keyword, { common.color(dracula_theme.syntax.keyword) },
  "syntax.keyword now dracula")
T.neq(style.syntax.keyword, { common.color(default_theme.syntax.keyword) },
  "syntax.keyword differs from default")

-- ── unknown theme contract ─────────────────────────────────────────
local before_bg = style.background
local before_name = style.theme_name
local res = style.set_theme("no-such-theme")
T.eq(res, false, "unknown theme returns false")
T.eq(style.theme_name, before_name, "theme_name unchanged after failed apply")
T.eq(style.background, before_bg, "background unchanged after failed apply")

-- and applying a *valid* theme afterwards still works
T.eq(style.set_theme("nord"), true, "valid theme works after a failed one")
T.eq(style.theme_name, "nord", "theme_name is nord")
T.eq(style.background,
  { common.color((require "themes.nord").background) }, "nord background applied")

-- leave the shared style table back on the default theme
T.eq(style.set_theme("default"), true, "restore default theme")
T.eq(style.theme_name, "default", "restored default theme")
