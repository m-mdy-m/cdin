-- The empty view's quick-reference help list, and the hook plugins add to it.
--
-- This lives here rather than in empty_view.lua because plugins call
-- core.register_help_shortcuts() from their own init(), and a plugin must
-- not depend on which views happened to be constructed before it loaded.
-- empty_view.lua required the empty view; anything else that did would work
-- until a plugin loaded early and found the function missing.
--
-- The shape of an entry is { key = "ctrl+p", desc = "Find file", section =
-- true }. `section` starts a new group visually; it is not a header in any
-- other sense.

local help = {}

-- { { id = n, list = { {key=…, desc=…}, … } }, … }
--
-- The id is what core.unregister_help_shortcuts matches on, and keeping the
-- handle opaque means a plugin cannot accidentally remove another plugin's
-- entries by registering the same list twice.
local groups = {}
local next_id = 0

-- Puts core.register_help_shortcuts and core.unregister_help_shortcuts on the
-- host's core table.
--
-- Called explicitly by core/init.lua rather than this module requiring
-- "core": init.lua *is* the module "core", so a require from here while it is
-- still loading is a cycle, not a dependency.
function help.install(core)
  -- Registers a group of entries and returns a handle for unregistering.
  --
  -- A plugin that does not keep the handle cannot clean up after itself,
  -- which is how a reload ends up with two copies of every shortcut it
  -- advertises. Unloading is part of loading: keep it, hand it back in
  -- unload().
  function core.register_help_shortcuts(list)
    next_id = next_id + 1
    local handle = { id = next_id, list = list }
    groups[#groups + 1] = handle
    return handle
  end

  -- Removes a group. Returns false for a handle that was never registered,
  -- rather than raising: unload() also runs on the error path, and a second
  -- call should be harmless.
  function core.unregister_help_shortcuts(handle)
    if type(handle) ~= "table" then return false end
    for i, group in ipairs(groups) do
      if group == handle or group.id == handle.id then
        table.remove(groups, i)
        return true
      end
    end
    return false
  end

  -- The same table, exposed for anything reading the older field directly.
  core._help_shortcut_groups = groups
  return core
end

-- Every registered entry, in registration order. A caller passes its own
-- core-owned list to come first; the groups are appended after it, which is
-- why a plugin's entries always appear below the editor's own.
function help.entries(core_entries)
  local out = {}
  for _, item in ipairs(core_entries or {}) do out[#out + 1] = item end
  for _, group in ipairs(groups) do
    for _, item in ipairs(group.list or {}) do out[#out + 1] = item end
  end
  return out
end

-- How many groups are registered. For tests, and for a plugin that wants to
-- know whether anything else already contributes to this screen.
function help.count()
  return #groups
end

return help
