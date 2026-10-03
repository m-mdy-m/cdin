# Troubleshooting

## Start here

```sh
make info
```

It prints the platform, compiler, detected Lua version, every flag and the output
path. Most build problems are answered by one of those lines.

Press <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>L</kbd>. That is the fastest place to
read a plugin error: the in-editor view over `core.log_items`, which is what
`core.log` / `core.error` write.

**Everything is also in one text file**, `cdin-log.txt` next to the binary: the
C logger's lines (tagged `INFO`, `WARN`, `ERROR`...) and the Lua ones (tagged
`LUA`, with tracebacks), in order. That is the file to send with a bug report.

The view has two sources, and <kbd>F2</kbd> switches between them. **editor** is
`core.log_items`; **native** is that same file.

| | |
| --- | --- |
| `CDIN_LOG_LEVEL` | console level: `trace` `debug` `info` `warn` `error` `fatal` |
| `CDIN_LOG_FILE_LEVEL` | file level, `debug` by default |
| `CDIN_LOG_FILE` | write the log somewhere else |
| `CDIN_LUA_LOG=0` | stop mirroring the Lua stream into that file (on by default) |

The Lua mirror matters most for one case: a Lua error *during startup*, where
the log view cannot be opened because there is no editor to open it in.
`cdin-log.txt` then has the message, the file and the line.

A log past 4 MB is rotated to `cdin-log.txt.1` at startup, so one crash report is
one file rather than a directory.

**Lua changes need a restart, not a rebuild.** `data/core` is symlinked into the
build, so editing it and relaunching is enough. If a change you made did not take
effect, you are almost certainly running a stale copy — see
[stale `data/core`](#a-lua-change-did-not-take-effect) below.

## Make targets that do not work

Five of the advertised targets are broken. Knowing which saves a confusing
afternoon:

| target | what actually happens |
| --- | --- |
| `make check` | runs `python scripts/check.py` — **that file does not exist** |
| `make size` | runs `python scripts/bench.py` — **that file does not exist** |
| `make test` | declared `.PHONY` with **no rule** |
| `make bench` | declared `.PHONY` with **no rule** |
| `make debug-san` | sets `SANITIZE=1`, which **no makefile reads** — identical to `make debug` |

These are known and recorded in `CHANGELOG.md`. None of them is on any path you
need: the build is `make`, and the tests are the four `test-*` targets. `make
help` also still claims plugins and themes ship inside `data/`, which has not been
true since 0.2.0-alpha.

**There is no lint or style checker in this repository today.** `-Wall -Wextra` is
the only automated check on C, and it is not `-Werror`; note that
`-Wno-unused-parameter` is also on, so "clean" means "no warning other than unused
parameters".

---

# Build problems

## `SDL3/SDL.h not found`

SDL3 is required. There is an SDL2 auto-detect path in `mk/config.mk` that will
happily select SDL2 and link `-lSDL2`, but the dependency check compiles a probe
against `SDL3/SDL.h` and stops there — so an SDL2-only machine selects SDL2 and
then fails anyway. The auto-detect is vestigial; SDL3 is the supported
configuration.

```sh
sudo apt install libsdl3-dev          # Debian / Ubuntu
sudo pacman -S sdl3                   # Arch

If SDL3 is in a non-standard prefix, put a `sdl3.pc` on `PKG_CONFIG_PATH` rather
than expecting a variable. There is **no `SDL3_PREFIX` make variable** — it
appears in `make help` and in one error message, but nothing in `mk/` reads it.
```

## `lua.h not found`

```sh
sudo apt install liblua5.4-dev
sudo pacman -S lua
make LUA_VERSION=5.4
```

`make info` shows the detected version. The makefile probes
`lua5.4 lua54 lua5.3 lua53 lua` in that order via `pkg-config`, so a machine with
only 5.3 will have 5.3 selected rather than an error — whether the tree then
compiles cleanly against 5.3 is untested, and 5.4 is the version CI uses.

## `python3 not found`

Needed for two things: generating the icon header, and assembling `data/`. The
assembly script is standard library only, but **icon generation is not** — it
needs `Pillow`, plus either `cairosvg` or `rsvg-convert` on `PATH`.

`src/icon.inl` is generated, not checked in, so every fresh clone needs it and
`make` writes it for you. You will hit this directly after `make distclean`,
which deletes it:

```sh
pip install Pillow cairosvg        # or install librsvg for rsvg-convert
make                                # regenerates src/icon.inl, then bundles
```

`make gen-icons` refreshes `scripts/icons/` only and leaves `src/icon.inl`
alone on purpose — the build is what writes that.

```sh
make PYTHON=python      # if it is not called python3
```

## `make` says it needs a cdin-x checkout

Expected, and it is the one place the two repositories meet. The message names
the path it probed, which is the part worth reading:

```
cdin needs cdin-x to produce a runnable editor — it provides the mandatory
  set: the vim plugin, the extension manager, the default theme and the fonts.

  Looked for /path/to/cdin/cdin-x/scripts/bundle.py and it is not there.

  CDINX_DIR is currently /path/to/cdin/cdin-x, which defaults to a sibling of
  this checkout. cdin-x has to sit next to cdin, not inside it: `cdin/cdin-x`
  is one directory too deep for `../cdin-x` to find.
```

The mandatory set — vim mode, the extension manager, the default theme and the
fonts — lives in cdin-x, and a cdin without it is not an editor, so a fresh clone of
this repository alone cannot produce a runnable editor.

```sh
git clone https://github.com/m-mdy-m/cdin-x ../cdin-x
make                                   # it looks there by default
make CDINX_DIR=/somewhere/else         # or say where
```

**The default is `../cdin-x` — a sibling, not a subdirectory.** `cdin/cdin-x` is
one level too deep and is the mistake CI makes when it checks cdin-x out inside
the checkout. If the path in the message ends in `cdin/cdin-x`, that is the
problem.

**`make bin` needs none of this.** It compiles the binary and stops, which is what
you want when you are only touching C.

## The bundler refuses to write

Five failures, all deliberate — it fails rather than working around a problem:

| message | meaning |
| --- | --- |
| no essential plugin | cdin-x has no `essential = true` plugin under `X/core/`. `vim` and `manager` should be it |
| not exactly one essential theme | a build has to know which theme to start with. Zero or two is unanswerable |
| `fonts/` missing or empty | the text pipeline has nothing to render with |
| a `bundle_with` path is missing | a bundled plugin declared support files — the manager declares `cdinx` — that are not in the checkout, or that point outside it. Bundling without them would give an editor that starts and then does nothing |
| output is a symlink or junction | see below |

**A symlink or junction is refused rather than followed.** This one is a Windows
trap worth understanding: a junction does not report itself as a symlink through
the obvious API, so a check written for POSIX passes right over one and the
bundler writes *through* it — into whatever it was pointed at. The refusal
covers all reparse points, not just the kind it recognises.

If you hit it, delete the output directory and let the build recreate it.

## `--no-plugins` did not turn the extensions off

Working as intended, but the boundary is worth stating precisely.
`--no-plugins` and `config.plugins = false` select the **site directory** — where
a cdin-x checkout (`make link`) and your own plugins live. The bundled set is
mandatory and always loads, because a cdin without vim mode is not an editor and
a debugging flag is not a policy.

What you installed **from the panel** is in neither place: the manager keeps its
own store under `<data_home>/cdin/extensions/X`, loads it itself, and never reads
`config.plugins`. Those extensions survive `--no-plugins`. To switch one off, press
<kbd>Space</kbd> on it in the panel — that choice persists in
`<data_home>/cdin/extensions.lua` — or delete the store. See
[configuration](configuration.md#plugins).

## Warnings after a change to `src/`

`-Wall -Wextra` is on and the tree builds clean. A new warning is yours; do not
suppress it. `make debug` (`-O0 -g3`) is usually more informative about what went
wrong than the release build's diagnostics.

---

# Runtime problems

## `command already exists: <name>`

The `assert` in `command.add`. Two things registered one name, and without the
`overwrite` argument it stops.

The usual cause is **reloading a plugin that self-registers at require time**:
the loader `dofile`s the entry point, so its body re-runs on every load, while
sibling modules stay cached from the first one. Guard it:

```lua
local loaded = false
function M.init(core, config)
  if loaded then return end
  loaded = true
  -- …
end
```

The other cause is a genuine collision between two plugins. That is what the
assert is for — the alternative is a binding that silently runs the wrong thing.

## `attempt to call a nil value` during plugin load

The function you called does not exist yet. The usual cause in this repository is
**ordering, not a typo**: `core.register_vcs_provider` is installed from inside
the project scanner's thread body, and that thread does not run until the frame
loop starts — which is *after* every plugin's `init()`. A plugin that calls
`core.register_vcs_provider` from its own `init()` therefore gets exactly this
error. The other three `register_*` functions are defined at require time and are
safe to call from `init()`.

This is a genuine rough edge in the runtime, not something you did wrong. If you
hit it from an extension, the workaround is to defer the call with
`core.add_thread`, or to have your `init()` tolerate a nil
`core.register_vcs_provider` and register later.

`core:list-plugins` will show the plugin as not loaded; `core:open-log` has the
traceback.

## `plugin loading failed; continuing with core only`

One line in the log says the loader itself raised. The editor is running with the
core and nothing else. Read the lines above it — that is the plugin that failed.

Note what this message means: **the editor always starts.** A failing bundled
plugin is reported at error level and the rest still load; a failing site plugin
is logged and skipped. An editor that refuses to open is a worse bug than a
missing feature.

## A plugin I installed does not load

In rough order of likelihood:

**`config.plugins` excludes it.** `nil` means all site plugins, `false` means
none, and a table is a whitelist. If you set a whitelist, a plugin you installed
into the site directory afterwards is not in it.

**It went somewhere the loader does not look.** There are two roots
`core.plugins` knows: `EXEDIR/data/plugins`, which is bundled and always loads,
and `config.site_path()/plugins`, which is site and selected by `config.plugins`.
To see where that is:

```lua
require("core.config").site_path()
```

**You installed it from the panel.** Then it is in neither root: the manager's
store, `<data_home>/cdin/extensions/X`, loaded by the manager and by nothing
else. It does not show up in `core:list-plugins` and `config.plugins` has no say
in it. The panel's *Installed* section is the place to look, and the usual reason
it is not running is that it is disabled there.

**A bundled plugin of the same name won.** The scan is bundled-first and
first-seen-wins, so a name is never loaded twice. `core:list-plugins` shows the
source of each.

**Its entry point did not return a table**, or its `init` raised. Both are in the
log.

## The empty view's shortcuts do nothing

Four of the five rows printed on the start screen — <kbd>↑</kbd> <kbd>↓</kbd>,
<kbd>Tab</kbd>, <kbd>Return</kbd>, <kbd>Esc</kbd> — do nothing in 0.2.0.
<kbd>Ctrl</kbd>+<kbd>N</kbd> works, and clicking a recent item works.

The empty view handles those keys in an `EmptyView:on_key_pressed`, and no code
path ever calls it: a key press goes to `keymap.on_key_pressed`, and a command
only runs if its predicate holds. Every command those strokes name
(`command:select-next`, `command:complete`, `command:submit`, `command:escape`)
requires an open prompt, and the empty view has none.

Nothing to configure and nothing to install — it is a missing dispatch in
`data/core/events.lua`, tracked in the changelog. Until it is fixed, use the mouse
or <kbd>Ctrl</kbd>+<kbd>N</kbd>.

## The command palette, or find file, does not open

Four keystrokes are unbound on any build you have not extended, and that is
correct rather than broken:

| key | needs |
| --- | --- |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd> | the `palette` extension |
| <kbd>Ctrl</kbd>+<kbd>P</kbd> | the `finder` extension |
| <kbd>Ctrl</kbd>+<kbd>O</kbd> | the `finder` extension |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>O</kbd> | the `finder` extension |

An editor with no extensions should have no dead keys, so the runtime binds none
of them. Install from the manager and they work immediately.

**If you did install one and the key still does nothing**, check the order: the
manager loads what it installed, and `keymap.add` prepends, so the stroke should
be live. If it is not, the extension is disabled in the panel or its `init()`
raised — the panel's *Installed* section says which, and the log has the reason.

**If a key does the wrong thing** rather than nothing, two extensions want it and
the later one won. <kbd>Alt</kbd>+<kbd>J</kbd> is the common one: the runtime's
`root:switch-to-right` and cdin-x's `window:focus-down` both claim it.
[Extensions](extensions.md#what-is-not-in-the-build-and-what-each-one-binds) has
the collision table.

Open the manager with <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd>, move to
`palette` and press <kbd>Space</kbd>. It is installed and live without a restart.

**If the panel does not open either**, the bundled manager did not load. A failing
bundled plugin is reported at error level, so check the log
(<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>L</kbd>) for `mandatory plugin manager:`.

And the same applies to the other three: <kbd>Ctrl</kbd>+<kbd>P</kbd>,
<kbd>Ctrl</kbd>+<kbd>O</kbd> and <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>O</kbd>
all belong to the `finder` extension, so on a build with nothing installed they
are unbound rather than broken. `find file`, `open file` and `open folder` are one
plugin.

## The extension panel is empty, or cannot install

The panel always lists what the build carries, under **In the editor**. What is
missing is the *Available* section, and that comes from a catalog index the manager
downloads: one file, `X/manifest.lua`.

**Press <kbd>?</kbd>** — it writes to the log where the catalog is meant to be, whether
it is on disk, and the state of the last download. Then:

- **`not downloaded` and the download failed.** There is no network, or none of
  `curl`, `wget` (or PowerShell on Windows) is installed. The manager uses exactly
  those three, in that order, and the `curl` path gives up after 120 seconds.
  <kbd>Ctrl</kbd>+<kbd>R</kbd> tries again.
- **The catalog came from the wrong place.** `config.registry_url` and the
  `CDIN_X_BRANCH` environment variable decide it, and `config.registry_raw_url` wins
  over both if you set it.
- **An install fails part-way.** Files are downloaded into a staging directory and
  moved into place only when all of them arrived, so a failed install leaves nothing
  half-installed. Try again; the log has the reason.
- **An extension you installed is gone after a restart.** It is in
  `<data_home>/cdin/extensions/X`. If it is not loading, it may be *disabled* —
  that choice persists in `<data_home>/cdin/extensions.lua` — or `config.plugins`
  may exclude it, if it was installed into the site directory instead.

Nothing here involves git, and a cdin-x checkout is not needed.

## A theme did not apply

Four things can be true at once, and the order matters:

**The theme is not in a root the registry knows.** Roots are searched in order:
`config.user_dir/themes`, then `EXEDIR/data/themes`, then anything a plugin added
with `require("core.themes").add_root()`. `require("core.themes").names()`
returns exactly what is visible.

**It resolves to a file but the name does not match.** The directory name is the
theme's name. `<root>/MyTheme/theme.lua` is `MyTheme`. The `name` field *inside*
the file is only a label for `style.theme_name`, not a lookup key.

**You installed it from the panel.** Themes are written to the manager's store,
`<data_home>/cdin/extensions/X/themes/<name>/theme.lua`, and the registry is never
pointed at that directory — the manager only registers the build's own theme
directory and a cdin-x checkout in the site directory. So a panel-installed theme
is listed but unreachable by name, and `config.theme` cannot find it. Copy the
directory into `config.user_dir .. "/themes"`, which is the first root searched.

**`config.theme` names an extension theme and startup applied nothing.**
`config.theme` is applied at `style.lua` load time, long before any plugin runs, so
a theme in a root that only exists after a plugin registers it can fall back
silently. The runtime then retries unconditionally once plugins have loaded, so
this normally resolves itself — if it has not, the root is not registered under the
name you think it is.

A theme that applies but is missing colours is a different problem, and the usual
answer is that it is a hand-written theme without the `vim_*` keys — the runtime
has no fallbacks for those, and they render **opaque white** rather than
disappearing. [Adding a theme](https://github.com/m-mdy-m/cdin-x/blob/main/docs/building/a-theme.md) lists every key, the
six `vim_*` ones included.

## `data/` is not next to the binary

The binary resolves `data/` relative to itself. Move one without the other and you
get an editor with no fonts — text renders as nothing or as boxes — and no vim
mode, because the bundled plugin lives in there too.

```
build/linux-release/
├── cdin
└── data/          ← has to be beside it
```

## A Lua change did not take effect

Check, in order:

1. **Did you restart?** The binary does not reload Lua. `make` is not needed;
   relaunching is.
2. **Is `build/…/data/core` still a symlink?** If it became a copy, your edits go
   to the source and the build reads the copy.
3. **Is there a `__pycache__` in the way?** The copy fallback ignores it; a
   hand-made one may not.
4. **Did you edit the right repository?** `data/core` is this repository's. The
   palette, the tree, the finders, the tabs and the extra themes are cdin-x's,
   under `X/`, and are loaded from the *site* directory — a completely different
   path.

If `data/core` did get copied, delete `build/` and rebuild; the symlink is
recreated on every build precisely so a stale copy cannot survive.

## The editor crashed and no `error.txt` appeared

**It never will.** There is no crash handler that writes one. `data/core/lifecycle.lua`
used to carry a `core.on_error` that would write `error.txt` and save every dirty
document to `<filename>~` — and nothing in the tree ever called it, so it has been
removed.

What actually happens on an uncaught error: the bootstrap's `xpcall` catches it,
reports it through `cdin_log_fatal` into **`cdin-log.txt`**, and `main()` returns
normally. So the one file that reliably has a crash traceback is the one that does
*not* contain plugin errors.

**Do not rely on a crash backup.** Save before you do something risky, and if you
do lose work, the log view (`core:open-log`) will usually tell you what happened
even though nothing was written to disk for you.

If a crash backup matters to you, it has to be written from the bootstrap handler
in `src/lua/api.c`, and that is a reasonable thing to propose.

## A command exists but does nothing

Check the predicate, not the binding. `command.get_all_valid()` returns what is
available *right now*, and the command palette shows that list — so if your
command is not in the palette, it is the predicate, and `command.perform` returns
`false` rather than raising.

A predicate is `nil` (always), a module path string, or a class table. The
document commands use `"core.views.docview"`, so they are unavailable in the log
view and the empty view.

**They *are* available while a prompt is open**, which surprises people:
`CommandView` extends `DocView` in order to reuse its gutter and scrolling maths,
and `View:is` walks the metatable chain, so `active_view:is(DocView)` is true
there too. That is exactly what makes the `{ "command:submit", "doc:newline" }`
chains work — <kbd>Return</kbd> submits, or falls through to a newline, depending
on whether the first predicate holds.

## A key does nothing at all

Two ways a binding can be dead, and both are silent — a miss in
`keymap.on_key_pressed` just returns false.

**The stroke is one no key press produces.** The runtime builds the string it
looks up — `ctrl+`, `alt+`, `altgr+`, `shift+`, then the key's own name — and
matches it for equality, with no normalisation. `ctrl+shift+alt+n` is therefore
not a variant of `ctrl+alt+shift+n`: it is a string nothing builds. Every such
stroke is listed in the log at boot, with the spelling that would have worked:

```text
keymap: 1 bound stroke no key press can produce, so the binding is dead:
keymap:   "ctrl+shift+alt+n" -> treeview:new-directory: "alt" is repeated or
          out of order — modifiers are built ctrl, alt, altgr, shift - write it
          as "ctrl+alt+shift+n"
```

**The command is not there.** Either nobody registered the name, or its
predicate does not hold in the view you are in — a log-view command in a
document, say. `command.perform` returns false for both. `make test-plugins`
checks the first against the runtime's own bindings, and `make test-lua` checks
that every stroke the runtime binds is one a key press can produce; for the
second cause, run the command from the palette in the view you meant to be in.

**A modifier is not arriving.** Modifier keys are state, not part of the key's
name: the editor records that <kbd>Shift</kbd> is held and rebuilds the stroke on
the next key. So <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>L</kbd> arrives as `ctrl+l`
— `doc:select-lines` — when <kbd>Caps Lock</kbd> is on, because no Shift key-down
is ever sent; and a modifier whose key-up went missing (usually alt-tabbing away
while holding one) stays held for every key after it. <kbd>AltGr</kbd> is
reported as `altgr` and clears `ctrl`, which is deliberate: on the layouts where
it is <kbd>Ctrl</kbd>+<kbd>Alt</kbd>, the two are the same chord.

## A key does the wrong thing

Two bindings can both be live on one stroke. `keymap.add` **prepends** unless you
pass `true`, so a plugin's binding runs before the core's and the core's still
works when the plugin's predicate fails.

```lua
keymap.add({ ["ctrl+d"] = "mine" }, true)   -- replace instead of prepend
```

If you want yours to win outright, pass `true`. If you want the existing one to
stay as a fallback, leave it off. [The command reference](commands.md#binding-your-own)
has the rest.

## Unloading a plugin left its keys behind

`keymap.remove` detaches only the commands you name, and takes the same shape you
added. `command.remove` takes a name or a list of names.

Both expect the plugin to actually call them from its `unload()`. Nothing
enforces that at runtime — a plugin that registers and never unregisters
accumulates one copy per load, which shows up as a binding that behaves as if it
ran twice.

---

# Getting more detail

```sh
make debug          # -O0 -g3

# and NOT this: `make debug-san` sets SANITIZE=1, which no makefile reads.
# It is identical to `make debug` and always has been. To build with
# sanitizers, pass the flags yourself:
make debug CFLAGS="-O0 -g3 -fsanitize=address,undefined" LDFLAGS="-fsanitize=address,undefined"
```

`cdin-log.txt` next to the binary has every message at the default log level.
`core:open-log` shows the same thing in the editor, and its own
<kbd>Ctrl</kbd>+<kbd>C</kbd> copies a selection out of it.

For a bug worth filing, `make info` output plus the relevant part of `cdin-log.txt` is
usually enough to identify it.
