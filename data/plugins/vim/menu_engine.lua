local core = require "core"

local M = {}
local function build_items(entries)
  local items   = {}

  local function add_entry(e, is_last_in_block)
    local branch  = is_last_in_block and "└─ " or "├─ "
    local icon    = e.icon  or ""
    local label   = e.label or ""
    local key     = e.key   or "?"

    local text = branch
               .. "[" .. key .. "] "
               .. (icon ~= "" and (icon .. " ") or "")
               .. label

    items[#items + 1] = {
      text    = text,
      info    = e.info,
      _key    = key,
      _action = e.action,
    }
  end

  for i, item in ipairs(entries) do
    if item.header then
      -- section header (not selectable)
      items[#items + 1] = {
        text    = "  ── " .. item.header .. " ──",
        info    = "",
        _key    = nil,
        _action = nil,
      }
      local sub = item.entries or {}
      for j, e in ipairs(sub) do
        add_entry(e, j == #sub)
      end
    else
      add_entry(item, i == #entries)
    end
  end

  return items
end

local function collect_all_entries(entries)
  local flat = {}
  for _, item in ipairs(entries) do
    if item.header then
      for _, e in ipairs(item.entries or {}) do
        flat[#flat + 1] = e
      end
    else
      flat[#flat + 1] = item
    end
  end
  return flat
end

local function build_key_map(entries)
  local map = {}
  local flat = collect_all_entries(entries)
  for _, e in ipairs(flat) do
    if e.key and e.action then
      map[e.key] = e.action
    end
  end
  return map
end

local function make_suggest(items, key_map)
  return function(text)
    local t = text:match("^%s*(.-)%s*$")
    if t == "" then return items end
    local first = t:sub(1, 1)
    if key_map[first] then
      for _, item in ipairs(items) do
        if item._key == first then return { item } end
      end
    end
    local lo = t:lower()
    local results = {}
    for _, item in ipairs(items) do
      if item._action then   -- skip section headers
        if item.text:lower():find(lo, 1, true)
        or (item.info and item.info:lower():find(lo, 1, true)) then
          results[#results + 1] = item
        end
      end
    end
    return results
  end
end

local function make_submit(items, key_map)
  return function(text, item)
    if item and item._action then
      item._action()
      return
    end
    local t = text:match("^%s*(.-)%s*$")
    if t ~= "" then
      local act = key_map[t:sub(1, 1)]
      if act then act(); return end
      local lo = t:lower()
      for _, it in ipairs(items) do
        if it._action and it.text:lower():find(lo, 1, true) then
          it._action()
          return
        end
      end
    end
    core.error("vim-menu: unknown option '%s'", text)
  end
end

function M.open(opts)
  local title   = opts.title   or "Menu"
  local context = opts.context or ""
  local entries = opts.entries or {}

  local items   = build_items(entries)
  local key_map = build_key_map(entries)

  local label = title
  if context ~= "" then
    label = label .. "  " .. context .. "  (key or Tab)"
  else
    label = label .. "  (key or Tab)"
  end

  core.command_view:enter(
    label,
    make_submit(items, key_map),
    make_suggest(items, key_map)
  )
end

return M
