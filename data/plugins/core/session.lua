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
  if not ok or not chunk then return { recent = {} } end
  local ok2, data = pcall(chunk)
  if not ok2 or type(data) ~= "table" then return { recent = {} } end
  data.recent = data.recent or {}
  return data
end

local function save_session(data)
  local path = session_path()
  ensure_dir(path)

  local lines = { "return {" }
  lines[#lines+1] = "  recent = {"
  for _, entry in ipairs(data.recent or {}) do
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

local function push_recent(filename)
  if not filename then return end
  -- normalize
  local abs = system.absolute_path(filename) or filename
  -- deduplicate
  for i, v in ipairs(_session.recent) do
    if v == abs then
      table.remove(_session.recent, i)
      break
    end
  end
  table.insert(_session.recent, 1, abs)
  -- trim
  while #_session.recent > config.session_max_recent do
    table.remove(_session.recent)
  end
end

local function exists(path)
  local info = system.get_file_info(path)
  return info ~= nil and info.type == "file"
end

local Doc = require "core.doc"

local _orig_load = Doc.load
local _orig_save = Doc.save

Doc.load = function(self, ...)
  local res = _orig_load(self, ...)
  if self.filename then push_recent(self.filename) end
  return res
end

Doc.save = function(self, ...)
  local res = _orig_save(self, ...)
  if self.filename then push_recent(self.filename) end
  return res
end

local _restored = false
local _orig_step = nil

local function do_restore()
  if not config.session_restore then return end
  local recent = _session.recent
  if #recent == 0 then return end
  local first = recent[1]
  if first and exists(first) then
    core.try(function()
      core.root_view:open_doc(core.open_doc(first))
    end)
    core.log("session: restored %s", first)
  end
end
local _orig_core_run
core.add_thread(function()
  coroutine.yield(0.05) 
  if not _restored then
    _restored = true
    do_restore()
  end
end)

local _orig_quit = core.quit

function core.quit(force)
  if config.session_save_on_quit then
    for _, doc in ipairs(core.docs) do
      if doc.filename then push_recent(doc.filename) end
    end
    save_session(_session)
  end
  _orig_quit(force)
end

local function open_recent_picker()
  local items = {}
  for i, path in ipairs(_session.recent) do
    if exists(path) then
      local name = path:match("[^\\/]+$") or path
      local dir  = path:match("^(.+)[\\/][^\\/]+$") or ""
      items[#items+1] = {
        text = name,
        info = dir,
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

command.add(nil, {
  ["session:open-recent"] = open_recent_picker,

  ["session:save"] = function()
    for _, doc in ipairs(core.docs) do
      if doc.filename then push_recent(doc.filename) end
    end
    if save_session(_session) then
      core.log("session: saved (%d recent files)", #_session.recent)
    end
  end,

  ["session:clear"] = function()
    _session.recent = {}
    save_session(_session)
    core.log("session: cleared")
  end,

  ["session:show-info"] = function()
    core.log("session: %d recent files — %s", #_session.recent, session_path())
  end,
})

keymap.add {
  ["ctrl+shift+r"] = "session:open-recent",
  ["ctrl+alt+s"]   = "session:save",
}

local M = {}

function M.get_recent()
  local out = {}
  for _, path in ipairs(_session.recent) do
    if exists(path) then
      out[#out+1] = path
    end
  end
  return out
end

function M.open(path)
  core.try(function()
    core.root_view:open_doc(core.open_doc(path))
  end)
end

return M
