# Architecture Overview

cdin is two programs in one process: a small C runtime that owns the window,
the renderer and the OS, and a Lua application that is the actual editor.
The C side is deliberately dumb — it knows nothing about documents, tabs or
keybindings. Everything a user would call "the editor" is Lua in `data/`.

```
┌────────────────────────────────────────────────┐
│  data/  (Lua)                                  │
│   core/      documents, views, commands,       │
│              keymap, syntax, styling           │
│   plugins/   treeview, vim mode, autocomplete, │
│              project search, languages, ...    │
│   user/      your config and themes            │
├────────────────────────────────────────────────┤
│  system / renderer  (Lua ↔ C API)              │
├────────────────────────────────────────────────┤
│  src/  (C)                                     │
│   SDL3 window + events, software renderer,     │
│   font rasterization (stb_truetype), logging   │
└────────────────────────────────────────────────┘
```

This split comes from lite, which cdin forked from. The boundary is the
useful property: the C side changes rarely and is easy to audit; the Lua
side is where all editing behavior lives and can be changed without a
compiler.

## The C side (`src/`)

```
main.c              startup: SDL init, window creation, Lua state, hands off to Lua
initial.c           pre-SDL process setup
api/api.c           registers the Lua ↔ C API
api/system.c        the `system` Lua library: events, clipboard, filesystem,
                    window control, process handling
api/renderer.c      the `renderer` Lua library: draw rects, text, clipping
api/renderer_font.c font loading and metrics for Lua
core/windows.c      SDL window creation, icon (from generated src/icon.inl)
core/lua_connector.c sets Lua globals (ARGS, SCALE, EXEFILE, ...) and runs data/core/init.lua
rendrer/renderer.c  software rasterizer drawing into the SDL surface
rendrer/rendrer_cache.c cell-based cache that skips redrawing unchanged screen regions
helpers/logger.c    leveled logging to stderr and cdin.log (next to the binary)
global_config.c     compile-time configuration
utils.c             misc helpers (exe path, content scale)
```

`main()` does exactly this: set up logging, init SDL3, create a window sized
to 80% of the usable display, init the renderer, create a Lua 5.4 state,
register the `system` and `renderer` libraries, set globals, and run
`data/core/init.lua`. From that point the Lua side owns the process; when
its main loop returns, `main()` cleans up and exits.

Rendering is a software rasterizer (no GPU dependency) with a cache: the
screen is divided into cells, each draw command is hashed per cell, and only
cells whose hash changed since the last frame get redrawn. Fonts are
rasterized with the vendored `stb_truetype` (`lib/stb/`).

The only C-side build artifact besides objects is `src/icon.inl`, generated
from `scripts/icon.svg` by `scripts/gen_icon.py` (this is why the build
needs Python).

## The Lua side (`data/`)

`data/core/init.lua` builds the editor: it parses the command-line arguments
(directories become the project, files get opened), constructs the view tree,
starts the project scanner, loads every plugin, then your user module, then
the project module, and finally enters the frame loop.

The important core modules:

| Module | Role |
|---|---|
| `core.doc` | the text buffer: lines, selection, undo/redo, load/save |
| `core.docview` | renders a Doc: caret, scrolling, mouse handling, gutter |
| `core.view` / `core.rootview` | base view class and the split/tab tree that lays views out |
| `core.command` | named commands with availability predicates |
| `core.keymap` | maps key strokes to command names |
| `core.commandview` | the one-line input prompt with suggestions |
| `core.statusview` / `core.titlebar` / `core.logview` | chrome |
| `core.syntax` / `core.tokenizer` / `core.doc.highlighter` | syntax highlighting (incremental, runs in a background coroutine) |
| `core.style` | all colors, fonts and metrics in one table |
| `core.object` | minimal single-inheritance class system (`Object:extend()`) |
| `core.common` | fuzzy matching, path suggestion, misc utilities |
| `core.strict` | errors on undeclared globals, keeps the codebase honest |

Three mechanisms tie everything together, and they are worth knowing because
every plugin uses them:

**Commands** — every user-visible action is a named command registered with
`command.add(predicate, table)`. The predicate makes commands contextual.
The command palette, the keymap and plugins all speak command names.

**Coroutine threads** — `core.add_thread` registers cooperative background
tasks. The frame loop resumes each one every frame; yielding a number sleeps
that many seconds. The project scanner, autoreload, syntax highlighting and
the tree view's git polling all run this way. There are no OS threads in the
Lua side.

**Wrapping** — there is no event/hook system. Code extends behavior by
replacing a function and calling the original, e.g. the vim plugin wraps
`keymap.on_key_pressed` to intercept keys, and trimwhitespace wraps
`Doc.save`.

## Plugins

Plugins are not sandboxed and not special — they are `require`d at startup
(every `.lua` under `data/plugins/`, recursively) and patch the same tables
the core uses.

- `plugins/core/` — treeview (file tree with git status), autocomplete,
  project search, autoreload, trimwhitespace
- `plugins/languages/` — syntax definitions for C, JavaScript, TypeScript,
  Lua, Markdown, Python
- `plugins/vim/` — the modal layer: `vimode.lua` (modes and keys),
  `ex.lua` (the `:` command line), `fmenu.lua` + `menu_engine.lua`
  (the `m` action menu), `fs.lua` (filesystem helpers), `shell.lua`
  (shell commands into scratch buffers)

Load order: core → plugins (directory order) → `user/init.lua` →
`.lite_project.lua`. Later wins, which is why the user module can override
anything.

## The frame loop

One iteration: poll SDL events and dispatch them to the keymap and views →
resume every background coroutine → recompute layout → redraw (through the
cell cache, so an idle editor draws almost nothing) → sleep to hold
`config.fps` (60 by default).

## Build system

GNU make, split into small includes under `mk/`: `platform.mk` (OS and
compiler detection), `version.mk` (version from git tags), `config.mk`
(flags, SDL/Lua discovery via pkg-config), `build.mk` (compile rules,
dependency checks), `install.mk` (install/uninstall). Objects and the
binary land in `build/<platform>-<build>/`. Details in
[Building from Source](../guides/building.md).
