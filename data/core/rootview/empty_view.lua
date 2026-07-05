local style  = require "core.style"
local common = require "core.utils.common"
local View   = require "core.views.view"

local EmptyView = View:extend()

local function draw_text(x, y, color)
  local title    = "cdin"
  local subtitle = "a minimal & fast code editor"

  local th_title = style.big_font:get_height()
  local th_sub   = style.font:get_height()
  local dh       = th_title + th_sub + style.padding.y * 3

  local tx = x + style.padding.x
  local ty = y + style.padding.y
  local tw = renderer.draw_text(style.big_font, title, tx, ty, color)

  local line_y = ty + th_title + style.padding.y / 2
  renderer.draw_rect(tx, line_y, tw, common.round(SCALE), style.dim)

  renderer.draw_text(style.font, subtitle, tx, line_y + style.padding.y, style.dim)

  return tw, dh
end

function EmptyView:draw()
  self:draw_background(style.background)
  local w, h = draw_text(0, 0, { 0, 0, 0, 0 })
  local x = self.position.x + math.max(style.padding.x, (self.size.x - w) / 2)
  local y = self.position.y + (self.size.y - h) / 2
  draw_text(x, y, style.dim)
end

return EmptyView