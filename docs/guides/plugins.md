# Plugins

## Overview

Plugins in cdin are Lua files in `data/plugins/`. They're loaded
automatically at startup, after the core but before `data/user/init.lua`.
A broken plugin logs the error and startup continues — one bad plugin won't
crash the editor.

Plugins are organized into subdirectories and the loader scans recursively.
There's no package manager. To install a third-party plugin, copy its file
(or directory) into `data/plugins/`.

---

## Bundled plugins

### treeview (`data/plugins/treeview/`)

A file tree panel showing the project directory. Optionally shows git status
markers next to changed files.

**Config options:**

```lua
config.treeview_size = 200 * SCALE   -- panel width
config.show_hidden_files = true       -- show dot files
config.treeview_git_enabled = true    -- show git status markers
config.treeview_git_update_rate = 2   -- seconds between git polls
```

Git markers: `A` added, `M` modified, `D` deleted, `?` untracked.

**Keybindings:** `Ctrl+\` or `F2` toggle the panel. `Ctrl+Shift+E` or `F3`
focus it. When focused, arrow keys navigate, `Return` opens the selected
item, `Delete` deletes it, `Ctrl+R` renames it, `Ctrl+Shift+N` creates a
new file, `Ctrl+Shift+Alt+N` creates a new directory.

### tab (`data/plugins/tab/`)

Manages tabs with a status bar indicator showing the current position
(`[2/5]`), jump-to-tab shortcuts, and tab reordering.

**Keybindings:**

| Binding | Action |
|---------|--------|
| `Ctrl+T` | New tab |
| `Ctrl+Shift+W` | Close current tab |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Next / previous tab |
| `Ctrl+1` – `Ctrl+9` | Jump to tab by number |
| `Ctrl+Shift+PageUp/PageDown` | Move tab left/right |

The tab indicator in the status bar is only shown when more than one tab
is open.

### window (`data/plugins/window/`)

Richer split management than the core root commands. Handles focus movement,
pane resizing, and shortcuts for common layouts.

**Keybindings:**

| Binding | Action |
|---------|--------|
| `Ctrl+\` | Vertical split (side by side) |
| `Ctrl+Shift+\` | Horizontal split (stacked) |
| `Alt+H/J/K/L` | Focus left/down/up/right |
| `Alt+W` / `Alt+P` | Cycle focus forward/backward |
| `Alt+C` | Close the focused pane |
| `Alt+O` | Close all other panes |
| `Alt+Arrow` | Resize the focused pane |
| `Alt+=` | Equalize pane sizes |

### autocomplete (`data/plugins/core/autocomplete.lua`)

Suggests completions as you type, pulled from words in all open documents.

```lua
config.autocomplete_max_suggestions = 6
```

`Tab` accepts the highlighted suggestion when the popup is open.

### projectsearch (`data/plugins/core/projectsearch.lua`)

Searches for a string across all files in the project. Results open in a
dedicated view showing file names, line numbers, and matches.

**Keybindings:** `Ctrl+Shift+F` opens the search. `F5` re-runs the last
search. In the results view, `Up`/`Down` navigate and `Return` opens the
selected file at the matching line.

### session (`data/plugins/core/session.lua`)

Tracks recently opened files and directories, and optionally restores the
last session on startup.

```lua
config.session_restore = false      -- reopen last session on startup
config.session_save_on_quit = true  -- save session automatically on quit
config.session_max_recent = 10      -- how many recent files/dirs to remember
```

**Keybindings:** `Ctrl+Shift+R` opens recent files, `Ctrl+Shift+D` opens
recent directories, `Ctrl+Alt+S` saves the session manually.

### autoreload (`data/plugins/core/autoreload.lua`)

Polls open documents for external changes and offers to reload them when
a file is modified by another process. No configuration needed.

### trimwhitespace (`data/plugins/core/trimwhitespace.lua`)

Strips trailing whitespace from every line whenever a document is saved.
Runs automatically — no configuration or keybinding needed.

### Vim mode (`data/plugins/vim/`)

The vim mode is a plugin. See [Vim Keybindings](vim-keybindings.md) for
full documentation.

---

## Language support

Syntax highlighting lives in `data/plugins/languages/`:

| File | Language |
|------|----------|
| `c.lua` | C |
| `js.lua` | JavaScript |
| `lua.lua` | Lua |
| `md.lua` | Markdown |
| `python.lua` | Python |
| `ts.lua` | TypeScript |

Language plugins register a syntax definition via `syntax.add()`. They match
files by extension pattern and define token types and patterns for the
tokenizer.

---

## Writing a plugin

A minimal plugin:

```lua
-- data/plugins/my_plugin.lua
local core    = require "core"
local command = require "core.input.command"
local keymap  = require "core.input.keymap"

command.add(nil, {
  ["my-plugin:hello"] = function()
    core.log("Hello from my plugin!")
  end,
})

keymap.add {
  ["ctrl+shift+h"] = "my-plugin:hello",
}
```

Drop this in `data/plugins/` and restart. The command appears in the command
palette and the keybinding works immediately.

### command.add(predicate, commands)

`predicate` controls when the command is active. `nil` means always. Pass a
class name to make it active only when a view of that type is focused:

```lua
command.add("core.views.docview", {
  ["my-plugin:do-something"] = function()
    local doc = core.active_view.doc
    core.log("Current file: %s", doc:get_name())
  end,
})
```

### core.log(fmt, ...)

Writes a message to the status bar and the log view. Uses `string.format`
conventions.

### core.add_thread(fn)

Registers a coroutine for background work. Yield a number to sleep:

```lua
core.add_thread(function()
  while true do
    -- do something periodically
    coroutine.yield(10)  -- sleep 10 seconds
  end
end)
```

### Accessing the active document

```lua
local doc = core.active_view.doc
local line, col = doc:get_selection()
local text = doc:get_text(line, col, line, math.huge)
```

### Adding a syntax definition

```lua
local syntax = require "core.syntax"

syntax.add {
  name = "My Language",
  files = "%.mylang$",
  patterns = {
    { pattern = "#.*",         type = "comment" },
    { pattern = { '"', '"' },  type = "string"  },
    { pattern = "%d+",         type = "number"  },
    { pattern = "[%a_][%w_]*", type = "symbol"  },
  },
  symbols = {
    ["if"]   = "keyword",
    ["else"] = "keyword",
    ["end"]  = "keyword",
  },
}
```

Token types that map to style colors: `"normal"`, `"symbol"`, `"comment"`,
`"keyword"`, `"keyword2"`, `"number"`, `"literal"`, `"string"`,
`"operator"`, `"function"`.

### Wrapping existing behavior

There's no event/hook system. Extend behavior by wrapping functions:

```lua
local Doc = require "core.doc"
local _save = Doc.save

function Doc:save(...)
  -- do something before saving
  _save(self, ...)
  -- do something after saving
end
```

This is how trimwhitespace hooks into saves, and how the vim plugin
intercepts keystrokes.