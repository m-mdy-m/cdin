# cdin

> A lightweight, fast, and hackable text editor with Vim-like keybindings

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-green.svg)](CHANGELOG.md)

## Project status and identity
cdin started as a fork of lite, and that heritage is visible in some design choices and early code. However, cdin is not a mere copy: the codebase has diverged, the project goals and implementation details have been rethought, and cdin is following its own path. The project is also inspired by lite-xl; ideas and UX learnings from lite-xl influenced several implementation and design decisions. In short: yes, a fork of lite, but cdin is its own project with its own direction.

## Philosophy
Simplicity and hackability come first. The core of cdin aims to be small, predictable, and understandable: you should be able to read the source, find the edit loop, and add or change behavior in a few minutes. Performance matters: startup time, low memory footprint, and smooth text rendering are priorities. Extensibility is designed to be simple and unobtrusive — plugins and configuration should feel like first-class citizens rather than afterthoughts. Keyboard-centric editing is the default; Vim-inspired modal keybindings let you stay in the editor and keep your hands on the keyboard. Minimal external dependencies reduce friction for building and packaging, and we favor single-file, auditable subsystems where practical. Above all, cdin is meant for people who prefer tools they can tweak, read, and carry with them — an editor that gives you freedom instead of obscuring behavior behind layers of abstraction.
## Documentation

- [Building from Source](docs/guides/building.md) __not_created__
- [Configuration Guide](docs/guides/configuration.md) __not_created__
- [Plugin Development](docs/guides/plugin-development.md) __not_created__
- [Vim Keybindings](docs/guides/vim-keybindings.md) __not_created__
- [API Reference](docs/api/) __not_created__ 
- [Architecture](docs/architecture/) __not_created__

## Contributing

We welcome contributions! Please see:
- [Contributing Guidelines](CONTRIBUTING.md) 
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Code Style Guide](docs/contributing/code-style.md) __not_created__

## Architecture

See [Architecture Overview](docs/architecture/overview.md) __not_created__

## License

MIT License - see [LICENSE](LICENSE)

## Credits

- Based on [lite](https://github.com/rxi/lite) by rxi
- Inspired by [Vim](https://www.vim.org/),
- Font rendering via [stb_truetype](https://github.com/nothings/stb)

## Support

- [Issue Tracker](https://github.com/m-mdy-m/cdin/issues)
- [Discussions](https://github.com/m-mdy-m/cdin/discussions)
- [Documentation](docs/) 