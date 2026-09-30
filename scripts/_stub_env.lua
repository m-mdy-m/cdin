-- A pure-Lua stand-in for the parts of the cdin runtime that normally come
-- from C, so the data layer can be exercised under a plain `lua` with no
-- build and no editor.
--
-- The C host (see src/api/api.c) registers:
--   globals  system, renderer, search
--   preload  fs, path
-- plus the boot globals in src/lua/api.c. This file provides the same
-- surface, backed by shell calls instead of libc, and says so at every
-- point where it is approximate.
--
-- Used by scripts/test_lua.lua and scripts/test_commands.lua. Nothing in
-- data/ may require it: the editor never loads this file.
--
-- shell-out is deliberate. The alternative is a Lua filesystem binding, and
-- the editor deliberately has none — its only dependency is what src/ links.

local M = {}

local SEP   = package.config:sub(1, 1)
local IS_WIN = SEP == "\\"

-- ── shell helpers ──────────────────────────────────────────────────────────

local function run(cmd)
  local p = io.popen(cmd)
  if not p then return nil end
  local out = p:read("*a")
  p:close()
  return out
end

local function lines_of(out)
  local result = {}
  if not out then return result end
  for line in out:gmatch("[^\r\n]+") do
    result[#result + 1] = line
  end
  return result
end

local function stat_cache() return M._stat_cache end

-- stat is called once per directory entry by core.fs.list, so the results are
-- memoised. The cache is per-process and the fixture trees are small and
-- fixed, so nothing is ever stale within a run.
M._stat_cache = {}

-- ── path (port of src/fs/path.c) ───────────────────────────────────────────

local path = {}
path.sep = SEP

local function is_sep(c) return c == "/" or c == "\\" end

function path.join(...)
  local n = select("#", ...)
  local out = {}
  for i = 1, n do
    local s = tostring(select(i, ...))
    if i < n then
      while #s > 1 and is_sep(s:sub(-1)) do s = s:sub(1, -2) end
    end
    if i > 1 and #s > 0 and not is_sep(s:sub(1, 1)) then
      out[#out + 1] = SEP
    end
    out[#out + 1] = s
  end
  return table.concat(out)
end

local function last_sep(s)
  for i = #s, 1, -1 do
    if is_sep(s:sub(i, i)) then return i end
  end
  return nil
end

function path.basename(p)
  p = tostring(p)
  while #p > 1 and is_sep(p:sub(-1)) do p = p:sub(1, -2) end
  local sep = last_sep(p)
  if not sep then return p end
  return p:sub(sep + 1)
end

function path.dirname(p)
  p = tostring(p)
  while #p > 1 and is_sep(p:sub(-1)) do p = p:sub(1, -2) end
  local sep = last_sep(p)
  if not sep then return "." end
  if sep == 1 then return p:sub(1, 1) end
  return p:sub(1, sep)
end

function path.ext(p)
  p = tostring(p)
  for i = #p, 1, -1 do
    local c = p:sub(i, i)
    if is_sep(c) then break end
    if c == "." and i > 1 and not is_sep(p:sub(i - 1, i - 1)) then
      return p:sub(i)
    end
  end
  return ""
end

function path.stem(p)
  p = tostring(p)
  local base_start = 1
  for i = #p, 1, -1 do
    if is_sep(p:sub(i, i)) then base_start = i + 1 break end
  end
  local dot
  for i = #p, base_start + 1, -1 do
    if p:sub(i, i) == "." then dot = i break end
  end
  if not dot then return p:sub(base_start) end
  return p:sub(base_start, dot - 1)
end

function path.split(p) return path.dirname(p), path.basename(p) end

function path.is_absolute(p)
  p = tostring(p)
  if not IS_WIN then return p:sub(1, 1) == "/" end
  if #p >= 3 and p:sub(2, 2) == ":" and is_sep(p:sub(3, 3)) then return true end
  return is_sep(p:sub(1, 1))
end

function path.absolute(p)
  p = tostring(p)
  if path.is_absolute(p) then return path.normalize(p) end
  local cwd = run(IS_WIN and "cd" or "pwd")
  if not cwd then return nil end
  return path.normalize(path.join((cwd:gsub("[\r\n]", "")), p))
end

-- Mirrors f_normalize in src/fs/path.c, including the "//" UNC prefix.
function path.normalize(p)
  p = tostring(p)
  local out, i = {}, 1
  local leading = 0
  while i <= #p and is_sep(p:sub(i, i)) do i = i + 1; leading = leading + 1 end

  if leading > 0 then
    out[#out + 1] = SEP
    if IS_WIN and leading >= 2 then out[#out + 1] = SEP end
  end

  while i <= #p do
    local j = i
    while j <= #p and not is_sep(p:sub(j, j)) do j = j + 1 end
    local comp = p:sub(i, j - 1)
    if comp == "" or comp == "." then
      -- skip
    elseif comp == ".." then
      if #out > 0 then table.remove(out) end
    else
      if #out > 0 and not is_sep(out[#out]:sub(-1)) then out[#out + 1] = SEP end
      out[#out + 1] = comp
    end
    i = j + 1
  end

  if #out == 0 then return leading > 0 and SEP or "." end
  return table.concat(out)
end

-- ── fs (port of src/fs/ops.c) ──────────────────────────────────────────────

-- File size without a shell out: seek to the end of the handle. A directory
-- has no handle, so it reports 0 the way the C stub's S_ISDIR branch would.
local function size_of(p, kind)
  if kind == "D" then return 0 end
  local f = io.open(p, "rb")
  if not f then return 0 end
  local n = f:seek("end")
  f:close()
  return n or 0
end

local function stat_raw(p)
  local hit = stat_cache()[p]
  if hit ~= nil then
    if hit == false then return nil, "no such file" end
    return hit
  end

  local kind
  if IS_WIN then
    local q = tostring(p):gsub("'", "''")
    local cmd = "powershell -NoProfile -Command \""
      .. "$ErrorActionPreference='SilentlyContinue';$p='" .. q .. "';"
      .. "if (Test-Path -LiteralPath $p -PathType Container) {'D'}"
      .. " elseif (Test-Path -LiteralPath $p -PathType Leaf) {'F'}"
      .. " else {'-'}\" 2>nul"
    local out = run(cmd) or ""
    kind = (out:gsub("%s", ""))
    if kind ~= "D" and kind ~= "F" then
      stat_cache()[p] = false
      return nil, "no such file or directory"
    end
  else
    -- `test -X p; echo $?` is one shell built-in plus one echo, and gives a
    -- definite answer for a missing path as well as an existing one.
    if run('test -d "' .. p .. '" 2>/dev/null; echo $?') == "0\n" then
      kind = "D"
    elseif run('test -f "' .. p .. '" 2>/dev/null; echo $?') == "0\n" then
      kind = "F"
    end
    if not kind then
      stat_cache()[p] = false
      return nil, "no such file or directory"
    end
  end

  local info = { type = kind == "D" and "dir" or "file", size = size_of(p, kind), mtime = 0 }
  stat_cache()[p] = info
  return info
end

local fs = {}

function fs.stat(p)
  local info, err = stat_raw(p)
  if not info then return nil, err end
  return { type = info.type, size = info.size, mtime = info.mtime }
end

-- One shell call per directory, and it reports each entry's type as well as
-- its name. core.fs.list() stats every entry it gets back, so priming the
-- cache here is what keeps a listing at one spawn instead of N+1.
local function list_typed(p)
  local names = {}
  if IS_WIN then
    local q = p:gsub("'", "''")
    local cmd = 'powershell -NoProfile -Command "'
      .. '$ErrorActionPreference=\'SilentlyContinue\';'
      .. 'Get-ChildItem -LiteralPath \'' .. q .. '\' -Force'
      .. ' | ForEach-Object { if ($_.PSIsContainer) {\'D\'} else {\'F\'}; $_.Name }" 2>nul'
    local out = run(cmd)
    if not out or out:match("is not recognized") or out:match("Cannot find") then
      return nil
    end
    local pending
    for _, line in ipairs(lines_of(out)) do
      if line == "D" or line == "F" then
        pending = line
      elseif pending then
        names[#names + 1] = { name = line, kind = pending }
        pending = nil
      end
    end
  else
    local out = run('ls -A "' .. p .. '" 2>/dev/null')
    if not out then return nil end
    for _, name in ipairs(lines_of(out)) do
      local kind = run('test -d "' .. p .. "/" .. name .. '" 2>/dev/null; echo $?') == "0\n"
        and "D" or "F"
      names[#names + 1] = { name = name, kind = kind }
    end
  end
  return names
end

function fs.list_dir(p)
  p = tostring(p)
  local listed = list_typed(p)
  if not listed then
    if stat_raw(p) then return {} end
    return nil, "cannot read directory: " .. p
  end

  local names = {}
  for _, entry in ipairs(listed) do
    local full = path.join(p, entry.name)
    stat_cache()[full] = {
      type = entry.kind == "D" and "dir" or "file",
      size = size_of(full, entry.kind),
      mtime = 0,
    }
    names[#names + 1] = entry.name
  end
  return names
end

function fs.remove_all(p)
  p = tostring(p)
  if not stat_raw(p) then return nil, "no such file: " .. p end
  -- Purge the whole subtree: a cached child of a removed directory would
  -- otherwise keep reporting as present, which is exactly the stale-state
  -- bug a build-time cache has to avoid.
  local prefix = p .. path.sep
  for key in pairs(stat_cache()) do
    if key == p or key:sub(1, #prefix) == prefix then stat_cache()[key] = false end
  end
  local cmd = IS_WIN
    and ('cmd /c rmdir /s /q "' .. p:gsub("/", "\\") .. '" 2>nul')
    or ('rm -rf "' .. p .. '"')
  run(cmd)
  if stat_raw(p) then return nil, "remove_all: " .. p end
  return true
end

function fs.mkdir_all(p)
  p = tostring(p)
  stat_cache()[p] = nil
  local cmd = IS_WIN and ('mkdir "' .. p:gsub("/", "\\") .. '" 2>nul') or ('mkdir -p "' .. p .. '"')
  run(cmd)
  if stat_raw(p) then return true end
  return nil, "mkdir_all: " .. p
end

function fs.copy_all(src, dst)
  local ok = run(IS_WIN
    and ('cmd /c xcopy /e /i /y /q "' .. tostring(src):gsub("/", "\\") .. '" "' .. tostring(dst):gsub("/", "\\") .. '" >nul')
    or ('cp -r "' .. tostring(src) .. '" "' .. tostring(dst) .. '"'))
  if ok == nil then return nil, "copy_all: " .. tostring(src) end
  return true
end

-- ── system (the global from src/api/system.c) ─────────────────────────────

local system = {}

function system.get_file_info(p)
  local info = fs.stat(p)
  if not info then return nil end
  return { type = info.type, size = info.size, mtime = info.mtime, readonly = false }
end

function system.absolute_path(p) return path.absolute(p) end
function system.chdir(p)  return os.execute('cd "' .. tostring(p) .. '"') end
function system.pwd()     return path.normalize((run("cd") or "."):gsub("[\r\n]", "")) end
function system.list_dir(p) return fs.list_dir(p) or {} end
function system.get_time()  return os.time() end
function system.get_clipboard() return "" end
function system.set_clipboard() end
function system.set_window_mode() end
function system.exec() return true end
function system.request_exit() end
function system.set_title() end
function system.open_url() end

-- ── renderer (the global from src/api/renderer_compat.c) ──────────────────

local function fake_font()
  return { add_fallback = function() end, width = function() return 0 end }
end

local renderer = {
  font = { load = function() return fake_font() end },
  measure_text = function() return 0 end,
  begin = function() end,
  ["end"] = function() end,
  clear = function() end,
  present = function() end,
  set_draw_color = function() end,
  draw_rect = function() end,
  draw_text = function() end,
  get_size = function() return 0, 0 end,
  set_cursor = function() end,
  get_size_px = function() return 0, 0 end,
  push_clip_rect = function() end,
  pop_clip_rect = function() end,
  translate = function() end,
  get_scale = function() return 1 end,
}

-- ── boot globals (src/lua/api.c) ───────────────────────────────────────────

M.SEP   = SEP
M.IS_WIN = IS_WIN

M.fake_font = fake_font

-- Installs every stub.
--
-- exedir is the directory the runtime resolves EXEDIR/data/plugins and
-- EXEDIR/data/themes against — in the tests, a fixture tree. src, when
-- given, is the checkout whose data/ holds the core modules. Both roots end
-- up on package.path in that order, so the core always resolves from src
-- while a fixture theme resolves from the fixture tree, exactly as a real
-- install resolves core and themes from the same data/ directory.
function M.install(opts)
  opts = opts or {}

  package.preload["fs"]   = function() return fs end
  package.preload["path"] = function() return path end

  local g = {
    SCALE    = 1,
    VERSION  = "0.0.0-test",
    PLATFORM = IS_WIN and "Windows" or "Linux",
    EXEDIR   = opts.exedir or ".",
    EXEFILE  = (opts.exedir or ".") .. "/cdin",
    ARGS     = {},
    PATHSEP  = SEP,
    system   = system,
    renderer = renderer,
    search   = { find = function() return {} end },
  }
  for k, v in pairs(g) do rawset(_G, k, v) end

  if opts.src then
    package.path = opts.src .. "/data/?.lua;"
                 .. opts.src .. "/data/?/init.lua;"
                 .. package.path
  end
  package.path = g.EXEDIR .. "/data/?.lua;"
               .. g.EXEDIR .. "/data/?/init.lua;"
               .. package.path

  return g
end

-- Reads a file, creating nothing. Used by the test scripts to snapshot
-- package.path before the loader mutates it.
function M.package_path()
  return package.path
end

M.fs   = fs
M.path = path

return M
