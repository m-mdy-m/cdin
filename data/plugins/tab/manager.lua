-- Design contract
-- ───────────────
-- Each Tab has its OWN root_node (Node tree).
-- When we switch tabs we swap core.root_view.root_node and restore the saved
-- active_view.  The locked nodes (title_bar, command_view, status_view) live
-- ABOVE the editable region in the outer root and are NEVER touched.

local core   = require "core"
local Tab    = require "plugins.tab.tab"

local M = {}

M.tabs         = {}   -- { [id] = Tab }
M.tab_order    = {}   -- { id, id, … } display order
M.active_id    = nil
M.closed_stack = {}   -- for reopen-closed-tab

-- ─── helpers ────────────────────────────────────────────────────────────────

local function emit(event, payload)
  if core.emit then core.emit(event, payload) end
  core.redraw = true
end

-- Layout after setup_views + treeview:
--   root_node (vsplit)
--     a  →  title_bar  (locked)
--     b  (vsplit)
--       a  →  editor slot  ← may be split further by treeview/window
--       b  (vsplit)
--           a  →  command_view (locked)
--           b  →  status_view  (locked)
--
-- After treeview loads it splits root_node.b.a into:
--   root_node.b.a (hsplit)
--     .a  →  TreeView  (locked)   ← permanent, shared across all tabs
--     .b  →  actual editor pane   ← THIS is what each tab owns
--
-- We must ONLY swap the unlocked child, never the locked side-panels.

local function get_editor_slot()
  -- Returns (parent_node, key) so the caller can read or write parent[key].
  local rn = core.root_view.root_node
  if not (rn and rn.b and rn.b.a) then return nil, nil end
  local ea = rn.b.a
  if ea.type == "leaf" then
    -- No treeview yet; the slot is rn.b.a directly.
    return rn.b, "a"
  end
  -- ea is an hsplit (e.g. treeview on the left).
  -- Find the unlocked child — that is the per-tab editor area.
  if ea.b and not ea.b.locked then return ea, "b" end
  if ea.a and not ea.a.locked then return ea, "a" end
  -- Both locked (shouldn't happen) — fall back to the outer slot.
  return rn.b, "a"
end

local function editor_node()
  local parent, key = get_editor_slot()
  if parent then return parent[key] end
  -- Emergency fallback: first unlocked leaf in the whole tree.
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

-- ─── freeze / restore ───────────────────────────────────────────────────────

local function freeze(tab)
  if not tab then return end
  tab.root_node   = editor_node()
  tab.active_view = core.active_view
end

local function restore(tab)
  if not tab then return end

  -- swap in this tab's node tree
  set_editor_node(tab.root_node)

  -- recalc layout with current window dimensions
  core.root_view.root_node:update_layout()

  -- restore the active view
  local av = tab.active_view
  if av then
    local node = core.root_view.root_node:get_node_for_view(av)
    if node then
      node:set_active_view(av)
      return
    end
  end

  -- fallback: focus the first unlocked leaf
  local function first_unlocked_leaf(n)
    if n.type == "leaf" then return (not n.locked) and n or nil end
    return first_unlocked_leaf(n.a) or first_unlocked_leaf(n.b)
  end
  local leaf = first_unlocked_leaf(core.root_view.root_node)
  if leaf then
    leaf:set_active_view(leaf.active_view)
  end
end

-- ─── bootstrap: create the very first tab around existing state ──────────────

function M.bootstrap()
  local tab = Tab("Tab 1")
  tab.root_node   = editor_node()
  tab.active_view = core.active_view
  M.tabs[tab.id]  = tab
  table.insert(M.tab_order, tab.id)
  M.active_id = tab.id
  emit("tab:create", { id = tab.id, tab = tab })
end

-- ─── create ─────────────────────────────────────────────────────────────────

function M.create(name, activate)
  -- build a brand-new Node for the new tab
  local Node      = require "core.rootview.node"
  local EmptyView = require "core.rootview.empty_view"

  local tab  = Tab(name)
  local node = Node()   -- fresh leaf with EmptyView inside
  tab.root_node = node

  M.tabs[tab.id] = tab
  table.insert(M.tab_order, tab.id)

  emit("tab:create", { id = tab.id, tab = tab })

  if activate ~= false then
    M.activate(tab.id)
  end

  return tab.id, tab
end

-- ─── activate ───────────────────────────────────────────────────────────────

function M.activate(id)
  if not M.tabs[id] then return false end
  if M.active_id == id then return true end

  freeze(M.tabs[M.active_id])

  local prev_id = M.active_id
  M.active_id   = id

  restore(M.tabs[id])

  emit("tab:activate", { id = id, prev_id = prev_id })
  return true
end

-- ─── close ──────────────────────────────────────────────────────────────────

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

  -- save for reopen
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

  emit("tab:close", { id = id })
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

-- ─── reopen ─────────────────────────────────────────────────────────────────

function M.reopen_closed()
  if #M.closed_stack == 0 then
    core.log("tab: no closed tabs to reopen")
    return
  end
  local data = table.remove(M.closed_stack)
  local tab  = Tab(data.name)
  tab.root_node   = data.root_node
  tab.active_view = data.active_view
  M.tabs[tab.id]  = tab
  table.insert(M.tab_order, tab.id)
  emit("tab:create", { id = tab.id, tab = tab })
  M.activate(tab.id)
end

-- ─── rename ─────────────────────────────────────────────────────────────────

function M.rename(id, name)
  local tab = M.tabs[id or M.active_id]
  if not tab then return end
  tab.name = name
  emit("tab:rename", { id = tab.id, name = name })
end

-- ─── move ───────────────────────────────────────────────────────────────────

function M.move(id, to_idx)
  local from_idx = M.get_index(id)
  if not from_idx then return end
  table.remove(M.tab_order, from_idx)
  to_idx = math.max(1, math.min(to_idx, #M.tab_order + 1))
  table.insert(M.tab_order, to_idx, id)
  emit("tab:move", { id = id, index = to_idx })
  core.redraw = true
end

-- ─── pin ────────────────────────────────────────────────────────────────────

function M.pin(id, state)
  local tab = M.tabs[id or M.active_id]
  if not tab then return end
  tab.pinned = (state == nil) and (not tab.pinned) or state
  emit("tab:update", { id = tab.id, pinned = tab.pinned })
  core.redraw = true
end

-- ─── duplicate ──────────────────────────────────────────────────────────────

function M.duplicate(id)
  id = id or M.active_id
  local src = M.tabs[id]
  if not src then return end
  -- Create a new tab; re-open whatever docs were visible in src
  local new_id, new_tab = M.create(src.name .. " (copy)", true)

  -- collect filenames from src's node tree
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

  emit("tab:update", { id = new_id })
end

-- ─── navigation ─────────────────────────────────────────────────────────────

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
  -- Vim: 9gt → last tab when n > count
  local id = M.tab_order[n] or M.tab_order[#M.tab_order]
  if id then M.activate(id) end
end

function M.first()
  if M.tab_order[1] then M.activate(M.tab_order[1]) end
end

function M.last()
  if #M.tab_order > 0 then M.activate(M.tab_order[#M.tab_order]) end
end

-- ─── helpers ────────────────────────────────────────────────────────────────

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
