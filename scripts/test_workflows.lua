-- The user-facing workflows, tested from the cdin-x side.
--
-- `test_commands.lua` answers the negative half: with no extensions, the
-- runtime owns `ctrl+n` and binds none of the workflow strokes. This answers
-- the positive half — with a cdin-x checkout installed, the workflow plugins
-- register their commands, own exactly the strokes the split moved, and can
-- be unloaded back out again.
--
-- The split is only real if there is exactly one owner of `ctrl+p`,
-- `ctrl+shift+p` and `ctrl+o`, and if that owner is cdin-x. That is the whole
-- question this file asks.
--
-- Runs under a plain `lua`: no build, no editor, no network.
--
-- Environment:
--   CDIN_SRC   (required) checkout whose data/ holds the core modules
--   CDINX_DIR  (required) a cdin-x checkout, used as the site directory
--   CDIN_SITE  "full" (default) | "empty" — empty means "no cdin-x", and the
--              workflow commands must then be absent and the strokes unbound

-- An environment variable that is set but empty is not the same as unset,
-- and the Makefile passes the optional overrides that way. Treat them alike.
local function env(name)
  local v = os.getenv(name)
  if v == nil or v == "" then return nil end
  return v
end

local function script_root()
  local override = env("CDIN_SRC")
  if override then return override end
  local self = arg and arg[0] or "scripts/test_workflows.lua"
  local dir = self:match("^(.*)[/\\][^/\\]+$") or "."
  local root = dir:gsub("[/\\]scripts$", "")
  if root == "" then root = "." end
  return root
end

local SRC = script_root()

local CDINX = env("CDINX_DIR")
if not CDINX then
  print("test_workflows.lua: CDINX_DIR is not set — this test needs a cdin-x checkout")
  os.exit(1)
end

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

local function report()
  if #failures == 0 then return end
  print("")
  print("FAILED:")
  for _, msg in ipairs(failures) do print("  - " .. msg) end
  print(string.format("test_workflows.lua: %d passed, %d FAILED", passed, #failures))
end

-- ── set up ─────────────────────────────────────────────────────────────────

-- cdin-x is used as the site directory directly rather than being installed
-- into one. Its checkout has exactly the shape scripts/install.py produces
-- (cdinx/, X/, plugins/cdin-x/), so pointing config.site_dir at it exercises
-- the same resolution without copying a tree the test then has to clean up.
local SITE = (os.getenv("CDIN_SITE") or "full") ~= "empty" and CDINX or nil

local stub = dofile("scripts/_stub_env.lua")
stub.install({ exedir = ".", src = SRC })

local config = require "core.config"
config.site_dir = SITE
config.plugins = nil

local core = require "core"
core.log_items = {}
core.active_view = nil

-- An active view has to exist from the start, not only once the behavioural
-- section reaches the palette. A view-class predicate does
-- `core.active_view:is(class)`, so every command in command.map raises on a
-- nil active view — and the palette calls command.get_all_valid(), which
-- evaluates every predicate with no pcall of its own. A real editor always has
-- one; headless has to be given one or nothing with a predicate can run.
local View = require "core.views.view"
local StubView = View:extend()
StubView.get_name = function() return "workflows-test" end
local stub_view = StubView()

-- common.fuzzy_match calls system.fuzzy_match, which is a C function
-- (src/search/find.c) the pure-Lua stub does not carry, and the palette and
-- both finders go through it. Ported from the C scorer so the ranking under
-- test is the real one: a run of consecutive matches is worth more than the
-- same characters scattered, and a shorter haystack scores higher.
system.fuzzy_match = function(str, ptn)
  if type(str) ~= "string" or type(ptn) ~= "string" then return nil end
  local s, run, i, j = 0, 0, 1, 1
  while i <= #str and j <= #ptn do
    if str:sub(i, i) == " " then i = i + 1
    elseif ptn:sub(j, j) == " " then j = j + 1
    else break end
  end
  while i <= #str and j <= #ptn do
    local a, b = str:lower():sub(i, i), ptn:lower():sub(j, j)
    if a == b then
      s = s + run * 10 - (str:sub(i, i) == ptn:sub(j, j) and 0 or 1)
      run, j = run + 1, j + 1
    else
      s, run = s - 10, 0
    end
    i = i + 1
  end
  if j <= #ptn then return nil end
  return s - (#str - i + 1)
end

core.add_thread = function(fn) coroutine.resume(coroutine.create(fn)) end
-- nil is refused, unlike the real set_active_view. Plugins call it during
-- load with whatever their own partially-built tree happens to hold, and the
-- real one asserts on that; here it would drop the stub view on the floor and
-- every predicate would go back to raising on a nil active view.
core.set_active_view = function(v)
  if v == nil then return end
  core.last_active_view = core.active_view
  core.active_view = v
end
core.redraw = function() end

-- The bare minimum of a view tree. cdin-x's entry plugin splits the root node
-- open for its panel at load time, and the workflow plugins open what they
-- resolve, so a headless run has to offer something for both. This is the
-- same reason test_commands.lua stubs add_thread and set_active_view: core.init
-- builds the real tree, and building it needs a window.
--
-- Deliberately not a RootView, but it is a table of the right shape rather
-- than an empty one. Two node methods matter here: `tab`'s restore calls
-- root_node:update_layout(), and a doc opened by the workflow commands is
-- saved by doc:save(). Both are extension code asking the runtime for
-- something the runtime owns, so a headless run has to offer it — a mock that
-- answered with whatever each caller wanted would test nothing.
--
-- Anything past these is reported rather than papered over.
local function fake_node()
  return {
    views = {}, active_view = nil,
    position = { x = 0, y = 0 }, size = { x = 0, y = 0 },
    get_locked_size = function() return false end,
    split = function() end,
    add_view = function() end,
    update_layout = function() end,
    get_children = function() return {} end,
    get_node_for_view = function() return nil end,
    set_active_view = function(self, v) self.active_view = v end,
    get_active_node = function(self) return self end,
  }
end

local node = fake_node()
core.root_view = {
  root_node = node,
  get_active_node = function() return node end,
  open_doc = function() end,
  defer_draw = function() end,
  add_view = function() end,
}

local command = require "core.input.command"
local keymap  = require "core.input.keymap"
command.add_defaults()

-- ── the split, asserted from both sides ───────────────────────────────────

-- Every workflow command the split moved, and the plugin that now owns it.
-- Both halves matter: the command has to be the moved one, and it has to be
-- registered by the plugin that owns the keystroke, not by the runtime.
local WORKFLOWS = {
  { name = "core:find-command",         plugin = "palette", stroke = "ctrl+shift+p" },
  { name = "core:find-file",            plugin = "finder",  stroke = "ctrl+p"       },
  { name = "core:open-file",            plugin = "finder",  stroke = "ctrl+o"       },
  { name = "core:open-folder",          plugin = "finder",  stroke = "ctrl+shift+o" },
  { name = "core:reload-module",        plugin = "modules"                    },
  { name = "core:open-user-module",     plugin = "modules"                    },
  { name = "core:open-project-module",  plugin = "modules"                    },
}

local STROKES = { "ctrl+p", "ctrl+shift+p", "ctrl+o", "ctrl+shift+o" }
local PLUGINS = { "palette", "finder", "modules" }

local function bound(stroke)
  local list = keymap.map[stroke]
  return list and list[1] or nil
end

local function bound_all(stroke)
  local out = {}
  for _, name in ipairs(keymap.map[stroke] or {}) do out[#out + 1] = name end
  return out
end

-- 1. With no cdin-x: the runtime still does not own any of them.
if not SITE then
  for _, wf in ipairs(WORKFLOWS) do
    check(command.map[wf.name] == nil, wf.name .. " is not a runtime command")
  end
  for _, stroke in ipairs(STROKES) do
    check(bound(stroke) == nil, stroke .. " is unbound with no cdin-x")
  end
  check(bound("ctrl+n") == "core:new-doc", "ctrl+n stays a runtime binding")

  print("site     : (none)")
  print("workflows: 0 loaded, 4 strokes unbound")
  report()
  print(string.format("test_workflows.lua: %d passed", passed))
  os.exit(0)
end

-- 2. With cdin-x: the manager boots and the workflow plugins register.

local plugins = require "core.plugins"
plugins.load_all()

if not check(plugins.loaded["cdin-x"] ~= nil, "the cdin-x entry plugin loaded") then
  local messages = {}
  for _, item in ipairs(core.log_items) do
    messages[#messages + 1] = tostring(item.text)
  end
  print("  loader log: " .. table.concat(messages, " | "))
end

local Manager = require "cdinx.manager"
local available = Manager.list()

-- Loading the catalog can move the active view (a plugin that restores its own
-- panel does), so it is put back before anything evaluates a predicate. A real
-- editor lands on a docview or a plugin view; the exact class is irrelevant
-- here, only that something is active.
core.active_view = stub_view

for _, wf in ipairs(WORKFLOWS) do
  check(command.map[wf.name] ~= nil, wf.name .. " is registered by " .. wf.plugin)
  check(available[wf.plugin] ~= nil, wf.plugin .. " is in the catalog")
end

-- 3. Every registered predicate is callable. The palette's first act is
--    command.get_all_valid(), which evaluates all of them with no pcall, so one
--    that raises takes the whole palette down before it opens.
do
  local raised = {}
  for name, cmd in pairs(command.map) do
    local ok, err = pcall(cmd.predicate)
    if not ok then raised[#raised + 1] = name end
  end
  check(#raised == 0, "every command predicate is callable (" .. #raised .. " raise)")
end

-- 4. The strokes the split moved are owned by the workflow plugin, and by
--    nothing else.
--
--    bound_all rather than bound: keymap.add without overwrite PREPENDS, so a
--    second owner of one stroke queues behind the first rather than replacing
--    it. Only the first entry would ever be reached, and the second would sit
--    there looking harmless. Listing every command on the stroke is what makes
--    a duplicate visible.
for _, wf in ipairs(WORKFLOWS) do
  if wf.stroke then
    local list = bound_all(wf.stroke)
    check_eq(#list, 1, wf.stroke .. " has exactly one command bound to it")
    check_eq(list[1], wf.name, wf.stroke .. " runs " .. wf.name)
  end
end

-- 5. The reverse map agrees with the forward one. The palette reads
--    keymap.get_binding to print the keystroke next to each command, so a
--    stroke that binds correctly but does not reverse-map shows a command
--    with no key — a wrong answer, not a missing one.
for _, wf in ipairs(WORKFLOWS) do
  if wf.stroke then
    check_eq(keymap.get_binding(wf.name), wf.stroke,
      wf.name .. " reverse-maps to " .. wf.stroke)
  end
end

-- 6. The runtime's own keymap file names none of them. Checked against the
--    source rather than the loaded table, because the loaded table is what the
--    plugins have already extended: a stale line in
--    data/core/keymaps/default.lua is the failure mode, and once keymap.add
--    has prepended a plugin's command in front of it, the loaded table no
--    longer shows it.
local default_src = nil
do
  local handle = io.open("data/core/keymaps/default.lua", "rb")
  default_src = handle and handle:read("*a") or ""
  if handle then handle:close() end
end
check(default_src ~= "", "data/core/keymaps/default.lua is readable")
for _, stroke in ipairs(STROKES) do
  check(not default_src:find('["' .. stroke .. '"]', 1, true),
    "data/core/keymaps/default.lua does not bind " .. stroke)
end

-- The runtime keymap is otherwise intact.
check(bound("ctrl+n") == "core:new-doc", "ctrl+n is still core:new-doc")
check(keymap.get_binding("core:new-doc") == "ctrl+n",
  "core:new-doc still reverse-maps to ctrl+n")
check(bound("ctrl+s") == "doc:save", "ctrl+s is still doc:save")
check(bound("ctrl+w") == "root:close", "ctrl+w is still root:close")

-- 7. Every workflow command actually runs. Registration is not behaviour: a
--    command can be in command.map and still do nothing, which looks exactly
--    like a keystroke being swallowed.
--
--    Driven through a prompt stand-in that records the label and the
--    suggestions and then submits the first one, so the whole path runs —
--    command -> command_view:enter -> suggest -> submit — rather than just the
--    entry.
--
--    `core.active_view` and `system.fuzzy_match` are set above, before the
--    loader ran, because every predicate and every suggester needs them.
--
--    One entry in core.project_files, so core:find-file has something to
--    suggest, and the working directory has real subdirectories, so
--    core:open-folder has something to offer.
core.project_files = {
  { type = "file", filename = "workflow-probe.txt" },
}

local function new_lines_since(mark)
  local out = {}
  for i = mark + 1, #core.log_items do
    out[#out + 1] = tostring(core.log_items[i].text)
  end
  return out
end

-- Runs `name` and reports what the prompt did. Returns label, #suggestions.
local function drive(name, typed)
  local label, count = nil, 0
  local opened_docs, switched_to, saved = {}, {}, {}

  core.command_view = {
    enter = function(_, l, submit, suggest)
      label = l
      local items = suggest(typed or "") or {}
      count = #items
      submit(typed or "", items[1])
    end,
  }
  -- save() because core:open-project-module creates .lite_project.lua and
  -- saves it; a returned table with no save raises, and the raise is caught
  -- and logged, so the command would look like it worked.
  core.open_doc = function(p)
    opened_docs[#opened_docs + 1] = p
    return { filename = p, save = function(_, to) saved[#saved + 1] = to end }
  end
  core.root_view.open_doc = function(_, d) opened_docs[#opened_docs + 1] = d end
  core.set_project_dir = function(p) switched_to[#switched_to + 1] = p; return true end

  local mark = #core.log_items
  local performed = command.perform(name)
  local logged = new_lines_since(mark)
  return {
    performed = performed, label = label, count = count,
    opened = opened_docs, switched = switched_to, saved = saved, logged = logged,
  }
end

-- A raise inside a workflow command is swallowed by command.perform and lands
-- in the log, so "no error lines" is the assertion — not the return value,
-- which reports success either way.
local function no_errors(run, name)
  local bad = {}
  for _, line in ipairs(run.logged) do
    -- a logged error names the file and line that raised
    if line:find("%.lua:%d+:") then bad[#bad + 1] = line end
  end
  check(#bad == 0,
    #bad == 0 and (name .. " raised nothing")
      or (name .. " raised: " .. table.concat(bad, " | ")))
end

local r = drive("core:find-command", "")
check(r.performed, "core:find-command performs")
check(r.label ~= nil, "core:find-command opened the palette (label " .. tostring(r.label) .. ")")
no_errors(r, "core:find-command")
check(r.count > 0, "the palette listed commands (" .. r.count .. ")")

r = drive("core:find-file", "probe")
check(r.performed, "core:find-file performs")
no_errors(r, "core:find-file")
check(r.count > 0, "core:find-file offered a suggestion (" .. r.count .. ")")

r = drive("core:open-file", "workflow-probe.txt")
check(r.performed, "core:open-file performs")
no_errors(r, "core:open-file")

-- The one that had no directories in it. A directory suggester reading
-- system.list_dir (an array of names) filters every entry out and returns
-- nothing, with nothing logged — so this is asserted on the count.
r = drive("core:open-folder", "")
check(r.performed, "core:open-folder performs")
no_errors(r, "core:open-folder")
check(r.count > 0, "core:open-folder offered a directory (" .. r.count .. ")")

r = drive("core:open-user-module", "")
check(r.performed, "core:open-user-module performs")
no_errors(r, "core:open-user-module")
check(#r.opened > 0, "core:open-user-module opened a file")

r = drive("core:open-project-module", "")
check(r.performed, "core:open-project-module performs")
no_errors(r, "core:open-project-module")
check(#r.opened > 0, "core:open-project-module opened a file")

-- reload-module both ways. A module that loads, and one that does not: the
-- second is the path that reported "undefined variable: core" instead of the
-- reason the require failed.
core.command_view = { enter = function(_, _, submit) submit("core.utils.common", nil) end }
local mark = #core.log_items
command.perform("core:reload-module")
no_errors({ logged = new_lines_since(mark) }, "core:reload-module (module that loads)")

core.command_view = { enter = function(_, _, submit) submit("no.such.module.anywhere", nil) end }
mark = #core.log_items
command.perform("core:reload-module")
no_errors({ logged = new_lines_since(mark) }, "core:reload-module (module that fails)")

-- 8. unload() genuinely detaches. This is the half that keeps a reload from
--    accumulating a second copy of every keystroke: unload palette, finder and
--    modules, and the commands and the strokes must be gone, not merely
--    shadowed.
--
--    Through the manager, not core.plugins: the host loader loaded the single
--    cdin-x entry plugin, and the manager is what loaded palette, finder and
--    modules underneath it. Asking the host loader to unload a plugin it never
--    loaded reports success and does nothing — which is exactly the shape of
--    bug this assertion exists to catch.
for _, name in ipairs(PLUGINS) do
  local ok, err = Manager.unload_plugin(name)
  check(ok, name .. " unloaded: " .. tostring(err))
end

for _, wf in ipairs(WORKFLOWS) do
  check(command.map[wf.name] == nil, wf.name .. " is gone after unload")
end
for _, stroke in ipairs(STROKES) do
  check(bound(stroke) == nil, stroke .. " is unbound after unload")
end
check(bound("ctrl+n") == "core:new-doc", "ctrl+n is untouched by unloading cdin-x")

-- And they come back, which is what makes it a reload rather than a removal.
for _, name in ipairs(PLUGINS) do
  local ok, err = Manager.load_plugin(name)
  check(ok, name .. " loaded again: " .. tostring(err))
end
for _, wf in ipairs(WORKFLOWS) do
  check(command.map[wf.name] ~= nil, wf.name .. " is registered again after reload")
end
for _, stroke in ipairs(STROKES) do
  check_eq(#bound_all(stroke), 1,
    stroke .. " still has exactly one command after reload")
end

-- ── report ─────────────────────────────────────────────────────────────────

print(string.format("site     : %s", SITE))
print(string.format("plugins  : %d loaded", (function()
  local n = 0 for _ in pairs(plugins.loaded) do n = n + 1 end return n
end)()))
print("workflows: palette, finder, modules")

if #failures > 0 then
  report()
  os.exit(1)
end

print(string.format("test_workflows.lua: %d passed", passed))
os.exit(0)
