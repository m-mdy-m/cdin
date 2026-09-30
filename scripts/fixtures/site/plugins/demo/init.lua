-- A site plugin: present, well-behaved, and selected by config.plugins.
--
-- Its init() records that it ran, so the test can assert on selection
-- rather than on load order or on log text.
local M = {
  name = "demo",
  version = "0.0.0-test",
  description = "Fixture: a site plugin",
  category = "core",
  type = "plugin",
}

M.inits = 0

function M.init(core, config)
  M.inits = M.inits + 1
  M.saw_core = core ~= nil
  M.saw_config = config ~= nil
end

function M.unload()
  M.unloads = (M.unloads or 0) + 1
end

return M
