# Configuration

cdin is configured through a single Lua file: `data/user/init.lua`. It loads
last, after the core and all plugins, so anything you set there overrides the
defaults.

To open it from inside the editor, run `core:open-user-module` from the
command palette (`Ctrl+Shift+P`).

---

## Config values

All options live in the `config` table:

```lua
local config = require "core.config"

config.indent_size = 4
config.tab_type = "hard"
```

### Editor

| Option | Default | Description |
|--------|---------|-------------|
| `config.indent_size` | `2` | Spaces per indent level |
| `config.tab_type` | `"soft"` | `"soft"` (spaces) or `"hard"` (tabs) |
| `config.line_limit` | `80` | Column where the line guide is drawn |
| `config.highlight_current_line` | `true` | Highlight the line the cursor is on |
| `config.line_height` | `1.2` | Line height multiplier |
| `config.max_undos` | `10000` | Maximum undo steps stored |
| `config.undo_merge_timeout` | `0.3` | Consecutive edits within this many seconds are merged into one step |
| `config.symbol_pattern` | `"[%a_][%w_]*"` | Lua pattern defining what counts as a "word" |
| `config.non_word_chars` | (punctuation) | Characters that word motions stop at |

### Vim mode

| Option | Default | Description |
|--------|---------|-------------|
| `config.vim_mode_enabled` | `true` | Enable or disable modal editing |
| `config.scrolloff` | `5` | Lines of context kept above/below the cursor while scrolling |
| `config.line_number_relative` | `false` | Show line numbers relative to the cursor |

### Files

| Option | Default | Description |
|--------|---------|-------------|
| `config.file_size_limit` | `10` | Maximum file size in MB the editor will open |
| `config.ignore_files` | `"^%."` | Lua pattern for files to hide from the project scanner |

### Rendering

| Option | Default | Description |
|--------|---------|-------------|
| `config.fps` | `60` | Target frame rate |
| `config.mouse_wheel_scroll` | `54 * SCALE` | Pixels scrolled per mouse wheel tick |

### Project scanner

| Option | Default | Description |
|--------|---------|-------------|
| `config.project_scan_rate` | `10` | How often (in seconds) the background thread rescans project files |

### Logs

| Option | Default | Description |
|--------|---------|-------------|
| `config.max_log_items` | `80` | Maximum entries kept in the log view |
| `config.message_timeout` | `3` | Seconds a status bar message stays visible |

### Tree view

| Option | Default | Description |
|--------|---------|-------------|
| `config.treeview_size` | `200 * SCALE` | Width of the tree panel in pixels |
| `config.show_hidden_files` | `true` | Show dot files in the tree |
| `config.treeview_git_enabled` | `true` | Show git status markers (A/M/D/?) |
| `config.treeview_git_update_rate` | `2` | Seconds between git status polls |

### Autocomplete

| Option | Default | Description |
|--------|---------|-------------|
| `config.autocomplete_max_suggestions` | `6` | Maximum suggestions shown |

### Session

| Option | Default | Description |
|--------|---------|-------------|
| `config.session_restore` | `false` | Reopen the last session on startup |
| `config.session_save_on_quit` | `true` | Save the session automatically on quit |
| `config.session_max_recent` | `10` | Number of recent files/dirs to remember |

---

## Keybindings

Add or override keybindings with `keymap.add`:

```lua
local keymap = require "core.input.keymap"

keymap.add {
  ["ctrl+escape"] = "core:quit",
  ["ctrl+h"]      = "find-replace:replace",
}
```

To override an existing binding, pass `true` as the second argument:

```lua
keymap.add({ ["ctrl+s"] = "doc:save-as" }, true)
```

Modifier names are lowercase and separated by `+`. A stroke can map to a
single command or a list — cdin tries each in order and stops at the first
one that does anything:

```lua
keymap.add {
  ["escape"] = { "command:escape", "doc:select-none" },
}
```

A full list of commands and their default bindings is in the
[Command Reference](commands.md).

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

To write your own theme, create a Lua file in `data/user/colors/` and set
fields on the `style` table:

```lua
local style  = require "core.style"
local common = require "core.utils.common"

style.background = { common.color "#1e1e2e" }
style.text       = { common.color "#cdd6f4" }
style.caret      = { common.color "#f5c2e7" }
style.accent     = { common.color "#89b4fa" }
-- ... and so on
```

See `data/core/style.lua` for the full list of style fields and their
defaults.

---

## Project-local config

Drop a `.lite_project.lua` file in the root of any project directory and
cdin loads it automatically when you open that directory. Use it for
per-project overrides:

```lua
-- .lite_project.lua
local config = require "core.config"
config.indent_size = 4
config.tab_type = "hard"
```

It's a plain Lua script with the same context as `user/init.lua`. To create
or open it from the editor, run `core:open-project-module` from the command
palette.

---

## Example user config

```lua
local config = require "core.config"
local keymap = require "core.input.keymap"

-- indentation
config.indent_size = 4
config.tab_type = "soft"

-- vim
config.scrolloff = 8
config.line_number_relative = true

-- session
config.session_restore = true

-- theme
require "user.colors.fall"

-- extra keybindings
keymap.add {
  ["ctrl+escape"] = "core:quit",
  ["ctrl+h"]      = "find-replace:replace",
}
```