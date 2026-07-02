#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

info()  { printf '\033[1;34m[build]\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m[build]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[build]\033[0m %s\n' "$*"; }
die()   { printf '\033[1;31m[build]\033[0m ERROR: %s\n' "$*" >&2; exit 1; }

BUILD_TYPE="${BUILD_TYPE:-release}"   # release | debug
PREFIX="${PREFIX:-/usr/local}"
JOBS="${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 4)}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)        BUILD_TYPE=debug   ;;
        --release)      BUILD_TYPE=release ;;
        --prefix=*)     PREFIX="${1#*=}"   ;;
        --jobs=*)       JOBS="${1#*=}"     ;;
        -j*)            JOBS="${1#-j}"     ;;
        -h|--help)
            echo "Usage: $0 [--debug|--release] [--prefix=DIR] [--jobs=N]"
            exit 0
            ;;
        *) warn "Unknown option: $1" ;;
    esac
    shift
done

info "Build type : $BUILD_TYPE"
info "Prefix     : $PREFIX"
info "Jobs       : $JOBS"

OS="$(uname -s)"
case "$OS" in
    Linux)   PLATFORM=linux  ;;
    Darwin)  PLATFORM=macos  ;;
    MINGW*|MSYS*|CYGWIN*) PLATFORM=windows ;;
    *)       PLATFORM=unknown; warn "Unknown OS: $OS" ;;
esac
info "Platform   : $PLATFORM"

for cmd in gcc make python3; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd not found – please install it."
done

ICON_INL="src/icon.inl"
ICON_SVG="scripts/icon.svg"

if [[ -f "$ICON_SVG" ]]; then
    if [[ ! -f "$ICON_INL" ]] || [[ "$ICON_SVG" -nt "$ICON_INL" ]]; then
        info "Generating $ICON_INL from $ICON_SVG …"
        python3 scripts/gen_icon.py --svg "$ICON_SVG" --out "$ICON_INL"
        ok "$ICON_INL generated."
    else
        info "$ICON_INL is up-to-date."
    fi
else
    warn "$ICON_SVG not found – $ICON_INL will not be regenerated."
fi

MAKE_FLAGS=(
    "-j$JOBS"
    "BUILD_TYPE=$BUILD_TYPE"
    "PREFIX=$PREFIX"
    "PLATFORM=$PLATFORM"
)

info "Running make ${MAKE_FLAGS[*]} …"
make "${MAKE_FLAGS[@]}"

ok "Build complete.  Binary: $(find . -maxdepth 2 -name 'cdin' -o -name 'cdin.exe' 2>/dev/null | head -1)"