# The extension contract

This is the whole of what cdin guarantees an extension, and therefore the whole
of what [cdin-x](https://github.com/m-mdy-m/cdin-x) is allowed to assume.

**If something is not in this document, it is not a contract, and changing it is
a breaking change.** That is the test to apply to any change you are considering:
if cdin-x would plausibly have depended on it, it belongs here first, and the
change is a major version.

Two repositories, one boundary:

- **cdin** is the editor runtime. Its `data/` contains only `core/`. It knows
  nothing about any extension.
- **cdin-x** is the extension ecosystem. It provides the mandatory set a build
  bundles — vim mode, the default theme, the fonts — and the optional workflows
  users install.

## The plugin protocol

An entry point is a directory with an `init.lua`, or a single `.lua` file. It
must return a table.

```lua
local M = {}
function M.init(core, config) end   -- called as mod.init(core, config)
function M.unload() end             -- optional
return M
```

**`init` takes two arguments, positionally.** `function M.init(config)` compiles
and then reads the `core` table as its config. This one is worth checking by eye
rather than by testing.

**`init` must tolerate being called twice.** The loader `dofile`s the entry
point, so its body re-runs on every load, while sibling modules pulled in with
`require` stay cached. Without a guard, an enable/disable cycle doubles every
registration the body performs.

**`unload` is the counterpart, and using it is what makes the cycle work.** The
runtime calls it from `core:unload-plugin` and nothing else — not on exit, not
on a failure.

## The two roots

| root | who puts it there | when it loads |
| --- | --- | --- |
| `EXEDIR/data/plugins` | a build, from cdin-x | **always**, whatever `config.plugins` or `--no-plugins` say |
| `config.site_path()/plugins` | the user, or cdin-x's manager | only if `config.plugins` selects it |

**Every bundled entry loads, unconditionally.** That is what makes a build a
runnable editor rather than a runtime with plugins available, and it is why
`config.plugins = false` and `--no-plugins` cannot disable vim mode. There is no
mechanism to skip a bundled plugin, by design.

**A bundled plugin always wins over a site plugin of the same name** — on disk and
at runtime. The scan is bundled-first and first-seen-wins.

**Entry points are loaded in sorted order by name.** Reproducible, and *not*
dependency order. If a plugin needs something another plugin registered, it must
tolerate running first. Ordering on declared dependencies is cdin-x's job, and
the runtime has no concept of one.

### `config.plugins`

Selects the **site set only**, in three forms:

| value | site plugins |
| --- | --- |
| `nil` | all of them |
| `false` | none |
| `{ "a", "b" }` | only the named ones |

Anything else is treated as `nil`. Names are directory names under `plugins/`.

### The error policy

| | a failing plugin is |
| --- | --- |
| bundled | reported with `core.error`, and the rest still load |
| site | logged with `core.log`, and skipped |

**The editor always starts.** An entry point that does not return a table, or an
`init` that raises, costs you that plugin and nothing else.

A plugin registered by name that is not on disk reports `no such plugin: <name>`.
Loading by name is not gated on the site set being enabled — `config.plugins`
decides what loads *on its own*, and naming one explicitly is the `:packadd` case.

## `package.path`

The site directory is **appended**:

```
<site>/?.lua
<site>/?/init.lua
```

The editor's own `EXEDIR/data/?.lua` and `EXEDIR/data/?/init.lua` were
**prepended** at bootstrap and stay ahead of it. So an extension can extend the
editor and cannot shadow the core it extends. A site plugin that wants to change a
core behaviour has to do it through one of the seams below.

## Commands

```lua
command.add(predicate, map, overwrite)
command.remove(names)               -- a name, or a list of names
command.names_of(map)               -- the sorted names a map would register
command.perform(name)               -- true if it ran
command.get_all_valid()             -- what is available right now
command.prettify_name(name)         -- for display
```

A command is a name, a predicate and a function. `predicate` has three legal
forms:

| form | available when |
| --- | --- |
| `nil` | always |
| a **string** — a module path | `require`d, and its returned function says so |
| a **class table** | `core.active_view` is an instance of it |

**Availability is not registration.** `command.perform` returns `false` and does
nothing when the predicate fails — it does not raise. That is what lets the
runtime route <kbd>Enter</kbd> to `command:submit` and fall through to
`doc:newline` when no prompt is open, and what lets it route a key to a command an
*optional* plugin might own without erroring when the plugin is absent.

`overwrite` permits re-registering an existing name. Without it `command.add`
asserts: `command already exists: <name>`. That is deliberate — two plugins
claiming one name is a bug, and the alternative is a binding that silently runs
the wrong thing.

`command.remove` exists so an `unload` can genuinely detach itself rather than
leaving commands that keep firing, or that assert on the next load.

## Keys

```lua
keymap.add(map, overwrite)
keymap.remove(map)                  -- the same shape that was added
keymap.get_binding(command)         -- the reverse lookup
```

Keys map a keystroke to a **command name**, never to a function. That is what lets
a keymap, a menu entry and an ex-command all reach the same thing without holding
a reference to a module they did not load.

A value may be a **list**, which is a fallback chain: the commands are tried in
order and the first whose predicate holds runs. That is how <kbd>Ctrl</kbd>+<kbd>D</kbd>
belongs to find-and-replace while a match is selected and to the document
otherwise, with neither knowing the other exists.

**Without `overwrite`, `keymap.add` prepends** and the existing chain stays alive
behind yours. With it, yours replaces the binding outright. This is stable
behaviour, and the second argument is written at every call site in the tree
rather than defaulted.

Keystroke spelling: lowercase, modifiers in `ctrl+alt+shift` order joined by `+`,
arrows as `left`/`right`/`up`/`down`, and `keypad enter` distinct from `return`.

`keymap.remove` detaches only the commands you name, so another plugin bound to
the same stroke keeps working. **Hand back the same table you added** — a rebuilt
one removes nothing, because a stroke maps to a list of names and a fresh list is
not the one registered.

## Themes

```lua
local themes = require "core.themes"
themes.add_root(dir)      -- a non-directory is ignored, not registered
themes.rescan()
themes.path(name)         -- the resolved path, or nil
themes.names()            -- what is visible
themes.load(name)         -- the table, or nil plus a message
themes.apply(style, name)
```

A theme is one file: `<root>/<name>/theme.lua` returning a table of colours. The
layout is the contract; where the root is, is not.

**Roots are searched in this order**, and the first hit wins:

1. `config.user_dir/themes`
2. `EXEDIR/data/themes`
3. every root added with `add_root`, in the order added

So a user theme can override a bundled one by name, and an extension can ship
themes without either knowing about the other.

`add_root` ignores a path that is not a directory rather than registering it, so a
caller cannot poison the search order with something that will never resolve.
Adding the same root twice is a no-op. `rescan` recomputes the list in place,
because a root that appears after load time would otherwise be loadable by name
but never listed.

**Apply semantics** (`themes.apply`): every key except `name` and `syntax` is
copied onto `style`, and the nested `syntax` table is merged key by key. A colour
is a hex string, or a table used as-is — which is how `search_highlight` is
`{ r, g, b, a }`. **Keys the theme omits keep their current value**, so a
six-colour theme works and a `type` with no theme key falls back rather than
failing.

`config.theme` is applied at `style.lua` load time, **before any plugin runs.** A
theme that only exists in a root an extension registers later can therefore fall
back at startup; the runtime retries once plugins have loaded. That retry is
unconditional — the `config.theme_auto_reload` key exists in `config.lua` but is
read nowhere, so it does not control this.

## Styles

```lua
style.set_fallback(key, hex)   -- a default for a key a plugin reads
style.set_theme(name)           -- apply now
style.syntax[key]               -- a resolved colour, after any theme
```

`style.set_fallback` is public so extensions can register their own defaults
rather than the runtime hardcoding colours only one of them uses.

The six `git_*` keys **do** have core fallbacks and are a shared vocabulary, not
one plugin's colours — every bundled theme defines all six, and several
independent places read them. The six `vim_*` keys deliberately have **none**;
they are cdin-x's, and a hand-written theme that omits them gets `nil` there.

## Syntax

```lua
require("core.syntax").add { files = …, headers = …, comment = …,
                              patterns = {…}, symbols = {…} }
```

`add` appends; the lookup walks the list **backwards**, so the last definition
that claims a filename wins. There is **no `remove`**, no validation, and no
manifest — which is why a definition added from an extension's `init()` lasts for
the session and why a syntax definition's `unload` is empty in every one of them.

`files` and `headers` are Lua patterns or lists of them. **The filename is tried
before the shebang**, and `headers` is matched against the first 128 bytes of
line 1.

`type` values are meant to be keys under `style.syntax`, and there is no
validation. A `type` with no matching style key is **not** uniformly rescued: one
of the three draw paths in `docview.lua` falls back to `normal`, the other two
pass the missing colour to the renderer and get opaque white. Define every `type`
your definitions emit.
[Syntax highlighting](../guides/syntax.md) has the format, the tokenizer and the
honest limits — including that the delimiter state is one level deep, not a stack.

## The prompt

```lua
core.command_view:enter(label, submit, suggest, cancel)
core.command_view:set_text(text)
core.command_view:get_text()
```

`submit(text, suggestion)`, `suggest(text) -> items`, and `cancel` may all be
`nil`. An item is anything with a `text` field; cdin's own `doc:go-to-line` adds
a `__tostring` metatable so one value can be both a display string and carry a
payload.

`enter` is a no-op if a prompt is already open, so a second one cannot displace
the first.

**This is the only prompt primitive.** An extension that builds its own gets a
second implementation of the same thing, and the one in the extension is the one
nobody tests.

## Side panels

```lua
core.root_view:attach_side_view(view, side, opts)   -- returns the node
core.root_view:detach_view(view)                    -- true if it was attached
core.root_view:get_edge_node(side)                  -- the outermost node
```

| | |
| --- | --- |
| `side` | `"left"` or `"right"`; anything else is `"right"` |
| `opts.locked` | keep the pane out of document routing. **default true** |
| `opts.width` | the pane's share of the split, `0.01`–`0.99`. Omit it and the divider keeps the node's own value |

**Attach to an edge, not to the active pane.** `get_active_node()` answers "the
node that happens to hold focus", which is a property of the moment: a panel
that splits it lands wherever the user last clicked. With one panel that is
merely surprising; with two it is a conflict neither extension can win — the
second split is taken out of the *first panel's* node, so one of them ends up
between the document and the other, and which one depends on load order.

`attach_side_view` is **idempotent and non-stealing**: a view already in the
tree is left where it is, and a fresh attach restores the previous active view.
Calling it from `init()` on every enable cycle is therefore safe. Focusing a
panel is a separate concern — `core.set_active_view(view)`.

**Sides are horizontal, and the rows are not sides.** The layout is built out of
rows as well as columns — the title bar on top, the status bar and the command
line at the bottom, each a locked pane — and for those `b` is the *bottom* of
the window, not the right of it. `get_edge_node` walks `a`/`b` through
horizontal splits only and takes `a` on a vertical one, so a side panel always
lands in the content region.

**Any number of locked panes can share an edge.** A locked pane's width comes
from its view, and each locked pane in a split is given the width it asked for —
so two panels side by side are two columns, not one column and one remainder.

`detach_view` is the counterpart, and an extension that attaches should detach
in `unload`: a disabled extension that leaves its pane behind is an empty column
the user has no key to close. An emptied pane collapses into its sibling, unless
the sibling is itself a locked side panel — then it becomes the empty view rather
than reclaiming space that is not free. A pane emptied *by `detach_view`* always
gives its space back: nothing is managing it any more, so a locked column of
nothing is not something to leave behind.

**These three functions are the whole of the pane-tree interface.** Reaching into
`node.views`, `node.divider` or `rootview/node.lua` is still not guaranteed.

## Providers

Four registries. Register, and the runtime uses your answer; the runtime never
learns what a plugin is for.

```lua
core.register_status_pill(key, fn)
    -- fn() -> nil, or (text, bg_key, fg_key). nil draws nothing.
    -- bg_key / fg_key are NAMES of style keys, resolved as style[bg_key].

core.register_vcs_provider { is_ignored, refresh_ignored_now, status }

core.register_recent_provider(provider)

local handle = core.register_help_shortcuts { { key = "ctrl+p", desc = "…",
                                               section = true } }
core.unregister_help_shortcuts(handle)
```

`status_pill` is **keyed**, so `core._status_pills[key] = nil` removes one. There
is no `remove` function, and the registry having no `remove` is why the keyed form
matters — a plugin that registered a pill is the only thing that should clear it.

**`core.register_vcs_provider` is the one that is not usable from `init()`.** It
is installed from inside `project.thread`, and that coroutine does not run until
`core.run()` starts — after every plugin's `init()`. A plugin calling it from
`init()` gets `attempt to call a nil value`. Defer it with `core.add_thread`, or
tolerate a nil function and register later.

This is stated here rather than hidden because cdin-x depends on it, and because
it is the only part of this page that does not currently hold. It is a one-line
fix — move the installation out of `M.thread` and to require time, alongside the
other three.

`register_vcs_provider` is read for file ignoring (the project scan) and for the
branch and ahead/behind display in the status bar. With none registered, both
simply render nothing.

`register_recent_provider` supplies the recent-item list on the empty view. The
empty view reads it through one accessor and does not know which plugin, if any,
registered.

`register_help_shortcuts` appends entries **after** the core-owned ones, in
registration order, and returns an opaque handle. Keep the handle: a plugin that
does not clean up accumulates one copy of every shortcut it advertises per load.
`unregister_help_shortcuts` returns `false` for an unknown handle rather than
raising, because `unload` also runs on the error path.

`register_help_shortcuts` is installed by `core.help` **before any view is
constructed**, deliberately — a plugin calls it from its own `init()` and must not
depend on which views happened to exist first.

## Document hooks

```lua
table.insert(Doc._before_save, fn)   -- fn(doc) before writing
table.insert(Doc._after_save,  fn)   -- fn(doc) after writing
table.insert(Doc._after_load,  fn)   -- fn(doc) after reading
```

Plain lists, called with the document. **Preferred over wrapping `Doc.save`**,
because a wrapper is in the path of every save and unloading is
`table.remove` rather than a restore-everything dance.

## What the runtime hands you

| | |
| --- | --- |
| `core.add_thread(fn, weak_ref)` | a coroutine; `coroutine.yield(seconds)` sleeps. `weak_ref` keys the thread so it dies with its owner. **Never block the frame loop with I/O** |
| `core.try(fn, ...)` | run it, log any error, return whether it worked |
| `core.log(fmt, …)`, `core.log_quiet(…)`, `core.error(fmt, …)` | printf-style; `error` reaches the log view |
| `core.open_doc(filename)` | open or create; returns the existing one if already open |
| `core.get_views_referencing_doc(doc)` | |
| `core.active_view`, `core.last_active_view`, `core.set_active_view(view)` | |
| `core.active_docview()` | the active view if it is a document view, else `nil` |
| `core.project_dir`, `core.project_files` | the working directory, and the scan's result |
| `core.set_project_dir(path)` | change directory; the scan follows |
| `core.reload_module(name)` | drop from `package.loaded`, require again, **fold the new fields into the old table** |
| `core.push_clip_rect` / `core.pop_clip_rect` | scoped clipping, for a custom view |
| `core.redraw = true` | after any state change a view caches |
| `core.quit(force)` | see below |
| `core.root_view:attach_side_view` / `detach_view` / `get_edge_node` | a side panel's whole interface; see [Side panels](#side-panels) |
| `core.load_project_module()` | load `.lite_project.lua` |

**`core.reload_module` folds new fields into the old table** so a module somebody
is still holding stays valid instead of becoming a second, stale copy. It does
**not** undo what the module registered while loading — a module that registers
commands at its top level will collide with itself on reload. Write modules so
their top level is declarations and their `init()` does the registering.

**`core.quit` is a seam.** It is the one function extensions wrap to run on exit.
`core.quit(true)` is the unwrap target: it skips the unsaved-changes prompt. That
pair is why a wrapper must call the original rather than reimplementing it.

**`core.quit` returns; it does not exit.** It sets the flag the frame loop
checks, and the process ends when `core.run()` returns — after `lua_close`, with
`main()` destroying the window itself. It used to call `os.exit()`, and that was
a hang rather than an exit: quitting from inside a keymap, a command and a
submit callback put `atexit(SDL_Quit)` in the middle of SDL's own event dispatch,
and what came back was a live process with no window and no event loop — every
key dead, nothing drawn, unkillable from inside. Two consequences for an
extension: **everything you do in a `core.quit` wrapper must be synchronous**,
because threads scheduled with `core.add_thread` will never run; and you cannot
tell from inside the wrapper that the process is about to end.

**`core.set_project_dir` is a runtime operation, not a workflow.** The working
directory *is* the project; the file list and revision the views read are runtime
state. The prompt that asks which directory is a workflow, and lives in an
extension that calls this.

## Configuration

```lua
local config = require "core.config"
config.site_path()      -- resolve the site directory; call it, do not cache it
config.user_dir         -- where init.lua and your themes are
config.data_home
config.site_dirname     -- "site" by default
config.plugins
```

`config.site_path()` is a **function, not a field.** `~/.config/cdin/user/init.lua`
runs after `core.config` was required, so a path computed at load time would be
fixed before you could change it and the one knob would silently do nothing.

`config.site_dirname` is the editor's to choose — `"site"` is what vim and
neovim call exactly this directory (`:h site-dir`) — and every consumer follows it:
the loader, the theme registry, and cdin-x. **Extensions read `config.site_path()`
rather than computing a path of their own**, so a user who renames the site
directory renames it for both halves at once. That is the whole of what an
extension needs to know about paths.

## Globals and the host tables

| global | |
| --- | --- |
| `EXEDIR` | the executable's directory — where `data/` is |
| `EXEFILE`, `PATHSEP`, `PLATFORM`, `VERSION`, `ARGS`, `SCALE` | |
| `system.*` | events, clipboard, time, `chdir`, `list_dir`, `absolute_path`, `get_file_info`, `exec`, `popen`, `fuzzy_match`, dialogs |
| `renderer.*` | fonts, text, rectangles, clipping, the frame |
| `core.fs`, `core.style`, `core.themes`, `core.syntax`, `core.utils.common`, `core.utils.object` | |

**`SCALE` is the display content scale, and it is `1.0` on every non-Windows
platform** — `utils_get_scale()` returns a real value only on Windows. Everything
sized in pixels multiplies by it, which is why a theme sets colours and never
sizes.

**Globals are an error at runtime.** `core.runtime.strict` loads first and raises
on any undeclared global, so a stray global in an extension is caught at load
rather than when two extensions pick the same name. The caveat: it fires only on a
*missing* key, so the six globals C sets (`ARGS`, `VERSION`, `PLATFORM`, `SCALE`,
`EXEFILE`, `PATHSEP`) can be reassigned silently. Do not write to them.

`core.fs` is the module to use for paths and filesystem work. `join` handles the
separator; a plugin that concatenates `"/"` produces a second directory level on
Windows.

## What is not guaranteed

**There is no hook or event system.** Not one, deliberately. For anything not
covered above, the supported technique is to wrap the function, call the original,
and restore it in `unload`:

```lua
local original = { update = RootView.update }
RootView.update = function(...) original.update(...) end

function M.unload()
  RootView.update = original.update
end
```

Several places in cdin-x are written this way. They are **working, not
endorsed**: none of the following is part of this contract, and any of them may
change in a release.

| wrapped today | by |
| --- | --- |
| `keymap.on_key_pressed` | vim mode |
| `RootView.on_text_input` / `update` / `draw` | autocomplete |
| `StatusView.get_items` | the tab counter |
| `core.quit` | session |

Wrapping the outermost function, and restoring it, is the whole of the technique.
A wrapper that leaks is a wrapper that runs again next load.

**Also not guaranteed**, and worth being explicit about since extensions reach
for all of them:

| | |
| --- | --- |
| load order between plugins | alphabetical by name, nothing more |
| `command.map`, `keymap.map`, `keymap.reverse_map` | internal tables; use the functions |
| `node.views`, `node.active_view`, `node.divider`, `rootview/node.lua` internals | the pane tree's shape; use `attach_side_view` / `detach_view` |
| `DocView.translate` and the translation table | a module detail, not an interface |
| `core._status_pills`, `core._help_shortcut_groups` | documented as the removal path, and still internals |
| `core.project` | use `core.set_project_dir` |
| `core.window_title`, `core.frame_start` | frame-loop internals |
| `core.on_error` | defined in `lifecycle.lua` and **called by nothing** |
| `config.theme_auto_reload`, `config.line_limit`, `config.symbol_pattern` | defined in `config.lua` and **read nowhere** |
| `core.project` | does not exist; it is a local in `core/init.lua`. Use `core.set_project_dir` |
| any module under `core.views.*` except the ones named above | |

**And these commands do not exist**, which is the other half of the contract —
cdin-x owns them:

```
core:open-file      core:open-folder      core:find-command
core:find-file      core:reload-module    core:open-user-module
core:open-project-module
```

The runtime references two of them — `empty-view:open-file` and
`empty-view:open-folder` delegate by name — which is why the delegation is safe:
`command.perform` on an unregistered name returns `false` and does nothing, so
those two are no-ops on a bare editor rather than errors. The empty view's
shortcut list is correspondingly short, and printed entries are only ever ones
that work.

**The line the runtime draws** is stated in `data/core/commands/core.lua` and is
worth repeating here because it is the criterion everything else follows from:

> Could this work without any input from the user? `core:open-file` cannot: it
> prompts for a path. `core:new-doc` can.

## Changing any of this

1. Say so in [the changelog](../../CHANGELOG.md) under `[Unreleased]`.
2. If cdin-x could plausibly have depended on it, **this is a breaking change**
   and it is a major version — not because the API is precious, but because the
   whole point of the split is that both halves can be wrong independently, and
   that only works if the boundary is written down.
3. `make test-workflows` is the suite that would catch it, and it needs
   `CDINX_DIR`. It is the only test that reads cdin-x, and it exists because a
   stale runtime binding and a duplicated plugin binding are both invisible from
   one repository alone.
