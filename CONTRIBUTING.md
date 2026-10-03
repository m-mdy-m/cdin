# Contributing

Thanks for wanting to contribute. Here's what you need to know.

---

## Before you start

Read [docs/architecture/overview.md](docs/architecture/overview.md). It covers
the C/Lua split, the command and keymap system, how plugins hook in, and how
the frame loop works. A lot of contribution mistakes come from not knowing how
these pieces connect, and the document is short.

The project values small, readable, auditable code. A contribution that adds
100 lines but could have added 30 is usually going to get pushed back. Same
for a change that works but is hard to follow — the goal is a codebase where
a new person can find any piece of behavior, understand it, and change it.

---

## Setting up

You need:

- `gcc` or `clang`
- GNU `make`
- SDL3 development headers (**required** — the SDL2 auto-detect in `mk/config.mk`
  is vestigial and the build probes `SDL3/SDL.h` regardless)
- Lua 5.4 development headers
- Python 3 with `cairosvg` and `Pillow` (for icon generation)

On most Linux distros:

```sh
# Debian / Ubuntu
sudo apt install gcc make libsdl3-dev liblua5.4-dev python3-pip
pip install cairosvg Pillow

# Arch
sudo pacman -S gcc make sdl3 lua54
pip install cairosvg Pillow
```

Then:

```sh
git clone https://github.com/m-mdy-m/cdin
cd cdin
make run
```

For more detail and platform-specific notes, see
[docs/guides/building.md](docs/guides/building.md).

---

## Development workflow

**For Lua changes** (plugins, config, core editor behavior): build once, then
edit and restart. The build symlinks only `build/<platform>-release/data/core` to
the repository's `data/core` — everything else in `data/` is a real copy assembled
from cdin-x. So any Lua change under `data/core` is live on the next launch, with
no recompile.

**For C changes** (renderer, SDL bindings, font rasterization): use the debug
build. It skips optimization, keeps debug symbols, and lets you run under gdb
or lldb:

```sh
make debug
./build/linux-debug/cdin
```

There is no sanitizer target. `make debug-san` sets a `SANITIZE` variable that no
makefile reads, so it is identical to `make debug`; to sanitize, pass the flags
yourself through `CFLAGS`/`LDFLAGS`.

**For checking what the build system detected:**

```sh
make info
```

This prints the detected Lua version, compiler, flags, output path and install
prefix. (The SDL line is a literal `3 (required)`, not a version — SDL3 is the only
supported configuration.) Run it first if the build fails; it usually shows what's
missing.

---

## Where things live

```
src/               C layer — window, renderer, SDL, filesystem, Lua binding
src/api/           the Lua-facing C API: system, renderer, search, fs, path
src/ui/            the software renderer and its cell-based redraw cache
src/fs/            path and filesystem operations exposed to Lua
src/search/        the C-side text search engine (used by find/replace)
src/core/          window lifecycle, boot, config, logger, utilities
src/lua/           Lua state setup and the entry point into Lua

data/core/                the Lua editor core — see data/core/init.lua for the boot order
  init.lua, config.lua, state.lua, loop.lua, style.lua, themes.lua,
  plugins.lua, project.lua, help.lua, docs.lua, events.lua, logging.lua,
  lifecycle.lua, preboot.lua, fs.lua
data/core/commands/       the runtime's own commands, one file per group
data/core/keymaps/        default.lua — every default binding
data/core/doc/            the text buffer, the highlighter, word translations
data/core/rootview/       the pane tree, the empty view, the logo
data/core/views/          DocView, CommandView, StatusView, TitleBar, LogView, View
data/core/input/          command registry and keymap
data/core/syntax/         the syntax registry and the tokenizer
data/core/text/           UTF-8, bidi, shaping
data/core/runtime/        strict (globals are errors)
data/core/utils/          Object (class system), common utilities

build/<platform>-<build>/data/   BUILD OUTPUT, not source:
  core/       a symlink to data/core (a copy where symlinks are unavailable)
  plugins/    one-line shims for the mandatory plugins — vim, manager
  X/          those two plugins, verbatim, from cdin-x
  cdinx/      the manager's own modules, carried by its bundle_with
  themes/     the mandatory theme a build bundled from cdin-x
  fonts/      the fonts a build bundled from cdin-x
  BUNDLE.lua  an index of what the bundle contains

~/.config/cdin/user/     user configuration (init.lua) and user themes
<data_home>/cdin/        site/, extensions/X/, registry/cdin-x/, extensions.lua
<data_home>/cdin/site/   a cdin-x checkout or your own plugins

mk/                Makefile fragments — platform, version, config, build,
                    install, and bundle. CDINX_DIR is defaulted in bundle.mk
                    and passed to the scripts; nothing else reads it.
scripts/           data assembly, icon generation, and four Lua test suites
tests/lua/         the unit + integration suite
docs/              documentation (you're here)
```

**The mandatory set is four things**, not three: vim, the extension manager, the
`default` theme, and the fonts. Three carry `essential = true` in cdin-x —
`vim`, `manager`, and the theme — and the fonts are not a plugin at all, which is
why the bundler checks them separately and fails on an empty `fonts/`.

There is no `data/core/git/`. Git support moved to
[cdin-x](https://github.com/m-mdy-m/cdin-x) in 0.2.0-alpha, and the runtime
reaches it through `core.register_vcs_provider`.

When deciding where a change belongs: if it's optional behavior, it's a
plugin. If it's something every editor needs, it might belong in core. If it
changes the window or the renderer, it's in `src/`. New features that can be
plugins should be plugins — that's where the ecosystem grows without making
the core heavier.

---

## Reporting bugs

Open an issue on GitHub with:

- Steps to reproduce
- What you expected
- What happened instead
- Your platform (OS, distro, SDL version, Lua version — `make info` prints
  this)
- The contents of `cdin-log.txt` (written next to the binary on each run) —
  it holds both streams, the C logger's and Lua's, with tracebacks

Check existing issues first. If it's already there, add a comment with your
reproduction steps — more data points help.

---

## Suggesting features

Open an issue describing the feature and the problem it solves. Keep the
project philosophy in mind:

- Features that can be plugins should be plugins, not core changes
- The editor should stay small and auditable; adding things because they're
  possible is not a good reason
- Configuration is good; making things configurable just to avoid a decision
  is not

If you're unsure whether something is in scope, open an issue to discuss it
before writing code.

---

## Submitting changes

1. Fork the repository and create a branch:

   ```sh
   git checkout -b fix/thing
   # or
   git checkout -b feature/thing
   ```

2. Make the change. Keep it focused — one topic per pull request. A PR that
   mixes a bug fix and a refactor and a new feature is hard to review and
   hard to merge.

3. Build cleanly on both release and debug:

   ```sh
   make
   make debug
   ```

   The C flags include `-Wall -Wextra`. Don't introduce warnings. If you're
   silencing a warning rather than fixing its root cause, explain why in a
   comment.

   `make` needs a cdin-x checkout beside this one; `make CDINX_DIR=…` if it is
   elsewhere. `make bin` compiles the binary alone and needs nothing.

4. Run the test suites. All four need only `lua` — no build, no editor:

   ```sh
   make test-plugins     # keymap integrity and the loader
   make test-lua         # unit + integration, in tests/lua/
   make test-workflows   # the cdin-x workflows; needs CDINX_DIR
   make test-site-dir    # the one duplicated constant, vs cdin-x
   ```

   Which one to run depends on what you touched, and `AGENTS.md` says which is
   which. `test-workflows` is the one that cannot be replaced: it is the only
   suite that reads cdin-x, and a stale runtime binding and a duplicated plugin
   binding are both invisible from this repository alone.

   `make check` and `make size` do not work — they call `scripts/check.py` and
   `scripts/bench.py`, which do not exist. `make test` and `make bench` are
   `.PHONY` entries with no rule, and `make debug-san` sets a variable nothing
   reads. There is no lint or style checker here; the compiler is it.

5. Run the editor and exercise what you changed, and include a note in your PR
   about what you tested and how. The suites do not replace that.

6. Update the docs if your change affects:
   - Commands or keybindings → [docs/guides/commands.md](docs/guides/commands.md)
   - Configuration options → [docs/guides/configuration.md](docs/guides/configuration.md)
   - What a build contains, or installing extensions → [docs/guides/extensions.md](docs/guides/extensions.md)
   - Plugin behavior or an extension seam → [docs/guides/plugins.md](docs/guides/plugins.md)
   - Build targets, `CDINX_DIR` or the test suites → [docs/guides/building.md](docs/guides/building.md)
   - A specific failure → [docs/guides/troubleshooting.md](docs/guides/troubleshooting.md)
   - The architecture → [docs/architecture/overview.md](docs/architecture/overview.md)
   - The highlighter or the tokenizer → [docs/architecture/internals.md](docs/architecture/internals.md)
   - **What cdin guarantees an extension** → [docs/architecture/extension-contract.md](docs/architecture/extension-contract.md)

   That last one is the one to think hardest about. If cdin-x could plausibly
   have depended on the change, it is a breaking change, not a documentation
   update — see the closing section of that page.

   **Themes, syntax definitions and vim mode are cdin-x's**, and so are their
   pages. A change to the theme *registry*, the tokenizer or the loader belongs
   here; a change to a theme, a language definition or a key in vim mode belongs
   in [cdin-x](https://github.com/m-mdy-m/cdin-x), which has its own
   `CONTRIBUTING.md` and the same rule about updating docs when behaviour moves.

7. Add a line to the `[Unreleased]` section of `CHANGELOG.md` if the change
   is user-visible:

   ```
   - Added `config.scrolloff` option to control cursor margin while scrolling
   - Fixed treeview git polling blocking the frame loop on slow filesystems
   ```

   A documentation fix counts. So does a bug you found while documenting — write
   what the code does, and say so in the entry when the docs were the thing that
   was wrong.

8. Open a pull request with a clear description of what you changed and why.
   Link to the issue it addresses if there is one.

---

## Code style

### General

The repository has an `.editorconfig` that most editors pick up automatically.
The short version: UTF-8, LF line endings, trailing whitespace trimmed, a
newline at the end of every file, 2-space indentation everywhere except
Makefiles (which use tabs).

### C

Standard: C11 (`-std=gnu11`). The goal is portable, auditable code — no
platform-specific tricks without a comment explaining them.

- Keep functions short. If a function doesn't fit on a screen, look for a
  natural split.
- No new external dependencies without prior discussion. The C layer has
  exactly three: SDL, Lua, and stb_truetype (vendored). That's intentional.
- If you add a new `src/` subsystem, add a header. Declarations go in `.h`,
  definitions in `.c`. No `static` inline functions in headers unless the
  performance case is clear and documented.
- Error handling: check return values. If a call can fail and you're ignoring
  the result, leave a comment saying why it's safe to do so.

### Lua

Follow the style of `data/core/`:

- `snake_case` for everything (variables, functions, module fields)
- Modules return a table
- Classes extend `core.utils.object` via `Object:extend()`
- Prefer `local` for everything. The `core.runtime.strict` module errors on
  undeclared globals — lean on it

Extend via the documented seams before you wrap a function. `Doc._before_save`,
`Doc._after_load` and `Doc._after_save` are real hooks; `trimwhitespace` (a cdin-x
plugin) uses `_before_save` rather than replacing `Doc.save`, and
`autoreload` uses the other two. See
[the extension contract](docs/architecture/extension-contract.md) for the full
list, including the functions that are wrapped today but are **not** part of the
contract.

### Commit messages

A short imperative summary line, ideally under 72 characters:

```
fix startup blocking on git status in large repos
add :tree ex command to focus and refresh treeview
```

If the why isn't obvious from the what, add a body after a blank line. The
body is for explaining the reasoning, not restating the diff.

---

## Lua plugin patterns

Four things tie the editor together, and every extension uses them.

**Commands** are named actions registered with `command.add(predicate, table,
overwrite)`. The predicate controls when the command is valid: `nil` means
always, a module path string means "that module's returned function says so", and
a class table means "the active view is an instance of it". The command palette,
the keymap, and other extensions all refer to commands by name — which is what
lets a binding, a menu entry and an ex-command reach the same thing without
holding a reference to a module they did not load.

```lua
local command = require "core.input.command"
command.add("core.views.docview", {
  ["my-plugin:do-thing"] = function()
    -- core.active_view.doc is the current document
  end,
})
```

**Coroutine threads** are background tasks. Register one with `core.add_thread`
and yield a number to sleep. The frame loop resumes each thread every frame.
Don't do blocking I/O here — the whole editor stalls if you do.

```lua
core.add_thread(function()
  while true do
    -- poll something
    coroutine.yield(5)  -- sleep 5 seconds
  end
end)
```

**Wrapping** is how extensions extend core behavior, and it is the last resort —
there is no event or hook system. Replace a function, call the original, and put
it back in `unload`:

```lua
local Doc = require "core.doc"
local _save = Doc.save

function Doc:save(...)
  -- before save
  _save(self, ...)
  -- after save
end

function M.unload()
  Doc.save = _save
end
```

Before reaching for it, check the three that are not wrapping: the document hook
lists `Doc._before_save` / `_after_save` / `_after_load`, the provider
registries (`core.register_status_pill`, `core.register_vcs_provider`,
`core.register_recent_provider`, `core.register_help_shortcuts`), and
`core.command_view` for prompts. A wrapper is in the path of every call including
the ones you did not want to touch, and a wrapper that leaks runs again on the
next load.

A minimal plugin that adds a command and a keybinding:

```lua
local core    = require "core"
local command = require "core.input.command"
local keymap  = require "core.input.keymap"

command.add(nil, {
  ["my-plugin:greet"] = function()
    core.log("hello")
  end,
})

keymap.add {
  ["ctrl+shift+g"] = "my-plugin:greet",
}
```

Drop it in `<site>/plugins/` — as a directory with an `init.lua` or a single
`.lua` file — and restart, or run `core:load-plugin my-plugin` for the session
without one.

**Keys** are bound by name, not by function, and that is the fourth thing:

```lua
keymap.add { ["ctrl+shift+g"] = "my-plugin:greet" }
```

A value may be a **list**, which is a fallback chain: each command is tried in
order and the first whose predicate holds runs. **Without `overwrite`,
`keymap.add` prepends**, so a later `add` wins and the old chain stays alive
behind it — which is why a plugin can override a key you set in `init.lua`, and
why you need `keymap.add(map, true)` to override one a plugin set. Note that
`keymap.add` is for keys and `command.add` for commands; a keystroke never holds
a function.

See [docs/guides/plugins.md](docs/guides/plugins.md) for the loader's rules, and
[the extension contract](docs/architecture/extension-contract.md) for the whole
of what is guaranteed.

---

## Questions

Open an issue or start a thread in
[Discussions](https://github.com/m-mdy-m/cdin/discussions). If it's a quick
question about where something is or how something works, the architecture doc
and the source comments are good first stops.