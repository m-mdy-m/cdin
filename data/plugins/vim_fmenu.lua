-- File-manager context menu for vimode, triggered by pressing `m`

local core    = require "core"
local command = require "core.command"
local common  = require "core.common"
local keymap  = require "core.keymap"
local fs      = require "plugins.vim_fs"

local M = {}

local function refresh_tree()
  command.perform("treeview:refresh")
end

local function context_path()
  local DocView    = require "core.docview"
  local CommandView = require "core.commandview"
  local av = core.active_view
  if av and av:is(DocView) and not av:is(CommandView) then
    local doc = av.doc
    if doc and doc.filename then
      local dir = doc.filename:match("^(.*)[\\/][^\\/]+$") or "."
      return dir, doc.filename
    end
  end
  return ".", nil
end

local function dirname(p)
  return p:match("^(.*)[\\/][^\\/]+$") or "."
end
local function build_menu(dir, file)
  return {
    { label = "n  new file",          action = function() M.new_file(dir)       end },
    { label = "d  new directory",     action = function() M.new_dir(dir)        end },
    { label = "r  rename",            action = function() M.rename_item(file or dir) end },
    { label = "c  copy",              action = function() M.copy_item(file or dir)   end },
    { label = "m  move",              action = function() M.move_item(file or dir)   end },
    { label = "x  delete",            action = function() M.delete_item(file or dir) end },
    { label = "o  open file",         action = function() M.open_file_prompt(dir)    end },
    { label = "p  pwd / current dir", action = function() core.log(fs.pwd())         end },
    { label = "R  refresh tree",      action = function() refresh_tree()             end },
  }
end

function M.open()
  local dir, file = context_path()
  local menu = build_menu(dir, file)

  local items = {}
  for _, entry in ipairs(menu) do
    items[#items+1] = { text = entry.label, _action = entry.action }
  end

  core.command_view:enter("File menu", function(text, item)
    if item and item._action then
      item._action()
    else
      local t = text:gsub("^%s+","")
      for _, entry in ipairs(menu) do
        if entry.label:sub(1,1) == t:sub(1,1) then
          entry.action()
          return
        end
      end
      core.error("vim-fmenu: unknown option '%s'", text)
    end
  end, function(_)
    return items
  end)
end


function M.new_file(dir)
  core.command_view:enter("New file name", function(name)
    if name == "" then return end
    local path = (dir ~= "." and dir .. PATHSEP or "") .. name
    local ok, err = fs.touch(path)
    if not ok then core.error("fmenu: %s", err); return end
    refresh_tree()
    core.try(function()
      core.root_view:open_doc(core.open_doc(path))
    end)
  end, function(partial)
    return common.path_suggest((dir ~= "." and dir .. PATHSEP or "") .. partial)
  end)
end

function M.new_dir(dir)
  core.command_view:enter("New directory name", function(name)
    if name == "" then return end
    local path = (dir ~= "." and dir .. PATHSEP or "") .. name
    local ok, err = fs.mkdir(path)
    if not ok then core.error("fmenu: %s", err); return end
    core.log("fmenu: created directory '%s'", path)
    refresh_tree()
  end, function(partial)
    return common.path_suggest((dir ~= "." and dir .. PATHSEP or "") .. partial)
  end)
end

function M.rename_item(path)
  if not path or not fs.exists(path) then
    core.error("fmenu: nothing selected to rename")
    return
  end
  local old_name = path:match("[^\\/]+$") or path
  core.command_view:enter("Rename to", function(new_name)
    if new_name == "" or new_name == old_name then return end
    local new_path = dirname(path) ~= "." and (dirname(path) .. PATHSEP .. new_name) or new_name
    local ok, err = fs.rename(path, new_path)
    if not ok then core.error("fmenu: %s", err); return end
    local abs_old = system.absolute_path(path)
    for _, doc in ipairs(core.docs) do
      if doc.filename and system.absolute_path(doc.filename) == abs_old then
        doc.filename = new_path
      end
    end
    core.log("fmenu: renamed to '%s'", new_path)
    refresh_tree()
  end, function() return {} end)
  core.command_view:set_text(old_name, true)
end

function M.copy_item(path)
  if not path or not fs.exists(path) then
    core.error("fmenu: nothing selected to copy")
    return
  end
  core.command_view:enter("Copy to", function(dst)
    if dst == "" then return end
    local ok, err = fs.copy(path, dst)
    if ok then
      core.log("fmenu: copied to '%s'", dst)
      refresh_tree()
    else
      core.error("fmenu: %s", err)
    end
  end, function(partial)
    return common.path_suggest(partial)
  end)
end

function M.move_item(path)
  if not path or not fs.exists(path) then
    core.error("fmenu: nothing selected to move")
    return
  end
  core.command_view:enter("Move to", function(dst)
    if dst == "" then return end
    local ok, err = fs.move(path, dst)
    if ok then
      local abs_src = system.absolute_path(path)
      for _, doc in ipairs(core.docs) do
        if doc.filename and system.absolute_path(doc.filename) == abs_src then
          doc.filename = dst
        end
      end
      core.log("fmenu: moved to '%s'", dst)
      refresh_tree()
    else
      core.error("fmenu: %s", err)
    end
  end, function(partial)
    return common.path_suggest(partial)
  end)
end

function M.delete_item(path)
  if not path or not fs.exists(path) then
    core.error("fmenu: nothing selected to delete")
    return
  end
  local name = path:match("[^\\/]+$") or path
  core.command_view:enter(
    ("Delete '%s'? type 'yes' to confirm"):format(name),
    function(answer)
      if answer:lower() ~= "yes" and answer:lower() ~= "y" then
        core.log("fmenu: delete cancelled")
        return
      end
      local ok, err = fs.rm(path)
      if ok then
        core.log("fmenu: deleted '%s'", path)
        refresh_tree()
      else
        core.error("fmenu: %s", err)
      end
    end,
    function() return {} end
  )
end

function M.open_file_prompt(dir)
  core.command_view:enter("Open file", function(path)
    if path == "" then return end
    if not fs.exists(path) then
      core.error("fmenu: no such file: %s", path)
      return
    end
    core.try(function()
      core.root_view:open_doc(core.open_doc(path))
    end)
  end, function(partial)
    return common.path_suggest(
      (dir ~= "." and dir ~= nil) and (dir .. PATHSEP .. partial) or partial)
  end)
end


command.add(nil, {
  ["vim-fmenu:open"]       = function() M.open() end,
  ["vim-fmenu:new-file"]   = function()
    local dir, _ = context_path(); M.new_file(dir) end,
  ["vim-fmenu:new-dir"]    = function()
    local dir, _ = context_path(); M.new_dir(dir) end,
  ["vim-fmenu:rename"]     = function()
    local _, file = context_path(); M.rename_item(file) end,
  ["vim-fmenu:delete"]     = function()
    local _, file = context_path(); M.delete_item(file) end,
})

return M