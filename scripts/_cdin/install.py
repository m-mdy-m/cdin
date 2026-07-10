from __future__ import annotations

import argparse
import os
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Optional

from ._constants import ROOT_DIR, SCRIPT_DIR, ICON_SVG, ICON_ICO, GEN_ICON_PY
from .platform import PLATFORM, EXE_NAME, default_prefix
from .ui import banner, info, ok, warn, die
from .utils import find_binary_candidate, find_icons_src, install_binary, install_data

def cmd_install(args: argparse.Namespace) -> None:
    banner("INSTALL")

    build_type = "debug" if getattr(args, "debug", False) else "release"
    prefix     = Path(getattr(args, "prefix", None) or default_prefix())
    binary_arg = getattr(args, "binary", None)
    shortcut   = getattr(args, "shortcut", False)
    reg_ft     = getattr(args, "register_filetypes", False)

    binary = Path(binary_arg) if binary_arg else find_binary_candidate(build_type)
    if not binary or not binary.is_file():
        die("Binary not found. Run 'build' first, or pass --binary PATH.")

    info(f"Binary     : {binary}")
    info(f"Prefix     : {prefix}")

    bin_dir = prefix / "bin"
    install_binary(binary, bin_dir / EXE_NAME)
    install_data(bin_dir)
    if PLATFORM == "linux":
        _install_linux_extras(prefix, bin_dir, shortcut)
    elif PLATFORM == "macos":
        _install_macos_extras(binary, prefix, bin_dir, shortcut)
    elif PLATFORM == "windows":
        _install_windows_extras(bin_dir / EXE_NAME, prefix, bin_dir, shortcut, reg_ft)
    else:
        _path_hint(bin_dir)

    ok("Installation complete!")

def _install_linux_extras(prefix: Path, bin_dir: Path, shortcut: bool) -> None:
    _install_icons_linux(prefix)
    if shortcut:
        _install_desktop_linux(prefix, bin_dir)
    _path_hint(bin_dir)


def _install_icons_linux(prefix: Path) -> None:
    hicolor   = prefix / "share" / "icons" / "hicolor"
    icons_src = find_icons_src()
    installed = 0

    if icons_src:
        for sz in (16, 22, 24, 32, 48, 64, 128, 256, 512):
            png = icons_src / f"cdin-{sz}.png"
            if png.is_file():
                dest = hicolor / f"{sz}x{sz}" / "apps"
                dest.mkdir(parents=True, exist_ok=True)
                shutil.copy2(png, dest / "cdin.png")
                installed += 1
    elif ICON_SVG.is_file():
        converter = shutil.which("rsvg-convert") or shutil.which("convert")
        if converter:
            tool = "rsvg" if "rsvg" in converter else "convert"
            for sz in (16, 22, 24, 32, 48, 64, 128, 256):
                tmp = Path(tempfile.mktemp(suffix=".png"))
                try:
                    cmd = (
                        [converter, "-w", str(sz), "-h", str(sz), str(ICON_SVG), "-o", str(tmp)]
                        if tool == "rsvg" else
                        [converter, "-background", "none", str(ICON_SVG), "-resize", f"{sz}x{sz}", str(tmp)]
                    )
                    subprocess.run(cmd, check=False)
                    if tmp.is_file():
                        dest = hicolor / f"{sz}x{sz}" / "apps"
                        dest.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(tmp, dest / "cdin.png")
                        installed += 1
                finally:
                    tmp.unlink(missing_ok=True)

    if ICON_SVG.is_file():
        scalable = hicolor / "scalable" / "apps"
        scalable.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ICON_SVG, scalable / "cdin.svg")

    if installed > 0:
        ok(f"Installed {installed} icons → {hicolor}")
        for tool in ("gtk-update-icon-cache", "update-icon-caches"):
            if shutil.which(tool):
                subprocess.run([tool, "-f", "-t", str(hicolor)], capture_output=True, check=False)
                break


def _install_desktop_linux(prefix: Path, bin_dir: Path) -> None:
    desktop_dir = prefix / "share" / "applications"
    desktop_dir.mkdir(parents=True, exist_ok=True)
    desktop_file = desktop_dir / "cdin.desktop"

    scalable_icon = prefix / "share" / "icons" / "hicolor" / "scalable" / "apps" / "cdin.svg"
    icon_ref = "cdin" if scalable_icon.is_file() else "text-editor"

    desktop_file.write_text(f"""[Desktop Entry]
Version=1.0
Type=Application
Name=cdin
Comment=Lightweight code editor
Exec={bin_dir}/cdin %F
Icon={icon_ref}
Terminal=false
Categories=Development;TextEditor;
MimeType=text/plain;text/x-csrc;text/x-chdr;text/x-lua;
StartupNotify=true
StartupWMClass=cdin
""", encoding="utf-8")
    ok(f"Desktop entry    → {desktop_file}")

    if shutil.which("update-desktop-database"):
        subprocess.run(["update-desktop-database", str(desktop_dir)], capture_output=True, check=False)

def _install_macos_extras(binary: Path, prefix: Path, bin_dir: Path, shortcut: bool) -> None:
    if shortcut:
        _install_app_macos(binary)
    _path_hint(bin_dir)


def _install_app_macos(binary: Path) -> None:
    """Create a minimal .app bundle in /Applications."""
    from .utils import find_data_dir, copytree_force

    app_dir = Path("/Applications/cdin.app")
    mac_dir = app_dir / "Contents" / "MacOS"
    res_dir = app_dir / "Contents" / "Resources"
    mac_dir.mkdir(parents=True, exist_ok=True)
    res_dir.mkdir(parents=True, exist_ok=True)

    install_binary(binary, mac_dir / "cdin")

    src_data = find_data_dir()
    if src_data:
        copytree_force(src_data, res_dir / "data")

    (app_dir / "Contents" / "Info.plist").write_text("""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>             <string>cdin</string>
  <key>CFBundleDisplayName</key>      <string>cdin</string>
  <key>CFBundleIdentifier</key>       <string>com.cdin.editor</string>
  <key>CFBundleVersion</key>          <string>1.0</string>
  <key>CFBundleExecutable</key>       <string>cdin</string>
  <key>CFBundlePackageType</key>      <string>APPL</string>
  <key>LSMinimumSystemVersion</key>   <string>10.13</string>
  <key>NSHighResolutionCapable</key>  <true/>
</dict>
</plist>
""", encoding="utf-8")
    ok(f"App bundle       → {app_dir}")

def _install_windows_extras(
    dest_exe: Path, prefix: Path, bin_dir: Path, shortcut: bool, reg_ft: bool
) -> None:
    _install_dlls_windows(dest_exe.parent, bin_dir)
    _add_to_path_windows(bin_dir)
    if shortcut:
        ico_path = _install_icon_windows(prefix)
        _create_shortcuts_windows(dest_exe, ico_path)
    if reg_ft:
        _register_filetypes_windows(dest_exe)


def _install_dlls_windows(binary_src_dir: Path, bin_dir: Path) -> None:
    """Copy SDL3.dll and lua*.dll from the binary's dir, MinGW paths, or PATH."""
    search_dirs: list[Path] = [binary_src_dir]
    for mingw in ("C:/msys64/mingw64/bin", "C:/msys64/ucrt64/bin", "C:/mingw64/bin", "C:/mingw/bin"):
        p = Path(mingw)
        if p.is_dir():
            search_dirs.append(p)
    for d in os.environ.get("PATH", "").split(os.pathsep):
        if d:
            search_dirs.append(Path(d))

    def find_dll(names: list[str]) -> Optional[Path]:
        for name in names:
            for d in search_dirs:
                candidate = d / name
                if candidate.is_file():
                    return candidate
        return None

    sdl = find_dll(["SDL3.dll"])
    if sdl:
        shutil.copy2(sdl, bin_dir / "SDL3.dll")
        ok(f"Installed SDL3.dll → {bin_dir}")
    else:
        warn("SDL3.dll not found — copy it manually to " + str(bin_dir))

    lua = find_dll(["lua55.dll", "lua54.dll", "lua5.4.dll", "lua53.dll", "lua5.3.dll", "lua.dll"])
    if lua:
        shutil.copy2(lua, bin_dir / lua.name)
        ok(f"Installed {lua.name} → {bin_dir}")
    else:
        warn("Lua DLL not found — copy it manually to " + str(bin_dir))


def _add_to_path_windows(bin_dir: Path) -> None:
    try:
        import winreg
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Environment", 0, winreg.KEY_ALL_ACCESS)
        try:
            cur, _ = winreg.QueryValueEx(key, "PATH")
        except FileNotFoundError:
            cur = ""
        if str(bin_dir) not in cur.split(";"):
            winreg.SetValueEx(key, "PATH", 0, winreg.REG_EXPAND_SZ,
                              f"{bin_dir};{cur}" if cur else str(bin_dir))
            ok(f"Added to user PATH: {bin_dir}")
            warn("Restart terminal for PATH to take effect.")
        else:
            info(f"{bin_dir} already in PATH.")
        winreg.CloseKey(key)
    except Exception as e:
        warn(f"Could not update PATH: {e}\n         Add manually: {bin_dir}")


def _install_icon_windows(prefix: Path) -> str:
    """Copy or generate cdin.ico; return path string (empty if unavailable)."""
    ico_dest = prefix / "cdin.ico"

    if ICON_ICO.is_file():
        shutil.copy2(ICON_ICO, ico_dest)
        ok(f"Icon             → {ico_dest}  (pre-built)")
        return str(ico_dest)

    if ICON_SVG.is_file() and GEN_ICON_PY.is_file():
        try:
            subprocess.run(
                [sys.executable, str(GEN_ICON_PY), "--svg", str(ICON_SVG), "--out-ico", str(ico_dest)],
                capture_output=True, text=True,
            )
            if ico_dest.is_file():
                ok(f"Icon             → {ico_dest}  (generated)")
                return str(ico_dest)
        except Exception:
            pass

    warn("Icon not available — shortcut will use default icon.")
    return ""


def _create_shortcuts_windows(exe: Path, ico_path: str) -> None:
    shell = _com_shell()
    if not shell:
        warn("WScript.Shell unavailable — shortcuts skipped.")
        return

    try:
        desktop   = Path(os.environ.get("USERPROFILE", "~")).expanduser() / "Desktop"
        startmenu = (Path(os.environ.get("APPDATA", ""))
                     / "Microsoft" / "Windows" / "Start Menu" / "Programs")

        for lnk_dir in (desktop, startmenu):
            lnk_dir.mkdir(parents=True, exist_ok=True)
            lnk_path = lnk_dir / "cdin.lnk"
            lnk = shell.CreateShortcut(str(lnk_path))
            lnk.TargetPath       = str(exe)
            lnk.WorkingDirectory = str(exe.parent)
            lnk.Description      = "cdin – Lightweight Code Editor"
            if ico_path:
                lnk.IconLocation = ico_path
            lnk.Save()
            ok(f"Shortcut         → {lnk_path}")
    except Exception as e:
        warn(f"Could not create shortcuts: {e}")


def _com_shell():
    for lib in ("comtypes.client", "win32com.client"):
        try:
            import importlib
            m = importlib.import_module(lib)
            fn = getattr(m, "CreateObject" if lib == "comtypes.client" else "Dispatch")
            return fn("WScript.Shell")
        except Exception:
            pass
    return None


def _register_filetypes_windows(exe: Path) -> None:
    EXTENSIONS = [
        ".txt", ".log", ".ini", ".cfg", ".conf",
        ".html", ".htm", ".css", ".js", ".ts", ".jsx", ".tsx",
        ".json", ".xml", ".yaml", ".yml",
        ".c", ".h", ".cpp", ".hpp", ".cs", ".rs", ".go",
        ".py", ".rb", ".sh", ".bat", ".ps1", ".lua",
        ".md", ".toml", ".sql", ".env", ".gitignore",
    ]
    try:
        import winreg
        root    = r"Software\Classes"
        prog_id = "cdin"
        base    = winreg.HKEY_CURRENT_USER

        for sub, val in [
            (f"{root}\\{prog_id}", "cdin Document"),
            (f"{root}\\{prog_id}\\shell\\open\\command", f'"{exe}" "%1"'),
        ]:
            k = winreg.CreateKey(base, sub)
            winreg.SetValue(k, "", winreg.REG_SZ, val)
            winreg.CloseKey(k)

        for ext in EXTENSIONS:
            k = winreg.CreateKey(base, f"{root}\\{ext}")
            winreg.SetValueEx(k, "", 0, winreg.REG_SZ, prog_id)
            winreg.CloseKey(k)

        ok(f"Registered {len(EXTENSIONS)} file-type associations (HKCU)")
    except Exception as e:
        warn(f"Could not register file types: {e}")

def _path_hint(bin_dir: Path) -> None:
    path_env = os.environ.get("PATH", "")
    if str(bin_dir) not in path_env.split(os.pathsep):
        warn(f"{bin_dir} is not in your PATH.")
        print(f"\n  Add to ~/.bashrc or ~/.zshrc:")
        print(f'    export PATH="{bin_dir}:$PATH"')
        print(f"  Then: source ~/.bashrc\n")
    else:
        ok("cdin is in your PATH. Run: cdin")
