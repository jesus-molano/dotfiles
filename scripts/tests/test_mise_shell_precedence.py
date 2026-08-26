#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def assert_after(path: str, activation: str, path_changes: tuple[str, ...]) -> None:
    content = (ROOT / path).read_text(encoding="utf-8")
    assert content.count(activation) == 1
    activation_offset = content.index(activation)
    for path_change in path_changes:
        assert path_change in content
        assert activation_offset > content.index(path_change)
    assert "activate_aggressive" not in content


assert_after(
    "fish/.config/fish/config.fish",
    "mise activate fish",
    (
        'fish_add_path -g "$PNPM_HOME"',
        'fish_add_path -g "$ANDROID_HOME/platform-tools"',
        'fish_add_path -g "$HOME/.local/bin"',
    ),
)
assert_after(
    "shell/.bashrc",
    "mise activate bash",
    (
        'export PATH="$PNPM_HOME:$PATH"',
        'export PATH="$HOME/.local/bin:$PATH"',
    ),
)
assert_after(
    "shell/.zshrc",
    "mise activate zsh",
    (
        'export PATH="$PNPM_HOME:$PATH"',
        'export PATH="$HOME/.local/bin:$PATH"',
    ),
)

print("PASS: mise se activa después de los cambios explícitos de PATH")
