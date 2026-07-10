from __future__ import annotations

import argparse

from .ui import banner, die
from .build import cmd_build
from .install import cmd_install
from .utils import find_binary_candidate


def cmd_build_install(args: argparse.Namespace) -> None:
    banner("BUILD + INSTALL")
    cmd_build(args)

    build_type = "debug" if getattr(args, "debug", False) else "release"
    binary = find_binary_candidate(build_type)
    if not binary:
        die("Build output not found after build step.")

    args.binary = str(binary)
    cmd_install(args)