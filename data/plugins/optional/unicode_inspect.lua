-- Optional: Unicode inspector. Shows codepoints of selection/caret.
local core = require "core"
local config = require "core.config"
local command = require "core.input.command"
local keymap = require "core.input.keymap"

if config.optional_plugins and config.optional_plugins.unicode_inspect == false then
  return
end

local function inspect()
  local dv = core.active_docview()
  if not dv then core.error("No active doc"); return end
  local doc = dv.doc
  local text
  if doc:has_selection() then
    local l1, c1, l2, c2 = doc:get_selection(true)
    text = doc:get_text(l1, c1, l2, c2)
  else
    local line, col = doc:get_selection()
    local ltext = doc.lines[line] or ""
    -- grab one full char at caret
    local b = ltext:byte(col) or 0
    local step = 1
    if b >= 0xF0 then step = 4 elseif b >= 0xE0 then step = 3 elseif b >= 0xC0 then step = 2 end
    text = ltext:sub(col, col + step - 1)
  end
  if text == nil or text == "" then core.log("Empty"); return end
  local ok, u = pcall(require, "core.text.utf8")
  local parts = {}
  if ok and u then
    local pos, n = 1, #text
    while pos <= n and #parts < 32 do
      local cp, nxt = u.decode(text, pos)
      parts[#parts + 1] = string.format("U+%04X", cp)
      pos = nxt
    end
    core.log("%s  (%d chars)", table.concat(parts, " "), u.len(text))
  else
    core.log("bytes: %d", #text)
  end
end

command.add("core.views.docview", { ["unicode:inspect"] = inspect })
keymap.add({ ["ctrl+alt+u"] = "unicode:inspect" })
