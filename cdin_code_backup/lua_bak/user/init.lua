-- data/user/init.lua -- VEX keybinds for cdin
-- Vim-style bindings inspired by the VEX vim config.
-- Kept minimal: only what's actually useful daily.

local core    = require "core"
local keymap  = require "core.keymap"
local config  = require "core.config"
local command = require "core.command"
local CommandView = require "core.commandview"

-- -- editor config ----------------------------------------------------------
config.indent_size        = 2
config.tab_type           = "soft"
config.line_height        = 1.2
config.highlight_current_line = true
config.line_limit         = 80
config.fps                = 60

-- -- vim colon-command entry ------------------------------------------------
-- Press ";" or ":" in normal context to open ex commandline (like vim's :)
command.add(nil, {
  ["vim:enter-command"] = function()
    core.command_view:enter_vim()
  end,
})

keymap.add {
  -- ";" is the vim-style command entry (like pressing : in vim)
  [";"] = "vim:enter-command",
}

-- -- basic vim-style keybinds -----------------------------------------------
keymap.add {
  -- save / close  (ctrl+s always works, Ctrl+w closes tab)
  ["ctrl+s"]      = "doc:save",
  ["ctrl+w"]      = "root:close",

  -- undo / redo
  ["ctrl+z"]      = "doc:undo",
  ["ctrl+y"]      = "doc:redo",

  -- clipboard (standard cross-app)
  ["ctrl+c"]      = "doc:copy",
  ["ctrl+x"]      = "doc:cut",
  ["ctrl+v"]      = "doc:paste",
  ["ctrl+a"]      = "doc:select-all",

  -- file opener (like ctrl+p in many editors)
  ["ctrl+p"]      = "core:find-file",
  ["ctrl+shift+p"] = "core:find-command",

  -- tab navigation (gt / gT feel)
  ["ctrl+tab"]        = "root:switch-to-next-tab",
  ["ctrl+shift+tab"]  = "root:switch-to-previous-tab",
  ["ctrl+1"]  = "root:switch-to-tab-1",
  ["ctrl+2"]  = "root:switch-to-tab-2",
  ["ctrl+3"]  = "root:switch-to-tab-3",
  ["ctrl+4"]  = "root:switch-to-tab-4",
  ["ctrl+5"]  = "root:switch-to-tab-5",

  -- splits (vim: :vs :sp)
  ["ctrl+shift+v"] = "root:split-right",
  ["ctrl+shift+s"] = "root:split-down",

  -- pane navigation (ctrl+hjkl)
  ["ctrl+h"] = "root:switch-to-left",
  ["ctrl+l"] = "root:switch-to-right",
  ["ctrl+k"] = "root:switch-to-up",
  ["ctrl+j"] = "root:switch-to-down",

  -- line operations
  ["ctrl+d"]       = "doc:delete-lines",
  ["ctrl+shift+d"] = "doc:duplicate-lines",

  -- indent / dedent (vim: >> <<)
  ["tab"]           = "doc:indent",
  ["shift+tab"]     = "doc:unindent",

  -- move lines (like vim's :move)
  ["ctrl+up"]   = "doc:move-lines-up",
  ["ctrl+down"] = "doc:move-lines-down",

  -- search  (/ and ? feel)
  ["ctrl+f"] = "find-replace:find",
  ["ctrl+r"] = "find-replace:replace",
  ["f3"]     = "find-replace:select-next",
  ["shift+f3"] = "find-replace:select-prev",

  -- toggle treeview (netrw feel)
  ["ctrl+\\"] = "treeview:toggle",

  -- go to line (vim: :NNN  -- this opens a quick prompt)
  ["ctrl+g"]  = "doc:go-to-line",

  -- comment toggle (gc motion stub)
  ["ctrl+/"]  = "doc:toggle-line-comments",

  -- fullscreen
  ["f11"] = "core:toggle-fullscreen",
}

-- -- escape in suggestion/command popup -------------------------------------
-- Already wired by default; keep here for explicitness
keymap.add {
  ["escape"] = "command:escape",
}
