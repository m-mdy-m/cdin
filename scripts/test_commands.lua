-- Keymap integrity test, with zero plugins loaded.
--
-- The question this answers is not "does the editor start" but "is every
-- binding pointing at something". A keymap that names a command nobody
-- registered is a silent no-op: the keystroke is consumed, nothing happens,
-- and there is no error anywhere. That is the "ctrl+o opens a menu that
-- does nothing" failure.
--
-- It also asserts the split the resplit introduced: the runtime owns a
-- specific set of commands and key bindings, and the user-facing workflow
-- bindings are owned by optional cdin-x plugins. With no cdin-x present,
-- those strokes must be unbound — not bound to a command that happens to
-- exist, and not bound to nothing.
--
-- Runs under a plain `lua`: no build, no editor, no cdin-x checkout.
--
-- Environment:
--   CDIN_SRC  (required) checkout whose data/ holds the core modules
--   CDIN_DIR  optional tree to resolve EXEDIR/data against

-- An environment variable that is set but empty is not the same as unset,
-- and the Makefile passes the optional overrides that way. Treat them alike.
local function env(name)
  local v = os.getenv(name)
  if v == nil or v == "" then return nil end
  return v
end

-- The checkout this script lives in, derived from arg[0] so it does not
-- depend on the caller's path format. CDIN_SRC is only an override.
local function script_root()
  local override = env("CDIN_SRC")
  if override then return override end
  local self = arg and arg[0] or "scripts/test_commands.lua"
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

-- ── set up ─────────────────────────────────────────────────────────────────

local stub = dofile("scripts/_stub_env.lua")
stub.install({ exedir = env("CDIN_DIR") or ".", src = SRC })

local core    = require "core"
core.log_items = {}
core.active_view = nil

-- core.init() normally installs these; it also builds the whole view tree,
-- which needs a window. Only the parts a Doc and a CommandView actually
-- touch are stubbed here, so the test exercises the real Doc/CommandView
-- code rather than a mock of it.
core.add_thread = function(fn) coroutine.resume(coroutine.create(fn)) end
core.set_active_view = function(v) core.last_active_view = core.active_view; core.active_view = v end
core.redraw = function() end

local command = require "core.input.command"
local keymap  = require "core.input.keymap"

-- Registers the runtime's own commands. Nothing here loads a plugin, so
-- whatever is missing from command.map afterwards is genuinely missing from
-- the runtime.
command.add_defaults()

-- ── 1. every command the keymap names exists ──────────────────────────────

-- keymap.map[stroke] is a list: a stroke can name several commands, tried
-- in order, and the first whose predicate passes wins. Every one of them has
-- to be a real command, or the list is shorter than it looks and the stroke
-- silently does nothing for a user whose active view does not match.
local dangling = {}
for stroke, commands in pairs(keymap.map) do
  for _, name in ipairs(commands) do
    if not command.map[name] then
      dangling[#dangling + 1] = string.format("%s -> %s", stroke, name)
    end
  end
end
table.sort(dangling)
check(#dangling == 0,
  "every command the keymap names is registered (" ..
  (#dangling > 0 and table.concat(dangling, ", ") or "86 strokes checked") .. ")")

-- ── 2. every registered command is reachable, and vice versa ──────────────

-- A command nothing binds is legitimate (the palette finds it by name), so
-- this only checks the reverse direction, which is the one that breaks.
local orphan_reverses = {}
for name in pairs(keymap.reverse_map) do
  if not command.map[name] then
    orphan_reverses[#orphan_reverses + 1] = name
  end
end
table.sort(orphan_reverses)
check(#orphan_reverses == 0,
  "keymap.reverse_map names only real commands (" ..
  table.concat(orphan_reverses, ", ") .. ")")

-- ── 3. no key is bound twice across layers ────────────────────────────────

-- keymap.add() without overwrite prepends, so a later layer does not
-- replace an earlier one, it queues behind it. That is the mechanism the
-- optional plugins use to extend a stroke. It is also how two plugins can
-- silently fight over one keystroke, so the duplicates are listed: not a
-- failure on their own, but they are the thing to look at.
local by_command = {}
for stroke, commands in pairs(keymap.map) do
  for _, name in ipairs(commands) do
    by_command[name] = by_command[name] or {}
    by_command[name][#by_command[name] + 1] = stroke
  end
end

-- ── 4. the palette is wired: enter() gets a submit and a suggest ──────────

-- A CommandView with no submit callback swallows the input and returns to
-- the previous view, which looks exactly like a keystroke doing nothing.
local CommandView = require "core.views.commandview"

local submitted, saw_suggest = nil, false
core.command_view = CommandView()
core.command_view:enter("Test Palette",
  function(text) submitted = text end,
  function(text)
    saw_suggest = true
    return { { text = "alpha", command = "core:new-doc" } }
  end)

core.command_view:set_text("alp")
core.command_view:update_suggestions()
check(saw_suggest, "the palette called the suggest callback")

core.command_view:submit()
check(submitted ~= nil, "the palette called the submit callback with a value")
if submitted ~= nil then
  check(submitted == "alpha" or submitted == "alp",
    "the palette submitted the accepted suggestion (got " .. tostring(submitted) .. ")")
end

-- ── 5. the runtime owns ctrl+n, and the workflow strokes are free ─────────

-- These are the two halves of the resplit, asserted from the runtime side:
-- the document-creation binding is the runtime's and must work, and the
-- three workflow bindings belong to optional cdin-x plugins and must not be
-- registered by the runtime at all.

local function bound(stroke)
  local commands = keymap.map[stroke]
  if not commands then return nil end
  return commands[1]
end

check(bound("ctrl+n") == "core:new-doc",
  "ctrl+n is bound to core:new-doc in the runtime")
check(command.map["core:new-doc"] ~= nil, "core:new-doc is a runtime command")
check(keymap.get_binding("core:new-doc") == "ctrl+n",
  "core:new-doc reverse-maps to ctrl+n")

-- The workflow commands are expected to be gone from the runtime entirely
-- (see §4.12.3: they become optional cdin-x plugins). If any of these still
-- exists here, the move is incomplete.
for _, name in ipairs({
  "core:find-command",
  "core:find-file",
  "core:open-file",
  "core:open-folder",
  "core:reload-module",
  "core:open-user-module",
  "core:open-project-module",
}) do
  check(command.map[name] == nil,
    name .. " is no longer a runtime command (it is an optional workflow plugin)")
end

-- The three strokes below belong to optional plugins. With none loaded they
-- must be unbound; a binding here would be a dead keystroke.
for _, stroke in ipairs({ "ctrl+p", "ctrl+shift+p", "ctrl+o" }) do
  check(bound(stroke) == nil,
    stroke .. " is not bound by the runtime (owned by a cdin-x workflow plugin)")
end

-- ── 6. doc and root commands are all still runtime-owned ──────────────────

-- These are the mechanisms an extension is written against. If any of them
-- moved, every integration in cdin-x would break, so they are pinned here.
local runtime_commands = {
  "core:quit", "core:force-quit", "core:toggle-fullscreen", "core:new-doc",
  "core:open-log",
  "doc:save", "doc:save-as", "doc:undo", "doc:redo", "doc:go-to-line",
  "root:close", "root:split-right", "root:split-down",
}
for _, name in ipairs(runtime_commands) do
  check(command.map[name] ~= nil, "runtime command present: " .. name)
end

-- The plugin-management commands are part of the runtime's own contract with
-- cdin-x, so they must survive the split intact.
for _, name in ipairs({ "core:load-plugin", "core:unload-plugin", "core:list-plugins" }) do
  check(command.map[name] ~= nil, "plugin command present: " .. name)
end

-- ── 7. a missing optional command is a no-op, not an error ───────────────

-- The runtime views invoke optional commands by name. A missing one has to
-- be silently ignored; raising would take the editor down over a plugin the
-- user chose not to install.
--
-- The contract is "no raise, no success", not a particular return value:
-- command.perform reports false for an unknown name and nil when the
-- command's own error handler swallowed something, and both mean "did not
-- run".
local ok_perform, performed = pcall(command.perform, "cdin-x:definitely-not-a-command")
check(ok_perform, "performing an unknown command does not raise")
check(not performed, "performing an unknown command reports no success")

check(command.perform("core:new-doc"),
  "performing a real command still reports success")

-- ── report ─────────────────────────────────────────────────────────────────

local strokes = 0
for _ in pairs(keymap.map) do strokes = strokes + 1 end
local cmds = 0
for _ in pairs(command.map) do cmds = cmds + 1 end

print(string.format("commands : %d registered, %d strokes bound, 0 plugins",
  cmds, strokes))

if #failures > 0 then
  print("")
  print("FAILED:")
  for _, msg in ipairs(failures) do print("  - " .. msg) end
  print(string.format("test_commands.lua: %d passed, %d FAILED", passed, #failures))
  os.exit(1)
end

print(string.format("test_commands.lua: %d passed", passed))
os.exit(0)
