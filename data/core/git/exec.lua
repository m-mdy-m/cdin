local IS_WIN = PATHSEP == "\\"

local M = {}

local _git_exe = nil

local function find_git_win()
  if _git_exe ~= nil then return _git_exe end

  local function popen_raw(c)
    if system.popen then return system.popen(c:gsub("%s*2>[^%s\"]*", "")) end
    local ok, fp = pcall(io.popen, c)
    if not ok or not fp then return nil end
    local o = fp:read("*a"); fp:close(); return o
  end
  local wo = popen_raw('cmd.exe /C "where.exe git 2>NUL"')
  if wo and wo ~= "" then
    local preferred = wo:match("([^\r\n]+\\cmd\\git%.exe)")
    local first     = wo:match("([^\r\n]+)")
    local found = preferred or first
    if found then
      found = found:gsub("^%s+", ""):gsub("%s+$", "")
      if found ~= "" then _git_exe = '"' .. found .. '"'; return _git_exe end
    end
  end

  local candidates = {
    "C:\\Program Files\\Git\\cmd\\git.exe",
    "C:\\Program Files (x86)\\Git\\cmd\\git.exe",
    os.getenv("LOCALAPPDATA") and
      (os.getenv("LOCALAPPDATA") .. "\\Programs\\Git\\cmd\\git.exe"),
    os.getenv("ProgramFiles") and
      (os.getenv("ProgramFiles")  .. "\\Git\\cmd\\git.exe"),
    os.getenv("USERPROFILE") and
      (os.getenv("USERPROFILE")   .. "\\scoop\\apps\\git\\current\\cmd\\git.exe"),
  }
  for _, p in ipairs(candidates) do
    if p then
      local f = io.open(p, "rb")
      if f then f:close(); _git_exe = '"' .. p .. '"'; return _git_exe end
    end
  end

  _git_exe = false
  return false
end

function M.exe()
  if not IS_WIN then return "git" end
  return find_git_win()
end

function M.exe_with_dir(dir)
  local gc = M.exe()
  if not gc then return false end
  if not dir or dir == "" then return gc end
  if IS_WIN then dir = dir:gsub("/", "\\") end
  return gc .. ' -C "' .. dir .. '"'
end

function M.exe_cwd()
  local core = rawget(_G, "core")
  local dir  = (core and core.project_dir) or system.absolute_path(".") or "."
  return M.exe_with_dir(dir)
end

function M.popen(cmd)
  if system.popen then
    return system.popen(cmd:gsub("%s*2>[^%s\"]*", ""))
  end
  local full_cmd
  if IS_WIN then
    full_cmd = 'cmd.exe /C "' .. cmd .. '"'
  else
    full_cmd = cmd .. " 2>/dev/null"
  end
  local ok, fp = pcall(io.popen, full_cmd)
  if not ok or not fp then return nil end
  local out = fp:read("*a")
  fp:close()
  return out
end

function M.normalize_path(p)
  if IS_WIN then
    p = p:gsub("^/(%a)/", function(d) return d:upper() .. ":\\" end)
    p = p:gsub("/", "\\")
  end
  return p
end

M.IS_WIN = IS_WIN

return M