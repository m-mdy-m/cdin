-- plugins/vimode — a *lightweight* vim-style modal layer, not a full vim
-- emulation. It covers the everyday subset: normal/insert/visual modes,
-- the usual motions (h j k l w b 0 $ gg G), x / dd / yy / p / u, the
-- insert-mode entries (i a o I A O), basic visual selection, and an
-- ex command line (:w :q :wq :x, plus a bare line number to jump to it).
--
-- Deliberately NOT included, to keep this simple: counts ("3dd"),
-- operator+motion composition beyond the literal dd/yy/gg doubles,
-- registers, macros, marks, or :s substitution. Real vim users will
-- notice the gaps; that's the trade-off for "simple" over "feature-rich".
--
-- Disable by setting `config.vim_mode_enabled = false` in your user
-- module, or just delete this file — nothing else in cdin depends on it.

local core = require "core"
local config = require "core.config"
local command = require "core.command"
local keymap = require "core.keymap"
local DocView = require "core.docview"
local CommandView = require "core.commandview"

if config.vim_mode_enabled == nil then
  config.vim_mode_enabled = true
end

local MODE_NORMAL, MODE_INSERT, MODE_VISUAL = "normal", "insert", "visual"
local PENDING_TIMEOUT = 0.6

local pending = nil


local function active_docview()
  local view = core.active_view
  -- CommandView extends DocView, so the explicit exclusion matters:
  -- without it, vim motions would hijack typing in the command line.
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


-- plain motion keys shared between normal mode (move) and visual mode
-- (extend selection)
local MOTIONS = {
  h = { "doc:move-to-previous-char",       "doc:select-to-previous-char" },
  l = { "doc:move-to-next-char",           "doc:select-to-next-char" },
  j = { "doc:move-to-next-line",           "doc:select-to-next-line" },
  k = { "doc:move-to-previous-line",       "doc:select-to-previous-line" },
  w = { "doc:move-to-next-word-end",       "doc:select-to-next-word-end" },
  b = { "doc:move-to-previous-word-start", "doc:select-to-previous-word-start" },
}


local function submit_ex_command(text)
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return end

  if text == "w" then
    command.perform("doc:save")
  elseif text == "q" or text == "q!" then
    command.perform("root:close")
  elseif text == "wq" or text == "x" then
    command.perform("doc:save")
    command.perform("root:close")
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


local function open_command_line()
  core.command_view:enter("", submit_ex_command, function() return {} end)
end


-- Returns true if the key was handled as a vim command (and should not
-- also be treated as text input / fall through to the normal keymap).
local function handle_key(k)
  if not config.vim_mode_enabled then return false end

  local view = active_docview()
  if not view then return false end

  -- never intercept modifier key-down events themselves
  if k:find("shift") or k:find("ctrl") or k:find("alt") then return false end
  if keymap.modkeys.ctrl or keymap.modkeys.alt or keymap.modkeys.altgr then
    return false
  end

  local mode = get_mode(view)
  local shift = keymap.modkeys.shift

  if k == "escape" then
    if mode == MODE_INSERT then
      set_mode(view, MODE_NORMAL)
      command.perform("doc:move-to-previous-char")
      return true
    elseif mode == MODE_VISUAL then
      set_mode(view, MODE_NORMAL)
      command.perform("doc:select-none")
      return true
    end
    return false -- normal mode: let the default escape behavior run
  end

  if mode == MODE_INSERT then
    return false -- everything else is just typing
  end

  -- visual-mode operators that act on the current selection
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

  -- gg / dd / yy: only meaningful as a double-tap in normal mode
  if mode == MODE_NORMAL and not shift and (k == "g" or k == "d" or k == "y") then
    if pending and pending.key == k and system.get_time() - pending.t < PENDING_TIMEOUT then
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
      return true
    end
    pending = { key = k, t = system.get_time() }
    return true
  end
  if pending and pending.key ~= k then
    pending = nil -- abandoned combo; handle this key normally below
  end

  if shift then
    if k == "g" then
      command.perform("doc:move-to-end-of-doc")
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
    elseif k == "n" then
      command.perform("find-replace:previous-find")
    elseif k == "4" then -- $ (shift+4): end of line
      command.perform("doc:move-to-end-of-line")
    elseif k == ";" then -- : (shift+;): ex command line
      open_command_line()
    end
    -- normal/visual mode never inserts text, mapped or not
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
  elseif k == "0" then
    command.perform("doc:move-to-start-of-line")
    return true
  elseif k == "x" then
    command.perform("doc:select-to-next-char")
    command.perform("doc:cut")
    return true
  elseif k == "p" then
    command.perform("doc:paste")
    return true
  elseif k == "u" then
    command.perform("doc:undo")
    return true
  elseif k == "i" then
    set_mode(view, MODE_INSERT)
    return true
  elseif k == "a" then
    command.perform("doc:move-to-next-char")
    set_mode(view, MODE_INSERT)
    return true
  elseif k == "o" then
    command.perform("doc:move-to-end-of-line")
    command.perform("doc:newline")
    set_mode(view, MODE_INSERT)
    return true
  elseif k == "/" then
    command.perform("find-replace:find")
    return true
  elseif k == "n" then
    command.perform("find-replace:repeat-find")
    return true
  end

  -- normal/visual mode swallows any other plain printable key instead
  -- of letting it fall through to text insertion
  if #k == 1 then return true end
  return false
end


local original_on_key_pressed = keymap.on_key_pressed
function keymap.on_key_pressed(k)
  local ok, handled = core.try(handle_key, k)
  if ok and handled then return true end
  return original_on_key_pressed(k)
end