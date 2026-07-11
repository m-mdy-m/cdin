# Architecture Overview

cdin is two programs in one process: a small C runtime that owns the window,
the renderer, and the OS, and a Lua application that is the actual editor.
The C side is deliberately dumb — it knows nothing about documents, tabs, or
keybindings. Everything a user would call "the editor" is Lua in `data/`.

```
┌────────────────────────────────────────────────┐
│  data/  (Lua)                                  │
│   core/      documents, views, commands,       │
│              keymap, syntax, styling           │
│   plugins/   treeview, vim mode, autocomplete, │
│              tabs, window splits, session, ... │
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

The C layer has one job: give Lua a window to draw into and a way to talk
to the OS. It handles SDL initialization, window creation, the software
renderer, font rasterization, filesystem operations, and logging. All of
that is exposed to Lua through two libraries registered at startup: `system`
(events, clipboard, file I/O, process control) and `renderer` (draw rects,
text, and clipping regions).

The renderer is a software rasterizer — no GPU dependency. It divides the
screen into a grid of cells, hashes each draw command per cell, and only
redraws cells whose content actually changed. An idle editor draws almost
nothing.

Fonts are rasterized with the vendored `stb_truetype`. The app icon is
compiled in as a C array (`src/icon.inl`) generated from `scripts/icon.svg`
by `scripts/gen_icon.py` — which is why Python is a build dependency.

`src/` is organized into subsystems: `core/` (window, boot, config, logger,
utils), `api/` (the Lua-facing C API), `ui/` (renderer and its cell cache),
`fs/` (path and filesystem ops exposed to Lua), `lua/` (Lua state setup and
entry point), and `search/` (the C-side text search used by find/replace).

`main()` does exactly this: set up logging, initialize SDL3, create a window
at 80% of the usable display size, initialize the renderer, create a Lua 5.4
state, register `system` and `renderer`, set globals (`ARGS`, `SCALE`,
`EXEFILE`, etc.), and run `data/core/init.lua`. From that point the Lua side
owns the process; when its main loop returns, `main()` cleans up and exits.

## The Lua side (`data/`)

`data/core/init.lua` builds the editor. It parses command-line arguments,
constructs the view tree, starts the project scanner, loads every plugin,
then your user module, then the project module, and enters the frame loop.

The important core modules:

| Module | Role |
|---|---|
| `core.doc` | the text buffer: lines, selection, undo/redo, load/save |
| `core.views.docview` | renders a Doc: caret, scrolling, mouse handling, gutter |
| `core.views.view` / `core.rootview` | base view class and the split/tab tree |
| `core.input.command` | named commands with availability predicates |
| `core.input.keymap` | maps keystrokes to command names |
| `core.views.commandview` | the one-line input prompt with suggestions |
| `core.views.statusview` / `core.views.titlebar` | editor chrome |
| `core.syntax` / `core.doc.highlighter` | syntax highlighting (incremental, runs as a coroutine) |
| `core.style` | all colors, fonts and metrics in one table |
| `core.utils.object` | minimal single-inheritance class system (`Object:extend()`) |
| `core.utils.common` | fuzzy matching, path suggestion, misc utilities |
| `core.runtime.strict` | errors on undeclared globals |

Three mechanisms tie everything together, and every plugin uses them:

**Commands** — every user-visible action is a named command registered with
`command.add(predicate, table)`. The predicate makes commands contextual.
The command palette, the keymap, and plugins all speak command names.

**Coroutine threads** — `core.add_thread` registers cooperative background
tasks. The frame loop resumes each one every frame; yielding a number sleeps
that many seconds. The project scanner, autoreload, syntax highlighting, and
the tree view's git polling all run this way. There are no OS threads in the
Lua side.

**Wrapping** — there is no event/hook system. Code extends behavior by
replacing a function and calling the original. For example, the vim plugin
wraps `keymap.on_key_pressed` to intercept keys, and trimwhitespace wraps
`Doc.save`.

## Plugins

Plugins are not sandboxed and not special — they are `require`d at startup
(every `.lua` under `data/plugins/`, recursively) and patch the same tables
the core uses. A broken plugin logs the error and startup continues.

The bundled plugins:

- `plugins/core/` — autocomplete, autoreload, project search, session
  (recent files/dirs, session restore), trimwhitespace
- `plugins/languages/` — syntax definitions for C, JavaScript, TypeScript,
  Lua, Markdown, Python
- `plugins/tab/` — multi-tab management with tab bar indicator, reordering,
  and jump-to-tab shortcuts
- `plugins/treeview/` — file tree panel with git status markers
- `plugins/vim/` — the modal layer: `vimode.lua` (modes and normal-mode
  keys), `ex.lua` (the `:` command line), `fmenu.lua` (the `m` action
  menu), `shell.lua` (shell commands into scratch buffers)
- `plugins/window/` — window split, focus, and resize commands (a richer
  replacement for the core root split commands)

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
(flags, SDL/Lua discovery via pkg-config), `build.mk` (compile rules),
`install.mk` (install/uninstall). Objects and the binary land in
`build/<platform>-<build>/`. Details in [Building from Source](../guides/building.md).