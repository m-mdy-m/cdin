-- Startup (init), shutdown (quit), plugin loader, project-module loader and the fatal-error handler (on_error).

local function install(core)
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
