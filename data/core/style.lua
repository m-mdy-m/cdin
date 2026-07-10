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
style.background        = { common.color "#060608" }
style.background2       = { common.color "#0c0c10" }
style.background3       = { common.color "#121218" }

-- ── text & caret ──────────────────────────────────────────────────────────────
style.text              = { common.color "#c8c8cc" }
style.caret             = { common.color "#c8c8cc" }
style.caret_block_alpha = 0.50

-- ── accent (muted purple, same as before) ─────────────────────────────────────
style.accent            = { common.color "#9080bf" }

-- ── structural / decorative ───────────────────────────────────────────────────
style.dim               = { common.color "#555560" }
style.divider           = { common.color "#18181e" }
style.selection         = { common.color "#1a1a24" }
style.line_number       = { common.color "#343440" }
style.line_number2      = { common.color "#7a6eb8" }
style.line_highlight    = { common.color "#0d0d14" }
style.scrollbar         = { common.color "#07070b" }
style.scrollbar2        = { common.color "#3d3d50" }
style.search_highlight  = { 255, 200, 0, 70 }

-- ── titlebar ──────────────────────────────────────────────────────────────────
style.titlebar_text         = { common.color "#888896" }
style.titlebar_text_focus   = { common.color "#c8c8cc" }
style.titlebar_button_hover = { common.color "#222230" }
style.titlebar_close_hover  = { common.color "#d05858" }

-- ── vim mode pill colors ───────────────────────────────────────────────────────
style.vim_pill_fg       = { common.color "#d8d8e0" }
style.vim_normal_bg     = { common.color "#222228" }
style.vim_insert_bg     = { common.color "#0e2440" }
style.vim_visual_bg     = { common.color "#2a1e00" }
style.vim_replace_bg    = { common.color "#2e0e0e" }
style.vim_command_bg    = { common.color "#1a2a18" }

-- ── git status colors (treeview + status bar) ─────────────────────────────────
style.git_modified      = { common.color "#b89a50" }
style.git_added         = { common.color "#5a9a5a" }
style.git_deleted       = { common.color "#b85050" }
style.git_conflict      = { common.color "#d06040" }
style.git_untracked     = { common.color "#666678" }
style.git_renamed       = { common.color "#7a70b0" }

-- ── syntax ────────────────────────────────────────────────────────────────────
style.syntax = {}
style.syntax["normal"]   = { common.color "#c8c8cc" }
style.syntax["symbol"]   = { common.color "#b8b8c0" }
style.syntax["comment"]  = { common.color "#505058" }
style.syntax["keyword"]  = { common.color "#7b6fd4" }
style.syntax["keyword2"] = { common.color "#7a6eb0" }
style.syntax["number"]   = { common.color "#d4915a" }
style.syntax["literal"]  = { common.color "#8888a0" }
style.syntax["string"]   = { common.color "#7aad7a" }
style.syntax["operator"] = { common.color "#b8b8c0" }
style.syntax["function"] = { common.color "#6aa8d8" }

return style
