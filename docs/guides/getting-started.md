# Getting Started

cdin is a small text editor written in C and Lua. The C side handles the
window, rendering, and input (via SDL3); everything else — documents, views,
commands, plugins — is Lua that lives in the `data/` directory next to the
binary. If you can read Lua, you can read the whole editor.

This page covers running the editor and finding your way around. For
compiling it yourself, see [Building from Source](building.md).

## Running

```
cdin                # open in the directory of the executable
cdin .              # open the current directory as the project
cdin path/to/dir    # open a directory as the project
cdin file.c         # open one or more files
cdin src main.c     # open a directory and a file at once
```

Any argument that is a directory becomes the project root (the editor changes
its working directory to it). Any argument that is a file gets opened in a
tab. Relative paths like `.` and `../` work.

The project root is what the file finder (`Ctrl+P`), project search, and the
tree view operate on.

## The screen

From top to bottom:

- **Title bar** — shows the current file and window controls.
- **Tree view** (left) — the project file tree. Toggle with `Ctrl+\` or
  `F2`, focus it with `Ctrl+Shift+E`. Shows git status markers
  (A/M/D/?) when the project is a git repo.
- **Editor area** — one or more views, split into tabs. Panes can be split
  horizontally and vertically.
- **Command view** — a one-line prompt at the top, shown when a command
  needs input (command palette, find bar, ex commands, etc.).
- **Status bar** — file name, cursor position, indent settings, and the
  current vim mode (`[NORMAL]`, `[INSERT]`, `[VISUAL]`).
- **Log view** — open with `core:open-log` from the palette to see editor
  messages and errors.

## Modal editing

cdin starts every buffer in NORMAL mode, like vim. Motions (`h j k l`, `w`,
`b`, `gg`, `G` …) work immediately; press `i`, `a`, or `o` to enter INSERT
mode before typing. `Esc` takes you back to NORMAL mode. The status bar
always shows which mode you're in.

If you don't want modal editing:

```lua
config.vim_mode_enabled = false
```

All the regular non-modal bindings (`Ctrl+S`, `Ctrl+Z`, arrow keys, …) work
in either case. See [Vim Keybindings](vim-keybindings.md) for the full
reference, including ex commands (`:w`, `:q`, `:e`, `:!cmd` …) and the `m`
action menu.

## Essential keys

| Key | Action |
|---|---|
| `Ctrl+Shift+P` | Command palette — every command in the editor, fuzzy-searchable |
| `Ctrl+P` | Open a file from the project (fuzzy find) |
| `Ctrl+O` | Open a file by path |
| `Ctrl+N` | New untitled document |
| `Ctrl+T` | New tab |
| `Ctrl+W` / `Ctrl+Shift+W` | Close view / close tab |
| `Ctrl+S` / `Ctrl+Shift+S` | Save / save as |
| `Ctrl+F` | Find in the current file |
| `Ctrl+Shift+F` | Search across the whole project |
| `Ctrl+G` | Go to line |
| `Ctrl+Z` / `Ctrl+Y` | Undo / redo |
| `Ctrl+\` | Toggle the tree view |
| `Alt+Return` | Toggle fullscreen |

**Tabs:** `Ctrl+Tab` / `Ctrl+Shift+Tab` cycle tabs. `Ctrl+1` through
`Ctrl+9` jump to a tab by number. `Ctrl+Shift+PageUp/PageDown` reorder tabs.

**Splits:** `Ctrl+\` splits vertically (side by side) and `Ctrl+Shift+\`
splits horizontally (stacked). `Alt+H/J/K/L` move focus between panes.
`Alt+Arrow` keys resize panes. `Alt+O` closes all other panes.

The command palette shows the keybinding next to each command, so it doubles
as a keybinding reference. The complete list is in
[Commands and Keybindings](commands.md).

## Configuring

Your personal configuration lives in `data/user/init.lua`. It's plain Lua,
loaded after the core and all plugins, so anything you set there wins. Open
it with `core:open-user-module` from the command palette.

```lua
local config = require "core.config"
local keymap = require "core.input.keymap"

config.indent_size = 4
config.tab_type = "hard"
keymap.add { ["ctrl+escape"] = "core:quit" }
```

See the [Configuration Guide](configuration.md) for every option.

## Where things live

```
cdin              the binary
data/core/        the Lua editor core (documents, views, commands, keymap)
data/plugins/     plugins, loaded automatically at startup
data/user/        your configuration and color themes
data/fonts/       bundled fonts
cdin.log          runtime log, written next to the binary
```

The `data/` directory is resolved relative to the executable, so a build
tree and an installed copy behave the same way.