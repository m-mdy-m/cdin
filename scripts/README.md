# scripts/

Portable wrappers around the cdin build system (`Makefile` / `mk/*.mk`).
Everything routes through a single entry point so you don't need to know
Make syntax to build, install, or manage assets.

## Main entry point — `cdin.py`

```
python3 scripts/cdin.py [command] [options]
```

No arguments → interactive wizard.

| Command | Does |
|---|---|
| `build` | Compile cdin from source (regenerates `icon.inl` automatically) |
| `install` | Install an already-built binary, data files, and desktop integration |
| `build-install` | `build` + `install` in one step |
| `update` | Download and install the latest release from GitHub |
| `uninstall` | Remove a cdin installation |
| `gen-icon` | Generate `.ico` / `.icns` / `.png` icons from the SVG source |
| `gen-logo` | Rasterize the SVG into `data/core/rootview/logo.lua` span data |

### Common examples

```sh
# build
python3 scripts/cdin.py build
python3 scripts/cdin.py build --debug --jobs 8

# install
python3 scripts/cdin.py install --shortcut
python3 scripts/cdin.py build-install

# update / uninstall
python3 scripts/cdin.py update --check
python3 scripts/cdin.py update --version 0.2.0
python3 scripts/cdin.py uninstall

# regenerate icons (called automatically on every build)
python3 scripts/cdin.py gen-icon
python3 scripts/cdin.py gen-icon path/to/icon.svg --out-dir build/icons --out-inl src/icon.inl

# regenerate logo.lua
python3 scripts/cdin.py gen-logo
python3 scripts/cdin.py gen-logo --grid 128 --out /tmp/logo.lua
```

## Standalone scripts

`gen_icon.py` and `gen_logo_lua.py` are thin entry points for the same
functionality — useful when you want to call them directly without going
through `cdin.py`:

```sh
python3 scripts/gen_icon.py [icon.svg] [--out-dir DIR] [--out-ico PATH] [--out-inl PATH]
python3 scripts/gen_logo_lua.py [icon.svg] [--grid N] [--out PATH]
```

Both require `cairosvg` and `Pillow`; `gen_logo_lua.py` also needs `numpy`.

```sh
pip install cairosvg Pillow numpy
```

## SVG sources

| File | Used for |
|---|---|
| `icon.svg` | Primary icon source (all sizes derived from this) |
| `icon bg.svg` | Background variant |

## Internal package — `_cdin/`

All logic lives in `_cdin/` as importable modules. `cdin.py` and the
standalone scripts are thin dispatchers on top of it.

| Module | Responsibility |
|---|---|
| `_constants.py` | Project-wide paths and constants |
| `platform.py` | Platform detection, prefix defaults |
| `ui.py` | Coloured output, prompts |
| `utils.py` | Subprocess, filesystem, version helpers |
| `build.py` | `build` command |
| `install.py` | `install` command |
| `build_install.py` | `build-install` command |
| `update.py` | `update` command |
| `uninstall.py` | `uninstall` command |
| `gen_icon.py` | Icon rasterisation and packaging |
| `gen_logo.py` | Logo span generation for `logo.lua` |
| `interactive.py` | Interactive wizard (no-args mode) |

If you already know Make, just use it directly — `make build`, `make install`,
`make info`, `make help`. These scripts are a convenience layer, not a
separate build system.

> **Windows users:** read `docs/guides/building.md` first — you need the SDL3
> MinGW devel package and `SDL3.dll` in the project root before building.