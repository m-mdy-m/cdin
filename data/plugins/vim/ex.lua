local core    = require "core"
local command = require "core.input.command"
local common  = require "core.utils.common"
local Doc     = require "core.doc"
local fs      = require "core.fs"
local shell   = require "plugins.vim.shell"

local M = {}


local HISTORY_MAX = 100
M.history = {}

local function history_push(text)
  if M.history[#M.history] == text then return end
  table.insert(M.history, text)
  if #M.history > HISTORY_MAX then
    table.remove(M.history, 1)
  end
end

local function tokenize(s)
  local tokens = {}
  local i = 1
  while i <= #s do
    while i <= #s and s:sub(i,i):match("%s") do i = i + 1 end
    if i > #s then break end
    local ch = s:sub(i,i)
    if ch == '"' or ch == "'" then
      local q = ch
      i = i + 1
      local start = i
      while i <= #s and s:sub(i,i) ~= q do
        if s:sub(i,i) == "\\" then i = i + 1 end 
        i = i + 1
      end
      tokens[#tokens+1] = s:sub(start, i-1)
      i = i + 1 
    else
      local start = i
      while i <= #s and not s:sub(i,i):match("%s") do i = i + 1 end
      tokens[#tokens+1] = s:sub(start, i-1)
    end
  end
  return tokens
end




local function save_all()
  for _, doc in ipairs(core.docs) do
    if doc.filename and doc:is_dirty() then
      doc:save()
    end
  end
end

local function force_close_active_view()
  local root = core.root_view.root_node
  local node = core.root_view:get_active_node()
  if #node.views > 1 then
    local idx = node:get_view_idx(node.active_view)
    table.remove(node.views, idx)
    node:set_active_view(node.views[idx] or node.views[#node.views])
  else
    local parent = node:get_parent_node(root)
    local is_a   = (parent.a == node)
    local other  = parent[is_a and "b" or "a"]
    if other:get_locked_size() then
      node.views = {}
      local View = require "core.views.view"
      node:add_view(View())
    else
      parent:consume(other)
      local p = parent
      while p.type ~= "leaf" do p = p[is_a and "a" or "b"] end
      p:set_active_view(p.active_view)
    end
  end
  core.last_active_view = nil
end

-- Open a file in the editor. Creates it if `create` is true.
local function open_file(path, create)
  if not fs.exists(path) then
    if create then
      local ok, err = fs.touch(path)
      if not ok then core.error("ex: %s", err); return end
    else
      core.error("ex: no such file: %s", path)
      return
    end
  end
  core.try(function()
    core.root_view:open_doc(core.open_doc(path))
  end)
end

local function show_ls(path)
  path = path or "."
  local entries, err = fs.ls(path)
  if not entries then core.error("ex: %s", err); return end

  local lines = { ("-- ls %s\n"):format(fs.pwd() .. PATHSEP .. path) }
  for _, e in ipairs(entries) do
    local marker = e.type == "dir" and "/" or ""
    local size   = e.type == "file"
      and ("  [%d bytes]"):format(e.size)
      or ""
    lines[#lines+1] = e.name .. marker .. size
  end
  lines[#lines+1] = ""

  local doc = Doc()
  doc:text_input(table.concat(lines, "\n"))
  doc:set_selection(1,1)
  function doc:get_name() return "ls " .. path end
  core.root_view:open_doc(doc)
end

local HELP_TEXT = [[
-- cdin vimode ex-commands help
-- ─────────────────────────────────────────────────────────────
--  File commands
--    :w              save current file
--    :w!             force-save (same as :w in cdin)
--    :wa             save all open files
--    :q              close current view (fails if unsaved)
--    :q!             force-close without saving
--    :qa / :qall     quit (fails if unsaved files)
--    :qa! / :qall!   force quit
--    :wq / :x        save then close
--    :wqa / :xa      save all then quit
--
--  Open / create
--    :e <path>       open file (error if not found)
--    :edit <path>    alias for :e
--    :new <path>     create + open a new file
--
--  Filesystem
--    :mkdir <path>   create directory (parents included)
--    :rm <path>      remove file or directory tree
--    :delete <path>  alias for :rm
--    :rename <old> <new>
--    :copy <src> <dst>
--    :move <src> <dst>
--
--  Navigation
--    :ls [path]      list directory contents in a buffer
--    :pwd            print working directory
--    :cd <path>      change working directory
--    :tree           focus / toggle the project tree panel
--    :<number>       go to line number
--
--  Shell
--    :!<cmd>         run shell command; output in a new buffer
--                    examples:  :!ls -la   :!git status   :!npm test
--
--    :help           show this help
-- ─────────────────────────────────────────────────────────────
]]

local function show_help()
  local doc = Doc()
  doc:text_input(HELP_TEXT)
  doc:set_selection(1,1)
  function doc:get_name() return ":help" end
  core.root_view:open_doc(doc)
end


-- Shared window-command map: used by both :wincmd here and Ctrl+W in vimode
M.WMAP = {
  h = "window:focus-left",  j = "window:focus-down",
  k = "window:focus-up",    l = "window:focus-right",
  w = "window:focus-next",  W = "window:focus-prev",
  p = "window:focus-prev-window",
  t = "window:focus-first", b = "window:focus-last",
  s = "window:split",       v = "window:vsplit",
  c = "window:close",       o = "window:only",
  n = "window:new",         N = "window:vnew",
  ["+"] = "window:increase-height",
  ["-"] = "window:decrease-height",
  [">"] = "window:increase-width",
  ["<"] = "window:decrease-width",
  ["="] = "window:equalize",
  ["|"] = "window:maximize-width",
  ["_"] = "window:maximize-height",
}

function M.submit(raw)
  local text = raw:gsub("^%s+",""):gsub("%s+$","")
  if text == "" then return end
  if text:sub(1,1) == ":" then text = text:sub(2) end
  if text == "" then return end

  if text:sub(1,1) == "!" then
    local cmd = text:sub(2):gsub("^%s+","")
    if cmd == "" then
      core.error("ex: empty shell command")
      return
    end
    history_push("!" .. cmd)
    shell.run_in_buffer(cmd)
    return
  end

  history_push(text)

  local tokens = tokenize(text)
  local cmd    = tokens[1] or ""
  local arg1   = tokens[2]
  local arg2   = tokens[3]

  if cmd == "w" or cmd == "w!" then
    command.perform("doc:save")

  elseif cmd == "wa" or cmd == "wa!" then
    save_all()

  elseif cmd == "q" then
    command.perform("root:close")

  elseif cmd == "q!" then
    force_close_active_view()

  elseif cmd == "qa" or cmd == "qall" then
    core.quit(false)

  elseif cmd == "qa!" or cmd == "qall!" then
    core.quit(true)

  elseif cmd == "wq" or cmd == "x" then
    command.perform("doc:save")
    command.perform("root:close")

  elseif cmd == "wqa" or cmd == "wqall" or cmd == "xa" then
    save_all(); core.quit(false)

  elseif cmd == "wqa!" or cmd == "wqall!" then
    save_all(); core.quit(true)

  elseif cmd == "e" or cmd == "edit" then
    if not arg1 then core.error("ex: :e requires a path"); return end
    open_file(arg1, false)

  elseif cmd == "new" then
    if not arg1 then core.error("ex: :new requires a path"); return end
    open_file(arg1, true)

  elseif cmd == "mkdir" then
    if not arg1 then core.error("ex: :mkdir requires a path"); return end
    local ok, err = fs.mkdir(arg1)
    if ok then
      core.log("mkdir: created '%s'", arg1)
    else
      core.error("ex: %s", err)
    end

  elseif cmd == "rm" or cmd == "delete" then
    if not arg1 then core.error("ex: :rm requires a path"); return end
    local ok, err = fs.rm(arg1)
    if ok then
      core.log("rm: removed '%s'", arg1)
    else
      core.error("ex: %s", err)
    end

  elseif cmd == "rename" then
    if not arg1 or not arg2 then
      core.error("ex: :rename <old> <new>")
      return
    end
    local ok, err = fs.rename(arg1, arg2)
    if ok then
      local abs_old = system.absolute_path(arg1)
      for _, doc in ipairs(core.docs) do
        if doc.filename and system.absolute_path(doc.filename) == abs_old then
          doc.filename = arg2
        end
      end
      core.log("rename: '%s' → '%s'", arg1, arg2)
    else
      core.error("ex: %s", err)
    end

  elseif cmd == "copy" then
    if not arg1 or not arg2 then
      core.error("ex: :copy <src> <dst>")
      return
    end
    local ok, err = fs.copy(arg1, arg2)
    if ok then
      core.log("copy: '%s' → '%s'", arg1, arg2)
    else
      core.error("ex: %s", err)
    end

  elseif cmd == "move" then
    if not arg1 or not arg2 then
      core.error("ex: :move <src> <dst>")
      return
    end
    local ok, err = fs.move(arg1, arg2)
    if ok then
      local abs_src = system.absolute_path(arg1)
      for _, doc in ipairs(core.docs) do
        if doc.filename and system.absolute_path(doc.filename) == abs_src then
          doc.filename = arg2
        end
      end
      core.log("move: '%s' → '%s'", arg1, arg2)
    else
      core.error("ex: %s", err)
    end

  elseif cmd == "ls" then
    show_ls(arg1)

  elseif cmd == "pwd" then
    core.log(fs.pwd())

  elseif cmd == "cd" then
    if not arg1 then core.error("ex: :cd requires a path"); return end
    local ok, err = fs.cd(arg1)
    if ok then
      core.log("cd: %s", fs.pwd())
      local project = require "core.project"
      project.request_rescan(core)
      command.perform("treeview:refresh")
    else
      core.error("ex: %s", err)
    end

  elseif cmd == "tree" then
    command.perform("treeview:focus-and-refresh")

  -- ── Tab commands ────────────────────────────────────────
  elseif cmd == "tabnew" or cmd == "tabe" or cmd == "tabedit" then
    command.perform("tab:new")
    if arg1 then open_file(arg1, false) end

  elseif cmd == "tabclose" or cmd == "tabc" then
    command.perform("tab:close")

  elseif cmd == "tabonly" or cmd == "tabo" then
    command.perform("tab:close-others")

  elseif cmd == "tabnext" or cmd == "tabn" then
    if arg1 then
      local ok, tabM = pcall(require, "plugins.tab.manager")
      if ok then tabM.go_to(tonumber(arg1) or 1) end
    else
      command.perform("tab:next")
    end

  elseif cmd == "tabprevious" or cmd == "tabp" or cmd == "tabNext" then
    command.perform("tab:prev")

  elseif cmd == "tabfirst" or cmd == "tabr" or cmd == "tabrew" then
    command.perform("tab:first")

  elseif cmd == "tablast" then
    command.perform("tab:last")

  elseif cmd == "tabmove" or cmd == "tabm" then
    if arg1 then
      local ok, tabM = pcall(require, "plugins.tab.manager")
      if ok then
        local n = tonumber(arg1)
        if n then tabM.move(tabM.active_id, n + 1) end
      end
    end

  -- ── Window commands ───────────────────────────────────────────────────────
  elseif cmd == "split" or cmd == "sp" then
    command.perform("window:split")
    if arg1 then open_file(arg1, false) end

  elseif cmd == "vsplit" or cmd == "vs" then
    command.perform("window:vsplit")
    if arg1 then open_file(arg1, false) end

  elseif cmd == "vnew" then
    command.perform("window:vnew")
    if arg1 then open_file(arg1, true) end

  elseif cmd == "close" or cmd == "clo" then
    command.perform("window:close")

  elseif cmd == "only" or cmd == "on" then
    command.perform("window:only")

  -- :wincmd {char}
  elseif cmd == "wincmd" or cmd == "winc" then
    local char = arg1 or ""
    local wcmd = M.WMAP[char]
    if wcmd then command.perform(wcmd)
    else core.error("ex: unknown :wincmd %q", char) end

  elseif cmd == "help" or cmd == "h" then
    show_help()

  elseif text:match("^%d+$") then
    local view = core.active_docview()
    if view then
      local line = tonumber(text)
      view.doc:set_selection(line, 1)
      view:scroll_to_line(line, false, true)
    end

  else
    core.error('vim: unknown command ":%s"', text)
  end
end

function M.suggest(text)
  if text:sub(1,1) == ":" then text = text:sub(2) end

  local FILE_CMDS = {
    e=true, edit=true, new=true,
    mkdir=true, rm=true, delete=true,
    rename=true, copy=true, move=true, cd=true,
  }

  local tokens = tokenize(text)
  local cmd    = tokens[1] or ""
  if FILE_CMDS[cmd] and #tokens >= 2 then
    local partial = tokens[#tokens]
    return common.path_suggest(partial)
  end
  if #tokens <= 1 then
    local ALL_CMDS = {
      "w","wa","q","q!","qa","qa!","wq","x","wqa",
      "e","edit","new",
      "mkdir","rm","delete","rename","copy","move",
      "ls","pwd","cd","tree","help",
      "tabnew","tabe","tabclose","tabonly","tabnext","tabprevious",
      "tabfirst","tablast","tabmove",
      "split","vsplit","vnew","close","only","wincmd",
    }
    local results = {}
    for _, c in ipairs(ALL_CMDS) do
      if c:sub(1, #cmd) == cmd then
        results[#results+1] = { text = c }
      end
    end
    return results
  end

  return {}
end

return M