# Building from Source

cdin is plain C (gnu11) built with GNU make. There is no configure step and
no build-time code generation apart from the window icon, which is generated
from an SVG by a small Python script.

## Dependencies

- A C compiler (gcc or clang)
- GNU make
- SDL3 (development headers) — the source includes `<SDL3/SDL.h>` directly
- Lua 5.4 (5.3 also works; the build looks for `lua5.4`, `lua54`, `lua5.3`,
  `lua53`, then `lua` via pkg-config)
- Python 3 — only needed to generate `src/icon.inl` from `scripts/icon.svg`
- pkg-config — optional but recommended; without it the build falls back to
  `-lSDL3 -llua`

On Debian/Ubuntu:

```
sudo apt install build-essential libsdl3-dev liblua5.4-dev python3 pkg-config
```

On Arch:

```
sudo pacman -S base-devel sdl3 lua python
```

Font rendering uses a vendored copy of `stb_truetype` (`lib/stb/`), so there
is nothing to install for that.

## Building

```
make            # release build (default)
make run        # build and start the editor
make debug      # -O0 -g3 -DDEBUG
make debug-san  # debug build with SANITIZE=1
make info       # print the resolved build configuration
make help       # list all targets and options
```

The binary lands in `build/<platform>-<build>/cdin`, for example
`build/linux-release/cdin`. The build symlinks the repository's `data/`
directory next to the binary, so `make run` uses your working tree's Lua
files directly — edit a Lua file, restart the editor, and the change is live.

Useful variables:

| Variable | Default | Meaning |
|---|---|---|
| `BUILD` | `release` | `release` or `debug` |
| `PREFIX` | `/usr/local` | install prefix |
| `CC` | `gcc` (`clang` on macOS) | compiler |
| `LUA_VERSION` | `auto` | pin a Lua version, e.g. `LUA_VERSION=5.4` |

Example: `make BUILD=debug CC=clang`.

The version string baked into the binary comes from `git describe` — the
latest `v*` tag, plus a `-dirty` suffix if the tree has uncommitted changes.
Without any tag it falls back to `0.0.0+<commit>`.

Other targets: `clean` removes the current build directory, `distclean` also
removes generated icons, `gen-icons` regenerates the pre-rendered icon PNGs.

## Installing

```
sudo make install             # to /usr/local
make install PREFIX=~/.local  # per-user, no sudo
sudo make uninstall
```

`make install` puts the binary and the `data/` directory under
`$PREFIX/lib/cdin/` and symlinks `$PREFIX/bin/cdin` to it.

Alternatively, `scripts/install.sh` does a more complete desktop install:
binary and data under `~/.local` (or `--prefix=DIR`), icons into the hicolor
theme, and a `.desktop` entry so cdin shows up in your application menu.
Run `scripts/build.sh` first, then `scripts/install.sh`.

## The scripts/ wrappers

The shell/batch scripts in `scripts/` are thin wrappers around the Makefile
for people who don't want to remember make options, and for CI:

| Script | Platform | Does |
|---|---|---|
| `build.sh` | Linux / macOS | dependency check, icon generation, `make` |
| `install.sh` | Linux / macOS | binary + data + icons + `.desktop` entry |
| `build.bat` | Windows (MinGW/MSYS2) | same as `build.sh` |
| `install.ps1` | Windows | installs to `%LOCALAPPDATA%\cdin`, adds it to PATH, creates shortcuts |

Both accept `--debug`, `--release`, `--prefix=DIR`, `--jobs=N`.

## Windows

Use MinGW-w64 (an MSYS2 shell works fine).

1. Download the SDL3 MinGW development package from the SDL releases
   (`SDL3-devel-3.x.x-mingw.zip`) and extract it.
2. Copy `x86_64-w64-mingw32\bin\SDL3.dll` from the extracted folder into the
   project root, next to where `cdin.exe` will be built.
3. Make sure the compiler can find the SDL3 headers and libraries, e.g. by
   adding `-IC:/path/to/sdl3/x86_64-w64-mingw32/include` and
   `-LC:/path/to/sdl3/x86_64-w64-mingw32/lib` to your environment, or by
   installing SDL3 through MSYS2's pacman.
4. Run `scripts\build.bat`.

To install afterwards, run `scripts\install.ps1` from PowerShell. It copies
the binary, the runtime DLLs (`SDL3.dll`, `lua*.dll`) and `data/` to
`%LOCALAPPDATA%\cdin`, adds the bin directory to your user PATH, and creates
Start Menu / Desktop shortcuts. See `scripts\install.ps1 -?` for options
like `-NoPath`, `-NoShortcut` and `-RegisterFileTypes`.

## Troubleshooting

- **`SDL3/SDL.h not found`** — install the SDL3 development package, or on
  Windows point the compiler at the extracted SDL3 directory.
- **`lua.h not found`** — install `liblua5.4-dev` (apt) or `lua` (pacman).
- **`python3 not found`** — Python is only needed once, to generate
  `src/icon.inl`. Install it, or build on a machine that has it and commit
  the generated file.
- The editor writes a `cdin.log` file next to the binary; check it when the
  editor starts but misbehaves.
