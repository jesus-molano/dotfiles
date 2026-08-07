#!/usr/bin/env python3
"""Sincroniza preferencias duraderas de Codex sin tocar hooks ni MCP ajenos."""

from __future__ import annotations

import argparse
import os
import re
import shutil
import sys
import tempfile
import time
from pathlib import Path

import tomllib

DESIRED_TOP = {
    "model": '"gpt-5.6-sol"',
    "model_reasoning_effort": '"medium"',
    "approval_policy": '"on-request"',
    "approvals_reviewer": '"user"',
    "sandbox_mode": '"workspace-write"',
    "notify": '["codex-notify"]',
}
DESIRED_SECTIONS = {
    "features": {
        "hooks": "true",
        "memories": "true",
    },
    "sandbox_workspace_write": {
        "network_access": "false",
    },
    "agents": {
        "enabled": "true",
        "max_concurrent_threads_per_session": "3",
        "default_subagent_model": '"gpt-5.6-terra"',
        "default_subagent_reasoning_effort": '"medium"',
    },
    "tui": {
        "status_line": '["model-with-reasoning", "context-remaining", "git-branch", "current-dir"]',
        "notifications": '["agent-turn-complete", "approval-requested"]',
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="comprueba sin escribir")
    mode.add_argument(
        "--apply", action="store_true", help="aplica con backup y confirmación"
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
        / "config.toml",
        help="config.toml exacto que se comprobará",
    )
    return parser.parse_args()


def section_bounds(lines: list[str], name: str | None) -> tuple[int, int] | None:
    table = re.compile(
        r"^\s*(?:\[\[([^\[\]]+)\]\]|\[([^\[\]]+)\])\s*(?:#.*)?$"
    )
    starts = [
        (index, match.group(1) or match.group(2), match.group(1) is not None)
        for index, line in enumerate(lines)
        if (match := table.match(line))
    ]
    if name is None:
        return 0, starts[0][0] if starts else len(lines)
    for position, (start, found_name, is_array) in enumerate(starts):
        if found_name == name and not is_array:
            end = starts[position + 1][0] if position + 1 < len(starts) else len(lines)
            return start + 1, end
    return None


def set_key(lines: list[str], section: str | None, key: str, value: str) -> None:
    bounds = section_bounds(lines, section)
    if bounds is None:
        if lines and lines[-1].strip():
            lines.append("\n")
        lines.extend([f"[{section}]\n", f"{key} = {value}\n"])
        return

    start, end = bounds
    pattern = re.compile(rf"^\s*{re.escape(key)}\s*=")
    matches = [index for index in range(start, end) if pattern.match(lines[index])]
    if len(matches) > 1:
        raise ValueError(f"clave duplicada: {section + '.' if section else ''}{key}")
    if matches:
        lines[matches[0]] = f"{key} = {value}\n"
        return

    insertion = end
    while insertion > start and not lines[insertion - 1].strip():
        insertion -= 1
    lines.insert(insertion, f"{key} = {value}\n")


def render(original: str) -> str:
    lines = original.splitlines(keepends=True)
    if original and not original.endswith("\n"):
        lines[-1] += "\n"
    for key, value in DESIRED_TOP.items():
        set_key(lines, None, key, value)
    for section, values in DESIRED_SECTIONS.items():
        for key, value in values.items():
            set_key(lines, section, key, value)
    rendered = "".join(lines)
    document = tomllib.loads(rendered)
    if not desired_state(document):
        raise ValueError("la configuración renderizada no contiene la política gestionada")
    return rendered


def desired_state(document: dict) -> bool:
    return (
        document.get("model") == "gpt-5.6-sol"
        and document.get("model_reasoning_effort") == "medium"
        and document.get("approval_policy") == "on-request"
        and document.get("approvals_reviewer") == "user"
        and document.get("sandbox_mode") == "workspace-write"
        and document.get("notify") == ["codex-notify"]
        and document.get("sandbox_workspace_write", {}).get("network_access") is False
        and document.get("features", {}).get("hooks") is True
        and document.get("features", {}).get("memories") is True
        and document.get("agents", {}).get("enabled") is True
        and document.get("agents", {}).get("max_concurrent_threads_per_session") == 3
        and document.get("agents", {}).get("default_subagent_model") == "gpt-5.6-terra"
        and document.get("agents", {}).get("default_subagent_reasoning_effort")
        == "medium"
        and document.get("tui", {}).get("notifications")
        == ["agent-turn-complete", "approval-requested"]
        and document.get("tui", {}).get("status_line")
        == ["model-with-reasoning", "context-remaining", "git-branch", "current-dir"]
    )


def main() -> int:
    args = parse_args()
    target = args.config.expanduser().resolve(strict=False)
    original = target.read_text(encoding="utf-8") if target.exists() else ""
    try:
        if original:
            tomllib.loads(original)
        updated = render(original)
    except (tomllib.TOMLDecodeError, ValueError) as error:
        print(f"Configuración Codex no válida: {error}", file=sys.stderr)
        return 1

    if original and desired_state(tomllib.loads(original)) and original == updated:
        print(f"✓ Configuración Codex sincronizada: {target}")
        return 0
    if not args.apply:
        print(f"! Configuración Codex pendiente: {target}")
        print("  Se conservarán hooks, trusts, MCP y cualquier clave no gestionada.")
        return 1

    print(f"Destino exacto: {target}")
    print("Se conservarán hooks, trusts, MCP y cualquier clave no gestionada.")
    try:
        confirmation = input("Escribe APLICAR: ")
    except EOFError:
        confirmation = ""
    if confirmation != "APLICAR":
        print("Cancelado sin cambios.")
        return 1

    state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    backup_dir = (
        state
        / "dotfiles/codex-config"
        / (time.strftime("%Y%m%d-%H%M%S") + f"-{time.time_ns()}")
    )
    backup_dir.mkdir(parents=True, mode=0o700, exist_ok=False)
    if target.exists():
        shutil.copy2(target, backup_dir / "config.toml")

    target.parent.mkdir(parents=True, exist_ok=True)
    mode = target.stat().st_mode & 0o777 if target.exists() else 0o600
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=".config.toml.", dir=target.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(updated)
            handle.flush()
            os.fsync(handle.fileno())
        temporary.chmod(mode)
        temporary.replace(target)
    finally:
        temporary.unlink(missing_ok=True)

    print(f"✓ Configuración Codex sincronizada. Backup: {backup_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
