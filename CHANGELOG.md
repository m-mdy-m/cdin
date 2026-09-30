# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

---

## [0.2.0-alpha.2] — 2026-09-30

15 commits, 114 files changed, +4,464 / −6,883. **Zero C changes** — every line
is Lua, Python, Make or Markdown.

The headline is a repository boundary. cdin is now the editor **runtime**, and
the extension set a build ships is assembled from a sibling
[cdin-x](https://github.com/m-mdy-m/cdin-x) checkout at build time. Everything
else in this release — the loader rewrite, the new extension points, four test
targets that can only be written once the boundary is enforced — exists to make
that boundary hold and to keep it from drifting back.

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

`data/core/` used to contain things that are workflows, not mechanics:

| Deleted | Lines | Where it is now |
|---------|-------|-----------------|
| `data/plugins/` — 44 entries: `core/*`, `languages/*`, `optional/*`, `tab/`, `treeview/`, `vim/`, `window/` | 5,788 | built output only, assembled from cdin-x |
| `data/themes/*.lua` — `default`, `dracula`, `nord`, `solarized-dark`, `solarized-light`, `monokai`, `github-light`, `gruvbox-dark`, `tokyo-night`, `catppuccin-mocha` | 240 | `cdin-x/X/themes/<name>/theme.lua`; one is bundled: `default` |
| `data/fonts/` — `font.ttf`, `monospace.ttf`, `icons.ttf`, `fallback.ttf`, `emoji.ttf` + 2 licences | 4,480 KB | `cdin-x/fonts/`, copied to `data/fonts` next to the binary |
| `data/user/init.lua` — the 67-line default user config | 67 | not bundled; `config.user_dir/init.lua` is read if present |
| `data/core/git/` — `init`, `exec`, `status`, `commands` | 356 | a git plugin in cdin-x, registered through `core.register_vcs_provider` |
| `data/core/commands/findreplace.lua` | 207 | a `find-replace` plugin in cdin-x; it prepends `find-replace:select-next` onto `ctrl+d` at load time |
| `data/core/search.lua` | 80 | cdin-x, or the C `search` API directly |
| `data/core/session_bootstrap.lua` | 41 | `data/core/preboot.lua` (39 lines, rewritten — same job, no session-plugin dependency) |
| `core.load_plugins()` from `data/core/lifecycle.lua` | 43 | `core.plugins.load_all()` in the new `data/core/plugins.lua` |
| `config.optional_plugins` | — | gone with the loader that read it |

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

`data/core/plugins.lua` is new (208 lines):

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
- **`scripts/assemble_data.py`** is new (177 lines; stdlib only, Python 3.8+, no
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

- `scripts/_stub_env.lua` (427 lines) is the pure-Lua stand-in for the C `fs` /
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

#### Documentation

- **`docs/architecture/extension-contract.md`** is the whole of what cdin
  guarantees an extension and the whole of what cdin-x may assume: the mandatory
  set and how it is bundled, the runtime contract (site resolution, `package.path`
  order, loader roots), the line between what the runtime owns and what an
  extension owns, the plugin lifecycle, the optional workflows, and the one known
  limitation.
- `docs/architecture/overview.md` and `docs/architecture/internals.md`
  rewritten for the split; `docs/guides/plugins.md` (323 lines changed),
  `themes.md`, `configuration.md`, `commands.md`, `building.md`,
  `getting-started.md` and `troubleshooting.md` updated; `README.md`,
  `CONTRIBUTING.md` and `AGENTS.md` updated.

### Changed

- **Boot order.** `core.init()` now: parse flags → build views →
  `command.add_defaults()` → **read `config.user_dir/init.lua`** → apply
  `--no-plugins` → `core.plugins.load_all()` → re-apply the persisted theme →
  load the project module → open the files named on the command line. User
  config runs *before* the plugins because `config.plugins` is user-owned. A
  plugin-loading failure no longer force-opens the log view; it logs and
  continues.
- **The runtime keymap went from 152 bindings to 84.** Every group a plugin used
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

### Fixed

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

### Build, packaging & CI

- `make` = `bin` + `bundle`; `make bin` = binary only, no cdin-x;
  `make bundle` = assemble `data/`; `make CDINX_DIR=/path` points the bundle at
  another checkout. `make help` still says "a plain `make` is all you need —
  plugins and themes ship inside `data/`", which is no longer true; the line is
  corrected below in the known issues rather than silently left to mislead.
- The three release workflows and `docker.yml` check cdin-x out as a **sibling**
  so the default `CDINX_DIR` resolves, and package the **assembled**
  `build/…/data` — the tree sitting next to the binary they just built —
  instead of the source `data/`. A release without the bundle cannot start, so
  shipping the source tree was always wrong; it just did not matter while the
  source tree *was* the whole editor.
- `Dockerfile` copies `cdin-x/` into `/src/cdin-x` — checked out by `docker.yml`
  into the build context — so `CDINX_DIR=../cdin-x` resolves with no extra
  configuration, and copies the assembled `data/` into the image. No `CDINX_DIR`
  is baked into the image: the bundle is resolved at image build time.
- Trailing-newline fixes in the three release workflows and the Dockerfile.

### Migration

From `0.2.0-alpha.1`, or from a build of the short-lived self-contained layout:

| You had | Do this |
|---------|---------|
| `data/plugins/<name>` in this repository | the plugin is in cdin-x; a build bundles the mandatory set, and `config.plugins` selects what is installed in your site directory |
| `data/themes/<name>.lua` | `<name>/theme.lua` in a themes root; user themes go in `<config_home>/cdin/user/themes/<name>/theme.lua` and win over bundled ones by name |
| `data/fonts/*.ttf` | cdin-x; the build copies them into `data/fonts` next to the binary |
| `config.optional_plugins.<name> = false` | gone — it selected plugins from a directory that no longer exists |
| a keymap naming `find-replace:*`, `tab:*`, `window:*`, `treeview:*`, `session:*`, `project-search:*`, `autocomplete:*`, `core:find-command`, `core:find-file`, `core:open-file`, `core:open-folder`, `core:reload-module`, `core:open-*-module` | bind it only if the matching cdin-x plugin is installed — `core:load-plugin` it, or add it to `config.plugins` |
| `core.git.*` | `core.vcs_provider.status.*`, via `core.register_vcs_provider` |
| `require "plugins.<name>"` across extensions | `require "X.core.<name>"`; the runtime appends the site directory to `package.path`, it does not rewrite names |
| `config.site_dir = "<path>"` | still works; `config.site_dirname` is the new knob if you only want to rename the directory under the data home |

### Known issues and limitations

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
- **`make check` and `make size` are still broken** — both call scripts that do
  not exist (`scripts/check.py`, `scripts/bench.py`) — and `test` / `bench` are
  still listed in `.PHONY` and in `make help`, which also still claims plugins
  and themes ship inside `data/`. Carried over from `0.1.0-beta.7`; unchanged
  here.
- **C-level test tiers (unit / integration / e2e) still do not exist.** Everything
  tested in this release is the Lua data layer, under a plain `lua`.

### Stability

- **Zero C changes.** 114 files, all Lua, Python, Make or Markdown. `src/` is
  untouched: `src/lua/api.c` already puts `EXEDIR/data/?.lua` and
  `EXEDIR/data/?/init.lua` on `package.path`, and that is still enough.
- The alpha cycle continues. The loader, `config.plugins`, `config.site_dirname`
  and the extension points above are written down in
  `docs/architecture/extension-contract.md`, and a change to any of them will be
  a breaking change.


## [0.2.0-alpha.1] — 2026-09-26

### ⚠️ BREAKING CHANGES

This release introduces a **fundamental architectural restructuring** of the cdin editor. The repository boundary between `cdin` (editor runtime) and `cdin-x` (extension ecosystem) has been enforced for the first time.

---

### Architecture — Extension Ecosystem Split

**The single largest change in cdin's history.** All plugin, theme, and font assets have been extracted from the `cdin` repository into the separate `cdin-x` repository. This enforces a clean separation between the editor host and the extension ecosystem.

#### What changed

- **Removed from `cdin`**: `data/plugins/`, `data/themes/`, `data/fonts/`, `data/user/` — all deleted
- **cdin-x owns everything**: All built-in extensions, themes, language syntax definitions, and bundled fonts now live exclusively in `cdin-x/`
- **`cdin` now contains only**: `src/` (C host), `data/core/` (Lua runtime), `data/init.lua` (entry point), build system, docs
- **`cdin-x` contains**: `core/` (extension manager), `X/` (extension catalog), `fonts/` (bundled fonts), `scripts/`, `docs/`

#### Directory mapping

| Old location | New location |
|---|---|
| `cdin/data/plugins/core/` | `cdin-x/X/core/` |
| `cdin/data/plugins/languages/` | `cdin-x/X/languages/` |
| `cdin/data/plugins/optional/` | `cdin-x/X/optional/` |
| `cdin/data/plugins/vim/` | `cdin-x/X/core/vim/` |
| `cdin/data/plugins/treeview/` | `cdin-x/X/core/treeview/` |
| `cdin/data/plugins/tab/` | `cdin-x/X/core/tab/` |
| `cdin/data/plugins/window/` | `cdin-x/X/core/window/` |
| `cdin/data/themes/*.lua` | `cdin-x/X/themes/<name>/theme.lua` |
| `cdin/data/fonts/*` | `cdin-x/fonts/` |
| `cdin/data/user/init.lua` | `~/.config/cdin/user/init.lua` |

#### Extension lifecycle

- **Built-in extensions** (vim, treeview, tab, window, core, autocomplete, autoreload, autoupdate, projectsearch, session, trimwhitespace): Always present, cannot be disabled or removed
- **Optional extensions** (theme_switcher, unicode_inspect, rtl_toggle, language packs, community themes): Installed per-user via cdin-x extension manager
- **Extension installation**: `scripts/install.sh /path/to/cdin` copies runtime + built-ins from cdin-x into cdin
- **User config**: Follows platform conventions (`~/.config/cdin/user/init.lua` on Linux/macOS, `%APPDATA%/cdin/user/init.lua` on Windows)

#### Runtime bootstrapping

- `src/lua/api.c` bootstrap now adds `data/core/x/`, `data/X/`, and `data/X/core/` to `package.path`
- `data/core/init.lua` bootstraps via `require "core.x"` → `cdin_x.bootstrap()` instead of scanning `data/plugins/`
- `data/core/lifecycle.lua` `load_plugins()` now delegates entirely to the cdin-x extension manager
- If cdin-x is unavailable, the editor still starts with core runtime only (graceful degradation)

#### Theme system

- `data/core/themes.lua` now loads themes from `data/core/x/X/themes/<name>/theme.lua` via `dofile`
- Falls back to legacy `require "themes.<name>"` for backward compatibility
- `data/core/style.lua` uses `config.fonts_dir` instead of hardcoded `EXEDIR .. "/data/fonts"`

#### Font system

- Fonts moved to `cdin-x/fonts/` (font.ttf, monospace.ttf, icons.ttf, fallback.ttf, emoji.ttf + LICENSE files)
- `scripts/install.sh` copies fonts to `cdin/data/fonts/` during installation
- `data/core/style.lua` references `config.fonts_dir` which points to the installed font directory

#### Build & Install

- `cdin-x/scripts/install.sh` now creates `data/fonts/` and copies fonts in addition to runtime + extensions
- `cdin-x/scripts/validate.lua` validates that font files exist in `fonts/`
- Development symlinks created: `data/X` → `cdin-x/X`, `data/core/x` → `cdin-x/core`, `data/fonts` → `cdin-x/fonts`

### 🎨 Theme System Simplified

- Themes are now **single-file**: each theme is just `theme.lua` — no `init.lua`, `manifest.lua`, or `README.md` needed
- `cdin-x/X/themes/<name>/theme.lua` is the only file required to define a theme
- `data/core/themes.lua` auto-discovers themes by scanning `data/core/x/X/themes/` for `theme.lua` files
- `cdin-x/scripts/new-plugin.lua` creates simplified `theme.lua` for themes vs full plugin scaffolding
- `cdin-x/scripts/generate-manifest.lua` auto-generates catalog entries from `theme.lua` `name` fields
- Theme creation is now ~30 lines instead of requiring 4 boilerplate files
- `cdin-x/docs/architecture/plugin-system.md` updated to reflect simplified theme structure

---

### 🔧 Fixed

- `data/core/project.lua`: Updated `require "plugins.treeview.cache"` → `require "X.core.treeview.cache"`
- `data/core/rootview/empty_view.lua`: Updated `require "plugins.core.session"` → `require "X.core.session"`
- `data/core/views/statusview.lua`: Updated `require "plugins.tab.manager"` → `require "X.core.tab.manager"`
- `data/core/commands/core.lua`: `core:open-user-module` now opens `~/.config/cdin/user/init.lua` instead of `data/user/init.lua`
- `src/lua/api.c`: Bootstrap now includes `data/core/x/`, `data/X/`, and `data/X/core/` in package.path for `require "core.x"` to work

### 📝 Updated Documentation

- `AGENTS.md`: Updated repo layout to reflect cdin/cdin-x separation, added Extension Architecture section
- `CONTRIBUTING.md`: Updated directory listing, plugin development instructions now reference `cdin-x/X/<category>/`
- `CHANGELOG.md`: This entry
- `docs/guides/getting-started.md`: Updated directory structure, user config path
- `docs/guides/plugins.md`: Rewritten for cdin-x extension ecosystem
- `docs/guides/themes.md`: Updated theme locations and creation instructions
- `docs/guides/configuration.md`: Updated config file path
- `docs/guides/commands.md`: Updated `core:open-user-module` description
- `docs/guides/troubleshooting.md`: Updated plugin disable instructions
- `docs/architecture/overview.md`: Updated plugin loading description
- `docs/architecture/internals.md`: Updated boot sequence and plugin loading sections
- `docs/architecture/plugin-system.md`: Updated theme asset location
- `website/src/consts/faqs.ts`: Updated all data/ references to cdin-x ecosystem
- `website/src/pages/AboutUs.tsx`: Updated plugin and config path references
- `website/src/components/Landing/Philosophy.tsx`: Updated plugin path reference

---

## [0.1.0-beta.1] — 2025-12-27

This is the first public release. It's a beta: the core editor is functional and usable day-to-day, but some things are still rough. APIs may change, a few documented features are stubs, and there are almost certainly bugs. Bug reports and patches are welcome.

### Core editor

- Windowed editor built on SDL3, with a custom title bar drawn entirely in Lua. No OS window decorations — cdin draws its own minimize/maximize/close buttons and handles the drag region via SDL's hit-test API.
- Custom renderer backed by stb_truetype. Three bundled fonts: a proportional UI font, a monospace editor font, and an icon font.
- Event loop running at a configurable FPS (default 60), with coroutine-based background threads for project scanning and similar tasks.
- Document model with unlimited undo/redo (configurable cap, default 10,000 steps) and undo merging for consecutive edits within a short time window.
- Project file scanner runs in a background thread and rescans every 5 seconds. Respects `config.ignore_files` (default: dot files).
- Files dropped onto the window open as new documents. Directories dropped open a new editor instance.
- Unsaved-changes dialog on quit.
- On crash, dirty documents are saved to `<filename>~` and a stack trace is written to `error.txt`.

### Vim mode

- Modal editing with three modes: Normal, Insert, Visual.
- Every buffer opens in Normal mode by default.
- Current mode shown in the status bar as `[NORMAL]`, `[INSERT]`, or `[VISUAL]`.
- Motions in Normal and Visual mode: `h j k l`, `w b e`, `0`, `$` (via `shift+4`), `^` (via `shift+6`), `gg`, `G`.
- Operators: `d`, `dd`, `D`, `yy`, `cc`, `x`, `p`, `u` (undo), `r` (redo).
- Mode transitions: `i`, `a`, `o`, `I`, `A`, `O`, `v`, `Escape`.
- Tab in Normal mode cycles to the next open tab.
- Ex command line opened with `:` (or `shift+;`).
- Ex command history navigable with Up/Down while the command line is open.
- Pending-key timeout of 600 ms for two-key sequences like `gg` and `dd`.

### Ex commands

`:w`, `:w!`, `:wa` — save current file / save all  
`:q`, `:q!`, `:qa`, `:qa!` — close / force-close / quit  
`:wq`, `:x`, `:wqa`, `:xa` — save-then-close variants  
`:e <path>`, `:edit <path>` — open file  
`:new <path>` — create and open a new file  
`:mkdir <path>` — create directory tree  
`:rm <path>`, `:delete <path>` — remove file or directory  
`:rename <old> <new>`, `:copy <src> <dst>`, `:move <src> <dst>` — file operations  
`:ls [path]` — list directory in a scratch buffer  
`:pwd` — print working directory  
`:cd <path>` — change working directory  
`:<number>` — go to line  
`:!<cmd>` — run shell command; output appears in a new scratch buffer  
`:tree` — focus/toggle the project tree  
`:help` — show ex command reference in a scratch buffer  

File-path arguments to `:e`, `:new`, `:mkdir`, `:rm`, `:rename`, `:copy`, `:move`, `:cd` support tab-completion.

### File manager menu (`m`)

Pressing `m` in Normal mode (or via `vim-fmenu:open`) opens a context-sensitive action menu. The available actions depend on where focus is:

- When the tree view is focused on a file: rename, delete, copy, move, open in editor, run shell command on it.
- When the tree view is focused on a directory: new file, new directory, rename, delete, run shell command.
- When a document is active: actions apply to that document's file.

### Standard keybindings (non-vim)

The full default keymap is documented in [Command Reference](docs/reference/commands.md). Highlights:

`Ctrl+Shift+P` — command palette  
`Ctrl+P` — fuzzy open file from project  
`Ctrl+O` — open file by path  
`Ctrl+N` — new document  
`Ctrl+S` / `Ctrl+Shift+S` — save / save as  
`Ctrl+F` / `Ctrl+R` — find / replace  
`Ctrl+G` — go to line  
`Ctrl+Z` / `Ctrl+Y` — undo / redo  
`Alt+1`–`9` — switch to tab by index  

### Plugins (bundled)

- **treeview** — project tree panel. Shows git status markers (A/M/D/?) when `config.treeview_git_enabled` is true. Polls every 2 seconds by default. Toggle hidden files with `Ctrl+Shift+H` or via `config.show_hidden_files`.
- **autocomplete** — word completion from all open documents. Shows up to 6 suggestions by default (`config.autocomplete_max_suggestions`).
- **projectsearch** — search across all project files; results open in a dedicated view.
- **autoreload** — detects when a file is changed on disk by another process and offers to reload it.
- **trimwhitespace** — strips trailing whitespace from every line on save. Runs automatically; no configuration needed.

### Build system

- `make` / `make build` — release build
- `make debug` — debug build (`-O0 -g3`)
- `make run` — build and run
- `make install` — install to `PREFIX` (default `/usr/local`)
- `make clean` / `make distclean`
- `make info` — print build configuration summary
- Version is derived from the nearest git tag; falls back to `0.0.0+<commit>`.
- Supports SDL3 (required) and Lua 5.3 or 5.4 (auto-detected via pkg-config).
- Linux, macOS, and Windows (MinGW) are all supported platforms.

### Known issues and limitations

- The `docs/guides/` directory in the repository contains stubs for several planned guides (configuration, plugin development, vim keybindings, API reference). This release ships those documents.
- No plugin package manager. Plugins are installed by dropping Lua files into `data/plugins/`.
- The Windows build requires manual SDL3 setup (see [Building from Source](docs/guides/building.md)).
- No LSP integration yet.
- No multiple cursors.
- Visual mode only supports character-wise selection. Line-wise and block-wise visual modes are not implemented.

## [0.1.0-beta.2] — 2026-07-05

This release focuses on a major internal refactor of the data layer and plugin architecture. While user-facing behavior remains largely unchanged, the internal structure has been significantly reorganized to improve modularity, maintainability, and future extensibility.

No intentional breaking changes to core editor behavior were introduced, but due to the scope of the refactor, some instability or plugin-related regressions may occur.

### Internal architecture

* Major refactor of the internal `data/` structure into a cleaner, modular layout.
* Improved separation of concerns across core systems without altering runtime behavior.
* Reorganized initialization and data flow to better support future plugin and feature expansion.
* Reduced coupling between subsystems for easier debugging and testing.
* Enhanced plugin system foundation with clearer lifecycle handling and session isolation.

### Plugins

* Introduced a **session plugin system** to manage runtime session state in a structured and extensible way.
### Tooling & Scripts

* Added an automated **update script** to streamline project updates and maintenance workflows.

### Stability notes

* Core editor behavior remains unchanged from `0.1.0-beta.1`.

### Versioning note

* This release remains within the beta cycle.
* APIs are still considered unstable and may change before the first stable release.

## [0.1.0-beta.3] — 2026-07-05

This release focuses on improving the startup experience and fixing several issues introduced during the previous internal refactor.

### Features

- Added a subtle background logo to the welcome/empty view for a cleaner visual appearance.

### Bug Fixes

- Fixed the Recent Files list not being displayed correctly in some situations.
- Fixed an issue where certain terminal windows appeared unexpectedly when launching cdin.
- Fixed a runtime error related to `_recent_rects` in the empty view.

### Stability

- Improved startup reliability following the internal architecture changes introduced in `0.1.0-beta.2`.

## [0.1.0-beta.4] — 2026-07-05

### Features

- **macOS Build:** Added official macOS build support — cdin is now distributed for macOS alongside Linux and Windows. ([`9a76e3e`](../../commit/9a76e3e))
- **Menu Navigation:** Navigate between options in the shell menu, fmenu (NerdTree-like file manager), and doc menu using `↑`/`↓` arrow keys, and confirm selection with `Tab`. ([`51c95a4`](../../commit/51c95a4))
- **Logo:** Auto-generate logo backgrounds via the new `gen_logo_lua` scripts. ([`846297b`](../../commit/846297b))

### Bug Fixes

- **macOS:** Fixed incorrect bash version used in macOS builds. ([`5c83e07`](../../commit/5c83e07))
- **File Open:** Fixed `Ctrl+O` shortcut not opening the file picker correctly. ([`900a092`](../../commit/900a092))

### Refactoring

- **Session:** Added a new option to automatically reopen the last active file on startup — disabled (`false`) by default. ([`29b11ae`](../../commit/29b11ae))

## [0.1.0-beta.5] — 2026-07-10

### Overview

This release is a major architectural milestone for cdin.

The focus of this release is not a large set of user-facing features, but a complete improvement of the internal foundation: the Lua layer has been simplified, core functionality has moved behind cleaner C-powered APIs, the event bus system has been removed, and several internal systems have been redesigned for better modularity and future extensibility.

Filesystem operations, searching, Git integration, state handling, and lifecycle management are now organized around dedicated APIs and modules, creating a cleaner foundation for future plugins and editor features.

Due to the scope of these changes, some internal Lua APIs and plugin behaviors may require updates.

---

# Breaking Changes

### Event system removal

- Removed the old `eventbus` system from both C and Lua.
- Plugins using `eventbus.emit(...)` or depending on event bus initialization must migrate to the new architecture.

### Lua structure changes

- Reorganized the `data/` Lua structure.
- Removed redundant modules and moved functionality into cleaner core APIs.
- Internal module paths may have changed.

### Keymap changes

- Centralized default keymap registration into `core/keymaps/default.lua`.
- Plugins or user configurations that relied on previous startup ordering may require adjustments.

### Document hooks

- Replaced document method monkey-patching with a structured hook table system.
- Plugins extending document behavior should migrate to the new hook mechanism.

---

# New Features

## Core Architecture

### State and project management

- Added `core.state` for centralized runtime state management.
- Added `core.project` for project lifecycle and project-related operations.
- Created a cleaner foundation for future session and workspace features.

### Lifecycle system

- Added Lua initialization and lifecycle management.
- Plugins can now follow structured initialization phases instead of relying on implicit loading behavior.

### Logging system

- Added a unified logger available from both C and Lua.
- Improved debugging and internal diagnostics.

### Core helpers

- Added `core.active_docview()` helper.
- Reduced the need for plugins and internal components to manually traverse views.
- Added shared utilities such as configuration helpers and copy utilities.

---

# Public APIs

## Filesystem API

- Added a public `fs` API exposed to Lua.
- Provides unified filesystem operations and path handling.
- Reduces duplicated filesystem logic across plugins and core modules.

## Search API

- Added a public `search` API exposed to Lua.
- Search functionality is now powered by the native C search engine.
- Plugins can use the same search implementation as the editor core.

## Git API

- Added centralized `core.git` APIs.
- Git operations are now shared between core components and plugins.
- Removed duplicated Git command handling from individual modules.

---

# Search Improvements

- Reworked search around the native `search.c` engine.
- Improved consistency between project search and internal search functionality.
- Removed older duplicated Lua-based search logic.
- Added a cleaner API layer for future search extensions.

---

# Git Integration

- Centralized Git status, branch, and repository operations.
- Improved Git usage across treeview, statusbar, and plugins.
- Git information is now provided through `core.git.status`.

### Git UI improvements

- Treeview Git badges now use centralized Git APIs.
- Status bar Git information now reads from the Git API instead of executing commands directly.

---

# UI & Editor Improvements

## Status bar

- Redesigned status bar layout.
- Added Vim mode indicator/pill.
- Git branch and status information are now integrated through the new Git API.

## Project search

- Improved search result presentation.
- Added match context display.
- Added highlighted matches.
- Added progress indication during searches.

## Tabs and windows

- Added tab/window command support.
- Improved tab and window management architecture.
- Removed unnecessary tab abstractions by integrating logic directly into the tab system.

## Theme

- Added a new built-in theme.

## Log view

- Added copy and paste support for log entries.

---

# Vim Improvements

- Unified write/quit mappings through the `ex` command system.
- Improved usage of `core.active_docview()`.
- Reduced duplicated view lookup logic.

---

# Configuration & Initialization

- Added dedicated configuration and event modules.
- Improved initialization order and module separation.
- Boot sequence has been simplified.

---

# Bug Fixes

### Git

- Fixed Linux Git ignored-file detection error:

```bash
git ls-files -i must be used with either -o or -c
```

- Fixed Git subprocess handling issues on Windows.

### Editor behavior

- Fixed insert mode `m` key incorrectly opening menus.
- Fixed incorrect directory label rendering in empty views.

### Build & Platform

- Fixed several platform-specific build issues.
- Improved consistency of Git and shell behavior across supported platforms.

---

# Refactoring & Internal Changes

- Removed event bus dependencies from the codebase.
- Replaced document monkey-patching with hook tables.
- Removed obsolete Lua files and duplicated logic.
- Simplified core module boundaries.
- Fixed C core submodule paths.
- Updated Makefile and build structure.
- Marked required build scripts as executable through Git attributes.
- Improved internal synchronization between C and Lua layers.

---

# Platform Notes

| Platform | Status |
|----------|--------|
| Linux | Supported. Native APIs and Git integration improved. |
| Windows | Supported. Git subprocess handling improved. |
| macOS | Supported. Existing release pipeline improvements continue. |

---

# Stability Notes

This release focuses on architecture rather than major visual changes.

The main goal is creating a cleaner and more maintainable foundation for future cdin development, including:

- More powerful plugins
- Better project management
- Advanced editor automation
- Improved language tooling support

The beta cycle continues, and APIs may still change before the first stable release.

## [0.1.0-beta.6] — 2026-07-13

### Features

- **Auto-update notifications:** cdin now includes a lightweight manual update checker that queries GitHub releases and notifies users when a newer version is available. The check runs asynchronously to avoid blocking the editor and displays an update badge in the status bar when a new release is found. ([`data/plugins/core/autoupdate.lua`](data/plugins/core/autoupdate.lua))

- **In-editor update check command:** Added `autoupdate:check` to manually check for the latest cdin release from GitHub without leaving the editor. The command can be triggered from the command palette or bound to a key.

- **Update notification dismissal:** Added `autoupdate:skip-version` to hide the current update badge for the active session.

- **Desktop shortcut & default text editor registration:** The installer now creates a desktop shortcut and registers cdin as a default text editor handler on supported platforms. ([`710cb08`](../../commit/710cb08))

- **Windows file icons:** Files associated with cdin (`.txt`, `.py`, `.lua`, and all registered extensions) now show the cdin icon in Explorer across all view modes — Details, Large Icons, Tiles. Previously the icon appeared only on the desktop/taskbar shortcut; files themselves kept the Windows default icon.

- **Gen-logo / gen-icon integrated into cdin script:** `python3 scripts/cdin.py gen-logo` and `gen-icon` are now first-class subcommands — no need to call the generator scripts directly. ([`38af4ab`](../../commit/38af4ab))

- **Git: show ignored files in tree:** The treeview now surfaces git-ignored files when `config.treeview_git_enabled` is true. ([`b3ce889`](../../commit/b3ce889))

- **Screenshots & README:** Added new screenshots to the repository and updated README copy. ([`497202b`](../../commit/497202b))

### Bug Fixes

- **Keymaps:** Fixed `R` and `E` keys misbehaving in Normal and Insert mode. ([`ddfd78d`](../../commit/ddfd78d))

- **macOS:** Fixed `realpath` not available in stdlib on macOS — now uses a compatible alternative. ([`3760e43`](../../commit/3760e43))

- **macOS build:** Fixed incorrect build in macOS/Linux/Windows CI pipeline. ([`e1bf07d`](../../commit/e1bf07d))

- **Icon:** Fixed `icon.inl` filename mismatch causing build failures. ([`f5ad624`](../../commit/f5ad624))

- **CI:** Fixed SDL3 cache SDL3 dependency caching issues across Linux and macOS. ([`9002817`](../../commit/9002817), [`b99509f`](../../commit/b99509f))

- **CI:** Fixed `rsvg-convert` installation step in the icon generation workflow. ([`0202de4`](../../commit/0202de4))

- **Windows installer:** `--shortcut` now automatically implies `--register-filetypes` — previously the two flags had to be passed together or file-type associations were skipped entirely.

- **Windows installer — locked DLL on reinstall:** Reinstalling over an existing installation raised `PermissionError: [WinError 32]` when trying to overwrite `SDL3.dll` or `lua*.dll`. The installer now terminates any running `cdin.exe` before touching the install directory, skips DLL copies whose size and modification time already match the source (the common case after a clean reinstall), and retries with back-off for transient locks from Windows Defender or the shell. ([`scripts/_cdin/install.py`](scripts/_cdin/install.py))

- **Windows build — stale `data/` after source edits:** Changes to Lua files under `data/` (e.g. `data/core/init.lua`) were not reflected when running a freshly built binary. `make build` creates the `build/windows-release/data` entry only once (`[ ! -e ... ]` guard); on Windows, `ln -s` frequently produced an empty directory or a non-transparent junction instead of a working symlink, so all subsequent builds silently used the original copy. The build script now syncs `data/` into the build output directory after every successful `make build` when the existing entry is not a working junction. ([`scripts/_cdin/build.py`](scripts/_cdin/build.py))

### Refactoring & Tooling

- **Build & install scripts:** Removed the old shell-based scripts and replaced them with a unified Python codebase (`scripts/cdin.py`) in sync with GitHub Actions workflows. ([`c6dbd2c`](../../commit/c6dbd2c))

- **CI:** Platform release workflows are now reusable via `workflow_call`, eliminating duplication across Linux, macOS, and Windows jobs. ([`3106531`](../../commit/3106531))

- **CI:** Added SDL3 dependency caching to reduce build times. ([`cb30186`](../../commit/cb30186))

- **Old update script removed:** The previous standalone update script has been removed; update checking is now handled by the `autoupdate` plugin. ([`a0fe22f`](../../commit/a0fe22f))

### UI & Theme

- **Theme contrast:** Increased contrast across the default theme for better readability. ([`7a6f42c`](../../commit/7a6f42c))

- **Theme & syntax highlight:** Updated color palette and syntax highlighting rules. ([`82bd197`](../../commit/82bd197))

- **Status bar:** Changed the modified-file indicator symbol for clarity. ([`85ac6ee`](../../commit/85ac6ee))

### Documentation

- Updated contributing guide. ([`7edd665`](../../commit/7edd665))
- Added new documentation pages. ([`cf5fee4`](../../commit/cf5fee4), [`bbdea32`](../../commit/bbdea32), [`2a44eab`](../../commit/2a44eab))

### Configuration

The auto-update checker is a lightweight manual GitHub release checker.

| Command | Default bind | Description |
|---|---|---|
| `autoupdate:check` | `Ctrl+Shift+U` | Check GitHub for a newer release |
| `autoupdate:skip-version` | — | Dismiss the current update badge |

### Stability

- The update check runs asynchronously and never blocks the editor UI. If GitHub is unreachable the editor continues normally.
- No new C code. The autoupdate plugin is implemented entirely in Lua and uses standard system process execution for GitHub API requests.
- Beta cycle continues; APIs may still change before the first stable release.

## [0.1.0-beta.7] — 2026-09-23

Largest release so far: 102 commits, 218 files changed, +21,760 / −149. Headline features are full UTF-8/RTL/Arabic shaping support, a theme system with 10 built-in themes, an optional-plugin system, a Lua test suite, Docker images, and a complete documentation website. The beta cycle continues; APIs may still change before the first stable release.

### Features

- **UTF-8, bidi & Arabic shaping pipeline:** New text modules `data/core/text/utf8.lua` (decode/encode/length/sanitize, invalid bytes become U+FFFD), `data/core/text/bidi.lua` (base-direction detection, directional runs, visual reordering) and `data/core/text/shaper.lua` (contextual Arabic presentation forms, lam-alef ligatures, correct joining for Persian پ چ ژ گ ک ی). Persian/Arabic text such as «سلام» now renders shaped and right-to-left. ([`dd5ac5d`](../../commit/dd5ac5d))

- **RTL rendering in the editor:** `DocView:draw_line_text` detects RTL lines, shapes the whole line and reorders it visually; pure-LTR lines keep the fast token-by-token path. (`data/core/views/docview.lua`)

- **Font fallback chain:** Bundled `data/fonts/fallback.ttf` (Vazirmatn, OFL — `LICENSE-fallback.txt`) and `data/fonts/emoji.ttf` (`LICENSE-emoji.txt`). `style.lua` auto-attaches them to the UI, big and code fonts via `font:add_fallback`, so Arabic/Persian glyphs and emoji resolve through the fallback chain — the primary fonts themselves contain no Arabic. ([`00bc28e`](../../commit/00bc28e), [`fc42267`](../../commit/fc42267))

- **Theme system:** New registry `data/core/themes.lua` plus 10 built-in themes under `data/themes/`: `default`, `catppuccin-mocha`, `dracula`, `github-light`, `gruvbox-dark`, `monokai`, `nord`, `solarized-dark`, `solarized-light`, `tokyo-night`. Selected with `config.theme`. ([`fc42267`](../../commit/fc42267), [`523a427`](../../commit/523a427))

- **Optional plugins:** New directory `data/plugins/optional/` with 3 plugins, each individually switchable through `config.optional_plugins` and skipped by the loader when disabled, with deterministic (sorted) plugin load order:
  - `rtl_toggle` — `rtl:toggle-direction` (`Ctrl+Alt+R`, cycles auto → ltr → rtl) and `rtl:toggle-shaping` (`Ctrl+Alt+S`).
  - `theme_switcher` — `core:change-theme` (`Ctrl+Alt+T`), a fuzzy picker over all registered themes.
  - `unicode_inspect` — `unicode:inspect` (`Ctrl+Alt+U`), shows the codepoints of the selection or caret. ([`dd6a781`](../../commit/dd6a781), [`4c62daa`](../../commit/4c62daa))

- **New config keys:** `direction` (`"auto" | "ltr" | "rtl"`), `shaping_enabled`, `theme`, `theme_auto_reload`, `optional_plugins`. (`data/core/config.lua`, [`ff3de84`](../../commit/ff3de84))

- **Lua test suite:** New `tests/lua/` suite — runner `run.lua`, shared `harness.lua`, 4 unit tests (`text_utf8`, `text_bidi`, `text_shaper`, `themes`) and 3 integration tests (`text_pipeline`, `doc_edit`, `config_style_theme`). Green run: `LUA TESTS OK (1587 asserts, 7 files)`; failures print a traceback and exit with code 1. Run from the repo root with `lua tests/lua/run.lua`. ([`c4ea56c`](../../commit/c4ea56c), [`d899198`](../../commit/d899198), [`a395dad`](../../commit/a395dad), [`b9ad541`](../../commit/b9ad541))

- **Docker:** New root `Dockerfile` (multi-stage, `ubuntu:22.04`, SDL 3.2.14 built from source, non-root user `cdin` uid 1000), `docker-compose.yml` (X11 socket + `ipc: host` for MIT-SHM, optional GPU passthrough) and `.dockerignore`. ([`99fa1c3`](../../commit/99fa1c3), [`c4baefc`](../../commit/c4baefc))

- **CI: Docker publishing:** New `.github/workflows/docker.yml` builds the image on every push/PR to `main`/`develop` without pushing (GHA cache, amd64); `release.yml` gained a `publish-docker` job that pushes `bitsgenix/cdin` to Docker Hub on tagged releases using `DOCKER_USERNAME`/`DOCKER_TOKEN`. ([`3a2641a`](../../commit/3a2641a))

- **Dependabot:** New `.github/dependabot.yml` — weekly (Monday 09:00 `Asia/Tehran`) updates for `github-actions`, `docker` and the website's `npm` dependencies, with `chore(ci)`/`chore(docker)`/`chore(website)` commit prefixes. Several bumps already merged (ubuntu base, login-action, buildx, upload/download-artifact, configure-pages, eslint, @types/node, typescript-eslint, globals). ([`99fa1c3`](../../commit/99fa1c3))

- **Website:** New `website/` — a full Vite + React + TypeScript + TailwindCSS + shadcn/ui site with react-router: responsive sticky navbar, hero, features, FAQs, philosophy, contributors (GitHub API), footer, light/dark theme toggle, Fira Code typography and the cdin color theme. Docs pages render the repository markdown with a grouped search dialog (`/` / `Cmd+K`), a shortcuts panel with heading navigation, breadcrumbs, a mobile header with sidebar, and a docs footer. Plus a download page with per-platform install instructions, an About us page, a designed 404 page (`404.html` for GitHub Pages), favicon, SEO fixes and a11y/lint fixes. Deployed through the new `.github/workflows/deploy-website.yml` (GitHub Pages). ([`e67df22`](../../commit/e67df22), [`f926891`](../../commit/f926891), [`a7327dd`](../../commit/a7327dd), [`0bb6828`](../../commit/0bb6828))

- **Build: new make targets:** `check`, `size` and `tiny` (`make tiny` = `BUILD=tiny`: `-Os -DNDEBUG -ffunction-sections -fdata-sections -flto` + `-Wl,--gc-sections` for a size-optimized binary). ([`58e9fcd`](../../commit/58e9fcd))

- **Repo tooling:** Conventional-commit validation via `.husky/commit-msg` (accepts `feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert` with optional scope/`!`, skips merge/revert/fixup/squash lines). `CODEOWNERS` (`* @m-mdy-m`), `AGENTS.md` with AI-agent rules and skills, and `.gix/config` describing the gix branch flow (bugfix/feature topics off `develop`, merge up/downstream, `delete_on_finish`). ([`5461b3e`](../../commit/5461b3e), [`21be047`](../../commit/21be047), [`926fa9a`](../../commit/926fa9a))

### Bug Fixes

- **UTF-8 renderer hardening:** The C decoder no longer over-reads buffers, rejects overlong/surrogate/`> U+10FFFF` sequences (returns U+FFFD), caps width/draw loops and is NULL-safe for fonts and text. ([`8d654e7`](../../commit/8d654e7))

- **Invalid UTF-8 from disk must not poison the buffer:** Files with broken byte sequences are sanitized on load instead of corrupting document lines. ([`aaf4a67`](../../commit/aaf4a67))

- **UTF-8 display:** Fixed text rendering for multibyte characters, added a visual column (`colxy`) offset so the caret and status bar show the correct column for UTF-8 text, and fixed invalid-UTF-8 display bugs. ([`17541a6`](../../commit/17541a6), [`17389c1`](../../commit/17389c1))

- **Scroll performance:** Editor lag and slowdown while scrolling is resolved (dirty-rect handling in the renderer cache). ([`9ebf8b2`](../../commit/9ebf8b2))

- **Treeview git status:** When cdin was installed (rather than run from the checkout), Git status no longer appeared in the treeview — git now runs against the project directory instead of the process cwd. ([`c586d50`](../../commit/c586d50))

- **Lua 5.1 compatibility:** `unpack` is a global in Lua 5.1, not `table.unpack`. ([`8785d57`](../../commit/8785d57))

- **Lint/build:** Removed unused or misplaced code flagged by linting. ([`4b97a5b`](../../commit/4b97a5b))

### Refactoring & Tooling

- **Makefile cleanup:** The `test` and `bench` targets were removed; `check` and `size` replaced them. (Note: `.PHONY`/`help` still list `test`/`bench` — see Known issues.) ([`43b3484`](../../commit/43b3484), [`d9c4774`](../../commit/d9c4774))

- **Base image bumps:** Docker base moved `ubuntu 22.04 → 26.04` via Dependabot and then back to `22.04` for SDL/package availability; `libasound` package updated. ([`646fcc9`](../../commit/646fcc9), [`63ec90b`](../../commit/63ec90b), [`4c22c62`](../../commit/4c22c62))

- **Dependency updates:** CI actions (`docker/login-action` 3→4, `docker/setup-buildx-action` 3→4, `actions/download-artifact` 4→8, `actions/upload-pages-artifact` 4→5, `actions/configure-pages` 5→6) and website deps (`eslint` 10.11, `@types/node` 26.6.2, `typescript-eslint` 8.70, `globals` 17.12).

- **Test cleanup:** Removed the old shell-based test/bench leftovers from the build scripts. ([`43b3484`](../../commit/43b3484))

### Documentation

- **Themes guide:** New docs section explaining how to add a theme (`docs/guides/themes.md`). ([`1ba6348`](../../commit/1ba6348))

- **README:** Rewritten. ([`427e9b7`](../../commit/427e9b7))

- **Repo docs:** `docs/.gitkeep` removed now that `docs/` has content. ([`ed24e02`](../../commit/ed24e02))

- **Website docs:** The whole `website/` documentation set (markdown-driven docs pages, search, shortcuts, download instructions).

### Configuration

New configuration keys (`data/core/config.lua`):

| Key | Default | Description |
|---|---|---|
| `direction` | `"auto"` | Base text direction: `auto` (per-line detection), `ltr`, or `rtl` |
| `shaping_enabled` | `true` | Contextual Arabic/Persian presentation-form shaping |
| `theme` | `"default"` | Startup theme name from `data/themes/` |
| `theme_auto_reload` | `true` | Reload theme files on change (defined; not yet consumed by a watcher) |
| `optional_plugins` | all `true` | Per-plugin enable flags for `data/plugins/optional/` |

New keybindings (only active when the corresponding optional plugin is enabled):

| Command | Default bind | Description |
|---|---|---|
| `rtl:toggle-direction` | `Ctrl+Alt+R` | Cycle text direction auto → ltr → rtl |
| `rtl:toggle-shaping` | `Ctrl+Alt+S` | Toggle Arabic/Persian shaping |
| `core:change-theme` | `Ctrl+Alt+T` | Fuzzy-pick a theme |
| `unicode:inspect` | `Ctrl+Alt+U` | Show codepoints under the caret/selection |

### Known issues and limitations

- **`make check` / `make size` are broken:** both call scripts that do not exist in the repository yet (`scripts/check.py`, `scripts/bench.py`). `make test` and `make bench` targets were removed but are still listed in `.PHONY` and `make help`.
- **Shaping is Lua-level, not HarfBuzz:** presentation forms are applied in `shaper.lua` (`config.shaping_enabled = false` disables it); no GSUB/GPOS, so Arabic kerning/mark positioning is not covered. Arabic coverage comes from `fallback.ttf` (Vazirmatn), which covers all checked base letters, Forms-A/B presentation forms and lam-alef ligatures; `font.ttf`/`monospace.ttf`/`icons.ttf`/`emoji.ttf` contain no Arabic.
- **C-level test tiers (unit/integration/e2e) do not exist yet** — only the Lua suite (`tests/lua/`).
- **`config.theme_auto_reload` is declared but no file watcher consumes it yet.**

### Stability

- The RTL path degrades safely: if `core.text` fails to load, lines render as plain LTR tokens; if `direction = "ltr"` or a line has no RTL characters, the original per-token drawing path is used unchanged.
- The whole test suite (1587 asserts) is green on the release commit.
- Beta cycle continues; APIs may still change before the first stable release.

## [0.1.0] — 2026-09-25

First stable release. The beta cycle (`0.1.0-beta.1` through `0.1.0-beta.7`) is over — no functional changes since `0.1.0-beta.7` beyond what's listed below, but the API and on-disk config are now considered stable within the `0.1.x` line.

### Packaging

- **Linux `.deb`:** Native Debian/Ubuntu package, built with `fpm` from the same `make install` layout. SDL3 is bundled alongside the binary (rewritten `RPATH` via `patchelf`), so no separate SDL3 install is needed. Installs a `.desktop` entry and hicolor icons. `sudo apt install ./cdin_0.1.0_amd64.deb`.
- **Windows installer:** Native Inno Setup installer (`cdin-0.1.0-setup.exe`) built alongside the existing portable zip. Standard wizard, optional desktop shortcut, optional PATH registration, Start Menu entry, clean uninstall via *Settings › Apps*.
- Both are built and attached automatically in CI on every tagged release, next to the existing tarball (Linux), zip (Windows), and DMG (macOS).

### Features

* Load the previous session before starting cdin.
* Restore the last session state across application restarts.
* Persist the selected theme across restarts.

### Bug Fixes

* Fix `qa` and `qa!` behavior for closing tabs and quitting cdin.
* Fix session and theme persistence issues.

### Improvements

* Add logging for debugging and troubleshooting.

## [0.1.1] — 2026-09-25

Patch release focused on fixing an issue with mode transitions.

### Bug Fixes

* Fix an issue where pressing `Esc` after entering insert mode would leave the bottom status bar visible instead of properly returning to normal mode.

## [0.1.2] — 2026-09-25

### Bug Fixes

- **Treeview auto-refresh:** Automatically rescan the project after saving a newly-created file so new files appear in the project tree without a manual refresh.
- **File manager menu on Home:** Fixed `m` in Normal mode so the file manager menu can be opened when no document is currently active, including from the Home/empty view.
- **Vim Visual mode indicator:** Hardened the `[VISUAL]` status indicator to read the Vim mode from the same active document view used by Vim mode itself, keeping the displayed mode synchronized with the actual Vim state.

## [0.1.3] — 2026-09-25

### Bug Fixes

* **File manager menu — stale TreeView paths after `:cd`:** Fixed an issue where the file manager menu could continue using a stale TreeView item from the previous working directory after changing directories with `:cd`. Creating a new file or directory from `m` could therefore place it in the old directory instead of the current working directory.

* **Context path validation:** TreeView and active document paths are now validated against the current working directory before being used as the context for file manager operations. If a stale or unrelated path is detected, the current working directory is used as the authoritative fallback.

* **Windows path handling:** Path containment checks now normalize case on Windows, preventing incorrectly rejected or accepted paths when directory names differ only by letter casing.
