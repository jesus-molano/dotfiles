#!/usr/bin/env python3
"""Claude Code status line: model, project and branch, context use and plan limits.

Reads the session JSON from stdin and prints one short line. Missing fields are
skipped. It shows no prompt, path beyond the project name, or account data.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys


def percent(value) -> str | None:
    return f"{round(value)}%" if isinstance(value, (int, float)) else None


def branch(directory: str) -> str | None:
    try:
        result = subprocess.run(["git", "-C", directory, "branch", "--show-current"],
                                capture_output=True, text=True, timeout=1)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return result.stdout.strip() or None if result.returncode == 0 else None


def line(data: dict) -> str:
    parts = []
    model = (data.get("model") or {}).get("display_name")
    if model:
        parts.append(model)
    directory = (data.get("workspace") or {}).get("current_dir") or data.get("cwd")
    if isinstance(directory, str) and directory:
        name = os.path.basename(directory.rstrip("/\\")) or directory
        current = branch(directory)
        parts.append(f"{name}:{current}" if current else name)
    context = percent((data.get("context_window") or {}).get("used_percentage"))
    if context:
        parts.append(f"ctx {context}")
    limits = data.get("rate_limits") or {}
    for key, label in (("five_hour", "5h"), ("seven_day", "7d")):
        used = percent((limits.get(key) or {}).get("used_percentage"))
        if used:
            parts.append(f"{label} {used}")
    return " · ".join(parts)


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return 0
    if isinstance(data, dict):
        print(line(data))
    return 0


if __name__ == "__main__":
    sys.exit(main())
