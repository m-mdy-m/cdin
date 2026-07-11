# Building from Source

## Dependencies

You need four things to build cdin:

- a C compiler (gcc or clang)
- GNU make
- SDL3 development headers and library (SDL2 also works and is auto-detected if SDL3 isn't found)
- Lua 5.4 development headers

Get these from your system's package manager. On most Linux distros they're a
single command away. On macOS, Homebrew covers all of them. On Windows, see
the note at the bottom.

Python 3 is also needed, but only to regenerate `src/icon.inl` from the SVG
source. The build checks for it and calls it automatically. If you already
have a current `src/icon.inl` checked in, you can skip Python entirely — but
if you're building from a fresh clone you'll want it. The two Python packages
it needs are `cairosvg` and `Pillow` (`pip install cairosvg Pillow`).

## Building

```sh
make          # release build (default)
make debug    # debug build — no optimization, debug symbols, sanitizers available
make run      # build then immediately launch the result
make info     # print what was detected (SDL version, Lua version, flags, output path)
```

The output lands in `build/<platform>-release/cdin` (or `cdin.exe` on
Windows). A symlink to the `data/` directory is placed there automatically so
you can run the binary from the build directory.

To clean up:

```sh
make clean       # remove this platform's build directory
make distclean   # remove all build directories and the generated icon.inl
```

## Options

These can be passed on the make command line:

| Variable | Default | Effect |
|----------|---------|--------|
| `BUILD` | `release` | Set to `debug` for a debug build |
| `PREFIX` | `/usr/local` | Installation prefix |
| `SDL_VERSION` | `auto` | Force `2` or `3`; auto prefers SDL3 |
| `LUA_VERSION` | `auto` | Force a version like `5.4` |
| `CC` | `gcc` / `clang` | Override the compiler |

Example — build with debug symbols and install to your home directory:

```sh
make BUILD=debug
make install PREFIX=~/.local
```

## Installing

```sh
make install            # installs to PREFIX/bin and PREFIX/lib/cdin
make install PREFIX=~   # or any other path
make uninstall          # removes what install put there
```

The binary goes to `$PREFIX/bin/cdin` as a symlink to the real binary in
`$PREFIX/lib/cdin/`. The `data/` directory is copied to `$PREFIX/lib/cdin/data/`.

## Python script

If you'd rather not use make directly, `scripts/cdin.py` wraps the same
operations and adds a few extras (auto-install, update from GitHub, icon
generation, interactive wizard):

```sh
python3 scripts/cdin.py build
python3 scripts/cdin.py build-install
python3 scripts/cdin.py install --shortcut   # also creates a desktop entry
```

Run it with no arguments for an interactive menu. Full documentation is in
[`scripts/README.md`](../../scripts/README.md).

## Windows

On Windows you need the SDL3 MinGW development package. Download it from the
SDL releases page, extract it, and copy `SDL3.dll` from the `x86_64-w64-mingw32/bin/`
folder into the project root before building. The compiler flags pick up the
headers and import libraries automatically if you point them at the right place.

The Python install script handles more of this automatically:
`python scripts/cdin.py build` walks you through it if dependencies are missing.

## Checking what was detected

Before building, run `make info` to see exactly what the build system found:

```
cdin build configuration
────────────────────────────────────────
  VERSION      0.1.0-beta.1
  PLATFORM     linux
  BUILD        release
  SDL          3 (required)
  LUA          5.4.7 [pkg: lua5.4]
  CC           gcc
  OUT          build/linux-release/cdin
  PREFIX       /usr/local
────────────────────────────────────────
```

If SDL or Lua headers aren't found, the error message tells you what's missing.