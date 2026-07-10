#!/usr/bin/env python3
"""
Usage (flags):
    python3 scripts/cdin.py build [--debug] [--jobs N] [--prefix DIR]
    python3 scripts/cdin.py install [--prefix DIR] [--binary PATH] [--shortcut] [--register-filetypes]
    python3 scripts/cdin.py build-install [--debug] [--prefix DIR] [--shortcut]
    python3 scripts/cdin.py update [--check] [--force] [--version X.Y.Z]
    python3 scripts/cdin.py uninstall [--prefix DIR]
    python3 scripts/cdin.py --help
"""

from __future__ import annotations

import argparse
import sys
import textwrap

from _cdin.build         import cmd_build
from _cdin.build_install import cmd_build_install
from _cdin.install       import cmd_install
from _cdin.interactive   import interactive
from _cdin.platform      import default_prefix
from _cdin.uninstall     import cmd_uninstall
from _cdin.update        import cmd_update


DISPATCH = {
    "build":         cmd_build,
    "install":       cmd_install,
    "build-install": cmd_build_install,
    "update":        cmd_update,
    "uninstall":     cmd_uninstall,
}


# ─────────────────────────── CLI parser ───────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="cdin.py",
        description="cdin build / install / update tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
            Examples:
              python3 scripts/cdin.py                          # interactive mode
              python3 scripts/cdin.py build                    # release build
              python3 scripts/cdin.py build --debug --jobs 8
              python3 scripts/cdin.py install --shortcut
              python3 scripts/cdin.py build-install            # build + install
              python3 scripts/cdin.py update                   # update to latest
              python3 scripts/cdin.py update --check           # check only
              python3 scripts/cdin.py update --version 0.2.0
              python3 scripts/cdin.py uninstall
        """),
    )
    sub = p.add_subparsers(dest="command")

    # build
    b = sub.add_parser("build", help="Build cdin from source")
    b.add_argument("--debug",   action="store_true", help="Debug build (default: release)")
    b.add_argument("--release", action="store_true", help="Release build (default)")
    b.add_argument("--jobs", "-j", type=int, metavar="N", help="Parallel jobs (default: CPU count)")
    b.add_argument("--prefix", metavar="DIR", help="Installation prefix for Makefile variables")

    # install
    i = sub.add_parser("install", help="Install an already-built binary")
    i.add_argument("--prefix",   metavar="DIR", help=f"Install prefix (default: {default_prefix()})")
    i.add_argument("--binary",   metavar="PATH", help="Path to cdin binary (auto-detected if omitted)")
    i.add_argument("--shortcut", action="store_true",
                   help="Create desktop shortcut / .app / .desktop entry")
    i.add_argument("--register-filetypes", action="store_true",
                   help="(Windows) Register file-type associations")

    # build-install
    bi = sub.add_parser("build-install", help="Build from source, then install")
    bi.add_argument("--debug",   action="store_true")
    bi.add_argument("--release", action="store_true")
    bi.add_argument("--jobs", "-j", type=int, metavar="N")
    bi.add_argument("--prefix",  metavar="DIR")
    bi.add_argument("--shortcut", action="store_true")
    bi.add_argument("--register-filetypes", action="store_true")

    # update
    u = sub.add_parser("update", help="Update cdin to the latest release from GitHub")
    u.add_argument("--check",  action="store_true", help="Only check — do not install")
    u.add_argument("--force", "-f", action="store_true", help="Skip confirmation prompt")
    u.add_argument("--version", metavar="X.Y.Z", help="Install a specific version")

    # uninstall
    un = sub.add_parser("uninstall", help="Remove a cdin installation")
    un.add_argument("--prefix", metavar="DIR")

    return p


# ─────────────────────────── entry point ──────────────────────────────────────

def main() -> None:
    parser = build_parser()
    args   = parser.parse_args()

    if args.command is None:
        interactive()
        return

    DISPATCH[args.command](args)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nInterrupted.")
        sys.exit(130)