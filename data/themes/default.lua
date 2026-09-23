-- default: near-black, low-saturation, single purple accent (current look)
return {
  name = "default",
  background = "#050507", background2 = "#0b0b10", background3 = "#15151c",
  text = "#d8d8df", caret = "#ffffff",
  accent = "#a89bd8",
  dim = "#707080", divider = "#252530", selection = "#252536",
  line_number = "#555565", line_number2 = "#a89bd8",
  line_highlight = "#111119", scrollbar = "#090910", scrollbar2 = "#55556a",
  search_highlight = { 255, 210, 80, 90 },
  titlebar_text = "#9a9aaa", titlebar_text_focus = "#eeeeff",
  titlebar_button_hover = "#303040", titlebar_close_hover = "#e06060",
  vim_pill_fg = "#eeeeff", vim_normal_bg = "#30303a",
  vim_insert_bg = "#12345a", vim_visual_bg = "#4a3300",
  vim_replace_bg = "#4a1616", vim_command_bg = "#204020",
  git_modified = "#d0ad55", git_added = "#65b875", git_deleted = "#d06060",
  git_conflict = "#e07050", git_untracked = "#888899", git_renamed = "#9b8de0",
  syntax = {
    normal = "#d8d8df", symbol = "#c4c4d0", comment = "#686878",
    keyword = "#9b8cff", keyword2 = "#7f75c8", number = "#e0a060",
    literal = "#aaaac0", string = "#86c986", operator = "#ccccd8",
    ["function"] = "#75b9ed",
  },
}
