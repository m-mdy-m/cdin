-- data/user/colors/cdin-dark.lua
-- cdin minimal dark theme — فقط رنگ‌ها، fonts دست نمیخوره
-- load path: data/user/init.lua -> require "colors.cdin-dark"

local style  = require "core.style"
local common = require "core.common"

-- ─── تابع کمکی برای تبدیل hex به RGBA ───────────────────────────────────────

local function c(hex)
  hex = hex:gsub("#", "")
  local r = tonumber(hex:sub(1,2), 16)
  local g = tonumber(hex:sub(3,4), 16)
  local b = tonumber(hex:sub(5,6), 16)
  local a = #hex >= 8 and tonumber(hex:sub(7,8), 16) or 255
  return { r, g, b, a }
end

-- ─── Background ──────────────────────────────────────────────────────────────

style.background   = c "#121212"
style.background2  = c "#161616"
style.background3  = c "#1c1c1c"
style.line_hl      = c "#1e1e1e"

-- ─── Text ────────────────────────────────────────────────────────────────────

style.text         = c "#c3c3c3"
style.caret        = c "#c8c8c8"
style.selection    = c "#32507080"

-- ─── Accents (mode colors) ───────────────────────────────────────────────────

style.accent       = c "#648cc8"   -- normal mode blue
style.accent_ins   = c "#50a050"   -- insert mode green
style.accent_vis   = c "#a05ab4"   -- visual mode purple
style.accent_warn  = c "#c8643c"

-- ─── Borders / dividers ──────────────────────────────────────────────────────

style.border       = c "#2d2d2d"
style.border_hi    = c "#464646"

-- ─── Titlebar ────────────────────────────────────────────────────────────────

style.titlebar_bg   = c "#0e0e0e"
style.titlebar_text = c "#5a5a5a"

-- ─── Syntax ──────────────────────────────────────────────────────────────────

style.syntax["normal"]   = c "#c3c3c3"
style.syntax["symbol"]   = c "#c3c3c3"
style.syntax["comment"]  = c "#50605a"
style.syntax["keyword"]  = c "#648cc8"
style.syntax["keyword2"] = c "#a05ab4"
style.syntax["number"]   = c "#b48250"
style.syntax["literal"]  = c "#50a078"
style.syntax["string"]   = c "#5aa05a"
style.syntax["operator"] = c "#aaaaaa"
style.syntax["function"] = c "#8cb4d2"
style.syntax["type"]     = c "#8cb48c"

-- ─── اندازه‌ها — فقط چیزهایی که باید override بشن ────────────────────────────

style.caret_width    = 2
style.scrollbar_size = 3
style.padding        = { x = 6, y = 3 }

-- window control dots config
style.wctrl = {
  size   = 11,
  gap    = 8,
  margin = 12,
  close  = { 200,  70,  70, 220 },
  min    = { 180, 160,  50, 220 },
  max    = {  70, 160,  80, 220 },
}

-- statusbar / titlebar heights
style.statusbar_height = 22
style.titlebar_height  = 28

-- treeview
style.tree_row_height = 20
style.tree_indent     = 14
style.tree_icon_width = 14
style.tree_text       = c "#9b9b9b"
style.tree_text_hi    = c "#d2d2d2"
style.tree_selected   = { 35, 50, 75, 200 }
