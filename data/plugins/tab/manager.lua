local core = require "core"

local M = {}
local _next_id = 1
local function new_tab(name)
  local id = _next_id
  _next_id  = _next_id + 1
  return {
    id          = id,
    name        = name or ("Tab " .. id),
    root_node   = nil,
    active_view = nil,
    pinned      = false,
  }
end

local function tab_display_name(tab)
  local av = tab.active_view
  if av and av.get_name then
    local ok, n = pcall(av.get_name, av)
    if ok and n and n ~= "" then return n end
  end
  return tab.name
end

M.tabs         = {}   -- { [id] = Tab }
M.tab_order    = {}   -- { id, id, … } display order
M.active_id    = nil
M.closed_stack = {}   -- for reopen-closed-tab


local function get_editor_slot()
  local rn = core.root_view.root_node
  if not (rn and rn.b and rn.b.a) then return nil, nil end
  local ea = rn.b.a
  if ea.type == "leaf" then
    return rn.b, "a"
  end
  if ea.b and not ea.b.locked then return ea, "b" end
  if ea.a and not ea.a.locked then return ea, "a" end
  return rn.b, "a"
end

local function editor_node()
  local parent, key = get_editor_slot()
  if parent then return parent[key] end
  local function find_unlocked(n)
    if n.type == "leaf" then return (not n.locked) and n or nil end
    return find_unlocked(n.a) or find_unlocked(n.b)
  end
  return find_unlocked(core.root_view.root_node)
end

local function set_editor_node(node)
  local parent, key = get_editor_slot()
  if parent then parent[key] = node end
end


local function freeze(tab)
  if not tab then return end
  tab.root_node   = editor_node()
  tab.active_view = core.active_view
end

local function restore(tab)
  if not tab then return end

  set_editor_node(tab.root_node)

  core.root_view.root_node:update_layout()

  local av = tab.active_view
  if av then
    local node = core.root_view.root_node:get_node_for_view(av)
    if node then
      node:set_active_view(av)
      return
    end
  end

  local function first_unlocked_leaf(n)
    if n.type == "leaf" then return (not n.locked) and n or nil end
    return first_unlocked_leaf(n.a) or first_unlocked_leaf(n.b)
  end
  local leaf = first_unlocked_leaf(core.root_view.root_node)
  if leaf then
    leaf:set_active_view(leaf.active_view)
  end
end


function M.bootstrap()
  local tab = new_tab("Tab 1")
  tab.root_node   = editor_node()
  tab.active_view = core.active_view
  M.tabs[tab.id]  = tab
  table.insert(M.tab_order, tab.id)
  M.active_id = tab.id
  core.redraw = true
end


function M.create(name, activate)
  local Node      = require "core.rootview.node"
  local EmptyView = require "core.rootview.empty_view"

  local tab  = new_tab(name)
  local node = Node()   -- fresh leaf with EmptyView inside
  tab.root_node = node

  M.tabs[tab.id] = tab
  table.insert(M.tab_order, tab.id)

  core.redraw = true

  if activate ~= false then
    M.activate(tab.id)
  end

  return tab.id, tab
end


function M.activate(id)
  if not M.tabs[id] then return false end
  if M.active_id == id then return true end

  freeze(M.tabs[M.active_id])

  local prev_id = M.active_id
  M.active_id   = id

  restore(M.tabs[id])

  core.redraw = true
  return true
end


function M.close(id, force)
  id = id or M.active_id
  local tab = M.tabs[id]
  if not tab then return false end

  if tab.pinned and not force then
    core.log("tab: '%s' is pinned — unpin first or use force", tab.name)
    return false
  end
  if #M.tab_order == 1 then
    core.log("tab: cannot close the last tab")
    return false
  end

  table.insert(M.closed_stack, {
    name      = tab.name,
    root_node = tab.root_node,
    active_view = tab.active_view,
  })
  if #M.closed_stack > 20 then table.remove(M.closed_stack, 1) end

  if M.active_id == id then
    local idx     = M.get_index(id)
    local next_id = M.tab_order[idx + 1] or M.tab_order[idx - 1]
    M.active_id   = nil
    M.activate(next_id)
  end

  M.tabs[id] = nil
  for i, tid in ipairs(M.tab_order) do
    if tid == id then table.remove(M.tab_order, i); break end
  end

  core.redraw = true
  return true
end

function M.close_others(keep_id)
  keep_id = keep_id or M.active_id
  for _, id in ipairs({ table.unpack(M.tab_order) }) do
    if id ~= keep_id then M.close(id, true) end
  end
end

function M.close_all()
  for _, id in ipairs({ table.unpack(M.tab_order) }) do
    M.close(id, true)
  end
end


function M.reopen_closed()
  if #M.closed_stack == 0 then
    core.log("tab: no closed tabs to reopen")
    return
  end
  local data = table.remove(M.closed_stack)
  local tab  = new_tab(data.name)
  tab.root_node   = data.root_node
  tab.active_view = data.active_view
  M.tabs[tab.id]  = tab
  table.insert(M.tab_order, tab.id)
  core.redraw = true
  M.activate(tab.id)
end


function M.rename(id, name)
  local tab = M.tabs[id or M.active_id]
  if not tab then return end
  tab.name = name
  core.redraw = true
end


function M.move(id, to_idx)
  local from_idx = M.get_index(id)
  if not from_idx then return end
  table.remove(M.tab_order, from_idx)
  to_idx = math.max(1, math.min(to_idx, #M.tab_order + 1))
  table.insert(M.tab_order, to_idx, id)
  core.redraw = true
  core.redraw = true
end


function M.pin(id, state)
  local tab = M.tabs[id or M.active_id]
  if not tab then return end
  tab.pinned = (state == nil) and (not tab.pinned) or state
  core.redraw = true
  core.redraw = true
end


function M.duplicate(id)
  id = id or M.active_id
  local src = M.tabs[id]
  if not src then return end
  -- Create a new tab; re-open whatever docs were visible in src
  local new_id, new_tab = M.create(src.name .. " (copy)", true)

  local files = {}
  local function walk(node)
    if node.type == "leaf" then
      for _, v in ipairs(node.views or {}) do
        if v.doc and v.doc.filename then
          table.insert(files, v.doc.filename)
        end
      end
    else
      if node.a then walk(node.a) end
      if node.b then walk(node.b) end
    end
  end
  if src.root_node then walk(src.root_node) end

  for _, path in ipairs(files) do
    core.try(function()
      core.root_view:open_doc(core.open_doc(path))
    end)
  end

  core.redraw = true
end


function M.next()
  local idx = M.get_index(M.active_id)
  if not idx then return end
  M.activate(M.tab_order[(idx % #M.tab_order) + 1])
end

function M.prev()
  local idx = M.get_index(M.active_id)
  if not idx then return end
  M.activate(M.tab_order[((idx - 2) % #M.tab_order) + 1])
end

function M.go_to(n)
  local id = M.tab_order[n] or M.tab_order[#M.tab_order]
  if id then M.activate(id) end
end

function M.first()
  if M.tab_order[1] then M.activate(M.tab_order[1]) end
end

function M.last()
  if #M.tab_order > 0 then M.activate(M.tab_order[#M.tab_order]) end
end


function M.get_index(id)
  for i, tid in ipairs(M.tab_order) do
    if tid == id then return i end
  end
end

function M.get_active()
  return M.tabs[M.active_id]
end

function M.get_count()
  return #M.tab_order
end

return M
