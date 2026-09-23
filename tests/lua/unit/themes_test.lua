local T = require "harness"
local themes = require "core.themes"

T.ok(type(themes.list) == "table" and #themes.list > 0, "themes.list non-empty")
T.eq(type(themes.names), "function", "themes.names() exists")
T.eq(type(themes.apply), "function", "themes.apply() exists")
T.eq(themes.names(), themes.list, "names() returns a copy of list")

local has_default = false
for _, n in ipairs(themes.list) do
  if n == "default" then has_default = true end
end
T.ok(has_default, "default theme is in themes.list")


local function all_keys(t, prefix, out)
  out = out or {}
  for k, v in pairs(t) do
    local key = prefix and (prefix .. "." .. tostring(k)) or tostring(k)
    out[key] = true
    if type(v) == "table" then all_keys(v, key, out) end
  end
  return out
end

local function check_color_strings(t, label)
  for k, v in pairs(t) do
    if k ~= "name" and type(v) == "string" then
      T.match(v, "^#%x%x%x%x%x%x$", label .. "." .. tostring(k) .. " is #rrggbb")
    elseif type(v) == "table" then
      check_color_strings(v, label .. "." .. tostring(k))
    end
  end
end

local ok_default, default_theme = pcall(require, "themes.default")
T.ok(ok_default and type(default_theme) == "table", "themes.default loads")
T.eq(default_theme.name, "default", "default theme self-identifies")
local default_keys = all_keys(default_theme)

for _, name in ipairs(themes.list) do
  local ok, t = pcall(require, "themes." .. name)
  T.ok(ok and type(t) == "table", name .. " loads via require")
  if ok and type(t) == "table" then
    T.eq(t.name, name, name .. " name field matches registry")

    T.ok(t.background ~= nil, name .. " has background")
    T.ok(t.text ~= nil, name .. " has text")
    T.ok(t.accent ~= nil, name .. " has accent")
    T.ok(type(t.syntax) == "table", name .. " has syntax table")

    check_color_strings(t, name)

    local keys = all_keys(t)
    for key in pairs(default_keys) do
      T.ok(keys[key] ~= nil, name .. " provides key " .. key)
    end
    for key in pairs(keys) do
      T.ok(default_keys[key] ~= nil, name .. " has no extra key " .. key)
    end
  end
end

local sink = {}
T.eq(themes.apply(sink, "no-such-theme"), false, "unknown theme returns false")
T.eq(next(sink), nil, "unknown theme leaves the style table untouched")
