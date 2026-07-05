local core   = require "core"
local config = require "core.config"
local style  = require "core.style"

local M = {}

M.ICON = {
  ["A"] = "+",
  ["M"] = "*",
  ["D"] = "-",
  ["R"] = "→",
  ["?"] = "?",
  ["U"] = "!",
}

local STATUS_RANK = { ["U"]=5, ["M"]=4, ["A"]=3, ["D"]=2, ["R"]=2, ["?"]=1 }

M.status = {}
M.root   = nil

local IS_WIN = PATHSEP == "\\"

local _git_cmd = nil

local function find_git_win()
  if _git_cmd then return _git_cmd end

  local probe = io.popen("git --version 2>NUL")
  if probe then
    local out = probe:read("*a")
    probe:close()
    if out and out:find("git version") then
      _git_cmd = "git"
      return _git_cmd
    end
  end

  local candidates = {
    "C:\\Program Files\\Git\\cmd\\git.exe",
    "C:\\Program Files (x86)\\Git\\cmd\\git.exe",
    os.getenv("LOCALAPPDATA") and
      (os.getenv("LOCALAPPDATA") .. "\\Programs\\Git\\cmd\\git.exe"),
    os.getenv("ProgramFiles") and
      (os.getenv("ProgramFiles") .. "\\Git\\cmd\\git.exe"),
  }
  for _, path in ipairs(candidates) do
    if path then
      local f = io.open(path, "rb")
      if f then f:close(); _git_cmd = '"' .. path .. '"'; return _git_cmd end
    end
  end

  _git_cmd = false
  return false
end

local function git_cmd()
  if not IS_WIN then return "git" end
  return find_git_win()
end

local function run_capture(cmd)
  if system.popen then return system.popen(cmd) end
  local ok, fp = pcall(io.popen, cmd)
  if not ok or not fp then return nil end
  local out = fp:read("*a")
  fp:close()
  return out
end

local function normalize_path(p)
  if IS_WIN then
    p = p:gsub("^/(%a)/", function(d) return d:upper() .. ":\\" end)
    p = p:gsub("/", "\\")
  end
  return p
end

local function parse_porcelain_line(line)
  if #line < 4 then return nil end
  local x, y   = line:sub(1,1), line:sub(2,2)
  local rest    = line:sub(4)

  if rest:sub(1,1) == '"' then rest = rest:match('^"(.-)"') or rest end
  local path = rest:match("%-> (.+)$") or rest
  local status
  if     x == "?" and y == "?" then status = "?"   -- untracked
  elseif x == "!" and y == "!" then return nil      -- ignored — SKIP
  elseif x == "U" or  y == "U" then status = "U"   -- merge conflict
  elseif x == "R"               then status = "R"
  elseif y == "R"               then status = "R"
  elseif x == "D" or  y == "D" then status = "D"
  elseif x == "A"               then status = "A"
  else                               status = "M"
  end
  return path, status
end

local _ignored   = {}
local _ignored_root = nil

local function refresh_ignored(root, gc)
  local null = IS_WIN and "NUL" or "/dev/null"
  local out  = run_capture(gc .. " ls-files --ignored --exclude-standard --directory 2>" .. null)
  local t    = {}
  if out then
    for line in out:gmatch("[^\r\n]+") do
      local l = line:gsub("/$", "")
      local abs = root .. PATHSEP .. normalize_path(l)
      t[abs] = true
    end
  end
  _ignored      = t
  _ignored_root = root
end

local function is_ignored(abs_path)
  if not _ignored_root then return false end
  local p = abs_path
  while p and p ~= _ignored_root do
    if _ignored[p] then return true end
    local parent = p:match("^(.+)[\\/][^\\/]+$")
    if not parent or parent == p then break end
    p = parent
  end
  return false
end

function M.refresh()
  if not config.treeview_git_enabled then
    M.status, M.root = {}, nil
    return
  end

  local gc = git_cmd()
  if not gc then
    M.status, M.root = {}, nil
    return
  end

  local null     = IS_WIN and "NUL" or "/dev/null"
  local toplevel = run_capture(gc .. " rev-parse --show-toplevel 2>" .. null)
  if not toplevel or toplevel == "" then
    M.status, M.root = {}, nil
    return
  end

  local root_raw = toplevel:gsub("[\r\n]+$", "")
  M.root         = normalize_path(root_raw)

  refresh_ignored(M.root, gc)
  local out = run_capture(gc .. " status --porcelain 2>" .. null)
  local t   = {}
  if out then
    for line in out:gmatch("[^\r\n]+") do
      local path, status = parse_porcelain_line(line)
      if path and status then
        local abs = M.root .. PATHSEP .. normalize_path(path)
        t[abs] = status
      end
    end
  end
  M.status = t
  core.redraw = true
end

function M.thread()
  while true do
    core.try(M.refresh)
    coroutine.yield(config.treeview_git_update_rate)
  end
end

function M.get_status(item)
  if not item or not item.abs_filename then return nil end
  if not M.root then return nil end
  if is_ignored(item.abs_filename) then return nil end

  if item.type == "file" then
    return M.status[item.abs_filename]
  end

  local best, best_rank = nil, 0
  local dir_prefix = item.abs_filename .. PATHSEP
  for abs, status in pairs(M.status) do
    if abs:sub(1, #dir_prefix) == dir_prefix then
      if not is_ignored(abs) then
        local rank = STATUS_RANK[status] or 0
        if rank > best_rank then best, best_rank = status, rank end
      end
    end
  end
  return best
end

function M.get_color(status)
  if status == "D" or status == "U" then
    return style.titlebar_close_hover
  elseif status == "?" then
    return style.dim
  else
    return style.accent
  end
end

return M
