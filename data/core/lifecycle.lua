-- Startup (init), shutdown (quit), plugin loader and project-module loader.

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
end

return { install = install }
