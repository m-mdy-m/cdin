#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

info()  { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m[install]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[install]\033[0m %s\n' "$*"; }
die()   { printf '\033[1;31m[install]\033[0m ERROR: %s\n' "$*" >&2; exit 1; }

PREFIX="${PREFIX:-$HOME/.local}"
BINARY_SRC="${BINARY_SRC:-}" 

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix=*)  PREFIX="${1#*=}" ;;
        --binary=*)  BINARY_SRC="${1#*=}" ;;
        -h|--help)
            echo "Usage: $0 [--prefix=DIR] [--binary=PATH]"
            exit 0 ;;
        *) warn "Unknown option: $1" ;;
    esac
    shift
done

info "Prefix  : $PREFIX"

if [[ -z "$BINARY_SRC" ]]; then
    for candidate in build/cdin cdin ./cdin bin/cdin; do
        [[ -f "$candidate" ]] && { BINARY_SRC="$candidate"; break; }
    done
fi

[[ -z "$BINARY_SRC" || ! -f "$BINARY_SRC" ]] && \
    die "Binary not found. Run build.sh first, or pass --binary=PATH."

info "Binary  : $BINARY_SRC"

BIN_DIR="$PREFIX/bin"
mkdir -p "$BIN_DIR"
install -m 755 "$BINARY_SRC" "$BIN_DIR/cdin"
ok "Installed binary → $BIN_DIR/cdin"

# ---------- install data files ------------------------------------------------
SHARE_DIR="$PREFIX/share/cdin"
if [[ -d "data" ]]; then
    mkdir -p "$SHARE_DIR"
    cp -r data/. "$SHARE_DIR/"
    ok "Installed data   → $SHARE_DIR"
fi

# ---------- install icon -------------------------------------------------------
ICON_DIR="$PREFIX/share/icons/hicolor"

install_icon_size() {
    local size="$1"
    local src_png="$2"
    local dest="$ICON_DIR/${size}x${size}/apps"
    mkdir -p "$dest"
    cp "$src_png" "$dest/cdin.png"
}

SVG_SRC="scripts/icon.svg"
ICON_INSTALLED=0

# Prefer converting SVG to multiple PNG sizes
if command -v rsvg-convert &>/dev/null && [[ -f "$SVG_SRC" ]]; then
    for sz in 16 32 48 64 128 256; do
        TMP_PNG="/tmp/cdin_${sz}.png"
        rsvg-convert -w "$sz" -h "$sz" "$SVG_SRC" -o "$TMP_PNG" 2>/dev/null && \
            install_icon_size "$sz" "$TMP_PNG"
    done
    # Also install scalable SVG
    SCALABLE_DIR="$ICON_DIR/scalable/apps"
    mkdir -p "$SCALABLE_DIR"
    cp "$SVG_SRC" "$SCALABLE_DIR/cdin.svg"
    ICON_INSTALLED=1
    ok "Installed icons  → $ICON_DIR"
elif command -v convert &>/dev/null && [[ -f "$SVG_SRC" ]]; then
    for sz in 16 32 48 64 128 256; do
        TMP_PNG="/tmp/cdin_${sz}.png"
        convert -background none "$SVG_SRC" -resize "${sz}x${sz}" "$TMP_PNG" 2>/dev/null && \
            install_icon_size "$sz" "$TMP_PNG"
    done
    ICON_INSTALLED=1
    ok "Installed icons  → $ICON_DIR"
else
    warn "rsvg-convert / ImageMagick not found – icon not converted to PNG."
    if [[ -f "$SVG_SRC" ]]; then
        SCALABLE_DIR="$ICON_DIR/scalable/apps"
        mkdir -p "$SCALABLE_DIR"
        cp "$SVG_SRC" "$SCALABLE_DIR/cdin.svg"
        ICON_INSTALLED=1
        info "Installed SVG icon → $SCALABLE_DIR/cdin.svg"
    fi
fi

# ---------- .desktop file (Linux / WSL GUI) -----------------------------------
DESKTOP_DIR="$PREFIX/share/applications"
mkdir -p "$DESKTOP_DIR"

ICON_REF="cdin"   # icon theme lookup by name
[[ "$ICON_INSTALLED" -eq 0 ]] && ICON_REF="text-editor"  # generic fallback

cat > "$DESKTOP_DIR/cdin.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=cdin
Comment=Lightweight code editor
Exec=$BIN_DIR/cdin %F
Icon=$ICON_REF
Terminal=false
Categories=Development;TextEditor;
MimeType=text/plain;text/x-csrc;text/x-chdr;text/x-lua;
StartupNotify=true
StartupWMClass=cdin
EOF

ok "Desktop entry → $DESKTOP_DIR/cdin.desktop"

# ---------- update icon cache / desktop database ------------------------------
if command -v update-icon-caches &>/dev/null; then
    update-icon-caches "$ICON_DIR" 2>/dev/null || true
elif command -v gtk-update-icon-cache &>/dev/null; then
    gtk-update-icon-cache -f -t "$ICON_DIR" 2>/dev/null || true
fi

if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

# ---------- PATH hint ---------------------------------------------------------
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    warn "$BIN_DIR is not in your PATH."
    echo
    echo "  Add this line to your ~/.bashrc or ~/.zshrc:"
    echo "    export PATH=\"$BIN_DIR:\$PATH\""
    echo "  Then reload: source ~/.bashrc"
else
    ok "cdin is now available in your terminal."
fi

echo
ok "Installation complete!  Run: cdin"