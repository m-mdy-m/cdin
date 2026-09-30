-- A bundled plugin whose init() raises.
--
-- Bundled entries are mandatory, so a failure here is the interesting one:
-- it must be reported at error level, it must not stop the other bundled
-- plugins from loading, and it must not take startup down. The loader
-- records the failure by NOT putting this module in plugins.loaded.
local M = {
  name = "broken",
  version = "0.0.0-test",
  description = "Fixture: bundled plugin that raises during init",
  category = "core",
  type = "plugin",
}

function M.init()
  error("broken: init raised on purpose")
end

return M
