#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

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
    for candidate in build/cdin cdin ./cdin bin/cdin build/linux-release/cdin; do
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
DATA_DIR="$BIN_DIR/data"

if [[ -d "bin/data" ]]; then
    SRC_DATA="bin/data"
elif [[ -d "data" ]]; then
    SRC_DATA="data"
else
    SRC_DATA=""
fi

if [[ -n "$SRC_DATA" ]]; then
    mkdir -p "$DATA_DIR"
    cp -r "$SRC_DATA"/. "$DATA_DIR/"
    ok "Installed data   → $DATA_DIR"
fi

# ---------- install icons -----------------------------------------------------
HICOLOR_DIR="$PREFIX/share/icons/hicolor"
ICON_INSTALLED=0

install_png_size() {
    local size="$1"
    local src_png="$2"
    local dest_dir="$HICOLOR_DIR/${size}x${size}/apps"
    mkdir -p "$dest_dir"
    cp "$src_png" "$dest_dir/cdin.png"
}

# Locate bundled pre-rendered PNGs (checked in priority order)
ICONS_SRC=""
for candidate in scripts/icons icons bin/icons; do
    [[ -d "$candidate" ]] && { ICONS_SRC="$candidate"; break; }
done

if [[ -n "$ICONS_SRC" ]]; then
    info "Installing icons from $ICONS_SRC …"
    installed_count=0
    for sz in 16 22 24 32 48 64 128 256 512; do
        PNG="$ICONS_SRC/cdin-${sz}.png"
        if [[ -f "$PNG" ]]; then
            install_png_size "$sz" "$PNG"
            (( installed_count++ )) || true
        fi
    done

    # Install scalable SVG if present
    for svg_candidate in scripts/icon.svg icon.svg; do
        if [[ -f "$svg_candidate" ]]; then
            SCALABLE_DIR="$HICOLOR_DIR/scalable/apps"
            mkdir -p "$SCALABLE_DIR"
            cp "$svg_candidate" "$SCALABLE_DIR/cdin.svg"
            info "Installed scalable SVG → $SCALABLE_DIR/cdin.svg"
            break
        fi
    done

    ok "Installed $installed_count PNG icons → $HICOLOR_DIR"
    ICON_INSTALLED=1

elif command -v rsvg-convert &>/dev/null && [[ -f "scripts/icon.svg" ]]; then
    info "No pre-rendered PNGs found; converting SVG with rsvg-convert …"
    for sz in 16 22 24 32 48 64 128 256; do
        TMP_PNG="/tmp/cdin_${sz}.png"
        rsvg-convert -w "$sz" -h "$sz" "scripts/icon.svg" -o "$TMP_PNG" 2>/dev/null \
            && install_png_size "$sz" "$TMP_PNG"
    done
    SCALABLE_DIR="$HICOLOR_DIR/scalable/apps"
    mkdir -p "$SCALABLE_DIR"
    cp "scripts/icon.svg" "$SCALABLE_DIR/cdin.svg"
    ICON_INSTALLED=1
    ok "Installed icons → $HICOLOR_DIR"

elif command -v convert &>/dev/null && [[ -f "scripts/icon.svg" ]]; then
    info "No pre-rendered PNGs found; converting SVG with ImageMagick …"
    for sz in 16 22 24 32 48 64 128 256; do
        TMP_PNG="/tmp/cdin_${sz}.png"
        convert -background none "scripts/icon.svg" -resize "${sz}x${sz}" "$TMP_PNG" 2>/dev/null \
            && install_png_size "$sz" "$TMP_PNG"
    done
    ICON_INSTALLED=1
    ok "Installed icons → $HICOLOR_DIR"

else
    warn "No pre-rendered icons found and no SVG converter available – icon skipped."
    warn "Re-run: pip install cairosvg Pillow && python3 scripts/gen_icon.py"
fi

# ---------- update icon cache -------------------------------------------------
if [[ "$ICON_INSTALLED" -eq 1 ]]; then
    # gtk-update-icon-cache is the standard tool; rebuild every size dir we touched
    if command -v gtk-update-icon-cache &>/dev/null; then
        gtk-update-icon-cache -f -t "$HICOLOR_DIR" 2>/dev/null && \
            info "Icon cache updated (gtk-update-icon-cache)" || true
    elif command -v update-icon-caches &>/dev/null; then
        update-icon-caches "$HICOLOR_DIR" 2>/dev/null && \
            info "Icon cache updated (update-icon-caches)" || true
    fi

    # xdg-icon-resource: registers the icon with the XDG icon system on
    # many DEs (GNOME, KDE, XFCE) and handles cache refresh automatically
    if command -v xdg-icon-resource &>/dev/null; then
        for sz in 16 22 24 32 48 64 128 256; do
            PNG="$HICOLOR_DIR/${sz}x${sz}/apps/cdin.png"
            [[ -f "$PNG" ]] && \
                xdg-icon-resource install --noupdate --size "$sz" "$PNG" cdin 2>/dev/null || true
        done
        xdg-icon-resource forceupdate 2>/dev/null || true
        info "Icons registered via xdg-icon-resource"
    fi
fi

# ---------- .desktop file -----------------------------------------------------
DESKTOP_DIR="$PREFIX/share/applications"
mkdir -p "$DESKTOP_DIR"

ICON_REF="cdin"
[[ "$ICON_INSTALLED" -eq 0 ]] && ICON_REF="text-editor"

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

# Register the .desktop file with the XDG menu system
if command -v xdg-desktop-menu &>/dev/null; then
    xdg-desktop-menu install --novendor "$DESKTOP_DIR/cdin.desktop" 2>/dev/null || true
    info "Desktop entry registered via xdg-desktop-menu"
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