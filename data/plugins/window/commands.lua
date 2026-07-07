local command = require "core.input.command"
local W       = require "plugins.window.manager"
local core    = require "core"

command.add(nil, {
  -- ── split ────────────────────────────────────────────────────────────────
  ["window:split"]     = function() W.split_horizontal(false) end,
  ["window:vsplit"]    = function() W.split_vertical(false) end,
  ["window:new"]       = function() W.new_horizontal() end,
  ["window:vnew"]      = function() W.new_vertical() end,

  -- split + open file picker
  ["window:split-open"] = function()
    W.split_horizontal(true)
    core.command_view:enter("Open file", function(text, item)
      local path = item and item.path or text
      core.try(function() core.root_view:open_doc(core.open_doc(path)) end)
    end, function(text)
      return require("core.utils.common").path_suggest(text)
    end)
  end,
  ["window:vsplit-open"] = function()
    W.split_vertical(true)
    core.command_view:enter("Open file", function(text, item)
      local path = item and item.path or text
      core.try(function() core.root_view:open_doc(core.open_doc(path)) end)
    end, function(text)
      return require("core.utils.common").path_suggest(text)
    end)
  end,
  ["window:close"]     = function() W.close() end,
  ["window:only"]      = function() W.only() end,
  ["window:focus-left"]  = function() W.focus("left") end,
  ["window:focus-right"] = function() W.focus("right") end,
  ["window:focus-up"]    = function() W.focus("up") end,
  ["window:focus-down"]  = function() W.focus("down") end,
  ["window:focus-next"]  = function() W.focus_next() end,
  ["window:focus-prev"]  = function() W.focus_prev() end,
  ["window:focus-prev-window"] = function() W.focus_prev_window() end,
  ["window:focus-first"] = function() W.focus_first() end,
  ["window:focus-last"]  = function() W.focus_last() end,
  ["window:increase-width"]   = function() W.resize_width(W.RESIZE_STEP)   end,
  ["window:decrease-width"]   = function() W.resize_width(-W.RESIZE_STEP)  end,
  ["window:increase-height"]  = function() W.resize_height(W.RESIZE_STEP)  end,
  ["window:decrease-height"]  = function() W.resize_height(-W.RESIZE_STEP) end,
  ["window:equalize"]         = function() W.equalize() end,
  ["window:maximize-width"]   = function() W.maximize_width() end,
  ["window:maximize-height"]  = function() W.maximize_height() end,
})
