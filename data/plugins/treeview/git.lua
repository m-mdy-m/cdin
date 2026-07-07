local core   = require "core"
local config = require "core.config"
local style  = require "core.style"

local M = {}

-- Display codes shown in treeview (git-style)
M.ICON = {
  ["M"]  = "M",   -- modified
  ["A"]  = "A",   -- added / staged new
  ["D"]  = "D",   -- deleted
  ["R"]  = "R",   -- renamed
  ["C"]  = "C",   -- copied
  ["U"]  = "U",   -- updated but unmerged (conflict)
  ["?"]  = "??",  -- untracked
}

local STATUS_RANK = { ["U"]=6, ["M"]=5, ["A"]=4, ["D"]=3, ["R"]=2, ["C"]=2, ["?"]=1 }

M.status     = {}
M.root       = nil
M.branch     = nil    -- current branch name, "(detached)", or nil
M.has_remote = false  -- true if upstream tracking branch exists
M.ahead      = 0      -- commits ahead of remote
M.behind     = 0      -- commits behind remote
M.staged     = 0      -- count of staged changes
M.unstaged   = 0      -- count of unstaged + untracked changes
M.conflicts  = 0      -- count of conflict files
M.repo_dirty = false  -- true if any tracked file is modified/staged/untracked
M.state      = nil    -- "rebase", "merge", "cherry", "bisect", or nil

local IS_WIN = PATHSEP == "\\"

local _git_cmd = nil
local function silent_popen(cmd)
  if system.popen then
    local clean = cmd:gsub("%s*2>[^%s\"]*", "")
    return system.popen(clean)
  end
  local full_cmd
  if IS_WIN then
    full_cmd = 'cmd.exe /C "' .. cmd .. '"'
  else
    full_cmd = cmd .. " 2>/dev/null"
  end
  local ok, fp = pcall(io.popen, full_cmd)
  if not ok or not fp then return nil end
  local out = fp:read("*a")
  fp:close()
  return out
end

local function find_git_win()
  if _git_cmd ~= nil then return _git_cmd end
  local where_out = silent_popen("where.exe git")
  if where_out and where_out ~= "" then
    local preferred = where_out:match("([^\r\n]+\\cmd\\git%.exe)")
    local first     = where_out:match("([^\r\n]+)")
    local found     = preferred or first
    if found then
      found = found:gsub("^%s+", ""):gsub("%s+$", "")
      if found ~= "" then
        _git_cmd = '"' .. found .. '"'
        return _git_cmd
      end
    end
  end
  local candidates = {
    "C:\\Program Files\\Git\\cmd\\git.exe",
    "C:\\Program Files (x86)\\Git\\cmd\\git.exe",
    os.getenv("LOCALAPPDATA") and
      (os.getenv("LOCALAPPDATA") .. "\\Programs\\Git\\cmd\\git.exe"),
    os.getenv("ProgramFiles") and
      (os.getenv("ProgramFiles") .. "\\Git\\cmd\\git.exe"),
    os.getenv("USERPROFILE") and
      (os.getenv("USERPROFILE") .. "\\scoop\\apps\\git\\current\\cmd\\git.exe"),
  }
  for _, path in ipairs(candidates) do
    if path then
      local f = io.open(path, "rb")
      if f then f:close(); _git_cmd = '"' .. path .. '"'; return _git_cmd end
    end
  end
  _git_cmd = false
  return false
end

local function git_cmd()
  if not IS_WIN then return "git" end
  return find_git_win()
end

local function git_cmd_cwd()
  local gc = git_cmd()
  if not gc then return false end
  local root = system.absolute_path(".")
  if not root or root == "" then return gc end
  return gc .. ' -C "' .. root .. '"'
end

local function run_capture(cmd)
  return silent_popen(cmd)
end

local function normalize_path(p)
  if IS_WIN then
    p = p:gsub("^/(%a)/", function(d) return d:upper() .. ":\\" end)
    p = p:gsub("/", "\\")
  end
  return p
end

local function parse_porcelain_line(line)
  if #line < 4 then return nil end
  local x, y = line:sub(1,1), line:sub(2,2)
  local rest  = line:sub(4)
  if rest:sub(1,1) == '"' then rest = rest:match('^"(.-)"') or rest end
  local path = rest:match("%-> (.+)$") or rest
  if x == "!" and y == "!" then return nil end  -- ignored: skip
  return x, y, path
end

local _ignored   = {}
local _ignored_root = nil

local function refresh_ignored(root, gc)
  local null = IS_WIN and "NUL" or "/dev/null"
  local out  = run_capture(gc .. " ls-files --ignored --exclude-standard --directory 2>" .. null)
  local t    = {}
  if out then
    for line in out:gmatch("[^\r\n]+") do
      local l = line:gsub("/$", "")
      local abs = root .. PATHSEP .. normalize_path(l)
      t[abs] = true
    end
  end
  _ignored      = t
  _ignored_root = root
end

local function is_ignored(abs_path)
  if not _ignored_root then return false end
  local p = abs_path
  while p and p ~= _ignored_root do
    if _ignored[p] then return true end
    local parent = p:match("^(.+)[\\/][^\\/]+$")
    if not parent or parent == p then break end
    p = parent
  end
  return false
end

function M.refresh()
  if not config.treeview_git_enabled then
    M.status, M.root = {}, nil
    M.branch, M.has_remote = nil, false
    M.ahead, M.behind, M.staged, M.unstaged, M.conflicts = 0, 0, 0, 0, 0
    M.repo_dirty = false
    return
  end

  local gc = git_cmd_cwd()
  if not gc then
    M.status, M.root = {}, nil
    M.has_remote = false
    return
  end

  local null     = IS_WIN and "NUL" or "/dev/null"
  local toplevel = run_capture(gc .. " rev-parse --show-toplevel 2>" .. null)
  if not toplevel or toplevel == "" then
    M.status, M.root = {}, nil
    M.has_remote = false
    return
  end

  local root_raw = toplevel:gsub("[\r\n]+$", "")
  M.root         = normalize_path(root_raw)

  local branch_out = run_capture(gc .. " symbolic-ref --short HEAD 2>" .. null)
  if branch_out and branch_out:match("%S") then
    M.branch = branch_out:gsub("[%s\r\n]+$", "")
  else
    local hash = run_capture(gc .. " rev-parse --short HEAD 2>" .. null)
    M.branch = hash and ("(" .. hash:gsub("[%s\r\n]+$", "") .. ")") or nil
  end

  do
    local git_dir_out = run_capture(gc .. " rev-parse --git-dir 2>" .. null)
    local gd = git_dir_out and git_dir_out:gsub("[%s\r\n]+$", "") or ""
    if IS_WIN then gd = gd:gsub("/", "\\") end
    local function gfile(name)
      local p = gd .. PATHSEP .. name
      local f = io.open(p, "r")
      if f then f:close(); return true end
      return false
    end
    if gfile("rebase-merge") or gfile("rebase-apply") then
      M.state = "rebase"
    elseif gfile("MERGE_HEAD") then
      M.state = "merge"
    elseif gfile("CHERRY_PICK_HEAD") then
      M.state = "cherry"
    elseif gfile("BISECT_LOG") then
      M.state = "bisect"
    else
      M.state = nil
    end
  end

  M.has_remote = false
  M.ahead      = 0
  M.behind     = 0
  local upstream_out = run_capture(gc .. " rev-parse --abbrev-ref @{u} 2>" .. null)
  if upstream_out and upstream_out:match("%S") then
    M.has_remote = true
    local ab_out = run_capture(gc .. " rev-list --count --left-right @{u}...HEAD 2>" .. null)
    if ab_out then
      local beh, ahd = ab_out:match("(%d+)%s+(%d+)")
      M.behind = tonumber(beh) or 0
      M.ahead  = tonumber(ahd) or 0
    end
  end

  refresh_ignored(M.root, gc)

  local out = run_capture(gc .. " status --porcelain 2>" .. null)
  local t         = {}
  local dirty     = false
  local staged    = 0
  local unstaged  = 0
  local conflicts = 0

  if out then
    for line in out:gmatch("[^\r\n]+") do
      local x, y, path = parse_porcelain_line(line)
      if path and x then
        local abs = M.root .. PATHSEP .. normalize_path(path)

        local status
        if     x == "?" and y == "?" then status = "?"
        elseif x == "U" or  y == "U" then status = "U"
        elseif x == "R" or  y == "R" then status = "R"
        elseif x == "C" or  y == "C" then status = "C"
        elseif x == "D" or  y == "D" then status = "D"
        elseif x == "A"               then status = "A"
        else                               status = "M"
        end

        t[abs] = { index = x, worktree = y, status = status }
        dirty = true

        if x ~= " " and x ~= "?" and x ~= "U" then staged    = staged    + 1 end
        if y ~= " " and y ~= "?" and y ~= "U" then unstaged  = unstaged  + 1 end
        if status == "?" then unstaged = unstaged + 1 end
        if status == "U" then conflicts = conflicts + 1 end
      end
    end
  end

  M.status     = t
  M.repo_dirty = dirty
  M.staged     = staged
  M.unstaged   = unstaged
  M.conflicts  = conflicts
  core.redraw  = true
end

function M.thread()
  while true do
    core.try(M.refresh)
    coroutine.yield(config.treeview_git_update_rate or 4)
  end
end

function M.get_status(item)
  if not item or not item.abs_filename then return nil end
  if not M.root then return nil end
  if is_ignored(item.abs_filename) then return nil end

  if item.type == "file" then
    local entry = M.status[item.abs_filename]
    return entry and entry.status or nil
  end

  local best, best_rank = nil, 0
  local dir_prefix = item.abs_filename .. PATHSEP
  for abs, entry in pairs(M.status) do
    if abs:sub(1, #dir_prefix) == dir_prefix then
      if not is_ignored(abs) then
        local rank = STATUS_RANK[entry.status] or 0
        if rank > best_rank then best, best_rank = entry.status, rank end
      end
    end
  end
  return best
end

function M.get_entry(item)
  if not item or not item.abs_filename then return nil end
  if not M.root then return nil end
  return M.status[item.abs_filename]
end

function M.get_color(status)
  if status == "D" or status == "U" then
    return style.titlebar_close_hover
  elseif status == "?" then
    return style.dim
  else
    return style.accent
  end
end

return M