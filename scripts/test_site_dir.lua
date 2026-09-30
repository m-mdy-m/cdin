-- The site directory name: one knob, and the two halves of the system
-- cannot disagree about it.
--
-- Needs `lua` and a cdin-x checkout (CDINX_DIR). No build, no editor.

local SRC  = os.getenv("CDIN_SRC") or "."
local CDINX = os.getenv("CDINX_DIR") or (SRC .. "/../cdin-x")

local stub = dofile("scripts/_stub_env.lua")
stub.install({ exedir = ".", src = SRC })

local passed, failures = 0, {}
local function check(cond, msg)
  passed = passed + 1
  if not cond then failures[#failures + 1] = msg end
end

local function read(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a"); f:close(); return s
end

-- ── cdin: config.site_dirname exists, and site_path() follows it ──────────

local config = require "core.config"

check(type(config.site_dirname) == "string" and config.site_dirname ~= "",
  "config.site_dirname is a non-empty string")
check(type(config.site_path) == "function", "config.site_path() exists")

local sep = config.sep
local base = config.data_home .. sep

check(config.site_path() == base .. "site",
  "default resolves to <data_home>/site, got " .. tostring(config.site_path()))

-- The whole point: one assignment, and every consumer follows.
config.site_dirname = "extensions"
check(config.site_path() == base .. "extensions",
  "renaming site_dirname renames the resolved path, got " .. tostring(config.site_path()))

-- And it has to be lazy: the user's init.lua runs after this module was
-- required, so a value cached at load time would already be fixed.
config.site_dirname = "site"
local plugins = require "core.plugins"
config.site_dirname = "addons"
local listed = {}
for _, e in ipairs(plugins.list()) do listed[e.name] = e end
check(listed.demo == nil or listed.demo.source ~= nil,
  "plugins.list() still works after a rename")
check(type(config.site_path()) == "string",
  "site_path() is callable after a rename (no stale cache)")
config.site_dirname = "site"

-- A full path beats the name entirely.
local saved = config.site_dir
config.site_dir = base .. "somewhere-else"
check(config.site_path() == base .. "somewhere-else",
  "config.site_dir overrides the name entirely")
config.site_dir = saved

-- ── cdin-x: the installer default must equal cdin's knob ────────────────

local install_src = read(CDINX .. "/scripts/install.py")
if check(install_src ~= nil, "read " .. CDINX .. "/scripts/install.py") then
  local py_name = install_src:match('SITE_DIRNAME%s*=%s*"([^"]*)"')
  check(py_name ~= nil, "install.py declares SITE_DIRNAME")
  check(py_name == config.site_dirname,
    string.format(
      "install.py's SITE_DIRNAME (%s) matches cdin's config.site_dirname (%s). "
      .. "These are the only duplicated value in the system; if they differ, "
      .. "the installer writes where the loader does not look.",
      tostring(py_name), tostring(config.site_dirname)))

  check(install_src:match("CDIN_SITE_DIRNAME") ~= nil,
    "install.py honours CDIN_SITE_DIRNAME")
  check(install_src:match("%-%-site%-name") ~= nil,
    "install.py exposes --site-name")
end

-- ── cdin-x: the runtime must read the host's resolver ────────────────────
-- It must not recompute the path, or a rename would apply to the loader and
-- not to the manager.

local cdinx_cfg = read(CDINX .. "/cdinx/config.lua")
if check(cdinx_cfg ~= nil, "read " .. CDINX .. "/cdinx/config.lua") then
  check(cdinx_cfg:match("config%.site_dir%s*=%s*config%.site_path%(%)") ~= nil,
    "cdinx reads config.site_path() rather than computing its own path")
  check(cdinx_cfg:match('cdin"%.%.%s*sep%.%.%s*"site"') == nil,
    "cdinx no longer hardcodes the directory name")
end

-- ── report ───────────────────────────────────────────────────────────────

print(string.format("site_dirname   : %s", config.site_dirname))
print(string.format("data_home      : %s", config.data_home))
print(string.format("resolved       : %s", config.site_path()))

if #failures > 0 then
  print("")
  print("FAILED:")
  for _, f in ipairs(failures) do print("  - " .. f) end
  print(string.format("test_site_dir.lua: %d passed, %d FAILED", passed, #failures))
  os.exit(1)
end

print(string.format("test_site_dir.lua: %d passed", passed))
os.exit(0)
