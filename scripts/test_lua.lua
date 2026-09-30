-- Data-layer test for the plugin loader and the theme registry.
--
-- Runs under a plain `lua`: no build, no editor, and no checkout of
-- anything.
-- The tree it exercises is assembled from scripts/fixtures/ into a temp
-- directory, so a change in data/plugins/ or data/themes/ cannot silently
-- turn this into a test of whatever happens to be on the developer's disk.
--
-- Environment:
--   CDIN_SRC       (required) checkout whose data/ holds the core modules
--   CDIN_DIR       optional prebuilt tree to test instead of a temp one
--   CDIN_SITE      "full" (default) | "empty"
--   CDIN_PLUGINS   "" (nil) | "false" | "name[,name...]" -> a whitelist
--
-- Separate processes on purpose: each run needs to require the core
-- against a fresh EXEDIR and a fresh config.plugins, and sharing one
-- process makes them fight over package.loaded.

-- An environment variable that is set but empty is not the same as unset,
-- and the Makefile passes the optional overrides that way. Treat them alike.
local function env(name)
  local v = os.getenv(name)
  if v == nil or v == "" then return nil end
  return v
end

-- The checkout this script lives in. Derived from arg[0] rather than trusted
-- from the environment, so it holds whatever shell or path format the caller
-- used; CDIN_SRC is only an override.
local function script_root()
  local override = env("CDIN_SRC")
  if override then return override end
  local self = arg and arg[0] or "scripts/test_lua.lua"
  local dir = self:match("^(.*)[/\\][^/\\]+$") or "."
  local root = dir:gsub("[/\\]scripts$", "")
  if root == "" then root = "." end
  return root
end

local SRC = script_root()

-- ── assertions ────────────────────────────────────────────────────────────

local passed, failures = 0, {}

local function check(cond, msg)
  passed = passed + 1
  if cond then return true end
  failures[#failures + 1] = msg
  return false
end

local function check_eq(got, want, msg)
  return check(got == want,
    string.format("%s: expected %s, got %s", msg, tostring(want), tostring(got)))
end

local function check_match(s, pattern, msg)
  return check(type(s) == "string" and s:find(pattern) ~= nil,
    string.format("%s: %s does not match %q", msg, tostring(s), pattern))
end

-- ── fixture tree ──────────────────────────────────────────────────────────

local stub = dofile("scripts/_stub_env.lua")

local sep = package.config:sub(1, 1)
local join = function(...) return table.concat({ ... }, sep) end

-- Copies a directory tree. The fixtures are a handful of small files, so
-- this is a plain recursive copy rather than a shell out.
local function copy_tree(src, dst)
  local fs = stub.fs
  fs.mkdir_all(dst)
  for _, name in ipairs(fs.list_dir(src) or {}) do
    local from, to = join(src, name), join(dst, name)
    local info = fs.stat(from)
    if info and info.type == "dir" then
      copy_tree(from, to)
    else
      local input = io.open(from, "rb")
      if input then
        local data = input:read("*a")
        input:close()
        local output = io.open(to, "wb")
        if output then output:write(data); output:close() end
      end
    end
  end
end

-- Builds the tree under test:
--   <tree>/data/plugins/…         bundled (mandatory, broken)
--   <tree>/data/themes/…          bundled theme
--   <tree>/data/site/plugins/…    site    (demo, raiser)
--   <tree>/data/site/X/themes/…   site theme
-- site = "empty" omits the site directory entirely, which is the state of
-- a user who has never installed an extension.
local function build_tree()
  local base = join(env("TEMP") or env("TMP") or ".", "cdin-test-lua")
  stub.fs.remove_all(base)

  local tree = base
  copy_tree(join(SRC, "scripts", "fixtures", "bundled"), join(tree, "data"))

  local want_site = (os.getenv("CDIN_SITE") or "full") ~= "empty"
  if want_site then
    copy_tree(join(SRC, "scripts", "fixtures", "site"), join(tree, "data", "site"))
  end

  return tree
end

local function parse_plugins()
  local raw = env("CDIN_PLUGINS")
  if raw == nil then return nil end
  if raw == "false" then return false end
  local names = {}
  for name in raw:gmatch("[^,%s]+") do names[#names + 1] = name end
  if #names == 0 then return nil end
  return names
end

-- ── set up ─────────────────────────────────────────────────────────────────

local tree = env("CDIN_DIR")
if tree then
  tree = tree:gsub("/+$", "")
else
  tree = build_tree()
end

local site_dir = join(tree, "data", "site")
local site_roots = {
  site_dir .. sep .. "?.lua",
  site_dir .. sep .. "?" .. sep .. "init.lua",
}

stub.install({ exedir = tree, src = SRC })

local config = require "core.config"
config.site_dir = site_dir
config.plugins = parse_plugins()

local core = require "core"
-- core.log_items is normally created by state.setup_state during
-- core.init(); the loader tests call load_all() directly, so the log sink
-- is set up here instead.
core.log_items = {}

local themes = require "core.themes"
local plugins = require "core.plugins"

local site_expected = (os.getenv("CDIN_SITE") or "full") ~= "empty"
local plugins_wanted = config.plugins

-- ── 6. package.path: site roots are appended, never prepended ─────────────

local path_before = package.path
-- EXEDIR/data/… is put on package.path by src/lua/api.c, and stub.install
-- mirrors it verbatim, forward slashes included.
local exedir_marker = tree .. "/data/?.lua"
local src_marker = SRC .. "/data/?.lua"

plugins.load_all()

local path_after = package.path
check(path_after:find(exedir_marker, 1, true) ~= nil, "EXEDIR data root is on package.path")
check(path_after:find(src_marker, 1, true) ~= nil, "core data root is on package.path")

-- Whether the site roots land on package.path is a property of the site
-- existing, not of config.plugins: load_all() extends the path before it
-- looks at the selection at all, because a later plugins.load() has to
-- reach them too.
if site_expected then
  check(path_after ~= path_before, "load_all() extends package.path when a site exists")
  for _, root in ipairs(site_roots) do
    check(path_after:find(root, 1, true) ~= nil, "site root is on package.path: " .. root)
  end
  local exedir_at = path_after:find(exedir_marker, 1, true)
  local src_at = path_after:find(src_marker, 1, true)
  local site_at = path_after:find(site_roots[1], 1, true)
  check(exedir_at and site_at and site_at > exedir_at,
    "site root comes AFTER the EXEDIR data root in package.path")
  check(src_at and site_at and site_at > src_at,
    "site root comes AFTER the core data root in package.path")
else
  check(path_after == path_before, "no site directory: package.path is left alone")
end

-- ── 1/2/3/4. what loads is a function of config.plugins ───────────────────

local loaded = plugins.loaded

local function describe(want)
  if want == nil then return "nil" end
  if want == false then return "false" end
  if type(want) == "table" then return "{" .. table.concat(want, ",") .. "}" end
  return tostring(want)
end

local function whitelisted(name)
  if type(plugins_wanted) ~= "table" then return false end
  for _, n in ipairs(plugins_wanted) do
    if n == name then return true end
  end
  return false
end

-- `demo` is the fixture that always loads, `raiser` the one that never
-- does, so their presence in plugins.loaded is a direct readout of the
-- selection rule rather than of anything incidental.
local want_demo
if not site_expected then want_demo = false        -- no site tree, nothing to select
elseif plugins_wanted == nil then want_demo = true  -- nil: everything in the site
elseif plugins_wanted == false then want_demo = false
else want_demo = whitelisted("demo") end

check(loaded.mandatory ~= nil,
  "mandatory bundled plugin loads with config.plugins=" .. describe(plugins_wanted))
check(loaded.broken == nil, "bundled plugin that raised is not in plugins.loaded")

check((loaded.demo ~= nil) == want_demo,
  string.format("config.plugins=%s: demo %s", describe(plugins_wanted),
    want_demo and "loads" or "does not load"))

check(loaded.raiser == nil, "a site plugin that raises is never in plugins.loaded")

if loaded.mandatory then
  check_eq(loaded.mandatory.inits, 1, "mandatory init() ran exactly once")
  check(loaded.mandatory.saw_core == true, "mandatory init() receives core")
  check(loaded.mandatory.saw_config == true, "mandatory init() receives config")
end

if want_demo then
  check_eq(loaded.demo.inits, 1, "demo init() ran exactly once")
  check(loaded.demo.saw_core == true, "demo init() receives core")
  check(loaded.demo.saw_config == true, "demo init() receives config")
end

if whitelisted("demo") then
  check(loaded.mandatory ~= nil,
    "the whitelist applies to the site set only: mandatory still loaded")
end

-- ── 5. a raising plugin is logged and skipped, startup continues ──────────

local function logged(pattern)
  for _, item in ipairs(core.log_items) do
    if type(item.text) == "string" and item.text:find(pattern) then return item.text end
  end
end

check_match(logged("mandatory plugin") or "", "mandatory plugin",
  "a failing mandatory plugin is reported with the words 'mandatory plugin'")
check_match(logged("broken") or "", "broken",
  "the failing mandatory plugin is named in the log")
check(loaded.mandatory ~= nil, "startup continued past a failing mandatory plugin")

if site_expected and (plugins_wanted == nil or whitelisted("raiser")) then
  check_match(logged("raiser") or "", "raiser",
    "a selected site plugin that raises is logged by name")
else
  check(logged("raiser") == nil, "an unselected site plugin is not even attempted")
end

-- ── 7. themes.add_root makes an extension's themes discoverable ───────────

local site_theme_root = join(site_dir, "X", "themes")
if site_expected then
  local listed_before = false
  for _, n in ipairs(themes.names()) do
    if n == "fixture-site" then listed_before = true end
  end
  check(listed_before == false, "site theme is not listed before add_root")

  check(themes.add_root(site_theme_root) == true, "themes.add_root accepts a directory")

  local listed_after = false
  for _, n in ipairs(themes.names()) do
    if n == "fixture-site" then listed_after = true end
  end
  check(listed_after, "themes.add_root rescans: the site theme is now listed")

  local t, err = themes.load("fixture-site")
  check(t ~= nil, "themes.load returns the site theme: " .. tostring(err))
  if t then
    check_eq(t.name, "fixture-site", "the loaded site theme self-identifies")
  end

  check(themes.add_root(join(site_dir, "does-not-exist")) == false,
    "themes.add_root ignores a non-directory")
  check(themes.add_root(site_theme_root) == true,
    "themes.add_root is idempotent for a root already added")
end

local bt = themes.load("fixture-bundled")
check(bt ~= nil, "the bundled fixture theme loads from the bundled root")
if bt then check_eq(bt.name, "fixture-bundled", "the bundled theme self-identifies") end

-- ── 8. plugins.load of an unknown name ────────────────────────────────────

local ok, err = plugins.load("nope")
check_eq(ok, false, "plugins.load(\"nope\") fails")
check_eq(err, "no such plugin: nope", "plugins.load(\"nope\") explains itself")

-- ── 9. list() reports where each plugin came from ─────────────────────────

local listing = {}
for _, entry in ipairs(plugins.list()) do listing[entry.name] = entry end

check_eq(listing.mandatory and listing.mandatory.source, "bundled",
  "list() reports mandatory as bundled")
check_eq(listing.mandatory and listing.mandatory.loaded, true,
  "list() reports mandatory as loaded")
if site_expected then
  check_eq(listing.demo and listing.demo.source, "site", "list() reports demo as site")
  check_eq(listing.raiser and listing.raiser.source, "site", "list() reports raiser as site")
end
check_eq(listing.broken and listing.broken.loaded, false,
  "list() reports a failed plugin as not loaded")

-- ── report ─────────────────────────────────────────────────────────────────

print(string.format("tree     : %s", tree))
print(string.format("site     : %s (%s)", site_dir, site_expected and "full" or "empty"))
print(string.format("plugins  : %s", plugins_wanted == nil and "nil"
  or (plugins_wanted == false and "false" or table.concat(plugins_wanted, ","))))
print(string.format("loaded   : %s", (function()
  local names = {}
  for name in pairs(loaded) do names[#names + 1] = name end
  table.sort(names)
  return #names > 0 and table.concat(names, " ") or "(none)"
end)()))

if #failures > 0 then
  print("")
  print("FAILED:")
  for _, msg in ipairs(failures) do print("  - " .. msg) end
  print(string.format("test_lua.lua: %d passed, %d FAILED", passed, #failures))
  os.exit(1)
end

print(string.format("test_lua.lua: %d passed", passed))
os.exit(0)
