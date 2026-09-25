local core              = require "core"
local config            = require "core.config"
local command           = require "core.input.command"
local common            = require "core.utils.common"
local session_bootstrap = require "core.session_bootstrap"

if config.session_max_recent  == nil then config.session_max_recent  = 10  end
if config.session_restore      == nil then config.session_restore      = false end
if config.session_save_on_quit == nil then config.session_save_on_quit = true end
if config.session_restore_dir  == nil then config.session_restore_dir  = true end
if config.session_restore_theme == nil then config.session_restore_theme = true end

local session_path = session_bootstrap.session_path
local ensure_dir   = common.ensure_dir

local function load_session()
  return core._boot_session or session_bootstrap.read()
end

local function save_session(data)
  local path = session_path()
  ensure_dir(path)

  local lines = { "return {" }

  -- recent_files
  lines[#lines+1] = "  recent_files = {"
  for _, entry in ipairs(data.recent_files or {}) do
    local safe = entry:gsub("\\", "\\\\"):gsub('"', '\\"')
    lines[#lines+1] = '    "' .. safe .. '",'
  end
  lines[#lines+1] = "  },"

  -- recent_dirs
  lines[#lines+1] = "  recent_dirs = {"
  for _, entry in ipairs(data.recent_dirs or {}) do
    local safe = entry:gsub("\\", "\\\\"):gsub('"', '\\"')
    lines[#lines+1] = '    "' .. safe .. '",'
  end
  lines[#lines+1] = "  },"

  -- last_dir
  if data.last_dir then
    local safe_dir = data.last_dir:gsub("\\", "\\\\"):gsub('"', '\\"')
    lines[#lines+1] = '  last_dir = "' .. safe_dir .. '",'
  end

  -- theme
  if data.theme then
    local safe_theme = data.theme:gsub("\\", "\\\\"):gsub('"', '\\"')
    lines[#lines+1] = '  theme = "' .. safe_theme .. '",'
  end

  lines[#lines+1] = "}"

  local fp, err = io.open(path, "w")
  if not fp then
    core.error("session: cannot write %s — %s", path, err)
    return false
  end
  fp:write(table.concat(lines, "\n") .. "\n")
  fp:close()
  return true
end

local _session = load_session()

local function short_label(path, is_dir)
  if is_dir then
    local name = path:match("([^\\/]+)[\\/]?$") or path
    return name .. "/"
  else
    return path:match("[^\\/]+$") or path
  end
end

local function push_recent_dir(dirpath)
  if not dirpath then return end
  local abs = system.absolute_path(dirpath) or dirpath
  for i, v in ipairs(_session.recent_dirs) do
    if v == abs then table.remove(_session.recent_dirs, i); break end
  end
  table.insert(_session.recent_dirs, 1, abs)
  while #_session.recent_dirs > config.session_max_recent do
    table.remove(_session.recent_dirs)
  end
end

local function set_last_dir(dirpath)
  if not dirpath then return end
  local abs = system.absolute_path(dirpath) or dirpath
  _session.last_dir = abs
end

local function push_recent_file(filename)
  if not filename then return end
  local abs = system.absolute_path(filename) or filename
  for i, v in ipairs(_session.recent_files) do
    if v == abs then table.remove(_session.recent_files, i); break end
  end
  table.insert(_session.recent_files, 1, abs)
  while #_session.recent_files > config.session_max_recent do
    table.remove(_session.recent_files)
  end
  -- Also push the parent directory
  local dir = abs:match("^(.+)[\\/][^\\/]+$")
  if dir then push_recent_dir(dir) end
end

local function file_exists(path)
  local info = system.get_file_info(path)
  return info ~= nil and info.type == "file"
end

local function dir_exists(path)
  local info = system.get_file_info(path)
  return info ~= nil and info.type == "dir"
end

local Doc = require "core.doc"

-- Register hooks instead of monkey-patching Doc.load / Doc.save
table.insert(Doc._after_load, function(doc)
  if doc.filename then push_recent_file(doc.filename) end
end)
table.insert(Doc._after_save, function(doc)
  if doc.filename then push_recent_file(doc.filename) end
end)

-- Directory and theme are already restored synchronously by core.init()
-- before the first frame — see data/core/init.lua. All that's left here is
-- optionally reopening the last file, which does need to wait a beat for
-- the views to exist. core.root_view is already set up by the time plugins
-- load, so this no longer needs coroutine.yield() to wait for anything;
-- it's a plain core.add_thread call purely so a bad restore can't block
-- startup (core.try already guards it either way).
local _restored = false
core.add_thread(function()
  if _restored then return end
  _restored = true

  if config.session_restore then
    local recent = _session.recent_files
    local first = recent and recent[1]
    if first and file_exists(first) then
      core.try(function()
        core.root_view:open_doc(core.open_doc(first))
      end)
      core.log("session: restored %s", first)
    end
  end
end)

local _orig_quit = core.quit

function core.quit(force)
  core.log("plugins.core.session: quit wrapper called, force=%s", tostring(force))
  if config.session_save_on_quit then
    for _, doc in ipairs(core.docs) do
      if doc.filename then push_recent_file(doc.filename) end
    end
    if core.project_dir then set_last_dir(core.project_dir) end
    if config.theme then _session.theme = config.theme end
    save_session(_session)
    core.log("plugins.core.session: session saved on quit")
  end
  _orig_quit(force)
end

-- Recent Files picker
local function open_recent_files_picker()
  local items = {}
  for i, path in ipairs(_session.recent_files) do
    if file_exists(path) then
      local name = path:match("[^\\/]+$") or path
      local dir  = path:match("^(.+)[\\/][^\\/]+$") or ""
      local dir_label = ""
      if dir ~= "" then
        local last = dir:match("([^\\/]+)$") or dir
        dir_label = last .. "/"
      end
      items[#items+1] = {
        text = name,
        info = dir_label,
        path = path,
        idx  = i,
      }
    end
  end

  if #items == 0 then
    core.log("session: no recent files")
    return
  end

  core.command_view:enter("Recent Files", function(text, item)
    if item and item.path then
      core.try(function()
        core.root_view:open_doc(core.open_doc(item.path))
      end)
    end
  end, function(text)
    if text == "" then return items end
    local res = {}
    for _, it in ipairs(items) do
      if it.text:lower():find(text:lower(), 1, true)
      or it.info:lower():find(text:lower(), 1, true) then
        res[#res+1] = it
      end
    end
    return res
  end)
end

local function open_recent_dirs_picker()
  local items = {}
  for i, path in ipairs(_session.recent_dirs) do
    if dir_exists(path) then
      local name = path:match("([^\\/]+)[\\/]?$") or path
      local parent = path:match("^(.+)[\\/][^\\/]+$") or ""
      items[#items+1] = {
        text = name .. "/",
        info = parent,
        path = path,
        idx  = i,
      }
    end
  end

  if #items == 0 then
    core.log("session: no recent directories")
    return
  end

  core.command_view:enter("Recent Directories", function(text, item)
    if item and item.path then
      local ok, err = pcall(system.chdir, item.path)
      if ok then
        core.project_dir = system.absolute_path(".") or item.path
        push_recent_dir(item.path)
        set_last_dir(item.path)
        core.log("session: changed to %s", item.path)
        pcall(function() command.perform("treeview:refresh") end)
      else
        core.error("session: cd failed: %s", tostring(err))
      end
    end
  end, function(text)
    if text == "" then return items end
    local res = {}
    for _, it in ipairs(items) do
      if it.text:lower():find(text:lower(), 1, true)
      or it.info:lower():find(text:lower(), 1, true) then
        res[#res+1] = it
      end
    end
    return res
  end)
end

command.add(nil, {
  ["session:open-recent"]      = open_recent_files_picker,
  ["session:open-recent-dirs"] = open_recent_dirs_picker,

  ["session:save"] = function()
    for _, doc in ipairs(core.docs) do
      if doc.filename then push_recent_file(doc.filename) end
    end
    if save_session(_session) then
      core.log("session: saved (%d files, %d dirs)", #_session.recent_files, #_session.recent_dirs)
    end
  end,

  ["session:clear"] = function()
    _session.recent_files = {}
    _session.recent_dirs  = {}
    _session.last_dir     = nil
    _session.theme        = nil
    save_session(_session)
    core.log("session: cleared")
  end,

  ["session:show-info"] = function()
    core.log("session: %d files, %d dirs — %s",
      #_session.recent_files, #_session.recent_dirs, session_path())
  end,
})


local M = {}

function M.get_recent_files()
  local out = {}
  for _, path in ipairs(_session.recent_files) do
    if file_exists(path) then out[#out+1] = path end
  end
  return out
end

function M.get_recent()
  return M.get_recent_files()
end

function M.get_recent_dirs()
  local out = {}
  for _, path in ipairs(_session.recent_dirs) do
    if dir_exists(path) then out[#out+1] = path end
  end
  return out
end

function M.open(path)
  core.try(function()
    core.root_view:open_doc(core.open_doc(path))
  end)
end

function M.set_theme(name)
  if not name then return end
  _session.theme = name
  save_session(_session)
end

function M.open_dir(path)
  local ok, err = pcall(system.chdir, path)
  if ok then
    core.project_dir = system.absolute_path(".") or path
    push_recent_dir(path)
    set_last_dir(path)
    pcall(function() command.perform("treeview:refresh") end)
  end
  return ok, err
end

return M