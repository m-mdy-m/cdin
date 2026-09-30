# The extension contract

This is the whole of what cdin guarantees an extension, and the whole of what
cdin-x is allowed to assume. If something is not here, it is not a contract,
and a change to it is a breaking change.

Two repositories, one boundary:

* **cdin** is the editor runtime. Its `data/` contains only `core/`. It knows
  nothing about any extension.
* **cdin-x** is the extension ecosystem. It provides the mandatory set a
  build bundles, and the optional workflows and plugins users install.

## 1. The mandatory set, and where it comes from

An editor with no extensions installed is not usable: it has no modal
editing, no default theme and no fonts. Those three things are mandatory.

They are not in cdin. They are in cdin-x, and a **build** copies them in:

```
python3 <CDINX_DIR>/scripts/bundle.py --out <DEST_DATA_DIR>
```

which writes exactly:

```
<DEST>/X/core/<n>/**            verbatim copy of each essential directory plugin  (X.* namespace preserved)
<DEST>/X/core/<n>.lua           verbatim copy of each essential single-file plugin
<DEST>/plugins/<n>.lua          shim, one line: return require("X.core.<n>")
<DEST>/themes/<t>/theme.lua     the essential theme(s)
<DEST>/fonts/**                 copy of cdin-x/fonts/
<DEST>/BUNDLE.lua               return { plugins = {sorted names}, themes = {sorted names} }
```

After this change the essential set is: plugin `vim`, theme `default`,
nothing else.

**Essential** is the selection rule and it is a marker on the plugin, not a
file list. `essential = true` in a plugin's manifest means "a cdin build
without this is not a working editor". Comments are stripped before the
marker is read, so a plugin that merely mentions `essential = true` in a
header is not bundled.

An essential plugin must be **self-contained**: every `require "X.…"` inside
it must resolve inside its own subtree, because the bundle contains that
plugin and nothing else. `make validate` in cdin-x checks this, and it can
only be checked there — the failure would otherwise appear in a built cdin.

The bundler never fetches, downloads or substitutes. If `fonts/` is missing
it fails; a build with no fonts cannot start, and silently shipping a
substitute would be worse than not shipping.

## 2. The runtime contract

SITE = `config.site_path()` — the host's own resolver. It is `config.site_dir`
if set, and otherwise `<data_home>/cdin/<config.site_dirname>`, which defaults
to `<data_home>/cdin/site`.

`data_home` is `$XDG_DATA_HOME` or `~/.local/share` on POSIX; `%LOCALAPPDATA%`,
then `%APPDATA%`, then `%USERPROFILE%\AppData\Local` on Windows.

**`config.site_dirname` is the single knob, and it lives in cdin** because cdin
is what resolves the directory: the loader is what appends it to
`package.path` and what walks it. cdin-x reads the host's `config.site_path()`
rather than computing a path of its own, so a user who renames the directory
renames it for both halves at once. `make test-site-dir` in cdin asserts the
two halves still agree.

1. `config.site_path()` — the site directory.
2. `package.path` gets `SITE/?.lua` and `SITE/?/init.lua` APPENDED (never
   prepended, so site can't shadow `core.*` or the bundled `X.core.vim.*`)
   when SITE exists. So `require "cdinx"` -> `SITE/cdinx/init.lua`, `require
   "X.core.treeview"` -> `SITE/X/core/treeview/init.lua`, while
   `X.core.vim.*` resolves to the bundle (`EXEDIR/data/X/...`) first.
3. Loader: every entry in `EXEDIR/data/plugins` (bundled, mandatory, always
   loaded) and then every `SITE/plugins/<n>/init.lua` or `SITE/plugins/<n>.lua`
   (site, controlled by `config.plugins`).
4. `require("core.plugins")`: `loaded` (name->module), `list()` (each item
   gains `source = "bundled"|"site"`), `load`, `unload`.
5. `require("core.themes").add_root(dir)` and `.rescan()` (new). Theme
   layout `<root>/<name>/theme.lua`.
6. Existing APIs stay (`core.register_vcs_provider`, `core.syntax.add`,
   `command.add`, `keymap.add`, `core.log`, `core.try`, ...).
7. Known limitation to document: bundled vim (from the CDINX_DIR checkout at
   build time) and site-installed integrations come from possibly different
   cdin-x versions; the vim registry (`X.core.vim.registry`) is the
   compatibility surface.

## 3. What the runtime owns, and what an extension owns

The runtime is the mechanism. An extension is a workflow. The line:

> Could this work with no input from the user?

`core:new-doc` can — an empty document needs no extension — so it is
runtime-owned and `ctrl+n` is a runtime binding. `core:find-file` cannot: it
prompts, so it is an optional workflow plugin and `ctrl+p` belongs to
whatever plugin implements it.

The runtime always provides: the command registry (`command.add`,
`command.remove`), the keymap registry and dispatch, `core.command_view`,
Doc / DocView / RootView and the `doc:*` and `root:*` commands, and the
public APIs extensions are written against — `core.register_vcs_provider`,
`core.syntax.add`, `core.set_project_dir`, `core.log`, `core.try`,
`core.register_help_shortcuts` and `core.unregister_help_shortcuts`.

`core.command_view` is a **runtime service**, not an optional workflow. vim,
shell, search, treeview, tab, window, menu, theme switcher and the workflow
plugins all use it. Do not move it.

## 4. Plugin lifecycle

* A plugin is a directory with an `init.lua`, or a single `.lua` file, in
  one of the two roots. The entry point returns a table with optional
  `init(core, config)` and `unload()`.
* Requires go **inside** `init()`, never at the top of the file: the catalog
  reads the entry point with `dofile()` to discover the manifest, and a
  top-level `require` would run the whole subtree's side effects just to look
  the plugin up.
* Register with `command.add` / `keymap.add`, and remove with
  `command.remove` / `keymap.remove` in `unload()`. Use
  `core.register_help_shortcuts` and keep the handle it returns, so `unload()`
  can hand it back to `core.unregister_help_shortcuts`.
* Loading, unloading and reloading must leave no stale command, key binding
  or help entry, and must not accumulate duplicates.
* Nothing bundled or site-installed is marked `essential`. Only the
  mandatory set is, and it is only ever written by cdin-x's own catalog.

## 5. Optional workflows

These live in cdin-x as ordinary, non-essential plugins, under
`X/core/<name>/`:

| workflow | plugin | key binding |
| --- | --- | --- |
| command palette | `palette` | `ctrl+shift+p` |
| find file | `finder` | `ctrl+p` |
| open file | `finder` | `ctrl+o` |
| open folder (project switch) | `finder` | `ctrl+shift+o` |
| reload module, open user/project module | `modules` | none; use the palette |

They are not in the mandatory bundle. A vim-only build remains usable through
vim's Ex commands — `:e`, `:w`, `:q`, `:new`, `:cd` — with none of them
installed.

The runtime invokes optional commands by name in one place, the empty view.
It uses `command.perform`, which returns false and does nothing for a name
nothing registered. That is deliberate: a missing optional command is a
silent no-op, not an error. A command that *does* exist keeps its normal
error handling.

## 6. What a cdin build needs

`CDINX_DIR` is the only cdin -> cdin-x input, and it is a path:

```sh
make                    # bin + bundle: needs a cdin-x checkout
make CDINX_DIR=/path   # …at that path
make bin               # compile the binary only: needs no cdin-x
```

The build never fetches anything. The release workflows and the Dockerfile
check cdin-x out as a sibling and copy the **assembled** `build/…/data`, never
the source `data/`.

## 7. Known limitation

The bundled vim comes from the CDINX_DIR checkout at build time; the site
installation comes from whatever cdin-x the user installed. Those can be
different versions, and there is no version negotiation. The compatibility
surface between them is `X.core.vim.registry`: an integration that only
uses the registry's documented extension points works across that gap, and
one that reaches into a vim module's internals does not.
