local core = require "core"
local command = require "core.input.command"
local config = require "core.config"
local search = require "core.doc.search"
local DocView = require "core.views.docview"

local max_previous_finds = 50


local function doc()
  return core.active_view.doc
end

local previous_finds = {}
local last_doc
local last_fn, last_text

local highlight_map = setmetatable({}, { __mode = "k" })
local M = {}

function M.get_highlight(d)
  return highlight_map[d]
end

function M.set_highlight(d, text, opt)
  if text and text ~= "" then
    highlight_map[d] = { text = text, opt = opt }
  else
    highlight_map[d] = nil
  end
  core.redraw = true
end

function M.clear_highlight(d)
  highlight_map[d] = nil
  core.redraw = true
end
core.findreplace = M


local function push_previous_find(doc, sel)
  if last_doc ~= doc then
    last_doc = doc
    previous_finds = {}
  end
  if #previous_finds >= max_previous_finds then
    table.remove(previous_finds, 1)
  end
  table.insert(previous_finds, sel or { doc:get_selection() })
end


local function find(label, search_fn, opt)
  local dv = core.active_view
  local sel = { dv.doc:get_selection() }
  local text = dv.doc:get_text(table.unpack(sel))
  local found = false

  core.command_view:set_text(text, true)

  core.command_view:enter(label, function(text)
    if found then
      last_fn, last_text = search_fn, text
      previous_finds = {}
      push_previous_find(dv.doc, sel)
      -- keep highlight alive after closing find bar
      M.set_highlight(dv.doc, text, opt)
    else
      core.error("Couldn't find %q", text)
      dv.doc:set_selection(table.unpack(sel))
      dv:scroll_to_make_visible(sel[1], sel[2])
      M.clear_highlight(dv.doc)
    end

  end, function(text)
    local ok, line1, col1, line2, col2 = pcall(search_fn, dv.doc, sel[1], sel[2], text)
    if ok and line1 and text ~= "" then
      dv.doc:set_selection(line2, col2, line1, col1)
      dv:scroll_to_line(line2, true)
      found = true
      -- live highlight while typing
      M.set_highlight(dv.doc, text, opt)
    else
      dv.doc:set_selection(table.unpack(sel))
      found = false
      if text == "" then M.clear_highlight(dv.doc) end
    end

  end, function(explicit)
    if explicit then
      -- user pressed Escape: clear highlight and restore position
      dv.doc:set_selection(table.unpack(sel))
      dv:scroll_to_make_visible(sel[1], sel[2])
      M.clear_highlight(dv.doc)
    end
  end)
end


local function replace(kind, default, fn)
  core.command_view:set_text(default, true)

  core.command_view:enter("Find To Replace " .. kind, function(old)
    core.command_view:set_text(old, true)

    local s = string.format("Replace %s %q With", kind, old)
    core.command_view:enter(s, function(new)
      local n = doc():replace(function(text)
        return fn(text, old, new)
      end)
      core.log("Replaced %d instance(s) of %s %q with %q", n, kind, old, new)
    end)
  end)
end


local function has_selection()
  return core.active_view:is(DocView)
     and core.active_view.doc:has_selection()
end

command.add(has_selection, {
  ["find-replace:select-next"] = function()
    local l1, c1, l2, c2 = doc():get_selection(true)
    local text = doc():get_text(l1, c1, l2, c2)
    local l1, c1, l2, c2 = search.find(doc(), l2, c2, text, { wrap = true })
    if l2 then doc():set_selection(l2, c2, l1, c1) end
  end
})

local function has_active_find()
  return core.active_view:is(DocView) and last_fn ~= nil
end

command.add("core.views.docview", {
  ["find-replace:find"] = function()
    local opt = { wrap = true, no_case = true }
    find("Find Text", function(doc, line, col, text)
      return search.find(doc, line, col, text, opt)
    end, opt)
  end,

  ["find-replace:find-pattern"] = function()
    local opt = { wrap = true, no_case = true, pattern = true }
    find("Find Text Pattern", function(doc, line, col, text)
      return search.find(doc, line, col, text, opt)
    end, opt)
  end,

  ["find-replace:clear-highlight"] = function()
    M.clear_highlight(doc())
    last_fn  = nil
    last_text = nil
  end,

  ["find-replace:replace"] = function()
    replace("Text", "", function(text, old, new)
      return text:gsub(old:gsub("%W", "%%%1"), new:gsub("%%", "%%%%"), nil)
    end)
  end,

  ["find-replace:replace-pattern"] = function()
    replace("Pattern", "", function(text, old, new)
      return text:gsub(old, new)
    end)
  end,

  ["find-replace:replace-symbol"] = function()
    local first = ""
    if doc():has_selection() then
      local text = doc():get_text(doc():get_selection())
      first = text:match(config.symbol_pattern) or ""
    end
    replace("Symbol", first, function(text, old, new)
      local n = 0
      local res = text:gsub(config.symbol_pattern, function(sym)
        if old == sym then
          n = n + 1
          return new
        end
      end)
      return res, n
    end)
  end,
})

command.add(has_active_find, {
  ["find-replace:repeat-find"] = function()
    local line, col = doc():get_selection()
    local line1, col1, line2, col2 = last_fn(doc(), line, col, last_text)
    if line1 then
      push_previous_find(doc())
      doc():set_selection(line2, col2, line1, col1)
      core.active_view:scroll_to_line(line2, true)
    end
  end,

  ["find-replace:previous-find"] = function()
    if doc() ~= last_doc or #previous_finds == 0 then
      core.error("No previous finds")
      return
    end
    local sel = table.remove(previous_finds)
    doc():set_selection(table.unpack(sel))
    core.active_view:scroll_to_line(sel[3], true)
  end,
})