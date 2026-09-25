local M = {}

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

local function empty_session()
  return { recent_files = {}, recent_dirs = {}, last_dir = nil, theme = nil }
end

-- Reads and parses the session file. Never throws: any failure (missing
-- file, malformed Lua, wrong shape) yields an empty session instead.
function M.read()
  local path = session_path()
  local ok, chunk = pcall(loadfile, path)
  if not ok or not chunk then return empty_session() end
  local ok2, data = pcall(chunk)
  if not ok2 or type(data) ~= "table" then return empty_session() end
  if data.recent and not data.recent_files then
    data.recent_files = data.recent
    data.recent = nil
  end
  data.recent_files = data.recent_files or {}
  data.recent_dirs  = data.recent_dirs  or {}
  data.last_dir     = data.last_dir  -- may be nil, that's fine
  data.theme        = data.theme     -- may be nil, that's fine
  return data
end

M.session_path = session_path

return M