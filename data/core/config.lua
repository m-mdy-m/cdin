local config = {}

config.project_scan_rate = 10
config.fps = 60
config.max_log_items = 80
config.message_timeout = 3

config.mouse_wheel_scroll = 54 * SCALE

config.file_size_limit = 10
config.ignore_files = "^%."
config.symbol_pattern = "[%a_][%w_]*"
config.non_word_chars = " \t\n/\\()\"':,.;<>~!@#$%^&*|+=[]{}`?-"
config.undo_merge_timeout = 0.3
config.max_undos = 10000
config.highlight_current_line = true
config.line_height = 1.2
config.indent_size = 2
config.tab_type = "soft"
config.line_limit = 80

config.scrolloff = 5

config.line_number_relative = false
-- config.session_restore and config.vim_mode_enabled are NOT defined
-- here: each is owned by its own plugin, which already sets its own default
-- via `if config.X == nil then config.X = default end`. A copy here would
-- be a config key that outlives the plugin — meaningless if that
-- plugin is ever disabled, and easy to drift from the plugin's own
-- default.

-- ── text direction & shaping ─────────────────────────────
-- "auto": per-line base direction; "ltr": legacy; "rtl": force RTL.
config.direction = "auto"
config.shaping_enabled = true

-- ── themes ───────────────────────────────────────────────
config.theme = "default"
config.theme_auto_reload = true

-- ── plugins ─────────────────────────────────────────────
-- Selects which SITE plugins load (SITE is config.site_dir below). It has no
-- effect on the bundled set, which is mandatory and always loads:
--   nil            load every site plugin
--   false          load no site plugins (bare editor, bundled set only)
--   { "demo", ... } load only the named site plugins
-- Anything else is treated as nil.
config.plugins = nil

-- Fonts directory (bundled with the binary)
config.fonts_dir = EXEDIR .. "/data/fonts"

-- ── user / site directories ─────────────────────────────
-- user_dir : where user themes (themes/<name>/theme.lua) and init.lua are looked up.
--
-- The site directory is where installed extensions live. Two knobs, and they
-- are the only two:
--
--   config.site_dirname   the directory's *name*, under <data_home>/cdin/.
--                         "site" is what vim and neovim call exactly this
--                         thing (:h site-dir) — third-party content, as
--                         opposed to the editor's own. Change it to
--                         "extensions", "addons" or "x" and everything
--                         follows.
--   config.site_dir       a full path, which overrides site_dirname entirely
--                         for anyone who wants it outside the data home.
do
  local sep = PATHSEP or package.config:sub(1, 1)
  local function env(name)
    local v = os.getenv(name)
    return v and v ~= "" and v or nil
  end

  local home, config_home, data_home
  if sep == "\\" then
    home = env("USERPROFILE") or env("HOME") or "."
    config_home = env("APPDATA") or (home .. "\\AppData\\Roaming")
    data_home = env("LOCALAPPDATA") or env("APPDATA") or (home .. "\\AppData\\Local")
  else
    home = env("HOME") or "."
    config_home = env("XDG_CONFIG_HOME") or (home .. "/.config")
    data_home = env("XDG_DATA_HOME") or (home .. "/.local/share")
  end

  local base_config = config_home .. sep .. "cdin"

  config.user_root = config.user_root or base_config
  config.user_dir  = config.user_dir or (base_config .. sep .. "user")

  -- Exported so config.site_path() can rebuild the path from the name.
  config.data_home = data_home .. sep .. "cdin"
  config.sep = sep

  -- THE knob. One value, and every consumer follows it — the loader, the
  -- theme registry, and cdin-x, which reads this table rather than
  -- computing a path of its own.
  config.site_dirname = config.site_dirname or "site"
end

-- Resolves the site directory, at the point of use rather than at load.
--
-- Deliberately not cached into a field: ~/.config/cdin/user/init.lua runs
-- *after* this module has been required, so a value computed here would be
-- fixed before the user had a chance to change it and the one knob would
-- silently do nothing. Call this; do not read a path out of the table.
function config.site_path()
  return config.site_dir or (config.data_home .. config.sep .. config.site_dirname)
end

return config