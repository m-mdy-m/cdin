from __future__ import annotations

import io
import os
import sys

def _ensure_utf8() -> None:
    for attr in ("stdout", "stderr"):
        stream = getattr(sys, attr)
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8", errors="replace")
            except Exception:
                pass
        elif hasattr(stream, "buffer"):
            try:
                setattr(sys, attr,
                        io.TextIOWrapper(stream.buffer,
                                         encoding="utf-8",
                                         errors="replace",
                                         line_buffering=stream.line_buffering))
            except Exception:
                pass

_ensure_utf8()


def _supports_color() -> bool:
    if os.environ.get("NO_COLOR"):
        return False
    if sys.platform == "win32":
        try:
            import ctypes
            kernel32 = ctypes.windll.kernel32
            kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)
            return True
        except Exception:
            return False
    return hasattr(sys.stdout, "isatty") and sys.stdout.isatty()


_COLOR = _supports_color()


def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _COLOR else text

def info(msg: str)   -> None: print(_c("1;34", "[cdin]") + f" {msg}")
def ok(msg: str)     -> None: print(_c("1;32", "[cdin]") + f" {msg}")
def warn(msg: str)   -> None: print(_c("1;33", "[cdin]") + f" {msg}")
def err(msg: str)    -> None: print(_c("1;31", "[cdin]") + f" ERROR: {msg}", file=sys.stderr)
def dim(msg: str)    -> None: print(_c("2",    msg))
def banner(msg: str) -> None: print("\n" + _c("1;35", f"  ══  {msg}  ══") + "\n")
def sep()            -> None: print(_c("2", "  " + "─" * 46))


def die(msg: str, code: int = 1) -> None:
    err(msg)
    sys.exit(code)

def prompt_yn(question: str, default: bool = True) -> bool:
    hint = "[Y/n]" if default else "[y/N]"
    try:
        ans = input(f"\n  {_c('1;33', '?')} {question} {hint}: ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        print()
        sys.exit(0)
    if ans == "":
        return default
    return ans in ("y", "yes")


def prompt_str(question: str, default: str = "") -> str:
    hint = f"[{default}]" if default else ""
    try:
        ans = input(f"  {_c('1;33', '?')} {question} {hint}: ").strip()
    except (EOFError, KeyboardInterrupt):
        print()
        sys.exit(0)
    return ans if ans else default


def prompt_choice(question: str, choices: list[tuple[str, str]]) -> str:
    """
    Display a numbered menu and return the chosen key.
    choices = [("key", "description"), ...]
    """
    print(f"\n  {_c('1;36', question)}")
    for i, (key, desc) in enumerate(choices, 1):
        print(f"    {_c('1;33', str(i))}) {desc}")
    print()
    while True:
        try:
            raw = input(f"  {_c('1;33', '>')} Enter number: ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            sys.exit(0)
        if raw.isdigit():
            idx = int(raw) - 1
            if 0 <= idx < len(choices):
                return choices[idx][0]
        warn(f"Please enter a number between 1 and {len(choices)}.")