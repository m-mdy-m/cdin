local core = require "core"
local style = require "core.style"
local DocView = require "core.views.docview"
local command = require "core.input.command"
local common = require "core.utils.common"


local t = {
  ["root:close"] = function()
    local node = core.root_view:get_active_node()
    node:close_active_view(core.root_view.root_node)
  end,

  -- Renamed from root:switch-to-{previous,next}-tab / root:move-tab-*.
  -- These operate on node.views — the list of open views/buffers within
  -- the *currently active split pane* (rootview/node.lua) — which is a
  -- different, lower-level thing than plugins.'s whole-layout
  -- freeze/restore "tab" concept (data/plugins/tab/manager.lua). Both used
  -- the word "tab" for their own, unrelated notion of it, which made it
  -- impossible to tell from a command name alone which system a given
  -- "tab" command belonged to. The old names are kept below as aliases
  -- so existing keymaps/scripts referencing them keep working.
  ["root:switch-to-previous-pane-view"] = function()
    local node = core.root_view:get_active_node()
    local idx = node:get_view_idx(core.active_view)
    idx = idx - 1
    if idx < 1 then idx = #node.views end
    node:set_active_view(node.views[idx])
  end,

  ["root:switch-to-next-pane-view"] = function()
    local node = core.root_view:get_active_node()
    local idx = node:get_view_idx(core.active_view)
    idx = idx + 1
    if idx > #node.views then idx = 1 end
    node:set_active_view(node.views[idx])
  end,

  ["root:move-pane-view-left"] = function()
    local node = core.root_view:get_active_node()
    local idx = node:get_view_idx(core.active_view)
    if idx > 1 then
      table.remove(node.views, idx)
      table.insert(node.views, idx - 1, core.active_view)
    end
  end,

  ["root:move-pane-view-right"] = function()
    local node = core.root_view:get_active_node()
    local idx = node:get_view_idx(core.active_view)
    if idx < #node.views then
      table.remove(node.views, idx)
      table.insert(node.views, idx + 1, core.active_view)
    end
  end,

  ["root:shrink"] = function()
    local node = core.root_view:get_active_node()
    local parent = node:get_parent_node(core.root_view.root_node)
    local n = (parent.a == node) and -0.1 or 0.1
    parent.divider = common.clamp(parent.divider + n, 0.1, 0.9)
  end,

  ["root:grow"] = function()
    local node = core.root_view:get_active_node()
    local parent = node:get_parent_node(core.root_view.root_node)
    local n = (parent.a == node) and 0.1 or -0.1
    parent.divider = common.clamp(parent.divider + n, 0.1, 0.9)
  end,
}

t["root:switch-to-previous-tab"] = t["root:switch-to-previous-pane-view"]
t["root:switch-to-next-tab"]     = t["root:switch-to-next-pane-view"]
t["root:move-tab-left"]          = t["root:move-pane-view-left"]
t["root:move-tab-right"]         = t["root:move-pane-view-right"]


for i = 1, 9 do
  t["root:switch-to-pane-view-" .. i] = function()
    local node = core.root_view:get_active_node()
    local view = node.views[i]
    if view then
      node:set_active_view(view)
    end
  end
  t["root:switch-to-tab-" .. i] = t["root:switch-to-pane-view-" .. i]
end


for _, dir in ipairs { "left", "right", "up", "down" } do
  t["root:split-" .. dir] = function()
    local node = core.root_view:get_active_node()
    local av = node.active_view
    node:split(dir)
    if av:is(DocView) then
      core.root_view:open_doc(av.doc)
    end
  end

  t["root:switch-to-" .. dir] = function()
    local node = core.root_view:get_active_node()
    local x, y
    if dir == "left" or dir == "right" then
      y = node.position.y + node.size.y / 2
      x = node.position.x + (dir == "left" and -1 or node.size.x + style.divider_size)
    else
      x = node.position.x + node.size.x / 2
      y = node.position.y + (dir == "up"   and -1 or node.size.y + style.divider_size)
    end
    local node = core.root_view.root_node:get_child_overlapping_point(x, y)
    if not node:get_locked_size() then
      core.set_active_view(node.active_view)
    end
  end
end

command.add(function()
  local node = core.root_view:get_active_node()
  return not node:get_locked_size()
end, t)