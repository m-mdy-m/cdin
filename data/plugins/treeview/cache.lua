local M = {}

local function item_hash(item)
  local modified = item.modified or 0
  return item.filename .. "\0" .. (item.type or "") .. "\0" .. tostring(modified)
end

local _store = {}
local _order = {}
local MAX_ENTRIES = 4096

local function evict_oldest()
  if #_order > MAX_ENTRIES then
    local oldest = table.remove(_order, 1)
    _store[oldest] = nil
  end
end

function M.get(item)
  local h = item_hash(item)
  local entry = _store[h]
  if entry then
    for i, k in ipairs(_order) do
      if k == h then
        table.remove(_order, i)
        break
      end
    end
    table.insert(_order, h)
    return entry
  end

  local function get_depth(filename)
    local n = 0
    for _ in filename:gmatch("[\\/]") do n = n + 1 end
    return n
  end

  entry = {
    filename     = item.filename,
    abs_filename = system.absolute_path(item.filename),
    name         = item.filename:match("[^\\/]+$"),
    depth        = get_depth(item.filename),
    type         = item.type,
    skip         = nil,
    _hash        = h,
  }

  _store[h] = entry
  table.insert(_order, h)
  evict_oldest()
  return entry
end

function M.invalidate_skips()
  for _, entry in pairs(_store) do
    entry.skip = nil
  end
end

function M.flush()
  _store = {}
  _order = {}
end

function M.stats()
  return { size = #_order, max = MAX_ENTRIES }
end

return M