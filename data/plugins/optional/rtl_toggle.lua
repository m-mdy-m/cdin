-- Optional: RTL toggle + direction status.
local core = require "core"
local config = require "core.config"
local command = require "core.input.command"
local keymap = require "core.input.keymap"

if config.optional_plugins and config.optional_plugins.rtl_toggle == false then
  return
end

local modes = { "auto", "ltr", "rtl" }
local idx = 1
for i, m in ipairs(modes) do
  if m == (config.direction or "auto") then idx = i break end
end

command.add(nil, {
  ["rtl:toggle-direction"] = function()
    idx = idx % #modes + 1
    config.direction = modes[idx]
    core.log("Text direction: %s (shaping %s)", config.direction,
      config.shaping_enabled ~= false and "on" or "off")
    core.redraw = true
  end,
  ["rtl:toggle-shaping"] = function()
    config.shaping_enabled = not (config.shaping_enabled ~= false)
    core.log("Arabic shaping %s", config.shaping_enabled and "on" or "off")
    core.redraw = true
  end,
})

keymap.add({
  ["ctrl+alt+r"] = "rtl:toggle-direction",
  ["ctrl+alt+s"] = "rtl:toggle-shaping",
})
