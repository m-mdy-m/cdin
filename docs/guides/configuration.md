# Configuration

There is no settings UI and no JSON. Configuration is Lua, and it lives in
`data/user/init.lua`. That file is loaded last — after the core and after
every plugin — so anything you set there wins. Open it from inside the
editor with the `core:open-user-module` command (`Ctrl+Shift+P`, then type
"open user module").

A minimal config looks like this:

```lua
local keymap = require "core.keymap"
local config = require "core.config"
local style  = require "core.style"

config.indent_size = 4
config.tab_type = "hard"

keymap.add {
  ["ctrl+escape"] = "core:quit",
}
```

Changes take effect the next time you start the editor. You can also reload
a single module at runtime with the `core:reload-module` command.

## Per-project configuration

The `core:open-project-module` command creates (or opens) a
`.lite_project.lua` file in the project directory. It works exactly like the
user module but is loaded per project, so you can keep project-specific
settings — indent width, extra keybindings, ignore patterns — with the code
they belong to.

## Options

All options are fields on the `core.config` module. Defaults are defined in
`data/core/config.lua`; plugins add their own (listed further down).

### Editing

| Option | Default | Meaning |
|---|---|---|
| `indent_size` | `2` | spaces per indent level |
| `tab_type` | `"soft"` | `"soft"` inserts spaces, `"hard"` inserts tab characters |
| `line_limit` | `80` | column of the line-limit guide |
| `line_height` | `1.2` | line height as a multiple of the font size |
| `highlight_current_line` | `true` | highlight the line the caret is on |
| `undo_merge_timeout` | `0.3` | seconds within which consecutive edits merge into one undo step |
| `max_undos` | `10000` | undo stack depth per document |
| `symbol_pattern` | `"[%a_][%w_]*"` | Lua pattern that defines a symbol (used by autocomplete) |
| `non_word_chars` | see source | characters that delimit words for word-wise movement |

### Vim mode

| Option | Default | Meaning |
|---|---|---|
| `vim_mode_enabled` | `true` | modal editing on/off |
| `scrolloff` | `5` | minimum lines kept visible above/below the caret while scrolling |
| `line_number_relative` | `false` | show line numbers relative to the caret, vim's `relativenumber` |
| `vim_ex_history_max` | `100` | how many ex commands (`:`) to remember |

### Project and files

| Option | Default | Meaning |
|---|---|---|
| `project_scan_rate` | `5` | seconds between rescans of the project tree |
| `file_size_limit` | `10` | files larger than this (MB) are excluded from the project scan |
| `ignore_files` | `"^%."` | Lua pattern for files to ignore (default: dotfiles) |

### Tree view (plugin)

| Option | Default | Meaning |
|---|---|---|
| `treeview_size` | `200 * SCALE` | panel width in pixels |
| `show_hidden_files` | `true` | show dotfiles in the tree (toggle at runtime with `treeview:toggle-hidden`) |
| `treeview_git_enabled` | `true` | poll `git status` and show A/M/D/? markers |
| `treeview_git_update_rate` | `2` | seconds between git status polls |

On very large repositories the periodic `git status` can be noticeable;
set `treeview_git_enabled = false` if so.

### UI and performance

| Option | Default | Meaning |
|---|---|---|
| `fps` | `60` | redraw rate cap |
| `mouse_wheel_scroll` | `54 * SCALE` | pixels scrolled per wheel step |
| `message_timeout` | `3` | seconds a status-bar message stays visible |
| `max_log_items` | `80` | entries kept in the log view |

## Keybindings

`keymap.add` maps key strokes to command names:

```lua
keymap.add {
  ["ctrl+shift+h"] = "treeview:toggle-hidden",
  ["f8"] = { "doc:save", "core:quit" },  -- first command whose predicate matches wins
}
```

Stroke syntax is modifiers joined with `+` and then the key name:
`ctrl+s`, `ctrl+shift+p`, `alt+return`, `f5`. Available modifiers are
`ctrl`, `alt`, `altgr` and `shift`. A stroke can map to a list of commands;
the first one that is valid in the current context runs.

By default `keymap.add` prepends to existing bindings. Pass `true` as the
second argument to replace them: `keymap.add({ ... }, true)`.

Command names are listed in [Commands and Keybindings](../reference/commands.md),
or browse them live with `Ctrl+Shift+P`.

## Colors and fonts

Themes are Lua modules that overwrite fields of `core.style`. Two alternative
themes ship in `data/user/colors/`; enable one from the user module:

```lua
require "user.colors.summer"   -- light theme
require "user.colors.fall"     -- warm dark theme
```

The default theme is defined in `data/core/style.lua`. To make your own
theme, copy one of the files in `data/user/colors/`, adjust the
`style.syntax` and UI color tables, and `require` it.

Fonts (UI, code, icons) also live on `style` and can be replaced with
`renderer.font.load(path, size)` in the user module. The bundled fonts are
in `data/fonts/`.
