local core  = require "core"
local style = require "core.style"
local M     = require "plugins.tab.manager"

require "plugins.tab.commands"

core.add_thread(function()
  coroutine.yield(0)   
  M.bootstrap()
  
  require "plugins.tab.session"
end)

local StatusView = require "core.views.statusview"
local _orig_get_items = StatusView.get_items

if _orig_get_items then
  function StatusView:get_items()
    local left, right = _orig_get_items(self)

    local total = M.get_count()
    if total < 2 then
      return left, right
    end

    local idx = M.get_index(M.active_id) or 1
    right = { table.unpack(right or {}) }
    table.insert(right, StatusView.sep)
    table.insert(right, style.dim)
    table.insert(right, "[")
    table.insert(right, style.accent)
    table.insert(right, idx)
    table.insert(right, style.dim)
    table.insert(right, "/")
    table.insert(right, total)
    table.insert(right, "]")
    table.insert(right, style.text)

    return left, right
  end
end

return M