local core = require "core"
local command = {}

command.map = {}

local always_true = function() return true end


-- `overwrite` lets a plugin re-register a name it already owns. This is
-- required for enable/disable cycles: the loader dofile()s a plugin's
-- init.lua (so its body re-runs on every load) while sibling modules
-- loaded with require() stay cached. Without this, reloading a plugin that
-- self-registers at require time is fine, but a plugin that (re)registers
-- from init.lua would trip the duplicate assert below.
function command.add(predicate, map, overwrite)
  predicate = predicate or always_true
  if type(predicate) == "string" then
    predicate = require(predicate)
  end
  if type(predicate) == "table" then
    local class = predicate
    predicate = function() return core.active_view:is(class) end
  end
  for name, fn in pairs(map) do
    assert(overwrite or not command.map[name], "command already exists: " .. name)
    command.map[name] = { predicate = predicate, perform = fn }
  end
end


-- Undo a previous command.add(). Accepts a single name or a list of
-- names so a plugin can drop exactly the commands it registered in its
-- own unload() and leave every other plugin's commands untouched.
--
-- This is the counterpart to command.add() and is what makes an
-- extension's unload() able to genuinely detach itself, rather than
-- leaving orphan commands that keep firing (or asserting) after the
-- plugin is disabled.
function command.remove(names)
  if type(names) == "string" then names = { names } end
  for _, name in ipairs(names or {}) do
    command.map[name] = nil
  end
end


-- Names that the given map would register, as a sorted list. A plugin
-- keeps its own registration map around and hands it back here on
-- unload, so the list of names it owns lives in exactly one place.
function command.names_of(map)
  local out = {}
  for name in pairs(map or {}) do out[#out + 1] = name end
  table.sort(out)
  return out
end


local function capitalize_first(str)
  return str:sub(1, 1):upper() .. str:sub(2)
end

function command.prettify_name(name)
  return name:gsub(":", ": "):gsub("-", " "):gsub("%S+", capitalize_first)
end


function command.get_all_valid()
  local res = {}
  for name, cmd in pairs(command.map) do
    if cmd.predicate() then
      table.insert(res, name)
    end
  end
  return res
end


local function perform(name)
  local cmd = command.map[name]
  if cmd and cmd.predicate() then
    cmd.perform()
    return true
  end
  return false
end


function command.perform(...)
  local ok, res = core.try(perform, ...)
  return not ok or res
end


-- Only true runtime command modules live here. Feature commands
-- (find-replace, git, etc.) are registered by their own plugins in
-- via command.add() at plugin load time -- they never appear in
-- data/core/commands/ at all, so there's no plugin list to keep in
-- sync here.
--
-- The set of files under data/core/commands/ is discovered from disk
-- instead of hand-listed, so adding a new core command module (e.g.
-- splitting doc.lua into doc.lua + selection.lua) needs no edit here —
-- dropping the file in that directory is enough.
--
-- Every file is loaded, including commands/command.lua. That one looks like
-- it should be skipped (same name as this module) but it is not a duplicate:
-- it holds the command:* commands the palette itself needs to function, and
-- skipping it left return/tab/escape/up/down bound to nothing.
function command.add_defaults()
  local dir = (EXEDIR or "") .. "/data/core/commands"
  local files = system.list_dir(dir) or {}
  table.sort(files) -- deterministic order; command.add's own
                     -- duplicate-name assert is what actually matters
  for _, filename in ipairs(files) do
    local name = filename:match("^(.+)%.lua$")
    if name then
      require("core.commands." .. name)
    end
  end

  -- Views that register their own commands have to be required here, not
  -- lazily by whoever opens them. Both register at require time, and both
  -- are named by data/core/keymaps/default.lua — so with a lazy require the
  -- keymap pointed at commands that did not exist yet, and the binding was
  -- dead until the view happened to be opened by some other route.
  --
  -- rootview.node pulls in empty_view, which registers the empty-view:
  -- commands; logview is required directly for the log: commands.
  require "core.rootview.node"
  require "core.views.logview"
end


return command