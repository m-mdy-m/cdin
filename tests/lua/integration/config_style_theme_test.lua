local T = require "harness"

-- config defaults and the style table, with the theme registry pointed at the
-- fixture tree. The bundled theme moved to cdin-x with the rest of the
-- mandatory set, so what the runtime can load at boot is nothing; style.lua
-- falls back to its own pre-theme colors and that is the state under test
-- here. The theme-switching contract lives in unit/themes_test.lua, against
-- fixtures, because it needs a theme to switch to.
--
-- Environment:
--   CDIN_THEME_TREE  the tree holding data/themes/. Unset means the theme
--                    registry finds nothing, which is the boot state of an
--                    editor whose bundle has not been assembled.
local TREE = os.getenv("CDIN_THEME_TREE")

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
  -- No fallback font files in the test environment, and no theme tree unless
  -- one was handed in: the bundler copies the fonts in at build time, so
  -- style.lua has to survive their absence.
  get_file_info = function() return nil end,
  get_time = function() return 0 end,
  fuzzy_match = function() return nil end,
  list_dir = function() return {} end,
})

local common = require "core.utils.common"
local config = require "core.config"
if TREE and TREE ~= "" then
  config.site_dir = TREE
end

local themes = require "core.themes"
local style   = require "core.style"

-- ── config contract ─────────────────────────────────────────────────

T.eq(config.theme, "default", "config.theme defaults to 'default'")
T.ok(config.direction == "auto" or config.direction == "ltr"
  or config.direction == "rtl", "config.direction is auto/ltr/rtl")
T.eq(type(config.shaping_enabled), "boolean", "config.shaping_enabled is boolean")

-- config.site_dir is the one place cdin-x is reached, and it is a cdin-side
-- value, so the runtime's computation of it is worth pinning.
T.eq(type(config.site_dir), "string", "config.site_dir is a string")
T.ok(#config.site_dir > 0, "config.site_dir is not empty")
T.eq(type(config.user_dir), "string", "config.user_dir is a string")
T.eq(config.fonts_dir, EXEDIR .. "/data/fonts",
  "config.fonts_dir points at the assembled bundle")

-- ── style loads, with or without a theme to load ─────────────────────

T.eq(type(style.set_theme), "function", "style.set_theme exists")
T.eq(type(style.set_fallback), "function", "style.set_fallback exists")

-- The pre-theme fallbacks. These are what an editor with no assembled bundle
-- renders with, so they must exist whether or not a theme resolved.
for _, key in ipairs({ "background", "text", "accent", "caret", "dim",
                       "divider", "selection", "line_highlight" }) do
  T.eq(type(style[key]), "table", "style." .. key .. " is a color table")
  T.ok(#style[key] >= 3, "style." .. key .. " has at least r,g,b")
end
T.eq(type(style.syntax), "table", "style.syntax exists")
T.ok(type(style.syntax.keyword) == "table", "style.syntax.keyword is a color table")

-- The theme_name contract: either a resolved theme set it, or nothing did.
if style.theme_name then
  T.eq(type(style.theme_name), "string", "style.theme_name is a string")
end

-- Whatever happened above, set_theme on a name nothing can resolve must
-- report failure and leave the table as it found it. style.lua's own
-- initialization makes this same call, so it is the same path either way.
local before_name = style.theme_name
local before_bg   = style.background
T.eq(style.set_theme("no-such-theme"), false, "set_theme(unknown) returns false")
T.eq(style.theme_name, before_name, "a failed set_theme leaves theme_name alone")
T.eq(style.background, before_bg, "a failed set_theme leaves background alone")

-- The registry is reachable and reports a name that does not exist, rather
-- than raising. style.lua calls it through a pcall at load time, so a raise
-- here would be silently swallowed into "no theme applied".
local t, err = themes.load("no-such-theme")
T.ok(t == nil, "themes.load(unknown) returns nil, not an error")
T.ok(type(err) == "string" and #err > 0, "themes.load(unknown) explains itself")
