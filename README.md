# cdin

A lightweight, keyboard-centric text editor with Vim-style modal editing.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0--beta.1-orange.svg)](CHANGELOG.md)

---

## What it is

cdin started as a fork of [lite](https://github.com/rxi/lite) and has since grown into its own project. The core idea is simple: an editor that's fast to start, easy to read through, and straightforward to extend. The design borrows from lite-xl in a few places, especially around UX decisions, but cdin makes its own choices about what to keep and what to cut.

Vim-style modal editing is built in and on by default. Every buffer opens in Normal mode. If you've used Vim, the basics transfer directly. If you haven't, the status bar always shows which mode you're in.

The editor is written in C and Lua. The C layer handles the window, renderer, and SDL bindings. Everything else — the editor behavior, plugins, keybindings, configuration — is Lua, loaded at runtime from `data/`. This means you can change most of how the editor works without recompiling anything.

## Philosophy

Simplicity and hackability come first. The codebase is meant to be readable: you should be able to find the edit loop, understand what it does, and change it without needing to know the whole project. Performance matters — startup time, memory use, and rendering smoothness are all considered. Extensibility should feel natural, not bolted on. And the editor should be something you can carry with you: small, self-contained, not dependent on a runtime ecosystem.

## Features

- Modal editing (Normal / Insert / Visual) with Vim keybindings
- Ex command line (`:w`, `:q`, `:e`, `:!cmd`, and more)
- File manager menu (`m` in Normal mode)
- Project tree view with optional git status markers
- Trailing whitespace trimmed on save
- Relative or absolute line numbers
- Configurable via a single Lua file

## Documentation

- [Over View](docs/architecture/overview.md)
- [Getting Started](docs/guides/getting-started.md.md)
- [Building from Source](docs/guides/building.md)
- [Configuration](docs/guides/configuration.md)
- [Vim Keybindings](docs/guides/vim-keybindings.md)
- [Plugins](docs/guides/plugins.md)
- [Command Reference](docs/guides/commands.md)
- [Contributing](CONTRIBUTING.md)

## Quick start

```sh
# clone
git clone https://github.com/m-mdy-m/cdin.git
cd cdin

# build (requires gcc, make, SDL3, Lua 5.4)
make

# run
./build/linux-release/cdin
# or open a file/directory
./build/linux-release/cdin path/to/project
```

See [Building from Source](docs/guides/building.md) for dependency details and platform-specific instructions.

## License

MIT — see [LICENSE](LICENSE).

## Credits

- Based on [lite](https://github.com/rxi/lite) by rxi
- Inspired by [Vim](https://www.vim.org/) and [lite-xl](https://lite-xl.com/)
- Font rendering via [stb_truetype](https://github.com/nothings/stb)