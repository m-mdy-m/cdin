local exec     = require "core.git.exec"
local status   = require "core.git.status"
local commands = require "core.git.commands"

local M = {}

M.exe            = exec.exe
M.exe_cwd        = exec.exe_cwd
M.popen          = exec.popen
M.normalize_path = exec.normalize_path
M.IS_WIN         = exec.IS_WIN
M.status = status
M.commands = commands

return M
