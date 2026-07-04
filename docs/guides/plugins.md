# Plugins

## Overview

Plugins in cdin are Lua files placed in `data/plugins/`. They're loaded automatically at startup, after the core but before `data/user/init.lua`. If a plugin fails to load, the error is logged and startup continues — a broken plugin won't crash the editor.

Plugins are organized into subdirectories. The loader scans recursively, so you can put related files in a folder and structure them however makes sense.

There's no package manager. To install a plugin, copy the file (or directory) into `data/plugins/`.

---

## Bundled plugins

### treeview (`data/plugins/core/treeview.lua`)

A file tree panel showing the project directory. Displays files and directories, and optionally marks changed files using git status.

**Config options:**

```lua
config.treeview_size = 200 * SCALE   -- panel width in pixels
config.show_hidden_files = true       -- show dot files
config.treeview_git_enabled = true    -- show git status markers
config.treeview_git_update_rate = 2   -- seconds between git polls
```

Git status markers appear next to file names: `A` for added, `M` for modified, `D` for deleted, `?` for untracked.

**Keybinding:**

`Ctrl+Shift+H` — toggle visibility of hidden files (bound in `data/user/init.lua`; you can rebind it).

**Commands:**

| Command | Description |
|---------|-------------|
| `treeview:toggle-hidden` | Toggle hidden file visibility |
| `treeview:focus-and-refresh` | Focus the tree and rescan |
| `treeview:refresh` | Rescan without changing focus |

### autocomplete (`data/plugins/core/autocomplete.lua`)

Suggests completions as you type, drawn from words in all open documents.

**Config options:**

```lua
config.autocomplete_max_suggestions = 6
```

Press `Tab` while a suggestion list is open to accept the highlighted suggestion.

### projectsearch (`data/plugins/core/projectsearch.lua`)

Searches for a string across all files in the project. Results open in a dedicated view showing file names, line numbers, and matching lines.

**Command:** `project-search:find` — there's no default keybinding; add one in your user config if you use this often:

```lua
keymap.add {
  ["ctrl+shift+f"] = "project-search:find",
}
```

### autoreload (`data/plugins/core/autoreload.lua`)

Polls open documents for external changes. When a file is modified by another process, the editor offers to reload it.

### trimwhitespace (`data/plugins/core/trimwhitespace.lua`)

Strips trailing whitespace from every line whenever a document is saved. Runs automatically on every save with no configuration needed.

### Vim mode (`data/plugins/vim/`)

The vim mode is itself a plugin. See [Vim Keybindings](vim-keybindings.md) for full documentation.

---

## Language support

Syntax highlighting is provided by language plugins in `data/plugins/languages/`:

| File | Language |
|------|----------|
| `c.lua` | C |
| `js.lua` | JavaScript |
| `lua.lua` | Lua |
| `md.lua` | Markdown |
| `python.lua` | Python |
| `ts.lua` | TypeScript |

Language plugins register a syntax definition via `syntax.add()`. They match files by extension pattern and define token types and patterns for the tokenizer.

---

## Writing a plugin

A minimal plugin looks like this:

```lua
-- data/plugins/my_plugin.lua
local core    = require "core"
local command = require "core.command"
local keymap  = require "core.keymap"

command.add(nil, {
  ["my-plugin:hello"] = function()
    core.log("Hello from my plugin!")
  end,
})

keymap.add {
  ["ctrl+shift+h"] = "my-plugin:hello",
}
```

Drop this file into `data/plugins/` and restart. The command appears in the command palette and the keybinding works immediately.

### `command.add(predicate, commands)`

`predicate` controls when the command is active. Pass `nil` for commands that are always available. Pass a class (like `"core.docview"`) to make the command active only when a view of that type is focused.

```lua
-- only active when a document is open
command.add("core.docview", {
  ["my-plugin:do-something"] = function()
    local doc = core.active_view.doc
    core.log("Current file: %s", doc:get_name())
  end,
})
```

### `core.log(fmt, ...)`

Writes a message to the status bar and the log view. Uses `string.format` conventions.

### `core.add_thread(fn)`

Registers a coroutine. Use `coroutine.yield(seconds)` inside it to sleep between iterations. Useful for background polling.

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
    { pattern = "#.*",         type = "comment"  },
    { pattern = { '"', '"' },  type = "string"   },
    { pattern = "%d+",         type = "number"   },
    { pattern = "[%a_][%w_]*", type = "symbol"   },
  },
  symbols = {
    ["if"]    = "keyword",
    ["else"]  = "keyword",
    ["end"]   = "keyword",
  },
}
```

Token types that map to style colors: `"normal"`, `"symbol"`, `"comment"`, `"keyword"`, `"keyword2"`, `"number"`, `"literal"`, `"string"`, `"operator"`, `"function"`.