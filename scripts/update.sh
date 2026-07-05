#!/usr/bin/env bash
# Usage:
#   cdin update            
#   cdin update --check    
#   cdin update --force    
#   cdin update --version X
#   bash update.sh         

set -euo pipefail

if [[ -t 1 ]]; then
  C_RESET='\033[0m'
  C_BOLD='\033[1m'
  C_BLUE='\033[1;34m'
  C_GREEN='\033[1;32m'
  C_YELLOW='\033[1;33m'
  C_RED='\033[1;31m'
  C_DIM='\033[2m'
  C_ACCENT='\033[38;5;140m'
else
  C_RESET='' C_BOLD='' C_BLUE='' C_GREEN=''
  C_YELLOW='' C_RED='' C_DIM='' C_ACCENT=''
fi

info()    { printf "${C_BLUE}[cdin]${C_RESET} %s\n" "$*"; }
ok()      { printf "${C_GREEN}[cdin]${C_RESET} %s\n" "$*"; }
warn()    { printf "${C_YELLOW}[cdin]${C_RESET} %s\n" "$*"; }
die()     { printf "${C_RED}[cdin]${C_RESET} ERROR: %s\n" "$*" >&2; exit 1; }
dim()     { printf "${C_DIM}%s${C_RESET}\n" "$*"; }
banner()  { printf "\n${C_ACCENT}${C_BOLD}%s${C_RESET}\n" "$*"; }

REPO="m-mdy-m/cdin"
GITHUB_API="https://api.github.com/repos/${REPO}"
GITHUB_RELEASES="${GITHUB_API}/releases"

CHECK_ONLY=false
FORCE=false
TARGET_VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)         CHECK_ONLY=true ;;
    --force|-f)      FORCE=true ;;
    --version=*)     TARGET_VERSION="${1#*=}" ;;
    --version)       shift; TARGET_VERSION="${1:-}" ;;
    -h|--help)
      echo "Usage: cdin update [--check] [--force] [--version=X.Y.Z]"
      echo ""
      echo "Options:"
      echo "  --check "
      echo "  --force "
      echo "  --version=X "
      exit 0
      ;;
    update) ;; 
    *) warn "Unknown option: $1" ;;
  esac
  shift
done

for dep in curl tar; do
  command -v "$dep" &>/dev/null || die "$dep not found. Please install it."
done

CDIN_BIN="$(command -v cdin 2>/dev/null || true)"
if [[ -z "$CDIN_BIN" ]]; then
  for candidate in "$HOME/.local/bin/cdin" "/usr/local/bin/cdin" "/usr/bin/cdin"; do
    if [[ -x "$candidate" ]]; then
      CDIN_BIN="$candidate"
      break
    fi
  done
fi

if [[ -z "$CDIN_BIN" ]]; then
  die "cdin binary not found. Is it installed and in PATH?"
fi

CDIN_DIR="$(dirname "$CDIN_BIN")"

CURRENT_VERSION="$("$CDIN_BIN" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")"

info "Checking for updates..."

fetch_json() {
  curl -fsSL \
    -H "Accept: application/vnd.github.v3+json" \
    "${GITHUB_RELEASES}/${1:-latest}" 2>/dev/null
}

if [[ -n "$TARGET_VERSION" ]]; then
  RELEASE_JSON="$(fetch_json "tags/v${TARGET_VERSION#v}")"
else
  RELEASE_JSON="$(fetch_json latest)"
fi

if [[ -z "$RELEASE_JSON" ]] || echo "$RELEASE_JSON" | grep -q '"message": "Not Found"'; then
  die "Could not fetch release info from GitHub. Check your internet connection."
fi

LATEST_VERSION="$(echo "$RELEASE_JSON" | grep '"tag_name"' | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+[^"]*' | head -1)"
LATEST_VERSION="${LATEST_VERSION#v}" 

if [[ -z "$LATEST_VERSION" ]]; then
  die "Could not parse version from GitHub response."
fi

banner "cdin updater"
dim "  Current:  v${CURRENT_VERSION}"
dim "  Latest:   v${LATEST_VERSION}"
echo ""

version_gt() {
  # a > b → true
  [[ "$1" != "$2" ]] && [[ "$(printf '%s\n' "$1" "$2" | sort -V | tail -1)" == "$1" ]]
}

if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
  ok "Already up to date (v${LATEST_VERSION})"
  exit 0
fi

if ! version_gt "$LATEST_VERSION" "$CURRENT_VERSION" && [[ -z "$TARGET_VERSION" ]]; then
  ok "Already up to date (v${LATEST_VERSION})"
  exit 0
fi

if $CHECK_ONLY; then
  info "Update available: v${CURRENT_VERSION} → v${LATEST_VERSION}"
  info "Run 'cdin update' to install."
  exit 0
fi

info "Update available: v${CURRENT_VERSION} → v${LATEST_VERSION}"

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Linux)
    case "$ARCH" in
      x86_64)   ASSET_PATTERN="linux.*x86_64\|linux.*amd64\|linux-x64" ;;
      aarch64)  ASSET_PATTERN="linux.*aarch64\|linux.*arm64" ;;
      *)        die "Unsupported architecture: $ARCH" ;;
    esac
    ;;
  Darwin)
    case "$ARCH" in
      x86_64)   ASSET_PATTERN="macos.*x86_64\|darwin.*x64\|macos-x64" ;;
      arm64)    ASSET_PATTERN="macos.*arm64\|darwin.*arm64\|macos-arm64" ;;
      *)        die "Unsupported architecture: $ARCH" ;;
    esac
    ;;
  *)
    die "Unsupported OS: $OS. For Windows, use PowerShell: scripts/install.ps1"
    ;;
esac

ASSET_URL="$(echo "$RELEASE_JSON" \
  | grep '"browser_download_url"' \
  | grep -iE "$ASSET_PATTERN" \
  | grep -v '\.sha256\|\.sig\|checksum' \
  | grep -oE 'https://[^"]+' \
  | head -1)"

if [[ -z "$ASSET_URL" ]]; then
  TARBALL_URL="$(echo "$RELEASE_JSON" \
    | grep '"tarball_url"' \
    | grep -oE 'https://[^"]+' \
    | head -1)"

  if [[ -z "$TARBALL_URL" ]]; then
    die "No suitable release asset found for ${OS}/${ARCH}."
  fi

  warn "No prebuilt binary found. Will build from source."
  BUILD_FROM_SOURCE=true
  ASSET_URL="$TARBALL_URL"
else
  BUILD_FROM_SOURCE=false
fi

dim "  Asset: ${ASSET_URL}"

if ! $FORCE; then
  printf "\n${C_YELLOW}Install v${LATEST_VERSION}? [y/N]${C_RESET} "
  read -r CONFIRM
  [[ "${CONFIRM,,}" == "y" || "${CONFIRM,,}" == "yes" ]] || { info "Cancelled."; exit 0; }
fi

TMPDIR_UPDATE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_UPDATE"' EXIT

ASSET_FILE="${TMPDIR_UPDATE}/cdin-update"
if [[ "$ASSET_URL" == *.tar.gz ]]; then
  ASSET_FILE="${ASSET_FILE}.tar.gz"
elif [[ "$ASSET_URL" == *.zip ]]; then
  ASSET_FILE="${ASSET_FILE}.zip"
fi

info "Downloading v${LATEST_VERSION}..."
curl -fL --progress-bar -o "$ASSET_FILE" "$ASSET_URL"

info "Installing..."

if $BUILD_FROM_SOURCE; then
  # build از source
  SRC_DIR="${TMPDIR_UPDATE}/src"
  mkdir -p "$SRC_DIR"
  tar -xzf "$ASSET_FILE" -C "$SRC_DIR" --strip-components=1

  cd "$SRC_DIR"
  if [[ ! -f "Makefile" ]]; then
    die "Makefile not found in source. Cannot build."
  fi

  command -v make &>/dev/null || die "make not found. Cannot build from source."
  command -v gcc &>/dev/null || command -v cc &>/dev/null || die "C compiler not found."

  info "Building from source (this may take a moment)..."
  make -j"$(nproc 2>/dev/null || echo 2)"

  NEW_BIN="$(find build -name "cdin" -type f 2>/dev/null | head -1)"
  [[ -n "$NEW_BIN" ]] || NEW_BIN="$(find . -maxdepth 2 -name "cdin" -type f | head -1)"
  [[ -n "$NEW_BIN" ]] || die "Build succeeded but cdin binary not found."

  install -m 755 "$NEW_BIN" "$CDIN_BIN"

  # data files
  if [[ -d "data" ]]; then
    cp -r data/. "$(dirname "$CDIN_BIN")/data/"
    ok "Updated data files"
  fi

else
  # binary prebuilt
  if [[ "$ASSET_FILE" == *.tar.gz ]]; then
    EXTRACT_DIR="${TMPDIR_UPDATE}/extracted"
    mkdir -p "$EXTRACT_DIR"
    tar -xzf "$ASSET_FILE" -C "$EXTRACT_DIR"

    NEW_BIN="$(find "$EXTRACT_DIR" -name "cdin" -type f | head -1)"
    [[ -n "$NEW_BIN" ]] || die "cdin binary not found in archive."

    install -m 755 "$NEW_BIN" "$CDIN_BIN"

    # data files
    DATA_SRC="$(find "$EXTRACT_DIR" -name "data" -type d | head -1)"
    if [[ -n "$DATA_SRC" ]]; then
      DATA_DEST="$(dirname "$CDIN_BIN")/data"
      mkdir -p "$DATA_DEST"
      cp -r "$DATA_SRC"/. "$DATA_DEST/"
      ok "Updated data files"
    fi

  elif [[ "$ASSET_FILE" == *.zip ]]; then
    command -v unzip &>/dev/null || die "unzip not found."
    EXTRACT_DIR="${TMPDIR_UPDATE}/extracted"
    mkdir -p "$EXTRACT_DIR"
    unzip -q "$ASSET_FILE" -d "$EXTRACT_DIR"

    NEW_BIN="$(find "$EXTRACT_DIR" -name "cdin" -type f | head -1)"
    [[ -n "$NEW_BIN" ]] || die "cdin binary not found in archive."

    install -m 755 "$NEW_BIN" "$CDIN_BIN"
  else
    # مستقیم binary
    install -m 755 "$ASSET_FILE" "$CDIN_BIN"
  fi
fi

NEW_INSTALLED="$("$CDIN_BIN" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")"

echo ""
ok "Updated: v${CURRENT_VERSION} → v${NEW_INSTALLED}"
dim "  Binary: ${CDIN_BIN}"
echo ""
dim "Restart cdin to use the new version."