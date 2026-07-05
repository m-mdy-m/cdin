local core    = require "core"
local command = require "core.input.command"
local common  = require "core.utils.common"
local fs      = require "plugins.vim.fs"
local engine  = require "plugins.vim.menu_engine"

local M = {}

local function refresh_tree()
  command.perform("treeview:refresh")
end

local function dirname(p)
  return p:match("^(.*)[\\/][^\\/]+$") or "."
end

local function basename(p)
  return p:match("[^\\/]+$") or p
end

local function context_path()
  local function walk(node)
    if not node then return nil end
    for _, view in ipairs(node.views or {}) do
      if view.cursor_item ~= nil and type(view.each_item) == "function" then
        return view
      end
    end
    return walk(node.a) or walk(node.b)
  end

  local tv = core.root_view and walk(core.root_view.root_node)
  if tv and tv.cursor_item then
    local item  = tv.cursor_item
    local path  = item.abs_filename or item.filename or "."
    local is_d  = (item.type == "dir")
    if is_d then
      return path, nil, true
    else
      return dirname(path), path, false
    end
  end

  local DocView     = require "core.views.docview"
  local CommandView = require "core.views.commandview"
  local av = core.active_view
  if av and av:is(DocView) and not av:is(CommandView) then
    local doc = av.doc
    if doc and doc.filename then
      return dirname(doc.filename), doc.filename, false
    end
  end

  return fs.pwd(), nil, true
end

local function with_path(prompt, path, start_dir, fn)
  if path and fs.exists(path) then fn(path); return end
  local base = (start_dir and start_dir ~= ".") and (start_dir .. PATHSEP) or ""
  core.command_view:enter(prompt, function(chosen)
    if chosen == "" then return end
    if not fs.exists(chosen) then
      core.error("fmenu: no such file or directory: %s", chosen)
      return
    end
    fn(chosen)
  end, function(partial)
    return common.path_suggest(base .. partial)
  end)
end

local function sh()
  return require "plugins.vim.shell"
end

local function build_entries(dir, file, is_dir)
  local target       = file or (is_dir and dir) or nil
  local target_label = (target and basename(target)) or "?"
  local dir_label    = (basename(dir) ~= "" and basename(dir)) or dir

  return {

    {
      header  = "Files  [" .. dir_label .. "]",
      entries = {
        { key="n", icon="", label="New File",
          info = "in " .. dir_label,
          action = function() M.new_file(dir) end },

        { key="N", icon="", label="New Directory",
          info = "mkdir -p",
          action = function() M.new_dir(dir) end },

        { key="o", icon="", label="Open File",
          info = "browse & open",
          action = function() M.open_file_prompt(dir) end },

        { key="r", icon="", label="Rename",
          info = target_label,
          action = function() M.rename_item(target, dir) end },

        { key="y", icon="", label="Copy",
          info = target_label,
          action = function() M.copy_item(target, dir) end },

        { key="v", icon="", label="Move",
          info = target_label,
          action = function() M.move_item(target, dir) end },

        { key="x", icon="", label="Delete",
          info = target_label,
          action = function() M.delete_item(target, dir) end },
      },
    },
    {
      header  = "Navigate",
      entries = {
        { key="f", icon="", label="Change Directory",
          info = "cd …",
          action = function() M.cd_prompt(dir) end },

        { key="u", icon="", label="Up One Level",
          info = "cd ..",
          action = function()
            local parent = dirname(dir)
            local ok, err = fs.cd(parent)
            if ok then
              core.log("fmenu: cd %s", fs.pwd())
              command.perform("treeview:focus-and-refresh")
            else
              core.error("fmenu: %s", err)
            end
          end },

        { key=".", icon="", label="Reveal in Tree",
          info = dir_label,
          action = function()
            command.perform("treeview:focus-and-refresh")
            core.log("fmenu: reveal %s", dir)
          end },

        { key="R", icon="", label="Refresh Tree",
          info = "re-scan",
          action = function()
            refresh_tree(); core.log("fmenu: tree refreshed")
          end },

        { key="/", icon="", label="Project Search",
          info = "ripgrep / find",
          action = function() command.perform("project-search:find") end },
      },
    },

    {
      header  = "Git",
      entries = {
        { key="s", icon="", label="Status",
          info = "git status",
          action = function() sh().run_in_buffer("git status") end },

        { key="l", icon="", label="Log",
          info = "--oneline -20",
          action = function() sh().run_in_buffer("git log --oneline -20") end },

        { key="d", icon="", label="Diff",
          info = "git diff",
          action = function() sh().run_in_buffer("git diff") end },

        { key="a", icon="", label="Add All",
          info = "git add .",
          action = function() sh().run_in_buffer("git add .") end },

        { key="c", icon="", label="Commit",
          info = "interactive",
          action = function()
            core.command_view:enter("Commit message", function(msg)
              if msg == "" then core.error("fmenu: empty commit message"); return end
              sh().run_in_buffer('git commit -m "' .. msg:gsub('"', '\\"') .. '"')
            end, function() return {} end)
          end },

        { key="P", icon="", label="Push",
          info = "git push",
          action = function() sh().run_in_buffer("git push") end },

        { key="p", icon="", label="Pull",
          info = "git pull",
          action = function() sh().run_in_buffer("git pull") end },

        { key="b", icon="", label="Branches",
          info = "git branch -a",
          action = function() sh().run_in_buffer("git branch -a") end },
      },
    },

    {
      header  = "Build",
      entries = {
        { key="m", icon="", label="Make",
          info = "make",
          action = function() sh().run_in_buffer("make") end },

        { key="t", icon="", label="Run Tests",
          info = "make test",
          action = function() sh().run_in_buffer("make test") end },
      },
    },

    {
      header  = "Shell",
      entries = {
        { key="!", icon="", label="Custom Command",
          info = "type any shell cmd",
          action = function() sh().prompt_and_run() end },

        { key="w", icon="", label="Working Directory",
          info = "pwd",
          action = function() sh().run_in_buffer("pwd") end },

        { key="e", icon="", label="Environment",
          info = "env",
          action = function() sh().run_in_buffer("env") end },

        { key="i", icon="", label="Network Info",
          info = "ip addr / ifconfig",
          action = function()
            local out = sh().capture("ip addr 2>/dev/null || ifconfig 2>/dev/null")
            if not out or out == "" then
              out = sh().capture("ipconfig 2>nul") or "no output"
            end
            local doc = require("core.doc")()
            doc:text_input("-- network info\n\n" .. out)
            doc:set_selection(1, 1)
            function doc:get_name() return ":net" end
            core.root_view:open_doc(doc)
          end },
      },
    },
  }
end

function M.open()
  local dir, file, is_dir = context_path()

  local ctx_name = (file and basename(file))
               or  (dir  and basename(dir))
               or  "."
  local ctx_icon = is_dir and "" or ""

  engine.open({
    title   = "Menu",
    context = ctx_icon .. " " .. ctx_name,
    entries = build_entries(dir, file, is_dir),
  })
end

function M.new_file(dir)
  local base = (dir and dir ~= ".") and (dir .. PATHSEP) or ""
  core.command_view:enter("New file name", function(name)
    if name == "" then return end
    local path = base .. name
    local ok, err = fs.touch(path)
    if not ok then core.error("fmenu: %s", err); return end
    refresh_tree()
    core.try(function()
      local doc = core.open_doc(path)
      core.root_view:open_doc(doc)
    end)
  end, function(partial)
    return common.path_suggest(base .. partial)
  end)
end

function M.new_dir(dir)
  local base = (dir and dir ~= ".") and (dir .. PATHSEP) or ""
  core.command_view:enter("New directory name", function(name)
    if name == "" then return end
    local path = base .. name
    local ok, err = fs.mkdir(path)
    if not ok then core.error("fmenu: %s", err); return end
    core.log("fmenu: created '%s'", path)
    refresh_tree()
  end, function(partial)
    return common.path_suggest(base .. partial)
  end)
end

function M.rename_item(path, dir)
  with_path("Rename — select target", path, dir, function(src)
    local old_name = basename(src)
    core.command_view:enter(
      "Rename '" .. old_name .. "' to",
      function(new_name)
        new_name = new_name:match("^%s*(.-)%s*$")
        if new_name == "" or new_name == old_name then return end
        local d        = dirname(src)
        local new_path = (d ~= ".") and (d .. PATHSEP .. new_name) or new_name
        local ok, err  = fs.rename(src, new_path)
        if not ok then core.error("fmenu: %s", err); return end
        local abs_old = system.absolute_path(src)
        for _, doc in ipairs(core.docs) do
          if doc.filename and system.absolute_path(doc.filename) == abs_old then
            doc.filename = new_path
          end
        end
        core.log("fmenu: renamed '%s' → '%s'", old_name, new_name)
        refresh_tree()
      end,
      function() return {} end
    )
    core.command_view:set_text(old_name, true)
  end)
end

function M.copy_item(path, dir)
  with_path("Copy — select source", path, dir, function(src)
    local src_name   = basename(src)
    local default_dst = dirname(src) .. PATHSEP .. src_name .. "_copy"
    core.command_view:enter(
      "Copy '" .. src_name .. "' to",
      function(dst)
        dst = dst:match("^%s*(.-)%s*$")
        if dst == "" then return end
        local ok, err = fs.copy(src, dst)
        if ok then
          core.log("fmenu: copied '%s' → '%s'", src_name, dst)
          refresh_tree()
        else
          core.error("fmenu: %s", err)
        end
      end,
      function(partial) return common.path_suggest(partial) end
    )
    core.command_view:set_text(default_dst)
  end)
end

function M.move_item(path, dir)
  with_path("Move — select source", path, dir, function(src)
    local src_name = basename(src)
    core.command_view:enter(
      "Move '" .. src_name .. "' to",
      function(dst)
        dst = dst:match("^%s*(.-)%s*$")
        if dst == "" then return end
        local ok, err = fs.move(src, dst)
        if ok then
          local abs_src = system.absolute_path(src)
          for _, doc in ipairs(core.docs) do
            if doc.filename and system.absolute_path(doc.filename) == abs_src then
              doc.filename = dst
            end
          end
          core.log("fmenu: moved '%s' → '%s'", src_name, dst)
          refresh_tree()
        else
          core.error("fmenu: %s", err)
        end
      end,
      function(partial) return common.path_suggest(partial) end
    )
    local same_dir = dirname(src)
    if same_dir ~= "." then
      core.command_view:set_text(same_dir .. PATHSEP)
    end
  end)
end

function M.delete_item(path, dir)
  with_path("Delete — select target", path, dir, function(target)
    local name = basename(target)
    local kind = fs.is_dir(target) and "directory" or "file"

    local confirm_items = {
      { text = "y", info = "yes — delete " .. kind .. " '" .. name .. "'" },
      { text = "n", info = "cancel" },
    }

    core.command_view:enter(
      ("Delete %s '%s'? [y/n]"):format(kind, name),
      function(answer, item)
        local a = (item and item.text) or answer
        a = a:lower():match("^%s*(.-)%s*$")
        if a ~= "y" and a ~= "yes" then
          core.log("fmenu: delete cancelled"); return
        end
        local ok, err = fs.rm(target)
        if ok then
          core.log("fmenu: deleted '%s'", target)
          refresh_tree()
        else
          core.error("fmenu: %s", err)
        end
      end,
      function(text)
        local t = text:lower():match("^%s*(.-)%s*$")
        if t == "" then return confirm_items end
        local res = {}
        for _, it in ipairs(confirm_items) do
          if it.text:find(t, 1, true) then res[#res+1] = it end
        end
        return res
      end
    )
  end)
end

function M.open_file_prompt(dir)
  local base = (dir and dir ~= "." and dir ~= nil) and (dir .. PATHSEP) or ""
  core.command_view:enter("Open file", function(path)
    if path == "" then return end
    if not fs.exists(path) then
      core.error("fmenu: no such file: %s", path); return
    end
    core.try(function()
      local doc = core.open_doc(path)
      core.root_view:open_doc(doc)
    end)
  end, function(partial)
    return common.path_suggest(base .. partial)
  end)
end

function M.cd_prompt(dir)
  core.command_view:enter("Change directory to", function(path)
    if path == "" then return end
    local ok, err = fs.cd(path)
    if ok then
      core.log("fmenu: cd %s", fs.pwd())
      command.perform("treeview:focus-and-refresh")
    else
      core.error("fmenu: %s", err)
    end
  end, function(partial)
    return common.path_suggest(partial)
  end)
  if dir and dir ~= "." then
    core.command_view:set_text(dir)
  end
end

command.add(nil, {
  ["vim-fmenu:open"]        = function() M.open() end,

  -- file ops
  ["vim-fmenu:new-file"]    = function() local d = context_path(); M.new_file(d) end,
  ["vim-fmenu:new-dir"]     = function() local d = context_path(); M.new_dir(d) end,
  ["vim-fmenu:rename"]      = function() local d, f = context_path(); M.rename_item(f, d) end,
  ["vim-fmenu:copy"]        = function() local d, f = context_path(); M.copy_item(f, d) end,
  ["vim-fmenu:move"]        = function() local d, f = context_path(); M.move_item(f, d) end,
  ["vim-fmenu:delete"]      = function() local d, f = context_path(); M.delete_item(f, d) end,

  -- nav
  ["vim-fmenu:refresh"]     = function() refresh_tree(); core.log("fmenu: refreshed") end,
  ["vim-fmenu:pwd"]         = function() core.log(fs.pwd()) end,
  ["vim-fmenu:cd-up"]       = function()
    local dir    = context_path()
    local parent = dirname(dir)
    local ok, err = fs.cd(parent)
    if ok then
      core.log("fmenu: cd %s", fs.pwd())
      command.perform("treeview:focus-and-refresh")
    else
      core.error("fmenu: %s", err)
    end
  end,

  -- git shortcuts
  ["vim-fmenu:git-status"]  = function() sh().run_in_buffer("git status") end,
  ["vim-fmenu:git-log"]     = function() sh().run_in_buffer("git log --oneline -20") end,
  ["vim-fmenu:git-add-all"] = function() sh().run_in_buffer("git add .") end,
  ["vim-fmenu:git-diff"]    = function() sh().run_in_buffer("git diff") end,
})

return M