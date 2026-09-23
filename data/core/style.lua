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

do
  style._fallback_fonts = style._fallback_fonts or {}

  local function add_fallback_if_present(path, size)
    if not system.get_file_info(path) then return nil end
    local ok, font = pcall(renderer.font.load, path, size)
    if not ok or not font then

      return nil
    end
    style.font:add_fallback(font)
    style.big_font:add_fallback(font)
    style.code_font:add_fallback(font)
    table.insert(style._fallback_fonts, font)
    return font
  end

  add_fallback_if_present(EXEDIR .. "/data/fonts/fallback.ttf", 14 * SCALE)
  add_fallback_if_present(EXEDIR .. "/data/fonts/emoji.ttf", 14 * SCALE)
end

local function fallback(key, hex)
  if style[key] == nil then style[key] = { common.color(hex) } end
end

fallback("background", "#050507")
fallback("background2", "#0b0b10")
fallback("background3", "#15151c")
fallback("text", "#d8d8df")
fallback("caret", "#ffffff")
style.caret_block_alpha = style.caret_block_alpha or 0.55
fallback("accent", "#a89bd8")
fallback("dim", "#707080")
fallback("divider", "#252530")
fallback("selection", "#252536")
fallback("line_number", "#555565")
fallback("line_number2", "#a89bd8")
fallback("line_highlight", "#111119")
fallback("scrollbar", "#090910")
fallback("scrollbar2", "#55556a")
if style.search_highlight == nil then style.search_highlight = { 255, 210, 80, 90 } end
fallback("titlebar_text", "#9a9aaa")
fallback("titlebar_text_focus", "#eeeeff")
fallback("titlebar_button_hover", "#303040")
fallback("titlebar_close_hover", "#e06060")
fallback("vim_pill_fg", "#eeeeff")
fallback("vim_normal_bg", "#30303a")
fallback("vim_insert_bg", "#12345a")
fallback("vim_visual_bg", "#4a3300")
fallback("vim_replace_bg", "#4a1616")
fallback("vim_command_bg", "#204020")
fallback("git_modified", "#d0ad55")
fallback("git_added", "#65b875")
fallback("git_deleted", "#d06060")
fallback("git_conflict", "#e07050")
fallback("git_untracked", "#888899")
fallback("git_renamed", "#9b8de0")

style.syntax = style.syntax or {}
local function syn(key, hex)
  if style.syntax[key] == nil then style.syntax[key] = { common.color(hex) } end
end
syn("normal", "#d8d8df")
syn("symbol", "#c4c4d0")
syn("comment", "#686878")
syn("keyword", "#9b8cff")
syn("keyword2", "#7f75c8")
syn("number", "#e0a060")
syn("literal", "#aaaac0")
syn("string", "#86c986")
syn("operator", "#ccccd8")
syn("function", "#75b9ed")

do
  local ok_cfg, config = pcall(require, "core.config")
  local name = (ok_cfg and config and config.theme) or "default"
  local ok, themes = pcall(require, "core.themes")
  if ok and themes then pcall(themes.apply, style, name) end
end

function style.set_theme(name)
  local themes = require "core.themes"
  return themes.apply(style, name)
end

return style