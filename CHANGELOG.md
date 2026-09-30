# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### ⚠️ BREAKING CHANGES

#### The editor is now a runtime; extensions come from cdin-x

cdin is the editor runtime and nothing else. Its `data/` contains only
`core/`. The mandatory set a working editor needs — the vim plugin, the
default theme and the fonts — lives in
[cdin-x](https://github.com/m-mdy-m/cdin-x) and is copied into the build
output at build time. The user-facing workflows (command palette, find file,
open file, open folder, the module pickers) are optional plugins there too.

This reverses the "fully self-contained" entry below, and the difference is
where the code lives rather than whether it ships. A build still bundles vim,
a theme and fonts, and an editor still starts and runs. What changed is the
ownership, so that a change to an extension is an extension change and not an
editor change.

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

No C changes: `src/lua/api.c` already puts `EXEDIR/data/?.lua` and
`EXEDIR/data/?/init.lua` on `package.path`, and that is still enough.

#### The editor is now fully self-contained

The split of `0.2.0-alpha.1` — which moved plugins, themes and language definitions into a separate `cdin-x` repository and made the build depend on fetching them — is reverted. This repository again builds and runs on its own.

- **A fresh clone builds with `make`.** No clone, fetch, `curl`, or network access at any point. The `_check_cdin_x` build gate is gone, along with every `cdin-x-*` make target, the fetch script, and the sibling-checkout steps in the release workflows and Dockerfile.
- **`data/plugins/`** — plugins now live in the repository and are loaded by the new `data/core/plugins.lua`. Bundled plugins are: `menu`, `session`, `tab`, `treeview`, `vim`, `window`, `autoreload`, `trimwhitespace`, plus language definitions for C, JavaScript, TypeScript, Lua, Markdown and Python.
- **`data/themes/default/theme.lua`** — the default theme ships in the repository. User themes are discovered from `~/.config/cdin/user/themes/<name>/theme.lua`, searched before the bundled ones so a user theme of the same name wins.
- **The extension manager is removed entirely**: `data/core/x/` (catalog, registry, git sync, panel, commands) is deleted, along with its `require "core.x"` call sites. The editor no longer contacts any remote host at runtime.
- **`essential` is gone.** It only ever meant "a manager must not disable this", and there is no manager. Every plugin — bundled or user-supplied — loads by the same rule: it is on disk, so it loads.
- **The editor requires no plugins.** An empty `data/plugins/` is a supported, tested state; everything in `data/core/` works without any plugin present. A plugin that raises an error is logged and skipped rather than taking startup down.
- **Cross-plugin `require` is rooted at `plugins`** (`require "plugins.tab.impl"`) and resolves through `data/?.lua`, so it no longer depends on the loader injecting paths. `src/lua/api.c` drops the four `data/core/x` and `data/X` entries from `package.path`.

#### Removed

- `autoupdate` — it fetched and self-replaced the editor over the network. Updating cdin is the user's job, as it is for every other editor.

##### Choosing what loads — `config.plugins`

cdin can now start with any subset of its plugins, including none. `config.plugins` in `~/.config/cdin/user/init.lua`:

| Value | Loads |
|-------|-------|
| `nil` (default) | every plugin in `data/plugins/` |
| `false` | nothing — the bare editor |
| `{ "vim" }` | exactly these, in this order |

This is Vim's `pack/*/start/*` vs `pack/*/opt/*` split collapsed into one list, with the same reasoning: what loads by default and what you opt into are different questions, so they are answered in different places.

- **`--no-plugins` / `-u NONE`** — command-line equivalent of `config.plugins = false`. Parsed before anything reads config, so it overrides the list. A flag is not a path and is never mistaken for a file to open.
- **User config now runs before plugins.** `config.plugins` is user-owned, so `~/.config/cdin/user/init.lua` has to be read first. A consequence: a plugin's commands and keymaps are registered *after* user config, so a plugin can overwrite a keymap set in `init.lua` but not the reverse. `require`-ing a plugin's module from `init.lua` still works — module names resolve absolutely and are order-independent — but its `init()` side effects are not there yet.
- **`core:load-plugin <name>`** — load a plugin that wasn't autoloaded; accepts a comma-separated list. With **`core:unload-plugin`** and **`core:list-plugins`**, these are the only way to change the set at runtime, and nothing persists across a restart. There is no state file to drift out of sync with the disk.

A plugin left out of the list is not gone — it stays on disk and loads on demand. Naming a plugin that isn't there is logged and skipped, so a config written against another build still gets an editor.

`vim` is fully self-contained: it requires only `plugins.vim.*` and `core.*`, and reaches the other features (tabs, splits, tree) through its own registry and `command.perform`, so it runs correctly with every other plugin absent.

#### Added

- `make test-plugins` — Lua data-layer test. Needs only `lua`: no build, no editor. Runs the checks three times, with `config.plugins` set to `nil`, `false` and `{ "vim" }`, covering the full set, the bare editor, and vim-alone. Also covers on-demand load/unload, an unknown plugin name, a deliberately broken plugin, and theme discovery/apply.

#### Fixed

- **Dead core keybindings.** Three separate causes, all invisible at runtime — the key press was consumed, nothing ran, and nothing errored:
  - `command.add_defaults()` skipped `data/core/commands/command.lua`, on the reasoning that a file sharing the module's own name must be a duplicate. It is not: that file holds the `command:*` commands the palette itself needs, so `Return`, `Tab`, `Escape`, `Up` and `Down` were bound to commands that were never registered. It is now loaded like every other command module, and the exclusion (and its wrong reasoning) is gone from the comment.
  - `empty_view.lua` and `logview.lua` register their commands at require time but were only required lazily, by whoever opened the view. Both are named by the core keymap, so `Ctrl+O` / `Ctrl+Shift+O` on the empty view and `Ctrl+C` / `Ctrl+A` in the log were bound to commands that did not exist yet. `add_defaults()` now requires both views up front.
  - `core:open-folder` was called by `empty-view:open-folder` but never defined anywhere, so `Ctrl+Shift+O` on the empty view did nothing at all. It is now implemented: a directory picker that chdirs into the chosen folder and resets the project file list.

  All 89 core keymap bindings now resolve with zero plugins loaded, and `make test-plugins` asserts it.

- **Themes now actually apply.** `data/core/themes.lua` defined `style.set_theme` against an undeclared global `style`, so requiring the module raised an error that the caller swallowed in a `pcall` — leaving `style` permanently on its built-in fallbacks. The duplicate method (already on `core.style`) is gone, and theme lookup spans both bundled and user directories.

- **Lua edits stopped reaching the editor on Windows.** `build/<platform>/data` was created with a bare `ln -s`, which MSYS silently turns into a *copy* unless winsymlinks are enabled — and the `[ ! -e ... ]` guard then made that copy permanent, so it was written once and never refreshed. Every later edit under `data/` was ignored by the built editor, which is the worst kind of bug: the code on disk is correct and the running binary disagrees. The build now prefers a verified symlink and mirrors the tree whenever it cannot make one, so `data/` is always current.

- **Core no longer depends on an extension.** The extension manager's registry sync did `require "X.core.git.exec"` — a module belonging to the git extension, in a directory `data/core/` has no business knowing about. The editor therefore died at startup with `module 'X.core.git.exec' not found` before it drew a frame, and the same line broke `cdin-x`, where it pointed at a `core/git/` that never existed. The manager now only *locates* a registry that is already on disk; fetching it is delegated to a syncer the git extension registers, mirroring the existing `core.register_vcs_provider` contract. With no extensions loaded, `refresh` reports that it is unavailable rather than failing to boot.

- **Startup no longer requires a manager that is not there.** `data/core/plugins.lua` and `data/core/init.lua` were left over from the abandoned CDIN-X split and still did `require "core.x"`, so a tree with no manager — which is the state a fresh clone is in — died with `module 'core.x' not found` before the first frame. `data/core/plugins.lua` is now a self-contained loader over `data/plugins/`: it discovers a plugin directory or a single `.lua` file, honours `config.plugins`, isolates a plugin that raises so one bad plugin cannot cost the user their editor, and answers `:packadd`-style `core:load-plugin` regardless of what autoload was configured to do. A missing or empty `data/plugins/` is a supported state, and core boots identically either way.


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
