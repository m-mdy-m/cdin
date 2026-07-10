local core   = require "core"
local common = require "core.utils.common"
local command = require "core.input.command"
local style  = require "core.style"
local View   = require "core.views.view"

local function c(hex)
  return { common.color(hex) }
end

local COL = {
  match_bg      = c "#2a1f3d",   -- purple-tinted bg behind matched keyword
  match_text    = c "#c8b8ff",   -- highlighted keyword text
  file_name     = c "#8b7fc7",   -- file path
  file_name_sel = c "#c8b8ff",
  line_num      = c "#5a5a5a",   -- :42:
  line_num_sel  = c "#a090c7",
  context_text  = c "#606060",   -- text before/after keyword (dimmed)
  context_sel   = c "#9a9a9a",
  row_hover     = c "#1a1530",   -- whole row highlight on hover/selection
  divider       = c "#1e1e2e",
  counter       = c "#a090c7",   -- "42 matches" badge
  counter_bg    = c "#1e1530",
  progress_bar  = c "#3a2a5a",
  progress_fill = c "#a090c7",
}

local CONTEXT_CHARS = 40

local ResultsView = View:extend()


function ResultsView:new(text, fn)
  ResultsView.super.new(self)
  self.scrollable   = true
  self.brightness   = 0
  self.query        = text
  self.query_fn     = fn
  self:begin_search(text, fn)
end


function ResultsView:get_name()
  if self.query and self.query ~= "" then
    return "  " .. self.query
  end
  return "Search Results"
end




local function find_matches_in_file(results, filename, fn)
  local fp = io.open(filename)
  if not fp then return end
  local n = 1
  for line in fp:lines() do
    local s, e = fn(line)
    if s then
      -- trim the line for display, remember exact byte offsets
      table.insert(results, {
        file = filename,
        text = line,
        line = n,
        col  = s,
        col_end = e or s,
      })
      core.redraw = true
    end
    if n % 100 == 0 then coroutine.yield() end
    n = n + 1
  end
  fp:close()
end


function ResultsView:begin_search(text, fn)
  self.search_args  = { text, fn }
  self.results      = {}
  self.last_file_idx = 1
  self.searching    = true
  self.selected_idx = 0

  core.add_thread(function()
    for i, file in ipairs(core.project_files) do
      if file.type == "file" then
        find_matches_in_file(self.results, file.filename, fn)
      end
      self.last_file_idx = i
    end
    self.searching  = false
    self.brightness = 100
    core.redraw     = true
  end, self.results)

  self.scroll.to.y = 0
end


function ResultsView:refresh()
  self:begin_search(table.unpack(self.search_args))
end

local HEADER_H_EXTRA = 8   -- extra vertical room for the header section

function ResultsView:get_header_height()
  local fh = style.font:get_height()
  return fh + style.padding.y * 2 + HEADER_H_EXTRA
end

function ResultsView:get_line_height()
  return math.floor(style.code_font:get_height() * 1.55)
end

function ResultsView:get_results_yoffset()
  return self:get_header_height() + style.divider_size + style.padding.y
end

function ResultsView:get_scrollable_size()
  return self:get_results_yoffset() + #self.results * self:get_line_height()
end

function ResultsView:get_visible_results_range()
  local lh  = self:get_line_height()
  local oy  = self:get_results_yoffset()
  local min = math.max(1, math.floor((self.scroll.y - oy) / lh))
  return min, min + math.floor(self.size.y / lh) + 2
end

function ResultsView:each_visible_result()
  return coroutine.wrap(function()
    local lh       = self:get_line_height()
    local cx, cy   = self:get_content_offset()
    local min, max = self:get_visible_results_range()
    local y        = cy + self:get_results_yoffset() + lh * (min - 1)
    for i = min, max do
      local item = self.results[i]
      if not item then break end
      coroutine.yield(i, item, cx, y, self.size.x, lh)
      y = y + lh
    end
  end)
end

function ResultsView:scroll_to_make_selected_visible()
  local h = self:get_line_height()
  local y = self:get_results_yoffset() + h * (self.selected_idx - 1)
  self.scroll.to.y = math.min(self.scroll.to.y, y)
  self.scroll.to.y = math.max(self.scroll.to.y, y + h - self.size.y)
end

function ResultsView:on_mouse_moved(mx, my, ...)
  ResultsView.super.on_mouse_moved(self, mx, my, ...)
  self.selected_idx = 0
  for i, item, x, y, w, h in self:each_visible_result() do
    if mx >= x and my >= y and mx < x + w and my < y + h then
      self.selected_idx = i
      break
    end
  end
end

function ResultsView:on_mouse_pressed(...)
  local caught = ResultsView.super.on_mouse_pressed(self, ...)
  if not caught then self:open_selected_result() end
end

function ResultsView:open_selected_result()
  local res = self.results[self.selected_idx]
  if not res then return end
  core.try(function()
    local dv = core.root_view:open_doc(core.open_doc(res.file))
    core.root_view.root_node:update_layout()
    dv.doc:set_selection(res.line, res.col)
    dv:scroll_to_line(res.line, false, true)
    -- set the search highlight in the opened doc so matches glow
    if core.findreplace then
      local opt = { no_case = true }
      core.findreplace.set_highlight(dv.doc, self.query, opt)
    end
  end)
end

function ResultsView:update()
  self:move_towards("brightness", 0, 0.1)
  ResultsView.super.update(self)
end

local function split_context(line, s, e)
  local keyword = line:sub(s, e)
  local pre_raw = line:sub(1, s - 1)
  local pre = pre_raw:match("^%s*(.-)%s*$")  -- trim both ends
  if #pre > CONTEXT_CHARS then
    pre = "…" .. pre:sub(#pre - CONTEXT_CHARS + 2)
  end

  local suf_raw = line:sub(e + 1)
  local suf = suf_raw:match("^(.-)%s*$")
  if #suf > CONTEXT_CHARS then
    suf = suf:sub(1, CONTEXT_CHARS - 1) .. "…"
  end

  return pre, keyword, suf
end
local function short_path(filename)
  local root = core.project and core.project.path or ""
  if root ~= "" and filename:sub(1, #root) == root then
    local rel = filename:sub(#root + 2)   -- skip trailing separator
    return rel
  end
  return filename:match("[^/\\]+$") or filename
end




function ResultsView:draw()
  self:draw_background(style.background)

  local ox, oy   = self:get_content_offset()
  local pad      = style.padding.x
  local fh       = style.font:get_height()
  local cfh      = style.code_font:get_height()
  local hdr_h    = self:get_header_height()
  local total    = #core.project_files
  local per      = total > 0 and (self.last_file_idx / total) or 1

  renderer.draw_rect(ox, oy, self.size.x, hdr_h, style.background2)

  local hx = ox + pad
  local hy = oy + math.floor((hdr_h - fh) / 2)

  if self.searching then
    local bar_y = oy + hdr_h - 3
    renderer.draw_rect(ox, bar_y, self.size.x, 3, COL.progress_bar)
    renderer.draw_rect(ox, bar_y, math.floor(self.size.x * per), 3, COL.progress_fill)

    local status = string.format("Searching… %d%%  ·  %d / %d files  ·  %d matches",
      math.floor(per * 100), self.last_file_idx, total, #self.results)
    renderer.draw_text(style.font, status, hx, hy, style.dim)
  else
    local count_str = tostring(#self.results)
    local label     = string.format(" matches for \"%s\"", self.query)
    local cw        = style.font:get_width(count_str) + pad
    local badge_x   = hx

    local badge_h = fh + 4
    local badge_y = hy - 2
    renderer.draw_rect(badge_x, badge_y, cw, badge_h, COL.counter_bg)
    renderer.draw_text(style.font, count_str, badge_x + pad / 2, hy,
      common.lerp(COL.counter, style.text, self.brightness / 100))

    renderer.draw_text(style.font, label, badge_x + cw + 4, hy, style.dim)
  end

  local div_y = oy + hdr_h
  renderer.draw_rect(ox, div_y, self.size.x, style.divider_size, COL.divider)

  local clip_x = self.position.x
  local clip_y = self.position.y + hdr_h + style.divider_size
  core.push_clip_rect(clip_x, clip_y, self.size.x, self.size.y - hdr_h)

  for i, item, rx, ry, rw, rh in self:each_visible_result() do
    local selected = (i == self.selected_idx)

    if selected then
      renderer.draw_rect(rx, ry, rw, rh, COL.row_hover)
      renderer.draw_rect(rx, ry, 2, rh, style.accent)
    end

    local ty = ry + math.floor((rh - cfh) / 2)

    local fname  = short_path(item.file)
    local fc     = selected and COL.file_name_sel or COL.file_name
    local fname_w = style.font:get_width(fname)
    renderer.draw_text(style.font, fname, rx + pad, ty, fc)

    local loc_str = string.format("  :%d:%d  ", item.line, item.col)
    local lc      = selected and COL.line_num_sel or COL.line_num
    local loc_x   = rx + pad + fname_w
    local loc_w   = style.font:get_width(loc_str)
    renderer.draw_text(style.font, loc_str, loc_x, ty, lc)

    local pre, kw, suf = split_context(item.text, item.col, item.col_end)
    local ctx_x = loc_x + loc_w
    local cc    = selected and COL.context_sel or COL.context_text

    if pre ~= "" then
      local pw = style.code_font:get_width(pre)
      renderer.draw_text(style.code_font, pre, ctx_x, ty, cc)
      ctx_x = ctx_x + pw
    end

    local kw_w = style.code_font:get_width(kw)
    renderer.draw_rect(ctx_x, ry + 2, kw_w, rh - 4, COL.match_bg)
    renderer.draw_text(style.code_font, kw, ctx_x, ty, COL.match_text)
    ctx_x = ctx_x + kw_w

    if suf ~= "" then
      renderer.draw_text(style.code_font, suf, ctx_x, ty, cc)
    end

    if not selected then
      renderer.draw_rect(rx + pad, ry + rh - 1, rw - pad * 2, 1, COL.divider)
    end
  end

  core.pop_clip_rect()
  self:draw_scrollbar()
end




local function begin_search(text, fn)
  if text == "" then
    core.error("Expected non-empty string")
    return
  end
  local rv = ResultsView(text, fn)
  core.root_view:get_active_node():add_view(rv)
end


command.add(nil, {
  ["project-search:find"] = function()
    core.command_view:enter("Find Text In Project", function(text)
      text = text:lower()
      begin_search(text, function(line_text)
        local s, e = line_text:lower():find(text, nil, true)
        return s, e
      end)
    end)
  end,

  ["project-search:find-pattern"] = function()
    core.command_view:enter("Find Pattern In Project", function(text)
      begin_search(text, function(line_text)
        local s, e = line_text:find(text)
        return s, e
      end)
    end)
  end,

  ["project-search:fuzzy-find"] = function()
    core.command_view:enter("Fuzzy Find Text In Project", function(text)
      begin_search(text, function(line_text)
        return common.fuzzy_match(line_text, text) and 1
      end)
    end)
  end,
})


command.add(ResultsView, {
  ["project-search:select-previous"] = function()
    local v = core.active_view
    v.selected_idx = math.max(v.selected_idx - 1, 1)
    v:scroll_to_make_selected_visible()
  end,

  ["project-search:select-next"] = function()
    local v = core.active_view
    v.selected_idx = math.min(v.selected_idx + 1, #v.results)
    v:scroll_to_make_selected_visible()
  end,

  ["project-search:open-selected"] = function()
    core.active_view:open_selected_result()
  end,

  ["project-search:refresh"] = function()
    core.active_view:refresh()
  end,
})