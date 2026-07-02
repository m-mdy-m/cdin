-- Filesystem operations for vimode ex-commands and the treeview

local IS_WIN = PATHSEP == "\\"

local M = {}


local function shell_quote(s)
  if IS_WIN then
    return '"' .. s:gsub('"', '""') .. '"'
  else
    return "'" .. s:gsub("'", "'\\''") .. "'"
  end
end

local function exec_silent(cmd)
  local ok, _, code = os.execute(cmd)
  if ok == true or ok == 0 then return true end
  return false, ("command failed (exit %s): %s"):format(tostring(code), cmd)
end


function M.exists(path)
  local info = system.get_file_info(path)
  return info ~= nil
end

function M.is_dir(path)
  local info = system.get_file_info(path)
  return info ~= nil and info.type == "dir"
end

function M.mkdir(path)
  if M.exists(path) then
    return false, ("mkdir: already exists: %s"):format(path)
  end
  local cmd
  if IS_WIN then
    cmd = 'mkdir "' .. path:gsub("/", "\\") .. '"'
  else
    cmd = "mkdir -p " .. shell_quote(path)
  end
  local ok, err = exec_silent(cmd)
  if not ok then
    return false, ("mkdir: could not create '%s': %s"):format(path, err or "")
  end
  return true
end

function M.rm(path)
  if not M.exists(path) then
    return false, ("rm: no such file or directory: %s"):format(path)
  end
  if M.is_dir(path) then
    local cmd
    if IS_WIN then
      cmd = 'rmdir /s /q "' .. path:gsub("/", "\\") .. '"'
    else
      cmd = "rm -rf " .. shell_quote(path)
    end
    local ok, err = exec_silent(cmd)
    if not ok then
      return false, ("rm: %s"):format(err or "unknown error")
    end
  else
    local ok, err = os.remove(path)
    if not ok then
      return false, ("rm: %s"):format(err or "unknown error")
    end
  end
  return true
end

function M.rename(old, new)
  if not M.exists(old) then
    return false, ("rename: no such file: %s"):format(old)
  end
  local ok, err = os.rename(old, new)
  if not ok then
    return false, ("rename: %s"):format(err or "unknown error")
  end
  return true
end

function M.copy(src, dst)
  if not M.exists(src) then
    return false, ("copy: source not found: %s"):format(src)
  end
  if M.is_dir(src) then
    local cmd
    if IS_WIN then
      cmd = 'xcopy /E /I /H /Y "' .. src:gsub("/","\\") .. '" "' .. dst:gsub("/","\\") .. '"'
    else
      cmd = "cp -r " .. shell_quote(src) .. " " .. shell_quote(dst)
    end
    local ok, err = exec_silent(cmd)
    if not ok then
      return false, ("copy: %s"):format(err or "unknown error")
    end
    return true
  end

  local inf, err1 = io.open(src, "rb")
  if not inf then
    return false, ("copy: cannot open source: %s"):format(err1 or src)
  end
  local outf, err2 = io.open(dst, "wb")
  if not outf then
    inf:close()
    return false, ("copy: cannot create destination: %s"):format(err2 or dst)
  end
  while true do
    local chunk = inf:read(65536)
    if not chunk then break end
    outf:write(chunk)
  end
  inf:close()
  outf:close()
  return true
end

function M.move(src, dst)
  local ok = os.rename(src, dst)
  if ok then return true end
  local ok2, err = M.copy(src, dst)
  if not ok2 then return false, err end
  local ok3, err2 = M.rm(src)
  if not ok3 then return false, err2 end
  return true
end

function M.touch(path)
  if M.exists(path) then
    return false, ("touch: already exists: %s"):format(path)
  end
  local fp, err = io.open(path, "w")
  if not fp then
    return false, ("touch: %s"):format(err or "cannot create file")
  end
  fp:close()
  return true
end

function M.ls(path)
  path = path or "."
  local names = system.list_dir(path)
  if not names then
    return nil, ("ls: cannot read directory: %s"):format(path)
  end
  table.sort(names)
  local result = {}
  for _, name in ipairs(names) do
    local full = path ~= "." and (path .. PATHSEP .. name) or name
    local info = system.get_file_info(full) or {}
    result[#result + 1] = {
      name = name,
      type = info.type or "file",
      size = info.size or 0,
    }
  end
  return result
end

function M.pwd()
  return system.absolute_path(".")
end

function M.cd(path)
  local ok, err = pcall(system.chdir, path)
  if not ok then
    return false, ("cd: %s"):format(err or "unknown error")
  end
  return true
end

return M