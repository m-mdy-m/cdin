local common = require "core.utils.common"
local style = {}

style.padding = { x = common.round(14 * SCALE), y = common.round(7 * SCALE) }
style.divider_size = common.round(1 * SCALE)
style.scrollbar_size = common.round(4 * SCALE)
style.caret_width = common.round(2 * SCALE)
style.tab_width = common.round(170 * SCALE)

style.titlebar_height = common.round(34 * SCALE)
style.titlebar_button_width = common.round(46 * SCALE)

style.font = renderer.font.load(EXEDIR .. "/data/fonts/font.ttf", 14 * SCALE)
style.big_font = renderer.font.load(EXEDIR .. "/data/fonts/font.ttf", 34 * SCALE)
style.icon_font = renderer.font.load(EXEDIR .. "/data/fonts/icons.ttf", 14 * SCALE)
style.code_font = renderer.font.load(EXEDIR .. "/data/fonts/monospace.ttf", 13.5 * SCALE)

-- ── base backgrounds  ─────────────────────────────────────────
style.background        = { common.color "#060608" }  -- editor body  (near black)
style.background2       = { common.color "#0c0c10" }  -- panels: tabs, titlebar, status
style.background3       = { common.color "#121218" }  -- popups / suggestion boxes

-- ── text & caret ──────────────────────────────────────────────────────────────
style.text              = { common.color "#c8c8cc" }
style.caret             = { common.color "#c8c8cc" }
style.caret_block_alpha = 0.50

-- ── accent (muted purple, same as before) ─────────────────────────────────────
style.accent            = { common.color "#9080bf" }

-- ── structural / decorative ───────────────────────────────────────────────────
style.dim               = { common.color "#555560" }
style.divider           = { common.color "#18181e" }
style.selection         = { common.color "#1e1e28" }
style.line_number       = { common.color "#343440" }
style.line_number2      = { common.color "#7a6eb8" }
style.line_highlight    = { common.color "#101018" }
style.scrollbar         = { common.color "#14141a" }
style.scrollbar2        = { common.color "#303040" }
style.search_highlight  = { 255, 200, 0, 70 }

-- ── titlebar ──────────────────────────────────────────────────────────────────
style.titlebar_text         = { common.color "#888896" }
style.titlebar_text_focus   = { common.color "#c8c8cc" }
style.titlebar_button_hover = { common.color "#222230" }
style.titlebar_close_hover  = { common.color "#d05858" }

-- ── vim mode pill colors ───────────────────────────────────────────────────────
style.vim_pill_fg       = { common.color "#d8d8e0" }   -- text on all pills
style.vim_normal_bg     = { common.color "#222228" }   -- dark charcoal
style.vim_insert_bg     = { common.color "#0e2440" }   -- dark navy (NOT bright blue)
style.vim_visual_bg     = { common.color "#2a1e00" }   -- dark amber
style.vim_replace_bg    = { common.color "#2e0e0e" }   -- dark crimson
style.vim_command_bg    = { common.color "#1a2a18" }   -- dark forest green

-- ── git status colors (treeview + status bar) ─────────────────────────────────
style.git_modified      = { common.color "#b89a50" }   -- amber  — changed files
style.git_added         = { common.color "#5a9a5a" }   -- muted green — new files
style.git_deleted       = { common.color "#b85050" }   -- muted red — removed files
style.git_conflict      = { common.color "#d06040" }   -- orange-red — conflicts
style.git_untracked     = { common.color "#666678" }   -- gray — untracked
style.git_renamed       = { common.color "#7a70b0" }   -- purple — renamed/copied

-- ── syntax ────────────────────────────────────────────────────────────────────
style.syntax = {}
style.syntax["normal"]   = { common.color "#c8c8cc" }
style.syntax["symbol"]   = { common.color "#c8c8cc" }
style.syntax["comment"]  = { common.color "#505058" }
style.syntax["keyword"]  = { common.color "#9080bf" }
style.syntax["keyword2"] = { common.color "#7a6eb0" }
style.syntax["number"]   = { common.color "#9080bf" }
style.syntax["literal"]  = { common.color "#7a6eb0" }
style.syntax["string"]   = { common.color "#707080" }
style.syntax["operator"] = { common.color "#b8b8c0" }
style.syntax["function"] = { common.color "#a8a8b8" }

return style
