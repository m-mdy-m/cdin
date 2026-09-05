# AGENTS.md

Guidance for agents working on cdin — a C + Lua text editor (fork of lite). The C binary is just a host; the actual editor is Lua loaded from `data/`. Detailed docs: `docs/architecture/overview.md` and `CONTRIBUTING.md`.

## Outside website direcotory
- NEVER and EVER change or touch anything outside the website directory.

## Repo layout

- Root of this repo = the editor. `website/` is a separate Vite/React site with its own `AGENTS.md` and pnpm toolchain.
- `src/` — C11 layer: window, renderer, SDL bindings, Lua binding (`src/api/` is the Lua-facing API). It knows nothing about documents or keybindings.
- `data/core/` — Lua editor core. `data/plugins/` — optional features (vim modal editing, treeview, tabs, syntax defs). Loaded automatically at startup.
- Rule of thumb: optional behavior belongs in a plugin, not core. Renderer/window changes belong in `src/`.

## Build & run

Requires: gcc/clang, GNU make, SDL3 dev headers (SDL2 auto-detected fallback), Lua 5.4 dev headers, python3.

```sh
make            # release build → build/<platform>-release/cdin
make run        # build then launch
make debug      # -O0 -g3 build → build/<platform>-debug/
make debug SANITIZE=address   # also: SANITIZE=undefined
make info       # prints detected SDL/Lua/compiler/output paths — run this first if the build fails
```

Quirks:

- First build generates `src/icon.inl` from `scripts/icon.svg` (needs python3). `make distclean` removes it; it's generated, never edit it.
- After building, `build/<platform>-release/data` is **symlinked** to the repo's `data/`. Lua changes need no recompile — edit and restart the editor. Only C changes require rebuilding.

## Verification

There is **no automated test suite**. Verify by:

1. `make && make debug` — both must build cleanly; flags are `-Wall -Wextra`, do not introduce warnings.
2. Run the editor and manually exercise what you changed; note what you tested in the PR.

## Lua conventions

- `snake_case` everything; modules return tables; classes extend `core.utils.object`.
- Globals are forbidden at runtime — `data/core/init.lua` loads `core.runtime.strict` which errors on undeclared globals.
- There is no event/hook system. Extend core by wrapping functions (save original, replace, call original) — see `data/plugins/core/trimwhitespace.lua` for the pattern.
- Background work uses `core.add_thread` coroutines (`coroutine.yield(seconds)` to sleep). Never block the frame loop with I/O.
- Commands are registered by name with predicates: `command.add("core.views.docview", { ["plugin:action"] = fn })`; keymaps map keystrokes to command names via `keymap.add`.

## PR expectations

- One topic per PR. Branches named `fix/*` or `feature/*`.
- Update docs when behavior changes: keybindings/commands → `docs/guides/commands.md`, config → `docs/guides/configuration.md`, vim → `docs/guides/vim-keybindings.md`, plugins → `docs/guides/plugins.md`, architecture → `docs/architecture/overview.md`.
- Add user-visible changes under `[Unreleased]` in `CHANGELOG.md`.
- Commits follow conventional style: `feat(scope): ...`, `fix(scope): ...`, imperative, <72 chars.
