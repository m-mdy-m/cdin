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
config.vim_mode_enabled = true

config.scrolloff = 5

config.line_number_relative = false
config.session_restore = false

-- ── text direction & shaping ─────────────────────────────
-- "auto": per-line base direction; "ltr": legacy; "rtl": force RTL.
config.direction = "auto"
config.shaping_enabled = true

-- ── themes ───────────────────────────────────────────────
config.theme = "default"
config.theme_auto_reload = true

-- ── essential plugins (non-removable) ────────────────────
-- NOT listed here. "Essential" is declared per-extension, in the
-- extension's own file (essential = true in a plugin's manifest.lua, or
-- in a theme's theme.lua) — never a name list kept by hand in config,
-- which drifts the moment a new essential extension is added without
-- also updating this file. Once cdin-x is bootstrapped, the live,
-- derived list is available from require("core.x.manager").get_essential_names().

-- ── plugin system ───────────────────────────────────────
-- All plugins/themes now managed through cdin-x extension ecosystem.
-- Optional extensions live in the cdin-x catalog (X/) and are installed
-- per-user into the user extension store.
config.plugin_paths = {}
config.plugins = {}
config.plugins_enabled_by_default = true

-- Fonts directory (populated by cdin-x install)
config.fonts_dir = EXEDIR .. "/data/fonts"

-- ── user config directory ───────────────────────────────
-- Defined here, independent of cdin-x, so the editor still has a valid
-- user_dir even if the cdin-x extension ecosystem fails to bootstrap
-- (e.g. cdin-x not installed yet, or install.sh only partially ran).
-- cdin-x/core/config.lua may override this later with the same logic;
-- both use `config.user_dir or (...)` so whichever runs first wins.
do
  local sep = PATHSEP or package.config:sub(1, 1)
  local function env(name)
    local v = os.getenv(name)
    return v and v ~= "" and v or nil
  end

  local home, config_home
  if sep == "\\" then
    home = env("USERPROFILE") or env("HOME") or "."
    config_home = env("APPDATA") or (home .. "\\AppData\\Roaming")
  else
    home = env("HOME") or "."
    config_home = env("XDG_CONFIG_HOME") or (home .. "/.config")
  end

  local base_config = config_home .. sep .. "cdin"
  config.user_root = config.user_root or base_config
  config.user_dir  = config.user_dir or (base_config .. sep .. "user")
end

return config