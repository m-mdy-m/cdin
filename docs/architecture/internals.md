# Internals

This is a deeper look at how cdin works under the hood. The
[Architecture Overview](overview.md) covers the big picture. This document
goes into the pieces you'll need to understand if you're working on the C
layer, the renderer, or the frame loop.

---

## Startup sequence

`main()` in `src/main.c` does this, in order:

1. Set up logging (to `cdin.log` next to the binary)
2. Initialize SDL3 (or SDL2) — window, event queue, display info
3. Create the window at 80% of the usable display area
4. Initialize the software renderer
5. Create a Lua 5.4 state
6. Register the `system` and `renderer` C libraries
7. Set globals that Lua will read: `ARGS`, `SCALE`, `EXEFILE`, `VERSION`,
   `PLATFORM`, `MOD_VERSION`
8. Call `data/core/init.lua`

From step 8 onward the Lua side owns the process. When the Lua main loop
returns, `main()` tears down SDL and exits.

`data/core/init.lua` does the rest of startup: parses `ARGS`, creates the
initial view tree, starts background threads (project scanner, etc.), loads
every plugin under `data/plugins/`, loads `data/user/init.lua`, loads the
per-project `.lite_project.lua` if it exists, and enters the frame loop.

---

## The frame loop

One iteration of the loop, in `data/core/loop.lua`:

1. **Poll events** — SDL events (keyboard, mouse, window resize, quit, …) are
   pulled off the queue one by one and dispatched. Key events go through the
   keymap, which maps them to command names. Mouse events go to the focused
   view.

2. **Resume background threads** — every coroutine registered with
   `core.add_thread` is resumed. If it yielded a number, it sleeps that many
   seconds before being resumed again. If it errors, the error is logged and
   the thread is removed.

3. **Compute layout** — the root view recalculates positions and sizes for
   all views. This is cheap when nothing has changed.

4. **Redraw** — each view's `draw` method is called. The software renderer
   collects draw commands (rectangles, text, lines) and runs them through the
   cell cache before writing to the framebuffer.

5. **Sleep** — the loop sleeps to hold the target FPS (`config.fps`, default
   60). When nothing is happening, the redraw step touches almost nothing and
   the loop mostly just sleeps.

The loop keeps a `core.redraw` flag. Any code that changes editor state can
set `core.redraw = true` to ensure the next frame does a full redraw. Most
code doesn't need to do this explicitly — the views handle it automatically
when their content changes.

---

## The renderer

The renderer is in `src/ui/renderer.c` and `src/ui/renderer_cache.c`.

It's a software rasterizer — no GPU, no OpenGL, no Vulkan. This is
intentional: it means cdin has zero graphics driver dependency and works
identically everywhere SDL runs.

The cell cache is the key performance trick. The screen is divided into a
uniform grid of cells (each a fixed number of pixels). Every draw command
is associated with the cell or cells it touches. The renderer hashes each
cell's draw commands, and only redraws a cell if its hash changed since the
last frame. A frame where nothing moves — the cursor is still, no background
poll just fired — touches almost no cells and writes almost nothing to the
framebuffer.

This means the renderer's cost scales with what changed, not with what's on
screen. A 4K display with a lot of text but no activity is essentially free.

The Lua side calls the renderer through two modules registered at startup:

- `renderer` — draw calls: `renderer.draw_rect`, `renderer.draw_text`,
  `renderer.set_clip_rect`, `renderer.get_size`, font loading
- `system` — OS calls: `system.get_time`, `system.sleep`, `system.exec`,
  `system.get_clipboard`, `system.set_clipboard`, file operations, process
  control

These are the only way Lua talks to C (besides standard Lua libraries).
Everything else — documents, views, commands, plugins — is pure Lua.

---

## The Lua/C boundary

The boundary is defined in `src/api/`. Two libraries are registered when
the Lua state starts: `system` (`src/api/system.c`) and `renderer`
(`src/api/renderer.c` plus `src/api/renderer_font.c`).

Adding a function to the C API means:

1. Writing a C function with the signature `static int fname(lua_State *L)`
2. Pushing and checking arguments with `lua_check*` and `lua_to*`
3. Pushing return values with `lua_push*`
4. Adding the function to the registration table in `luaL_Reg` at the bottom
   of the file

The Lua side calls these like ordinary Lua functions — `system.exec(cmd)`,
`renderer.draw_rect(x, y, w, h, color)`. There's no binding layer or
marshaling system.

`src/api/renderer_compat.c` is a thin compatibility shim that translates
between the SDL2 and SDL3 renderer APIs. It exists so the same Lua API works
regardless of which SDL version is installed.

---

## The document model

`data/core/doc/init.lua` is the text buffer. It represents a file as a table
of lines, where each line is a string. The document has no concept of bytes
or encoding — it works in Lua strings (which are byte arrays), and the
renderer handles Unicode correctly because stb_truetype does.

Key operations:

- `doc:insert(line, col, text)` — insert at a position
- `doc:remove(line1, col1, line2, col2)` — remove a range
- `doc:get_text(line1, col1, line2, col2)` — read a range
- `doc:get_selection()` — return the current selection endpoints
- `doc:set_selection(l1, c1, l2, c2)` — set the selection

Every mutating operation goes through `doc:raw_insert` and `doc:raw_remove`,
which record undo entries. Undo is a flat list of entries with a pointer into
it; `doc:undo()` and `doc:redo()` walk the list.

`data/core/doc/highlighter.lua` is a syntax highlighter that runs as a
coroutine alongside the document. It tokenizes lines incrementally —
tokenizing one chunk per frame so it never blocks — and stores the results
in a cache keyed by line. DocView reads from the cache to know what color
to draw each run of text.

---

## The view tree

The root of the view hierarchy is the `RootView` in
`data/core/rootview/init.lua`. It manages a binary tree of split nodes,
where leaf nodes hold tabs, and each tab holds a view.

Every view inherits from `data/core/views/view.lua`:

- `view:update()` — called every frame; update state, set `self.scroll.to`
  for smooth scrolling
- `view:draw()` — called every frame after update; call renderer functions to
  draw the view
- `view:on_mouse_pressed(button, x, y, clicks)` — mouse events
- `view:on_key_pressed(key, modifiers)` — only called if the keymap doesn't
  handle the key first

`DocView` (`data/core/views/docview.lua`) extends this to render a `Doc`:
it draws the gutter (line numbers), the text (using the highlighter cache),
the caret, and selections. It also handles mouse input for cursor placement
and selection dragging.

---

## The command and keymap system

Commands are in `data/core/input/command.lua`. Every named action in the
editor — `doc:save`, `tab:next`, `vim-fmenu:open` — is registered with
`command.add(predicate, table)`. The predicate is called at runtime; if it
returns false, the command is inactive. `nil` means always active. A class
name string means active when a view of that class is focused.

The keymap is in `data/core/input/keymap.lua`. It maps keystroke strings to
command names (or lists of command names). When a key event fires, the keymap
walks the list for that stroke and runs the first command whose predicate is
currently true.

This design means any code — plugin or core — can add commands and keybindings
without touching existing code. Everything competes on an equal footing.

Default keybindings are loaded from `data/core/keymaps/default.lua`.
User overrides in `data/user/init.lua` call `keymap.add` and stack on top.

---

## Background threads (coroutines)

There are no OS threads in the Lua side. Background tasks are cooperative
coroutines scheduled by the frame loop.

`core.add_thread(fn)` registers a function. Each frame, the loop calls
`coroutine.resume` on each registered thread. If the thread yields a number,
it sleeps that many seconds before being resumed again (the loop tracks the
resume time). If it errors, the error is logged and the thread is dropped.

This means background tasks must yield frequently. A task that spends 20ms
in Lua before yielding will drop frames. The project scanner yields after
scanning each directory entry; the git poller yields between running `git`
and reading the result.

The coroutine scheduler is simple — there's no priority, no preemption, no
inter-thread messaging. For the editor's use cases (polling at low frequencies,
reading a few files) this is plenty.

---

## Plugin loading

Plugins load in `data/core/init.lua`, after the core modules and before the
user config. The loader `require`s every `.lua` file under `data/plugins/`
recursively, in directory order.

Plugins are not sandboxed. They run in the same Lua state as the core, with
access to all the same tables. A plugin can modify anything. This is
intentional — it's what makes the wrap-and-call extension pattern possible.

If a plugin errors during load, the error is caught, logged, and startup
continues. The intent is that one broken plugin doesn't take down the editor.

Load order: core → plugins (alphabetical within each directory) →
`data/user/init.lua` → `.lite_project.lua`. Later always wins, which is why
user config can override anything.

---

## The search engine

`src/search/find.c` is the C-side text search used by find and replace. It
exposes one function to Lua: `system.find_text(lines, needle, line, col, opt)`.
It returns the next match as `(line, start_col, end_col)`, or `nil` if there
are no more matches.

`data/core/doc/search.lua` wraps this into a Lua API used by DocView and the
find-replace plugin. `data/core/search.lua` (note: different file) is the
project-wide grep that the projectsearch plugin drives — it uses
`system.exec` to call `grep` (or a fallback) rather than the in-process
search engine, since grepping millions of lines in Lua would be too slow.