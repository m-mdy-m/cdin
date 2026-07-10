local core   = require "core"
local style  = require "core.style"
local common = require "core.utils.common"
local View   = require "core.views.view"

local TitleBar = View:extend()

local ICON_CLOSE    = "x"
local ICON_MINIMIZE = "-"

function TitleBar:new()
  TitleBar.super.new(self)
  self.size.y          = style.titlebar_height
  self.hovered_button  = nil
  self.last_hit_regions = nil
end

function TitleBar:get_name() return "---" end

function TitleBar:get_button_rects()
  local bw = style.titlebar_button_width
  local h  = self.size.y
  local rx = self.position.x + self.size.x
  return {
    minimize = { rx - bw*3, self.position.y, bw, h },
    maximize = { rx - bw*2, self.position.y, bw, h },
    close    = { rx - bw,   self.position.y, bw, h },
  }
end

function TitleBar:button_at(x, y)
  for name, r in pairs(self:get_button_rects()) do
    if x >= r[1] and x < r[1]+r[3] and y >= r[2] and y < r[2]+r[4] then
      return name
    end
  end
end

function TitleBar:on_mouse_moved(x, y, ...)
  TitleBar.super.on_mouse_moved(self, x, y, ...)
  self.hovered_button = self:button_at(x, y)
end

function TitleBar:on_mouse_pressed(button, x, y, clicks)
  local target = self:button_at(x, y)
  if     target == "close"    then core.quit()
  elseif target == "minimize" then system.window_minimize()
  elseif target == "maximize" then system.window_toggle_maximize()
  elseif button == "left" and clicks == 2 then system.window_toggle_maximize()
  end
  core.set_active_view(core.last_active_view or core.active_view)
  return true
end

function TitleBar:update()
  TitleBar.super.update(self)

  local r   = self:get_button_rects()
  local key = string.format("%d:%d:%d", self.size.x, self.position.x, self.position.y)
  if key ~= self.last_hit_regions then
    self.last_hit_regions = key
    system.set_hit_regions(self.size.y, { r.minimize, r.maximize, r.close })
  end
end

local function draw_square_outline(x, y, size, color)
  local t = common.round(SCALE)
  renderer.draw_rect(x,          y,          size, t,    color)
  renderer.draw_rect(x,          y+size-t,   size, t,    color)
  renderer.draw_rect(x,          y,          t,    size,  color)
  renderer.draw_rect(x+size-t,   y,          t,    size,  color)
end

function TitleBar:draw_buttons()
  local rects     = self:get_button_rects()
  local maximized = system.window_is_maximized()

  for name, r in pairs(rects) do
    local x, y, w, h = table.unpack(r)
    local hovered     = self.hovered_button == name

    if hovered then
      local hover_color = (name == "close")
        and style.titlebar_close_hover or style.titlebar_button_hover
      renderer.draw_rect(x, y, w, h, hover_color)
    end

    local icon_color = (hovered and name == "close")
      and style.text or style.titlebar_text
    local cx, cy = x + w / 2, y + h / 2

    if name == "close" then
      common.draw_text(style.icon_font, icon_color, ICON_CLOSE, "center", x, y, w, h)
    elseif name == "minimize" then
      common.draw_text(style.icon_font, icon_color, ICON_MINIMIZE, "center", x, y, w, h)
    elseif name == "maximize" then
      local size = common.round(10 * SCALE)
      if maximized then
        local off = common.round(3 * SCALE)
        draw_square_outline(cx - size/2 + off, cy - size/2 - off, size, icon_color)
        renderer.draw_rect(cx - size/2 - 1, cy - size/2 - 1, size+2, size+2, style.background2)
        draw_square_outline(cx - size/2 - off/2, cy - size/2 + off/2, size, icon_color)
      else
        draw_square_outline(cx - size/2, cy - size/2, size, icon_color)
      end
    end
  end
end
function TitleBar:draw()
  self:draw_background(style.background2)

  local focused    = system.window_has_focus()
  local title      = core.window_title or "CDIN"
  local text_color = focused and style.titlebar_text_focus or style.titlebar_text
  local bw         = style.titlebar_button_width * 3

  common.draw_text(
    style.font, text_color, title, "center",
    self.position.x, self.position.y, self.size.x - bw, self.size.y
  )

  self:draw_buttons()

  renderer.draw_rect(
    self.position.x,
    self.position.y + self.size.y - style.divider_size,
    self.size.x, style.divider_size,
    style.divider
  )
end

return TitleBar