-- catppuccin-mocha (soft pastel dark palette, matches the Catppuccin Mocha flavor)
return {
  name = "catppuccin-mocha",
  background = "#1e1e2e", background2 = "#181825", background3 = "#313244",
  text = "#cdd6f4", caret = "#f5e0dc",
  accent = "#cba6f7",
  dim = "#6c7086", divider = "#313244", selection = "#45475a",
  line_number = "#585b70", line_number2 = "#cba6f7",
  line_highlight = "#232336", scrollbar = "#181825", scrollbar2 = "#585b70",
  search_highlight = { 249, 226, 175, 90 },
  titlebar_text = "#a6adc8", titlebar_text_focus = "#cdd6f4",
  titlebar_button_hover = "#313244", titlebar_close_hover = "#f38ba8",
  vim_pill_fg = "#1e1e2e", vim_normal_bg = "#45475a",
  vim_insert_bg = "#89b4fa", vim_visual_bg = "#f5c2e7",
  vim_replace_bg = "#f38ba8", vim_command_bg = "#a6e3a1",
  git_modified = "#f9e2af", git_added = "#a6e3a1", git_deleted = "#f38ba8",
  git_conflict = "#fab387", git_untracked = "#6c7086", git_renamed = "#cba6f7",
  syntax = {
    normal = "#cdd6f4", symbol = "#bac2de", comment = "#6c7086",
    keyword = "#cba6f7", keyword2 = "#f5c2e7", number = "#fab387",
    literal = "#f5e0dc", string = "#a6e3a1", operator = "#89dceb",
    ["function"] = "#89b4fa",
  },
}