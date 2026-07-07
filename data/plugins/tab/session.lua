local core   = require "core"
local config = require "core.config"

if config.tab_session_restore == nil then config.tab_session_restore = false end

local IS_WIN = PATHSEP == "\\"

local function session_path()
  local base
  if IS_WIN then
    base = os.getenv("APPDATA") or os.getenv("USERPROFILE") or "."
    return base .. "\\cdin\\tab_session.lua"
  else
    base = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
    return base .. "/cdin/tab_session.lua"
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

local function collect_files(node, out)
  if not node then return end
  if node.type == "leaf" then
    for _, v in ipairs(node.views or {}) do
      if v.doc and v.doc.filename then
        table.insert(out, v.doc.filename)
      end
    end
  else
    collect_files(node.a, out)
    collect_files(node.b, out)
  end
end

-- ─── save ───────────────────────────────────────────────────────────────────

local function save()
  local M = require "plugins.tab.manager"

  local path = session_path()
  ensure_dir(path)

  local lines = { "return {" }
  lines[#lines+1] = "  active_index = " .. (M.get_index(M.active_id) or 1) .. ","
  lines[#lines+1] = "  tabs = {"

  for _, id in ipairs(M.tab_order) do
    local tab = M.tabs[id]
    if tab then
      local files = {}
      collect_files(tab.root_node, files)
      -- also check if active tab has unsaved files in current node
      if id == M.active_id then
        collect_files(require("plugins.tab.manager").tabs[id] and
          core.root_view.root_node or nil, files)
      end
      local safe_name = tab.name:gsub('"', '\\"')
      lines[#lines+1] = "    {"
      lines[#lines+1] = '      name = "' .. safe_name .. '",'
      lines[#lines+1] = "      pinned = " .. tostring(tab.pinned) .. ","
      lines[#lines+1] = "      files = {"
      for _, f in ipairs(files) do
        local sf = f:gsub("\\", "\\\\"):gsub('"', '\\"')
        lines[#lines+1] = '        "' .. sf .. '",'
      end
      lines[#lines+1] = "      },"
      lines[#lines+1] = "    },"
    end
  end

  lines[#lines+1] = "  },"
  lines[#lines+1] = "}"

  local fp, err = io.open(path, "w")
  if not fp then
    core.error("tab-session: cannot write %s — %s", path, err)
    return false
  end
  fp:write(table.concat(lines, "\n") .. "\n")
  fp:close()
  return true
end

-- ─── restore ────────────────────────────────────────────────────────────────

local function restore()
  if not config.tab_session_restore then return end

  local path = session_path()
  local ok, chunk = pcall(loadfile, path)
  if not ok or not chunk then return end
  local ok2, data = pcall(chunk)
  if not ok2 or type(data) ~= "table" then return end

  local M = require "plugins.tab.manager"

  local tabs = data.tabs or {}
  if #tabs == 0 then return end

  for i, tdata in ipairs(tabs) do
    if i == 1 then
      -- first tab already exists (bootstrap created it)
      local existing = M.tabs[M.active_id]
      if existing then
        existing.name   = tdata.name or existing.name
        existing.pinned = tdata.pinned or false
      end
      for _, f in ipairs(tdata.files or {}) do
        if system.get_file_info(f) then
          core.try(function()
            core.root_view:open_doc(core.open_doc(f))
          end)
        end
      end
    else
      local id = M.create(tdata.name or ("Tab " .. i), false)
      local tab_obj = M.tabs[id]
      if tab_obj then
        tab_obj.pinned = tdata.pinned or false
      end
      -- We can't restore individual layouts without deep-copying Node trees,
      -- so we activate the tab, open files, then move on.
      M.activate(id)
      for _, f in ipairs(tdata.files or {}) do
        if system.get_file_info(f) then
          core.try(function()
            core.root_view:open_doc(core.open_doc(f))
          end)
        end
      end
    end
  end

  -- switch to the previously active tab
  local active_idx = data.active_index or 1
  local target_id  = M.tab_order[active_idx] or M.tab_order[1]
  if target_id then M.activate(target_id) end

  core.log("tab-session: restored %d tab(s)", #tabs)
end

-- ─── wire into quit ─────────────────────────────────────────────────────────

local _orig_quit = core.quit
function core.quit(force)
  save()
  _orig_quit(force)
end

-- ─── delayed restore ─────────────────────────────────────────────────────────

core.add_thread(function()
  coroutine.yield(0.1)
  restore()
end)

local S = {}
S.save    = save
S.restore = restore
return S
