-- Commands for inspecting and changing the loaded plugin set at runtime.
--
-- These are the on-demand half of the loader, equivalent to Vim's :packadd
-- for a package you chose not to autoload. They are deliberately the *only*
-- way to load a plugin after startup: there is no manager, no registry and
-- no persistence, so nothing here survives a restart except what
-- config.plugins asks for.
local core    = require "core"
local command = require "core.input.command"
local plugins = require "core.plugins"

local t = {}

-- core:load-plugin <name> — load a plugin that config.plugins did not.
-- Accepts a comma-separated list so several can be brought in at once.
t["core:load-plugin"] = function(...)
  local arg = table.concat({ ... }, " ")
  if arg == "" then
    core.error("core:load-plugin: expected a plugin name (see core:list-plugins)")
    return
  end

  local failed = 0
  for name in arg:gmatch("[^,%s]+") do
    local ok, err = plugins.load(name)
    if ok then
      core.log("loaded plugin: %s", name)
    else
      core.error("core:load-plugin %s: %s", name, tostring(err))
      failed = failed + 1
    end
  end
  if failed == 0 then
    core.log("plugins: %d loaded", (function()
      local n = 0 for _ in pairs(plugins.loaded) do n = n + 1 end return n
    end)())
  end
end

-- core:unload-plugin <name> — run a plugin's unload() and forget it.
t["core:unload-plugin"] = function(...)
  local arg = table.concat({ ... }, " ")
  if arg == "" then
    core.error("core:unload-plugin: expected a plugin name")
    return
  end
  for name in arg:gmatch("[^,%s]+") do
    local ok, err = plugins.unload(name)
    if ok then
      core.log("unloaded plugin: %s", name)
    else
      core.error("core:unload-plugin %s: %s", name, tostring(err))
    end
  end
end

-- core:list-plugins — what is on disk, and what of it is loaded.
t["core:list-plugins"] = function()
  local on_disk = plugins.list()
  local function loaded_count()
    local n = 0
    for _ in pairs(plugins.loaded) do n = n + 1 end
    return n
  end

  local lines = {}
  for _, entry in ipairs(on_disk) do
    lines[#lines + 1] = string.format("  %-16s %s", entry.name,
      plugins.loaded[entry.name] and "loaded" or "-")
  end
  if #lines == 0 then lines[1] = "  (none)" end

  core.log("plugins: %d loaded, %d available\n%s",
    loaded_count(), #on_disk, table.concat(lines, "\n"))
end

-- Registered on the palette with no predicate so they are always reachable,
-- including in a bare editor where no plugin has registered anything.
command.add(nil, t)

return t
