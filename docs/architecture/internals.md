# Internals

A deeper look at the pieces you need if you are working on the C layer, the text
pipeline, or the frame loop. [The overview](overview.md) has the split and the
boot order; this page has the machinery.

## The C layer

`src/` is deliberately thin. It owns a window, a renderer and an OS interface,
and exposes them to Lua. It knows nothing about documents, views, commands or
keybindings.

| directory | holds |
| --- | --- |
| `src/main.c` | `main()` and the bootstrap string |
| `src/core/` | window, logger, utils, and the Windows DPI setup in `boot.c` |
| `src/ui/` | the renderer, and its caches |
| `src/fs/` | path handling and filesystem operations |
| `src/search/` | the C-side substring search used by the find bar |
| `src/api/` | the Lua-facing bindings: `system.*`, `renderer.*`, `core.*` |
| `src/lua/` | the Lua state, the globals, and `lua_run_core` |

**The C11 rule is that the C side has no editor concepts.** It cannot grow a bug
about a document, because it has no idea what one is. If you find yourself wanting
to add "tab" or "selection" to `src/`, the answer is a binding for something the
renderer already knows how to draw.

### What Lua gets

Five native modules, from `api_load_libs` (`src/api/api.c:11-22`). Three are
registered **eagerly**, two are **lazy preloads**:

| module | on it |
| --- | --- |
| `system` | `poll_event`, `wait_event`, cursor, window (title, mode, focus, minimize, maximize), `set_hit_regions`, `show_confirm_dialog`, clipboard, `get_time`, `sleep`, `chdir`, `list_dir`, `absolute_path`, `get_file_info`, `exec`, `popen`, `fuzzy_match` |
| `renderer` | `show_debug`, `get_size`, `begin_frame`, `end_frame`, `set_clip_rect`, `draw_rect`, `draw_text`, plus the `renderer.font` sub-table (`load`, `set_tab_width`, `get_width`, `get_height`, `add_fallback`, `__gc`) |
| `search` | the C substring search behind `doc/search.lua`, and `fuzzy_match` |
| `fs` | `mkdir_all`, `remove_all`, `copy_all`, `stat`, `list_dir` — reached through `core.fs` |
| `path` | `absolute`, `join`, `basename`, `dirname`, `ext`, `stem`, `split`, `normalize`, `is_absolute`, and `sep` as a field — `core.fs` re-exports the first four and `sep`; the rest are reachable only as `require "path"` |

**There is no `core` table from the C layer.** `core` is the Lua runtime module
(`data/core/init.lua`), installed by the bootstrap. Hit regions are
`system.set_hit_regions`; the scale factor is the `SCALE` global.

Plus five globals from `lua_setup_globals`: `VERSION`, `PLATFORM`, `SCALE`,
`EXEFILE`, `ARGS`. The bootstrap string then adds `PATHSEP` and `EXEDIR`.

**`SCALE` is the display content scale, and it is `1.0` on every non-Windows
platform** — `utils_get_scale()` has an `#ifdef _WIN32` around the real value and
returns a literal `1.0` otherwise. Everything sized in pixels multiplies by it
(`style.lua` does this uniformly: `common.round(14 * SCALE)` for padding and so
on), which is why a theme sets colours and never sizes. On Windows this is a real
HiDPI factor; everywhere else it is a hook that is not currently connected to
anything.

**The renderer has no line primitive.** Rects and text only — a rule or a divider
is a one-pixel rect. A glyph-coverage check walks a chain of at most **8 font
fallbacks** (`renderer.c:217-230`), with a per-fallback baseline offset so metrics
differ harmlessly.

### The renderer cache

`src/ui/renderer_cache.c` exists because immediate-mode drawing of a text editor
re-issues the same rectangles every frame. It buckets commands into an **80 × 50
grid of 96 px cells**, hashes each command into the cells it touches, diffs
against the previous frame, and expands changed cells to dirty pixel rects. The
command buffer is 512 KB.

Invalidation is explicit, via `rencache_invalidate`, on a resize **or a clip-rect
change** — not per frame.

**This is why `core.redraw = true` matters.** A frame that does not redraw skips
the whole draw path, which is the idle-cost story. Any state change a view has
cached needs to set it, or the screen goes stale.

## The text pipeline

`data/core/text/` is where non-ASCII gets decided, and it is three independent
pieces that run in that order.

### `utf8.lua`

| | |
| --- | --- |
| `is_cont(byte)` | is this a continuation byte |
| `len(text)` | character count, not byte count |
| `chars(text)` | an iterator over characters |
| `offset(text, n)` | byte offset of character *n* |
| `decode(text, pos)` | codepoint at *pos* |
| `encode(cp)` | one character from a codepoint |
| `sanitize(text)` | drop or replace anything invalid |

**Columns are byte offsets, not character indices.** This is worth stating
plainly because the opposite is the natural assumption. `DocView:get_col_x_offset`
slices with `text:sub(1, col - 1)` and hands the bytes straight to the font;
`doc/translate.lua` steps by byte while *skipping* UTF-8 continuation bytes, so a
motion never lands mid-codepoint; and `get_text`, `insert` and `remove` are all
byte-indexed. The document layer is byte-indexed throughout.

UTF-8 awareness appears in exactly two places: skipping continuation bytes so a
position is always on a character boundary, and `utf8.sanitize` on load.

A column past the end of a line is `math.huge` and means "the end", which is why
`doc:newline-below` and `doc:duplicate-lines` can append without measuring.

`sanitize` is applied to every line on load. A file with invalid UTF-8 opens
rather than failing, and the invalid bytes are dropped — a text editor that
refuses to open a file is a worse bug than one that shows it slightly wrong.

### `bidi.lua`

| | |
| --- | --- |
| `is_rtl_char(cp)` | |
| `base_dir(text)` | the paragraph direction — the first strong character wins, defaulting to ltr |
| `has_rtl(text)` | |
| `visual(text, dir)` | the visual-order run list for a line |

### `shaper.lua`

`needs_shaping(s)` and `shape(s)` — letterform joining, the reason Arabic and
Indic scripts look like words rather than sequences of letters. Driven by
`config.shaping_enabled`, which defaults on.

`style.font`, `style.code_font` and `style.big_font` each get `fallback.ttf` and
`emoji.ttf` added as fallbacks if those files are present, which is how a single
monospace font renders an emoji without a second font stack per view.

### The order, which is the whole point

`text.visual()` is six lines, and both of its branches matter:

```lua
local shaped = (shaping and shaper.needs_shaping(s)) and shaper.shape(s) or s
if dir == "ltr" and not bidi.has_rtl(s) then return shaped end
return bidi.visual(shaped, dir)
```

**Shaping runs first, then bidi.** Not the other way round. The shaper produces
the joined letterforms in *logical* order; the bidi pass then reorders the
already-shaped runs into visual order. Reversing them would reorder unshaped
isolated forms, which is wrong in a way that is obvious the moment you have seen
it and invisible in a test.

**Bidi is not skipped for a line with no RTL text unless `direction` is exactly
`"ltr"`.** `"auto"` — the default — still calls `bidi.visual` on every line and
lets it decide the base direction per line. The short-circuit is for a document
that has explicitly been declared left-to-right, not an optimisation for
ordinary text.

Shaping is guarded separately by `needs_shaping`, so an English or CJK line skips
the shaper without any configuration.

## The document

`data/core/doc/init.lua`. A `Doc` is a `lines` table, a selection, and two undo
stacks.

### Undo

```lua
self.undo_stack = { idx = 1 }
self.redo_stack = { idx = 1 }
self.clean_change_id = 1
```

**The change id is the undo stack's index**, and dirtiness is
`clean_change_id ~= undo_stack.idx`. There is no separate dirty flag to get out
of sync: saving calls `clean()`, which copies the current index. Undo back to the
clean index and the document is clean again, which is the behaviour you want and
the reason it is implemented this way.

**Consecutive edits merge** within `config.undo_merge_timeout`, so typing is one
undo step rather than one per keystroke. `raw_insert` and `raw_remove` take the
time and decide; the public `insert`/`remove` do not expose it.

### The three hooks

```lua
Doc._before_save = {}   -- fn(doc) before writing to disk
Doc._after_save  = {}   -- fn(doc) after writing
Doc._after_load  = {}   -- fn(doc) after reading
```

Plain lists, called with `ipairs`. They are the extension seam plugins prefer
over wrapping `Doc.save`, because unloading is `table.remove` rather than a
restore-everything dance. See [plugins](../guides/plugins.md#document-hooks).

### `reset_syntax`

Runs on load. Reads the first 128 bytes of line 1, asks `syntax.get(filename, header)`,
and resets the highlighter only if the answer actually changed — so reloading a
file whose syntax did not change does not throw away the token cache.

## The highlighter

`data/core/doc/highlighter.lua`. Per document, incremental, in its own thread.

| | |
| --- | --- |
| `first_invalid_line` | the top of the dirty region |
| `max_wanted_line` | the bottom of what is visible |
| `lines[i]` | `{ text, tokens, state, init_state }` |

The thread walks outward from what is visible, at most 40 lines per pass before
yielding, and only when `first_invalid_line > max_wanted_line` does it back off
and wait. That is why opening a very large file is instant.

**A cached line records the state it started in.** If the previous line's end
state changes, every line after it is stale, and `init_state` is how that is
detected. Editing line 1 of a file whose line 2 opens a multi-line string
re-tokenizes everything below — correct, and also why a large paste near the top
of a big file is the one edit that costs a frame.

## Syntax highlighting

`core.syntax` is a registry and `core.syntax.tokenizer` is a walker; the
highlighter above is what drives it. **The runtime ships no language
definitions.** Every language is an extension that calls `syntax.add`, so with
nothing installed every file is plain text and `doc:toggle-line-comments` has no
comment marker to read. The *format* of a definition is cdin-x's documentation —
[adding a syntax definition](https://github.com/m-mdy-m/cdin-x/blob/main/docs/building/a-syntax-definition.md) — and what
follows is the half that belongs to the runtime.

**`add` appends; lookup walks the list backwards.** The last definition that
claims a filename wins. There is no way to insert at a position and no `remove`,
so a definition added from an extension's `init()` lasts for the session. The
filename is tried before the shebang.

**Patterns are tried in order at each position, first match wins, each anchored
at the current position.** If none match, one character is consumed as `normal`.
A delimited span is `{ open, close }` or `{ open, close, escape }`, and the escape
is checked by counting the backslashes before a candidate close and testing for an
odd number — which is the case most delimiters get wrong.

**The state is one level deep.** A delimited span sets a single `state`, the index
of the pattern that opened it, and the next line starts in whatever state the
previous one ended in. That is what makes multi-line strings and block comments
work at all. It is **not a stack**: a `"` inside a block comment does not nest a
string. A language that needs nesting needs a different walker, and that is the
honest limit of the design.

**Whitespace is absorbed.** Adjacent tokens merge when they share a type *or when
the previous one is only whitespace*, and merging overwrites the type. The run of
spaces before a keyword is tokenized as part of the keyword, so leading whitespace
cannot be coloured on its own.

**A `type` with no matching `style.syntax` key is not uniformly rescued.** One of
the three draw paths in `docview.lua` falls back to `normal`; the other two hand
the missing colour to the renderer, which draws opaque white. A typo in a
definition can therefore render as ordinary text, as white, or as a
partly-coloured line, depending on which span it lands in.

| file | holds |
| --- | --- |
| [`data/core/syntax/syntax.lua`](../../data/core/syntax/syntax.lua) | `add`, `get`, the backwards lookup |
| [`data/core/syntax/tokenizer.lua`](../../data/core/syntax/tokenizer.lua) | the walker, the state machine, token merging |
| [`data/core/doc/highlighter.lua`](../../data/core/doc/highlighter.lua) | the per-document cache and its thread |
| [`data/core/utils/common.lua`](../../data/core/utils/common.lua) | `match_pattern`, shared with the project scan |

## Views

Everything draws through `View:extend()`, and there are three methods that matter
more than the rest.

```lua
function MyView:get_name() end          -- the window title and the pane's tab label
function MyView:update() end            -- layout, scroll, anything cached
function MyView:draw() end              -- draw only; must not change state
```

**`draw` must not change state.** It runs only when `core.redraw` is set, so a
view that mutates something while drawing will not do it consistently — the
change happens on the frames that redraw and not on the ones that do not. Layout
goes in `update`.

**Keys do not arrive here.** `data/core/events.lua` routes a key press to
`keymap.on_key_pressed` and to nothing else; there is no fallback that hands it
to the active view, and `View` does not define `on_key_pressed`. So a view
responds to a keystroke in exactly two ways: through a command it registered and
bound, or through a wrapper on `keymap.on_key_pressed`. `EmptyView` implements
`on_key_pressed` and is the exception that proves the rule — it is unreachable,
and the four shortcuts it advertises do nothing.

The class test is a separate method, `View:is(T)`, and it walks the metatable
chain — which is why `"core.views.docview"` works as a predicate string
(`command.add` `require`s the string and gets that class back), and why
`CommandView:is(DocView)` is **true**: `CommandView` extends `DocView` in order to
reuse its scrolling and gutter maths. That inheritance is load-bearing, and it is
also why every `doc:*` command stays available while a prompt is open.

Scrolling is the view's own business. `DocView:get_scrollable_size`,
`get_line_screen_position`, `scroll_to_line`, `scroll_to_make_visible` and
`get_visible_line_range` are the set, and a custom scrollable view needs the same
five.

### `View:extend()`

From `data/core/utils/object.lua`, which is the whole inheritance system:

```lua
Object:new()      Object:extend()
Object:is(T)      Object:__tostring() Object:__call(...)
```

`extend` returns a subclass with `super` pointing at the parent. There is no
metatable magic beyond that — no `__index` chains to debug, and
`X.super.new(self)` is the first line of every constructor.

`Object:is` is the `instanceof` used everywhere.

## `core.fs`

`data/core/fs.lua` wraps the C filesystem calls, and it is the module a plugin
should use rather than shelling out or guessing at separators:

| | |
| --- | --- |
| paths | `join`, `basename`, `dirname`, `abs`, `sep` |
| queries | `exists`, `is_dir`, `is_file`, `stat`, `list` (alias `ls`), `pwd` |
| changes | `mkdir`, `rm`, `touch`, `copy`, `rename`, `move`, `cd` |

**`ext`, `stem`, `split`, `normalize` and `is_absolute` are not re-exported.** The
native `path` module has all five and nothing in the tree calls them, so they were
dropped from this wrapper rather than left as a second way to do the same thing.
A plugin that wants one requires `path` directly — which is a native module, so it
is not part of what this document promises to stay.

`join` handles the separator; `core.fs.sep` is whatever the C `path` module
reports. A plugin that builds paths by concatenating `"/"` works on Linux and
quietly produces a second directory level on Windows.

`list` returns entries with `type` set to `"dir"` or `"file"`, which is the whole
reason `fs.list` reports it at all: `system.list_dir` returns bare names, and a
name does not say whether it is a directory. An extension that needs the
distinction should use `core.fs.list` rather than counting on the other one.

## `core.try` and logging

```lua
function core.try(fn, ...)   -- returns true on success, false plus a logged error
```

Installed by `core.logging`. It is the boundary for anything a user action
triggered: a thread body, an event handler, `command.perform`. `command.perform`
wraps every call in it, which is why a raising command logs rather than taking
the frame loop with it. On failure it attaches a de-tabbed `debug.traceback` to
the log item's `.info`, which is the only way to see *where* a plugin broke.

All three log levels are printf-style and append to the same ring buffer,
`core.log_items`, capped at `config.max_log_items`. They differ only in the status
bar:

| | status bar | in the log |
| --- | --- | --- |
| `core.log` | an `i` in `style.text` | yes |
| `core.log_quiet` | nothing | yes |
| `core.error` | a `!` in `style.accent` | yes |

Every item records `{ text, time = os.time(), at = "src:line" }`, from
`debug.getinfo`. `log_quiet` is not "quieter" in the log — it is the same entry
without the transient status-bar message, which is what you want for something
that happens on every keystroke.

**The Lua log and `cdin-log.txt` are one file.** `core.log` and `core.error`
write `core.log_items`, which `core:open-log` shows, and `data/core/logging.lua`
also appends each message — and, for `core.try` failures, the traceback — to the
C logger's file, `cdin-log.txt` next to the binary, tagged `LUA`. The C logger
writes its own lines (tagged by level) to the same file, so it reads in the order
things happened. `CDIN_LUA_LOG=0` turns the Lua half off.

**There is no crash handler, and no `error.txt` is ever written.** An uncaught
raise propagates to the bootstrap's `xpcall` (`src/lua/api.c:39-49`), which calls
`cdin_log_fatal` → `log_fatal` → `cdin-log.txt`, and then `main()` returns and the
process exits normally. It used to write `error.txt` and save every dirty document
to `<filename>~` from a `core.on_error` handler in `data/core/lifecycle.lua`, but
nothing ever called it, so it has been removed. Do not rely on either.

## Things that are load-bearing

A short list, because each of these looks like a style choice and is not:

**`package.path` is prepended for `EXEDIR/data` and appended for the site
directory.** The editor's own modules win; extensions extend rather than replace.

**Globals are an error.** `core.runtime.strict` is the first thing loaded, so a
stray global in a plugin is caught at load rather than when two plugins collide on
a name. It fires only on a *missing* key, so the six globals C sets
(`ARGS`, `VERSION`, `PLATFORM`, `SCALE`, `EXEFILE`, `PATHSEP`) bypass it and can
be reassigned silently.

**`config.site_path()` is a function, not a field.** Your `init.lua` runs after
`core.config` was required, so a path computed at load time would be fixed before
you could change it and the one knob would silently do nothing.

**The default keymap is installed before your config, and your config before the
plugins.** That single ordering is what makes a plugin able to override a key you
set and you able to override a key a plugin sets.

**A failing plugin never stops startup.** Bundled is reported at error level, site
is logged and skipped. An editor that refuses to open is a worse bug than a
missing feature.

**`data/core` is symlinked into the build and recreated every time.** A link made
once and then assumed correct is exactly how a stale copy becomes the editor you
are running.

**Two of the `doc:move-to-*` commands are overwritten by hand.**
`doc:move-to-previous-char` and `doc:move-to-next-char` collapse a selection
before moving, which is why the arrows shrink a selection. The generated versions
are still there for the other fourteen translations.

## Files

| file | holds |
| --- | --- |
| [`src/main.c`](../../src/main.c) | `main()` |
| [`src/lua/api.c`](../../src/lua/api.c) | the globals and the bootstrap string |
| [`src/ui/renderer.c`](../../src/ui/renderer.c) | drawing, and the caches |
| [`data/core/loop.lua`](../../data/core/loop.lua) | the frame loop and the scheduler |
| [`data/core/doc/init.lua`](../../data/core/doc/init.lua) | the document, undo, the hooks |
| [`data/core/doc/highlighter.lua`](../../data/core/doc/highlighter.lua) | the incremental highlighter |
| [`data/core/text/`](../../data/core/text) | UTF-8, bidi, shaping |
| [`data/core/utils/object.lua`](../../data/core/utils/object.lua) | `extend`, `is` |
| [`data/core/fs.lua`](../../data/core/fs.lua) | the filesystem and path layer |
| [`data/core/logging.lua`](../../data/core/logging.lua) | `core.try` and the three levels |
