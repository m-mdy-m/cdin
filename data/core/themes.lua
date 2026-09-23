-- Theme registry: name -> module. Add a file here and it appears
-- in `core:change-theme` automatically.
local themes = {}

themes.list = {
  "default",
  "dracula",
  "nord",
  "solarized-dark",
  "solarized-light",
  "monokai",
  "github-light",
  "gruvbox-dark",
  "tokyo-night",
  "catppuccin-mocha",
}

function themes.names()
  local out = {}
  for _, n in ipairs(themes.list) do out[#out + 1] = n end
  return out
end

function themes.apply(style, name)
  local common = require "core.utils.common"
  local ok, t = pcall(require, "themes." .. tostring(name))
  if not ok or type(t) ~= "table" then return false end
  local function col(v, fallback)
    if type(v) == "string" then return { common.color(v) } end
    if type(v) == "table" then return v end
    return fallback
  end
  for k, v in pairs(t) do
    if k ~= "name" and k ~= "syntax" then
      style[k] = col(v, style[k])
    end
  end
  if type(t.syntax) == "table" then
    style.syntax = style.syntax or {}
    for k, v in pairs(t.syntax) do
      style.syntax[k] = col(v, style.syntax[k])
    end
  end
  style.theme_name = t.name or name
  return true
end

return themes