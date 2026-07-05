local core    = require "core"
local common  = require "core.utils.common"
local command = require "core.input.command"
local config  = require "core.config"
local keymap  = require "core.input.keymap"
local style   = require "core.style"
local View    = require "core.views.view"

local Cache = require "plugins.treeview.cache"
local Git   = require "plugins.treeview.git"
local Nav   = require "plugins.treeview.nav"

config.treeview_size            = 200 * SCALE
config.show_hidden_files        = true
config.treeview_git_enabled     = true
config.treeview_git_update_rate = 2

if config.show_hidden_files then
  config.ignore_files = "^$"
end

local TreeView = View:extend()

function TreeView:new()
  TreeView.super.new(self)
  self.scrollable        = true
  self.visible           = true
  self.init_size         = true
  self.selected          = {}
  self.last_clicked      = nil
  self.cursor_item       = nil
  self._last_project_files = nil
end

function TreeView:get_name() return "Project" end

function TreeView:get_item_height()
  return style.font:get_height() + style.padding.y
end

function TreeView:get_cached(item)
  if core.project_files ~= self._last_project_files then
    Cache.invalidate_skips()
    self._last_project_files = core.project_files
  end
  return Cache.get(item)
end
function TreeView:each_item()
  return coroutine.wrap(function()
    local ox, oy = self:get_content_offset()
    local y = oy + style.padding.y
    local w = self.size.x
    local h = self:get_item_height()
    local i = 1

    while i <= #core.project_files do
      local item   = core.project_files[i]
      local cached = self:get_cached(item)

      coroutine.yield(cached, ox, y, w, h)
      y = y + h
      i = i + 1

      if not cached.expanded then
        if cached.skip then
          i = cached.skip
        else
          local depth = cached.depth
          while i <= #core.project_files do
            if (function(fn)
                  local n = 0
                  for _ in fn:gmatch("[\\/]") do n = n + 1 end
                  return n
                end)(core.project_files[i].filename) <= depth then
              break
            end
            i = i + 1
          end
          cached.skip = i
        end
      end
    end
  end)
end
function TreeView:on_mouse_moved(px, py, ...)
  TreeView.super.on_mouse_moved(self, px, py, ...)
  self.hovered_item = nil
  for item, x, y, w, h in self:each_item() do
    if px > x and py > y and px <= x+w and py <= y+h then
      self.hovered_item = item
      break
    end
  end
  self.cursor = self.hovered_item and "hand" or "arrow"
end

function TreeView:toggle_select(item, additive)
  if not additive then self.selected = {} end
  if self.selected[item.abs_filename] then
    self.selected[item.abs_filename] = nil
  else
    self.selected[item.abs_filename] = item
  end
end

function TreeView:on_mouse_pressed(button, x, y, clicks)
  if TreeView.super.on_mouse_pressed(self, button, x, y, clicks) then return true end
  if not self.hovered_item then
    if not keymap.modkeys.ctrl and not keymap.modkeys.shift then
      self.selected = {}
    end
    return
  end

  local item = self.hovered_item
  self.cursor_item = item

  if keymap.modkeys.ctrl then
    self:toggle_select(item, true)
    return
  elseif keymap.modkeys.shift and self.last_clicked then
    local items, in_range = {}, false
    for it in self:each_item() do
      if it == self.last_clicked or it == item then
        in_range = not in_range or it == item
        items[#items+1] = it
      elseif in_range then
        items[#items+1] = it
      end
    end
    self.selected = {}
    for _, it in ipairs(items) do self.selected[it.abs_filename] = it end
    return
  end

  self.selected     = { [item.abs_filename] = item }
  self.last_clicked = item

  if item.type == "dir" then
    item.expanded = not item.expanded
  else
    core.try(function()
      core.root_view:open_doc(core.open_doc(item.filename))
    end)
  end
end

function TreeView:get_item_list()       return Nav.get_item_list(self) end
function TreeView:ensure_cursor()       return Nav.ensure_cursor(self) end
function TreeView:scroll_to_cursor()    Nav.scroll_to_cursor(self) end
function TreeView:move_cursor(dir)      Nav.move_cursor(self, dir) end
function TreeView:open_cursor_item()    Nav.open_cursor_item(self) end
function TreeView:collapse_or_go_to_parent()     Nav.collapse_or_go_to_parent(self) end
function TreeView:expand_or_go_to_first_child()  Nav.expand_or_go_to_first_child(self) end

function TreeView:update()
  local dest = self.visible and config.treeview_size or 0
  if self.init_size then
    self.size.x    = dest
    self.init_size = false
  else
    self:move_towards(self.size, "x", dest)
  end
  TreeView.super.update(self)
end

function TreeView:set_locked_size(axis, value)
  if axis == "x" then config.treeview_size = value end
end

function TreeView:draw()
  self:draw_background(style.background2)

  local icon_width = style.icon_font:get_width("D")
  local spacing    = style.font:get_width(" ") * 2

  local doc = core.active_view.doc
  local active_filename = doc and system.absolute_path(doc.filename or "")

  for item, x, y, w, h in self:each_item() do
    local color = style.text

    if item.abs_filename == active_filename then color = style.accent end

    if self.selected[item.abs_filename] then
      renderer.draw_rect(x, y, w, h, style.selection)
    end

    if item == self.cursor_item and core.active_view == self then
      renderer.draw_rect(x, y, w, h, style.line_highlight)
      renderer.draw_rect(x, y, w, math.ceil(SCALE), style.accent)
      renderer.draw_rect(x, y+h-math.ceil(SCALE), w, math.ceil(SCALE), style.accent)
    end

    if item == self.hovered_item then
      renderer.draw_rect(x, y, w, h, style.line_highlight)
      color = style.accent
    end

    local row_x = x + item.depth * style.padding.x + style.padding.x

    if item.type == "dir" then
      local icon1 = item.expanded and "-" or "+"
      local icon2 = item.expanded and "D" or "d"
      common.draw_text(style.icon_font, color, icon1, nil, row_x, y, 0, h)
      row_x = row_x + style.padding.x
      common.draw_text(style.icon_font, color, icon2, nil, row_x, y, 0, h)
      row_x = row_x + icon_width
    else
      row_x = row_x + style.padding.x
      common.draw_text(style.icon_font, color, "f", nil, row_x, y, 0, h)
      row_x = row_x + icon_width
    end

    row_x = row_x + spacing
    common.draw_text(style.font, color, item.name, nil, row_x, y, 0, h)

    if Git.root then
      local status = Git.get_status(item)
      if status then
        local icon   = Git.ICON[status] or status
        local gcolor = Git.get_color(status)
        common.draw_text(style.font, gcolor, icon, "right", x, y, w-style.padding.x, h)
      end
    end
  end
end

local view = TreeView()
local node = core.root_view:get_active_node()
node:split("left", view, true)

if config.treeview_git_enabled then
  core.add_thread(Git.thread)
end

local function selected_items()
  local t = {}
  for _, item in pairs(view.selected) do t[#t+1] = item end
  if #t == 0 and view.hovered_item then t[1] = view.hovered_item end
  return t
end

local function refresh_tree()
  Cache.flush()
  view._last_project_files = nil
  core.redraw = true
end

local function context_dir()
  local items = selected_items()
  local item  = items[1]
  if not item then return "." end
  if item.type == "dir" then return item.filename end
  return item.filename:match("^(.*)[\\/][^\\/]+$") or "."
end
command.add(nil, {
  ["treeview:toggle"] = function()
    view.visible = not view.visible
  end,

  ["treeview:focus"] = function()
    view.visible = true
    core.set_active_view(view)
    view:ensure_cursor()
    view:scroll_to_cursor()
  end,

  ["treeview:focus-and-refresh"] = function()
    command.perform("treeview:focus")
    command.perform("treeview:refresh")
  end,

  ["treeview:refresh"] = function()
    refresh_tree()
    if config.treeview_git_enabled then core.try(Git.refresh) end
  end,

  ["treeview:toggle-hidden"] = function()
    config.show_hidden_files = not config.show_hidden_files
    config.ignore_files = config.show_hidden_files and "^$" or "^%."
    refresh_tree()
  end,

  ["treeview:new-file"] = function()
    local dir = context_dir()
    core.command_view:enter("New File", function(text)
      if text == "" then return end
      local path = (dir ~= "." and dir..PATHSEP or "") .. text
      local fp = io.open(path, "r")
      if fp then fp:close(); core.error('treeview: "%s" already exists', path); return end
      fp = io.open(path, "w")
      if not fp then core.error('treeview: could not create "%s"', path); return end
      fp:close()
      refresh_tree()
      core.try(function() core.root_view:open_doc(core.open_doc(path)) end)
    end, function(text)
      return common.path_suggest(dir ~= "." and dir..PATHSEP..text or text)
    end)
  end,

  ["treeview:new-directory"] = function()
    local dir = context_dir()
    core.command_view:enter("New Directory", function(text)
      if text == "" then return end
      local path = (dir ~= "." and dir..PATHSEP or "") .. text
      local ok = os.execute(PATHSEP == "\\"
        and ('mkdir "'..path..'"')
        or  ('mkdir -p "'..path..'"'))
      if not ok then core.error('treeview: could not create directory "%s"', path); return end
      refresh_tree()
    end, function(text)
      return common.path_suggest(dir ~= "." and dir..PATHSEP..text or text)
    end)
  end,

  ["treeview:rename"] = function()
    local items = selected_items()
    local item  = items[1]
    if not item then return end
    core.command_view:enter("Rename", function(text)
      if text == "" or text == item.name then return end
      local parent  = item.filename:match("^(.*)[\\/][^\\/]+$") or "."
      local new_path = parent ~= "." and (parent..PATHSEP..text) or text
      local ok, err = os.rename(item.filename, new_path)
      if not ok then core.error("treeview: rename failed: %s", err or "unknown"); return end
      for _, doc in ipairs(core.docs) do
        if doc.filename and system.absolute_path(doc.filename) == item.abs_filename then
          doc.filename = new_path
        end
      end
      refresh_tree()
    end, function() return {} end)
    core.command_view:set_text(item.name, true)
  end,

  ["treeview:delete"] = function()
    local items = selected_items()
    if #items == 0 then return end
    local names = {}
    for _, it in ipairs(items) do names[#names+1] = it.name end
    local msg = (#items == 1)
      and string.format('Delete "%s"? This cannot be undone.', names[1])
      or  string.format("Delete %d items? This cannot be undone.\n%s",
            #items, table.concat(names, ", "))
    if not system.show_confirm_dialog("Delete", msg) then return end
    for _, item in ipairs(items) do
      if item.type == "dir" then
        os.execute(PATHSEP == "\\"
          and ('rmdir /s /q "'..item.filename..'"')
          or  ('rm -rf "'..item.filename..'"'))
      else
        os.remove(item.filename)
      end
    end
    view.selected = {}
    refresh_tree()
  end,
})

keymap.add {
  ["f2"]            = {"treeview:toggle", "treeview:focus-and-refresh"},
  ["f3"]            = {"treeview:focus"},
  ["f4"]            = {"find-replace:repeat-find"},
  ["ctrl+\\"]       = "treeview:toggle",
  ["ctrl+shift+e"]  = "treeview:focus",
  ["ctrl+shift+n"]  = "treeview:new-file",
  ["ctrl+shift+alt+n"] = "treeview:new-directory",
}

command.add(function() return core.active_view == view end, {
  ["treeview:rename-key"]     = function() command.perform("treeview:rename") end,
  ["treeview:delete-key"]     = function() command.perform("treeview:delete") end,
  ["treeview:refresh-key"]    = function() command.perform("treeview:refresh") end,
  ["treeview:select-previous"] = function() view:move_cursor(-1) end,
  ["treeview:select-next"]     = function() view:move_cursor(1) end,
  ["treeview:open-cursor-item"]      = function() view:open_cursor_item() end,
  ["treeview:collapse-or-parent"]    = function() view:collapse_or_go_to_parent() end,
  ["treeview:expand-or-child"]       = function() view:expand_or_go_to_first_child() end,
})

keymap.add {
  ["up"]            = "treeview:select-previous",
  ["down"]          = "treeview:select-next",
  ["return"]        = "treeview:open-cursor-item",
  ["keypad enter"]  = "treeview:open-cursor-item",
  ["left"]          = "treeview:collapse-or-parent",
  ["right"]         = "treeview:expand-or-child",
  ["ctrl+r"]        = "treeview:rename-key",
  ["delete"]        = "treeview:delete-key",
  ["ctrl+shift+r"]  = "treeview:refresh-key",
}