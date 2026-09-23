-- Optional: theme switcher (data/themes/* + core:change-theme).
local core = require "core"
local config = require "core.config"
local common = require "core.utils.common"
local command = require "core.input.command"
local keymap = require "core.input.keymap"
local style = require "core.style"

if config.optional_plugins and config.optional_plugins.theme_switcher == false then
  return
end

command.add(nil, {
  ["core:change-theme"] = function()
    local ok, themes = pcall(require, "core.themes")
    if not ok or not themes then core.error("themes module missing") return end
    core.command_view:enter("Change Theme", function(_, item)
      local name = item and item.text or nil
      if not name then return end
      if style.set_theme(name) then
        config.theme = name
        core.log("Theme: %s", name)
        core.redraw = true
      else
        core.error("Unknown theme: %s", name)
      end
    end, function(text)
      return common.fuzzy_match(themes.names(), text)
    end)
  end,
})

keymap.add({ ["ctrl+alt+t"] = "core:change-theme" })
