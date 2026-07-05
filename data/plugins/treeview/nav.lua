local core   = require "core"
local common = require "core.utils.common"

local M = {}

local function dirname(path)
  return path:match("^(.*)[\\/][^\\/]+$") or "."
end

function M.ensure_cursor(view)
  local list = M.get_item_list(view)
  if #list == 0 then
    view.cursor_item = nil
    return nil
  end
  for _, item in ipairs(list) do
    if item == view.cursor_item then return item end
  end
  local doc = core.active_view and core.active_view.doc
  local active_filename = doc and system.absolute_path(doc.filename or "")
  if active_filename then
    for _, item in ipairs(list) do
      if item.abs_filename == active_filename then
        view.cursor_item = item
        return item
      end
    end
  end
  view.cursor_item = list[1]
  return view.cursor_item
end

function M.get_item_list(view)
  local list = {}
  for item in view:each_item() do
    list[#list + 1] = item
  end
  return list
end

function M.scroll_to_cursor(view)
  if not view.cursor_item then return end
  local h = view:get_item_height()
  for item, x, y in view:each_item() do
    if item == view.cursor_item then
      local doc_y = y - view.position.y + view.scroll.y
      if doc_y < view.scroll.to.y then
        view.scroll.to.y = doc_y
      elseif doc_y + h > view.scroll.to.y + view.size.y then
        view.scroll.to.y = doc_y + h - view.size.y
      end
      return
    end
  end
end

function M.move_cursor(view, dir)
  local list = M.get_item_list(view)
  if #list == 0 then return end
  M.ensure_cursor(view)
  local idx = 1
  for i, item in ipairs(list) do
    if item == view.cursor_item then idx = i; break end
  end
  idx = common.clamp(idx + dir, 1, #list)
  view.cursor_item = list[idx]
  M.scroll_to_cursor(view)
  core.redraw = true
end

function M.open_cursor_item(view)
  local item = M.ensure_cursor(view)
  if not item then return end
  if item.type == "dir" then
    item.expanded = not item.expanded
    core.redraw = true
  else
    core.try(function()
      core.root_view:open_doc(core.open_doc(item.filename))
    end)
  end
end
function M.collapse_or_go_to_parent(view)
  local item = M.ensure_cursor(view)
  if not item then return end
  if item.type == "dir" and item.expanded then
    item.expanded = false
    core.redraw = true
    return
  end
  local parent_dir = dirname(item.filename)
  if parent_dir == "." then return end
  local list = M.get_item_list(view)
  for _, it in ipairs(list) do
    if it.filename == parent_dir then
      view.cursor_item = it
      M.scroll_to_cursor(view)
      core.redraw = true
      return
    end
  end
end

function M.expand_or_go_to_first_child(view)
  local item = M.ensure_cursor(view)
  if not item then return end
  if item.type == "dir" and not item.expanded then
    item.expanded = true
    core.redraw = true
    return
  end
  if item.type == "dir" then
    M.move_cursor(view, 1)
  end
end

return M