local core    = require "core"
local style   = require "core.style"
local common  = require "core.utils.common"
local View    = require "core.views.view"
local command = require "core.input.command"
local logo    = require "core.rootview.logo"

local EmptyView = View:extend()

local function get_session()
  local ok, m = pcall(require, "plugins.core.session")
  if ok and m then return m end
  return nil
end

local function rawget_g(name)
  return rawget(_G, name)
end

local SECTION_GAP  = math.floor(32 * SCALE)
local ITEM_H       = math.floor(22 * SCALE)
local COL_GAP      = math.floor(50 * SCALE)
local RECENT_MAX   = 7

local ICON_FILE = "f"
local ICON_DIR  = "d"

local SHORTCUTS = {
  { key = "↑ / ↓",        desc = "Navigate recent items",    section = true },
  { key = "Tab",           desc = "Switch Files ↔ Dirs" },
  { key = "Enter",         desc = "Open selected item" },
  { key = "Esc",           desc = "Clear selection" },
  { key = "ctrl+o",        desc = "Open file…",              section = true },
  { key = "ctrl+shift+o",  desc = "Open folder…" },
  { key = "ctrl+shift+r",  desc = "Recent files picker" },
  { key = "ctrl+shift+d",  desc = "Recent dirs picker" },
  { key = "ctrl+n",        desc = "New document" },
  -- Editor
  { key = "ctrl+p",        desc = "Command palette",         section = true },
  { key = "ctrl+shift+p",  desc = "Find file (fuzzy)" },
  { key = ":q / :wq",     desc = "Quit / Save & Quit" },
  { key = "i / Esc",      desc = "Insert / Normal mode" },
}

local function safe_open_file(raw)
  if not raw or raw == "" then return end
  raw = raw:match("^%s*(.-)%s*$")
  local abs = system.absolute_path(raw)
  if not abs then
    core.error("Cannot resolve path: %s", raw)
    return
  end
  local info = system.get_file_info(abs)
  if not info then
    core.error("File not found: %s", abs)
    return
  end
  if info.type ~= "file" then
    core.error("Not a file: %s", abs)
    return
  end
  core.try(function()
    core.root_view:open_doc(core.open_doc(abs))
  end)
end

command.add(nil, {
  ["empty-view:open-file"] = function()
    core.command_view:enter("Open File", function(text, item)
      safe_open_file((item and item.text) or text)
    end, common.path_suggest)
  end,
  ["empty-view:open-folder"] = function()
    command.perform("core:open-folder")
  end,
  ["empty-view:open-recent-files"] = function()
    command.perform("session:open-recent")
  end,
  ["empty-view:open-recent-dirs"] = function()
    command.perform("session:open-recent-dirs")
  end,
})



function EmptyView:new()
  EmptyView.super.new(self)
  self._hover_file = -1
  self._hover_dir  = -1
  self._file_rects = {}
  self._dir_rects  = {}
  self._kb_section = nil   -- "files" | "dirs" | nil
  self._kb_index   = 0
end

local function draw_rect_safe(x, y, w, h, color)
  if w > 0 and h > 0 then
    renderer.draw_rect(x, y, w, h, color)
  end
end


local function draw_logo(px, py)
  local big  = style.big_font
  local font = style.font

  local title    = "cdin"
  local subtitle = "a minimal code editor"
  local version  = "v" .. (rawget_g("CDIN_VERSION") or rawget_g("VERSION") or "dev")

  local tw = big:get_width(title)
  local th = big:get_height()
  local sw = font:get_width(subtitle)
  local sh = font:get_height()

  renderer.draw_text(big, title, px, py, style.text)

  local line_y = py + th + math.floor(style.padding.y * 0.5)
  draw_rect_safe(px, line_y, tw, common.round(SCALE), style.accent)

  local sub_y = line_y + math.floor(style.padding.y * 0.8)
  renderer.draw_text(font, subtitle, px, sub_y, style.dim)
  renderer.draw_text(font, version, px + sw + style.padding.x, sub_y, style.dim)

  local total_h = (sub_y + sh) - py
  return tw, total_h
end


local function draw_section_header(title, px, py)
  local font    = style.font
  local fh      = font:get_height()
  local title_w = font:get_width(title)

  renderer.draw_text(font, title, px, py, style.text)
  local ul_y = py + fh + common.round(2 * SCALE)
  draw_rect_safe(px, ul_y, title_w, common.round(SCALE), style.dim)

  return ul_y + math.floor(style.padding.y * 0.7)
end

local function draw_shortcuts(px, py)
  local font = style.font
  local mono = style.code_font
  local fh   = font:get_height()
  local mh   = mono:get_height()

  local y        = draw_section_header("Quick Reference", px, py)
  local first    = true

  for _, item in ipairs(SHORTCUTS) do
    if item.section and not first then
      y = y + math.floor(6 * SCALE)
    end
    first = false

    local kw = mono:get_width(item.key) + style.padding.x
    draw_rect_safe(px, y, kw, ITEM_H, style.background3)
    local ky = y + math.floor((ITEM_H - mh) / 2)
    renderer.draw_text(mono, item.key, px + math.floor(style.padding.x / 2), ky, style.accent)

    local dy = y + math.floor((ITEM_H - fh) / 2)
    renderer.draw_text(font, item.desc, px + kw + style.padding.x, dy, style.dim)

    y = y + ITEM_H + math.floor(4 * SCALE)
  end

  return y - py
end


local function draw_recent_list(self, title, items, icon, px, py, col_w, hover_idx, kb_idx, rects_out)
  if #items == 0 then return 0 end

  local font     = style.font
  local iconfont = style.icon_font
  local fh       = font:get_height()

  local y = draw_section_header(title, px, py)

  for k in pairs(rects_out) do rects_out[k] = nil end

  local count = math.min(#items, RECENT_MAX)
  for i = 1, count do
    local path = items[i]
    local name, dir_label

    local is_dir_icon = (icon == ICON_DIR)
    if is_dir_icon then
      name      = (path:match("([^\\/]+)[\\/]?$") or path) .. "/"
    else
      name      = path:match("[^\\/]+$") or path
    end
    dir_label = ""

    local is_hover = (i == hover_idx) or (i == kb_idx)

    if is_hover then
      draw_rect_safe(
        px - math.floor(style.padding.x * 0.5), y,
        col_w + style.padding.x, ITEM_H,
        style.background3
      )
    end

    local iy = y + math.floor((ITEM_H - iconfont:get_height()) / 2)
    renderer.draw_text(iconfont, icon, px, iy,
                       is_hover and style.accent or style.dim)

    local ix  = px + iconfont:get_width(icon) + math.floor(style.padding.x * 0.5)
    local fy  = y + math.floor((ITEM_H - fh) / 2)

    local name_col = is_hover and style.text
                               or { style.text[1], style.text[2], style.text[3], 200 }
    local nw = renderer.draw_text(font, name, ix, fy, name_col)

    if dir_label ~= "" then
      renderer.draw_text(font, "  " .. dir_label, ix + nw, fy, style.dim)
    end

    rects_out[i] = { x = px, y = y, w = col_w, h = ITEM_H, path = path }
    y = y + ITEM_H + math.floor(3 * SCALE)
  end

  return y - py
end


function EmptyView:on_mouse_moved(mx, my, ...)
  EmptyView.super.on_mouse_moved(self, mx, my, ...)

  local prev_f = self._hover_file
  local prev_d = self._hover_dir
  self._hover_file = -1
  self._hover_dir  = -1

  for i, r in ipairs(self._file_rects) do
    if mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h then
      self._hover_file = i
      break
    end
  end
  for i, r in ipairs(self._dir_rects) do
    if mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h then
      self._hover_dir = i
      break
    end
  end

  if self._hover_file ~= prev_f or self._hover_dir ~= prev_d then
    core.redraw = true
  end
end

function EmptyView:on_mouse_pressed(btn, mx, my, ...)
  if btn == "left" then
    for _, r in ipairs(self._dir_rects) do
      if mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h then
        local session = get_session()
        if session then session.open_dir(r.path) end
        return true
      end
    end
    for _, r in ipairs(self._file_rects) do
      if mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h then
        local session = get_session()
        if session then session.open(r.path) end
        return true
      end
    end
  end
  return EmptyView.super.on_mouse_pressed(self, btn, mx, my, ...)
end

function EmptyView:on_key_pressed(key, ...)
  local session = get_session()

  if key == "tab" then
    local files = session and session.get_recent_files() or {}
    local dirs  = session and session.get_recent_dirs()  or {}
    local fc    = math.min(#files, RECENT_MAX)
    local dc    = math.min(#dirs,  RECENT_MAX)

    if self._kb_section == "files" and dc > 0 then
      self._kb_section = "dirs"
      self._kb_index   = math.max(1, math.min(self._kb_index, dc))
    elseif self._kb_section == "dirs" and fc > 0 then
      self._kb_section = "files"
      self._kb_index   = math.max(1, math.min(self._kb_index, fc))
    elseif self._kb_section == nil then
      if fc > 0 then
        self._kb_section = "files"; self._kb_index = 1
      elseif dc > 0 then
        self._kb_section = "dirs";  self._kb_index = 1
      end
    end
    core.redraw = true
    return true
  end

  if key == "down" or key == "up" then
    local files = session and session.get_recent_files() or {}
    local dirs  = session and session.get_recent_dirs()  or {}
    local fc    = math.min(#files, RECENT_MAX)
    local dc    = math.min(#dirs,  RECENT_MAX)

    if self._kb_section == nil then
      self._kb_section = fc > 0 and "files" or (dc > 0 and "dirs" or nil)
      self._kb_index   = self._kb_section and 1 or 0
    else
      local count = (self._kb_section == "files") and fc or dc
      if key == "down" then
        self._kb_index = self._kb_index + 1
        if self._kb_index > count then
          if self._kb_section == "files" and dc > 0 then
            self._kb_section = "dirs"; self._kb_index = 1
          else
            self._kb_section = fc > 0 and "files" or "dirs"; self._kb_index = 1
          end
        end
      else
        self._kb_index = self._kb_index - 1
        if self._kb_index < 1 then
          if self._kb_section == "dirs" and fc > 0 then
            self._kb_section = "files"; self._kb_index = fc
          else
            self._kb_section = dc > 0 and "dirs" or "files"
            self._kb_index = (self._kb_section == "dirs") and dc or fc
          end
        end
      end
    end
    core.redraw = true
    return true
  end

  if key == "return" and self._kb_section and self._kb_index > 0 then
    if session then
      if self._kb_section == "files" then
        local files = session.get_recent_files()
        if files[self._kb_index] then session.open(files[self._kb_index]) end
      else
        local dirs = session.get_recent_dirs()
        if dirs[self._kb_index] then session.open_dir(dirs[self._kb_index]) end
      end
    end
    self._kb_section = nil; self._kb_index = 0
    return true
  end

  if key == "escape" then
    self._kb_section = nil; self._kb_index = 0
    core.redraw = true
    return true
  end

  return EmptyView.super.on_key_pressed(self, key, ...)
end


function EmptyView:draw()
  self:draw_background(style.background)

  local vx, vy = self:get_content_offset()
  local vw, vh = self.size.x, self.size.y

  -- watermark via logo module
  logo.draw_watermark(vx, vy, vw, vh)

  local session      = get_session()
  local recent_files = session and session.get_recent_files() or {}
  local recent_dirs  = session and session.get_recent_dirs()  or {}
  local file_count   = math.min(#recent_files, RECENT_MAX)
  local dir_count    = math.min(#recent_dirs,  RECENT_MAX)
  local has_files    = file_count > 0
  local has_dirs     = dir_count  > 0

  local font     = style.font
  local big_font = style.big_font
  local pad      = math.floor(style.padding.x * 2)

  local logo_h = big_font:get_height() + font:get_height() + style.padding.y * 2

  local sh_title_h  = font:get_height() + math.floor(style.padding.y * 0.7) + common.round(SCALE)
  local shortcuts_h = sh_title_h + #SHORTCUTS * (ITEM_H + math.floor(4 * SCALE))

  local function recent_block_h(count)
    if count == 0 then return 0 end
    local th = font:get_height() + math.floor(style.padding.y * 0.7) + common.round(SCALE)
    return th + count * (ITEM_H + math.floor(3 * SCALE))
  end

  local files_h = recent_block_h(file_count)
  local dirs_h  = recent_block_h(dir_count)

  local KEY_COL_W    = math.floor(220 * SCALE)
  local RECENT_COL_W = math.floor(220 * SCALE)

  local THREE_COL = vw > math.floor(900 * SCALE) and (has_files or has_dirs)
  local TWO_COL   = (not THREE_COL) and vw > math.floor(620 * SCALE)

  local total_h, content_w

  if THREE_COL then
    total_h   = logo_h + SECTION_GAP + math.max(shortcuts_h, math.max(files_h, dirs_h))
    content_w = KEY_COL_W + COL_GAP + RECENT_COL_W + COL_GAP + RECENT_COL_W
  elseif TWO_COL then
    local right_h = (has_files and files_h or 0)
                  + (has_files and has_dirs and SECTION_GAP or 0)
                  + (has_dirs  and dirs_h  or 0)
    total_h   = logo_h + SECTION_GAP + math.max(shortcuts_h, right_h)
    content_w = KEY_COL_W + COL_GAP + RECENT_COL_W
  else
    total_h   = logo_h + SECTION_GAP + shortcuts_h
              + (has_files and (SECTION_GAP + files_h) or 0)
              + (has_dirs  and (SECTION_GAP + dirs_h)  or 0)
    content_w = math.min(KEY_COL_W + RECENT_COL_W, vw - pad * 2)
  end

  local start_y = vy + math.floor((vh - total_h) / 2)
  if start_y < vy + pad then start_y = vy + pad end

  local start_x = vx + math.floor((vw - content_w) / 2)
  if start_x < vx + pad then start_x = vx + pad end

  draw_logo(start_x, start_y)

  local body_y = start_y + logo_h + SECTION_GAP

  local kb_fi = (self._kb_section == "files") and self._kb_index or 0
  local kb_di = (self._kb_section == "dirs")  and self._kb_index or 0

  if THREE_COL then
    draw_shortcuts(start_x, body_y)
    local col2_x = start_x + KEY_COL_W + COL_GAP
    local col3_x = col2_x + RECENT_COL_W + COL_GAP
    if has_files then
      draw_recent_list(self, "Recent Files", recent_files, ICON_FILE,
                       col2_x, body_y, RECENT_COL_W,
                       self._hover_file, kb_fi, self._file_rects)
    end
    if has_dirs then
      draw_recent_list(self, "Recent Directories", recent_dirs, ICON_DIR,
                       col3_x, body_y, RECENT_COL_W,
                       self._hover_dir, kb_di, self._dir_rects)
    end

  elseif TWO_COL then
    draw_shortcuts(start_x, body_y)
    local col2_x = start_x + KEY_COL_W + COL_GAP
    local col2_y = body_y
    if has_files then
      local used = draw_recent_list(self, "Recent Files", recent_files, ICON_FILE,
                                    col2_x, col2_y, RECENT_COL_W,
                                    self._hover_file, kb_fi, self._file_rects)
      col2_y = col2_y + used + SECTION_GAP
    end
    if has_dirs then
      draw_recent_list(self, "Recent Directories", recent_dirs, ICON_DIR,
                       col2_x, col2_y, RECENT_COL_W,
                       self._hover_dir, kb_di, self._dir_rects)
    end

  else
    draw_shortcuts(start_x, body_y)
    local next_y = body_y + shortcuts_h + SECTION_GAP
    if has_files then
      local used = draw_recent_list(self, "Recent Files", recent_files, ICON_FILE,
                                    start_x, next_y, vw - pad * 2,
                                    self._hover_file, kb_fi, self._file_rects)
      next_y = next_y + used + SECTION_GAP
    end
    if has_dirs then
      draw_recent_list(self, "Recent Directories", recent_dirs, ICON_DIR,
                       start_x, next_y, vw - pad * 2,
                       self._hover_dir, kb_di, self._dir_rects)
    end
  end
end

return EmptyView
