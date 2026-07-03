# Changelog

All notable changes to cdin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and the project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0-beta.1] - 2026-07-03

First public beta. cdin started as a fork of [lite](https://github.com/rxi/lite)
and has since diverged: the C core was restructured and ported to SDL3, and a
modal (vim-style) editing layer was built on top. This release is usable for
day-to-day editing but the vim layer is still a subset — see "Known
limitations" below.

### Core editor

- Documents with unlimited undo/redo (merged within a 0.3s window),
  multiple cursors/selections, soft or hard tabs, line-limit guide
- Tabs and recursive vertical/horizontal splits with keyboard navigation
- Command palette (`Ctrl+Shift+P`) exposing every command with its binding
- Fuzzy file finder over the project (`Ctrl+P`)
- Incremental find/replace per file, plus project-wide search with a
  results view (plain text, Lua patterns, and fuzzy)
- Syntax highlighting for C, JavaScript, TypeScript, Lua, Markdown and
  Python, computed incrementally in the background
- Line numbers with optional relative numbering, current-line highlight,
  configurable `scrolloff`
- Status bar with cursor position, indent info and vim mode indicator
- Log view for editor messages and errors

### Vim mode (on by default, can be disabled)

- NORMAL / INSERT / VISUAL modes with the mode shown in the status bar
- Motions: `h j k l w b e 0 $ ^ gg G`
- Editing: `x dd yy cc D J p u`, insert entries `i a A I o O`
- Visual mode operations: delete, yank, indent/unindent
- Search: `/`, `n`, `N`, `*`
- Ex command line (`:`) with history and tab completion:
  file commands (`:w :q :wq :qa :x` and force variants), `:e :new`,
  filesystem commands (`:mkdir :rm :rename :copy :move :ls :pwd :cd`),
  `:tree`, `:<line>`, `:help`, and `:!cmd` to run shell commands with the
  output in a scratch buffer
- Action menu on `m`: context-aware file operations, navigation, git
  (status/log/diff/add/commit/push/pull/branches), make targets and
  custom shell commands, all driven by single keys

### Plugins (bundled)

- Tree view with git status markers (added/modified/deleted/untracked),
  keyboard navigation, and file operations (create, rename, delete)
- Autocomplete from symbols in open documents
- Project search results view
- Auto-reload of files changed on disk
- Trailing-whitespace trimming on save

### Configuration

- Plain-Lua configuration in `data/user/init.lua`, loaded after core and
  plugins; per-project overrides via `.lite_project.lua`
- User-definable keybindings, commands and syntax definitions
- Three color themes: the default dark theme plus `summer` (light) and
  `fall` (warm dark)

### Platform / build

- C11 core on SDL3 with a cached software renderer (no GPU requirement)
  and stb_truetype font rasterization
- Lua 5.4 runtime (5.3 compatible)
- Make-based build with release/debug/sanitizer targets, versioning from
  git tags, and `make install`
- Build and install scripts for Linux/macOS (`build.sh`, `install.sh` with
  desktop entry and icons) and Windows (`build.bat`, `install.ps1` with
  PATH setup and shortcuts)
- File and console logging (`cdin.log` next to the binary)

### Known limitations

- Vim layer: no counts, registers, marks, macros or text objects;
  operator+motion combos (`dw`, `ciw`, …) are not implemented — only line
  forms (`dd`, `yy`, `cc`) and visual-mode operations; `r` is redo rather
  than replace-char
- Yank/paste go through the system clipboard; no separate registers
- No LSP, no debugger, no soft wrap
- Windows support is functional but less tested than Linux

[Unreleased]: https://github.com/m-mdy-m/cdin/compare/v0.1.0-beta.1...HEAD
[0.1.0-beta.1]: https://github.com/m-mdy-m/cdin/releases/tag/v0.1.0-beta.1
