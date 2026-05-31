# src/engine

This is a self-contained, pure-C implementation of cdin's editing model:
a gap buffer (`buffer.c`), modal editor state machine (`editor.c`), and
Vim-style key dispatch (`keymaps.c`).

It now compiles as part of the normal build (it's inside `src/`, so the
Makefile's `find src -name '*.c'` glob picks it up), but **nothing calls
into it yet**. The active cdin architecture (matching `NOTICE` and
`data/core/init.lua`) drives editing logic from Lua, the same way the
original `lite` editor does — the C side only exposes primitives
(windowing, events, rendering, filesystem) via `src/api/`. `editor_create()`,
`keymap_dispatch()`, etc. are compiled in but unreferenced, so they just
sit there as dead-but-harmless object code until something calls them.

If cdin moves toward a C-native editing core (dropping or supplementing
the Lua layer for the buffer/editor logic), this is a solid starting
point — wire `main.c` to call `editor_create()` instead of (or alongside)
`lua_run_core()`.