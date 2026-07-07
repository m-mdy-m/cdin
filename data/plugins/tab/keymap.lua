local keymap = require "core.input.keymap"

keymap.add {
  -- cycle
  ["ctrl+tab"]       = "tab:next",
  ["ctrl+shift+tab"] = "tab:prev",

  -- jump to tab N  (Ctrl+1 … Ctrl+9, VSCode-style)
  ["ctrl+1"] = "tab:go-1",
  ["ctrl+2"] = "tab:go-2",
  ["ctrl+3"] = "tab:go-3",
  ["ctrl+4"] = "tab:go-4",
  ["ctrl+5"] = "tab:go-5",
  ["ctrl+6"] = "tab:go-6",
  ["ctrl+7"] = "tab:go-7",
  ["ctrl+8"] = "tab:go-8",
  ["ctrl+9"] = "tab:go-9",

  -- lifecycle
  ["ctrl+t"]       = "tab:new",
  ["ctrl+shift+w"] = "tab:close",

  -- reorder
  ["ctrl+shift+pageup"]   = "tab:move-left",
  ["ctrl+shift+pagedown"] = "tab:move-right",
}