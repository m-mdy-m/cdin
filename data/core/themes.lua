-- Theme registry: name -> module.
-- Themes are simplified: each theme is just a theme.lua file.
-- Built-in themes live in cdin-x/X/themes/<name>/theme.lua
-- and are installed into data/X/themes/<name>/ during setup (see
-- cdin-x/scripts/install.sh).
-- themes.lua auto-discovers all available themes by scanning the catalog.

local themes = {}

function themes.discover()
  local found = {}
  local catalog_dir = (EXEDIR or "") .. "/data/X/themes"
  if not system.get_file_info(catalog_dir) then return found end

  for _, entry in ipairs(system.list_dir(catalog_dir) or {}) do
    if entry.type == "dir" and entry.name ~= ".git" then
      local theme_file = catalog_dir .. "/" .. entry.name .. "/theme.lua"
      if system.get_file_info(theme_file) then
        found[#found + 1] = entry.name
      end
    end
  end
  table.sort(found)
  return found
end

themes.list = themes.discover()

function themes.names()
  local out = {}
  for _, n in ipairs(themes.list) do out[#out + 1] = n end
  return out
end

function themes.apply(style, name)
  local common = require "core.utils.common"

  -- Load theme from cdin-x catalog
  local theme_path = (EXEDIR or "") .. "/data/X/themes/" .. tostring(name) .. "/theme.lua"
  local ok, t = pcall(dofile, theme_path)
  if not ok or type(t) ~= "table" then return false end

  local function col(v, fallback)
    if type(v) == "string" then return { common.color(v) } end
    if type(v) == "table" then return v end
    return fallback
  end
  for k, v in pairs(t) do
    if k ~= "name" and k ~= "syntax" then
      style[k] = col(v, style[k])
    end
  end
  if type(t.syntax) == "table" then
    style.syntax = style.syntax or {}
    for k, v in pairs(t.syntax) do
      style.syntax[k] = col(v, style.syntax[k])
    end
  end
  style.theme_name = t.name or name
  return true
end

function style.set_theme(name)
  local themes = require "core.themes"
  return themes.apply(style, name)
end

return themes
