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
    last_check   = tonumber(ts) or 0,
    skip_version = skip,
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

local tmp_file = EXEDIR .. "/autoupdate.tmp"

local function fetch_latest_tag_async()
  local url = "https://api.github.com/repos/m-mdy-m/cdin/releases/latest"
  local out  = tmp_file
  local cmd
  os.remove(out)

  if IS_WIN then
    cmd = string.format(
      'powershell -NoProfile -NonInteractive -Command ' ..
      '"try{$r=(Invoke-WebRequest -Uri \'%s\' -UseBasicParsing).Content;' ..
      '$t=[regex]::Match($r,\'\\\"tag_name\\\"\\s*:\\s*\\\"([^\\\"]+)\\\"\').Groups[1].Value;' ..
      '$t=$t -replace \'\\^v\',\'\';' ..
      'Set-Content -Path \'%s\' -Value $t}catch{}"',
      url, out)
  else
    cmd = string.format(
      'curl -sf --max-time 10 ' ..
      '-H "Accept: application/vnd.github.v3+json" ' ..
      '-H "User-Agent: cdin-autoupdate" ' ..
      '"%s" | grep -o \'"tag_name":"[^"]*"\' | grep -o \'[0-9][^"]*\' > "%s"',
      url, out)
  end

  system.exec(cmd)
end

local function await_tag(timeout)
  timeout = timeout or 15
  local deadline = system.get_time() + timeout
  while system.get_time() < deadline do
    coroutine.yield(0.5)   -- yield for 0.5s, keep editor responsive
    local f = io.open(tmp_file, "r")
    if f then
      local raw = f:read("*a"); f:close()
      os.remove(tmp_file)
      raw = raw:match("^%s*(.-)%s*$")  -- trim whitespace/newlines
      if raw and raw ~= "" then return raw end
      return nil  -- file appeared but empty → network error
    end
  end
  return nil  -- timed out
end

local badge_dismissed = false

local function notify_update_available(latest)
  core.log("cdin %s available — run :update or press <leader>U to upgrade.", latest)

  local StatusView = require "core.views.statusview"
  local orig_get   = StatusView.get_items

  StatusView.get_items = function(self)
    local left, right = orig_get(self)
    if badge_dismissed then
      StatusView.get_items = orig_get  -- restore once dismissed
    else
      table.insert(right, 1, style.text)
      table.insert(right, 2, string.format(" \xe2\x86\x91 v%s available ", latest))
      table.insert(right, 3, style.dim)
    end
    return left, right
  end
end

local function run_update()
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

local function async_check(on_start)
  fetch_latest_tag_async()
  if on_start then core.log("Checking for updates…") end
  local latest = await_tag(15)
  if not latest then
    if not on_start then core.log("autoupdate: could not reach GitHub.") end
    return
  end
  local current = (VERSION or "0.0.0"):match("(%d+%.%d+%.%d+[%-%w%.]*)") or "0.0.0"
  local st = read_state()
  if st.skip_version and st.skip_version == latest then return end
  if version_gt(latest, current) then
    notify_update_available(latest)
  else
    if not on_start then
      core.log("cdin is up to date (v%s).", current)
    end
  end
end

local function start_check_thread()
  core.add_thread(function()
    coroutine.yield(5)  -- let the editor finish loading first

    if not config.autoupdate_check then return end

    local st  = read_state()
    local now = os.time()
    if (now - (st.last_check or 0)) < config.autoupdate_interval then return end

    st.last_check = now
    write_state(st)

    async_check(true)
  end)
end

command.add(nil, {
  ["autoupdate:check"] = function()
    core.log("Checking for updates…")
    core.add_thread(function()
      async_check(false)
    end)
  end,

  ["autoupdate:run-update"] = function()
    badge_dismissed = true
    run_update()
  end,

  ["autoupdate:skip-version"] = function()
    core.add_thread(function()
      fetch_latest_tag_async()
      local latest = await_tag(15)
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