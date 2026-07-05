local core    = require "core"
local common  = require "core.utils.common"
local command = require "core.input.command"
local config  = require "core.config"
local style   = require "core.style"
local DocView = require "core.views.docview"
local LogView = require "core.views.logview"
local View    = require "core.views.view"

local StatusView = View:extend()

StatusView.separator  = "      "
StatusView.separator2 = "   |   "
function StatusView:new()
  StatusView.super.new(self)
  self.message_timeout = 0
  self.message         = {}
end
function StatusView:show_message(icon, icon_color, text)
  self.message = {
    icon_color, style.icon_font, icon,
    style.dim,  style.font,      StatusView.separator2,
    style.text, text,
  }
  self.message_timeout = system.get_time() + config.message_timeout
end

function StatusView:on_mouse_pressed()
  core.set_active_view(core.last_active_view)
  if system.get_time() < self.message_timeout
  and not core.active_view:is(LogView) then
    command.perform("core:open-log")
  end
end

function StatusView:update()
  self.size.y = style.font:get_height() + style.padding.y * 2
  self.scroll.to.y = (system.get_time() < self.message_timeout)
    and self.size.y or 0
  StatusView.super.update(self)
end
local function draw_items(self, items, x, y, draw_fn)
  local font, color = style.font, style.text
  for _, item in ipairs(items) do
    if type(item) == "userdata" then font  = item
    elseif type(item) == "table"    then color = item
    else x = draw_fn(font, color, item, nil, x, y, 0, self.size.y)
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
    draw_items(self, items, x + self.size.x - w - style.padding.x, y, common.draw_text)
  else
    draw_items(self, items, x + style.padding.x, y, common.draw_text)
  end
end

function StatusView:get_items()
  if getmetatable(core.active_view) == DocView then
    local dv          = core.active_view
    local line, col   = dv.doc:get_selection()
    local dirty       = dv.doc:is_dirty()

    local left = {
      dirty and style.accent or style.text, style.icon_font, "f",
      style.dim, style.font, self.separator2, style.text,
    }

    if dv.vim_mode then
      left[#left+1] = style.accent
      left[#left+1] = style.font
      left[#left+1] = "[" .. dv.vim_mode:upper() .. "]"
      left[#left+1] = style.text
      left[#left+1] = self.separator2
    end

    left[#left+1] = dv.doc.filename and style.text or style.dim
    left[#left+1] = dv.doc:get_name()
    left[#left+1] = style.text
    left[#left+1] = self.separator
    left[#left+1] = "line: "
    left[#left+1] = line
    left[#left+1] = self.separator
    left[#left+1] = col > config.line_limit and style.accent or style.text
    left[#left+1] = "col: "
    left[#left+1] = col
    left[#left+1] = style.text
    left[#left+1] = self.separator
    left[#left+1] = string.format("%d%%", math.floor(line / #dv.doc.lines * 100))

    local right = {
      style.icon_font, "g",
      style.font, style.dim, self.separator2, style.text,
      #dv.doc.lines, " lines",
      self.separator,
      dv.doc.crlf and "CRLF" or "LF",
    }
    return left, right
  end

  return {}, {
    style.icon_font, "g",
    style.font, style.dim, self.separator2,
    #core.docs, style.text, " / ",
    #core.project_files, " files",
  }
end

function StatusView:draw()
  self:draw_background(style.background2)
  if self.message then
    self:draw_items(self.message, false, self.size.y)
  end
  local left, right = self:get_items()
  self:draw_items(left)
  self:draw_items(right, true)
end

return StatusView