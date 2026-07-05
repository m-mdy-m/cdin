local core    = require "core"
local common  = require "core.utils.common"
local style   = require "core.style"
local Doc     = require "core.doc"
local DocView = require "core.views.docview"
local View    = require "core.views.view"

local SingleLineDoc = Doc:extend()
function SingleLineDoc:insert(line, col, text)
  SingleLineDoc.super.insert(self, line, col, text:gsub("\n", ""))
end

local CommandView = DocView:extend()

local MAX_SUGGESTIONS = 10
local noop = function() end

local DEFAULT_STATE = {
  submit  = noop,
  suggest = noop,
  cancel  = noop,
}

function CommandView:new()
  CommandView.super.new(self, SingleLineDoc())
  self.suggestion_idx        = 1
  self.suggestions           = {}
  self.suggestions_height    = 0
  self.last_change_id        = 0
  self.gutter_width          = 0
  self.gutter_text_brightness = 0
  self.selection_offset      = 0
  self.state                 = DEFAULT_STATE
  self.font                  = "font"
  self.size.y                = 0
  self.label                 = ""
end

function CommandView:get_name() return View.get_name(self) end

function CommandView:get_scrollable_size()          return 0  end
function CommandView:scroll_to_make_visible()             end  -- no-op
function CommandView:draw_line_highlight()                end  -- no-op

function CommandView:get_line_screen_position()
  local x   = CommandView.super.get_line_screen_position(self, 1)
  local _, y = self:get_content_offset()
  return x, y + (self.size.y - self:get_line_height()) / 2
end

function CommandView:get_gutter_width()
  return self.gutter_width
end

function CommandView:get_text()
  return self.doc:get_text(1, 1, 1, math.huge)
end

function CommandView:set_text(text, select)
  self.doc:remove(1, 1, math.huge, math.huge)
  self.doc:text_input(text)
  if select then self.doc:set_selection(math.huge, math.huge, 1, 1) end
end

function CommandView:get_suggestion_line_height()
  return self:get_font():get_height() + style.padding.y
end

function CommandView:update_suggestions()
  local t   = self.state.suggest(self:get_text()) or {}
  local res = {}
  for i, item in ipairs(t) do
    if i > MAX_SUGGESTIONS then break end
    if type(item) == "string" then item = { text = item } end
    res[i] = item
  end
  self.suggestions    = res
  self.suggestion_idx = 1
end

function CommandView:move_suggestion_idx(dir)
  self.suggestion_idx = common.clamp(
    self.suggestion_idx + dir, 1, #self.suggestions)
  self:complete()
  self.last_change_id = self.doc:get_change_id()
end

function CommandView:complete()
  if #self.suggestions > 0 then
    self:set_text(self.suggestions[self.suggestion_idx].text)
  end
end

function CommandView:enter(label, submit, suggest, cancel)
  if self.state ~= DEFAULT_STATE then return end
  self.state = {
    submit  = submit  or noop,
    suggest = suggest or noop,
    cancel  = cancel  or noop,
  }
  core.set_active_view(self)
  self:update_suggestions()
  self.gutter_text_brightness = 100
  self.label                  = label .. ": "
end

function CommandView:submit()
  local suggestion = self.suggestions[self.suggestion_idx]
  local text       = self:get_text()
  local submit     = self.state.submit
  self:exit(true)
  submit(text, suggestion)
end

function CommandView:exit(submitted, inexplicit)
  if core.active_view == self then
    core.set_active_view(core.last_active_view)
  end
  local cancel  = self.state.cancel
  self.state    = DEFAULT_STATE
  self.doc:reset()
  self.suggestions = {}
  if not submitted then cancel(not inexplicit) end
end

function CommandView:update()
  CommandView.super.update(self)

  if core.active_view ~= self and self.state ~= DEFAULT_STATE then
    self:exit(false, true)
  end

  if self.last_change_id ~= self.doc:get_change_id() then
    self:update_suggestions()
    self.last_change_id = self.doc:get_change_id()
  end

  self:move_towards("gutter_text_brightness", 0, 0.1)

  local dest = self:get_font():get_width(self.label) + style.padding.x
  if self.size.y <= 0 then self.gutter_width = dest
  else self:move_towards("gutter_width", dest) end

  local lh = self:get_suggestion_line_height()
  self:move_towards("suggestions_height", #self.suggestions * lh)
  self:move_towards("selection_offset", self.suggestion_idx * lh)

  local target = (self == core.active_view)
    and (style.font:get_height() + style.padding.y * 2) or 0
  self:move_towards(self.size, "y", target)
end

function CommandView:draw_line_gutter(idx, x, y)
  local yoffset = self:get_line_text_y_offset()
  local color   = common.lerp(style.text, style.accent, self.gutter_text_brightness / 100)
  local pos     = self.position
  core.push_clip_rect(pos.x, pos.y, self:get_gutter_width(), self.size.y)
  renderer.draw_text(self:get_font(), self.label, x + style.padding.x, y + yoffset, color)
  core.pop_clip_rect()
end

local function draw_suggestions_box(self)
  if #self.suggestions == 0 then return end

  local lh  = self:get_suggestion_line_height()
  local ds  = style.divider_size
  local x   = (self:get_line_screen_position())
  local h   = math.ceil(self.suggestions_height)
  local rx, ry = self.position.x, self.position.y - h - ds
  local rw, rh = self.size.x, h

  renderer.draw_rect(rx, ry, rw, rh, style.background3)
  renderer.draw_rect(rx, ry - ds, rw, ds, style.divider)

  local sel_y = self.position.y - self.selection_offset - ds
  renderer.draw_rect(rx, sel_y, rw, lh, style.line_highlight)

  core.push_clip_rect(rx, ry, rw, rh)
  for i, item in ipairs(self.suggestions) do
    local color = (i == self.suggestion_idx) and style.accent or style.text
    local iy    = self.position.y - i * lh - ds
    common.draw_text(self:get_font(), color, item.text, nil, x, iy, 0, lh)
    if item.info then
      local w = self.size.x - x - style.padding.x
      common.draw_text(self:get_font(), style.dim, item.info, "right", x, iy, w, lh)
    end
  end
  core.pop_clip_rect()
end

function CommandView:draw()
  CommandView.super.draw(self)
  core.root_view:defer_draw(draw_suggestions_box, self)
end

return CommandView