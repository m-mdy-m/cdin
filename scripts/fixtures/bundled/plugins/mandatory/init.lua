-- A stand-in for a bundled mandatory plugin.
--
-- In a real build this role belongs to a modal-editing plugin that the
-- bundler copies into EXEDIR/data/plugins. The point of the fixture is the
-- loader rule, not the plugin: entries in the bundled root load regardless of
-- config.plugins, including config.plugins = false.
local M = {
  name = "mandatory",
  version = "0.0.0-test",
  description = "Fixture standing in for a bundled mandatory plugin",
  category = "core",
  type = "plugin",
}

M.inits = 0

function M.init(core, config)
  M.inits = M.inits + 1
  M.saw_core = core ~= nil
  M.saw_config = config ~= nil
end

return M
