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