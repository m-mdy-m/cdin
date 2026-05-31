-- statusview.lua  (VEX-patched)
-- Shows:  left -> mode pill | filename | line:col | %
--         right -> total lines | encoding
-- Mode pill: NORMAL / INSERT / VISUAL / COMMAND  -- matches VEX statusline

local core    = require "core"
local common  = require "core.common"
local command = require "core.command"
local config  = require "core.config"
local style   = require "core.style"
local DocView = require "core.docview"
local LogView = require "core.logview"
local View    = require "core.view"

local StatusView = View:extend()

StatusView.separator  = "  "
StatusView.separator2 = "  |  "

-- mode colours (from VEX palette)
local mode_colors = {
  NORMAL  = common.color "#3a3a3a",   -- subtle grey bg
  INSERT  = common.color "#1a2a1a",   -- dim green
  VISUAL  = common.color "#2a2a1a",   -- dim amber
  COMMAND = common.color "#1a1a2a",   -- dim violet
}
local mode_fg = common.color "#d0d0d0"

function StatusView:new()
  StatusView.super.new(self)
  self.message_timeout = 0
  self.message = {}
end

function StatusView:on_mouse_pressed()
  core.set_active_view(core.last_active_view)
  if system.get_time() < self.message_timeout
  and not core.active_view:is(LogView) then
    command.perform "core:open-log"
  end
end

function StatusView:show_message(icon, icon_color, text)
  self.message = {
    icon_color, style.icon_font, icon,
    style.dim, style.font, StatusView.separator2, style.text, text
  }
  self.message_timeout = system.get_time() + config.message_timeout
end

function StatusView:update()
  self.size.y = style.font:get_height() + style.padding.y * 2

  if system.get_time() < self.message_timeout then
    self.scroll.to.y = self.size.y
  else
    self.scroll.to.y = 0
  end

  StatusView.super.update(self)
end

local function draw_items(self, items, x, y, draw_fn)
  local font  = style.font
  local color = style.text
  for _, item in ipairs(items) do
    if type(item) == "userdata" then
      font = item
    elseif type(item) == "table" then
      color = item
    else
      x = draw_fn(font, color, item, nil, x, y, 0, self.size.y)
    end
  end
  return x
end

local function text_width(font, _, text, _, x)
  return x + font:get_width(text)
end

function StatusView:draw_items(items, right_align, yoffset)
  local x, y = self:get_content_offset()
  y = y + (yoffset or 0)
  if right_align then
    local w = draw_items(self, items, 0, 0, text_width)
    x = x + self.size.x - w - style.padding.x
    draw_items(self, items, x, y, common.draw_text)
  else
    x = x + style.padding.x
    draw_items(self, items, x, y, common.draw_text)
  end
end

-- -- mode pill -------------------------------------------------------------

local function current_mode_label()
  local cv = core.command_view
  if cv and cv == core.active_view then
    if cv.vim_mode then return "COMMAND" end
    return "COMMAND"
  end
  -- cdin uses the C engine's editor mode; surface it if exported
  -- fallback: INSERT when active_view is a DocView and in text input mode
  -- (full modal state would need a Lua-C bridge; for now show NORMAL/INSERT)
  if core.active_view and core.active_view:is(DocView) then
    return "NORMAL"   -- will be extended once editor.mode is bridged to Lua
  end
  return "NORMAL"
end

local function draw_mode_pill(self, x, y)
  local label = current_mode_label()
  local bg    = mode_colors[label] or mode_colors.NORMAL
  local fw    = style.font:get_width(label)
  local ph    = style.padding.x
  local ph_y  = style.padding.y
  local bh    = self.size.y
  -- draw pill background
  renderer.draw_rect(x, y, fw + ph * 2, bh, bg)
  -- draw label text
  renderer.draw_text(style.font, mode_fg, label, x + ph, y + ph_y)
  return x + fw + ph * 2 + style.padding.x
end

function StatusView:get_items()
  if getmetatable(core.active_view) == DocView then
    local dv   = core.active_view
    local line, col = dv.doc:get_selection()
    local dirty = dv.doc:is_dirty()

    return {
      dirty and style.accent or style.dim, style.icon_font, "f",
      style.dim, style.font, self.separator2,
      dv.doc.filename and style.text or style.dim, dv.doc:get_name(),
      style.text,
      self.separator,
      style.dim, tostring(line), style.text, ":", style.dim, tostring(col),
      style.text,
      self.separator,
      string.format("%d%%", math.floor(line / #dv.doc.lines * 100)),
    }, {
      style.icon_font, "g",
      style.font, style.dim, self.separator2, style.text,
      #dv.doc.lines, " lines",
      self.separator,
      dv.doc.crlf and "CRLF" or "LF"
    }
  end

  return {}, {
    style.icon_font, "g",
    style.font, style.dim, self.separator2,
    #core.docs, style.text, " / ",
    #core.project_files, " files"
  }
end

function StatusView:draw()
  self:draw_background(style.background2)

  -- message overlay (scrolls up from below)
  if self.message then
    self:draw_items(self.message, false, self.size.y)
  end

  -- mode pill (drawn before text items, advances x)
  local ox, oy = self:get_content_offset()
  local px = draw_mode_pill(self, ox, oy)

  local left, right = self:get_items()

  -- draw left items starting after pill
  local font  = style.font
  local color = style.text
  local x, y  = px, oy
  for _, item in ipairs(left) do
    if type(item) == "userdata" then
      font = item
    elseif type(item) == "table" then
      color = item
    else
      x = common.draw_text(font, color, item, nil, x, y, 0, self.size.y)
    end
  end

  self:draw_items(right, true)
end

return StatusView
