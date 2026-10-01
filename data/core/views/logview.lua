-- The log view, and the only answer to "what happened?".
--
-- Two streams, deliberately kept apart because they answer different
-- questions, and mixing them is how a user ends up looking for a plugin
-- traceback in a file that never gets one:
--
--   editor   core.log_items — what core.log / core.error wrote. Every
--            plugin error lands here, with its traceback.
--   native   core.log_path, the C logger's file next to the binary. C-level
--            diagnostics, and boot failures from before the editor existed.
--
-- f2 switches between them, ctrl+r re-reads the file. A file being appended
-- to while you read it is not a snapshot, so the native side is re-read on
-- demand rather than watched.
local core    = require "core"
local style   = require "core.style"
local View    = require "core.views.view"
local command = require "core.input.command"

local LogView = View:extend()

-- The tail of the native log is read, not the file: a whole session of it
-- is megabytes, and the part that matters is the end.
local NATIVE_TAIL_BYTES = 256 * 1024
local NATIVE_MAX_LINES = 2000

local LEVEL_COLORS = {
  FATAL  = "titlebar_close_hover",
  ERROR  = "titlebar_close_hover",
  WARN   = "git_modified",
  INFO   = "text",
  DEBUG  = "dim",
  TRACE  = "dim",
}


function LogView:new()
  LogView.super.new(self)
  self.source     = "editor"
  self.native     = { lines = {}, note = "not read yet" }
  self.last_item  = core.log_items[#core.log_items]
  self.scrollable = true
  self.scroll.to.y = 0

  self._sel_start = nil
  self._sel_end   = nil
  self._dragging  = false
  self._line_rects = {}
end


function LogView:get_name()
  return "Log"
end


function LogView:get_line_height()
  return style.font:get_height() + style.padding.y
end


function LogView:get_header_height()
  return self:get_line_height()
end


-- ── the two sources ───────────────────────────────────────────────────────

function LogView:_editor_lines()
  local lines = {}
  for i = #core.log_items, 1, -1 do
    local item = core.log_items[i]
    lines[#lines + 1] = {
      color = "dim",
      text  = os.date(nil, item.time),
    }
    lines[#lines + 1] = { color = "text", text = item.text }
    lines[#lines + 1] = { color = "dim", text = "at " .. item.at }
    if item.info then
      for ln in item.info:gmatch("[^\n]+") do
        lines[#lines + 1] = { color = "dim", text = "  " .. ln }
      end
    end
    lines[#lines + 1] = { color = "gap", text = "" }
  end
  return lines
end


-- Reads the tail of the native log. Everything is plain text off disk, so
-- this is a file read rather than anything the logger exposes.
function LogView:read_native()
  local path = core.log_path
  if not path then
    self.native = { lines = {}, note = "file logging is off (no cdin-log.txt)" }
    return false
  end

  local fp = io.open(path, "rb")
  if not fp then
    self.native = { lines = {}, note = "cannot open " .. path }
    return false
  end

  local size = fp:seek("end")
  local from = size > NATIVE_TAIL_BYTES and (size - NATIVE_TAIL_BYTES) or 0
  fp:seek("set", from)
  local text = fp:read("*a") or ""
  fp:close()

  local out, dropped = {}, 0
  for line in text:gmatch("[^\r\n]+") do
    -- Reading from the middle of the file leaves the first line half a
    -- line; it is a fragment, not the head of anything.
    if from > 0 and dropped == 0 then dropped = 1 else out[#out + 1] = line end
  end

  local lines = {}
  if #out > NATIVE_MAX_LINES then
    lines[#lines + 1] = { color = "dim",
      text = string.format("… %d earlier lines not shown", #out - NATIVE_MAX_LINES) }
    for i = #out - NATIVE_MAX_LINES + 1, #out do out[i] = nil end
  end
  for _, line in ipairs(out) do
    local level = line:match("%s(%u+%s?)%s") or ""
    lines[#lines + 1] = { color = LEVEL_COLORS[level] or "text", text = line }
  end

  self.native = {
    lines = lines,
    note  = string.format("%s — %d lines", path, #lines),
  }
  return true
end


function LogView:_native_lines()
  local lines = {}
  if #self.native.lines == 0 then
    lines[1] = { color = "dim", text = self.native.note or "(empty)" }
    return lines
  end
  for _, l in ipairs(self.native.lines) do lines[#lines + 1] = l end
  return lines
end


function LogView:get_lines()
  if self.source == "native" then return self:_native_lines() end
  return self:_editor_lines()
end


function LogView:get_scrollable_size()
  return self:get_header_height() + #self:get_lines() * self:get_line_height()
end


-- ── selection & copy ──────────────────────────────────────────────────────

function LogView:_sel_range()
  if not self._sel_start or not self._sel_end then return nil, nil end
  local a, b = self._sel_start, self._sel_end
  if a > b then a, b = b, a end
  return a, b
end


function LogView:select_all()
  local n = #self:get_lines()
  if n == 0 then return end
  self._sel_start, self._sel_end = 1, n
  core.redraw = true
end


-- With no selection, copy everything on screen. Copying the whole log to
-- paste into a bug report is the reason this view exists.
function LogView:_copy_selection()
  local lo, hi = self:_sel_range()
  if not lo then
    local out = {}
    for _, line in ipairs(self:get_lines()) do out[#out + 1] = line.text end
    system.set_clipboard(table.concat(out, "\n"))
    core.log("Log copied to clipboard.")
    return
  end

  local lines = self:get_lines()
  local out = {}
  for i = lo, hi do out[#out + 1] = (lines[i] or {}).text or "" end
  system.set_clipboard(table.concat(out, "\n"))
end


function LogView:_line_at_y(my)
  for i, r in ipairs(self._line_rects) do
    if my >= r.y and my < r.y + r.h then return i end
  end
  return nil
end


-- ── input ─────────────────────────────────────────────────────────────────

function LogView:switch_source()
  if self.source == "editor" then
    self.source = "native"
    self:read_native()
  else
    self.source = "editor"
  end
  self._sel_start, self._sel_end = nil, nil
  self._line_rects = {}
  self.scroll.to.y = 0
  core.redraw = true
end


function LogView:reload()
  if self.source == "native" then
    if self:read_native() then
      core.log("re-read %s", core.log_path)
    else
      core.error("log: %s", self.native.note)
    end
  else
    self.last_item = core.log_items[#core.log_items]
    core.log("log reloaded")
  end
  core.redraw = true
end


function LogView:on_mouse_pressed(btn, mx, my, clicks)
  if LogView.super.on_mouse_pressed(self, btn, mx, my, clicks) then return true end
  if btn == "left" then
    local li = self:_line_at_y(my)
    if li then
      self._sel_start = li
      self._sel_end   = li
      self._dragging  = true
      core.redraw = true
      return true
    end
  end
end


function LogView:on_mouse_moved(mx, my, dx, dy)
  LogView.super.on_mouse_moved(self, mx, my, dx, dy)
  if self._dragging then
    local li = self:_line_at_y(my)
    if li and li ~= self._sel_end then
      self._sel_end = li
      core.redraw = true
    end
  end
end


function LogView:on_mouse_released(btn, mx, my)
  LogView.super.on_mouse_released(self, btn, mx, my)
  if btn == "left" then
    self._dragging = false
    if self._sel_start and self._sel_start == self._sel_end then
      self._sel_start = nil
      self._sel_end   = nil
      core.redraw = true
    end
  end
end


function LogView:update()
  local item = core.log_items[#core.log_items]
  if self.source == "editor" and self.last_item ~= item then
    self.last_item = item
    -- Follow the tail, the way a console does. Only in the editor stream:
    -- the native one is a file, and it does not move under the cursor.
    self.scroll.to.y  = math.max(0, self:get_scrollable_size() - self.size.y)
    self._sel_start   = nil
    self._sel_end     = nil
    self._line_rects  = {}
  end

  LogView.super.update(self)
end


-- ── drawing ───────────────────────────────────────────────────────────────

function LogView:_draw_header()
  local h = self:get_header_height()
  local x = self.position.x
  local y = self.position.y
  local w = self.size.x

  renderer.draw_rect(x, y, w, h, style.background2)
  renderer.draw_rect(x, y + h - style.divider_size, w, style.divider_size,
    style.divider)

  local tx = x + style.padding.x
  local ty = y + style.padding.y
  local th = style.font:get_height()

  local function tab(label, active)
    tx = renderer.draw_text(style.font, label, tx, ty,
      active and style.accent or style.dim)
      + style.padding.x
  end

  tab("Log", true)
  tx = tx + style.padding.x
  tab("editor (" .. #core.log_items .. ")", self.source == "editor")
  tab("native", self.source == "native")

  local hint = self.source == "native"
    and "ctrl+r re-read  f2 editor"
    or  "f2 native log  ctrl+r reload"
  local note = self.source == "native" and (self.native.note or "") or ""
  local right = hint
  if note ~= "" and #note + #hint + 40 < w then
    right = note .. "   " .. hint
  end
  local rw = style.font:get_width(right)
  renderer.draw_text(style.font, right, x + w - style.padding.x - rw, ty,
    style.dim)

  return h
end


function LogView:draw()
  self:draw_background(style.background)
  local header_h = self:_draw_header()

  local ox, oy = self:get_content_offset()
  local lh = self:get_line_height()
  local lines = self:get_lines()
  local lo, hi = self:_sel_range()

  local y = oy + header_h + style.padding.y
  self._line_rects = {}

  for i, line in ipairs(lines) do
    -- Every line gets a rect, empty ones included: the selection indices
    -- are indices into `lines`, and a rect list that skipped blanks would
    -- be off by one from the first gap onwards.
    local selected = lo ~= nil and i >= lo and i <= hi
    if selected then
      renderer.draw_rect(ox, y, self.size.x, lh, style.selection)
    end
    self._line_rects[i] = { y = y, h = lh }
    if line.text ~= "" then
      local color = selected and style.background or (style[line.color] or style.text)
      renderer.draw_text(style.font, line.text, ox + style.padding.x, y, color)
    end
    y = y + lh
  end

  self:draw_scrollbar()
end


command.add(function() return core.active_view and core.active_view:is(LogView) end, {
  ["log:copy-selection"] = function() core.active_view:_copy_selection() end,
  ["log:select-all"]      = function() core.active_view:select_all() end,
  ["log:switch-source"]   = function() core.active_view:switch_source() end,
  ["log:reload"]          = function() core.active_view:reload() end,
})


return LogView
