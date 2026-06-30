#!/usr/bin/env bash
#
# scripts/install.sh — build and install cdin on Linux/macOS
#
# Thin wrapper around `make install`. Installs the binary and its data/
# directory as siblings under $PREFIX/lib/cdin, with a symlink in
# $PREFIX/bin so `cdin` ends up on PATH (see mk/install.mk for why the
# binary and data/ must stay siblings).
#
# Usage:
#   ./scripts/install.sh                  # installs to /usr/local
#   PREFIX=$HOME/.local ./scripts/install.sh
#   sudo ./scripts/install.sh             # if PREFIX needs root (default)
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

PREFIX="${PREFIX:-/usr/local}"

if ! command -v make >/dev/null 2>&1; then
  echo "error: 'make' not found." >&2
  exit 1
fi

echo "==> make build"
make build

echo "==> make install PREFIX=$PREFIX"
make install PREFIX="$PREFIX"

echo
echo "Installed. Run with: cdin"
echo "(if 'cdin' isn't found, make sure $PREFIX/bin is on your PATH)"