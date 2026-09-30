-- The plugin loader.
--
-- Two roots, with deliberately different rules:
--
--   EXEDIR/data/plugins          bundled. Part of the build output, and
--                                mandatory: every entry here loads, always,
--                                whatever config.plugins or --no-plugins say.
--                                This is what makes a build a runnable editor.
--   config.site_dir/plugins      the user's site, and selected by
--                                config.plugins.
--
-- The loader knows nothing about where the bundled set came from. Whatever
-- produced it is not this repository's business; the only thing that knows is
-- the build, and it knows it as a path.
local core   = require "core"
local fs     = require "core.fs"
local config = require "core.config"

local plugins = {}

plugins.loaded = {}

local SEP = PATHSEP or package.config:sub(1, 1)
-- package.path entries are separated by package.config's SECOND line, which
-- is ';' on every platform. It is a different character from the path
-- separator, so it cannot be substituted for it: joining new entries with
-- the path separator fuses them into the last existing entry instead of
-- adding to the list, and the list stops being a list.
local PATH_LIST_SEP = package.config:match("\n(.-)\n") or ";"

local function bundled_dir()
  return fs.join(EXEDIR or ".", "data", "plugins")
end

-- Resolved through config.site_path() rather than read off the table, so
-- that renaming the site directory in the user's init.lua is honoured.
local function site_dir()
  return config.site_path()
end

local function site_plugins_dir()
  return fs.join(site_dir(), "plugins")
end

-- Entry points of one plugins root, sorted by name: a directory with an
-- init.lua, or a top-level <name>.lua file.
local function entry_points(dir)
  local points = {}
  if not dir or not fs.is_dir(dir) then return points end

  for _, entry in ipairs(fs.list(dir) or {}) do
    if entry.type == "dir" then
      local init_file = fs.join(dir, entry.name, "init.lua")
      if fs.is_file(init_file) then
        points[#points + 1] = { name = entry.name, path = init_file }
      end
    elseif entry.type == "file" and entry.name:match("%.lua$") then
      local name = entry.name:match("^(.+)%.lua$")
      points[#points + 1] = { name = name, path = fs.join(dir, entry.name) }
    end
  end

  table.sort(points, function(a, b) return a.name < b.name end)
  return points
end

-- Every entry of both roots, bundled first, one row per name. A bundled
-- plugin always wins over a site plugin of the same name, on disk and at
-- runtime alike.
local function all_entries()
  local seen, result = {}, {}
  for _, source in ipairs({ "bundled", "site" }) do
    local dir = source == "bundled" and bundled_dir() or site_plugins_dir()
    for _, entry in ipairs(entry_points(dir)) do
      if not seen[entry.name] then
        seen[entry.name] = true
        entry.source = source
        result[#result + 1] = entry
      end
    end
  end
  return result
end

-- Site modules are reachable as SITE/<name>.lua and SITE/<name>/init.lua, so
-- a plugin's `require "some.module"` finds SITE/some/module.lua and
-- `require "some.module"` finds SITE/some/module/init.lua.
--
-- The roots are APPENDED, never prepended. A site may add extensions to the
-- editor; it may not shadow the core it extends, nor the bundled X.* modules
-- that the runtime itself loads first.
local function extend_package_path()
  local dir = site_dir()
  if not dir or not fs.is_dir(dir) then return false end
  package.path = package.path
    .. PATH_LIST_SEP .. fs.join(dir, "?.lua")
    .. PATH_LIST_SEP .. fs.join(dir, "?", "init.lua")
  return true
end

-- config.plugins selects the SITE set only. The bundled set is mandatory and
-- is not affected by this value in any of its forms.
local function site_wants(name)
  local want = config.plugins
  if want == nil then return true end
  if type(want) ~= "table" then return true end

  for _, n in ipairs(want) do
    if n == name then return true end
  end
  return false
end

local function load_entry(entry)
  if plugins.loaded[entry.name] then return true end

  local ok, mod = pcall(dofile, entry.path)
  if not ok then return false, tostring(mod) end
  if type(mod) ~= "table" then return false, "entry point must return a table" end

  if mod.init then
    local init_ok, init_err = pcall(mod.init, core, config)
    if not init_ok then return false, "init failed: " .. tostring(init_err) end
  end

  plugins.loaded[entry.name] = mod
  plugins.loaded[entry.name].source = entry.source
  return true
end

-- Loads the bundled set, then the site set. A plugin that raises is logged
-- and skipped: one broken plugin must not cost the user their editor.
function plugins.load_all()
  extend_package_path()

  -- Bundled first and unconditionally. A mandatory plugin that fails is an
  -- error worth shouting about, but startup continues either way: the editor
  -- without vim is degraded, not unusable.
  for _, entry in ipairs(entry_points(bundled_dir())) do
    entry.source = "bundled"
    local ok, err = load_entry(entry)
    if not ok then
      core.error("mandatory plugin %s: %s", entry.name, err)
    end
  end

  if config.plugins == false then return true end

  for _, entry in ipairs(entry_points(site_plugins_dir())) do
    entry.source = "site"
    if site_wants(entry.name) then
      local ok, err = load_entry(entry)
      if not ok then
        core.log("plugin %s: %s", entry.name, err)
      end
    end
  end

  return true
end

function plugins.list()
  local result = {}
  for _, entry in ipairs(all_entries()) do
    result[#result + 1] = {
      name = entry.name,
      path = entry.path,
      init = entry.path,
      source = entry.source,
      loaded = plugins.loaded[entry.name] ~= nil,
    }
  end
  return result
end

-- Loads one plugin by name, whatever config.plugins said. config.plugins
-- decides what loads *on its own*; naming a plugin explicitly is the :packadd
-- case and is how a bare editor stays useful rather than merely empty, so it
-- is not gated on the site set being enabled.
function plugins.load(name)
  if plugins.loaded[name] then return true end

  for _, entry in ipairs(all_entries()) do
    if entry.name == name then
      return load_entry(entry)
    end
  end
  return false, "no such plugin: " .. tostring(name)
end

function plugins.unload(name)
  local mod = plugins.loaded[name]
  if not mod then return true end

  if mod.unload then
    local ok, err = pcall(mod.unload)
    if not ok then return false, "unload failed: " .. tostring(err) end
  end

  plugins.loaded[name] = nil
  return true
end

function plugins.autoload_list()
  return config.plugins
end

return plugins
