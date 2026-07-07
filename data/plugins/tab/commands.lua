
local command = require "core.input.command"
local core    = require "core"
local M       = require "plugins.tab.manager"

command.add(nil, {
  -- ── lifecycle ──────────────────────────────────────────────────────────
  ["tab:new"]           = function() M.create() end,
  ["tab:close"]         = function() M.close(M.active_id, false) end,
  ["tab:close-force"]   = function() M.close(M.active_id, true) end,
  ["tab:close-others"]  = function() M.close_others() end,
  ["tab:close-all"]     = function() M.close_all() end,
  ["tab:reopen-closed"] = function() M.reopen_closed() end,
  ["tab:duplicate"]     = function() M.duplicate() end,
  ["tab:pin"]           = function() M.pin(M.active_id) end,

  ["tab:rename"] = function()
    local tab = M.get_active()
    if not tab then return end
    core.command_view:enter("Rename Tab", function(name)
      if name and name ~= "" then M.rename(tab.id, name) end
    end, nil, nil, tab.name)
  end,

  -- ── navigation ────────────────────────────────────────────────────────
  ["tab:next"]    = function() M.next() end,
  ["tab:prev"]    = function() M.prev() end,
  ["tab:first"]   = function() M.first() end,
  ["tab:last"]    = function() M.last() end,

  ["tab:go-1"]    = function() M.go_to(1) end,
  ["tab:go-2"]    = function() M.go_to(2) end,
  ["tab:go-3"]    = function() M.go_to(3) end,
  ["tab:go-4"]    = function() M.go_to(4) end,
  ["tab:go-5"]    = function() M.go_to(5) end,
  ["tab:go-6"]    = function() M.go_to(6) end,
  ["tab:go-7"]    = function() M.go_to(7) end,
  ["tab:go-8"]    = function() M.go_to(8) end,
  ["tab:go-9"]    = function() M.go_to(9) end,

  -- ── reorder ───────────────────────────────────────────────────────────
  ["tab:move-left"] = function()
    local idx = M.get_index(M.active_id)
    if idx then M.move(M.active_id, idx - 1) end
  end,
  ["tab:move-right"] = function()
    local idx = M.get_index(M.active_id)
    if idx then M.move(M.active_id, idx + 1) end
  end,

  -- ── session ───────────────────────────────────────────────────────────
  ["tab:session-save"] = function()
    local s = require "plugins.tab.session"
    if s.save() then core.log("tab-session: saved") end
  end,
})
