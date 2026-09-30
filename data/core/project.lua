local common = require "core.utils.common"
local config  = require "core.config"

local M = {}
local _core = nil

local function install_vcs_hook(core)
  core.register_vcs_provider = core.register_vcs_provider or function(provider)
    core.vcs_provider = provider
  end
end

local function get_vcs()
  return _core and _core.vcs_provider
end

M._after_root_change = {}

local function flush_treeview_cache()
  for _, fn in ipairs(M._after_root_change) do
    pcall(fn)
  end
end

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
  local vcs = get_vcs()
  if vcs and vcs.refresh_ignored_now then
    pcall(vcs.refresh_ignored_now)
  end
end

local function is_git_ignored(a)
  local vcs = get_vcs()
  if not vcs or not vcs.is_ignored then return false end
  return vcs.is_ignored(a)
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

-- Switching project directory.
--
-- cdin is single-project: "which project" is the process working directory,
-- and the scan thread notices that it changed and rebuilds core.project_files
-- from it. So this owns the whole transition — validate, chdir, reset the
-- cached scan state — and the thread does the rest on its next tick.
--
-- It is a runtime API rather than something an extension does inline
-- because the state it touches is the runtime's: core.project_dir, the
-- project_files table, and the revision counter the views watch. An
-- extension that chdir'd on its own would leave the revision stale and the
-- tree would keep showing the old project until something else forced a
-- rescan.
--
-- Returns true, or false plus a reason. The caller reports the reason; this
-- does not, so the same call works from a command, a keymap or a palette.
function M.set_project_dir(path)
  if type(path) ~= "string" or path == "" then
    return false, "no path given"
  end

  -- Trailing separators and backslashes are noise here: the user types them,
  -- and a path that differs only in those is the same directory.
  local cleaned = path:gsub("%s+$", ""):gsub("\\", "/"):gsub("/+$", "")
  if cleaned == "" then return false, "no path given" end

  local abs = system.absolute_path(cleaned)
  if not abs then return false, "cannot resolve: " .. cleaned end

  local info = system.get_file_info(abs)
  if not info or info.type ~= "dir" then
    return false, "not a folder: " .. abs
  end

  -- system.chdir raises on failure rather than returning false, so the call
  -- has to be guarded or a bad path takes the whole thing down instead of
  -- reporting why it did not work.
  local ok, err = pcall(system.chdir, abs)
  if not ok then
    return false, "cannot enter: " .. tostring(err or abs)
  end

  -- The thread detects a changed root on its next tick, but core.project_dir
  -- and the file list are read synchronously by the views, so they are
  -- updated here rather than one frame later.
  local core = _core
  if core then
    core.project_dir = abs
    core.project_files = {}
    bump_revision(core)
  end

  -- Drop the cached scan so the new root is walked from scratch. Without
  -- this the old project's entries would still be in _scanned and a
  -- same-named file in the new project would never be visited.
  _scanned = {}
  _prio_q  = {}
  _bg_q    = {}
  _root    = nil

  if core then core.log("Project directory: %s", abs) end
  return true
end

function M.thread(core)
  _core = core
  install_vcs_hook(core)

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