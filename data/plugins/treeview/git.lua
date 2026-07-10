local style = require "core.style"
local git   = require "core.git"

local M = setmetatable({}, { __index = git.status })

-- Single-character labels — shown right-aligned in the treeview row
M.ICON = {
  ["M"]  = "M",   -- modified
  ["A"]  = "A",   -- added / staged new
  ["D"]  = "D",   -- deleted
  ["R"]  = "R",   -- renamed
  ["C"]  = "C",   -- copied
  ["U"]  = "!",   -- conflict (unmerged) — exclamation is more visible
  ["?"]  = "?",   -- untracked
}

function M.get_color(status)
  if status == "M" then
    return style.git_modified or { 0xb8, 0x9a, 0x50, 0xff }
  elseif status == "A" then
    return style.git_added    or { 0x5a, 0x9a, 0x5a, 0xff }
  elseif status == "D" then
    return style.git_deleted  or { 0xb8, 0x50, 0x50, 0xff }
  elseif status == "U" then
    return style.git_conflict or { 0xd0, 0x60, 0x40, 0xff }
  elseif status == "R" or status == "C" then
    return style.git_renamed  or style.accent
  elseif status == "?" then
    return style.git_untracked or style.dim
  else
    return style.accent
  end
end

return M
