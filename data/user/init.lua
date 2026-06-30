-- put user settings here
-- this module will be loaded after everything else when the application starts

local keymap = require "core.keymap"
local config = require "core.config"
local style = require "core.style"

-- light theme:
-- require "user.colors.summer"

-- key binding:
-- keymap.add { ["ctrl+escape"] = "core:quit" }

-- treeview: disable git status polling (e.g. huge monorepos)
-- config.treeview_git_enabled = false

-- treeview: show dotfiles by default, and bind a key to toggle them
-- config.show_hidden_files = true
-- keymap.add { ["ctrl+shift+h"] = "treeview:toggle-hidden" }