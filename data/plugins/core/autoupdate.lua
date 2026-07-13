local core    = require "core"
local command = require "core.input.command"
local keymap  = require "core.input.keymap"
local config  = require "core.config"
local style   = require "core.style"

config.autoupdate_check    = (config.autoupdate_check    == nil) and true  or config.autoupdate_check
config.autoupdate_interval = (config.autoupdate_interval == nil) and 86400 or config.autoupdate_interval

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

local function state_path()
  return EXEDIR .. "/autoupdate.state"
end

local function read_state()
  local f = io.open(state_path(), "r")
  if not f then return {} end
  local raw = f:read("*a"); f:close()
  local ts   = raw:match("last_check=(%d+%.?%d*)")
  local skip = raw:match("skip_version=([%d%.%-]+)")
  return {
    last_check    = tonumber(ts) or 0,
    skip_version  = skip,
  }
end

local function write_state(st)
  local f = io.open(state_path(), "w")
  if not f then return end
  f:write(string.format("last_check=%.0f\n", st.last_check or 0))
  if st.skip_version then
    f:write(string.format("skip_version=%s\n", st.skip_version))
  end
  f:close()
end

local IS_WIN = PATHSEP == "\\"

local function fetch_latest_tag()
  local url  = "https://api.github.com/repos/m-mdy-m/cdin/releases/latest"
  local hdr  = '-H "Accept: application/vnd.github.v3+json" -H "User-Agent: cdin-autoupdate"'
  local cmd

  if IS_WIN then
    cmd = string.format(
      'powershell -NoProfile -Command "(Invoke-WebRequest -Uri \'%s\' -UseBasicParsing).Content"',
      url)
  else
    -- prefer curl, fall back to wget
    if os.execute("command -v curl >/dev/null 2>&1") == 0 then
      cmd = string.format("curl -s --max-time 10 %s %q", hdr, url)
    else
      cmd = string.format("wget -qO- --timeout=10 %q", url)
    end
  end

  -- system.popen is our non-blocking bridge
  local raw
  if system.popen then
    raw = system.popen(cmd)
  else
    local ok, fp = pcall(io.popen, cmd)
    if ok and fp then raw = fp:read("*a"); fp:close() end
  end

  if not raw or raw == "" then return nil end
  local tag = raw:match('"tag_name"%s*:%s*"([^"]+)"')
  return tag and tag:gsub("^v", "")
end

local function notify_update_available(latest)
  -- The status bar shows a transient message; we piggy-back on core.log so the
  -- message also appears in the log view (accessible via core:open-log).
  core.log("cdin %s available — run :update or press <leader>U to upgrade.", latest)

  -- Persist a longer-lived visual hint: override status bar items.
  -- We inject a right-side item that stays until the editor is restarted or
  -- the user dismisses it.
  local StatusView = require "core.views.statusview"
  local orig_get   = StatusView.get_items

  local shown = false
  StatusView.get_items = function(self)
    local left, right = orig_get(self)
    if not shown then
      -- prepend update badge to the right side
      table.insert(right, 1, style.text)
      table.insert(right, 2, string.format(" ↑ v%s available ", latest))
      table.insert(right, 3, style.dim)
    end
    return left, right
  end

  -- Mark as "shown" after the user triggers :update so the badge disappears.
  local orig_update = command.get("autoupdate:run-update")
  if orig_update then
    local orig_fn = orig_update.perform
    orig_update.perform = function(...)
      shown = true
      StatusView.get_items = orig_get   -- restore
      if orig_fn then orig_fn(...) end
    end
  end
end

local function run_update()
  -- The Python update script handles everything: download, verify, replace binary.
  -- We launch it detached so cdin stays alive; user restarts manually afterward.
  local scripts_dir = EXEDIR .. "/scripts"
  local py_script   = scripts_dir .. "/cdin.py"
  local cmd

  if IS_WIN then
    cmd = string.format('start "" /B python "%s" update --force', py_script)
  else
    cmd = string.format("python3 %q update --force &", py_script)
  end

  system.exec(cmd)
  core.log("Update launched in background. Restart cdin when it finishes.")
end

local function start_check_thread()
  core.add_thread(function()
    -- Delay first check so the editor fully starts before we hit the network.
    coroutine.yield(5)

    if not config.autoupdate_check then return end

    local st = read_state()
    local now = os.time()

    -- Skip if we checked recently
    if (now - (st.last_check or 0)) < config.autoupdate_interval then
      return
    end

    -- Update timestamp immediately so parallel instances don't double-fetch
    st.last_check = now
    write_state(st)

    local latest = fetch_latest_tag()
    if not latest then return end  -- network unavailable — silent fail

    local current = (VERSION or "0.0.0"):match("(%d+%.%d+%.%d+[%-%w%.]*)") or "0.0.0"

    if st.skip_version and st.skip_version == latest then
      return  -- user asked to skip this version
    end

    if version_gt(latest, current) then
      notify_update_available(latest)
    end
  end)
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
        notify_update_available(latest)
      else
        core.log("cdin is up to date (v%s).", current)
      end
    end)
  end,

  ["autoupdate:run-update"] = function()
    run_update()
  end,

  ["autoupdate:skip-version"] = function()
    -- Fetches latest tag and records it as "skip", silencing future nags.
    core.add_thread(function()
      local latest = fetch_latest_tag()
      if not latest then return end
      local st = read_state()
      st.skip_version = latest
      write_state(st)
      core.log("autoupdate: will skip v%s.", latest)
    end)
  end,
})

keymap.add {
  ["ctrl+shift+u"] = "autoupdate:check",
}

start_check_thread()