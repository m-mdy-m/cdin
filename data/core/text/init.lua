local utf8 = require "core.text.utf8"
local bidi = require "core.text.bidi"
local shaper = require "core.text.shaper"

local text = {
  utf8 = utf8,
  bidi = bidi,
  shaper = shaper,
}

function text.visual(s, opts)
  if type(s) ~= "string" then return "" end
  opts = opts or {}
  local dir = opts.direction or "auto"
  local shaping = opts.shaping
  if shaping == nil then shaping = true end
  local shaped = (shaping and shaper.needs_shaping(s)) and shaper.shape(s) or s
  if dir == "ltr" and not bidi.has_rtl(s) then return shaped end
  return bidi.visual(shaped, dir)
end

return text
