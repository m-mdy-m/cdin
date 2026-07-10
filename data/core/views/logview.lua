local core = require "core"
local style = require "core.style"
local View = require "core.views.view"
local command = require "core.input.command"


local LogView = View:extend()


function LogView:new()
  LogView.super.new(self)
  self.last_item = core.log_items[#core.log_items]
  self.scrollable = true
  self.yoffset = 0

  self._sel_start = nil   
  self._sel_end   = nil
  self._dragging  = false
  self._line_rects = {}   
end


function LogView:get_name()
  return "Log"
end



function LogView:_build_lines()
  local lines = {}
  local th = style.font:get_height()
  for i = #core.log_items, 1, -1 do
    local item = core.log_items[i]
    local time = os.date(nil, item.time)
    
    local main = time .. "  " .. item.text .. " at " .. item.at
    table.insert(lines, main)
    if item.info then
      for ln in item.info:gmatch("[^\n]+") do
        table.insert(lines, "    " .. ln)
      end
    end
    table.insert(lines, "")   
  end
  return lines
end


function LogView:_all_text()
  local lines = self:_build_lines()
  
  while lines[#lines] == "" do table.remove(lines) end
  return table.concat(lines, "\n")
end


function LogView:update()
  local item = core.log_items[#core.log_items]
  if self.last_item ~= item then
    self.last_item = item
    self.scroll.to.y = 0
    self.yoffset = -(style.font:get_height() + style.padding.y)
    self._sel_start = nil
    self._sel_end   = nil
    self._line_rects = {}
  end

  self:move_towards("yoffset", 0)

  LogView.super.update(self)
end


local function draw_text_multiline(font, text, x, y, color)
  local th = font:get_height()
  local resx, resy = x, y
  for line in text:gmatch("[^\n]+") do
    resy = y
    resx = renderer.draw_text(font, line, x, y, color)
    y = y + th
  end
  return resx, resy
end



function LogView:_sel_range()
  if not self._sel_start or not self._sel_end then return nil, nil end
  local a, b = self._sel_start, self._sel_end
  if a > b then a, b = b, a end
  return a, b
end


function LogView:_copy_selection()
  local lo, hi = self:_sel_range()
  if not lo then
    
    system.set_clipboard(self:_all_text())
    core.log("Log copied to clipboard.")
    return
  end
  local lines = self:_build_lines()
  local selected = {}
  for i = lo, hi do
    table.insert(selected, lines[i] or "")
  end
  system.set_clipboard(table.concat(selected, "\n"))
end



function LogView:_line_at_y(my)
  for i, r in ipairs(self._line_rects) do
    if my >= r.y and my < r.y + r.h then return i end
  end
  return nil
end


function LogView:on_mouse_pressed(btn, mx, my, clicks)
  if LogView.super.on_mouse_pressed(self, btn, mx, my, clicks) then return true end
  if btn == "left" then
    local li = self:_line_at_y(my)
    if li then
      self._sel_start = li
      self._sel_end   = li
      self._dragging  = true
      core.redraw = true
      return true
    end
  end
end


function LogView:on_mouse_moved(mx, my, dx, dy)
  LogView.super.on_mouse_moved(self, mx, my, dx, dy)
  if self._dragging then
    local li = self:_line_at_y(my)
    if li and li ~= self._sel_end then
      self._sel_end = li
      core.redraw = true
    end
  end
end


function LogView:on_mouse_released(btn, mx, my)
  LogView.super.on_mouse_released(self, btn, mx, my)
  if btn == "left" then
    self._dragging = false
    
    if self._sel_start and self._sel_start == self._sel_end then
      self._sel_start = nil
      self._sel_end   = nil
      core.redraw = true
    end
  end
end


function LogView:on_key_pressed(key, ...)
  
  if key == "a" and (system.get_scancode and true or false) then
    
  end
  return LogView.super.on_key_pressed and LogView.super.on_key_pressed(self, key, ...) or false
end


function LogView:draw()
  self:draw_background(style.background)

  local ox, oy = self:get_content_offset()
  local th = style.font:get_height()
  local y = oy + style.padding.y + self.yoffset

  local lo, hi = self:_sel_range()

  self._line_rects = {}
  local line_idx = 0

  for i = #core.log_items, 1, -1 do
    local x = ox + style.padding.x
    local item = core.log_items[i]
    local time = os.date(nil, item.time)
    local start_y = y

    line_idx = line_idx + 1
    local sel_main = lo and (line_idx >= lo and line_idx <= hi)
    if sel_main then
      renderer.draw_rect(ox, y, self.size.x, th, style.selection)
    end
    table.insert(self._line_rects, { y = y, h = th })

    x = renderer.draw_text(style.font, time, x, y, style.dim)
    x = x + style.padding.x
    local subx = x
    x, y = draw_text_multiline(style.font, item.text, x, y,
           sel_main and style.background or style.text)
    renderer.draw_text(style.font, " at " .. item.at, x, y,
           sel_main and style.background or style.dim)
    y = y + th

    if item.info then
      for ln in item.info:gmatch("[^\n]+") do
        line_idx = line_idx + 1
        local sel_ln = lo and (line_idx >= lo and line_idx <= hi)
        if sel_ln then
          renderer.draw_rect(ox, y, self.size.x, th, style.selection)
        end
        table.insert(self._line_rects, { y = y, h = th })
        renderer.draw_text(style.font, ln, subx, y,
               sel_ln and style.background or style.dim)
        y = y + th
      end
    end

    line_idx = line_idx + 1
    table.insert(self._line_rects, { y = y, h = style.padding.y })
    y = y + style.padding.y
  end

  self:draw_scrollbar()
end



command.add(function() return core.active_view and core.active_view:is(LogView) end, {
  ["log:copy-selection"] = function()
    core.active_view:_copy_selection()
  end,
  ["log:select-all"] = function()
    local lv = core.active_view
    local n = #lv._line_rects
    if n > 0 then
      lv._sel_start = 1
      lv._sel_end   = n
      core.redraw = true
    end
  end,
})


return LogView