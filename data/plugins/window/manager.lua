local core = require "core"

local W = {}


local function emit(event, payload)
  core.redraw = true
end

local function root()
  return core.root_view.root_node
end

local function active_node()
  return core.root_view.root_node:get_node_for_view(core.active_view)
end

local function collect_leaves(node, result)
  result = result or {}
  if node.type == "leaf" then
    if not node.locked then table.insert(result, node) end
  else
    collect_leaves(node.a, result)
    collect_leaves(node.b, result)
  end
  return result
end

function W.split_horizontal(open_new)
  local node = active_node()
  if not node or node.locked then return end

  local view
  if not open_new then
    local DocView = require "core.views.docview"
    local doc     = core.active_view and core.active_view.doc
    if doc then view = DocView(doc) end
  end

  node:split("down", view)
  root():update_layout()
  emit("window:split", {})
end

function W.split_vertical(open_new)
  local node = active_node()
  if not node or node.locked then return end

  local view
  if not open_new then
    local DocView = require "core.views.docview"
    local doc     = core.active_view and core.active_view.doc
    if doc then view = DocView(doc) end
  end

  node:split("right", view)
  root():update_layout()
  emit("window:vsplit", {})
end

-- :new  – horizontal split with empty buffer
function W.new_horizontal()
  local node = active_node()
  if not node or node.locked then return end
  node:split("down", nil)
  root():update_layout()
  emit("window:create", { type = "horizontal" })
end

-- :vnew  – vertical split with empty buffer
function W.new_vertical()
  local node = active_node()
  if not node or node.locked then return end
  node:split("right", nil)
  root():update_layout()
  emit("window:create", { type = "vertical" })
end


function W.close()
  local node = active_node()
  if not node or node.locked then return end
  local leaves = collect_leaves(root())
  if #leaves <= 1 then
    core.log("window: only one window open")
    return
  end

  node:close_active_view(root())
  root():update_layout()
  emit("window:close", {})
end

-- :only / Ctrl+w o  – close every window except the active one
function W.only()
  local current_view = core.active_view
  if not current_view then return end

  local leaves = collect_leaves(root())
  if #leaves <= 1 then return end
  for _, leaf in ipairs(leaves) do
    if leaf ~= active_node() then
    end
  end
  local Node = require "core.rootview.node"
  local new_leaf = Node()   -- fresh leaf (has EmptyView)
  local EmptyView = require "core.rootview.empty_view"
  new_leaf.views = {}
  table.insert(new_leaf.views, current_view)
  new_leaf.active_view = current_view
  local rn = root()
  if rn and rn.b and rn.b.a then
    rn.b.a = new_leaf
  end

  root():update_layout()
  core.set_active_view(current_view)
  emit("window:close", { type = "only" })
end
local function find_adjacent(direction)
  local cur = active_node()
  if not cur then return nil end

  local cx = cur.position.x + cur.size.x * 0.5
  local cy = cur.position.y + cur.size.y * 0.5
  local leaves = collect_leaves(root())

  local best, best_dist = nil, math.huge
  for _, leaf in ipairs(leaves) do
    if leaf ~= cur then
      local lx = leaf.position.x + leaf.size.x * 0.5
      local ly = leaf.position.y + leaf.size.y * 0.5
      local dx, dy = lx - cx, ly - cy
      local valid = false
      local TOLERANCE = 2   -- px guard against floating-point noise

      if direction == "right" then
        valid = dx > TOLERANCE and math.abs(dy) <= cur.size.y * 0.5 + leaf.size.y * 0.5
      elseif direction == "left" then
        valid = dx < -TOLERANCE and math.abs(dy) <= cur.size.y * 0.5 + leaf.size.y * 0.5
      elseif direction == "down" then
        valid = dy > TOLERANCE and math.abs(dx) <= cur.size.x * 0.5 + leaf.size.x * 0.5
      elseif direction == "up" then
        valid = dy < -TOLERANCE and math.abs(dx) <= cur.size.x * 0.5 + leaf.size.x * 0.5
      end

      if valid then
        local dist = dx * dx + dy * dy
        if dist < best_dist then
          best_dist = dist
          best = leaf
        end
      end
    end
  end
  return best
end

function W.focus(direction)
  local leaf = find_adjacent(direction)
  if leaf then
    leaf:set_active_view(leaf.active_view)
    emit("window:focus", { direction = direction })
  end
end

-- Ctrl+w w  – cycle to next window
function W.focus_next()
  local leaves = collect_leaves(root())
  if #leaves < 2 then return end
  local cur = active_node()
  for i, leaf in ipairs(leaves) do
    if leaf == cur then
      local next = leaves[(i % #leaves) + 1]
      next:set_active_view(next.active_view)
      return
    end
  end
end

-- Ctrl+w W  – cycle to previous window
function W.focus_prev()
  local leaves = collect_leaves(root())
  if #leaves < 2 then return end
  local cur = active_node()
  for i, leaf in ipairs(leaves) do
    if leaf == cur then
      local prev = leaves[((i - 2) % #leaves) + 1]
      prev:set_active_view(prev.active_view)
      return
    end
  end
end

-- Ctrl+w p  – jump to previous (last-active) window
function W.focus_prev_window()
  if core.last_active_view then
    local leaf = root():get_node_for_view(core.last_active_view)
    if leaf and not leaf.locked then
      leaf:set_active_view(core.last_active_view)
    end
  end
end

-- Ctrl+w t  – top-left window
function W.focus_first()
  local leaves = collect_leaves(root())
  if leaves[1] then leaves[1]:set_active_view(leaves[1].active_view) end
end

-- Ctrl+w b  – bottom-right window
function W.focus_last()
  local leaves = collect_leaves(root())
  if #leaves > 0 then
    local l = leaves[#leaves]
    l:set_active_view(l.active_view)
  end
end


local RESIZE_STEP = 0.05

local function find_split_parent(target, split_type)
  local function walk(n)
    if n.type == "leaf" then return nil end
    if (n.a == target or n.b == target) and n.type == split_type then
      return n
    end
    return walk(n.a) or walk(n.b)
  end
  return walk(root())
end

function W.resize_width(delta)
  local node   = active_node()
  local parent = find_split_parent(node, "hsplit")
  if not parent then return end
  local d = (parent.a == node) and delta or -delta
  parent.divider = math.max(0.1, math.min(0.9, parent.divider + d))
  root():update_layout()
  emit("window:resize", {})
end

function W.resize_height(delta)
  local node   = active_node()
  local parent = find_split_parent(node, "vsplit")
  if not parent then return end
  local d = (parent.a == node) and delta or -delta
  parent.divider = math.max(0.1, math.min(0.9, parent.divider + d))
  root():update_layout()
  emit("window:resize", {})
end

function W.equalize()
  local function reset(n)
    if n.type == "leaf" then return end
    n.divider = 0.5
    reset(n.a); reset(n.b)
  end
  reset(root())
  root():update_layout()
  emit("window:resize", { type = "equalize" })
end

function W.maximize_width()
  local node   = active_node()
  local parent = find_split_parent(node, "hsplit")
  if not parent then return end
  parent.divider = (parent.a == node) and 0.9 or 0.1
  root():update_layout()
end

function W.maximize_height()
  local node   = active_node()
  local parent = find_split_parent(node, "vsplit")
  if not parent then return end
  parent.divider = (parent.a == node) and 0.9 or 0.1
  root():update_layout()
end

W.RESIZE_STEP = RESIZE_STEP
return W
