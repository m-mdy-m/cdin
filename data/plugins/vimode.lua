-- vimode.lua — modal (vim-style) editing core.
--
-- Structure:
--   1. Config / constants
--   2. View & mode helpers
--   3. Ex command line (with history)
--   4. Key tables      : MOTIONS, DOUBLE_KEYS, SHIFT_KEYS, NORMAL_KEYS
--   5. Mode handlers   : visual / pending / shift / normal
--   6. Dispatcher      : handle_key()
--   7. Keymap hook + statusbar label
--
-- Menus (normal mode):
--   m  → file menu   (vim_fmenu)
--   s  → shell menu  (vim_shell — git & shell commands)

local core        = require "core"
local config      = require "core.config"
local command     = require "core.command"
local keymap      = require "core.keymap"
local DocView     = require "core.docview"
local CommandView = require "core.commandview"
local ex          = require "plugins.vim_ex"

require "plugins.vim_fmenu"
require "plugins.vim_shell"

-- 1. Config / constants ──────────────────────────────────────────────────────

if config.vim_mode_enabled == nil then
  config.vim_mode_enabled = true
end
config.vim_ex_history_max = 100

local MODE_NORMAL = "normal"
local MODE_INSERT = "insert"
local MODE_VISUAL = "visual"

local PENDING_TIMEOUT = 0.6

local pending = nil       -- { key, t } for double-key sequences (dd, yy, …)
local history_pos = nil   -- ex history cursor

-- 2. View & mode helpers ─────────────────────────────────────────────────────

local function active_docview()
  local v = core.active_view
  if v and v:is(DocView) and not v:is(CommandView) then return v end
  return nil
end

local function get_mode(view)
  return view.vim_mode or MODE_NORMAL
end

local function set_mode(view, mode)
  view.vim_mode = mode
  core.redraw = true
end

-- 3. Ex command line ─────────────────────────────────────────────────────────

local function ex_suggest(text)
  local bare = text:sub(1, 1) == ":" and text:sub(2) or text
  return ex.suggest(bare)
end

local function open_ex_commandline()
  history_pos = nil
  core.command_view:enter(
    "",
    function(text) ex.submit(text) end,
    ex_suggest,
    function() history_pos = nil end
  )
  core.command_view:set_text(":")
end

local function ex_history_prev()
  if core.active_view ~= core.command_view then return false end
  local hist = ex.history
  if #hist == 0 then return true end
  if not history_pos then
    history_pos = #hist
  else
    history_pos = math.max(1, history_pos - 1)
  end
  core.command_view:set_text(":" .. hist[history_pos])
  return true
end

local function ex_history_next()
  if core.active_view ~= core.command_view then return false end
  local hist = ex.history
  if not history_pos then return true end
  history_pos = history_pos + 1
  if history_pos > #hist then
    history_pos = nil
    core.command_view:set_text(":")
  else
    core.command_view:set_text(":" .. hist[history_pos])
  end
  return true
end

-- 4. Key tables ──────────────────────────────────────────────────────────────

-- key → { normal-command, visual-command }
local MOTIONS = {
  h = { "doc:move-to-previous-char",       "doc:select-to-previous-char"       },
  l = { "doc:move-to-next-char",           "doc:select-to-next-char"           },
  j = { "doc:move-to-next-line",           "doc:select-to-next-line"           },
  k = { "doc:move-to-previous-line",       "doc:select-to-previous-line"       },
  w = { "doc:move-to-next-word-end",       "doc:select-to-next-word-end"       },
  b = { "doc:move-to-previous-word-start", "doc:select-to-previous-word-start" },
  e = { "doc:move-to-next-word-end",       "doc:select-to-next-word-end"       },
}

-- double-key sequences in normal mode: gg, dd, yy, cc
local DOUBLE_KEYS = {
  g = function()
    command.perform("doc:move-to-start-of-doc")
  end,
  d = function()
    command.perform("doc:delete-lines")
  end,
  y = function()
    command.perform("doc:select-lines")
    command.perform("doc:copy")
    command.perform("doc:select-none")
  end,
  c = function(view)
    command.perform("doc:delete-lines")
    set_mode(view, MODE_INSERT)
  end,
}

-- shift + key in normal / visual mode
local SHIFT_KEYS = {
  g = function() command.perform("doc:move-to-end-of-doc") end,      -- G
  i = function(view)                                                 -- I
    command.perform("doc:move-to-start-of-line")
    set_mode(view, MODE_INSERT)
  end,
  a = function(view)                                                 -- A
    command.perform("doc:move-to-end-of-line")
    set_mode(view, MODE_INSERT)
  end,
  o = function(view)                                                 -- O
    command.perform("doc:move-to-start-of-line")
    command.perform("doc:newline-above")
    set_mode(view, MODE_INSERT)
  end,
  n = function() command.perform("find-replace:previous-find") end,  -- N
  ["4"] = function() command.perform("doc:move-to-end-of-line") end,   -- $
  ["6"] = function() command.perform("doc:move-to-start-of-line") end, -- ^
  d = function()                                                     -- D
    command.perform("doc:select-to-end-of-line")
    command.perform("doc:cut")
  end,
  j = function()                                                     -- J
    command.perform("doc:move-to-end-of-line")
    command.perform("doc:delete")
  end,
}

-- single keys in normal mode
local NORMAL_KEYS = {
  i = function(view) set_mode(view, MODE_INSERT) end,
  a = function(view)
    command.perform("doc:move-to-next-char")
    set_mode(view, MODE_INSERT)
  end,
  o = function(view)
    command.perform("doc:move-to-end-of-line")
    command.perform("doc:newline")
    set_mode(view, MODE_INSERT)
  end,
  ["0"] = function() command.perform("doc:move-to-start-of-line") end,
  x = function()
    command.perform("doc:select-to-next-char")
    command.perform("doc:cut")
  end,
  p = function() command.perform("doc:paste") end,
  u = function() command.perform("doc:undo") end,
  r = function() command.perform("doc:redo") end,
  ["/"] = function() command.perform("find-replace:find") end,
  n = function() command.perform("find-replace:repeat-find") end,
  ["*"] = function(view)
    local doc = view.doc
    local line, col = doc:get_selection()
    local word = doc:get_text(line, col, line, math.huge)
    word = word:match("^([%w_]+)") or ""
    if word ~= "" then
      command.perform("find-replace:find")
    end
  end,
  tab = function() command.perform("root:switch-to-next-tab") end,
}

-- 5. Mode handlers ───────────────────────────────────────────────────────────

local function handle_escape(view, mode)
  pending = nil
  if not view then return false end
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

local function handle_visual(view, k)
  if k == "d" or k == "x" then
    command.perform("doc:cut")
    set_mode(view, MODE_NORMAL)
    return true
  elseif k == "y" then
    command.perform("doc:copy")
    command.perform("doc:select-none")
    set_mode(view, MODE_NORMAL)
    return true
  elseif k == ">" then
    command.perform("doc:indent")
    return true
  elseif k == "<" then
    command.perform("doc:unindent")
    return true
  end
  return false
end

local function handle_pending(view, k, mode, shift)
  if mode == MODE_NORMAL and not shift and DOUBLE_KEYS[k] then
    if pending and pending.key == k
    and system.get_time() - pending.t < PENDING_TIMEOUT then
      pending = nil
      DOUBLE_KEYS[k](view)
    else
      pending = { key = k, t = system.get_time() }
    end
    return true
  end
  if pending and pending.key ~= k then
    pending = nil
  end
  return false
end

local function handle_shift(view, k)
  local fn = SHIFT_KEYS[k]
  if fn then
    fn(view)
    return true
  end
  return #k == 1   -- swallow unbound printable shift-keys, pass the rest through
end

local function handle_normal(view, k, mode)
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

  local fn = NORMAL_KEYS[k]
  if fn then
    fn(view)
    return true
  end

  return #k == 1   -- swallow unbound printable keys in normal / visual mode
end

-- 6. Dispatcher ──────────────────────────────────────────────────────────────

local function handle_key(k)
  if not config.vim_mode_enabled then return false end

  -- ex command line: history navigation only
  if core.active_view == core.command_view then
    if k == "up"   then return ex_history_prev() end
    if k == "down" then return ex_history_next() end
    return false
  end

  if k:find("ctrl") or k:find("alt") then return false end
  if keymap.modkeys.ctrl or keymap.modkeys.alt or keymap.modkeys.altgr then
    return false
  end

  local shift = keymap.modkeys.shift
  local view  = active_docview()
  local mode  = view and get_mode(view) or MODE_NORMAL

  if k == "escape" then
    return handle_escape(view, mode)
  end

  -- ":" opens the ex command line (outside insert mode)
  if shift and k == ";" and mode ~= MODE_INSERT then
    open_ex_commandline()
    return true
  end

  -- menus — available outside insert mode, even without a focused doc
  if mode ~= MODE_INSERT and not shift then
    if k == "m" then command.perform("vim-fmenu:open"); return true end
    if k == "s" then command.perform("vim-shell:menu"); return true end
  end

  if not view then return false end
  if mode == MODE_INSERT then return false end

  if mode == MODE_VISUAL and not shift and handle_visual(view, k) then
    return true
  end

  if handle_pending(view, k, mode, shift) then return true end

  if shift then
    return handle_shift(view, k)
  end

  return handle_normal(view, k, mode)
end

-- 7. Keymap hook + statusbar label ───────────────────────────────────────────

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

function core.get_vim_mode_label()
  if not config.vim_mode_enabled then return nil end
  local v = core.active_view
  if v and v:is(DocView) and not v:is(CommandView) then
    local mode = get_mode(v)
    if     mode == MODE_INSERT then return "[INSERT]"
    elseif mode == MODE_VISUAL then return "[VISUAL]"
    else                            return "[NORMAL]"
    end
  end
  return nil
end
