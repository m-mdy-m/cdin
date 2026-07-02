-- data/user/init.lua
--
-- Your personal cdin config. Loaded last, after core and every plugin
-- in data/plugins/, so anything set here always wins.
--
-- This file follows the same philosophy as VEX's own settings.vim:
-- sensible, slightly opinionated defaults, all overridable in one
-- place, nothing hidden. Every line below is real and active -- comment
-- a line out (prefix it with `--`) to fall back to the built-in default
-- instead of deleting it, so you can see what changed later.

local keymap = require "core.keymap"
local config = require "core.config"
local style  = require "core.style"


-- ── theme ──
-- Default is the near-black, low-saturation, single-purple-accent
-- palette (see core/style.lua). Swap in a bundled alternative:
--   require "user.colors.summer"  -- light theme
--   require "user.colors.fall"    -- warm dark theme


-- ── vim philosophy ──
-- cdin starts every buffer in NORMAL mode, exactly like vim: motions
-- (hjkl, w, b, gg, G...) work immediately, and you press `i`/`a`/`o`
-- to enter INSERT mode before typing. Watch the `[NORMAL]` / `[INSERT]`
-- / `[VISUAL]` tag in the status bar (bottom-left) if you ever lose
-- track of which mode you're in -- that tag is always accurate.
config.vim_mode_enabled = true

-- Keep 5 lines of margin above/below the caret while scrolling
-- (vim's `scrolloff`). Set to 0 to let the caret touch the edges.
config.scrolloff = 5

-- Gutter shows the distance from the caret on every line but the
-- current one (vim's `relativenumber`), so counted motions like `5j`
-- can be read straight off the gutter. Flip to `false` for plain
-- absolute line numbers.
config.line_number_relative = false


-- ── treeview ──
-- Hidden/dot files are shown by default; toggle at runtime with the
-- binding below, or flip the default here.
-- config.show_hidden_files = false

-- Git status polling in the tree (A/M/D/? markers). Disable on huge
-- monorepos if the periodic `git status` becomes noticeable.
-- config.treeview_git_enabled = false
-- config.treeview_git_update_rate = 2 -- seconds between polls

keymap.add {
  ["ctrl+shift+h"] = "treeview:toggle-hidden",
}


-- ── extra key bindings ──
-- Uncomment to bind Ctrl+Escape to quit, VS Code style:
-- keymap.add { ["ctrl+escape"] = "core:quit" }
