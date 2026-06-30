local common = require "core.common"
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

style.background  = { common.color "#0a0a0a" }  -- editor body
style.background2  = { common.color "#141414" }  -- panels: tabs, titlebar, status bar
style.background3  = { common.color "#1a1a1a" }  -- popups / suggestion boxes
style.text         = { common.color "#d0d0d0" }
style.caret         = { common.color "#d0d0d0" }
style.accent        = { common.color "#a090c7" }  -- the one accent color
style.dim            = { common.color "#5a5a5a" }
style.divider        = { common.color "#1a1a1a" }
style.selection      = { common.color "#2a2a2a" }
style.line_number   = { common.color "#3a3a3a" }
style.line_number2 = { common.color "#8b7fc7" }
style.line_highlight = { common.color "#141414" }
style.scrollbar      = { common.color "#1a1a1a" }
style.scrollbar2    = { common.color "#3a3a3a" }

style.titlebar_text       = { common.color "#9a9a9a" }
style.titlebar_text_focus = { common.color "#d0d0d0" }
style.titlebar_button_hover = { common.color "#2a2a2a" }
style.titlebar_close_hover  = { common.color "#e06060" }

style.syntax = {}
style.syntax["normal"]   = { common.color "#d0d0d0" }
style.syntax["symbol"]   = { common.color "#d0d0d0" }
style.syntax["comment"]  = { common.color "#5a5a5a" }
style.syntax["keyword"]  = { common.color "#a090c7" }
style.syntax["keyword2"] = { common.color "#8b7fc7" }
style.syntax["number"]   = { common.color "#a090c7" }
style.syntax["literal"]  = { common.color "#8b7fc7" }
style.syntax["string"]   = { common.color "#808080" }
style.syntax["operator"] = { common.color "#c0c0c0" }
style.syntax["function"] = { common.color "#b0b0b0" }

return style
