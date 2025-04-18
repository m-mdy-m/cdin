local common = require "core.common"
local style = {}

style.padding = { x = common.round(14 * SCALE), y = common.round(7 * SCALE) }
style.divider_size = common.round(1 * SCALE)
style.scrollbar_size = common.round(4 * SCALE)
style.caret_width = common.round(2 * SCALE)
style.tab_width = common.round(170 * SCALE)

style.font = renderer.font.load(EXEDIR .. "/data/fonts/font.ttf", 14 * SCALE)
style.big_font = renderer.font.load(EXEDIR .. "/data/fonts/font.ttf", 34 * SCALE)
style.icon_font = renderer.font.load(EXEDIR .. "/data/fonts/icons.ttf", 14 * SCALE)
style.code_font = renderer.font.load(EXEDIR .. "/data/fonts/monospace.ttf", 13.5 * SCALE)

style.background = { common.color "#0F111A" }
style.background2 = { common.color "#1A1C25" }
style.background3 = { common.color "#20222C" }
style.text = { common.color "#C8C9D1" }
style.caret = { common.color "#80CBC4" }
style.accent = { common.color "#82AAFF" }
style.dim = { common.color "#5C5F6E" }
style.divider = { common.color "#272935" }
style.selection = { common.color "#2D3142" }
style.line_number = { common.color "#3B3E4A" }
style.line_number2 = { common.color "#5E6270" }
style.line_highlight = { common.color "#191B24" }
style.scrollbar = { common.color "#2A2C37" }
style.scrollbar2 = { common.color "#3B3E4A" }

style.syntax = {}
style.syntax["normal"] = { common.color "#D0D0E0" }
style.syntax["symbol"] = { common.color "#D0D0E0" }
style.syntax["comment"] = { common.color "#5C6370" }
style.syntax["keyword"] = { common.color "#C792EA" }
style.syntax["keyword2"] = { common.color "#F78C6C" }
style.syntax["number"] = { common.color "#FFCB6B" }
style.syntax["literal"] = { common.color "#FF5370" }
style.syntax["string"] = { common.color "#C3E88D" }
style.syntax["operator"] = { common.color "#89DDFF" }
style.syntax["function"] = { common.color "#82AAFF" }

return style
