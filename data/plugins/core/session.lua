local core    = require "core"
local config  = require "core.config"
local command = require "core.input.command"
local keymap  = require "core.input.keymap"
local common  = require "core.utils.common"

if config.session_max_recent  == nil then config.session_max_recent  = 10  end
if config.session_restore      == nil then config.session_restore      = true end
if config.session_save_on_quit == nil then config.session_save_on_quit = true end

local IS_WIN = PATHSEP == "\\"

local function session_path()
  local base
  if IS_WIN then
    base = os.getenv("APPDATA") or os.getenv("USERPROFILE") or "."
    return base .. "\\cdin\\session.lua"
  else
    base = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
    return base .. "/cdin/session.lua"
  end
end

local function ensure_dir(path)
  local dir = path:match("^(.+)[\\/][^\\/]+$")
  if not dir then return end
  if IS_WIN then
    os.execute('mkdir "' .. dir .. '" 2>nul')
  else
    os.execute('mkdir -p "' .. dir .. '"')
  end
end

local function load_session()
  local path = session_path()
  local ok, chunk = pcall(loadfile, path)
  if not ok or not chunk then return { recent_files = {}, recent_dirs = {} } end
  local ok2, data = pcall(chunk)
  if not ok2 or type(data) ~= "table" then return { recent_files = {}, recent_dirs = {} } end
  if data.recent and not data.recent_files then
    data.recent_files = data.recent
    data.recent = nil
  end
  data.recent_files = data.recent_files or {}
  data.recent_dirs  = data.recent_dirs  or {}
  return data
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

local _orig_load = Doc.load
local _orig_save = Doc.save

Doc.load = function(self, ...)
  local res = _orig_load(self, ...)
  if self.filename then push_recent_file(self.filename) end
  return res
end

Doc.save = function(self, ...)
  local res = _orig_save(self, ...)
  if self.filename then push_recent_file(self.filename) end
  return res
end

local _restored = false
core.add_thread(function()
  coroutine.yield(0.05)
  if not _restored then
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
  end
end)

local _orig_quit = core.quit

function core.quit(force)
  if config.session_save_on_quit then
    for _, doc in ipairs(core.docs) do
      if doc.filename then push_recent_file(doc.filename) end
    end
    save_session(_session)
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
    save_session(_session)
    core.log("session: cleared")
  end,

  ["session:show-info"] = function()
    core.log("session: %d files, %d dirs — %s",
      #_session.recent_files, #_session.recent_dirs, session_path())
  end,
})

keymap.add {
  ["ctrl+shift+r"] = "session:open-recent",
  ["ctrl+shift+d"] = "session:open-recent-dirs",
  ["ctrl+alt+s"]   = "session:save",
}

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

function M.open_dir(path)
  local ok, err = pcall(system.chdir, path)
  if ok then
    push_recent_dir(path)
    pcall(function() command.perform("treeview:refresh") end)
  end
  return ok, err
end

return M