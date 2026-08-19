#!/usr/bin/env python3
"""Static contract tests for the keyboard-first qutebrowser profile."""

from __future__ import annotations

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CONFIG = REPO_ROOT / "qutebrowser/.config/qutebrowser/config.py"


def require(source: str, fragment: str) -> None:
    if fragment not in source:
        raise SystemExit(f"FAIL: falta {fragment!r} en {CONFIG}")


def main() -> None:
    source = CONFIG.read_text(encoding="utf-8")

    for fragment in (
        "config.load_autoconfig()",
        '"mdn":',
        '"ghc":',
        '"archpkg":',
        '"pypi":',
        'config.bind(",t", "cmd-set-text -s :tab-focus ")',
        'config.bind(",s", "cmd-set-text -s :session-save ")',
        'config.bind(",y", "yank inline [{title}]({url:yank})")',
        'config.bind(";m", "hint links userscript yank-markdown-link")',
        'config.bind(",i", "devtools right")',
        'c.downloads.location.suggestion = "both"',
    ):
        require(source, fragment)

    print("PASS: qutebrowser conserva el líder coma y los flujos técnicos")


if __name__ == "__main__":
    main()
