local common = require "core.utils.common"
local config  = require "core.config"

local IS_WIN = PATHSEP == "\\"

local M = {}

local _scanned = {}
local _prio_q  = {}
local _bg_q    = {}
local _root    = nil

local function abs_path(p)
  return system.absolute_path(p) or p
end

local function get_root()
  return abs_path(".")
end

local _git_ignored = {}

local function normalize_path(p)
  if IS_WIN then
    p = p:gsub("^/(%a)/", function(d) return d:upper() .. ":\\" end)
    p = p:gsub("/", "\\")
  end
  return p
end

local _git_exe = nil
local function find_git_win()
  if _git_exe ~= nil then return _git_exe end
  local function popen_raw(c)
    local ok, fp = pcall(io.popen, c); if not ok or not fp then return nil end
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
    os.getenv("LOCALAPPDATA") and (os.getenv("LOCALAPPDATA") .. "\\Programs\\Git\\cmd\\git.exe"),
    os.getenv("ProgramFiles")  and (os.getenv("ProgramFiles")  .. "\\Git\\cmd\\git.exe"),
    os.getenv("USERPROFILE")   and (os.getenv("USERPROFILE")   .. "\\scoop\\apps\\git\\current\\cmd\\git.exe"),
  }
  for _, p in ipairs(candidates) do
    if p then local f = io.open(p, "rb"); if f then f:close(); _git_exe = '"'..p..'"'; return _git_exe end end
  end
  _git_exe = false; return false
end

local function git_exe()
  if not IS_WIN then return "git" end
  return find_git_win()
end

local function silent_popen(cmd)
  if system.popen then
    local clean = cmd:gsub("%s*2>[^%s\"]*", "")
    return system.popen(clean)
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

local function refresh_git_ignored()
  local gc = git_exe()
  if not gc then _git_ignored = {}; return end
  local null = IS_WIN and "NUL" or "/dev/null"
  local root_out = silent_popen(gc .. " rev-parse --show-toplevel 2>" .. null)
  if not root_out or root_out == "" then _git_ignored = {}; return end
  local root = root_out:gsub("[\r\n]+$", "")
  root = normalize_path(root)
  local out = silent_popen(gc .. " ls-files --ignored --exclude-standard --directory 2>" .. null)
  local t = {}
  if out then
    for line in out:gmatch("[^\r\n]+") do
      local is_dir = line:sub(-1) == "/"
      local rel    = is_dir and line:sub(1, -2) or line
      local a      = root .. PATHSEP .. normalize_path(rel)
      t[a] = is_dir and "dir" or "file"
    end
  end
  _git_ignored = t
end

local function is_git_ignored(a)
  if _git_ignored[a] then return true end
  local p = a
  while true do
    local parent = p:match("^(.+)[\\/][^\\/]+$")
    if not parent or parent == p then break end
    if _git_ignored[parent] == "dir" then return true end
    p = parent
  end
  return false
end

local function compare_file(a, b)
  return a.filename < b.filename
end

local function scan_shallow(path)
  coroutine.yield()
  local size_limit = config.file_size_limit * 10e5
  local all  = system.list_dir(path) or {}
  local dirs  = {}
  local files = {}

  for _, file in ipairs(all) do
    if not common.match_pattern(file, config.ignore_files) then
      local full = (path ~= "." and path .. PATHSEP or "") .. file
      local a    = abs_path(full)
      if not is_git_ignored(a) then
        local info = system.get_file_info(full)
        if info and info.size < size_limit then
          info.filename = full
          table.insert(info.type == "dir" and dirs or files, info)
        end
      end
    end
  end

  table.sort(dirs,  compare_file)
  table.sort(files, compare_file)

  local items = {}
  for _, f in ipairs(dirs)  do table.insert(items, f) end
  for _, f in ipairs(files) do table.insert(items, f) end

  local subdir_paths = {}
  for _, f in ipairs(dirs) do table.insert(subdir_paths, f.filename) end

  return items, subdir_paths
end

local function find_insert_pos(project_files, parent_path)
  for i, f in ipairs(project_files) do
    if f.filename == parent_path then
      return i
    end
  end
  return #project_files
end

local function insert_children(project_files, pos, items)
  for i, item in ipairs(items) do
    table.insert(project_files, pos + i, item)
  end
end

local function bump_revision(core)
  core.project_files_revision = (core.project_files_revision or 0) + 1
end


function M.request_rescan(core)
  _scanned = {}
  _prio_q  = {}
  _bg_q    = {}
  _root    = nil 
end

function M.prioritize(path)
  local a = abs_path(path)
  if _scanned[a] then return end 
  for _, p in ipairs(_prio_q) do
    if p == path then return end
  end
  table.insert(_prio_q, 1, path)
end

function M.thread(core)
  local cycle = 0

  local function do_initial_scan()
    pcall(refresh_git_ignored)
    local items, subdirs = scan_shallow(".")
    core.project_files = items
    bump_revision(core)
    core.redraw = true
    _scanned[abs_path(".")] = true
    _prio_q = {}
    _bg_q   = {}
    for _, s in ipairs(subdirs) do
      table.insert(_bg_q, s)
    end
    _root = get_root()
  end

  do_initial_scan()

  while true do
    cycle = cycle + 1
    coroutine.yield()

    local cur_root = get_root()
    if cur_root ~= _root then
      _scanned = {}
      do_initial_scan()
      coroutine.yield()
    end

    if cycle % 5 == 1 then
      pcall(refresh_git_ignored)
    end

    if #_prio_q > 0 then
      local path  = table.remove(_prio_q, 1)
      local apath = abs_path(path)
      if not _scanned[apath] then
        local items, subdirs = scan_shallow(path)
        local pos = find_insert_pos(core.project_files, path)
        insert_children(core.project_files, pos, items)
        _scanned[apath] = true
        bump_revision(core)
        core.redraw = true
        for i = #subdirs, 1, -1 do
          local s = subdirs[i]
          if not _scanned[abs_path(s)] then
            table.insert(_prio_q, 1, s)
          end
        end
      end
      coroutine.yield()

    elseif #_bg_q > 0 then
      local path  = table.remove(_bg_q, 1)
      local apath = abs_path(path)
      if not _scanned[apath] then
        local items, subdirs = scan_shallow(path)
        local pos = find_insert_pos(core.project_files, path)
        insert_children(core.project_files, pos, items)
        _scanned[apath] = true
        bump_revision(core)
        core.redraw = true
        for _, s in ipairs(subdirs) do
          table.insert(_bg_q, s)
        end
      end
      coroutine.yield(0.05)

    else
      coroutine.yield(config.project_scan_rate or 5)
    end
  end
end

return M