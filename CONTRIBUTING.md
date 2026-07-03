# Contributing

Thanks for your interest in cdin. The project values small, readable,
auditable code — contributions should keep it that way.

## Getting set up

You need gcc/clang, GNU make, SDL3 and Lua 5.4 headers, and Python 3.
See [docs/guides/building.md](docs/guides/building.md) for the details.

```
git clone https://github.com/m-mdy-m/cdin
cd cdin
make run
```

The build symlinks the repository's `data/` directory next to the binary,
so Lua changes are live on the next start — most editor work is a
change-and-restart loop with no recompile. Use `make debug` for a
debuggable C build and `make debug-san` for sanitizers.

## Where things are

- `src/` — the C runtime: window, input, rendering, the Lua ↔ C API.
  Changes here should be rare and well justified.
- `data/core/` — the Lua editor core: documents, views, commands, keymap.
- `data/plugins/` — everything optional: tree view, vim mode, autocomplete,
  language syntaxes. New features usually belong here.
- `mk/`, `scripts/` — build system and its wrappers.

Read [docs/architecture/overview.md](docs/architecture/overview.md) before
touching the core; it explains the command/keymap/coroutine patterns that
everything is built on.

## Reporting bugs

Open an issue with steps to reproduce, what you expected, what happened
instead, and your platform. The `cdin.log` file written next to the binary
often contains the relevant error — include it. Check existing issues first.

## Suggesting features

Open an issue describing the feature and the problem it solves. Keep the
project philosophy in mind: cdin prefers a small core with features as
plugins, and would rather do less than become configurable soup. Features
that can be a plugin should be a plugin.

## Submitting changes

1. Fork and create a branch (`git checkout -b feature/thing`)
2. Make the change; keep it focused — one topic per pull request
3. Build both `make` and `make debug` cleanly (the C flags include
   `-Wall -Wextra`; don't introduce warnings)
4. Run the editor and exercise what you changed. There is no automated test
   suite yet, so a note in the PR about how you tested it is expected
5. Update the docs under `docs/` if behavior, commands, keybindings or
   configuration changed
6. Add a line to the `[Unreleased]` section of `CHANGELOG.md` if the change
   is user-visible
7. Open a pull request explaining what and why

## Code style

The repository has an `.editorconfig`; most editors pick it up
automatically. In short: UTF-8, LF line endings, final newline, trimmed
trailing whitespace, 2-space indentation (tabs in Makefiles).

For C: C11 (gnu11), keep functions short, no new dependencies without prior
discussion. For Lua: follow the style of `data/core/` — `snake_case`,
modules return a table, classes use `Object:extend()` from `core.object`.

Commit messages: a short imperative summary line ("add soft wrap to
docview"), with a body when the why isn't obvious.

## Questions

Open an issue or start a thread in
[Discussions](https://github.com/m-mdy-m/cdin/discussions).
