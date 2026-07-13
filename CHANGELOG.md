# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

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