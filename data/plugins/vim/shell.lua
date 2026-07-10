local core    = require "core"
local command = require "core.input.command"
local Doc     = require "core.doc"
local config  = require "core.config"
local git     = require "core.git"

local IS_WIN = PATHSEP == "\\"

if config.shell_win         == nil then config.shell_win         = "cmd" end
if config.shell_capture_win == nil then config.shell_capture_win = "cmd" end

local function shell_quote(s)
  if IS_WIN then
    return '"' .. s:gsub('"', '""') .. '"'
  else
    return "'" .. s:gsub("'", "'\\''") .. "'"
  end
end

local function make_capture_cmd(cmd)
  if not IS_WIN then
    return cmd .. " 2>&1"
  end
  if config.shell_capture_win == "powershell" then
    local escaped = cmd:gsub('"', '\\"')
    return 'powershell -NoProfile -NonInteractive -Command "' .. escaped .. ' 2>&1"'
  else
    return 'cmd /c "' .. cmd:gsub('"', '""') .. '" 2>&1'
  end
end

local function launch_interactive_shell()
  if not IS_WIN then
    local term = os.getenv("TERMINAL") or os.getenv("TERM_PROGRAM") or "xterm"
    system.exec(term)
    return
  end
  local shell = config.shell_win
  if shell == "powershell" then
    system.exec("start powershell -NoExit")
  elseif shell == "pwsh" then
    system.exec("start pwsh -NoExit")
  else
    system.exec("start cmd")
  end
end

local M = {}
M.IS_WIN      = IS_WIN
M.shell_quote = shell_quote

function M.capture(cmd)
  local full = make_capture_cmd(cmd)
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
    core.error("shell: %s", err)
  else
    core.log("shell: done")
  end
end

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

-- ── Commands ──────────────────────────────────────────────────────────────────
command.add(nil, {
  ["vim-shell:run-custom"]     = function() M.prompt_and_run() end,
  ["vim-shell:git-status"]     = function() M.run_in_buffer(git.commands.status) end,
  ["vim-shell:git-log"]        = function() M.run_in_buffer(git.commands.log) end,
  ["vim-shell:git-diff"]       = function() M.run_in_buffer(git.commands.diff) end,
  ["vim-shell:make"]           = function() M.run_in_buffer("make") end,
  ["vim-shell:make-test"]      = function() M.run_in_buffer("make test") end,
  -- Open a new interactive terminal window (non-blocking)
  ["vim-shell:open-terminal"]  = function() launch_interactive_shell() end,
  -- Switch the interactive shell preference at runtime
  ["vim-shell:use-cmd"]        = function() config.shell_win = "cmd";        core.log("shell: interactive → cmd.exe") end,
  ["vim-shell:use-powershell"] = function() config.shell_win = "powershell"; core.log("shell: interactive → PowerShell 5") end,
  ["vim-shell:use-pwsh"]       = function() config.shell_win = "pwsh";       core.log("shell: interactive → PowerShell 7+") end,
})

return M
