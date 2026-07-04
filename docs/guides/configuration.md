# Configuration

cdin is configured through a single Lua file: `data/user/init.lua`. This file is loaded last, after the core and all plugins, so anything you set here overrides the defaults.

To open it from inside the editor, run the command `core:open-user-module` from the command palette (`Ctrl+Shift+P`).

---

## Config values

All config options live in the `config` table. You set them like this:

```lua
local config = require "core.config"

config.indent_size = 4
config.tab_type = "hard"
```

### Editor

| Option | Default | Description |
|--------|---------|-------------|
| `config.indent_size` | `2` | Number of spaces per indent level |
| `config.tab_type` | `"soft"` | `"soft"` (spaces) or `"hard"` (tabs) |
| `config.line_limit` | `80` | Column at which the line limit guide is drawn |
| `config.highlight_current_line` | `true` | Highlight the line the cursor is on |
| `config.line_height` | `1.2` | Line height multiplier |
| `config.max_undos` | `10000` | Maximum number of undo steps stored |
| `config.undo_merge_timeout` | `0.3` | Consecutive edits within this many seconds are merged into one undo step |
| `config.symbol_pattern` | `"[%a_][%w_]*"` | Lua pattern defining what counts as a word for word-motion commands |
| `config.non_word_chars` | `" \t\n/\\()\"':,.;<>~!@#$%^&*\|+=[]{}\`?-"` | Characters that word motions stop at |

### Vim mode

| Option | Default | Description |
|--------|---------|-------------|
| `config.vim_mode_enabled` | `true` | Enable or disable modal editing entirely |
| `config.scrolloff` | `5` | Lines of context kept above/below the cursor while scrolling (like Vim's `scrolloff`) |
| `config.line_number_relative` | `false` | Show line numbers relative to cursor position (like `relativenumber` in Vim) |
| `config.vim_ex_history_max` | `100` | Maximum number of ex commands kept in history |

### Files

| Option | Default | Description |
|--------|---------|-------------|
| `config.file_size_limit` | `10` | Maximum file size in MB the editor will open |
| `config.ignore_files` | `"^%."` | Lua pattern for files to exclude from the project scanner. Default hides dot files. |

### Rendering

| Option | Default | Description |
|--------|---------|-------------|
| `config.fps` | `60` | Target frame rate |
| `config.mouse_wheel_scroll` | `54 * SCALE` | Pixels scrolled per mouse wheel tick |

### Project scanner

| Option | Default | Description |
|--------|---------|-------------|
| `config.project_scan_rate` | `5` | How often (in seconds) the background thread rescans project files |

### Logs

| Option | Default | Description |
|--------|---------|-------------|
| `config.max_log_items` | `80` | Maximum number of entries kept in the log view |
| `config.message_timeout` | `3` | Seconds a status bar message stays visible |

### Tree view

| Option | Default | Description |
|--------|---------|-------------|
| `config.treeview_size` | `200 * SCALE` | Width of the tree panel in pixels |
| `config.show_hidden_files` | `true` | Show dot files in the tree. Setting to `false` restores the default `ignore_files` pattern |
| `config.treeview_git_enabled` | `true` | Show git status markers (A/M/D/?) in the tree |
| `config.treeview_git_update_rate` | `2` | Seconds between git status polls |

### Autocomplete

| Option | Default | Description |
|--------|---------|-------------|
| `config.autocomplete_max_suggestions` | `6` | Maximum number of autocomplete suggestions shown |

---

## Keybindings

You can add or override keybindings with `keymap.add`:

```lua
local keymap = require "core.keymap"

keymap.add {
  ["ctrl+escape"] = "core:quit",
  ["ctrl+shift+h"] = "treeview:toggle-hidden",
}
```

To override an existing binding, pass `true` as the second argument:

```lua
keymap.add({
  ["ctrl+s"] = "doc:save-as",
}, true)
```

Each key in the table is a stroke string. Modifiers are written lowercase, separated by `+`. Examples: `"ctrl+s"`, `"alt+shift+j"`, `"ctrl+shift+p"`, `"f3"`.

A stroke can map to a single command string or a list. When it's a list, cdin tries each command in order and stops at the first one that does anything:

```lua
keymap.add {
  ["escape"] = { "command:escape", "doc:select-none" },
}
```

The value on the right is a command name. A list of all built-in commands is in the [Command Reference](../reference/commands.md).

---

## Themes

Three themes are available. Load one in `data/user/init.lua`:

```lua
-- warm dark theme
require "user.colors.fall"

-- light theme
require "user.colors.summer"

-- default (near-black, purple accent) — no require needed
```

To write your own theme, create a Lua file in `data/user/colors/` and set colors on the `style` table:

```lua
local style = require "core.style"
local common = require "core.common"

style.background  = { common.color "#1e1e2e" }
style.text        = { common.color "#cdd6f4" }
style.caret       = { common.color "#f5c2e7" }
style.accent      = { common.color "#89b4fa" }
-- ... and so on
```

See `data/user/colors/fall.lua` or `data/user/colors/summer.lua` for a complete list of style fields.

---

## Project-local config

If you create a file called `.lite_project.lua` in the root of a project directory, cdin loads it automatically when you open that directory. Use it for per-project settings:

```lua
-- .lite_project.lua
local config = require "core.config"
config.indent_size = 4
config.tab_type = "hard"
```

This file is a plain Lua script executed in the same context as `user/init.lua`, so you can do anything there that you can do in your user config.

To create or open this file from inside the editor, run `core:open-project-module` from the command palette.

---

## Example user config

```lua
local config = require "core.config"
local keymap = require "core.keymap"

-- indentation
config.indent_size = 4
config.tab_type = "soft"

-- vim settings
config.scrolloff = 8
config.line_number_relative = true

-- theme
require "user.colors.fall"

-- extra keybindings
keymap.add {
  ["ctrl+escape"] = "core:quit",
}
```