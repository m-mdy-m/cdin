-- Theme registry: name -> style table.
--
-- A theme is a single file: <root>/<name>/theme.lua returning a table of
-- colors. A theme can come from anywhere; the layout is what matters.
--
-- The search order is user themes first, then the bundled ones, then any root
-- an extension added with themes.add_root(). So a user can override any
-- bundled theme by name, and an extension can ship its own themes without
-- either knowing about the other.

local fs     = require "core.fs"
local common = require "core.utils.common"
local config = require "core.config"

local themes = {}

-- Extra roots, in the order they were added. Precedence is the order of
-- this list, after the user root and the bundled root.
local extra_roots = {}

local function roots()
  local out = {}
  if config.user_dir then
    out[#out + 1] = fs.join(config.user_dir, "themes")
  end
  out[#out + 1] = fs.join(EXEDIR or ".", "data", "themes")
  for _, root in ipairs(extra_roots) do
    out[#out + 1] = root
  end
  return out
end

-- Adds a themes root. A non-directory is ignored rather than registered, so
-- a caller does not have to stat first and cannot poison the search order
-- with a path that will never resolve. Adding the same root twice is a
-- no-op. Rescans, so a caller can add a root and immediately list what is
-- in it.
function themes.add_root(dir)
  if type(dir) ~= "string" or dir == "" then return false end
  if not fs.is_dir(dir) then return false end
  for _, root in ipairs(extra_roots) do
    if root == dir then return true end
  end
  extra_roots[#extra_roots + 1] = dir
  themes.rescan()
  return true
end

-- Recomputes themes.list in place. Needed because the list is a snapshot:
-- a root that appears after load time (an extension installing its themes
-- during its own init()) would otherwise be loadable by name but never
-- listed.
function themes.rescan()
  themes.list = themes.discover()
  return themes.list
end

function themes.path(name)
  for _, root in ipairs(roots()) do
    local p = fs.join(root, tostring(name), "theme.lua")
    if fs.is_file(p) then return p end
  end
  return nil
end

function themes.discover()
  local found, seen = {}, {}
  for _, root in ipairs(roots()) do
    for _, entry in ipairs(fs.list(root) or {}) do
      if entry.type == "dir" and entry.name ~= ".git"
         and not seen[entry.name]
         and fs.is_file(fs.join(root, entry.name, "theme.lua")) then
        seen[entry.name] = true
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

function themes.load(name)
  local path = themes.path(name)
  if not path then return nil, "no such theme: " .. tostring(name) end
  local ok, t = pcall(dofile, path)
  if not ok then return nil, tostring(t) end
  if type(t) ~= "table" then return nil, "theme must return a table" end
  return t
end

function themes.apply(style, name)
  local t, err = themes.load(name)
  if not t then return false, err end

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

return themes
