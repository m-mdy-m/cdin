local command = require "core.input.command"
local keymap = {}

keymap.modkeys = {}
keymap.map = {}
keymap.reverse_map = {}

local modkey_map = {
  ["left ctrl"]   = "ctrl",
  ["right ctrl"]  = "ctrl",
  ["left shift"]  = "shift",
  ["right shift"] = "shift",
  ["left alt"]    = "alt",
  ["right alt"]   = "altgr",
}

local modkeys = { "ctrl", "alt", "altgr", "shift" }

local function key_to_stroke(k)
  local stroke = ""
  for _, mk in ipairs(modkeys) do
    if keymap.modkeys[mk] then
      stroke = stroke .. mk .. "+"
    end
  end
  return stroke .. k
end


function keymap.add(map, overwrite)
  for stroke, commands in pairs(map) do
    if type(commands) == "string" then
      commands = { commands }
    end
    if overwrite then
      keymap.map[stroke] = commands
    else
      keymap.map[stroke] = keymap.map[stroke] or {}
      for i = #commands, 1, -1 do
        table.insert(keymap.map[stroke], 1, commands[i])
      end
    end
    for _, cmd in ipairs(commands) do
      keymap.reverse_map[cmd] = stroke
    end
  end
end


-- Undo a previous keymap.add(). `map` is the same shape that was added
-- (stroke -> command or list of commands); only the named commands are
-- detached, so other plugins bound to the same stroke keep working.
-- This is what lets a plugin's unload() really unbind its keys instead of
-- leaving them live after the plugin has been unloaded.
function keymap.remove(map)
  for stroke, commands in pairs(map or {}) do
    if type(commands) == "string" then commands = { commands } end
    local bound = keymap.map[stroke]
    if bound then
      for i = #bound, 1, -1 do
        for _, cmd in ipairs(commands) do
          if bound[i] == cmd then table.remove(bound, i) end
        end
      end
      if #bound == 0 then keymap.map[stroke] = nil end
    end
    -- reverse_map is a cmd -> single stroke lookup, so only clear it
    -- when no remaining stroke still binds that command.
    for _, cmd in ipairs(commands) do
      local still_bound = false
      for _, other in pairs(keymap.map) do
        for _, c in ipairs(other) do
          if c == cmd then still_bound = true; break end
        end
        if still_bound then break end
      end
      if not still_bound then keymap.reverse_map[cmd] = nil end
    end
  end
end


function keymap.get_binding(cmd)
  return keymap.reverse_map[cmd]
end


function keymap.on_key_pressed(k)
  local mk = modkey_map[k]
  if mk then
    keymap.modkeys[mk] = true
    -- work-around for windows where `altgr` is treated as `ctrl+alt`
    if mk == "altgr" then
      keymap.modkeys["ctrl"] = false
    end
  else
    local stroke = key_to_stroke(k)
    local commands = keymap.map[stroke]
    if commands then
      local performed = false
      for _, cmd in ipairs(commands) do
        performed = command.perform(cmd)
        if performed then break end
      end
      return performed
    end
  end
  return false
end


function keymap.on_key_released(k)
  local mk = modkey_map[k]
  if mk then
    keymap.modkeys[mk] = false
  end
end


for _, layer in ipairs(require "core.keymaps.default") do
  keymap.add(layer)
end


return keymap