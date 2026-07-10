-- Startup (init), shutdown (quit), plugin loader, project-module loader and the fatal-error handler (on_error).

local function install(core)
  function core.load_plugins()
    local no_errors = true
    local function load_dir(dir, prefix)
      for _, filename in ipairs(system.list_dir(dir) or {}) do
        local full = dir .. "/" .. filename
        local info = system.get_file_info(full)
        if info and info.type == "dir" then
          load_dir(full, prefix .. filename .. ".")
        elseif filename:match("%.lua$") then
          local modname = prefix .. filename:gsub("%.lua$", "")
          local ok = core.try(require, modname)
          if ok then
            core.log_quiet("Loaded plugin %q", modname)
          else
            no_errors = false
          end
        end
      end
    end
    load_dir(EXEDIR .. "/data/plugins", "plugins.")
    return no_errors
  end

  function core.load_project_module()
    local filename = ".lite_project.lua"
    if system.get_file_info(filename) then
      return core.try(function()
        local fn, err = loadfile(filename)
        if not fn then error("Error when loading project module:\n\t" .. err) end
        fn()
        core.log_quiet("Loaded project module")
      end)
    end
    return true
  end

  function core.on_error(err)
    local fp = io.open(EXEDIR .. "/error.txt", "wb")
    fp:write("Error: " .. tostring(err) .. "\n")
    fp:write(debug.traceback(nil, 4))
    fp:close()
    for _, doc in ipairs(core.docs) do
      if doc:is_dirty() and doc.filename then
        doc:save(doc.filename .. "~")
      end
    end
  end
end

return { install = install }
