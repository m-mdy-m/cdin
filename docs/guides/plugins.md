# Plugins

cdin has a loader, a site directory, and an extension contract. It does **not**
have a package manager, a plugin registry, a dependency resolver, or network
access at runtime.

That is not a missing feature so much as a boundary. The loader is about twenty
lines of intent; the interesting part is what it deliberately refuses to do, and
why each refusal matters. Everything above that line — installing, versioning,
dependency order, a UI for it — is
[cdin-x](https://github.com/m-mdy-m/cdin-x), which is free to be as large as it
needs to be.

**And a build now ships that half**, marked `essential` next to vim, so the panel
is reachable in every editor rather than only in one that was set up by hand.
Which of the two you are talking about matters: `data/core/` owns what *loads*,
cdin-x owns what is *installed*. [The manager](#the-manager) below.

## Two roots, and the difference decides everything

| root | what it is | who puts it there | when it loads |
| --- | --- | --- | --- |
| `EXEDIR/data/plugins` | **bundled** — the mandatory set | a build, from cdin-x | always, whatever `config.plugins` says |
| `config.site_path()/plugins` | **site** — what you installed | you, or cdin-x's manager | only if `config.plugins` selects it |

**Every bundled entry loads, always.** Not "the ones that are enabled" — all of
them. That is what makes a build a runnable editor rather than a runtime with
plugins available, and it is why `config.plugins = false` and `--no-plugins`
cannot turn off vim mode: a cdin without it is not an editor, and a debugging
flag is not a policy.

A failing **bundled** plugin is reported at error level and the rest still load.
A failing **site** plugin is logged and skipped. The editor always starts, because
an editor that refuses to open is a worse bug than a missing feature.

**A bundled plugin always wins over a site plugin of the same name** — on disk and
at runtime. The scan is bundled-first and first-seen-wins, so a name is never
loaded twice from two places.

## What counts as a plugin

Either of these, in either root:

```
plugins/my-plugin/init.lua      a directory
plugins/my-plugin.lua           a single file
```

The name is the directory name or the filename without `.lua`. Entry points are
loaded in **sorted order by name**, not in filesystem order — so load order is
reproducible, and a plugin cannot rely on being scanned first because its name
sorted earlier by accident.

Load order within a root is alphabetical, and **that is not dependency order.** If
plugin A needs something plugin B registered, A has to be robust to running
first. Where that is not acceptable, the answer is cdin-x's manager, which sorts
on declared dependencies.

## What a plugin is handed

```lua
-- <site>/plugins/my-plugin/init.lua
local M = {}

function M.init(core, config)
  -- called with two positional arguments
end

function M.unload()             -- optional
end

return M                        -- must return a table
```

Two things are easy to get wrong here, and both fail quietly.

**`init` receives two arguments, positionally.** `function M.init(config)` compiles
perfectly and then reads the `core` table as your config. Worth checking by eye
rather than by testing.

**The entry point must return a table.** A `nil` return is reported as
`entry point must return a table`, not as a missing-plugin error.

**`init` may be called more than once.** The loader `dofile`s the entry point — it
does not `require` it — so a reload re-runs the file's body, while sibling modules
you pulled in with `require` stay cached from the first load. Guard it:

```lua
local loaded = false
function M.init(core, config)
  if loaded then return end
  loaded = true
  -- …
end
```

Without the guard, an enable/disable cycle doubles every registration the body
performs. The loader's `command.add` duplicate-name assert is what turns that
into a visible failure rather than a silent one — but only for commands.

**`unload` is the counterpart, and using it is what makes the cycle work.** A
plugin that registers and never unregisters accumulates one copy per load. The
loader calls it on `core:unload-plugin` and nothing else; it is not called on
exit.

## Requiring your own files

The site directory is added to `package.path` as `site/?.lua` and
`site/?/init.lua`, so inside a plugin:

```lua
require("my-plugin.commands")     -- → <site>/plugins/my-plugin/commands.lua
require("my-plugin.util")         -- → <site>/plugins/my-plugin/util/init.lua
```

**The roots are appended, never prepended.** A site plugin may extend the editor;
it may not shadow the core it extends, nor the bundled modules the runtime loads
first. That is why a plugin that wants to replace a `core.*` behaviour has to do
it through one of the seams below rather than by putting a file in the way.

`require`-ing a *plugin's module* from your `init.lua` works, because your file
runs before the plugins and the site path is already extended. Its `init()` side
effects have not run at that point — you are loading code, not starting a
plugin.

## The seams

There is no hook or event system. There are a set of provider registries and
document hooks, and beyond that you wrap a function and call the original. Every
seam below is documented in
[the extension contract](../architecture/extension-contract.md), which is the
normative version.

### Provider registries

The clean ones. Register, and the runtime uses your answer; the runtime never
learns what a plugin is for.

| call | what it claims |
| --- | --- |
| `core.register_status_pill(key, fn)` | one coloured badge at the left of the status bar; `fn` returns `nil` or `(text, bg_key, fg_key)` |
| `core.register_vcs_provider(provider)` | `{ is_ignored, refresh_ignored_now, status }` — file ignoring and the git branch in the status bar |
| `core.register_recent_provider(provider)` | the recent-item list on the empty view |
| `core.register_help_shortcuts(list)` | entries for the quick-reference list on the empty view; returns a handle |
| `core.unregister_help_shortcuts(handle)` | removes that group |
| `style.set_fallback(key, hex)` | a default colour for a key your plugin reads |

**A pill returns style *key names*, not colours.** The second and third values are
resolved as `style[bg_key]` and `style[fg_key]`, so they must be names of keys a
theme defines — `"vim_normal_bg"`, `"accent"` — and that is what lets the badge
follow a theme change. A literal colour there will not work.

A pill whose function returns `nil` draws nothing, so the badge disappears rather
than sitting there showing a zero. `register_status_pill` is keyed, so
`core._status_pills[key] = nil` removes one — documented here because the
registry has no `remove` and a plugin that registered it is the only thing that
should clear it.

**`core.register_vcs_provider` cannot be called from `init()`.** Unlike the other
three, it is installed from inside the project scanner's thread body, and that
thread does not start until the frame loop runs — after every plugin's `init()`
has returned. Calling it there gives `attempt to call a nil value`. This is a real
rough edge in the runtime, not a mistake on your part: defer the call with
`core.add_thread`, or tolerate a nil function and register on a later pass.

`core.unregister_help_shortcuts` returns `false` for a handle that was never
registered rather than raising, because `unload` also runs on the error path and a
second call should be harmless.

### Document hooks

Three lists on the `Doc` class, called with the document:

```lua
table.insert(Doc._before_save, fn)   -- fn(doc) before writing to disk
table.insert(Doc._after_save,  fn)   -- fn(doc) after writing
table.insert(Doc._after_load,  fn)   -- fn(doc) after reading
```

These are preferred over wrapping `Doc.save`, because wrapping it puts your code
in the path of every save including ones you did not want to touch, and because
unloading is `table.remove` rather than a restore-everything dance. cdin-x's
`trimwhitespace` uses `_before_save` and its `autoreload` uses `_after_load` and
`_after_save`; neither wraps anything.

### The prompt

`core.command_view` is the one prompt primitive:

```lua
core.command_view:enter(label, submit, suggest, cancel)
core.command_view:set_text(text)
```

`submit(text, suggestion)` and `suggest(text) -> items` may both be `nil`. An item
is anything with a `text` field; cdin's own `doc:go-to-line` adds a `__tostring`
metatable so an item can be both a display string and carry a payload.

A plugin that builds a second prompt rather than using this one ends up with two
implementations of the same thing, and the one in the plugin is the one nobody
tests.

### Wrapping a function

For everything else, save the original and put it back on unload:

```lua
local original = { update = RootView.update }
RootView.update = function(...) original.update(...) end

function M.unload()
  RootView.update = original.update
end
```

`core.quit`, `keymap.on_key_pressed`, `StatusView.get_items` and
`RootView.on_text_input` / `update` / `draw` are wrapped this way by the
extensions that need them. **Wrap the outermost one, and restore it in
`unload`** — a wrapper that leaks is a wrapper that runs again next load.

### What cdin hands you outright

| | |
| --- | --- |
| `core.add_thread(fn, weak_ref)` | a coroutine; `coroutine.yield(seconds)` to sleep. **Never block the frame loop with I/O** |
| `core.try(fn, ...)` | run it, log the error, return whether it worked |
| `core.log(fmt, …)` / `core.log_quiet(…)` / `core.error(fmt, …)` | printf-style; the `error` level goes to the log view |
| `core.open_doc(filename)` | open or create; returns the existing one if already open |
| `core.active_view`, `core.last_active_view` | the focused view, and the one before it |
| `core.active_docview()` | the active view if it is a document view, else `nil` |
| `core.set_active_view(view)` | focus a view |
| `core.set_project_dir(path)` | change the working directory; the project scan follows |
| `core.reload_module(name)` | drop from `package.loaded`, require again, **fold the new fields back into the old table** |
| `core.push_clip_rect` / `core.pop_clip_rect` | scoped clipping, for a custom view |
| `core.redraw = true` | after any state change a view caches |

`core.reload_module` folding new fields into the old table is the detail worth
knowing: a module somebody is still holding stays valid instead of becoming a
second, stale copy of itself. What it does **not** undo is what the module
registered while loading. A module that registers commands at its top level and
gets reloaded will collide with itself — so write modules so their top level is
declarations and their `init()` does the registering.

`core.set_project_dir` is a runtime operation, not a workflow. The working
directory *is* the project; the file list and revision the views read are runtime
state. The prompt that asks which directory is a workflow, and lives in a plugin
that calls this.

## Managing the set at runtime

Three commands, and they are the only way to change the loaded set after startup:

| command | does |
| --- | --- |
| `core:list-plugins` | what is on disk in both roots, and which of it is loaded |
| `core:load-plugin <name>…` | load by name, whatever `config.plugins` said |
| `core:unload-plugin <name>…` | run its `unload()` and forget it |

Comma-separated or whitespace-separated lists work. With no argument they report
what to do rather than failing silently.

These are the `:packadd` case: `config.plugins` decides what loads on its own,
and naming a plugin explicitly is how a bare editor stays *useful* rather than
merely empty. Loading is deliberately not gated on the site set being enabled, so
`config.plugins = false` still leaves you a way to bring one thing in.

**Nothing here persists.** There is no saved state — what you load this way is
gone at exit, and the only thing that survives a restart is what `config.plugins`
asks for. Persistence is the package manager's job, and the manager is in every
build: see below.

## The manager

Not a runtime command, and not a plugin you have to install. It is marked
`essential` in [cdin-x](https://github.com/m-mdy-m/cdin-x), so `make` bundles it
the way it bundles vim, and the panel is a keystroke away in any build:

| key | does |
| --- | --- |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd> | open / close the extension panel |
| <kbd>M</kbd> | the same, in vim normal mode |
| <kbd>J</kbd> / <kbd>K</kbd> | move |
| <kbd>/</kbd> or <kbd>Ctrl</kbd>+<kbd>F</kbd> | search; type to filter |
| <kbd>Space</kbd> / <kbd>Return</kbd> | enable or disable |
| <kbd>I</kbd> / <kbd>U</kbd> | install / remove |
| <kbd>D</kbd> | details |
| <kbd>R</kbd> | rescan |

It lists what the build carries, what is installed, and what the catalog offers,
grouped by category, and it filters as you type. **What it can install depends
on what is on disk**: with only a build present it lists the set the build ships
and nothing else, because installing means copying files that have to exist
somewhere. Install cdin-x and the whole catalog is there.

Two things about it worth knowing, because they are deliberate. The extensions
the build ships show as **in editor**: present, listed, and not the manager's to
remove. And enable/disable *does* persist — in cdin-x's own state file, keyed by
name, so the panel's idea of what is on survives a restart without the runtime
growing a registry of its own.

## Installing your own

Drop a directory or a `.lua` file into `config.site_path()/plugins/` and restart,
or run `core:load-plugin <name>`. To find out where that is:

```lua
require("core.config").site_path()
```

`config.site_path()` rather than a field on the table, deliberately — see
[configuration](configuration.md#where-things-live). Your plugin can be loaded by
name while it is still being written, which is the whole development loop.

For a package manager, an in-app UI, dependency resolution or anything that
survives a restart, that is cdin-x, and you want it rather than a second
implementation here.

## The two things that are not yours

**The bundled set.** The loader knows nothing about where it came from. Whatever
produced it is not this repository's business; only the build knows, and it knows
it as a path — `CDINX_DIR`. A build never fetches anything.

**The site directory's name.** `config.site_dirname` is the editor's to choose,
and cdin-x reads `config.site_path()` rather than computing a path of its own.
That is the whole of what it knows about where anything lives, and it is why
renaming the site directory renames it for both halves at once.

## Files

| file | holds |
| --- | --- |
| [`data/core/plugins.lua`](../../data/core/plugins.lua) | the loader: both roots, entry points, the error policy |
| [`data/core/config.lua`](../../data/core/config.lua) | `config.plugins` and the path resolution |
| [`data/core/commands/plugin.lua`](../../data/core/commands/plugin.lua) | the three management commands |
| [`data/core/help.lua`](../../data/core/help.lua) | the help-shortcut registry |
| [`data/core/project.lua`](../../data/core/project.lua) | the VCS provider hook, and the file scan |
| [`data/core/docs.lua`](../../data/core/docs.lua) | `core.open_doc`, `core.reload_module`, clipping |
| [`data/core/init.lua`](../../data/core/init.lua) | `core.add_thread`, `core.set_active_view`, `core.quit` |
| [`data/core/loop.lua`](../../data/core/loop.lua) | `core.step`, `core.run`, the thread scheduler, and where `core.redraw` is consumed |
| [`data/core/preboot.lua`](../../data/core/preboot.lua) | the session state read before anything else loads |
| [`data/core/lifecycle.lua`](../../data/core/lifecycle.lua) | the project module, and an uncalled `core.on_error` |
