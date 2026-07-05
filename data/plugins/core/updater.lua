local core    = require "core"
local config  = require "core.config"
local command = require "core.input.command"
local shell   = require "plugins.vim.shell"
local Doc     = require "core.doc"

if config.updater_auto_check    == nil then config.updater_auto_check    = false end
if config.updater_check_interval == nil then config.updater_check_interval = 86400 end -- 24h
local IS_WIN = PATHSEP == "\\"

local function find_update_script()
  local script = IS_WIN
    and (EXEDIR .. PATHSEP .. "scripts" .. PATHSEP .. "update.bat")
    or  (EXEDIR .. PATHSEP .. "scripts" .. PATHSEP .. "update.sh")

  local info = system.get_file_info(script)
  if info then return script end
  script = IS_WIN
    and (EXEDIR .. PATHSEP .. "update.bat")
    or  (EXEDIR .. PATHSEP .. "update.sh")
  info = system.get_file_info(script)
  if info then return script end

  return nil
end
local function run_update(flags)
  flags = flags or ""

  if IS_WIN then
    -- Windows: PowerShell script
    local ps_script = EXEDIR .. PATHSEP .. "scripts" .. PATHSEP .. "install.ps1"
    local info = system.get_file_info(ps_script)
    if info then
      local cmd = 'powershell -NoProfile -ExecutionPolicy Bypass -File '
                .. shell.shell_quote(ps_script) .. ' ' .. flags
      shell.run_in_buffer(cmd)
      return
    end
    core.error("updater: update.bat / install.ps1 not found next to cdin binary")
    return
  end

  -- Linux/macOS
  local script = find_update_script()
  if not script then
    core.log("updater: update script not found — running via curl")
    local cmd = 'curl -fsSL https://raw.githubusercontent.com/m-mdy-m/cdin/main/scripts/update.sh | bash -s -- ' .. flags
    shell.run_in_buffer(cmd)
    return
  end

  local cmd = 'bash ' .. shell.shell_quote(script) .. ' ' .. flags
  shell.run_in_buffer(cmd)
end
local function check_update_silent(callback)
  local cmd = 'curl -fsSL -H "Accept: application/vnd.github.v3+json" '
            .. '"https://api.github.com/repos/m-mdy-m/cdin/releases/latest" '
            .. '2>/dev/null | grep \'"tag_name"\' | grep -oE \'v?[0-9]+\\.[0-9]+\\.[0-9]+\' | head -1'

  if IS_WIN then
    cmd = 'powershell -NoProfile -NonInteractive -Command '
        .. '"(Invoke-RestMethod https://api.github.com/repos/m-mdy-m/cdin/releases/latest).tag_name"'
  end

  local out, err = shell.capture(cmd)
  if err or not out or out == "" then
    if callback then callback(nil, "Could not reach GitHub") end
    return
  end

  local latest = out:match("[0-9]+%.[0-9]+%.[0-9]+")
  local current = (CDIN_VERSION or ""):match("[0-9]+%.[0-9]+%.[0-9]+")
  if callback then callback(latest, nil, current) end
end
local function last_check_path()
  if IS_WIN then
    local base = os.getenv("APPDATA") or os.getenv("USERPROFILE") or "."
    return base .. "\\cdin\\last_update_check"
  else
    local base = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
    return base .. "/cdin/last_update_check"
  end
end

local function should_check()
  local path = last_check_path()
  local fp = io.open(path, "r")
  if not fp then return true end
  local ts = tonumber(fp:read("*l") or "") or 0
  fp:close()
  return (os.time() - ts) >= config.updater_check_interval
end

local function mark_checked()
  local path = last_check_path()
  local dir = path:match("^(.+)[\\/][^\\/]+$")
  if dir then
    if IS_WIN then os.execute('mkdir "' .. dir .. '" 2>nul')
    else           os.execute('mkdir -p "' .. dir .. '"') end
  end
  local fp = io.open(path, "w")
  if fp then fp:write(tostring(os.time()) .. "\n"); fp:close() end
end
if config.updater_auto_check then
  core.add_thread(function()
    coroutine.yield(5) 
    if not should_check() then return end
    mark_checked()
    check_update_silent(function(latest, err, current)
      if err or not latest then return end
      if latest ~= current and latest ~= "" then
        core.log("updater: new version available — v%s (current: v%s). Run :update to upgrade.", latest, current or "?")
      end
    end)
  end)
end

command.add(nil, {
  ["core:update"] = function()
    run_update("--force")
  end,
  ["core:update-interactive"] = function()
    run_update("")
  end,
  ["core:check-update"] = function()
    core.log("updater: checking for updates...")
    check_update_silent(function(latest, err, current)
      if err then
        core.error("updater: %s", err)
        return
      end
      if not latest then
        core.error("updater: could not parse version")
        return
      end
      local cur = current or (CDIN_VERSION or "?"):match("[0-9]+%.[0-9]+%.[0-9]+") or "?"
      if latest == cur then
        core.log("updater: already up to date (v%s)", latest)
      else
        core.log("updater: update available! v%s → v%s. Run :update to upgrade.", cur, latest)
      end
    end)
  end,
})
local ok, ex = pcall(require, "plugins.vim.ex")
if ok and ex and ex.register then
  ex.register("update", function(args)
    local flags = table.concat(args, " ")
    run_update(flags)
  end, {
    complete = function()
      return { "--check", "--force", "--version=" }
    end,
    help = "update cdin to latest version",
  })

  ex.register("check-update", function()
    command.perform("core:check-update")
  end, {
    help = "check if a new version of cdin is available",
  })
end
