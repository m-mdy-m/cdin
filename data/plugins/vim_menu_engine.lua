-- vim_menu_engine.lua — shared key-driven menu engine for the vim plugins.
--
-- A menu is described declaratively and rendered through the command view:
--
--   menu.open {
--     name    = "fmenu",                  -- used in error messages
--     title   = "File Menu",              -- command view prompt
--     entries = {
--       { key = "n", label = "New File", info = "touch", action = fn },
--       ...
--     },
--   }
--
-- Behaviour:
--   * typing an entry's key and pressing Enter runs its action
--   * fuzzy text matching on label/info also works (Tab to browse)
--   * selecting a suggestion with Enter runs its action directly

local core = require "core"

local M = {}

local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

function M.open(opts)
  assert(type(opts) == "table" and type(opts.entries) == "table",
    "menu.open: expected { title, entries }")

  local items, key_map = {}, {}
  for _, e in ipairs(opts.entries) do
    local item = {
      text    = e.key .. "  " .. e.label,
      info    = e.info,
      _key    = e.key,
      _action = e.action,
    }
    items[#items + 1] = item
    key_map[e.key] = item
  end

  local function suggest(text)
    local t = trim(text)
    if t == "" then return items end

    -- exact key match takes priority
    local hit = key_map[t]
    if hit then return { hit } end

    -- fall back to fuzzy substring matching on label + info
    local lo, results = t:lower(), {}
    for _, item in ipairs(items) do
      if item.text:lower():find(lo, 1, true)
      or (item.info and item.info:lower():find(lo, 1, true)) then
        results[#results + 1] = item
      end
    end
    return results
  end

  local function submit(text, item)
    if item and item._action then
      item._action()
      return
    end
    local t = trim(text)
    if t ~= "" then
      local hit = key_map[t]
      if hit then hit._action(); return end
      local lo = t:lower()
      for _, it in ipairs(items) do
        if it.text:lower():find(lo, 1, true) then
          it._action()
          return
        end
      end
    end
    core.error("%s: unknown option '%s'", opts.name or "menu", text)
  end

  core.command_view:enter(opts.title or "Menu", submit, suggest)
end

return M
