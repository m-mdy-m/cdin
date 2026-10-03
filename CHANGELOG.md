# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [0.2.0-alpha] — 2026-10-03

The headline is a repository boundary. cdin is now the editor **runtime**,
and the extension set a build ships is assembled from a sibling
[cdin-x](https://github.com/m-mdy-m/cdin-x) checkout at build time.
Everything else in this release — the loader rewrite, the new extension
points, four test targets that can only be written once the boundary is
enforced — exists to make that boundary hold and to keep it from drifting
back.

Two smaller arcs sit on top of it. The two log streams became one file the
editor can open, a keystroke the input layer cannot produce is now reported at
boot instead of silently doing nothing, and the documentation was checked against
the code in both trees rather than against itself — which is where the third arc
came from. Several pages had been quietly wrong about the boundary: they counted
three things where four cross it, told you to clone a repository to install an
extension, and claimed keystrokes that no build has ever bound. That pass is under
**Documentation** below, and the two bugs it found rather than merely recorded are
the stroke count in `test_commands.lua` and the error message that now prints the
`CDINX_DIR` it probed.

### ⚠️ BREAKING CHANGES

#### cdin is the runtime; the extension set is built from cdin-x

- **`data/` contains only `core/`.** `data/plugins/`, `data/themes/` and
  `data/fonts/` are gone from the source tree.
- **A build bundles the mandatory set from cdin-x.** `make` runs
  `scripts/assemble_data.py`, which links the source `core/` into
  `build/<platform>-<build>/data/core` and then runs
  `<CDINX_DIR>/scripts/bundle.py` for everything else. `CDINX_DIR` defaults to
  `../cdin-x`.
- **`make bin` compiles the binary only** and needs no cdin-x; `make bundle`
  assembles `data/` and does. With no cdin-x reachable, `make` fails with a
  message saying exactly that, rather than producing an editor that cannot
  start.
- **`--no-plugins` no longer disables vim.** Bundled plugins are mandatory and
  always load; `config.plugins` selects the *site* set only, so with no cdin-x
  installed the vim keys and `ctrl+n`/`ctrl+s`/`ctrl+z` still work on a bare
  editor.
- **`config.plugins = nil`** by default, meaning "every site plugin". `false`
  means "no site plugins", a table is a whitelist.
- **The loader knows two roots**: `EXEDIR/data/plugins` (bundled, mandatory)
  and `config.site_dir/plugins` (site, selected by `config.plugins`). A
  bundled plugin wins over a site plugin of the same name, and
  `plugins.list()` reports which is which.
- **`package.path` gains the site directory, appended.** Never prepended, so a
  site can extend the editor but cannot shadow `core.*` or the bundled
  `X.core.vim.*`.
- **User-facing workflows are no longer runtime commands.**
  `core:find-command`, `core:find-file`, `core:open-file`,
  `core:open-folder`, `core:reload-module`, `core:open-user-module` and
  `core:open-project-module` moved to cdin-x. `ctrl+p`, `ctrl+shift+p` and
  `ctrl+o` are no longer bound by the runtime, so an editor with no
  extensions has no dead keystrokes. `ctrl+n` stays: a new document needs no
  extension.
- **`core.set_project_dir(path)` is new.** The project-directory transition —
  validate, chdir, reset the file list, bump the revision — is a runtime API,
  because the working directory *is* the project and the state involved is the
  runtime's. The folder workflow calls it instead of poking at
  `core.project_dir` itself.
- **The empty view's shortcut help is no longer hardcoded.** Only what the
  runtime owns is listed; everything else arrives through
  `core.register_help_shortcuts`, which now returns a handle and has a
  matching `core.unregister_help_shortcuts` so a plugin can clean up after
  itself.
- **The empty view no longer has its own open-file prompt.** It delegates to
  `core:open-file` through `command.perform`, which is a silent no-op when no
  plugin registered one.
- **`core.themes.add_root(dir)` and `core.themes.rescan()` are new.** The theme
  list was a snapshot taken at require time, so a theme that appeared later —
  an extension's, registered during its own init — was loadable by name but
  never listed. A theme named by a persisted `config.theme` is re-applied at
  startup once the plugins have registered their roots.
- **The release workflows and the Dockerfile package the assembled
  `build/…/data`,** not the source `data/`, and check cdin-x out as a sibling.
- **`make test-plugins` no longer needs cdin-x or anything on disk.** Both test
  scripts build their tree from `scripts/fixtures/`, so a test can no longer be
  satisfied by whatever happens to be in `data/plugins/`.
  `scripts/test_lua.lua` and `scripts/test_commands.lua` are new — the target
  referenced them and they did not exist — and `scripts/_stub_env.lua` is the
  pure-Lua stand-in for the C modules that lets them run under a plain `lua`.
- **`make test-workflows` is new**, and it is the only test that reads the
  other repository. With `CDINX_DIR` pointed at a cdin-x checkout it boots the
  real loader against it and asserts the cdin-x half of the split: the workflow
  commands are registered, `ctrl+p`, `ctrl+shift+p`, `ctrl+o` and `ctrl+shift+o`
  each have **exactly one** command bound to them, the runtime keymap file
  names none of them, and unloading `palette`, `finder` and `modules` through
  the manager actually detaches the commands and the strokes. It runs with
  `site=empty` as well, which is the state before anything is installed.
  `test_commands.lua` already asserted the negative half — the runtime owns
  `ctrl+n` and none of the workflow strokes — but not this one, and the reason
  is the mechanism: `keymap.add` prepends, so a second owner of a stroke is
  queued behind the first rather than replacing it. A duplicate registration is
  invisible until a plugin is actually loaded.
- **`make test-lua` is new**, and gives `tests/lua/` a target. The unit and
  integration suite in that directory had none, so it was run by hand and
  rotted: two of its files still required `data/themes/`, which this change
  moved to cdin-x, and failed at `module 'fs' not found` because the harness
  never supplied the C `fs` / `path` preloads that `core.themes` now goes
  through. Both are fixed rather than deleted — the registry and the style
  fallbacks are still the runtime's, and the theme files are now fixtures
  under `data/themes/<name>/theme.lua` instead of a bundled directory. The
  target reuses the tree `scripts/test_lua.lua` already builds rather than
  growing a second copy of the fixture-copying code.
- **The contract is written down** in
  [`docs/architecture/extension-contract.md`](docs/architecture/extension-contract.md).

#### A self-contained layout was tried on this branch, and reverted

Between `beead74` and `aa08b96` this branch moved the extension set back into
`data/plugins/`, restored `data/themes/` and `data/fonts/`, added the
`plugin-manager` plugin and the first `make test-plugins`, deleted the
extension manager, and made a fresh clone build with `make` alone — no
cdin-x, no network, no sibling checkout. That state was real, it worked, and
it was tested; it is simply not what shipped, because `f46b1b3` onward puts
the split back and takes the bundle at build time instead. None of it is in
the tree today and this entry describes the shipped state only. The
keybinding-integrity work (`make test-plugins`, `scripts/test_commands.lua`,
the three dead-binding causes under **Fixed**) came out of it and is kept.

### Removed from the runtime

Every symbol below was defined in `data/core/` and had **no reference anywhere** —
not in core, not in `src/`, not in the tests, not in the docs as a feature, and
not in cdin-x. Removed because a knob that does nothing is worse than no knob:
it reads as a promise. Nothing here was on a live path, so nothing here is a
behaviour change.

| Deleted | File | Was |
|---------|------|-----|
| `plugins.autoload_list` | `data/core/plugins.lua` | `return config.plugins`, unread |
| `core.on_error` | `data/core/lifecycle.lua` | wrote `error.txt`, saved dirty docs — **called by nothing**, ever |
| `core.runtime.temp` (whole module) + `core.temp_filename` | `data/core/runtime/temp.lua`, `data/core/init.lua` | generated a scratch name from a per-run prefix and swept `EXEDIR` for that prefix on force-quit. Nothing called the generator, so no temp file was ever created and the sweep found nothing |
| `core.close_log_file` | `data/core/logging.lua` | closed the mirror handle; the process exit closes it |
| `help.count` | `data/core/help.lua` | number of registered help groups |
| `common.utf8_len`, `common.bench` | `data/core/utils/common.lua` | a `utf8.len` wrapper, and a `print`-based timing helper |
| `Object:implement` | `data/core/utils/object.lua` | a mixin helper, never called (and not inherited: `extend` copies only `__`-prefixed keys) |
| `command.names_of` | `data/core/input/command.lua` | sorted names of a registration map — advertised in the contract, adopted by nobody |
| `fs.ext`, `fs.stem`, `fs.split`, `fs.normalize`, `fs.is_absolute` | `data/core/fs.lua` | thin `_path` pass-throughs |
| `config.theme_auto_reload` | `data/core/config.lua` | `true`, read nowhere; there is no theme file watcher |
| `config.line_limit` | `data/core/config.lua` | `80`, read nowhere; there is no gutter truncation |
| `style.caret_block_alpha` | `data/core/style.lua` | `0.55`, documented with a failure mode — but **there is no block cursor in this editor**, so nothing read it |
| `doc_search` local | `data/core/views/docview.lua` | an unused `require "core.doc.search"` binding |
| `core.views`, `core.utils`, `core.input`, `core.runtime` | four `init.lua` aggregators | re-export tables nobody required. Every consumer already required the leaf directly — `core.views.view`, `core.utils.common`, `core.input.command`, `core.runtime.strict` |

#### Splitting the runtime from the extension set

`data/core/` used to contain things that are workflows, not mechanics:

| Deleted | Where it is now |
|---------|-----------------|
| `data/plugins/` — `core/*`, `languages/*`, `optional/*`, `tab/`, `treeview/`, `vim/`, `window/` | built output only, assembled from cdin-x |
| `data/themes/*.lua` — `default`, `dracula`, `nord`, `solarized-dark`, `solarized-light`, `monokai`, `github-light`, `gruvbox-dark`, `tokyo-night`, `catppuccin-mocha` | `cdin-x/X/themes/<name>/theme.lua`; one is bundled: `default` |
| `data/fonts/` — `font.ttf`, `monospace.ttf`, `icons.ttf`, `fallback.ttf`, `emoji.ttf` + 2 licences | `cdin-x/fonts/`, copied to `data/fonts` next to the binary |
| `data/user/init.lua` — the default user config | not bundled; `config.user_dir/init.lua` is read if present |
| `data/core/git/` — `init`, `exec`, `status`, `commands` | a git plugin in cdin-x, registered through `core.register_vcs_provider` |
| `data/core/commands/findreplace.lua` | a `find-replace` plugin in cdin-x; it prepends `find-replace:select-next` onto `ctrl+d` at load time |
| `data/core/search.lua` | cdin-x, or the C `search` API directly |
| `data/core/session_bootstrap.lua` | `data/core/preboot.lua` (rewritten — same job, no session-plugin dependency) |
| `core.load_plugins()` from `data/core/lifecycle.lua` | `core.plugins.load_all()` in the new `data/core/plugins.lua` |
| `config.optional_plugins` | gone with the loader that read it |
| `command.names_of` from `data/core/input/command.lua` | advertised in the contract; no extension adopted it |

`autoupdate` is gone for good rather than moved: it fetched and self-replaced
the editor over the network. Updating cdin is the user's job, as it is for
every other editor.

`core.git.*` is now a **hook, not a require**. `core/project.lua` and
`core/views/statusview.lua` read `core.vcs_provider`; with no git plugin
loaded, tree ignored-files and the status-bar branch render nothing and the
editor is otherwise unaffected.

#### `config.plugins` — choosing what loads

cdin can start with any subset of its **site** plugins, including none:

| Value | Loads |
|-------|-------|
| `nil` (default) | every plugin in the *site* directory |
| `false` | nothing — bare runtime plus the mandatory bundle |
| `{ "palette" }` | exactly these |

This is Vim's `pack/*/start/*` vs `pack/*/opt/*` split collapsed into one list,
with the same reasoning: what loads by default and what you opt into are
different questions, so they are answered in different places.

- **`--no-plugins`** — command-line equivalent of `config.plugins = false`.
  Parsed from `ARGS` before anything reads config and applied *after*
  `~/.config/cdin/user/init.lua` has run, so the flag overrides the list. It is
  a flag, not a path, and is kept out of the file/directory scan below it —
  `-u NONE` is accepted as a spelling and its argument swallowed.
- **User config runs before plugins.** `config.plugins` is user-owned, so
  `config.user_dir/init.lua` has to be read first. A consequence: a plugin's
  commands and keymaps are registered *after* user config, so a plugin can
  overwrite a keymap set in `init.lua` but not the reverse. `require`-ing a
  plugin's module from `init.lua` works — the site roots are already on
  `package.path` — but its `init()` side effects are not there yet.
- **`core:load-plugin` / `core:unload-plugin` / `core:list-plugins`** are the
  only way to change the set at runtime, and nothing persists across a restart.
  There is no state file to drift out of sync with the disk.

A plugin left out of the list is not gone — it stays on disk and loads on
demand. Naming a plugin that is not there is logged and skipped, so a config
written against another build still gets an editor.

### Added

#### The loader, with two roots and different rules for each

`data/core/plugins.lua` is new:

- `EXEDIR/data/plugins` is **bundled**: part of the build output, **mandatory**.
  Every entry loads, always, whatever `config.plugins` or `--no-plugins` say.
  This is what makes a build a runnable editor.
- `config.site_dir/plugins` is **site**: what the user installed, selected by
  `config.plugins`.
- A plugin is a **directory with an `init.lua`, or a single `.lua` file**. The
  entry point is read with `dofile()` — so it may return a manifest table —
  and never `require`d: a top-level `require` would run the whole subtree's
  side effects just to look the plugin up. `init(core, config)` is called if
  present, and it is where every `require` belongs.
- **A bundled plugin wins over a site plugin of the same name**, on disk and at
  runtime alike; `plugins.list()` reports which is which via
  `source = "bundled" | "site"`.
- **Load order is deterministic**: sorted by name inside each root, bundled root
  first.
- **`package.path` gains the site directory, APPENDED** — never prepended, so a
  site can extend the editor but cannot shadow `core.*` or the bundled
  `X.core.vim.*`. (`package.config`'s *second* line is the path-list separator;
  its first is the path separator, and joining new entries with the wrong one
  fuses them into the last existing entry instead of adding one.)
- **A plugin that raises is contained.** A failing *bundled* plugin is logged at
  error level and startup continues — an editor without vim is degraded, not
  unusable; a failing *site* plugin is logged and skipped. Either way the editor
  starts.
- `config.plugins` is read through `config.site_path()` at the point of use and
  never cached into a table field, because user config runs after
  `core.config` is required and must be able to change `config.site_dirname`.

#### Extension points — the API cdin-x may rely on

Written down in
[`docs/architecture/extension-contract.md`](docs/architecture/extension-contract.md).
If it is not in that document it is not a contract, and a change to it is a
breaking change.

| API | What it is for |
|-----|----------------|
| `core.register_help_shortcuts(list) → handle` | contribute rows to the empty view's Quick Reference, and **keep the handle** |
| `core.unregister_help_shortcuts(handle)` | hand it back in `unload()` |
| `core.register_status_pill(key, provider)` | a colored badge at the left edge of the status bar; `provider()` returns `nil`, or `text, bg_style_key, fg_style_key` |
| `core.register_recent_provider(provider)` | supplies `open_recent_picker` / `open_recent_dirs_picker` to the empty view |
| `core.register_vcs_provider(provider)` | `status.branch`, `status.is_ignored`, `refresh_ignored_now` |
| `core.set_project_dir(path) → ok, reason` | the project-directory transition |
| `core.themes.add_root(dir)`, `core.themes.rescan()` | register a themes root, so an extension's themes become listable |
| `core.style.set_fallback(key, hex)` | register a style fallback instead of having core hardcode one plugin's colors |
| `command.add(predicate, map, overwrite)` | third argument lets a plugin re-register a name it already owns |
| `command.remove(names)` | drop exactly the commands a plugin registered, and nobody else's |
| `command.names_of(map)` | the names a registration map owns, sorted |
| `keymap.remove(map)` | detach named commands from a stroke, leaving other owners bound |

- `core.register_help_shortcuts` returns an **opaque handle** rather than
  taking a name, so a plugin cannot remove another plugin's rows by registering
  the same list twice. The registry lives in the new `data/core/help.lua`, not
  in `empty_view.lua`, because a plugin calls it from its own `init()` and must
  not depend on which views happened to be constructed before it loaded. The
  empty view's built-in list now contains only what the runtime owns, so an
  editor with no extensions installed prints no keystroke that does nothing.
- `core.set_project_dir` is a runtime API because the state it touches *is* the
  runtime's: cdin is single-project, the working directory *is* the project, and
  `core.project_dir`, `core.project_files` and the revision counter the views
  watch are read synchronously. An extension that chdir'd on its own left the
  revision stale and the tree showing the previous project until something else
  forced a rescan. It validates the path, normalises it (`\` → `/`, strips
  trailing separators), chdirs under a `pcall` because `system.chdir` raises
  rather than returning false, updates the three fields, and drops the cached
  scan so a same-named file in the new project is actually visited. It returns
  `false` plus a reason and does not report it itself, so the same call works
  from a command, a keymap or the palette.
- `core.themes` is no longer a hardcoded list of ten names. It discovers
  `<root>/<name>/theme.lua` across `config.user_dir/themes`,
  `EXEDIR/data/themes` and any root an extension added, sorted, with earlier
  roots winning. The list used to be a snapshot taken at require time, so a
  theme that appeared later — an extension's, registered during its own init —
  was loadable by name but never listed. `core/init.lua` now re-applies
  `config.theme` after the plugins have registered their roots, which is what
  makes a persisted extension theme actually apply at startup.
- `keymap.remove` exists because `keymap.add` **prepends**: a second owner of a
  stroke is queued behind the first, not replaced. Without removal a plugin's
  `unload()` could not detach its own keys, and reloading it left live
  duplicates. It clears `reverse_map` only for commands no remaining stroke
  binds.
- The five `vim_pill_*` fallbacks left `core/style.lua`. The status bar knows
  how to lay out a colored badge, not what any badge means, and the mode
  vocabulary and colors belong to the plugin that registers the pill.

#### Runtime commands

`core:load-plugin <name>`, `core:unload-plugin <name>` (both accept a
comma-separated list) and `core:list-plugins` are new, in
`data/core/commands/plugin.lua`, registered with **no predicate** so they stay
reachable from the palette on a bare editor where nothing else has registered
anything. `core:load-plugin` is the `:packadd` case and is deliberately *not*
gated on the site set being enabled — that is how a bare editor stays useful
rather than merely empty.

#### Build: bundling the mandatory set

- **`mk/bundle.mk`** is new and holds the entire cdin → cdin-x coupling: one
  variable, `CDINX_DIR`, read nowhere in this repository except
  `mk/bundle.mk`, `scripts/assemble_data.py` and `scripts/_cdin/*.py`. Nothing
  under `src/` or `data/` names cdin-x, nothing is fetched, and there is no
  submodule or sibling lookup at runtime — a build takes a directory and reads
  files out of it. The `build:` recipe moved here from `mk/build.mk`, which now
  owns compilation only.
- **`scripts/assemble_data.py`** is new (stdlib only, Python 3.8+, no
  network) and produces the build output's `data/`:
  - `data/core` — a symlink to the source tree, **recreated on every run**,
    falling back to a copy on a platform that gives no symlink. Not
    created-if-missing: a link made once and then assumed correct is exactly how
    a stale copy becomes the editor you are running.
  - everything else — `python3 <CDINX_DIR>/scripts/bundle.py --out <data>`, with
    the same interpreter so a venv cannot end up bundling with a different
    Python. The mandatory set arrives as `X/core/<n>/**`, one-line
    `plugins/<n>.lua` shims, `themes/<t>/theme.lua`, `fonts/**` and a
    `BUNDLE.lua` index.
  - A symlink left at the output path by an older build is **unlinked, never
    traversed** — `shutil.rmtree` on a link deletes the *target's* contents, and
    a build script that can destroy the source tree is not something anyone
    should have to debug. On Windows any reparse point counts as a link,
    because `os.path.islink` is false for a junction and a junction redirects
    writes just as well.
  - With no cdin-x reachable it fails with a message saying exactly that,
    instead of producing an editor that cannot start.

#### Tests — four new make targets, split by what each one may read

`scripts/` had no test file at all before this release.

| Target | Reads | Runs |
|--------|-------|------|
| `make test-plugins` | nothing on disk — `scripts/fixtures/` only | `scripts/test_commands.lua`, `scripts/test_lua.lua` |
| `make test-lua` | nothing on disk — the fixture tree | `tests/lua/run.lua`, the pre-existing suite, finally given a target |
| `make test-workflows` | **cdin-x**, via `CDINX_DIR` | `scripts/test_workflows.lua` |
| `make test-site-dir` | **cdin-x**, via `CDINX_DIR` | `scripts/test_site_dir.lua` |

- `scripts/_stub_env.lua` is the pure-Lua stand-in for the C `fs` /
  `path` / `system` modules, which is what lets the data layer run under a plain
  `lua` with no build and no editor.
- `scripts/test_lua.lua` runs the loader and the theme registry eight times —
  site-present × site-absent against `config.plugins` = `nil` / `false` /
  `{demo}` / `{raiser}` — each in its own process, because each needs a fresh
  `EXEDIR` and a fresh `config.plugins` and they would otherwise fight over
  `package.loaded`.
- `scripts/test_workflows.lua` is the only test that reads the other
  repository, because it is testing the other repository's half of the
  contract, and there is nothing for it to do without a checkout to read.
  `scripts/test_site_dir.lua` guards the one thing that cannot be checked from
  either repository alone: cdin owns the *name* of the site directory, cdin-x's
  installer copies it, and a mismatch installs where the loader does not look.
- Both fixtures are built by the test scripts from `scripts/fixtures/`, so a
  test can never be satisfied by whatever happens to be on disk.
- The `tests/lua/` suite (`text_utf8`, `text_bidi`, `text_shaper`, `themes`,
  `text_pipeline`, `doc_edit`, `config_style_theme`) had no target and was run by
  hand, which is how two of its files came to require a `data/themes/` this
  change moved to cdin-x and failed at `module 'fs' not found`. Both are fixed
  rather than deleted — the registry and the style fallbacks are still the
  runtime's, and the theme files are fixtures under `data/themes/<name>/theme.lua`
  — and `make test-lua` reuses the tree `scripts/test_lua.lua` already builds
  rather than growing a second copy of the fixture-copying code.

#### The log is one file, and the editor can open it

- **One text file holds the whole log.** The C logger's file is now
  `cdin-log.txt` (was `cdin.log`; the rotated copy is `cdin-log.txt.1`), and the
  Lua stream is mirrored into it by default, tagged `LUA`, with `core.try`
  tracebacks. Before, the mirror was opt-in (`CDIN_LUA_LOG=1`) and wrote the
  message but never the traceback, because the traceback is attached after the
  line is logged. `CDIN_LUA_LOG=0` turns the mirror off. The file is opened once
  per run in line-buffered append mode instead of once per message.
- **`Ctrl+Shift+L` opens the log.** `core:open-log` had no binding, which made
  the log unreachable in exactly the build it matters most: the command palette
  is a plugin, so a bare editor had no route to it and no error either. The log
  view is the runtime's own view, so the stroke is the runtime's.
- **The log view has two sources and a key for each.** <kbd>F2</kbd> switches
  between the editor's `core.log_items` (every `core.log` / `core.error`, with
  tracebacks) and the C logger's file, and <kbd>Ctrl</kbd>+<kbd>R</kbd>
  re-reads the current one. The header names the file and its size, because
  "the log is somewhere" is not an answer and the file is next to the binary,
  which is not where anyone looks.
- **`cdin-log.txt` is bounded and quiet.** The file was opened at `LOG_TRACE`, so
  a day of editing produced 3.4 MB of per-frame renderer traces and nothing
  useful; it is now `LOG_DEBUG`, and past 4 MB the previous run is rotated to
  `cdin-log.txt.1` at startup rather than the file growing forever.
  `CDIN_LOG_LEVEL`, `CDIN_LOG_FILE_LEVEL` and `CDIN_LOG_FILE` override the level
  and the path.
- **`CDIN_LUA_LOG=1` mirrors the Lua stream into that file.** Off by default:
  the two streams are deliberately separate and a bug report wants the file to
  hold what the file is for. It exists for the one situation with no other way
  out — a Lua error during startup, when the log view cannot be opened yet.
- **`config.data_dir` is published.** An extension can only answer "what does
  this editor already ship?" if the editor says so, and an extension cannot
  know where its own data directory is. cdin-x reads this to see the set a
  build carries.
- **`RootView:attach_side_view(view, side, opts)` and
  `RootView:detach_view(view)`.** A side panel's whole interface, and the reason
  two extensions can both own an edge. Splitting the *active* node — which is
  what both cdin-x panels did — makes the layout depend on load order and on
  where the user last clicked: the second panel to load splits itself out of the
  first one, so the file tree ended up between the document and the extension
  panel. `attach_side_view` targets the edge of the layout instead, is idempotent
  across enable cycles, and does not steal focus; `detach_view` gives the space
  back on `unload`, so a disabled extension no longer leaves an unclosable empty
  column. Documented under *Side panels* in the extension contract.

#### Documentation

- **`docs/architecture/extension-contract.md`** is the whole of what cdin
  guarantees an extension and the whole of what cdin-x may assume: the mandatory
  set and how it is bundled, the runtime contract (site resolution, `package.path`
  order, loader roots), the line between what the runtime owns and what an
  extension owns, the plugin lifecycle, the optional workflows, and the one known
  limitation.
- `docs/architecture/overview.md` and `docs/architecture/internals.md`
  rewritten for the split; `docs/guides/plugins.md`, `configuration.md`,
  `commands.md`, `building.md`, `getting-started.md` and `troubleshooting.md`
  updated; `README.md`, `CONTRIBUTING.md` and `AGENTS.md` updated.
  *(The sync above removed `themes.md`, `syntax.md` and `vim-keybindings.md` and
  added `extensions.md`; the list is the state at the split.)*

### Changed

- **Boot order.** `core.init()` now: parse flags → build views →
  `command.add_defaults()` → **read `config.user_dir/init.lua`** → apply
  `--no-plugins` → `core.plugins.load_all()` → re-apply the persisted theme →
  load the project module → open the files named on the command line. User
  config runs *before* the plugins because `config.plugins` is user-owned. A
  plugin-loading failure no longer force-opens the log view; it logs and
  continues.
- **The runtime keymap went from 152 bindings to 85.** Every group a plugin used
  to own is gone from `data/core/keymaps/default.lua` — treeview, tab, window,
  autocomplete, session, project-search and find-replace — along with the
  empty-view `ctrl+o` / `ctrl+shift+o` entries. `ctrl+d` keeps `doc:select-word`;
  the find-replace plugin prepends `find-replace:select-next` onto it at load
  time. `ctrl+f`, `shift+r` and `ctrl+shift+h` are gone from the runtime and are
  the plugin's to bind.
- **`ctrl+tab` / `ctrl+shift+tab` are no longer bound by the runtime.** Cycling
  within the active pane is still there under its new names; whole-layout tab
  switching is the tab plugin's.
- **`root:*-tab*` renamed to `root:*-pane-view*`, old names kept as aliases:**
  `root:switch-to-{next,previous}-pane-view`, `root:move-pane-view-{left,right}`,
  `root:switch-to-pane-view-1…9`. These operate on `node.views` — the open
  buffers within the *currently active split pane* — which is a different,
  lower-level thing than the tab plugin's whole-layout freeze/restore concept.
  Both used the word "tab" for their own unrelated notion of it, which made it
  impossible to tell from a command name alone which system a given `tab`
  command belonged to. The old names remain as aliases so an existing keymap or
  script keeps working.
- **The status bar's vim-mode pill is now a generic pill registry.**
  `core.register_status_pill(key, provider)`; multiple pills draw left-to-right
  in registration order. There is intentionally no built-in tab indicator — the
  tab plugin wraps `StatusView:get_items()` itself and appends its own, because
  core has no business knowing the tab plugin's data shape.
- **`command.add_defaults()` discovers `data/core/commands/*.lua` from disk**
  instead of hand-listing five names, so adding a command module — splitting
  `doc.lua` into `doc.lua` + `selection.lua`, say — needs no edit there. It also
  requires `core.rootview.node` and `core.views.logview` up front, because both
  register their commands at require time and both are named by the keymap.
- **`config.site_dirname`** is the single knob for the site directory's *name*
  (default `"site"` — what vim and neovim call exactly this thing, third-party
  content as opposed to the editor's own), and it lives in cdin because cdin is
  what resolves the directory. `config.site_dir` overrides it with a full path.
  `config.data_home` and `config.sep` are exported so `config.site_path()` can
  rebuild the path at the point of use; cdin-x reads `config.site_path()` rather
  than computing a path of its own, so renaming the directory renames it for
  both halves at once.
- **`core/style.lua` reads its fonts from `config.fonts_dir`** instead of
  hardcoding `EXEDIR .. "/data/fonts"`, and exposes `style.set_fallback` so an
  extension can register a fallback instead of having core hardcode its colors.
- **`data/core/preboot.lua`** replaces `session_bootstrap.lua`: same job — read
  the persisted `session.lua` before the editor starts and apply the saved
  theme — with no dependency on a session plugin, and a `recent` →
  `recent_files` migration for older state files.

- **The extension manager ships with every build.** It is marked `essential` in
  cdin-x, the same marker vim carries, so `make` bundles it and the panel is
  reachable in a build with nothing installed — <kbd>Ctrl</Shift>+<kbd>M</kbd>,
  or <kbd>M</kbd> in vim normal mode. Everything it *offers* stays optional;
  what is not optional is the ability to ask what is installed. See cdin-x's
  changelog for the panel itself.
- **`core.quit` asks the loop to stop instead of calling `os.exit()`.** Quitting
  runs with the frame loop on the stack — a keymap, a command, a submit callback
  — and `os.exit()` from there put `atexit(SDL_Quit)` in the middle of SDL's own
  event dispatch. The process survived it: window destroyed, event loop gone,
  every key dead, nothing drawn, and no way out from inside. `:qa!`, the title
  bar's close button and the window manager's close all went through this, so
  all three froze the editor instead of closing it. `core.run()` now returns when
  the quit is requested and `main()` unwinds the window in order. Extensions that
  wrap `core.quit` are unaffected as long as their wrapper is synchronous,
  because a thread scheduled at exit is a thread that will now never run.

### Fixed

- **The "cdin needs cdin-x" error never said where it looked.** It named the
  problem and stopped, so the one thing that identifies the actual cause — the
  resolved `CDINX_DIR` — was nowhere in the output. That is exactly the failure
  CI hit: the Docker build had cdin-x present and readable, one directory too
  deep for `../cdin-x` to resolve, and the log could not distinguish that from a
  missing checkout. The message now prints the path it probed and says the
  default is a *sibling*, not a subdirectory. It also lists the extension
  manager, which is part of the mandatory set and was missing from the list.

- **`scripts/test_commands.lua` reported a hardcoded stroke count.** The success
  line said "86 strokes checked" as a string literal, so it went on claiming a
  number the test no longer computed — it was 85, and it drifted silently every
  time a binding was added or removed. It is now counted from `keymap.map`, which
  is what the message was always claiming to be about.

- **Dead core keybindings, three separate causes, all invisible at runtime** — the
  key press was consumed, nothing ran, and nothing errored:
  - `command.add_defaults()` skipped `data/core/commands/command.lua`, on the
    reasoning that a file sharing the module's own name must be a duplicate. It
    is not: that file holds the `command:*` commands the palette itself needs to
    function, so `Return`, `Tab`, `Escape`, `Up` and `Down` were bound to
    commands that were never registered. It is loaded like every other command
    module now, and the exclusion — and its wrong reasoning — is gone from the
    comment.
  - `empty_view.lua` and `logview.lua` register their commands at require time
    but were only required lazily, by whoever opened the view. Both are named by
    the core keymap, so `ctrl+o` / `ctrl+shift+o` on the empty view and
    `ctrl+c` / `ctrl+a` in the log were bound to commands that did not exist
    yet.
  - `core:open-folder` was called by `empty-view:open-folder` but never defined
    anywhere, so `ctrl+shift+o` on the empty view did nothing at all.

  `make test-plugins` now asserts that every command the keymap names exists
  with zero plugins loaded — the "ctrl+o opens a menu that does nothing" check.

- **Themes now actually apply.** `data/core/themes.lua` defined
  `style.set_theme` against an undeclared global `style`, so requiring the
  module raised an error that the caller swallowed in a `pcall` — leaving
  `style` permanently on its built-in fallbacks. The duplicate method (already
  on `core.style`) is gone, and lookup spans the user, bundled and extension
  roots.

- **Lua edits reached the editor on Windows again.** `build/<platform>/data`
  used to be created with a bare `ln -s`, which MSYS silently turns into a
  *copy* unless winsymlinks are enabled — and the `[ ! -e ... ]` guard then
  made that copy permanent, so it was written once and never refreshed. Every
  later edit under `data/` was ignored by the built editor, which is the worst
  kind of bug: the code on disk is correct and the running binary disagrees.
  `assemble_data.py` recreates the link (or the copy) on every build, and the
  Windows-only `_sync_data_windows` hack in `scripts/_cdin/build.py` is deleted
  rather than kept as a second mechanism for the same job.

- **Core no longer depends on an extension at startup.** The extension manager's
  registry sync did `require "X.core.git.exec"` — a module belonging to the git
  extension, in a directory `data/core/` had no business knowing about. The
  editor died at startup with `module 'X.core.git.exec' not found` before it
  drew a frame, and the same line broke cdin-x, where it pointed at a
  `core/git/` that never existed. Git is now a provider registered at load time,
  and with nothing registered the treeview renders no ignored-file markers and
  the status bar renders no branch, rather than either failing.

- **The install and update scripts install a runnable editor.**
  `scripts/_cdin/utils.py`'s `find_data_dir()` used to prefer the source
  `data/`, which now holds only `core` — that install has no fonts and no
  theme and fails at *startup* rather than at install time, which is the worst
  place to find out. It now recognises an assembled tree by its `BUNDLE.lua`
  index and prefers `build/*/data`. `scripts/_cdin/update.py` copies the
  assembled `build/…/data` next to the new binary and fails loudly if the build
  produced none, instead of silently installing a source tree.
  `scripts/cdin.py build` now passes the flags the Makefile actually reads
  (`BUILD=`, not the `BUILD_TYPE=` that nothing read) plus `CDINX_DIR=`.

- **`log:switch-source` was bound to a keystroke nobody can type.** The log
  view's layer had `["ctrl+s+l"]`, and a stroke is a string the input layer
  *builds* — `ctrl+`, `alt+`, `altgr+`, `shift+`, then the key's own name —
  which `keymap.map` then matches for equality, with no normalisation. There
  is no stroke with two key names in it, so switching between the editor's log
  and the native one had no working key at all, while `docs/guides/commands.md`
  and the view's own header (`f2 native log`) both said F2. It is bound to `f2`
  now. F2 was free in the runtime; an extension that binds it globally can
  still take it, which is what cdin-x's treeview did — hence
  `treeview:toggle-key`, a command that exists only so that one keystroke can
  decline while the log is open, leaving `treeview:toggle` itself available.
- **A keystroke nothing could press passed every check.** Both failures above
  are silent: `keymap.on_key_pressed` misses, returns false, and nothing is
  written anywhere. So `keymap.add` now records every stroke it cannot build
  (`keymap.unreachable`, with the reason and the spelling that would have
  worked), and `core.init` reports the list once boot is done and every plugin
  has registered. Nothing is refused — a binding nobody can press is already
  inert, and refusing it would turn a typo in one plugin's keymap into a boot
  that fails for everybody. Covered by `make test-lua`, whose new
  `tests/lua/unit/keymap_stroke_test.lua` pins the rule itself: which spellings
  the input layer can build, why the others cannot, and that the suggestion
  handed back is the string `on_key_pressed` really looks up.
- **`make` could not generate the icon header.** `mk/build.mk` still called
  `gen_icon.py` with the flags that existed before the generator moved into
  `scripts/_cdin/`: `--out`, plus `--no-inl` for `make gen-icons`. Neither
  exists now, and because `argparse` accepts unambiguous abbreviations,
  `--out` was read as a prefix of `--out-dir`, `--out-ico` and `--out-inl`
  and rejected as *ambiguous*. Every fresh clone hit it, because
  `src/icon.inl` is generated and `make` has to produce it. CI never did:
  the release workflows write the header themselves first, with the current
  flags, so the rule had nothing left to run. Both invocations now use
  `--out-inl` / no `.inl`, the rule also depends on the generator that
  actually does the work, and the interpreter comes from `PYTHON` like the
  rest of the build does — so the documented `make PYTHON=python` now covers
  icon generation too, which it did not.
- **A keystroke that named a command nobody registered.** `make test-plugins`
  and `make test-workflows` cover this; both pass.
- **The second of two side panels was given the whole window.**
  `calc_split_sizes` placed the divider using the first locked child's size and
  handed the remainder to the other, so it only ever honoured *one* locked pane
  per split. That is correct until two panels are side by side — the file tree
  and the extension panel — and then the second one, which had asked for 460px,
  filled everything the first had not claimed and pushed the document off the
  screen. Each locked child now gets the width it asked for.
- **A pane collapsing next to a locked pane raised instead of collapsing.**
  `Node:collapse` is now shared by closing a node's last view and by
  `remove_view`, and it clears the lock before installing the empty view —
  `add_view` refuses a locked node, so that branch could only ever assert.

### Documentation

- **The documentation is synced against both repositories.** Every claim was
  checked against the code in both trees rather than against the previous page,
  and a page that disagreed with the code was the bug. The split is now described
  the same way everywhere: **four** things cross the line — vim, the extension
  manager, the `default` theme, the fonts — not three. Three carry
  `essential = true` in cdin-x and only those three plus the fonts reach a build.

- **`docs/guides/extensions.md` is new**, and holds the arrangement in one place:
  what a build contains, what each optional extension binds, the
  <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd> panel, what installing actually
  downloads, and where everything lands on disk.

- **`themes.md`, `syntax.md` and `vim-keybindings.md` are gone.** All three
  described extensions, and all three belong to the repository the extensions
  live in — an extension's documentation should change when its code does. They
  are replaced by pointers to cdin-x's `a-theme.md`, `a-syntax-definition.md` and
  `plugins/vim.md`. The runtime's half — the theme registry, the tokenizer, the
  loader — is still documented here.

- **Installing extensions does not clone anything, and the docs said it did.**
  Getting started told you to clone cdin-x and run `make link`; `plugins.md` said
  a build installs nothing. The manager fetches one index file
  (`X/manifest.lua`) and then exactly the files of the extension you picked, over
  HTTPS with `curl` / `wget` / PowerShell, into a staging directory. You need a
  cdin-x checkout to *build* cdin and to work on cdin-x — not to use it.

- **Every optional extension now has its keys, and what it collides with.**
  <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>O</kbd> was listed beside
  <kbd>Ctrl</kbd>+<kbd>O</kbd> as though the pair were a unit, and both belong to
  cdin-x's `finder` — which is `essential = false` and in no build. So on a fresh
  build all four of those keys are unbound, and a build's entire cdin-x keystroke
  inventory is two: <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd> and
  <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>L</kbd>. Two tables now exist — one per
  extension, one for the strokes where two extensions want the same key:
  <kbd>Alt</kbd>+<kbd>J</kbd>/<kbd>K</kbd>/<kbd>L</kbd>, <kbd>Ctrl</kbd>+<kbd>D</kbd>,
  <kbd>Ctrl</kbd>+<kbd>R</kbd>, <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>D</kbd> and
  <kbd>F2</kbd>. Three of those cost something real; the predicate-gated ones are
  the design working and are called out as such.

- **`Ctrl+Shift+M` and `Ctrl+Shift+L` are bound by the runtime's own bundle.** Both
  were documented as things to bind yourself. The log had no binding at all, which
  made it unreachable in a bare editor — the palette is a plugin, so with nothing
  installed there was no route to it and no error either.
  <kbd>Shift</kbd>+<kbd>M</kbd> still needs cdin-x's `vim-plugin-manager`
  integration, because a global capital `M` is also how you type an `M`.

- **`--no-plugins` and `config.plugins = false` do less than the docs claimed.**
  They select the *site* directory. The mandatory set is unaffected, and what the
  manager installed is in neither root — it keeps its own store under
  `<data_home>/cdin/extensions/X`, loads it itself, and never reads
  `config.plugins` — so those extensions survive the flag too. That is the case
  people actually hit.

- **Your `init.lua` cannot `require` a site plugin's module.** The loader extends
  `package.path` as the first statement of `load_all()`, which is step 11 of the
  boot order; your file is step 9. Three pages said the opposite, and the
  `require` example had the wrong prefix — the site *root* is added, not
  `site/plugins`, so the path is `plugins.<name>.…`.

- **The Lua log is not absent from `cdin-log.txt`.** `commands.md` said no Lua
  output reaches the file. It is mirrored in, tagged `LUA`, tracebacks included,
  unless `CDIN_LUA_LOG=0`.

- **`doc:delete-to-next-char` exists.** `commands.md` said it did not, three
  lines after saying all sixteen `delete-to` commands exist. It is generated and
  simply unbound.

- **Panel details that were guesses.** The manager's keys are lowercase,
  <kbd>Esc</kbd> is the only way out and there is no <kbd>q</kbd>, the catalog
  index is ~18 KiB rather than ~16, the title-bar counts show *matches* while a
  search is running rather than totals, and <kbd>Return</kbd> enables or disables
  rather than opening a submenu. The two precedence rules do not agree with each
  other either: the runtime loader takes the first name it sees (bundled beats
  site), the manager takes the last root it scanned (a site checkout beats the
  bundle).

- **A theme installed from the panel is not registered as a theme root.** It is
  written to the store and listed, but `themes.add_root` is only ever called for
  the build's own theme directory and a cdin-x checkout in the site directory —
  not the store. So it does not reach the theme switcher and `config.theme` cannot
  find it by name. Documented as the gap it is, with the workaround.

- **`make test-site-dir` is documented where it belongs.** It existed and was in
  no page's list. It is the smallest suite and the easiest to skip, and it is the
  only thing keeping cdin's `config.site_dirname` and cdin-x's copy of it the same
  word.

- **`make check` is not "lint and style".** `building.md` called it that in one
  sentence while calling it broken in three others. It runs
  `scripts/check.py`, which does not exist. **There is no lint or style checker in
  this repository** — the compiler is it, at `-Wall -Wextra` without `-Werror`.

- **`make debug-san` is not a sanitizer build.** It sets `SANITIZE=1`, which no
  makefile reads, so it is `make debug` with extra steps. Troubleshooting's closing
  section recommended it; it now says so and shows the flags to pass.

- **`docs/` rewritten.** Eleven pages and a new `docs/README.md` index, with a
  reading order. The old set had no index, duplicated the extension
  documentation, and could not be navigated.
- **The runtime/cdin-x boundary is now stated everywhere.** Every page used to
  tell users to press <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd> and to run
  `core:open-user-module` — neither of which the runtime owns. Both are cdin-x
  plugins. The command reference now says so explicitly and explains why the
  runtime leaves those keys unbound.
- **`docs/guides/configuration.md` no longer inverts the load order.** It
  claimed the user config "loads last, after the core and all extensions". It
  loads *before* plugins, which is what makes a plugin able to override a key you
  set and you able to override a key a plugin sets.
- **`docs/guides/vim-keybindings.md` no longer describes files that do not
  exist.** It listed `vimode.lua`, `ex.lua`, `fmenu.lua` and `shell.lua`; vim
  mode is `X/core/vim/` in cdin-x, and there is no `fmenu.lua`. It also pointed
  at `data/user/init.lua`, which is not a path cdin reads. *(Removed entirely in
  the sync above; the pointers to cdin-x's `plugins/vim.md` replace it.)*
- **New: `docs/guides/syntax.md`.** The highlighter, the tokenizer and the
  definition format are in this repository and no page covered them. *(Removed
  in the sync above: the tokenizer and the registry are the runtime's and are
  documented in `internals.md`; writing a definition is cdin-x's, and that half
  moved out with it.)*
- **UTF-8 corruption removed from `docs/`.** Six pages had em-dashes and
  box-drawing characters mangled into replacement characters, including the whole
  architecture diagram.
- `docs/architecture/extension-contract.md` rewritten as the normative list of
  what cdin guarantees, with an explicit **not guaranteed** section — including
  the functions cdin-x wraps today (`keymap.on_key_pressed`, the `RootView`
  methods, `StatusView.get_items`) and the commands that belong to cdin-x.
- `docs/guides/building.md` no longer claims SDL2 is auto-detected and
  supported. `mk/config.mk` still has the path, but `mk/build.mk` hard-requires
  `SDL3/SDL.h`, so an SDL2-only machine selects SDL2 and then fails. The page
  now says SDL3 is required and why.

### Build, packaging & CI

- `make` = `bin` + `bundle`; `make bin` = binary only, no cdin-x;
  `make bundle` = assemble `data/`; `make CDINX_DIR=/path` points the bundle at
  another checkout. `make help` still says "a plain `make` is all you need —
  plugins and themes ship inside `data/`", which is no longer true; the line is
  corrected below in the known issues rather than silently left to mislead.
- The three release workflows check cdin-x out at `path: ../cdin-x` — a true
  sibling, one level above the repo — which is what the default `CDINX_DIR`
  (`$(abspath $(CURDIR)/../cdin-x)`) resolves to. `docker.yml` cannot do that:
  `COPY` only reaches inside the build context, so it checks cdin-x out at
  `./cdin-x` and the `Dockerfile` copies it to `/cdin-x`, the sibling position
  the default expects. All four package the **assembled** `build/…/data` — the
  tree sitting next to the binary they just built — instead of the source
  `data/`. A release without the bundle cannot start, so shipping the source
  tree was always wrong; it just did not matter while the source tree *was* the
  whole editor.
- **`Dockerfile` copies the assembled `data/` into the image.** No `CDINX_DIR`
  is baked into the image: the bundle is resolved at image build time.
- Trailing-newline fixes in the three release workflows and the Dockerfile.

### Migration

From `0.1.3`, which is the last published release:

| You had | Do this |
|---------|---------|
| `data/plugins/<name>` in this repository | the plugin is in cdin-x; a build bundles the mandatory set, and `config.plugins` selects what is installed in your site directory |
| `data/themes/<name>.lua` | `<name>/theme.lua` in a themes root; user themes go in `<config_home>/cdin/user/themes/<name>/theme.lua` and win over bundled ones by name |
| `data/fonts/*.ttf` | cdin-x; the build copies them into `data/fonts` next to the binary |
| `config.optional_plugins.<name> = false` | gone — it selected plugins from a directory that no longer exists |
| a keymap naming `find-replace:*`, `tab:*`, `window:*`, `treeview:*`, `session:*`, `project-search:*`, `autocomplete:*`, `core:find-command`, `core:find-file`, `core:open-file`, `core:open-folder`, `core:reload-module`, `core:open-*-module` | bind it only if the matching cdin-x plugin is installed — `core:load-plugin` it, or add it to `config.plugins` |
| `core.git.*` | `core.vcs_provider.status.*`, via `core.register_vcs_provider` |
| `require "plugins.<name>"` across extensions | `require "X.core.<name>"`; the runtime appends the **site root** to `package.path`, so an extension's own modules are `require "plugins.<name>.…"` — the `plugins.` prefix is not stripped |
| a `require` of a site plugin's module from `init.lua` | move it into that plugin's `init()`, or into a command. The loader extends `package.path` as the first statement of `load_all()`, which runs *after* your file |
| `config.site_dir = "<path>"` | still works; `config.site_dirname` is the new knob if you only want to rename the directory under the data home |

### Known issues and limitations

- **Four of the five shortcuts on the start screen do nothing.**
  <kbd>↑</kbd> <kbd>↓</kbd>, <kbd>Tab</kbd>, <kbd>Return</kbd> and <kbd>Esc</kbd>
  are printed by the empty view and unreachable;
  <kbd>Ctrl</kbd>+<kbd>N</kbd> and clicking a recent item are what actually work.
  `EmptyView:on_key_pressed` handles all four, and no code path calls it:
  `events.lua` routes a key press to `keymap.on_key_pressed` and to nothing else,
  so a key only ever reaches a command by name — and every command those strokes
  name requires an open prompt, which the empty view has none of. **Not fixed in
  this release**: it is a missing dispatch in `data/core/events.lua`, not a
  documentation problem. It is recorded here because the screen printing a
  keystroke that does nothing is the one thing that should not happen, and three
  pages plus the extension contract were rewritten to stop claiming otherwise.

- **Three keystrokes change meaning once particular extensions are installed.**
  <kbd>Ctrl</kbd>+<kbd>R</kbd> stops reloading the log (`treeview:rename-key`),
  <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>D</kbd> stops duplicating a line
  (`session:open-recent-dirs`), and <kbd>F2</kbd> stops switching the log's
  stream (`treeview:toggle-key`). `keymap.add` prepends, so the extension loaded
  later wins. There is no runtime binding to move; the fix is to rebind in
  `init.lua`, which runs before every plugin. Tabulated in
  `docs/guides/extensions.md`.

- **The mandatory bundle must be self-contained.** Every `require "X.…"` inside
  an essential plugin has to resolve inside its own subtree, because the bundle
  contains that plugin and nothing else. cdin-x's `make validate` checks this,
  and it can only be checked there — the failure would otherwise appear in a
  built cdin.
- **`make`, `make bundle`, `make test-workflows` and `make test-site-dir` all
  need a cdin-x checkout.** `make bin`, `make test-plugins` and `make test-lua`
  do not. There is deliberately no target that fetches cdin-x.
- **`empty-view:open-folder` is a silent no-op unless a plugin registers
  `core:open-folder`.** The runtime keeps the command as a delegation point —
  per the contract, `finder` owns it — and does not implement it itself.
- **Bundled vim and site-installed integrations can come from different cdin-x
  versions**, and there is no version negotiation. `X.core.vim.registry` is the
  compatibility surface: an integration that uses its documented extension
  points works across the gap; one that reaches into a vim module's internals
  does not.
- **Five advertised make targets are broken**: `check` and `size` call scripts
  that do not exist (`scripts/check.py`, `scripts/bench.py`), `test` and `bench`
  are `.PHONY` entries with no rule, and `debug-san` sets `SANITIZE=1`, which no
  makefile reads — so it is `make debug` with extra steps. `make help` also still
  claims plugins and themes ship inside `data/`. All documented as broken now
  rather than advertised. Carried over from `0.1.0-beta.7`.
- **C-level test tiers (unit / integration / e2e) still do not exist.** Everything
  tested in this release is the Lua data layer, under a plain `lua`.

### Stability

- **The C layer grew, and stayed small.** Five files under `src/` are touched:
  `src/core/logger.{c,h}` (a second file handle for the Lua mirror),
  `src/fs/ops.c` (`mkdir_all` no longer reports "Permission denied" for every
  absolute path on Windows — `C:` is a root to skip, not a directory to
  create), `src/lua/api.c` (publishes the log path to Lua as `LOGFILE`, so the
  log view can name the file instead of leaving the user to guess) and
  `src/main.c` (log level from the environment, size-bounded rotation at
  startup, and `core.quit` asking the loop to stop so `main()` unwinds the
  window in order rather than `os.exit()` from inside SDL's event dispatch).
- **`package.path` needs no help.** `src/lua/api.c` already put
  `EXEDIR/data/?.lua` and `EXEDIR/data/?/init.lua` on it, and the loader only
  ever appends — so moving the extension set to a sibling checkout cost no C.
- The alpha cycle continues. The loader, `config.plugins`, `config.site_dirname`
  and the extension points above are written down in
  `docs/architecture/extension-contract.md`, and a change to any of them will be
  a breaking change.
- **The contract was audited in the same pass, and three of its claims were
  wrong.** `View:on_key_pressed` is listed nowhere and now carries an explicit
  row — defined by nothing, no dispatch path calls it. `core.project` appeared
  twice in the *not guaranteed* table, once saying to use `set_project_dir` and
  once saying it does not exist. And the side-panel section told extensions to
  attach to an edge rather than the active node, while both cdin-x panels still
  split the active node — the exact conflict that section warns about, so it now
  says so. It is harmless with one panel and a fight the day there are two.
- **Not verified by a test run.** No `lua` and no C compiler were available where
  this pass was done, so `make` and the four suites could not be executed. Every
  claim above was checked by reading the source in both trees — file and line —
  and the two code fixes are each one line of intent. A run of `make && make
  debug` plus the four suites is still owed before this is tagged.

### Theme authoring, in cdin-x

- Themes are **single-file**: each theme is just `theme.lua` — no `init.lua`,
  `manifest.lua` or `README.md` needed.
- `X/themes/<name>/theme.lua` is the only file required to define a theme —
  a handful of lines instead of four boilerplate files.
- `data/core/themes.lua` discovers them by scanning each root for
  `<name>/theme.lua`, over the user themes directory, `EXEDIR/data/themes` and
  any root an extension registered with `themes.add_root()` — earlier roots
  win, so a user theme overrides a bundled one by name.
- `cdin-x/scripts/new-plugin.lua` and `generate-manifest.lua` know a theme is a
  single file and scaffold accordingly.
- `cdin-x/docs/architecture/plugin-system.md` updated to reflect simplified theme structure
