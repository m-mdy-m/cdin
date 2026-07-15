require "core.runtime.strict"
local temp = require "core.runtime.temp"

local config = require "core.config"
local style  = require "core.style"

local core = {}
require("core.logging").install(core)
core.temp_filename = temp.filename

core.project_dir = nil

function core.quit(force)
  if force then
    temp.delete_all()
    os.exit()
  end
  local dirty_count, dirty_name = 0, nil
  for _, doc in ipairs(core.docs) do
    if doc:is_dirty() then
      dirty_count = dirty_count + 1
      dirty_name  = doc:get_name()
    end
  end
  if dirty_count > 0 then
    local text = dirty_count == 1
      and string.format('"%s" has unsaved changes. Quit anyway?', dirty_name)
      or  string.format("%d docs have unsaved changes. Quit anyway?", dirty_count)
    if not system.show_confirm_dialog("Unsaved Changes", text) then return end
  end
  core.quit(true)
end

require("core.lifecycle").install(core)

local state = require "core.state"

function core.init()
  local command     = require "core.input.command"
  local keymap      = require "core.input.keymap"
  local RootView    = require "core.rootview"
  local StatusView  = require "core.views.statusview"
  local CommandView = require "core.views.commandview"
  local TitleBar    = require "core.views.titlebar"
  local Doc         = require "core.doc"

  local project_dir = EXEDIR
  local files = {}
  for i = 2, #ARGS do
    local abs  = system.absolute_path(ARGS[i]) or ARGS[i]
    local info = system.get_file_info(abs) or {}
    if     info.type == "file" then table.insert(files, abs)
    elseif info.type == "dir"  then project_dir = abs
    end
  end

  system.chdir(project_dir)
  core.project_dir = system.absolute_path(".") or project_dir

  state.setup_state(core)

  function core.set_active_view(view)
    assert(view, "Tried to set active view to nil")
    if view ~= core.active_view then
      core.last_active_view = core.active_view
      core.active_view      = view
    end
  end

  function core.add_thread(f, weak_ref)
    local key = weak_ref or #core.threads + 1
    local fn  = function() return core.try(f) end
    core.threads[key] = { cr = coroutine.create(fn), wake = 0 }
  end

  state.setup_views(core, RootView, CommandView, StatusView, TitleBar)
  require("core.docs").install(core, Doc)
  require("core.events").install(core, keymap)
  require("core.loop").install(core)

  local project = require "core.project"
  core.add_thread(function() project.thread(core) end)

  command.add_defaults()
  local got_plugin_error  = not core.load_plugins()
  local got_user_error    = not core.try(require, "user")
  local got_project_error = not core.load_project_module()

  for _, filename in ipairs(files) do
    core.root_view:open_doc(core.open_doc(filename))
  end

  if got_plugin_error or got_user_error or got_project_error then
    command.perform("core:open-log")
  end
end


function core.active_docview()
  local DocView     = require "core.views.docview"
  local CommandView = require "core.views.commandview"
  local v = core.active_view
  if v and v:is(DocView) and not v:is(CommandView) then return v end
  return nil
end

return core