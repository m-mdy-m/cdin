-- Shell execution layer for vimode's :! command.

local core   = require "core"
local Doc    = require "core.doc"

local IS_WIN = PATHSEP == "\\"

local M = {}

local function shell_quote(s)
  if IS_WIN then
    return '"' .. s:gsub('"', '""') .. '"'
  else
    return "'" .. s:gsub("'", "'\\''") .. "'"
  end
end
local function with_stderr(cmd)
  if IS_WIN then
    return cmd .. " 2>&1"
  else
    return cmd .. " 2>&1"
  end
end
function M.capture(cmd)
  local full = with_stderr(cmd)
  local ok, fp = pcall(io.popen, full, "r")
  if not ok or not fp then
    return nil, ("shell: could not launch: %s"):format(cmd)
  end
  local out = fp:read("*a")
  local success = fp:close()
  if success == false then
    return out or "", ("shell: command exited with error: %s"):format(cmd)
  end
  return out or "", nil
end

function M.run(cmd)
  system.exec(cmd)
end

function M.run_in_buffer(cmd)
  core.log("shell: running %s", cmd)

  local output, err = M.capture(cmd)
  local doc = Doc()
  local header = ("-- :!%s\n-- %s\n\n"):format(
    cmd, os.date("%Y-%m-%d %H:%M:%S"))
  local content = header .. (output or "") .. (err and ("\n\n-- [error] " .. err) or "")
  doc:text_input(content)
  doc:set_selection(1, 1)
  doc.name = ":!" .. cmd
  function doc:get_name() return self.name end
  core.root_view:open_doc(doc)

  if err then
    core.warn("shell: %s", err)
  else
    core.log("shell: done")
  end
end

function M.platform()
  if IS_WIN then return "windows" end
 
  local out = M.capture("uname -s") or ""
  if out:find("Darwin") then return "macos" end
  return "linux"
end

M.IS_WIN = IS_WIN
M.shell_quote = shell_quote

return M