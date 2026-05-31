-- core.titlebar — the window has no OS decorations (see src/core/windows.c),
-- so this draws cdin's own slim, VSCode-style caption bar: a draggable
-- strip with the window title, and minimize / maximize / close buttons.
--
-- The actual "is this pixel draggable or a button" decision is made in C
-- via SDL_HitTest; every update() we tell it where the buttons currently
-- are (system.set_hit_regions) so OS-level window dragging and resizing
-- keep working even though there's no OS title bar.

local core = require "core"
local style = require "core.style"
local common = require "core.common"
local View = require "core.view"

local TitleBar = View:extend()

-- icons.ttf maps these ASCII letters to glyphs; see data/fonts/icons.ttf
local ICON_CLOSE = "x"
local ICON_MINIMIZE = "-"


function TitleBar:new()
  TitleBar.super.new(self)
  self.size.y = style.titlebar_height
  self.hovered_button = nil
  self.last_hit_regions = nil
end


function TitleBar:get_name()
  return "---"
end


-- Buttons are laid out from the right edge, Windows/Linux VSCode style:
-- [ minimize ] [ maximize/restore ] [ close ]
function TitleBar:get_button_rects()
  local bw = style.titlebar_button_width
  local h = self.size.y
  local x = self.position.x + self.size.x
  local close_x = x - bw
  local max_x = close_x - bw
  local min_x = max_x - bw
  return {
    minimize = { min_x, self.position.y, bw, h },
    maximize = { max_x, self.position.y, bw, h },
    close    = { close_x, self.position.y, bw, h },
  }
end


function TitleBar:button_at(x, y)
  for name, r in pairs(self:get_button_rects()) do
    if x >= r[1] and x < r[1] + r[3] and y >= r[2] and y < r[2] + r[4] then
      return name
    end
  end
  return nil
end


function TitleBar:on_mouse_moved(x, y, ...)
  TitleBar.super.on_mouse_moved(self, x, y, ...)
  self.hovered_button = self:button_at(x, y)
end


function TitleBar:on_mouse_pressed(button, x, y, clicks)
  local target = self:button_at(x, y)
  if target == "close" then
    core.quit()
  elseif target == "minimize" then
    system.window_minimize()
  elseif target == "maximize" then
    system.window_toggle_maximize()
  elseif button == "left" and clicks == 2 then
    -- double-click on the bare drag area toggles maximize, same as
    -- VSCode / most native title bars
    system.window_toggle_maximize()
  end
  -- clicking the title bar shouldn't steal editing focus away from
  -- whatever document the user was working on
  core.set_active_view(core.last_active_view or core.active_view)
  return true
end


function TitleBar:update()
  TitleBar.super.update(self)

  local rects = self:get_button_rects()
  local regions = {
    rects.minimize, rects.maximize, rects.close,
  }

  -- avoid spamming the C side every single frame when nothing moved
  local key = string.format("%d:%d:%d", self.size.x, self.position.x, self.position.y)
  if key ~= self.last_hit_regions then
    self.last_hit_regions = key
    system.set_hit_regions(self.size.y, regions)
  end
end


local function draw_square_outline(x, y, size, color)
  local t = common.round(SCALE)
  renderer.draw_rect(x, y, size, t, color)
  renderer.draw_rect(x, y + size - t, size, t, color)
  renderer.draw_rect(x, y, t, size, color)
  renderer.draw_rect(x + size - t, y, t, size, color)
end


function TitleBar:draw_buttons()
  local rects = self:get_button_rects()
  local maximized = system.window_is_maximized()

  for name, r in pairs(rects) do
    local x, y, w, h = table.unpack(r)
    if self.hovered_button == name then
      local hover_color = (name == "close") and style.titlebar_close_hover
                                              or style.titlebar_button_hover
      renderer.draw_rect(x, y, w, h, hover_color)
    end

    local cx, cy = x + w / 2, y + h / 2
    local icon_color = (self.hovered_button == name and name == "close")
        and style.text or style.titlebar_text

    if name == "close" then
      common.draw_text(style.icon_font, icon_color, ICON_CLOSE, "center", x, y, w, h)
    elseif name == "minimize" then
      common.draw_text(style.icon_font, icon_color, ICON_MINIMIZE, "center", x, y, w, h)
    elseif name == "maximize" then
      local size = common.round(10 * SCALE)
      if maximized then
        local back_off = common.round(3 * SCALE)
        draw_square_outline(cx - size / 2 + back_off, cy - size / 2 - back_off, size, icon_color)
        -- mask the corner of the back square that the front one covers
        renderer.draw_rect(
          cx - size / 2 - 1, cy - size / 2 - 1,
          size + 2, size + 2, style.background2
        )
        draw_square_outline(cx - size / 2 - back_off / 2, cy - size / 2 + back_off / 2, size, icon_color)
      else
        draw_square_outline(cx - size / 2, cy - size / 2, size, icon_color)
      end
    end
  end
end


function TitleBar:draw()
  self:draw_background(style.background2)

  local focused = system.window_has_focus()
  local title = core.window_title or "cdin"
  local text_color = focused and style.titlebar_text_focus or style.titlebar_text

  -- title, centered in the draggable area (left of the buttons)
  local bw = style.titlebar_button_width * 3
  local avail_w = self.size.x - bw
  common.draw_text(
    style.font, text_color, title, "center",
    self.position.x, self.position.y, avail_w, self.size.y
  )

  self:draw_buttons()

  renderer.draw_rect(
    self.position.x, self.position.y + self.size.y - style.divider_size,
    self.size.x, style.divider_size, style.divider
  )
end


return TitleBar