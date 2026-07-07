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

-- ── vim mode labels (uppercase, minimal) ──────────────────────────────────────
local MODES = {
  normal  = { label = "NORMAL",  color = "dim"    },
  insert  = { label = "INSERT",  color = "accent" },
  visual  = { label = "VISUAL",  color = "accent" },
  replace = { label = "REPLACE", color = "accent" },
  command = { label = "COMMAND", color = "accent" },
}

local function mode_items(dv, sep)
  if not dv.vim_mode then return nil end
  local m   = MODES[dv.vim_mode] or { label = dv.vim_mode:upper(), color = "dim" }
  local clr = style[m.color] or style.dim
  return {
    clr,        m.label,
    style.dim,  sep,
    style.text,
  }
end

-- ── git branch + status ───────────────────────────────────────────────────────
--
-- Format:  main ↑3↓2 +4*3 ! R
--
--  main          clean, in sync
--  main -        no upstream
--  main ↑3       3 ahead
--  main ↓2       2 behind
--  main ↑1↓2     diverged
--  main +2*3     2 staged, 3 unstaged/untracked
--  main *3       only unstaged
--  main +2       only staged
--  main !        conflicts
--  main R        rebasing
--  main M        merging
--
local function git_items(sep)
  local ok, Git = pcall(require, "plugins.treeview.git")
  if not ok or not Git.branch then return nil end

  local out = {}

  -- branch name
  out[#out+1] = style.text
  out[#out+1] = Git.branch

  -- no upstream
  if not Git.has_remote then
    out[#out+1] = style.dim
    out[#out+1] = " -"
  else
    -- ahead / behind
    if Git.ahead > 0 then
      out[#out+1] = style.accent
      out[#out+1] = " \xe2\x86\x91" .. Git.ahead   -- ↑
    end
    if Git.behind > 0 then
      out[#out+1] = style.accent
      out[#out+1] = " \xe2\x86\x93" .. Git.behind  -- ↓
    end
  end

  -- dirty: +staged *unstaged
  if Git.repo_dirty then
    local s = Git.staged   or 0
    local u = Git.unstaged or 0
    if s > 0 or u > 0 then
      out[#out+1] = style.dim
      out[#out+1] = " "
      if s > 0 then
        out[#out+1] = style.accent
        out[#out+1] = "+" .. s
      end
      if u > 0 then
        out[#out+1] = style.dim
        out[#out+1] = "*" .. u
      end
    else
      out[#out+1] = style.dim
      out[#out+1] = " *"
    end
  end

  -- conflicts
  if Git.conflicts and Git.conflicts > 0 then
    out[#out+1] = style.titlebar_close_hover
    out[#out+1] = " !"
  end

  -- special state: R=rebase, M=merge, C=cherry
  if Git.state == "rebase" then
    out[#out+1] = style.accent
    out[#out+1] = " R"
  elseif Git.state == "merge" then
    out[#out+1] = style.accent
    out[#out+1] = " M"
  elseif Git.state == "cherry" then
    out[#out+1] = style.accent
    out[#out+1] = " C"
  elseif Git.state == "bisect" then
    out[#out+1] = style.accent
    out[#out+1] = " B"
  end

  out[#out+1] = style.dim
  out[#out+1] = sep
  out[#out+1] = style.text

  return out
end

-- ── tab indicator ─────────────────────────────────────────────────────────────
-- Shows: 1 [2] 3
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

function StatusView:draw_items(items, right_align, yoffset)
  local x, y = self:get_content_offset()
  y = y + (yoffset or 0)
  if right_align then
    local w = draw_items(self, items, 0, 0, measure)
    draw_items(self, items, x + self.size.x - w - style.padding.x, y, common.draw_text)
  else
    draw_items(self, items, x + style.padding.x, y, common.draw_text)
  end
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

    -- LEFT:  MODE | branch ↑1 +2*3 ! R | [RO]  or  [m]
    local left = {}

    local mi = mode_items(dv, sep)
    if mi then push_list(left, mi) end

    if gi then push_list(left, gi) end

    -- file state indicator
    if ro then
      push(left, style.dim, "[RO]", style.text, style.dim, sep, style.text)
    elseif dirty then
      push(left, style.accent, "[m]", style.text, style.dim, sep, style.text)
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

    -- line endings
    local le = dv.doc.crlf and "crlf" or "lf"
    push(right, style.dim, sep, style.dim, le, style.text)

    return left, right
  end

  -- ── non-editor view ─────────────────────────────────────────────────────────
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
  self:draw_items(left)
  self:draw_items(right, true)
end

return StatusView