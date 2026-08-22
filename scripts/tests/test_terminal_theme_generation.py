#!/usr/bin/env python3
"""Verifica que los temas terminales se generan fuera del checkout."""

from __future__ import annotations

import os
from pathlib import Path
import re
import subprocess
import tempfile
import tomllib


ROOT = Path(__file__).resolve().parents[2]
NOCTALIA_CONFIG = ROOT / "noctalia/.config/noctalia/config.toml"
STARSHIP_BASE = ROOT / "starship/.config/starship.toml"
STARSHIP_TEMPLATE = ROOT / "noctalia/.config/noctalia/templates/project-atlas-starship.toml"
BAT_TEMPLATE = ROOT / "noctalia/.config/noctalia/templates/project-atlas.tmTheme"
MICRO_TEMPLATE = ROOT / "noctalia/.config/noctalia/templates/project-atlas.micro"
LEGACY_THEME_MODULES = ("gtk", "kitty", "kvantum", "micro")
LEGACY_THEME_REFERENCES = (
    ROOT / "docs/reference/legacy-kitty.conf",
    ROOT / "docs/reference/legacy-kvantum.kvconfig",
)


def render(template: Path) -> str:
    """Sustituye los tokens de Noctalia para validar el artefacto resultante."""
    return re.sub(r"{{colors\.[^}]+}}", "#123456", template.read_text(encoding="utf-8"))


def run(*args: str, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, env=env, check=True, text=True, capture_output=True)


def main() -> None:
    with NOCTALIA_CONFIG.open("rb") as source:
        templates = tomllib.load(source)["theme"]["templates"]
    assert {"gtk3", "gtk4"} <= set(templates["builtin_ids"])
    assert "starship" not in templates["builtin_ids"]
    starship = templates["user"]["starship"]
    assert starship["input_path"].endswith("project-atlas-starship.toml")
    assert starship["output_path"] == "$XDG_CONFIG_HOME/noctalia/generated/starship.toml"
    micro = templates["user"]["micro"]
    assert micro["input_path"].endswith("project-atlas.micro")
    assert micro["output_path"] == "$XDG_CONFIG_HOME/micro/colorschemes/project-atlas.micro"
    assert micro["post_hook"].endswith("project-atlas-theme-settings micro")
    for module in LEGACY_THEME_MODULES:
        assert not any(
            path.is_file() or path.is_symlink()
            for path in (ROOT / module).rglob("*")
        )
    assert all(reference.is_file() for reference in LEGACY_THEME_REFERENCES)

    base = tomllib.loads(STARSHIP_BASE.read_text(encoding="utf-8"))
    assert base["palette"] == "project_atlas"
    assert "project_atlas" in base["palettes"]
    assert "NOCTALIA STARSHIP PALETTE" not in STARSHIP_BASE.read_text(encoding="utf-8")

    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        config_home = root / "config"
        cache_home = root / "cache"
        generated_starship = config_home / "noctalia/generated/starship.toml"
        generated_bat = config_home / "bat/themes/project-atlas.tmTheme"
        generated_micro = config_home / "micro/colorschemes/project-atlas.micro"
        generated_starship.parent.mkdir(parents=True)
        generated_bat.parent.mkdir(parents=True)
        generated_micro.parent.mkdir(parents=True)
        generated_starship.write_text(render(STARSHIP_TEMPLATE), encoding="utf-8")
        generated_bat.write_text(render(BAT_TEMPLATE), encoding="utf-8")
        generated_micro.write_text(render(MICRO_TEMPLATE), encoding="utf-8")
        (config_home / "bat/config").write_text(
            (ROOT / "shell/.config/bat/config").read_text(encoding="utf-8"),
            encoding="utf-8",
        )

        assert ROOT not in generated_starship.parents
        assert ROOT not in generated_bat.parents
        assert ROOT not in generated_micro.parents
        rendered = tomllib.loads(generated_starship.read_text(encoding="utf-8"))
        assert rendered["palette"] == "noctalia"
        assert "noctalia" in rendered["palettes"]
        assert "color-link default" in generated_micro.read_text(encoding="utf-8")

        env = os.environ | {
            "XDG_CONFIG_HOME": str(config_home),
            "XDG_CACHE_HOME": str(cache_home),
            "STARSHIP_CONFIG": str(generated_starship),
            "BAT_THEME": "project-atlas",
        }
        run("starship", "prompt", env=env)
        run("bat", "cache", "--build", env=env)
        themes = run("bat", "--list-themes", env=env).stdout
        assert "project-atlas" in themes
        preview = run("bat", "--paging=never", "--style=plain", str(STARSHIP_BASE), env=env)
        assert "palette = \"project_atlas\"" in preview.stdout

    assert (ROOT / "shell/.config/bat/config").read_text(encoding="utf-8") == '--theme="project-atlas"\n'
    for shell in ("fish/.config/fish/config.fish", "shell/.bashrc", "shell/.zshrc"):
        content = (ROOT / shell).read_text(encoding="utf-8")
        assert "noctalia/generated/starship.toml" in content
        assert "BAT_THEME" in content
    assert "syntax-theme = project-atlas" in (ROOT / "git/.gitconfig").read_text(encoding="utf-8")


if __name__ == "__main__":
    main()
