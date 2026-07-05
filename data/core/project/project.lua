local common = require "core.utils.common"
local config = require "core.config"

local IS_WIN = PATHSEP == "\\"

local M = {}

local _git_ignored    = {}
local _git_ignore_tick = 0  

local function normalize_path(p)
  if IS_WIN then
    p = p:gsub("^/(%a)/", function(d) return d:upper() .. ":\\" end)
    p = p:gsub("/", "\\")
  end
  return p
end

local function refresh_git_ignored()
  local null = IS_WIN and "NUL" or "/dev/null"

  local root_out
  local ok, fp = pcall(io.popen, "git rev-parse --show-toplevel 2>" .. null)
  if ok and fp then
    root_out = fp:read("*a"); fp:close()
  end
  if not root_out or root_out == "" then
    _git_ignored = {}
    return
  end

  local root = root_out:gsub("[\r\n]+$", "")
  root = normalize_path(root)

  local ok2, fp2 = pcall(io.popen,
    "git ls-files --ignored --exclude-standard --directory 2>" .. null)
  local t = {}
  if ok2 and fp2 then
    local out = fp2:read("*a"); fp2:close()
    for line in out:gmatch("[^\r\n]+") do
      local is_dir = line:sub(-1) == "/"
      local rel    = is_dir and line:sub(1, -2) or line
      local abs    = root .. PATHSEP .. normalize_path(rel)
      t[abs] = is_dir and "dir" or "file"
    end
  end
  _git_ignored = t
end

local function is_git_ignored(abs_path)
  if _git_ignored[abs_path] then return true end
  local p = abs_path
  while true do
    local parent = p:match("^(.+)[\\/][^\\/]+$")
    if not parent or parent == p then break end
    if _git_ignored[parent] == "dir" then return true end
    p = parent
  end
  return false
end

local function diff_files(a, b)
  if #a ~= #b then return true end
  for i, v in ipairs(a) do
    if b[i].filename ~= v.filename
    or b[i].modified ~= v.modified then
      return true
    end
  end
  return false
end

local function compare_file(a, b)
  return a.filename < b.filename
end

local function get_files(path, t)
  coroutine.yield()
  t = t or {}
  local size_limit = config.file_size_limit * 10e5
  local all        = system.list_dir(path) or {}
  local dirs, files = {}, {}

  for _, file in ipairs(all) do
    if not common.match_pattern(file, config.ignore_files) then
      local full = (path ~= "." and path .. PATHSEP or "") .. file
      local abs  = system.absolute_path(full) or full
      if not is_git_ignored(abs) then
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

  for _, f in ipairs(dirs)  do table.insert(t, f); get_files(f.filename, t) end
  for _, f in ipairs(files) do table.insert(t, f) end
  return t
end

function M.thread(core)
  local cycle = 0
  while true do
    -- Refresh git ignore list every ~5 scan cycles (cheap, avoids subprocess spam)
    cycle = cycle + 1
    if cycle % 5 == 1 then
      coroutine.yield()
      pcall(refresh_git_ignored)
    end

    local t = get_files(".")
    if diff_files(core.project_files, t) then
      core.project_files = t
      core.redraw = true
    end
    coroutine.yield(config.project_scan_rate)
  end
end

return M
