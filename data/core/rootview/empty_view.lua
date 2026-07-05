local core    = require "core"
local style   = require "core.style"
local common  = require "core.utils.common"
local View    = require "core.views.view"

local EmptyView = View:extend()
local function get_session()
  local ok, m = pcall(require, "plugins.core.session")
  if ok and m then return m end
  return nil
end

local function rawget_g(name)
  return rawget(_G, name)
end

local SECTION_GAP = math.floor(28 * SCALE)
local ITEM_H      = math.floor(22 * SCALE)
local KEY_COL_W   = math.floor(140 * SCALE)
local RECENT_MAX  = 7

local ICON_FILE = "f"

local SHORTCUTS = {
  { key = "ctrl+p",       desc = "Open file" },
  { key = "ctrl+shift+p", desc = "Command palette" },
  { key = "ctrl+shift+r", desc = "Recent files" },
  { key = "ctrl+n",       desc = "New document" },
  { key = ":q / :wq",    desc = "Quit / Save & Quit" },
  { key = "i / Esc",     desc = "Insert / Normal mode" },
}

function EmptyView:new()
  EmptyView.super.new(self)
  self._recent_hover = -1
end

local function draw_rect_safe(x, y, w, h, color)
  if w > 0 and h > 0 then
    renderer.draw_rect(x, y, w, h, color)
  end
end

local function draw_logo(px, py, color_title, color_sub)
  local big  = style.big_font
  local font = style.font

  local title    = "cdin"
  local subtitle = "a minimal code editor"
  local version  = "v" .. (rawget_g("CDIN_VERSION") or rawget_g("VERSION") or "dev")

  local tw = big:get_width(title)
  local th = big:get_height()
  local sw = font:get_width(subtitle)
  local sh = font:get_height()

  renderer.draw_text(big, title, px, py, color_title)

  local line_y = py + th + math.floor(style.padding.y * 0.5)
  draw_rect_safe(px, line_y, tw, common.round(SCALE), style.accent)

  local sub_y = line_y + math.floor(style.padding.y * 0.8)
  renderer.draw_text(font, subtitle, px, sub_y, color_sub)

  renderer.draw_text(font, version, px + sw + style.padding.x, sub_y, style.dim)

  local total_h = (sub_y + sh) - py
  return tw, total_h
end

local function draw_shortcuts(px, py, max_w)
  local font    = style.font
  local fh      = font:get_height()
  local mono    = style.code_font
  local title   = "Quick Reference"
  local title_w = font:get_width(title)

  renderer.draw_text(font, title, px, py, style.text)
  local underline_y = py + fh + common.round(2 * SCALE)
  draw_rect_safe(px, underline_y, title_w, common.round(SCALE), style.dim)

  local y = underline_y + math.floor(style.padding.y * 0.8)

  for _, item in ipairs(SHORTCUTS) do
    local kw = mono:get_width(item.key) + style.padding.x
    draw_rect_safe(px, y, kw, ITEM_H, style.background3)
    local ky = y + math.floor((ITEM_H - mono:get_height()) / 2)
    renderer.draw_text(mono, item.key, px + math.floor(style.padding.x / 2), ky, style.accent)

    local dy = y + math.floor((ITEM_H - fh) / 2)
    renderer.draw_text(font, item.desc, px + kw + style.padding.x, dy, style.dim)

    y = y + ITEM_H + math.floor(4 * SCALE)
  end

end
local function draw_recent(self, px, py, hover_idx)
  local session = get_session()
  if not session then return 0 end

  local recent = session.get_recent()
  if #recent == 0 then return 0 end

  local font  = style.font
  local fh    = font:get_height()
  local iconfont = style.icon_font

  local title   = "Recent Files"
  local title_w = font:get_width(title)
  renderer.draw_text(font, title, px, py, style.text)
  local underline_y = py + fh + common.round(2 * SCALE)
  draw_rect_safe(px, underline_y, title_w, common.round(SCALE), style.dim)

  local y = underline_y + math.floor(style.padding.y * 0.8)
  _recent_rects = {}

  local count = math.min(#recent, RECENT_MAX)
  for i = 1, count do
    local path     = recent[i]
    local name     = path:match("[^\\/]+$") or path
    local dir      = path:match("^(.+)[\\/][^\\/]+$") or ""
    local is_hover = (i == hover_idx)

    local row_w = font:get_width(name) + font:get_width(dir) + style.padding.x * 3 + iconfont:get_width(ICON_FILE)
    if is_hover then
      draw_rect_safe(px - math.floor(style.padding.x * 0.5), y,
                     row_w + style.padding.x, ITEM_H, style.background3)
    end

    local iy = y + math.floor((ITEM_H - iconfont:get_height()) / 2)
    renderer.draw_text(iconfont, ICON_FILE, px, iy,
                       is_hover and style.accent or style.dim)

    local ix = px + iconfont:get_width(ICON_FILE) + math.floor(style.padding.x * 0.5)
    local fy = y + math.floor((ITEM_H - fh) / 2)
    local nw = renderer.draw_text(font, name, ix, fy,
                                  is_hover and style.text or { style.text[1], style.text[2], style.text[3], 200 })

    if dir ~= "" then
      renderer.draw_text(font, "  " .. dir, ix + nw, fy, style.dim)
    end

    _recent_rects[i] = { x = px, y = y, w = 9999, h = ITEM_H, path = path }
    y = y + ITEM_H + math.floor(3 * SCALE)
  end

  return y - py
end

function EmptyView:on_mouse_moved(mx, my, ...)
  EmptyView.super.on_mouse_moved(self, mx, my, ...)
  local prev = self._recent_hover
  self._recent_hover = -1
  for i, r in ipairs(_recent_rects) do
    if mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h then
      self._recent_hover = i
      break
    end
  end
  if self._recent_hover ~= prev then
    core.redraw = true
  end
end

function EmptyView:on_mouse_pressed(btn, mx, my, ...)
  if btn == "left" then
    for i, r in ipairs(_recent_rects) do
      if mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h then
        local session = get_session()
        if session then session.open(r.path) end
        return true
      end
    end
  end
  return EmptyView.super.on_mouse_pressed(self, btn, mx, my, ...)
end

function EmptyView:draw()
  self:draw_background(style.background)

  local vx, vy   = self:get_content_offset()
  local vw, vh   = self.size.x, self.size.y

  local TWO_COL   = vw > math.floor(700 * SCALE)
  local col_gap   = math.floor(60 * SCALE)
  local pad       = math.floor(style.padding.x * 2)

  local logo_w    = style.big_font:get_width("cdin")
  local logo_h    = style.big_font:get_height() + style.font:get_height() + style.padding.y * 2

  local shortcuts_h = #SHORTCUTS * (ITEM_H + math.floor(4 * SCALE))
                    + style.font:get_height() + math.floor(style.padding.y * 0.8) + math.floor(SCALE)

  local session = get_session()
  local recent_count = 0
  if session then
    local r = session.get_recent()
    recent_count = math.min(#r, RECENT_MAX)
  end
  local recent_h = recent_count > 0
    and (recent_count * (ITEM_H + math.floor(3 * SCALE))
         + style.font:get_height() + math.floor(style.padding.y * 0.8) + math.floor(SCALE))
    or 0

  local total_h
  if TWO_COL then
    total_h = logo_h + SECTION_GAP + math.max(shortcuts_h, recent_h)
  else
    total_h = logo_h + SECTION_GAP + shortcuts_h
              + (recent_h > 0 and SECTION_GAP + recent_h or 0)
  end

  local start_y = vy + math.floor((vh - total_h) / 2)
  if start_y < vy + pad then start_y = vy + pad end

  local content_w = TWO_COL and (logo_w + col_gap + KEY_COL_W * 2)
                             or  math.min(logo_w + KEY_COL_W, vw - pad * 2)
  local start_x   = vx + math.floor((vw - content_w) / 2)
  if start_x < vx + pad then start_x = vx + pad end

  draw_logo(start_x, start_y, style.text, style.dim)

  local body_y = start_y + logo_h + SECTION_GAP

  if TWO_COL then
    draw_shortcuts(start_x, body_y, KEY_COL_W)
    if recent_count > 0 then
      local col2_x = start_x + KEY_COL_W + col_gap
      draw_recent(self, col2_x, body_y, self._recent_hover)
    end
  else
    draw_shortcuts(start_x, body_y, vw - pad * 2)
    if recent_count > 0 then
      local rec_y = body_y + shortcuts_h + SECTION_GAP
      draw_recent(self, start_x, rec_y, self._recent_hover)
    end
  end
end

return EmptyView