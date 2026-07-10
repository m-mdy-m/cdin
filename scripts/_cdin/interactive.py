from __future__ import annotations

import argparse

from ._constants import ROOT_DIR
from .platform import PLATFORM, default_prefix, default_jobs
from .ui import banner, sep, _c
from .ui import prompt_choice, prompt_str, prompt_yn
from .build import cmd_build
from .install import cmd_install
from .uninstall import cmd_uninstall
from .update import cmd_update


def interactive() -> None:
    banner("cdin build tool")
    print(f"  Platform: {_c('1;36', PLATFORM)}   Root: {_c('2', str(ROOT_DIR))}\n")

    action = prompt_choice("What do you want to do?", [
        ("build",         "Build cdin from source"),
        ("install",       "Install an already-built binary"),
        ("build-install", "Build + Install in one step"),
        ("update",        "Update cdin to the latest release"),
        ("uninstall",     "Uninstall cdin"),
    ])

    sep()

    args = argparse.Namespace(
        debug=False,
        jobs=default_jobs(),
        prefix=None,
        binary=None,
        shortcut=False,
        register_filetypes=False,
        check=False,
        force=False,
        version=None,
    )

    if action in ("build", "build-install"):
        build_choice = prompt_choice("Build type?", [
            ("release", "Release — optimised, smaller binary"),
            ("debug",   "Debug   — with symbols and assertions"),
        ])
        args.debug = (build_choice == "debug")

        jobs_str = prompt_str("Parallel jobs?", default=str(default_jobs()))
        try:
            args.jobs = int(jobs_str)
        except ValueError:
            args.jobs = default_jobs()

    if action in ("build", "install", "build-install", "uninstall"):
        prefix_str = prompt_str("Installation prefix?", default=str(default_prefix()))
        args.prefix = prefix_str

    if action == "install":
        binary_str = prompt_str("Path to cdin binary? (leave blank to auto-detect)", default="")
        if binary_str:
            args.binary = binary_str

    if action in ("install", "build-install"):
        if PLATFORM in ("linux", "macos", "windows"):
            args.shortcut = prompt_yn("Create desktop shortcut / launcher?", default=True)
        if PLATFORM == "windows":
            args.register_filetypes = prompt_yn(
                "Register cdin as handler for text/code files?", default=False)

    if action == "update":
        ver_str = prompt_str("Target version? (leave blank for latest)", default="")
        if ver_str:
            args.version = ver_str
        args.force = prompt_yn("Skip confirmation prompt?", default=False)

    sep()

    dispatch = {
        "build":         cmd_build,
        "install":       cmd_install,
        "build-install": _cmd_build_install,
        "update":        cmd_update,
        "uninstall":     cmd_uninstall,
    }
    dispatch[action](args)


def _cmd_build_install(args: argparse.Namespace) -> None:
    """Thin wrapper so interactive.py doesn't need to import from build_install."""
    from .build_install import cmd_build_install
    cmd_build_install(args)