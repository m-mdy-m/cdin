# Plugins

## Overview

cdin has no package manager, no plugin registry, and no network access at
runtime. It also knows nothing about any specific plugin.

Plugins live in one of two places, and the difference decides how they load:

| root | what it is | who puts it there |
|------|------------|-------------------|
| `EXEDIR/data/plugins` | **bundled** — the mandatory set | a build, from [cdin-x](https://github.com/m-mdy-m/cdin-x) |
| `config.site_dir/plugins` | **site** — what you installed | `make install` in a cdin-x checkout, or you |

`data/core/plugins.lua` loads the bundled set first, unconditionally, and then
the site set as `config.plugins` selects it.

**The bundled set is not optional.** A build without the vim plugin, a default
theme and the fonts is not an editor that starts, so those are bundled and
always load — including under `--no-plugins`. This is the one thing cdin
delegates to cdin-x, and it happens at build time through a single variable,
`CDINX_DIR`.

Everything else is optional and lives in the site directory. With none of it,
cdin is a plain text editor with vim keys.

## The site directory

cdin resolves it, because cdin is what walks it: `config.site_path()`, which is
`config.site_dir` if you set it and otherwise
`<data_home>/cdin/<config.site_dirname>`. `data_home` is `$XDG_DATA_HOME` or
`~/.local/share` on Linux and macOS; on Windows `%LOCALAPPDATA%`, then
`%APPDATA%`, then `%USERPROFILE%\AppData\Local`, each plus `\cdin`.

`config.site_dirname` is the one knob. Change it and the loader, the theme
registry and cdin-x all move together:

```lua
-- ~/.config/cdin/user/init.lua
config.site_dirname = "extensions"     -- ~/.local/share/cdin/extensions
```

"site" is the word vim and neovim use for exactly this directory
(`:h site-dir`): third-party content, as opposed to the editor's own. It is
also what `make install` in cdin-x writes to by default. If you would rather
it said `extensions`, change that one line — and the installer's
`SITE_DIRNAME`, which `make test-site-dir` checks still agrees.

To install extensions into an installed cdin:

```sh
git clone https://github.com/m-mdy-m/cdin-x.git
cd cdin-x
make link      # symlink, for development — edits take effect on restart
make install   # copy
```

## Layout

A plugin is either a directory containing `init.lua`, or a single `.lua` file.
Both are loaded the same way.

```text
<site>/
  plugins/
    cdin-x/init.lua       -- the extension manager's entry point
    my-plugin/init.lua     -- a directory plugin
    my-thing.lua           -- a single-file plugin
  cdinx/                   -- the extension manager
  X/                       -- the extension catalog
```

Modules inside a plugin are required by their path from the site root, because
the loader puts `<site>/?.lua` and `<site>/?/init.lua` on `package.path`:

```lua
require "cdinx"                      -- <site>/cdinx/init.lua
require "X.core.treeview.api"        -- <site>/X/core/treeview/api.lua
```

Those roots are **appended**, never prepended. A site can add extensions to the
editor; it cannot shadow `core.*` or the bundled `X.core.vim.*`, which is what
stops a plugin from replacing the runtime it is extending.

## Choosing what loads

`config.plugins` selects the **site** set only. It does not affect the bundled
set.

| Value | Site plugins that load |
|-------|------------------------|
| `nil` (default) | all of them |
| `false` | none — the mandatory bundle still loads |
| `{ "palette", "finder" }` | exactly these |

```lua
-- ~/.config/cdin/user/init.lua

-- Load nothing from the site. The bundled set is unaffected.
config.plugins = false
```

A plugin you leave out is not gone — it is still on disk and can be loaded
later with `core:load-plugin`. A name that isn't there is logged and skipped,
so a config written on another machine still gets an editor.

### From the command line

```sh
cdin --no-plugins          # same as config.plugins = false
cdin -u NONE               # the Vim spelling of the same thing
```

The flag wins over `config.plugins`. It sets the *site* set to nothing; the
mandatory bundle still loads, because `--no-plugins` cannot turn vim off in an
editor that has no other modal editing.

### Loading a plugin after startup

| Command | Effect |
|---------|--------|
| `core:load-plugin <name>` | load a site plugin that wasn't autoloaded; accepts a comma-separated list |
| `core:unload-plugin <name>` | run its `unload()` and forget it |
| `core:list-plugins` | what is on disk, where it came from, and what of it is loaded |

These are the only way to change the set at runtime, and nothing about it
persists — after a restart you are back to whatever `config.plugins` says.

## What core owns, and what a plugin owns

A keymap binding that names a command nobody registered is the worst kind of
bug: the key press is consumed, nothing runs, and nothing errors. So core
draws a hard line, and `make test-plugins` enforces it.

**Everything in the core keymap is a core command.** All of them resolve with
zero plugins loaded.

The line is drawn at: *could this work with no input from the user?*

- `Ctrl+N` — new document. No input needed, so it is core, and it works in a
  bare editor.
- `Ctrl+P` — find file. Prompts, so it is a plugin.
- `Ctrl+Shift+P` — command palette. Prompts, so it is a plugin.
- `Ctrl+O` — open file. Prompts, so it is a plugin.

`Ctrl+C` / `Ctrl+A` in the log view are core.

A plugin that wants a key must bind it itself, in its own `init()`. Nothing in
`data/core/keymaps/default.lua` may name a plugin command, which is what keeps
the bare editor free of bindings that go nowhere.

The reverse also holds: core never requires a plugin. If a feature needs one,
it goes through a hook the plugin fills in — `core.register_help_shortcuts` for
the empty view's shortcut list, `core.register_status_pill` for status-bar
badges, `core.register_vcs_provider` for git status,
`core.register_recent_provider` for recents. With no plugin loaded, the hook is
simply unset and core renders nothing there.

### What moved to cdin-x, and what did not

These were runtime commands and are now optional plugins in cdin-x:

| was | is now | key |
|-----|--------|-----|
| `core:find-command` | `X/core/palette` | `Ctrl+Shift+P` |
| `core:find-file` | `X/core/finder` | `Ctrl+P` |
| `core:open-file` | `X/core/finder` | `Ctrl+O` |
| `core:open-folder` | `X/core/finder` | `Ctrl+Shift+O` |
| `core:reload-module` | `X/core/modules` | — |
| `core:open-user-module` | `X/core/modules` | — |
| `core:open-project-module` | `X/core/modules` | — |

What stayed in the runtime, because vim, shell, search, treeview, tab, window,
menu and the theme switcher are all written against it:

- `core.command_view` and CommandView
- the command registry (`command.add`, `command.remove`) and the keymap
  registry
- Doc, DocView, RootView, and the `doc:*` / `root:*` commands
- `core:set_project_dir(path)` — the project-directory transition

`core.command_view` is a **runtime service**, not an optional workflow. Do not
move it.

## Writing a plugin

Minimal single-file plugin:

```lua
-- <site>/plugins/my-plugin.lua
return {
  name = "my-plugin",

  init = function(core, config)
    local command = require "core.input.command"
    local keymap  = require "core.input.keymap"

    command.add(nil, {
      ["my-plugin:hello"] = function()
        core.log("Hello from my plugin!")
      end,
    })
    keymap.add { ["ctrl+shift+h"] = "my-plugin:hello" }
  end,

  unload = function()
    require("core.input.keymap").remove { ["ctrl+shift+h"] = "my-plugin:hello" }
    require("core.input.command").remove { "my-plugin:hello" }
  end,
}
```

Drop it in `<site>/plugins/` and restart.

`unload()` has to undo everything `init()` registered. A plugin that binds a
key and never removes it will fight the next thing to bind that key, and one
that is reloaded will accumulate a copy of its registrations per load. For
help entries, keep the handle `core.register_help_shortcuts` returns and hand it
back to `core.unregister_help_shortcuts`.

`init()` must be safe to call twice — guard it, as above.

A plugin with several files uses a directory:

```text
<site>/plugins/my-plugin/
  init.lua        -- returns the table above
  commands.lua
  keymap.lua
```

`init.lua` is the only entry point the loader looks at, and it is `dofile`d
rather than `require`d, so its body re-runs on every load while sibling modules
stay cached. Keep `require` calls for your own modules *inside* `init()`.

### Required and optional fields

Only `init` and `unload` are read by the loader. `name` is used as the display
name; without it the filename is used.

A failure inside `init()` is caught and logged — the plugin is skipped and the
editor carries on. A plugin that raises an error cannot take the editor down
with it. A failing *bundled* plugin is reported at error level and named
explicitly, because you will want to know a build is missing part of itself.

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
    coroutine.yield(10)  -- sleep 10 seconds
  end
end)
```

### core.set_project_dir(path)

Switches project directory. The working directory *is* the project, so this
validates the path, chdirs, resets the project file list and bumps the
revision. Returns `true`, or `false` plus a reason. cdin-x's folder workflow
calls this rather than chdir-ing itself.

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

## Running with no extensions

The site directory can be empty. cdin still starts, still edits, and still has
vim keys, because the mandatory bundle is part of the build rather than part of
the site.

```sh
cdin --no-plugins      # load nothing from the site
mv "$SITE" /tmp/site-backup && cdin    # or take the whole site away
```

You keep: file open/save/undo, editing, window and pane navigation, the log
view, the default theme, and the bundled vim plugin.

You lose: the command palette, find file, the open-file and open-folder
prompts, the project tree, tabs, split management, search, and the other
themes.

Nothing keystrokes into a wall. `Ctrl+P` with no `finder` installed is not bound
to anything, rather than bound to a command that does not exist.

Both halves of that are tested, because they fail differently:

```sh
make test-plugins     # the runtime half: no cdin-x, nothing read from disk
make test-workflows   # the cdin-x half: needs CDINX_DIR
make test-lua         # the unit + integration suite in tests/lua
```

`test_commands.lua` pins what the runtime owns. `test_workflows.lua` boots the
real loader against a cdin-x checkout and pins what it owns, that each of
`Ctrl+P` / `Ctrl+Shift+P` / `Ctrl+O` / `Ctrl+Shift+O` has exactly one command
bound to it, and that unloading `palette`, `finder` and `modules` takes the
commands and the keystrokes with them.

The single-owner assertion is the one worth having. `keymap.add` prepends, so a
second plugin binding a stroke it does not own is queued behind the first
rather than replacing it — nothing errors, and the shadowed binding only shows
up if you go looking.

## The contract

What cdin guarantees an extension, and what cdin-x may rely on, is written
down in [the extension contract](../architecture/extension-contract.md).
