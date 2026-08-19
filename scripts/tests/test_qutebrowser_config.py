#!/usr/bin/env python3
"""Static contract tests for the keyboard-first qutebrowser profile."""

from __future__ import annotations

import ast
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CONFIG = REPO_ROOT / "qutebrowser/.config/qutebrowser/config.py"


def require(source: str, fragment: str) -> None:
    if fragment not in source:
        raise SystemExit(f"FAIL: falta {fragment!r} en {CONFIG}")


def load_palette_helper(source: str):
    """Load config's stdlib-only palette helpers without requiring qutebrowser."""
    tree = ast.parse(source, filename=str(CONFIG))
    nodes = []
    wanted = {"DEFAULT_PALETTE", "_is_hex_color", "_read_palette", "_load_palette"}
    for node in tree.body:
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            nodes.append(node)
        elif isinstance(node, (ast.Assign, ast.FunctionDef)) and getattr(node, "name", None) in wanted:
            nodes.append(node)
        elif isinstance(node, ast.Assign) and any(
            isinstance(target, ast.Name) and target.id == "DEFAULT_PALETTE" for target in node.targets
        ):
            nodes.append(node)

    namespace = {"__name__": "qutebrowser_palette_test"}
    exec(compile(ast.Module(body=nodes, type_ignores=[]), str(CONFIG), "exec"), namespace)
    return namespace["_load_palette"]


def write_palette(path: Path, primary: str, background: str) -> None:
    path.write_text(
        """{
  "dark": {
    "mPrimary": "%s",
    "mSurface": "#202122",
    "mSurfaceVariant": "#303132",
    "mHover": "#404142",
    "mOutline": "#505152",
    "mOnPrimary": "#fafafa",
    "mSecondary": "#606162",
    "mTertiary": "#707172",
    "mError": "#808182",
    "mOnSurfaceVariant": "#909192",
    "terminal": {
      "background": "%s",
      "foreground": "#f0f1f2",
      "normal": {"green": "#a0a1a2"}
    }
  }
}
"""
        % (primary, background),
        encoding="utf-8",
    )


def test_generated_palette_overrides_fallback(source: str) -> None:
    load_palette = load_palette_helper(source)
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        active = root / "active.json"
        fallback = root / "ProjectAtlas.json"
        write_palette(fallback, "#111111", "#121212")
        write_palette(active, "#abcdef", "#010203")

        palette = load_palette(active, fallback)
        if palette["primary"] != "#abcdef" or palette["background"] != "#010203":
            raise SystemExit("FAIL: la paleta activa no prevalece sobre el fallback")


def test_fallback_for_missing_or_invalid_active_palette(source: str) -> None:
    load_palette = load_palette_helper(source)
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        active = root / "active.json"
        fallback = root / "ProjectAtlas.json"
        write_palette(fallback, "#123456", "#101112")

        palette = load_palette(active, fallback)
        if palette["primary"] != "#123456":
            raise SystemExit("FAIL: no usa ProjectAtlas cuando falta la paleta activa")

        active.write_text("{ no es JSON", encoding="utf-8")
        palette = load_palette(active, fallback)
        if palette["background"] != "#101112":
            raise SystemExit("FAIL: no usa ProjectAtlas cuando la paleta activa es inválida")


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
        'config_dir / "generated/active-palette.json"',
        'config_dir / "palettes/ProjectAtlas.json"',
        'palette = _load_palette()',
    ):
        require(source, fragment)

    test_generated_palette_overrides_fallback(source)
    test_fallback_for_missing_or_invalid_active_palette(source)

    print("PASS: qutebrowser conserva sus flujos y carga una paleta segura al inicio")


if __name__ == "__main__":
    main()
