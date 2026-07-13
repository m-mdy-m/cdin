local core    = require "core"
local command = require "core.input.command"
local keymap  = require "core.input.keymap"
local config  = require "core.config"
local style   = require "core.style"

local IS_WIN = PATHSEP == "\\"

local function version_parts(v)
  local t = {}
  for n in (v or ""):gmatch("%d+") do t[#t+1] = tonumber(n) end
  return t
end

local function version_gt(a, b)
  local pa, pb = version_parts(a), version_parts(b)
  for i = 1, math.max(#pa, #pb) do
    local x, y = pa[i] or 0, pb[i] or 0
    if x ~= y then return x > y end
  end
  return false
end

-- Fetch latest tag from GitHub. Blocks briefly — only called on manual check.
local function fetch_latest_tag()
  local url = "https://api.github.com/repos/m-mdy-m/cdin/releases/latest"
  local raw

  if IS_WIN then
    local cmd = string.format(
      "powershell -NoProfile -NonInteractive -Command " ..
      "\"(Invoke-WebRequest -Uri '%s' -UseBasicParsing).Content\"",
      url)
    local ok, fp = pcall(io.popen, cmd)
    if ok and fp then raw = fp:read("*a"); fp:close() end
  else
    local cmd = string.format(
      "curl -sf --max-time 10 " ..
      "-H 'Accept: application/vnd.github.v3+json' " ..
      "-H 'User-Agent: cdin-autoupdate' '%s'",
      url)
    local ok, fp = pcall(io.popen, cmd)
    if ok and fp then raw = fp:read("*a"); fp:close() end
  end

  if not raw or raw == "" then return nil end
  -- Extract tag_name value, strip leading "v"
  local tag = raw:match('"tag_name"%s*:%s*"v?([^"]+)"')
  return tag
end

local badge_dismissed = false

local function show_badge(latest)
  local StatusView = require "core.views.statusview"
  local orig       = StatusView.get_items

  StatusView.get_items = function(self)
    local left, right = orig(self)
    if badge_dismissed then
      StatusView.get_items = orig
    else
      table.insert(right, 1, style.text)
      table.insert(right, 2, string.format(" \xe2\x86\x91 v%s available ", latest))
      table.insert(right, 3, style.dim)
    end
    return left, right
  end
end

command.add(nil, {
  ["autoupdate:check"] = function()
    core.log("Checking for updates…")
    core.add_thread(function()
      local latest = fetch_latest_tag()
      if not latest then
        core.log("autoupdate: could not reach GitHub.")
        return
      end
      local current = (VERSION or "0.0.0"):match("(%d+%.%d+%.%d+[%-%w%.]*)") or "0.0.0"
      if version_gt(latest, current) then
        core.log(
          "cdin v%s is available! https://github.com/m-mdy-m/cdin/releases/tag/v%s",
          latest, latest)
        show_badge(latest)
      else
        core.log("cdin is up to date (v%s).", current)
      end
    end)
  end,

  ["autoupdate:skip-version"] = function()
    badge_dismissed = true
    core.log("autoupdate: update badge dismissed.")
  end,
})

keymap.add {
  ["ctrl+shift+u"] = "autoupdate:check",
}