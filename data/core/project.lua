local common = require "core.utils.common"
local config  = require "core.config"
local git     = require "core.git"

local function flush_treeview_cache()
  local ok, Cache = pcall(require, "plugins.treeview.cache")
  if ok and Cache and Cache.flush then Cache.flush() end
end

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

local function refresh_git_ignored()
  pcall(git.status.refresh_ignored_now)
end

local function is_git_ignored(a)
  return git.status.is_ignored(a)
end

local function compare_file(a, b)
  return a.filename < b.filename
end

local function scan_shallow(path)
  coroutine.yield()
  local size_limit = config.file_size_limit * 10e5
  local all   = system.list_dir(path) or {}
  local dirs  = {}
  local files = {}

  for _, file in ipairs(all) do
    if not common.match_pattern(file, config.ignore_files) then
      local full = (path ~= "." and path .. PATHSEP or "") .. file
      local a    = abs_path(full)
      local info = system.get_file_info(full)
      if info and info.size < size_limit then
        info.filename = full
        if is_git_ignored(a) then
          info.git_ignored = true
        end
        table.insert(info.type == "dir" and dirs or files, info)
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

    core.project_dir = _root
  end

  do_initial_scan()

  while true do
    cycle = cycle + 1
    coroutine.yield()

    local cur_root = get_root()
    if cur_root ~= _root then
      _scanned = {}
      flush_treeview_cache()
      do_initial_scan()
      coroutine.yield()
    end

    if cycle % 5 == 1 then
      pcall(refresh_git_ignored)
      if core.project_files then
        local changed = false
        for _, item in ipairs(core.project_files) do
          local a       = abs_path(item.filename)
          local ignored = is_git_ignored(a)
          if (item.git_ignored or false) ~= ignored then
            item.git_ignored = ignored
            changed = true
          end
        end
        if changed then
          bump_revision(core)
          core.redraw = true
        end
      end
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