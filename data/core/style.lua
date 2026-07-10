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

-- ── base backgrounds ─────────────────────────────────────────
style.background        = { common.color "#050507" }
style.background2       = { common.color "#0b0b10" }
style.background3       = { common.color "#15151c" }

-- ── text & caret ─────────────────────────────────────────────
style.text              = { common.color "#d8d8df" }
style.caret             = { common.color "#ffffff" }
style.caret_block_alpha = 0.55

-- ── accent ────────────────────────────────────────────────────
style.accent            = { common.color "#a89bd8" }

-- ── structural ────────────────────────────────────────────────
style.dim               = { common.color "#707080" }
style.divider           = { common.color "#252530" }
style.selection         = { common.color "#252536" }
style.line_number       = { common.color "#555565" }
style.line_number2      = { common.color "#a89bd8" }
style.line_highlight    = { common.color "#111119" }
style.scrollbar         = { common.color "#090910" }
style.scrollbar2        = { common.color "#55556a" }
style.search_highlight  = { 255, 210, 80, 90 }

-- ── titlebar ──────────────────────────────────────────────────
style.titlebar_text         = { common.color "#9a9aaa" }
style.titlebar_text_focus   = { common.color "#eeeeff" }
style.titlebar_button_hover = { common.color "#303040" }
style.titlebar_close_hover  = { common.color "#e06060" }

-- ── vim mode ──────────────────────────────────────────────────
style.vim_pill_fg       = { common.color "#eeeeff" }
style.vim_normal_bg     = { common.color "#30303a" }
style.vim_insert_bg     = { common.color "#12345a" }
style.vim_visual_bg     = { common.color "#4a3300" }
style.vim_replace_bg    = { common.color "#4a1616" }
style.vim_command_bg    = { common.color "#204020" }

-- ── git ───────────────────────────────────────────────────────
style.git_modified      = { common.color "#d0ad55" }
style.git_added         = { common.color "#65b875" }
style.git_deleted       = { common.color "#d06060" }
style.git_conflict      = { common.color "#e07050" }
style.git_untracked     = { common.color "#888899" }
style.git_renamed       = { common.color "#9b8de0" }

-- ── syntax ────────────────────────────────────────────────────
style.syntax = {}
style.syntax["normal"]   = { common.color "#d8d8df" }
style.syntax["symbol"]   = { common.color "#c4c4d0" }
style.syntax["comment"]  = { common.color "#686878" }
style.syntax["keyword"]  = { common.color "#9b8cff" }
style.syntax["keyword2"] = { common.color "#7f75c8" }
style.syntax["number"]   = { common.color "#e0a060" }
style.syntax["literal"]  = { common.color "#aaaac0" }
style.syntax["string"]   = { common.color "#86c986" }
style.syntax["operator"] = { common.color "#ccccd8" }
style.syntax["function"] = { common.color "#75b9ed" }

return style
