#!/usr/bin/env bash
#
# scripts/build.sh — build cdin on Linux/macOS
#
# Thin wrapper around `make build`. Exists so people (and CI) who don't
# want to think about Makefile targets have one obvious command to run.
#
# Usage:
#   ./scripts/build.sh                # release build
#   ./scripts/build.sh debug          # debug build (BUILD=debug)
#   ./scripts/build.sh debug-san      # debug build + sanitizers
#   PREFIX=/opt/cdin ./scripts/build.sh
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

MODE="${1:-build}"

case "$MODE" in
  build|debug|debug-san)
    ;;
  *)
    echo "usage: $0 [build|debug|debug-san]" >&2
    exit 1
    ;;
esac

if ! command -v make >/dev/null 2>&1; then
  echo "error: 'make' not found. Install build-essential (Debian/Ubuntu)," >&2
  echo "       Xcode command line tools (macOS), or your distro's equivalent." >&2
  exit 1
fi

if ! command -v pkg-config >/dev/null 2>&1; then
  echo "warning: 'pkg-config' not found — SDL3/Lua autodetection will fall back" >&2
  echo "         to hardcoded link flags and may fail to find your install." >&2
fi

echo "==> make $MODE"
make "$MODE"

echo "==> make info"
make info