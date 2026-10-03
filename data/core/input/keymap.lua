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

local MODIFIER_RANK, MODIFIER_SET = {}, {}
for idx, mk in ipairs(modkeys) do
  MODIFIER_RANK[mk] = idx
  MODIFIER_SET[mk] = true
end

local FOREIGN_MODIFIERS = {
  cmd = true, command = true, meta = true, super = true, win = true,
  windows = true, control = true, option = true, opt = true, hyper = true,
}

keymap.unreachable = {}

function keymap.canonical_stroke(stroke)
  if type(stroke) ~= "string" or stroke == "" then return nil, "not a keystroke" end

  local parts, pos = {}, 1
  while true do
    local at = stroke:find("+", pos, true)
    parts[#parts + 1] = at and stroke:sub(pos, at - 1) or stroke:sub(pos)
    if not at then break end
    pos = at + 1
  end
  for _, part in ipairs(parts) do
    if part == "" then
      return nil, "'+' joins modifiers and nothing else, so this stroke has an empty part"
    end
  end

  local mods, key_parts = {}, {}
  for _, part in ipairs(parts) do
    if MODIFIER_SET[part] then mods[part] = true else key_parts[#key_parts + 1] = part end
  end
  local canonical = {}
  for _, mk in ipairs(modkeys) do
    if mods[mk] then canonical[#canonical + 1] = mk end
  end
  for _, part in ipairs(key_parts) do canonical[#canonical + 1] = part:lower() end
  local suggestion = table.concat(canonical, "+")

  local seen = 0
  for _, part in ipairs(parts) do
    if MODIFIER_SET[part] then
      if MODIFIER_RANK[part] <= seen then
        return nil, ("%q is repeated or out of order — modifiers are built ctrl, alt, altgr, shift")
          :format(part), suggestion
      end
      seen = MODIFIER_RANK[part]
    end
  end

  if #parts > 1 and FOREIGN_MODIFIERS[parts[1]] then
    return nil, ("%q is not a modifier this input layer reports; it knows ctrl, alt, altgr and shift")
      :format(parts[1])
  end

  if #key_parts == 0 then return nil, "modifiers but no key", suggestion end
  if #key_parts > 1 then
    return nil, "the key is one key name; '+' joins modifiers and is not part of it", suggestion
  end
  if key_parts[1]:find("%u") then
    return nil, "key names arrive lowercased from the input layer", suggestion
  end

  return suggestion
end


function keymap.add(map, overwrite)
  for stroke, commands in pairs(map) do
    if type(commands) == "string" then
      commands = { commands }
    end
    local canonical, reason, suggestion = keymap.canonical_stroke(stroke)
    if not canonical then
      local names = {}
      for _, cmd in ipairs(commands) do names[#names + 1] = cmd end
      keymap.unreachable[stroke] = {
        stroke = stroke, commands = names, reason = reason, suggestion = suggestion,
      }
    end
    if overwrite then
      keymap.map[stroke] = commands
    else
      keymap.map[stroke] = keymap.map[stroke] or {}
      local chain = keymap.map[stroke]
      -- A command already in the chain is moved to the front rather than
      -- inserted a second time, so a plugin that registers twice (enable /
      -- disable cycles, reloads) does not grow the chain on every load.
      for i = #commands, 1, -1 do
        for j = #chain, 1, -1 do
          if chain[j] == commands[i] then table.remove(chain, j) end
        end
        table.insert(chain, 1, commands[i])
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


-- Say the unreachable strokes out loud, once, after boot. `core` is an
-- argument rather than a require because keymap.lua is loaded from inside
-- core's own require chain, so `require "core"` at this level is a circular
-- require. Called from core.init, once every plugin has registered.
function keymap.report_unreachable(core)
  local strokes = {}
  for stroke in pairs(keymap.unreachable) do strokes[#strokes + 1] = stroke end
  if #strokes == 0 then return 0 end
  table.sort(strokes)

  core.error("keymap: %d bound stroke%s no key press can produce, so the binding is dead:",
    #strokes, #strokes == 1 and "" or "s")
  for _, stroke in ipairs(strokes) do
    local entry = keymap.unreachable[stroke]
    core.error("keymap:   %q -> %s: %s%s",
      stroke, table.concat(entry.commands, ", "), entry.reason,
      entry.suggestion and entry.suggestion ~= stroke
        and (" - write it as " .. string.format("%q", entry.suggestion))
        or "")
  end
  return #strokes
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