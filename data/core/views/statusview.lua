local core    = require "core"
local common  = require "core.utils.common"
local command = require "core.input.command"
local config  = require "core.config"
local style   = require "core.style"
local DocView = require "core.views.docview"
local LogView = require "core.views.logview"
local View    = require "core.views.view"

local StatusView = View:extend()

-- Vim-like pipe separator
StatusView.sep = " | "

-- ── vim mode pill definitions ──────────────────────────────────────────────────
local VIM_PILL = {
  normal  = { bg = "vim_normal_bg",  label = "NORMAL"  },
  insert  = { bg = "vim_insert_bg",  label = "INSERT"  },
  visual  = { bg = "vim_visual_bg",  label = "VISUAL"  },
  replace = { bg = "vim_replace_bg", label = "REPLACE" },
  command = { bg = "vim_command_bg", label = "COMMAND" },
}

-- ── git branch + status ───────────────────────────────────────────────────────
local function git_items(sep)
  local ok, Git = pcall(require, "core.git")
  if not ok or not Git.status.branch then return nil end

  local out = {}

  -- branch name
  out[#out+1] = style.text
  out[#out+1] = Git.status.branch

  -- no upstream
  if not Git.status.has_remote then
    out[#out+1] = style.dim
    out[#out+1] = " -"
  else
    -- ahead / behind
    if Git.status.ahead > 0 then
      out[#out+1] = style.accent
      out[#out+1] = " \xe2\x86\x91" .. Git.status.ahead   -- ↑
    end
    if Git.status.behind > 0 then
      out[#out+1] = style.accent
      out[#out+1] = " \xe2\x86\x93" .. Git.status.behind  -- ↓
    end
  end

  -- dirty: +staged *unstaged
  if Git.status.repo_dirty then
    local s = Git.status.staged   or 0
    local u = Git.status.unstaged or 0
    if s > 0 or u > 0 then
      out[#out+1] = style.dim
      out[#out+1] = " "
      if s > 0 then
        out[#out+1] = style.git_added or style.accent
        out[#out+1] = "+" .. s
      end
      if u > 0 then
        out[#out+1] = style.git_modified or style.dim
        out[#out+1] = " ~" .. u
      end
    else
      out[#out+1] = style.dim
      out[#out+1] = " ·"
    end
  end

  if Git.status.conflicts and Git.status.conflicts > 0 then
    out[#out+1] = style.git_conflict or style.titlebar_close_hover
    out[#out+1] = " !"
  end

  if Git.status.state == "rebase" then
    out[#out+1] = style.git_modified or style.accent
    out[#out+1] = " REBASE"
  elseif Git.status.state == "merge" then
    out[#out+1] = style.git_conflict or style.accent
    out[#out+1] = " MERGE"
  elseif Git.status.state == "cherry" then
    out[#out+1] = style.accent
    out[#out+1] = " CHERRY"
  elseif Git.status.state == "bisect" then
    out[#out+1] = style.accent
    out[#out+1] = " BISECT"
  end

  out[#out+1] = style.dim
  out[#out+1] = sep
  out[#out+1] = style.text

  return out
end

-- ── tab indicator ─────────────────────────────────────────────────────────────
local function tab_items(sep)
  local ok, tabM = pcall(require, "plugins.tab.manager")
  if not ok then return nil end
  local n = tabM.get_count and tabM.get_count() or 0
  if n < 2 then return nil end
  local idx = tabM.get_index and tabM.get_index(tabM.active_id) or 1
  local out = {}
  for i, tid in ipairs(tabM.tab_order or {}) do
    if tabM.tabs[tid] then
      if i == idx then
        out[#out+1] = style.accent
        out[#out+1] = "[" .. i .. "]"
        out[#out+1] = style.text
      else
        out[#out+1] = style.dim
        out[#out+1] = tostring(i)
        out[#out+1] = style.text
      end
      if i < n then
        out[#out+1] = style.dim
        out[#out+1] = " "
      end
    end
  end
  out[#out+1] = style.dim
  out[#out+1] = sep
  out[#out+1] = style.text
  return out
end

function StatusView:new()
  StatusView.super.new(self)
  self.message_timeout = 0
  self.message         = {}
end

function StatusView:show_message(icon, icon_color, text)
  self.message = {
    icon_color, style.icon_font, icon,
    style.dim,  style.font,     self.sep,
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

-- ── draw helpers ──────────────────────────────────────────────────────────────
local function draw_items(self, items, x, y, draw_fn)
  local font, color = style.font, style.text
  for _, item in ipairs(items) do
    if     type(item) == "userdata" then font  = item
    elseif type(item) == "table"    then color = item
    else   x = draw_fn(font, color, item, nil, x, y, 0, self.size.y)
    end
  end
  return x
end

local function measure(font, _, text, _, x)
  return x + font:get_width(text)
end

-- xoffset shifts the left-aligned items (used to skip past the vim pill)
function StatusView:draw_items(items, right_align, yoffset, xoffset)
  local x, y = self:get_content_offset()
  y = y + (yoffset or 0)
  if right_align then
    local w = draw_items(self, items, 0, 0, measure)
    draw_items(self, items, x + self.size.x - w - style.padding.x, y, common.draw_text)
  else
    draw_items(self, items, x + style.padding.x + (xoffset or 0), y, common.draw_text)
  end
end

-- ── vim mode pill ─────────────────────────────────────────────────────────────
-- Returns the total horizontal space consumed (so left items can be shifted).
function StatusView:draw_vim_pill()
  if not core.get_vim_mode_label then return 0 end
  local label = core.get_vim_mode_label()
  if not label then return 0 end

  -- "[INSERT]" → "INSERT", "insert"
  local mode_text = label:match("%[(.+)%]") or label
  local mode_key  = mode_text:lower()

  local info = VIM_PILL[mode_key] or VIM_PILL.normal
  local bg   = style[info.bg]     or style.vim_normal_bg
  local fg   = style.vim_pill_fg  or style.text

  local ox, oy = self:get_content_offset()
  local bar_h  = self.size.y
  local font   = style.font

  -- pill dimensions
  local h_pad = style.padding.x
  local tw    = font:get_width(mode_text)
  local pw    = tw + h_pad * 2
  local ph    = font:get_height() + math.floor(style.padding.y * 1.2)
  local pill_y = oy + math.floor((bar_h - ph) / 2)
  local pill_x = ox + math.floor(style.padding.x * 0.4)

  -- draw background rect
  if bg then
    renderer.draw_rect(pill_x, pill_y, pw, ph, bg)
  end

  -- draw mode text centered in pill
  common.draw_text(font, fg, mode_text, "center", pill_x, oy, pw, bar_h)

  -- return total space taken (pill + a small gap)
  return pw + math.floor(style.padding.x * 0.8)
end

-- ── item assembly ─────────────────────────────────────────────────────────────
local function push(t, ...)
  for i = 1, select("#", ...) do t[#t+1] = select(i, ...) end
end

local function push_list(t, src)
  for _, v in ipairs(src) do t[#t+1] = v end
end

function StatusView:get_items()
  local sep = self.sep
  local gi  = git_items(sep)
  local ti  = tab_items(sep)

  -- ── editor view ─────────────────────────────────────────────────────────────
  if getmetatable(core.active_view) == DocView then
    local dv        = core.active_view
    local line, col = dv.doc:get_selection()
    local dirty     = dv.doc:is_dirty()
    local ro        = dv.doc.read_only
    local nlines    = #dv.doc.lines

    -- LEFT:  branch ↑1 ~3 | [RO] or [m]   (vim mode is drawn separately as pill)
    local left = {}

    if gi then push_list(left, gi) end

    -- file state indicator
    if ro then
      push(left, style.dim, "[RO]", style.text, style.dim, sep, style.text)
    elseif dirty then
      push(left, style.git_modified or style.accent, "-", style.text, style.dim, sep, style.text)
    end

    -- RIGHT:  [1] 2 3 | 42:18 | 37% | lf
    local right = {}

    if ti then push_list(right, ti) end

    -- cursor position (vim-style line:col)
    push(right, style.dim, tostring(line) .. ":" .. tostring(col), style.text)

    -- scroll percentage
    if nlines > 0 then
      local pct_str
      if line == 1 then
        pct_str = "top"
      elseif line >= nlines then
        pct_str = "bot"
      else
        pct_str = tostring(math.floor(line / nlines * 100)) .. "%"
      end
      push(right, style.dim, sep, style.dim, pct_str, style.text)
    end

    local le = dv.doc.crlf and "crlf" or "lf"
    push(right, style.dim, sep, style.dim, le, style.text)

    return left, right
  end

  local left = {}
  if gi then push_list(left, gi) end

  local right = {}
  if ti then push_list(right, ti) end
  push(right, style.dim, tostring(#core.docs) .. " buf", style.text)

  return left, right
end

function StatusView:draw()
  self:draw_background(style.background2)
  if self.message then
    self:draw_items(self.message, false, self.size.y)
  end
  local left, right = self:get_items()

  -- Draw vim mode pill first; get its width to shift left items
  local pill_w = self:draw_vim_pill()

  self:draw_items(left,  false, nil, pill_w)
  self:draw_items(right, true)
end

return StatusView
