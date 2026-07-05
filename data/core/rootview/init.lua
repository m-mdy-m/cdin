local core    = require "core"
local common  = require "core.utils.common"
local View    = require "core.views.view"
local DocView = require "core.views.docview"
local Node    = require "core.rootview.node"

local RootView = View:extend()

function RootView:new()
  RootView.super.new(self)
  self.root_node     = Node()
  self.deferred_draws = {}
  self.mouse         = { x = 0, y = 0 }
end

function RootView:defer_draw(fn, ...)
  table.insert(self.deferred_draws, 1, { fn = fn, ... })
end

function RootView:get_active_node()
  return self.root_node:get_node_for_view(core.active_view)
end

function RootView:open_doc(doc)
  local node = self:get_active_node()

  if node.locked then
    if core.last_active_view then
      local last_node = self.root_node:get_node_for_view(core.last_active_view)
      if last_node and not last_node.locked then
        core.set_active_view(core.last_active_view)
        node = last_node
      end
    end

    if node.locked then
      local function find_unlocked(n)
        if n.type == "leaf" then return (not n.locked) and n or nil end
        return find_unlocked(n.a) or find_unlocked(n.b)
      end
      local unlocked = find_unlocked(self.root_node)
      if unlocked then
        node = unlocked
        core.set_active_view(node.active_view)
      end
    end
  end

  if node.locked then
    core.log("Cannot open doc: no unlocked editor node available")
    return
  end

  for i, view in ipairs(node.views) do
    if view.doc == doc then
      node:set_active_view(node.views[i])
      return view
    end
  end

  local view = DocView(doc)
  node:add_view(view)
  self.root_node:update_layout()
  view:scroll_to_line(view.doc:get_selection(), true, true)
  return view
end

function RootView:on_mouse_pressed(button, x, y, clicks)
  local div = self.root_node:get_divider_overlapping_point(x, y)
  if div then
    self.dragged_divider = div
    return
  end

  local node = self.root_node:get_child_overlapping_point(x, y)

  local close_idx = node:get_tab_close_overlapping_point(x, y)
  if close_idx then
    node:set_active_view(node.views[close_idx])
    node:close_active_view(self.root_node)
    return
  end

  local idx = node:get_tab_overlapping_point(x, y)
  if idx then
    node:set_active_view(node.views[idx])
    if button == "middle" then
      node:close_active_view(self.root_node)
    end
  else
    core.set_active_view(node.active_view)
    node.active_view:on_mouse_pressed(button, x, y, clicks)
  end
end

function RootView:on_mouse_released(...)
  self.dragged_divider = nil
  self.root_node:on_mouse_released(...)
end

function RootView:on_mouse_moved(x, y, dx, dy)
  if self.dragged_divider then
    local node = self.dragged_divider
    if node.type == "hsplit" then
      node.divider = node.divider + dx / node.size.x
    else
      node.divider = node.divider + dy / node.size.y
    end
    node.divider = common.clamp(node.divider, 0.01, 0.99)
    return
  end

  self.mouse.x, self.mouse.y = x, y
  self.root_node:on_mouse_moved(x, y, dx, dy)

  local node = self.root_node:get_child_overlapping_point(x, y)
  local div  = self.root_node:get_divider_overlapping_point(x, y)
  if div then
    system.set_cursor(div.type == "hsplit" and "sizeh" or "sizev")
  elseif node:get_tab_overlapping_point(x, y) then
    system.set_cursor("arrow")
  else
    system.set_cursor(node.active_view.cursor)
  end
end

function RootView:on_mouse_wheel(...)
  local node = self.root_node:get_child_overlapping_point(self.mouse.x, self.mouse.y)
  node.active_view:on_mouse_wheel(...)
end

function RootView:on_text_input(...)
  core.active_view:on_text_input(...)
end


function RootView:update()
  self.root_node.position.x = self.position.x
  self.root_node.position.y = self.position.y
  self.root_node.size.x     = self.size.x
  self.root_node.size.y     = self.size.y
  self.root_node:update()
  self.root_node:update_layout()
end

function RootView:draw()
  self.root_node:draw()
  while #self.deferred_draws > 0 do
    local t = table.remove(self.deferred_draws)
    t.fn(table.unpack(t))
  end
end

return RootView