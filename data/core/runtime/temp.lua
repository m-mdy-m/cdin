local M = {}

local uid     = math.floor((system.get_time() * 1000) % 0xffffffff)
local prefix  = string.format(".lite_temp_%08x", uid)
local counter = 0

function M.filename(ext)
  counter = counter + 1
  return EXEDIR .. PATHSEP .. prefix
      .. string.format("%06x", counter) .. (ext or "")
end

function M.delete_all()
  for _, filename in ipairs(system.list_dir(EXEDIR) or {}) do
    if filename:find(prefix, 1, true) == 1 then
      os.remove(EXEDIR .. PATHSEP .. filename)
    end
  end
end

return M