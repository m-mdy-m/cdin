# scripts/

Thin, portable wrappers around the real build system (the `Makefile` /
`mk/*.mk`). They exist so you don't need to know Make syntax just to
build or install cdin, and so CI configs have one obvious entry point
per platform.

| Script | Platform | Does |
|---|---|---|
| `build.sh` | Linux / macOS | `make build` (+ `debug`, `debug-san`), then prints `make info` |
| `install.sh` | Linux / macOS | `make install` to `$PREFIX` (default `/usr/local`) |
| `build.bat` | Windows (MSYS2/MinGW shell) | same as `build.sh`, plus copies `SDL3.dll` next to the binary |
| `install.bat` | Windows | builds and stages a self-contained folder (binary + `data/` + `SDL3.dll`) since Windows has no `/usr/local`-style convention |

If you already know Make, just use it directly — `make build`,
`make install`, `make info`, `make help`. These scripts don't do
anything Make can't; they're a convenience layer, not a separate
build system.

Windows users: read `docs/guides/building.md` first — you need the
SDL3 mingw devel package extracted and `SDL3.dll` copied into the
project root before either script will work.