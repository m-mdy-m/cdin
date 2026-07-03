-- vim_shell.lua — shell layer for the vim plugins.
--
-- Structure:
--   1. Execution layer : capture(), run(), run_in_buffer()  (used by :! in vim_ex)
--   2. Prompts         : run_prompt(), git_commit_prompt()
--   3. Shell menu      : open_menu()  — bound to "s" in normal mode
--   4. Commands        : vim-shell:*

local core    = require "core"
local command = require "core.command"
local Doc     = require "core.doc"
local menu    = require "plugins.vim_menu_engine"

local IS_WIN = PATHSEP == "\\"

local M = {}

M.IS_WIN   = IS_WIN
M.last_cmd = nil

-- 1. Execution layer ─────────────────────────────────────────────────────────

local function shell_quote(s)
  if IS_WIN then
    return '"' .. s:gsub('"', '""') .. '"'
  else
    return "'" .. s:gsub("'", "'\\''") .. "'"
  end
end
M.shell_quote = shell_quote

-- Run `cmd`, return its combined stdout+stderr (or nil + error message).
function M.capture(cmd)
  local ok, fp = pcall(io.popen, cmd .. " 2>&1", "r")
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

-- Fire-and-forget (no output).
function M.run(cmd)
  system.exec(cmd)
end

-- Run `cmd` and show its output in a scratch buffer.
function M.run_in_buffer(cmd)
  core.log("shell: running %s", cmd)
  M.last_cmd = cmd

  local output, err = M.capture(cmd)
  local doc = Doc()
  local header = ("-- :!%s\n-- %s\n\n"):format(cmd, os.date("%Y-%m-%d %H:%M:%S"))
  local content = header
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

function M.platform()
  if IS_WIN then return "windows" end
  local out = M.capture("uname -s") or ""
  if out:find("Darwin") then return "macos" end
  return "linux"
end

-- 2. Prompts ─────────────────────────────────────────────────────────────────

function M.run_prompt()
  core.command_view:enter("Shell command", function(cmd)
    cmd = cmd:match("^%s*(.-)%s*$")
    if cmd == "" then return end
    M.run_in_buffer(cmd)
  end)
end

function M.repeat_last()
  if not M.last_cmd then
    core.error("shell: no previous command")
    return
  end
  M.run_in_buffer(M.last_cmd)
end

function M.git_commit_prompt()
  core.command_view:enter("Commit message", function(msg)
    msg = msg:match("^%s*(.-)%s*$")
    if msg == "" then return end
    M.run_in_buffer("git commit -m " .. shell_quote(msg))
  end)
end

-- 3. Shell menu (former smenu, merged here) ──────────────────────────────────

local function git(cmd)
  return function() M.run_in_buffer(cmd) end
end

function M.open_menu()
  menu.open {
    name  = "shell",
    title = "Shell Menu  (key or Tab)",
    entries = {
      -- Shell ────────────────────────────────────────────────────────────────
      { key = "!", label = " Run Command",
        info = "output in buffer", action = M.run_prompt },

      { key = ".", label = " Repeat Last",
        info = M.last_cmd or "nothing yet", action = M.repeat_last },

      -- Git ──────────────────────────────────────────────────────────────────
      { key = "s", label = " Git Status",
        info = "git status",            action = git("git status") },

      { key = "l", label = " Git Log",
        info = "--oneline -20",         action = git("git log --oneline -20") },

      { key = "d", label = " Git Diff",
        info = "git diff",              action = git("git diff") },

      { key = "D", label = " Git Diff (staged)",
        info = "git diff --staged",     action = git("git diff --staged") },

      { key = "a", label = " Git Add All",
        info = "git add .",             action = git("git add .") },

      { key = "c", label = " Git Commit",
        info = "prompt for message",    action = M.git_commit_prompt },

      { key = "p", label = " Git Push",
        info = "git push",              action = git("git push") },

      { key = "P", label = " Git Pull",
        info = "git pull",              action = git("git pull") },

      { key = "b", label = " Git Branches",
        info = "git branch -a",         action = git("git branch -a") },
    },
  }
end

-- 4. Commands ────────────────────────────────────────────────────────────────

command.add(nil, {
  ["vim-shell:menu"]        = function() M.open_menu() end,
  ["vim-shell:run-command"] = function() M.run_prompt() end,
  ["vim-shell:repeat-last"] = function() M.repeat_last() end,
  ["vim-shell:git-status"]  = git("git status"),
  ["vim-shell:git-log"]     = git("git log --oneline -20"),
  ["vim-shell:git-diff"]    = git("git diff"),
  ["vim-shell:git-add-all"] = git("git add ."),
  ["vim-shell:git-commit"]  = function() M.git_commit_prompt() end,
})

return M
