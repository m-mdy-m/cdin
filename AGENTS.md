# AGENTS.md

Guidance for agents working on cdin — a C + Lua text editor (fork of lite). The C binary is just a host; the actual editor is Lua loaded from `data/`. Detailed docs: `docs/architecture/overview.md` and `CONTRIBUTING.md`.

## Outside website direcotry
- NEVER and EVER change or touch anything outside the website directory.

## Repo layout

- Root of this repo = the editor **runtime**, and it is self-contained: its `data/` holds only `core/`. `website/` is a separate Vite/React site with its own `AGENTS.md` and pnpm toolchain.
- `src/` — C11 layer: window, renderer, SDL bindings, Lua binding (`src/api/` is the Lua-facing API). It knows nothing about documents or keybindings.
- `data/core/` — the whole of the editor. Runtime: config, state, views, syntax, commands, keymaps, plugin loader. Loaded from `data/core/init.lua`.
- There is no `data/plugins/`, `data/themes/` or `data/fonts/` in this repo. Those are **build output**, assembled into `build/<platform>-<build>/data/` from [cdin-x](https://github.com/m-mdy-m/cdin-x) at build time. See `mk/bundle.mk`.
- Rule of thumb: optional behavior belongs in an extension, not core. Renderer/window changes belong in `src/`.

## cdin-x and CDINX_DIR

The one coupling between this repo and cdin-x is a build input: the variable `CDINX_DIR`, read only in `mk/bundle.mk`, `scripts/assemble_data.py` and `scripts/_cdin/*.py`. Nothing under `src/` or `data/` refers to cdin-x, and a build never fetches anything.

A **build** is not self-sufficient on its own: `make` compiles the binary *and* bundles the mandatory set (the vim plugin, the default theme, the fonts) from a cdin-x checkout, because an editor without them cannot start. `make bin` compiles the binary only and needs no cdin-x.

The contract cdin provides and cdin-x may rely on is written down in `docs/architecture/extension-contract.md`. Read it before changing anything about `config.site_dir`, the plugin loader or the theme registry.

## Plugins

A plugin is a directory with an `init.lua`, or a single `.lua` file. There are two roots and they have different rules:

- `EXEDIR/data/plugins` — **bundled**, i.e. the mandatory set. Every entry loads, always, whatever `config.plugins` or `--no-plugins` say. This is what a build produced from cdin-x.
- `config.site_dir/plugins` — **site**, i.e. what a user installed. Selected by `config.plugins`.

`data/core/plugins.lua` `dofile`s each entry point and calls `init(core, config)`. Failures are caught and logged — a failing *bundled* plugin is reported at error level and the rest still load; a failing site plugin is logged and skipped. The editor always starts.

**Nothing in `data/core/` may depend on a site plugin.** With no cdin-x installed the editor must start, render, edit and respond to `ctrl+n`. That is why the user-facing workflows — command palette, find file, open file, open folder, the module pickers — are not runtime commands, and why `ctrl+p`, `ctrl+shift+p` and `ctrl+o` are not bound here. `ctrl+n` is: a new document needs no extension.

`config.plugins` is read from `~/.config/cdin/user/init.lua`, which therefore runs *before* the plugins. Two consequences: a plugin's commands and keymaps are registered after user config, so a plugin can overwrite a keymap set in `init.lua` but not the reverse; and `require`-ing a plugin's *module* from `init.lua` works (the site roots are on `package.path`) while its `init()` side effects are not there yet. The `--no-plugins` flag sets `config.plugins = false`, which now means "no **site** plugins" — the mandatory bundle still loads, because a cdin without vim is not an editor.

`core:load-plugin` / `core:unload-plugin` / `core:list-plugins` (`data/core/commands/plugin.lua`) change the site set at runtime. Nothing about that persists.

## Build & run

Requires: gcc/clang, GNU make, SDL3 dev headers (SDL2 auto-detected fallback), Lua 5.4 dev headers, python3. Plus a cdin-x checkout, for anything other than `make bin`.

### Quick start

```sh
make                          # binary + bundled data/ → build/<platform>-release/
make CDINX_DIR=/path/to/cdin-x   # …using that checkout instead of ../cdin-x
make bin                      # compile the binary only; no cdin-x needed
make bundle                   # assemble build/…/data only
make run                      # build then launch
make debug                    # -O0 -g3 build → build/<platform>-debug/
make info                     # prints detected SDL/Lua/compiler/output paths
```

A fresh clone does **not** build with `make` alone: it needs a cdin-x checkout
next to it, because the mandatory set lives there. That is deliberate — the
split is the point, and the failure message says what to do.

### CI/CD

Release workflows check out this repository **and cdin-x as a sibling**, generate
icons, and run `make build`. The Dockerfile does the same. They package the
**assembled** `build/…/data`, never the source `data/`.

### The data assembly

`scripts/assemble_data.py` owns it:

- `build/…/data/core` is a symlink to the source `data/core`, falling back to a
  copy. It is **recreated on every build**, not created-if-missing: a link that
  is made once and then assumed correct is exactly how a stale copy becomes
  the editor you are running.
- Everything else comes from `<CDINX_DIR>/scripts/bundle.py`.
- An old `build/…/data` that is a symlink is unlinked, never followed.

Lua changes under `data/core/` need no recompile — edit and restart. Only C
changes require rebuilding.

### Verification

1. `make && make debug` — both must build cleanly; flags are `-Wall -Wextra`, do not introduce warnings.
2. `make test-plugins` — the Lua data-layer tests. Needs only `lua`; no build, no editor, and **no cdin-x**. `scripts/test_commands.lua` covers keymap integrity with zero plugins (every command a binding names must exist, the palette must get a working submit and suggest, and the runtime must own exactly the bindings it is supposed to). `scripts/test_lua.lua` covers the loader and the theme registry over `scripts/fixtures/`, across site-present/site-absent × `config.plugins` = nil / false / whitelist. Both build their tree from the fixtures, so a test can never be satisfied by what happens to be on disk. Run it after touching anything under `data/core/plugins.lua`, `data/core/themes.lua`, `data/core/commands/`, `data/core/keymaps/`, `data/core/rootview/empty_view.lua` or `scripts/`.
3. `make test-lua` — the unit + integration suite in `tests/lua/` (text pipeline, `Doc`, theme registry). Plain `lua`, no build, no editor, no cdin-x. The theme tests need a tree holding `data/themes/<name>/theme.lua`, so the target asks `scripts/test_lua.lua` to build the fixture tree it already builds and points at that. Run it after touching anything under `data/core/text/`, `data/core/doc/`, `data/core/themes.lua` or `data/core/style.lua`.
4. `make test-workflows` — the other half of the split, and the only test that reads cdin-x. Needs `lua` and `CDINX_DIR`; no build, no editor. `scripts/test_workflows.lua` uses the cdin-x checkout as the site directory and asserts that the workflow plugins register their commands, that `ctrl+p` / `ctrl+shift+p` / `ctrl+o` / `ctrl+shift+o` each have exactly one command bound, that `data/core/keymaps/default.lua` names none of them, and that unloading `palette`, `finder` and `modules` through the manager detaches both. Run it whenever a keybinding, the loader, or anything under `data/core/keymaps/` changes — a stale runtime binding and a duplicated plugin binding are the two failures it exists to catch, and neither is visible from one repository alone.
5. Run the editor and manually exercise what you changed; note what you tested in the PR.

## Lua conventions

- `snake_case` everything; modules return tables; classes extend `core.utils.object`.
- Globals are forbidden at runtime — `data/core/init.lua` loads `core.runtime.strict` which errors on undeclared globals.
- There is no event/hook system. Extend core by wrapping functions (save original, replace, call original).
- Background work uses `core.add_thread` coroutines (`coroutine.yield(seconds)` to sleep). Never block the frame loop with I/O.
- Commands are registered by name with predicates: `command.add("core.views.docview", { ["plugin:action"] = fn })`; keymaps map keystrokes to command names via `keymap.add`. Both have matching `remove`, and a plugin that registers is expected to unregister.

## PR expectations

- One topic per PR. Branches named `fix/*` or `feature/*`.
- Update docs when behavior changes: keybindings/commands → `docs/guides/commands.md`, config → `docs/guides/configuration.md`, vim → `docs/guides/vim-keybindings.md`, plugins → `docs/guides/plugins.md`, themes → `docs/guides/themes.md`, architecture → `docs/architecture/overview.md`.
- Add user-visible changes under `[Unreleased]` in `CHANGELOG.md`.
- Commits follow conventional style: `feat(scope): ...`, `fix(scope): ...`, imperative, <72 chars.
