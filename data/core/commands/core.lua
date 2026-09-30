-- The editor's own commands.
--
-- What is here is what the runtime is: document and view mechanics, window
-- management, the log, quitting. What is not here is any user-facing
-- workflow that merely uses them — the command palette, the file finders,
-- the module pickers. Those are optional plugins, so an editor with no
-- extensions installed has exactly this set and no more.
--
-- The line is drawn at "could this work without any input from the user?".
-- core:open-file cannot: it prompts for a path. core:new-doc can.
local core = require "core"
local command = require "core.input.command"
local LogView = require "core.views.logview"


local fullscreen = false

command.add(nil, {
  ["core:quit"] = function()
    core.quit()
  end,

  ["core:force-quit"] = function()
    core.quit(true)
  end,

  ["core:toggle-fullscreen"] = function()
    fullscreen = not fullscreen
    system.set_window_mode(fullscreen and "fullscreen" or "normal")
  end,

  -- ctrl+n. Stays in the runtime: a new empty document needs no extension,
  -- and the vim integrations and every plugin that opens a document assume
  -- it is there.
  ["core:new-doc"] = function()
    core.root_view:open_doc(core.open_doc())
  end,

  ["core:open-log"] = function()
    local node = core.root_view:get_active_node()
    node:add_view(LogView())
  end,
})
