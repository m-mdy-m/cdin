local Object = require "core.utils.object"

local Tab = Object:extend()

local _next_id = 1
local function gen_id()
  local id = _next_id
  _next_id = _next_id + 1
  return id
end

function Tab:new(name)
  self.id          = gen_id()
  self.name        = name or ("Tab " .. self.id)
  self.root_node   = nil
  self.active_view = nil
  self.pinned      = false
  self.created_at  = os.time()
end

function Tab:get_display_name()
  local av = self.active_view
  if av and av.get_name then
    local ok, n = pcall(av.get_name, av)
    if ok and n and n ~= "" then return n end
  end
  return self.name
end

return Tab
