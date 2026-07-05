local core    = require "core"
local style   = require "core.style"
local common  = require "core.utils.common"
local View    = require "core.views.view"
local keymap  = require "core.input.keymap"
local command = require "core.input.command"

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


-- ── Logo watermark data (64×64 raster of scripts/icon.svg) ──────────────────
-- Each entry: { grid_row, grid_col, run_width, r, g, b }
local LOGO_SPANS = {
  {13,18,2,83,163,183},
  {13,45,1,32,56,132},
  {14,17,1,85,166,185},
  {14,18,1,116,231,252},
  {14,19,1,105,209,229},
  {14,20,1,86,165,185},
  {14,43,1,32,57,137},
  {14,44,2,38,73,186},
  {14,46,1,31,56,136},
  {15,17,1,88,170,191},
  {15,18,1,115,229,250},
  {15,19,1,91,176,197},
  {15,20,1,116,231,252},
  {15,21,1,98,194,215},
  {15,22,1,86,161,180},
  {15,41,1,32,56,129},
  {15,42,5,35,67,170},
  {16,17,1,88,171,192},
  {16,18,1,112,223,244},
  {16,19,1,19,24,41},
  {16,20,1,45,80,97},
  {16,21,1,99,196,217},
  {16,22,1,115,229,250},
  {16,23,2,92,180,200},
  {16,39,2,32,51,121},
  {16,41,2,39,75,196},
  {16,43,2,23,35,75},
  {16,45,1,39,75,196},
  {16,46,1,31,57,140},
  {17,17,1,88,172,192},
  {17,18,1,110,218,239},
  {17,19,3,19,24,41},
  {17,22,1,63,118,137},
  {17,23,2,111,219,240},
  {17,25,1,86,166,186},
  {17,38,1,31,56,139},
  {17,39,2,36,72,185},
  {17,41,1,28,46,108},
  {17,42,3,19,25,43},
  {17,45,1,37,72,190},
  {17,46,1,31,56,140},
  {18,17,1,88,172,192},
  {18,18,1,108,213,234},
  {18,19,4,19,24,41},
  {18,23,1,28,45,62},
  {18,24,1,81,156,175},
  {18,25,1,112,223,244},
  {18,26,1,77,162,218},
  {18,27,1,89,186,235},
  {18,28,4,117,231,251},
  {18,32,3,65,142,196},
  {18,35,2,55,119,166},
  {18,37,2,46,97,194},
  {18,39,1,29,52,128},
  {18,40,5,20,27,50},
  {18,45,1,36,69,183},
  {18,46,1,31,56,140},
  {19,17,1,89,173,193},
  {19,18,1,105,209,228},
  {19,19,6,19,24,41},
  {19,25,1,59,115,143},
  {19,26,1,97,201,241},
  {19,27,5,114,228,251},
  {19,32,2,72,159,219},
  {19,34,4,80,182,250},
  {19,38,1,49,103,160},
  {19,39,6,21,28,45},
  {19,45,1,35,66,177},
  {19,46,1,31,55,141},
  {20,17,1,91,176,195},
  {20,18,1,103,202,223},
  {20,19,4,19,24,41},
  {20,23,1,32,54,71},
  {20,24,1,85,166,185},
  {20,25,4,116,230,251},
  {20,35,2,51,111,162},
  {20,37,1,70,156,214},
  {20,38,1,82,186,254},
  {20,39,1,74,167,229},
  {20,40,1,41,81,116},
  {20,41,4,19,24,41},
  {20,45,2,33,63,169},
  {21,17,1,90,176,196},
  {21,18,1,100,197,217},
  {21,19,3,19,24,41},
  {21,22,1,50,89,108},
  {21,23,3,110,219,239},
  {21,38,1,53,114,158},
  {21,39,1,68,149,206},
  {21,40,1,82,186,254},
  {21,41,1,64,140,193},
  {21,42,3,24,36,57},
  {21,45,2,32,60,162},
  {22,17,2,92,177,198},
  {22,19,2,19,24,41},
  {22,21,1,66,124,144},
  {22,22,3,116,231,252},
  {22,40,1,56,120,169},
  {22,41,2,78,176,241},
  {22,43,1,28,47,71},
  {22,44,1,19,24,41},
  {22,45,2,30,57,155},
  {23,17,2,92,180,200},
  {23,19,1,19,24,41},
  {23,20,1,62,117,137},
  {23,21,2,116,231,252},
  {23,41,1,55,110,155},
  {23,42,2,74,168,230},
  {23,44,1,27,44,67},
  {23,45,2,29,55,149},
  {24,17,1,93,181,202},
  {24,18,1,72,148,192},
  {24,19,1,44,79,96},
  {24,20,2,115,229,250},
  {24,42,1,57,110,156},
  {24,43,2,78,172,236},
  {24,45,2,31,60,149},
  {25,17,2,82,166,203},
  {25,19,1,106,210,229},
  {25,20,1,116,231,252},
  {25,43,1,56,117,164},
  {25,44,1,81,185,252},
  {25,45,1,59,129,191},
  {25,46,1,27,51,143},
  {26,17,1,75,164,227},
  {26,18,1,92,193,238},
  {26,19,2,116,231,252},
  {26,44,1,63,136,187},
  {26,45,1,82,186,254},
  {26,46,1,38,78,147},
  {27,17,1,77,169,230},
  {27,18,2,114,228,251},
  {27,45,1,63,139,192},
  {27,46,1,53,114,158},
  {28,17,1,95,199,240},
  {28,18,2,116,231,252},
  {29,17,2,113,228,251},
  {30,17,2,116,232,252},
  {31,17,2,116,231,252},
  {32,16,3,115,230,255},
  {33,16,3,117,233,255},
  {34,16,3,117,234,255},
  {35,17,2,116,231,252},
  {36,17,2,116,231,253},
  {37,17,3,116,230,251},
  {38,17,3,117,230,251},
  {39,18,2,116,231,253},
  {40,18,3,116,230,252},
  {41,19,3,116,231,252},
  {42,19,3,114,228,255},
  {43,20,3,115,231,252},
  {44,21,4,114,232,252},
  {45,22,5,117,230,251},
  {46,24,8,115,230,251},
  {46,32,6,60,146,221},
  {46,38,10,38,79,210},
  {47,26,6,115,230,253},
  {47,32,3,62,143,220},
  {47,35,3,77,175,245},
  {47,38,10,36,77,210},
  {48,29,3,117,234,255},
  {48,32,6,64,143,221},
  {48,38,10,35,75,210},
}

local function draw_logo_watermark(vx, vy, vw, vh)
  -- Size: fill ~55% of the smaller view dimension
  local GRID = 64
  local px   = math.max(2, math.floor(math.min(vw, vh) * 0.55 / GRID))
  local lw   = GRID * px
  local lh   = GRID * px
  local ox   = vx + math.floor((vw - lw) / 2)
  local oy   = vy + math.floor((vh - lh) / 2)

  -- Very low alpha keeps the look subtle (like VSCode watermark)
  local ALPHA = 28

  for _, s in ipairs(LOGO_SPANS) do
    local sy, sx, sw, r, g, b = s[1], s[2], s[3], s[4], s[5], s[6]
    renderer.draw_rect(ox + sx * px, oy + sy * px, sw * px, px,
                       {r, g, b, ALPHA})
  end
end


local SHORTCUTS = {
  { key = "ctrl+p",       desc = "Open file" },
  { key = "ctrl+shift+p", desc = "Command palette" },
  { key = "ctrl+shift+r", desc = "Recent files" },
  { key = "ctrl+shift+d", desc = "Recent dirs" },
  { key = "ctrl+n",       desc = "New document" },
  { key = ":q / :wq",    desc = "Quit / Save & Quit" },
  { key = "i / Esc",     desc = "Insert / Normal mode" },
}

function EmptyView:new()
  EmptyView.super.new(self)
  self._hover_file = -1
  self._hover_dir  = -1
  self._file_rects = {}
  self._dir_rects  = {}
  self._kb_section = nil
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

  local y = draw_section_header("Quick Reference", px, py)

  for _, item in ipairs(SHORTCUTS) do
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
      dir_label = path:match("^(.+)[\\/][^\\/]+$") or ""
    else
      name      = path:match("[^\\/]+$") or path
      local raw_dir = path:match("^(.+)[\\/][^\\/]+$") or ""
      local last    = raw_dir:match("([^\\/]+)$") or ""
      dir_label     = last ~= "" and (last .. "/") or ""
    end

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

  draw_logo_watermark(vx, vy, vw, vh)

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

  local KEY_COL_W    = math.floor(200 * SCALE)
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