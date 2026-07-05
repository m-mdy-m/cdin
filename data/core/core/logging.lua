-- Internal log() helper + core.log / core.log_quiet / core.error / core.try.
-- Installed early (before views exist); log() guards against nil status_view.

local config = require "core.config"
local style  = require "core.style"

local function install(core)
  local function log(icon, icon_color, fmt, ...)
    local text = string.format(fmt, ...)
    if icon and core.status_view then
      core.status_view:show_message(icon, icon_color, text)
    end
    local info = debug.getinfo(2, "Sl")
    local at   = string.format("%s:%d", info.short_src, info.currentline)
    local item = { text = text, time = os.time(), at = at }
    -- log_items may not exist yet during very early boot
    if core.log_items then
      table.insert(core.log_items, item)
      if #core.log_items > config.max_log_items then
        table.remove(core.log_items, 1)
      end
    end
    return item
  end

  function core.log(...)       return log("i", style.text,   ...) end
  function core.log_quiet(...) return log(nil, nil,           ...) end
  function core.error(...)     return log("!", style.accent,  ...) end

  function core.try(fn, ...)
    local err
    local ok, res = xpcall(fn, function(msg)
      local item = core.error("%s", msg)
      if item then
        item.info = debug.traceback(nil, 2):gsub("\t", "")
      end
      err = msg
    end, ...)
    return ok and true or false, ok and res or err
  end
end

return { install = install }
