local core    = require "core"
local command = require "core.command"
local Doc     = require "core.doc"

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
  local out     = fp:read("*a")
  local success = fp:close()
  if success == false then
    return out or "", ("shell: command exited with error: %s"):format(cmd)
  end
  return out or "", nil
end

function M.run(cmd)
  system.exec(cmd)
end

-- Run cmd and open its output in a new scratch buffer.
function M.run_in_buffer(cmd)
  core.log("shell: running %s", cmd)

  local output, err = M.capture(cmd)
  local doc         = Doc()
  local header      = ("-- :!%s\n-- %s\n\n"):format(cmd, os.date("%Y-%m-%d %H:%M:%S"))
  local content     = header
                    .. (output or "")
                    .. (err and ("\n\n-- [error] " .. err) or "")

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

-- Ask user for a shell command and run it in a buffer.
function M.prompt_and_run()
  core.command_view:enter(":! shell command", function(cmd)
    if cmd == "" then core.error("shell: empty command"); return end
    M.run_in_buffer(cmd)
  end, function() return {} end)
  core.command_view:set_text("")
end

function M.platform()
  if IS_WIN then return "windows" end
  local out = M.capture("uname -s") or ""
  if out:find("Darwin") then return "macos" end
  return "linux"
end

M.IS_WIN      = IS_WIN
M.shell_quote = shell_quote

-- ── commands ─────────────────────────────────────────────────────────────────

command.add(nil, {
  ["vim-shell:run-custom"]  = function() M.prompt_and_run() end,
  ["vim-shell:git-status"]  = function() M.run_in_buffer("git status") end,
  ["vim-shell:git-log"]     = function() M.run_in_buffer("git log --oneline -20") end,
  ["vim-shell:git-diff"]    = function() M.run_in_buffer("git diff") end,
  ["vim-shell:make"]        = function() M.run_in_buffer("make") end,
  ["vim-shell:make-test"]   = function() M.run_in_buffer("make test") end,
})

return M
