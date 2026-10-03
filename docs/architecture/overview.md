# Architecture overview

cdin is two programs in one process. A small C layer owns the window, the
renderer and the OS; a Lua application is the actual editor. The C side knows
nothing about documents, views, commands or keybindings — everything a user would
call "the editor" is Lua in `data/core/`.

```
+---------------------------------------------+
|  src/          C11                           |
|                window, renderer, SDL,        |
|                OS calls, the Lua binding     |
+---------------------------------------------+
|  data/core/    Lua 5.4                       |
|                documents, views, commands,   |
|                keymap, syntax, style         |
+---------------------------------------------+
|  data/plugins/   bundled: vim, the manager   |
|  data/X/         those two plugins, verbatim |
|  data/cdinx/     the manager's own modules   |
|  data/themes/    the default theme            |
|  data/fonts/     the bundled fonts            |
+---------------------------------------------+
```

Everything below `data/core/` is **build output**, assembled from a cdin-x
checkout by `scripts/assemble_data.py`. The source tree has none of it.

The split is not a layering argument, it is a **capability** argument. The C
layer has no idea what a document is, so it cannot grow a bug about documents. It
exposes a window, a renderer, a clock, a clipboard, a directory listing and a Lua
state; everything else is Lua.

**Globals are forbidden at runtime.** `data/core/init.lua` loads
`core.runtime.strict` first, which errors on any undeclared global. It is the
first line of the editor for a reason: a stray global in a plugin is otherwise
invisible until two plugins pick the same name.

## Two repositories

```
cdin     the runtime        data/core/ only; knows nothing about any extension
cdin-x   the ecosystem      the mandatory set a build bundles (vim, the manager,
                            the default theme, the fonts), plus everything
                            optional that users install
```

The coupling between them is one build input: the variable `CDINX_DIR`, read in
`mk/bundle.mk`, `scripts/assemble_data.py` and `scripts/_cdin/*.py`. Nothing
under `src/` or `data/` refers to cdin-x, and a build never fetches anything.

A cdin checkout builds and runs on its own — `make bin` needs no cdin-x — and a
cdin-x checkout installs, updates and removes itself without going near an editor
installation. The cost is one line in a build script. What it buys is that "the
editor is broken" and "an extension misbehaves" stop being the same
investigation.

The contract cdin provides, and cdin-x may rely on, is
[the extension contract](extension-contract.md). Read it before changing anything
about `config.site_dir`, the loader or the theme registry.

## Boot

### The C side

`main()` in `src/main.c`, in order:

1. `utils_get_exe_filename` → the executable's own path
2. `setup_logging` → opens `cdin-log.txt` **next to the binary**, appending
3. `cdin_init_setup()`
4. `SDL_Init(VIDEO | EVENTS)`; the window is 80% of the display's usable bounds
5. `window_create`, `window_set_icon`, `SDL_StartTextInput`
6. `ren_init` — the renderer, and its caches
7. `utils_get_scale` → `SCALE`, the display scale factor
8. a Lua state, all standard libraries, then `api_load_libs` which puts
   `system`, `renderer` and `core` on it
9. `lua_setup_globals` → `VERSION`, `PLATFORM`, `SCALE`, `EXEFILE`, `ARGS`
10. `lua_run_core`

`lua_run_core` is a string of Lua under `xpcall`, and it is short enough to read
in full:

```lua
PATHSEP = package.config:sub(1, 1)
EXEDIR  = EXEFILE:match('^(.+)[/\\].*$') or '.'
package.path = EXEDIR .. '/data/?.lua;'      .. package.path
package.path = EXEDIR .. '/data/?/init.lua;' .. package.path
core = require('core')
core.init()
core.run()
```

Note the two `package.path` entries are **prepended** — the editor's own modules
come first, so nothing can shadow them. The site directory is *appended* later, by
the plugin loader, which is the opposite and equally deliberate: an extension may
extend the editor, not replace it.

### The Lua side

Requiring `core` already does a lot, before `core.init()` is ever called:

| | |
| --- | --- |
| `core.runtime.strict` | globals are errors from here on |
| `core.config` | every default, and the path resolution |
| `core.preboot` | reads `session.lua` — the theme and last directory, before anything can depend on them |
| `core.style` | loads the fonts, sets every colour fallback, applies `config.theme` |
| `core.logging`, `core.help`, `core.lifecycle` | installed onto `core` |

`core.style` applying the theme **before plugins run** is why cdin-x registers its
theme roots from its entry point's `init()`, and why a theme that only exists in
an extension's root can fall back at startup. The runtime retries after plugins
load, unconditionally — nothing watches the theme files.

Then `core.init()`:

```
 1. parse ARGS          --no-plugins / -u, and the file and directory arguments
 2. resolve the project directory   an argument, else the session's last_dir, else EXEDIR
 3. system.chdir         the working directory IS the project
 4. state.setup_state    frame_start, clip stack, log buffer, docs, threads
 5. build the view tree  see below
 6. install the runtime  open_doc, reload_module, clip rects, events, the frame loop
 7. start the project scan thread
 8. command.add_defaults()          every runtime command, every default binding
 9. your ~/.config/cdin/user/init.lua
10. --no-plugins overrides config.plugins
11. plugins.load_all()              bundled first, then site
12. re-apply config.theme if it resolves now
13. load .lite_project.lua
14. open the files named on the command line
```

**Steps 8–11 are the order everything else depends on.** The default keymap is
installed before your config runs, so a key you set is one a plugin can override;
and your config runs before plugins, so it can `require` a plugin's module but
not its side effects. The argument for each is in
[configuration](../guides/configuration.md#when-it-runs-and-why-that-matters).

**Step 3 is the load-bearing one for everything project-shaped.** The file list,
the ignore rules and the git status all come from the working directory, so
`core.project_dir` is `system.absolute_path(".")` after the `chdir` and not a
parameter anywhere.

## The view tree

There are four views and they never move:

```
root_node
├── a:  TitleBar
└── b:
    ├── a:  the content area   DocView, EmptyView or LogView
    └── b:
        ├── a:  CommandView    the prompt, hidden until something opens it
        └── b:  StatusView
```

`rootview/node.lua` owns the tree: `split`, `close_active_view`, `get_child_overlapping_point`,
`get_locked_size`. A plugin that opens a pane — cdin-x's treeview and its
manager panel both do — calls `node:split(dir, view, true)` on the active node
and becomes part of the same tree rather than a layer above it.
`RootView:attach_side_view` is the better interface and is the documented one;
both cdin-x panels still split the active node, which is fine while there is one
panel and a conflict the day there are two. See
[side panels](extension-contract.md#side-panels).

**A node holds a list of views.** That is what `root:switch-to-pane-view-N` and
`root:move-pane-view-*` reach, and it is why those names say *pane view*: the
word "tab" belongs to cdin-x's plugin, which is a different concept, and the
runtime's names were changed to say so. The old `-tab-` spellings remain as
aliases.

**A node can have a locked size**, which is how a panel stays full-width. Every
`root:` command's predicate is `not node:get_locked_size()`, so the bindings go
quiet while a panel holds the pane rather than fighting it.

## The frame loop

`core.run()`, in `data/core/loop.lua`:

```lua
while true do
  core.frame_start = system.get_time()
  local did_redraw = core.step()
  run_threads()
  if not did_redraw and not system.window_has_focus() then
    system.wait_event(0.25)
  end
  system.sleep(max(0, 1 / config.fps - elapsed))
end
```

`core.step()` is one frame:

1. Poll events. Mouse motion is **coalesced** across the poll and dispatched once
   with the accumulated delta; a `textinput` is suppressed when the key that
   produced it was already handled by the keymap, which is what stops a character
   being typed twice.
2. Resize the root view, then `root_view:update()`.
3. **Return early if nothing set `core.redraw`.** A frame that changed nothing is
   not drawn, and an unfocused window sleeps on `wait_event` instead of spinning.
   This is the idle-cost story, and it is why `core.redraw = true` after changing
   state a view has cached is not optional.
4. Reap documents no view references any more.
5. Set the window title, if it changed.
6. `begin_frame`, set the root clip rect, `root_view:draw()`, `end_frame`.

`run_threads` is a scheduler, not a queue. It walks `core.threads`, resumes each
one whose `wake` time has passed, treats a yielded value as a delay in seconds,
and **yields back to the frame if the time budget is blown** — checked per thread,
not per pass, so a thread that sleeps for a second costs one resume and then
nothing.

`core.threads` has `__mode = "k"`, so a thread registered with a `weak_ref` key
dies with its key. That is how the highlighter's per-document thread stops when
the document does.

**Never block this loop with I/O.** A coroutine that runs a shell command without
yielding stalls every keypress, and on some platforms the window stops responding
to the compositor as well.

## Data flow

```
keypress ──> keymap.on_key_pressed
              └─ stroke -> [commands]  ──> command.perform
                                                 └─ predicate ──> fn
                                                       │
   document edit <──────────────────────────────────────┘
        │
        └─> Doc._after_* hooks, Highlighter:invalidate, core.redraw = true
                                                        │
   draw <───────────────────────────────────────────────┘
        │
        └─> View:draw ──> style colours ──> renderer ──> SDL
```

Two properties make that diagram work:

**Commands are addressed by name across every boundary.** `command.perform`
("doc:save") is a string, not a function reference, so a binding, a menu entry and
a vim ex-command can all reach the same thing without holding a reference to a
module they did not load. A command name is a public interface.

**Predicates, not registration, decide what is available.** `command.perform`
returns `false` when the predicate fails and does nothing. That is what lets
<kbd>Return</kbd> be bound to `{ "command:submit", "doc:newline" }` and work in
both a prompt and a document, and it is why the runtime can route a key to a
command an optional plugin might own without erroring when it is absent.

## Where to look

| | |
| --- | --- |
| [`data/core/init.lua`](../../data/core/init.lua) | the boot order above, in the order it happens |
| [`data/core/loop.lua`](../../data/core/loop.lua) | the frame loop and the thread scheduler |
| [`data/core/state.lua`](../../data/core/state.lua) | the initial state and the view tree |
| [`data/core/rootview/`](../../data/core/rootview) | the pane tree |
| [`data/core/views/`](../../data/core/views) | DocView, CommandView, StatusView, TitleBar, LogView |
| [`data/core/doc/`](../../data/core/doc) | the document, the highlighter, the word translations |
| [`data/core/input/`](../../data/core/input) | the command and key registries |
| [`data/core/plugins.lua`](../../data/core/plugins.lua) | the loader |
| [`data/core/themes.lua`](../../data/core/themes.lua) | the theme registry |
| [`src/`](../../src) | the C layer |
