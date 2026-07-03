-- vim_fmenu.lua — file operations menu for the vim plugins.
--
-- Structure:
--   1. Path helpers   : context_path() resolves the item under the cursor
--   2. File actions   : new/rename/copy/move/delete/open/cd prompts
--   3. File menu      : open()  — bound to "m" in normal mode
--   4. Commands       : vim-fmenu:*
--
-- Git and shell actions live in the shell menu (vim_shell.lua, key "s").

local core    = require "core"
local command = require "core.command"
local common  = require "core.common"
local fs      = require "plugins.vim_fs"
local menu    = require "plugins.vim_menu_engine"

local M = {}

-- 1. Path helpers ────────────────────────────────────────────────────────────

local function refresh_tree()
  command.perform("treeview:refresh")
end

local function dirname(p)
  return p:match("^(.*)[\\/][^\\/]+$") or "."
end

local function basename(p)
  return p:match("[^\\/]+$") or p
end

-- Returns: dir, file (or nil), is_dir — for the treeview cursor item,
-- else the active doc, else the CWD.
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
    local item = tv.cursor_item
    local path = item.abs_filename or item.filename or "."
    if item.type == "dir" then
      return path, nil, true
    else
      return dirname(path), path, false
    end
  end

  local DocView     = require "core.docview"
  local CommandView = require "core.commandview"
  local av = core.active_view
  if av and av:is(DocView) and not av:is(CommandView) then
    local doc = av.doc
    if doc and doc.filename then
      return dirname(doc.filename), doc.filename, false
    end
  end

  return fs.pwd(), nil, true
end

-- Runs `fn(path)` immediately if `path` is valid, otherwise prompts for one.
local function with_path(prompt, path, start_dir, fn)
  if path and fs.exists(path) then
    fn(path)
    return
  end
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

-- 2. File actions ────────────────────────────────────────────────────────────

function M.new_file(dir)
  local base = (dir and dir ~= ".") and (dir .. PATHSEP) or ""
  core.command_view:enter("New file name", function(name)
    if name == "" then return end
    local path = base .. name
    local ok, err = fs.touch(path)
    if not ok then core.error("fmenu: %s", err); return end
    refresh_tree()
    core.try(function() core.root_view:open_doc(core.open_doc(path)) end)
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
        local d = dirname(src)
        local new_path = (d ~= ".") and (d .. PATHSEP .. new_name) or new_name
        local ok, err = fs.rename(src, new_path)
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
    local src_name = basename(src)
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
      { text = "y", info = "yes, delete " .. kind .. " '" .. name .. "'" },
      { text = "n", info = "cancel" },
    }

    core.command_view:enter(
      ("Delete %s '%s'?"):format(kind, name),
      function(answer, item)
        local a = (item and item.text) or answer
        a = a:lower():match("^%s*(.-)%s*$")
        if a ~= "y" and a ~= "yes" then
          core.log("fmenu: delete cancelled")
          return
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
          if it.text:find(t, 1, true) then res[#res + 1] = it end
        end
        return res
      end
    )
  end)
end

function M.open_file_prompt(dir)
  local base = (dir and dir ~= ".") and (dir .. PATHSEP) or ""
  core.command_view:enter("Open file", function(path)
    if path == "" then return end
    if not fs.exists(path) then
      core.error("fmenu: no such file: %s", path)
      return
    end
    core.try(function() core.root_view:open_doc(core.open_doc(path)) end)
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

function M.cd_up(dir)
  local parent = dirname(dir)
  local ok, err = fs.cd(parent)
  if ok then
    core.log("fmenu: cd %s", fs.pwd())
    command.perform("treeview:focus-and-refresh")
  else
    core.error("fmenu: %s", err)
  end
end

-- 3. File menu ───────────────────────────────────────────────────────────────

function M.open()
  local dir, file, is_dir = context_path()
  local target       = file or (is_dir and dir) or nil
  local target_label = (target and basename(target)) or "?"
  local dir_label    = basename(dir) ~= "" and basename(dir) or dir

  local ctx_name = (file and basename(file)) or dir_label or "."
  local ctx_type = is_dir and "[dir] " or "[file] "

  menu.open {
    name  = "fmenu",
    title = "File Menu  " .. ctx_type .. ctx_name .. "  (key or Tab)",
    entries = {
      -- Creation ─────────────────────────────────────────────────────────────
      { key = "n", label = " New File",
        info = "in " .. dir_label,
        action = function() M.new_file(dir) end },

      { key = "d", label = " New Directory",
        info = "mkdir -p",
        action = function() M.new_dir(dir) end },

      -- Navigation ───────────────────────────────────────────────────────────
      { key = "o", label = " Open File",
        info = "browse & open",
        action = function() M.open_file_prompt(dir) end },

      { key = "f", label = " Change Directory",
        info = "cd …",
        action = function() M.cd_prompt(dir) end },

      { key = "u", label = " Up One Directory",
        info = "cd ..",
        action = function() M.cd_up(dir) end },

      { key = ".", label = " Reveal in Tree",
        info = dir_label,
        action = function()
          command.perform("treeview:focus-and-refresh")
          core.log("fmenu: reveal %s", dir)
        end },

      -- File operations ──────────────────────────────────────────────────────
      { key = "r", label = " Rename",
        info = target_label,
        action = function() M.rename_item(target, dir) end },

      { key = "c", label = " Copy",
        info = target_label,
        action = function() M.copy_item(target, dir) end },

      { key = "v", label = " Move",
        info = target_label,
        action = function() M.move_item(target, dir) end },

      { key = "x", label = " Delete",
        info = target_label,
        action = function() M.delete_item(target, dir) end },

      -- Tree / view ──────────────────────────────────────────────────────────
      { key = "R", label = " Refresh Tree",
        info = "re-scan",
        action = function()
          refresh_tree()
          core.log("fmenu: tree refreshed")
        end },

      { key = "p", label = " Print CWD",
        info = "log path",
        action = function() core.log(fs.pwd()) end },

      { key = "s", label = " Search",
        info = "project search",
        action = function() command.perform("project-search:find") end },
    },
  }
end

-- 4. Commands ────────────────────────────────────────────────────────────────

command.add(nil, {
  ["vim-fmenu:open"]     = function() M.open() end,

  ["vim-fmenu:new-file"] = function()
    local dir = context_path(); M.new_file(dir) end,

  ["vim-fmenu:new-dir"]  = function()
    local dir = context_path(); M.new_dir(dir) end,

  ["vim-fmenu:rename"]   = function()
    local dir, file = context_path(); M.rename_item(file, dir) end,

  ["vim-fmenu:copy"]     = function()
    local dir, file = context_path(); M.copy_item(file, dir) end,

  ["vim-fmenu:move"]     = function()
    local dir, file = context_path(); M.move_item(file, dir) end,

  ["vim-fmenu:delete"]   = function()
    local dir, file = context_path(); M.delete_item(file, dir) end,

  ["vim-fmenu:refresh"]  = function()
    refresh_tree(); core.log("fmenu: tree refreshed") end,

  ["vim-fmenu:pwd"]      = function() core.log(fs.pwd()) end,

  ["vim-fmenu:cd-up"]    = function()
    local dir = context_path(); M.cd_up(dir) end,
})

return M
