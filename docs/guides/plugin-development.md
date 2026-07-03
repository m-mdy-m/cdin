# Plugin Development

A plugin is a Lua file in `data/plugins/`. At startup the editor walks that
directory recursively and `require`s every `.lua` file it finds —
subdirectories become module prefixes, so `data/plugins/vim/ex.lua` is the
module `plugins.vim.ex`. There is no manifest, no registration and no API
boundary: a plugin is ordinary code running in the same Lua state as the
editor core, with full access to everything.

If a plugin errors at load time the editor keeps starting, logs the error,
and opens the log view so you notice.

The bundled plugins are the best reference. Rough sizes, to give you an idea
of what's feasible:

```
plugins/core/trimwhitespace.lua    35 lines   strip trailing whitespace on save
plugins/core/autoreload.lua        61 lines   reload files changed on disk
plugins/languages/lua.lua          51 lines   Lua syntax highlighting
plugins/core/autocomplete.lua     284 lines   completion popup
plugins/core/treeview.lua         699 lines   the file tree panel
```

## The core modules

```lua
local core    = require "core"          -- editor state, logging, threads
local command = require "core.command"  -- define and run commands
local keymap  = require "core.keymap"   -- key bindings
local config  = require "core.config"   -- configuration table
local style   = require "core.style"    -- colors, fonts, metrics
local common  = require "core.common"   -- fuzzy match, path utils, misc helpers
local Doc     = require "core.doc"      -- document (text buffer) class
local DocView = require "core.docview"  -- the editor view class
local View    = require "core.view"     -- base class for custom views
local syntax  = require "core.syntax"   -- syntax definitions
```

Useful `core` functions: `core.log(fmt, ...)` and `core.error(fmt, ...)`
write to the status bar and log view (`core.log_quiet` skips the status
bar); `core.try(fn, ...)` is a pcall that reports errors properly;
`core.active_view`, `core.docs`, `core.project_files` and
`core.root_view` expose the editor state.

## Commands

Commands are the unit of functionality. Everything the editor can do — every
menu entry, every keybinding — is a named command.

```lua
command.add(predicate, {
  ["my-plugin:do-thing"] = function()
    core.log("did the thing")
  end,
})
```

The predicate decides when the command is available:

- `nil` — always available
- a module name string like `"core.docview"` — available when the active
  view is an instance of that class
- a function returning a boolean — checked each time

Run a command from code with `command.perform("my-plugin:do-thing")`. Users
find it in the command palette (`Ctrl+Shift+P`) under the prettified name
"My Plugin: Do Thing".

## Keybindings

```lua
keymap.add { ["ctrl+alt+t"] = "my-plugin:do-thing" }
```

Several commands can share a stroke; the first one whose predicate matches
wins. This is how `Tab` can mean "complete", "indent" or "next suggestion"
depending on context.

## Background work

The editor is single-threaded. Long-running work goes in a coroutine
registered with `core.add_thread`; yield frequently, and yield a number to
sleep for that many seconds:

```lua
core.add_thread(function()
  while true do
    for _, doc in ipairs(core.docs) do
      -- do a small amount of work
      coroutine.yield()
    end
    coroutine.yield(5)  -- wait 5 seconds before the next pass
  end
end)
```

This is how the project scanner, autoreload and the tree view's git polling
work.

## Extending behavior by wrapping

There is no hook or event system. The convention is to wrap the function you
want to extend, keeping a reference to the original:

```lua
local Doc = require "core.doc"

local save = Doc.save
function Doc.save(self, ...)
  -- do something before saving
  return save(self, ...)
end
```

`trimwhitespace.lua` does exactly this to trim trailing whitespace on every
save, and `vimode.lua` wraps `keymap.on_key_pressed` to intercept keys before
the normal keymap sees them.

## Syntax highlighting

Language support is a plugin too — one `syntax.add` call with file patterns,
match patterns and a keyword table. See `data/plugins/languages/lua.lua` for
a complete example; it's about 50 lines. Currently bundled: C, JavaScript,
TypeScript, Lua, Markdown and Python.

```lua
local syntax = require "core.syntax"

syntax.add {
  files = "%.mylang$",
  comment = "//",
  patterns = {
    { pattern = { '"', '"', '\\' }, type = "string" },
    { pattern = "//.-\n",           type = "comment" },
    { pattern = "[%a_][%w_]*",      type = "symbol" },
  },
  symbols = {
    ["if"] = "keyword",
    ["true"] = "literal",
  },
}
```

Token types (`keyword`, `keyword2`, `string`, `comment`, `number`,
`operator`, `function`, `symbol`, `literal`) map to colors in the active
theme's `style.syntax` table.

## Custom views

For UI beyond commands, subclass `View` (see `data/core/object.lua` for the
object system — `Class:extend()`, `Class.super`). Override `draw()` and
`update()`, then attach the view to the layout via `core.root_view`. The
tree view (`plugins/core/treeview.lua`) and the project search results view
(`plugins/core/projectsearch.lua`) are the two in-tree examples.

## Development loop

The build symlinks `data/` next to the binary, so when you run a development
build (`make run`) your plugin edits are picked up on the next editor start.
For pure-Lua changes you can often skip the restart with the
`core:reload-module` command. Errors land in the log view
(`core:open-log`) and in `cdin.log` next to the binary.
