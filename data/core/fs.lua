local _fs   = require "fs"
local _path = require "path"

local M = {}


M.sep = _path.sep


function M.exists(p)
  return _fs.stat(p) ~= nil
end

function M.is_dir(p)
  local info = _fs.stat(p)
  return info ~= nil and info.type == "dir"
end

function M.is_file(p)
  local info = _fs.stat(p)
  return info ~= nil and info.type == "file"
end

function M.stat(p)
  local info, err = _fs.stat(p)
  if not info then return nil, err end
  return info
end

function M.mkdir(p)
  local ok, err = _fs.mkdir_all(p)
  if not ok then
    return false, ("mkdir: %s: %s"):format(p, err or "unknown error")
  end
  return true
end

function M.rm(p)
  local ok, err = _fs.remove_all(p)
  if not ok then
    return false, ("rm: %s: %s"):format(p, err or "unknown error")
  end
  return true
end

function M.list(p)
  p = p or "."
  local names, err = _fs.list_dir(p)
  if not names then
    return nil, ("ls: cannot read directory '%s': %s"):format(p, err or "")
  end
  table.sort(names)
  local result = {}
  for _, name in ipairs(names) do
    local full = p ~= "." and (p .. M.sep .. name) or name
    local info = _fs.stat(full) or {}
    result[#result + 1] = {
      name = name,
      type = info.type or "file",
      size = info.size or 0,
    }
  end
  return result
end

M.ls = M.list   -- alias

function M.touch(p)
  if M.exists(p) then
    return false, ("touch: already exists: %s"):format(p)
  end
  local fp, err = io.open(p, "w")
  if not fp then
    return false, ("touch: %s"):format(err or "cannot create file")
  end
  fp:close()
  return true
end

function M.copy(src, dst)
  local ok, err = _fs.copy_all(src, dst)
  if not ok then
    return false, ("copy: %s"):format(err or "unknown error")
  end
  return true
end

function M.rename(old, new)
  local ok, err = os.rename(old, new)
  if ok then return true end
  return false, ("rename: %s"):format(err or "unknown error")
end

function M.move(src, dst)
  local ok = os.rename(src, dst)
  if ok then return true end

  local ok2, err2 = M.copy(src, dst)
  if not ok2 then return false, err2 end

  local ok3, err3 = M.rm(src)
  if not ok3 then return false, err3 end

  return true
end

function M.abs(p)
  return _path.absolute(p) or p
end

function M.join(...)
  return _path.join(...)
end

function M.basename(p)
  return _path.basename(p)
end

function M.dirname(p)
  return _path.dirname(p)
end

function M.ext(p)
  return _path.ext(p)
end

function M.stem(p)
  return _path.stem(p)
end

function M.split(p)
  return _path.split(p)
end

function M.normalize(p)
  return _path.normalize(p)
end

function M.is_absolute(p)
  return _path.is_absolute(p)
end

function M.pwd()
  return system.absolute_path(".") or "."
end

function M.cd(p)
  local ok, err = pcall(system.chdir, p)
  if not ok then
    return false, ("cd: %s"):format(err or "unknown error")
  end
  return true
end

return M