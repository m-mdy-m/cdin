from __future__ import annotations

import argparse
import json
import platform as _platform_mod
import re
import shutil
import subprocess
import tempfile
import urllib.request
from pathlib import Path
from typing import Optional

from ._constants import GITHUB_RELEASES
from .platform import PLATFORM, default_jobs
from .ui import banner, info, ok, warn, dim, die
from .ui import prompt_yn
from .utils import (
    current_installed_version, version_gt,
    find_installed_binary, install_binary,
    extract_archive, replace_binary_from_archive, copytree_force,
)

def cmd_update(args: argparse.Namespace) -> None:
    banner("UPDATE")

    check_only     = getattr(args, "check", False)
    force          = getattr(args, "force", False)
    target_version = getattr(args, "version", None)

    cdin_bin = find_installed_binary()
    if not cdin_bin:
        die("cdin binary not found. Is it installed?")

    current = current_installed_version(cdin_bin)
    info(f"Installed binary : {cdin_bin}")
    info(f"Current version  : v{current}")
    info("Checking for updates …")

    release = _fetch_release(target_version)
    latest  = release.get("tag_name", "").lstrip("v")
    if not latest:
        die("Could not parse version from GitHub response.")

    dim(f"  Latest available : v{latest}")
    print()

    if current == latest or (not version_gt(latest, current) and not target_version):
        ok(f"Already up to date (v{latest})")
        return

    info(f"Update available: v{current} → v{latest}")

    if check_only:
        info("Run without --check to install.")
        return

    if not force and not prompt_yn(f"Install v{latest}?"):
        info("Cancelled.")
        return

    asset_url, build_from_source = _resolve_asset(release)
    dim(f"  Asset: {asset_url}")

    with tempfile.TemporaryDirectory() as tmp:
        tmp_path   = Path(tmp)
        ext        = ".tar.gz" if asset_url.endswith(".tar.gz") else \
                     ".zip"    if asset_url.endswith(".zip")    else ".tar.gz"
        asset_file = tmp_path / f"cdin-update{ext}"

        info(f"Downloading v{latest} …")
        _download(asset_url, asset_file)

        info("Installing …")
        if build_from_source:
            _update_from_source(asset_file, tmp_path, cdin_bin)
        else:
            replace_binary_from_archive(asset_file, tmp_path, cdin_bin)

    new_ver = current_installed_version(cdin_bin)
    ok(f"Updated: v{current} → v{new_ver}")
    dim(f"  Binary: {cdin_bin}")
    print()
    dim("Restart cdin to use the new version.")

def _github_fetch(url: str) -> dict:
    req = urllib.request.Request(url, headers={
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "cdin-updater/1.0",
    })
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read().decode())
    except Exception as e:
        die(f"Network error: {e}\n         Check your internet connection.")


def _fetch_release(target_version: Optional[str]) -> dict:
    url = (f"{GITHUB_RELEASES}/tags/v{target_version.lstrip('v')}"
           if target_version else f"{GITHUB_RELEASES}/latest")
    release = _github_fetch(url)
    if "message" in release:
        die(f"GitHub: {release['message']}")
    return release

_ASSET_PATTERNS: dict[str, list[str]] = {
    "linux":   ["linux.*x86_64", "linux.*amd64", "linux-x64"],      # overridden for arm below
    "macos":   ["macos.*x86_64", "darwin.*x64", "macos-x64"],       # overridden for arm below
    "windows": ["windows.*x86_64", "windows.*amd64", "win.*x64", "win64"],
}

def _resolve_asset(release: dict) -> tuple[str, bool]:
    """Return (download_url, build_from_source)."""
    arch   = _platform_mod.machine().lower()
    assets = release.get("assets", [])

    patterns = list(_ASSET_PATTERNS.get(PLATFORM, []))
    if PLATFORM == "linux" and ("aarch64" in arch or "arm64" in arch):
        patterns = ["linux.*aarch64", "linux.*arm64"]
    elif PLATFORM == "macos" and arch == "arm64":
        patterns = ["macos.*arm64", "darwin.*arm64", "macos-arm64"]

    for asset in assets:
        name = asset.get("name", "").lower()
        url  = asset.get("browser_download_url", "")
        if any(re.search(p, name, re.I) for p in patterns):
            if not re.search(r"sha256|\.sig|checksum", name):
                return url, False

    # Fallback: source tarball
    tarball = release.get("tarball_url", "")
    if not tarball:
        die(f"No suitable release asset found for {PLATFORM}/{arch}.")
    warn("No prebuilt binary found — will build from source.")
    return tarball, True

def _download(url: str, dest: Path) -> None:
    def _progress(count, block, total):
        if total > 0:
            pct = min(100, int(count * block * 100 / total))
            bar = "█" * (pct // 2) + "░" * (50 - pct // 2)
            print(f"\r  [{bar}] {pct:3d}%", end="", flush=True)
    try:
        urllib.request.urlretrieve(url, dest, reporthook=_progress)
        print()
    except Exception as e:
        die(f"Download failed: {e}")

def _update_from_source(asset: Path, tmp: Path, cdin_bin: Path) -> None:
    src = tmp / "src"
    src.mkdir()
    extract_archive(asset, src)

    items    = list(src.iterdir())
    src_root = items[0] if len(items) == 1 and items[0].is_dir() else src

    make_cmd = shutil.which("make") or shutil.which("mingw32-make") or shutil.which("gmake")
    if not make_cmd:
        die("make not found — cannot build from source.")

    info("Building from source …")
    subprocess.run([make_cmd, f"-j{default_jobs()}"], cwd=src_root, check=True)

    new_bin = next(src_root.rglob("cdin"), None) or next(src_root.rglob("cdin.exe"), None)
    if not new_bin:
        die("Build succeeded but cdin binary not found.")

    install_binary(new_bin, cdin_bin)

    data_src = src_root / "data"
    if data_src.is_dir():
        data_dst = cdin_bin.parent / "data"
        data_dst.mkdir(exist_ok=True)
        copytree_force(data_src, data_dst)
        ok("Updated data files")
