local config = require "core.config"
local style  = require "core.style"

local function install(core)
  -- Two log streams, and it is worth being able to say which is which:
  --
  --   core.log_items  this table. What core.log / core.error wrote, newest
  --                   last, bounded by config.max_log_items. Shown by the log
  --                   view, and it is the only place a plugin's traceback
  --                   appears.
  --   core.log_path   the C logger's file, next to the binary. C-level
  --                   diagnostics and bootstrap failures. No Lua output
  --                   reaches it. Nil when file logging is off.
  core.log_path = (type(LOGFILE) == "string" and LOGFILE ~= "") and LOGFILE or nil

  -- The Lua stream is mirrored into that same file, so one text file holds
  -- everything: the C logger's lines (tagged by level) and the Lua ones (tagged
  -- LUA), in the order they happened, tracebacks included. That is also the
  -- only way out when a Lua error happens during startup, before there is an
  -- editor to open the log view in.
  --
  -- On by default. CDIN_LUA_LOG=0 (or off / false / no) turns it off.
  local mirror = true
  do
    local v = os.getenv("CDIN_LUA_LOG")
    if v then
      v = v:lower()
      if v == "0" or v == "off" or v == "false" or v == "no" then mirror = false end
    end
  end

  -- One handle for the whole run instead of an open/close per message. Append
  -- mode and line buffering, so a line from here and a line from the C logger
  -- (also append, flushed per line) interleave whole and nothing is lost if
  -- the editor dies mid-frame.
  local mirror_fp = nil
  local function mirror_write(text)
    if not (mirror and core.log_path) then return end
    if not mirror_fp then
      mirror_fp = io.open(core.log_path, "a")
      if not mirror_fp then mirror = false; return end
      mirror_fp:setvbuf("line")
    end
    mirror_fp:write(text)
  end

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
    mirror_write(string.format("%s LUA   %-22s  %s\n",
      os.date("%Y-%m-%d %H:%M:%S"), at, text))
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
        -- The line was written before the traceback existed; add it now, or
        -- the file would say "something failed" and never say where.
        mirror_write(item.info .. "\n")
      end
      err = msg
    end, ...)
    return ok and true or false, ok and res or err
  end
end

return { install = install }
