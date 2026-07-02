local core    = require "core"
local config  = require "core.config"
local command = require "core.command"
local keymap  = require "core.keymap"
local DocView = require "core.docview"
local CommandView = require "core.commandview"

if config.vim_mode_enabled == nil then
  config.vim_mode_enabled = true
end

local MODE_NORMAL = "normal"
local MODE_INSERT = "insert"
local MODE_VISUAL = "visual"

local PENDING_TIMEOUT = 0.6

local pending = nil

local function active_docview()
  local view = core.active_view
  if view and view:is(DocView) and not view:is(CommandView) then
    return view
  end
  return nil
end

local function get_mode(view)
  return view.vim_mode or MODE_NORMAL
end

local function set_mode(view, mode)
  view.vim_mode = mode
  core.redraw = true
end


-- ── motion table ──────────────────────────────────────────────────────────
-- Each entry: { normal_cmd, visual_cmd }
local MOTIONS = {
  h = { "doc:move-to-previous-char",       "doc:select-to-previous-char" },
  l = { "doc:move-to-next-char",           "doc:select-to-next-char" },
  j = { "doc:move-to-next-line",           "doc:select-to-next-line" },
  k = { "doc:move-to-previous-line",       "doc:select-to-previous-line" },
  w = { "doc:move-to-next-word-end",       "doc:select-to-next-word-end" },
  b = { "doc:move-to-previous-word-start", "doc:select-to-previous-word-start" },
}


-- ── ex-command handler ────────────────────────────────────────────────────

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
    local is_a = (parent.a == node)
    local other = parent[is_a and "b" or "a"]
    if other:get_locked_size() then
      node.views = {}
      local EmptyView = require "core.view"
      node:add_view(EmptyView())
    else
      parent:consume(other)
      local p = parent
      while p.type ~= "leaf" do
        p = p[is_a and "a" or "b"]
      end
      p:set_active_view(p.active_view)
    end
  end
  core.last_active_view = nil
end

local function submit_ex_command(text)
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return end

  if     text == "w"                              then command.perform("doc:save")
  elseif text == "wa" or text == "wa!"            then save_all()
  elseif text == "q"                              then command.perform("root:close")
  elseif text == "q!"                             then force_close_active_view()
  elseif text == "qa" or text == "qall"           then core.quit(false)
  elseif text == "qa!" or text == "qall!"         then core.quit(true)
  elseif text == "wq"  or text == "x"             then
    command.perform("doc:save"); command.perform("root:close")
  elseif text == "wqa" or text == "wqall" or text == "xa" then
    save_all(); core.quit(false)
  elseif text == "wqa!" or text == "wqall!"       then
    save_all(); core.quit(true)
  elseif text:match("^%d+$") then
    local view = active_docview()
    if view then
      local line = tonumber(text)
      view.doc:set_selection(line, 1)
      view:scroll_to_line(line, false, true)
    end
  else
    core.error("vim: unknown command \":%s\"", text)
  end
end

local function open_ex_commandline()
  core.command_view:enter("", submit_ex_command, function() return {} end)
end


local function handle_key(k)
  if not config.vim_mode_enabled then return false end

  local view = active_docview()
  if not view then return false end

  if k:find("shift") or k:find("ctrl") or k:find("alt") then return false end
  if keymap.modkeys.ctrl or keymap.modkeys.alt or keymap.modkeys.altgr then
    return false
  end

  local mode  = get_mode(view)
  local shift = keymap.modkeys.shift

  if k == "escape" then
    if mode == MODE_INSERT then
      set_mode(view, MODE_NORMAL)
      command.perform("doc:move-to-previous-char")
    elseif mode == MODE_VISUAL then
      set_mode(view, MODE_NORMAL)
      command.perform("doc:select-none")
    else
      command.perform("doc:select-none")
    end
    return true
  end

  if mode == MODE_INSERT then
    return false
  end

  if mode == MODE_VISUAL and not shift then
    if k == "d" or k == "x" then
      command.perform("doc:cut")
      set_mode(view, MODE_NORMAL)
      return true
    elseif k == "y" then
      command.perform("doc:copy")
      command.perform("doc:select-none")
      set_mode(view, MODE_NORMAL)
      return true
    end
  end

  if mode == MODE_NORMAL and not shift and (k == "g" or k == "d" or k == "y") then
    if pending and pending.key == k
    and system.get_time() - pending.t < PENDING_TIMEOUT then
      pending = nil
      if k == "g" then
        command.perform("doc:move-to-start-of-doc")
      elseif k == "d" then
        command.perform("doc:delete-lines")
      elseif k == "y" then
        command.perform("doc:select-lines")
        command.perform("doc:copy")
        command.perform("doc:select-none")
      end
    else
      pending = { key = k, t = system.get_time() }
    end
    return true
  end

  if pending and pending.key ~= k then
    pending = nil
  end

  if shift then
    if     k == "g" then command.perform("doc:move-to-end-of-doc")
    elseif k == "i" then
      command.perform("doc:move-to-start-of-line")
      set_mode(view, MODE_INSERT)
    elseif k == "a" then
      command.perform("doc:move-to-end-of-line")
      set_mode(view, MODE_INSERT)
    elseif k == "o" then
      command.perform("doc:move-to-start-of-line")
      command.perform("doc:newline-above")
      set_mode(view, MODE_INSERT)
    elseif k == "n" then command.perform("find-replace:previous-find")
    elseif k == "4" then command.perform("doc:move-to-end-of-line")   -- $ (shift+4)
    elseif k == ";" then open_ex_commandline()                        -- : (shift+;)
    end
    return true
  end

  if MOTIONS[k] then
    command.perform(mode == MODE_VISUAL and MOTIONS[k][2] or MOTIONS[k][1])
    return true
  end

  if k == "v" then
    if mode == MODE_VISUAL then
      command.perform("doc:select-none")
      set_mode(view, MODE_NORMAL)
    else
      set_mode(view, MODE_VISUAL)
    end
    return true
  end

  if k == "i" then set_mode(view, MODE_INSERT); return true end

  if k == "a" then
    command.perform("doc:move-to-next-char")
    set_mode(view, MODE_INSERT)
    return true
  end

  if k == "o" then
    command.perform("doc:move-to-end-of-line")
    command.perform("doc:newline")
    set_mode(view, MODE_INSERT)
    return true
  end

  if k == "0" then command.perform("doc:move-to-start-of-line"); return true end

  if k == "x" then
    command.perform("doc:select-to-next-char")
    command.perform("doc:cut")
    return true
  end

  if k == "p" then command.perform("doc:paste"); return true end
  if k == "u" then command.perform("doc:undo");  return true end

  if k == "/" then command.perform("find-replace:find");        return true end
  if k == "n" then command.perform("find-replace:repeat-find"); return true end

  if #k == 1 then return true end

  return false
end


local original_on_key_pressed = keymap.on_key_pressed

function keymap.on_key_pressed(k)
  local ok, handled = core.try(handle_key, k)
  if ok and handled then
    if system.suppress_next_textinput then
      system.suppress_next_textinput()
    end
    return true
  end
  return original_on_key_pressed(k)
end
