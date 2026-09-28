#!/usr/bin/env python3
"""Per-project verification gate for Claude Code hooks.

Opt-in per repository through local Git config, so nothing is written to the
project tree or its history:

    git config --local ai.format "pnpm exec prettier --write --ignore-unknown"
    git config --local ai.check  "pnpm lint && pnpm typecheck"

`format` (PostToolUse on Write|Edit|MultiEdit) runs `ai.format` with the edited
file appended; it never blocks. `check` (Stop) runs `ai.check` when the working
tree changed since the last passing run; a failure exits 2, so Claude keeps
working on it instead of ending the turn. `suggest` prints candidate commands
from package.json. A repository without the config is never touched.
"""
import hashlib
import json
import shlex
import subprocess
import sys
from pathlib import Path

CHECK_TIMEOUT = 280  # The Stop hook entry allows 300 s.
FORMAT_TIMEOUT = 25  # The PostToolUse hook entry allows 30 s.
TAIL = 40


def git(root: Path, *args: str) -> str:
    result = subprocess.run(["git", "-C", str(root), *args], capture_output=True, timeout=20)
    return result.stdout.decode("utf-8", "replace").strip() if result.returncode == 0 else ""


def repo(cwd: str) -> Path | None:
    top = git(Path(cwd or "."), "rev-parse", "--show-toplevel")
    return Path(top) if top else None


def fingerprint(root: Path) -> str:
    status = subprocess.run(["git", "-C", str(root), "status", "--porcelain=v1", "-uall", "-z"],
                            capture_output=True, timeout=20).stdout
    if not status:
        return ""
    diff = subprocess.run(["git", "-C", str(root), "diff", "HEAD", "--binary"],
                          capture_output=True, timeout=20).stdout
    digest = hashlib.sha256(status + diff)
    # Untracked files have no diff; hash their content too.
    for entry in status.split(b"\0"):
        if entry.startswith(b"?? "):
            path = root / entry[3:].decode("utf-8", "replace")
            if path.is_file():
                digest.update(path.read_bytes())
    return digest.hexdigest()


def run(command: str, root: Path, timeout: int) -> tuple[int, str]:
    try:
        result = subprocess.run(command, shell=True, cwd=root, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return 124, f"timed out after {timeout} s"
    output = (result.stdout + result.stderr).decode("utf-8", "replace")
    return result.returncode, output


def format_file(event: dict) -> int:
    root = repo(event.get("cwd", ""))
    path = (event.get("tool_input") or {}).get("file_path")
    command = git(root, "config", "--get", "ai.format") if root else ""
    if not (command and path):
        return 0
    file = Path(path) if Path(path).is_absolute() else root / path
    if not file.is_file() or not file.resolve().is_relative_to(root.resolve()):
        return 0
    quoted = f'"{file}"' if sys.platform == "win32" else shlex.quote(str(file))
    run(f"{command} {quoted}", root, FORMAT_TIMEOUT)
    return 0


def check(event: dict) -> int:
    root = repo(event.get("cwd", ""))
    command = git(root, "config", "--get", "ai.check") if root else ""
    if not command:
        return 0
    marker = Path(git(root, "rev-parse", "--absolute-git-dir")) / "ai-gate-pass"
    state = fingerprint(root)
    try:
        passed = marker.read_text(encoding="utf-8").strip()
    except OSError:
        passed = ""
    if not state or state == passed:
        return 0
    code, output = run(command, root, CHECK_TIMEOUT)
    if code == 0:
        marker.write_text(state, encoding="utf-8")
        return 0
    if event.get("stop_hook_active"):
        # Claude already continued once for this gate; report and let the turn end.
        print(f"project-gate: `{command}` still fails; report it to the user.", file=sys.stderr)
        return 0
    tail = "\n".join(output.strip().splitlines()[-TAIL:])
    print(f"project-gate: `{command}` failed (exit {code}). Fix the cause, do not skip "
          f"or weaken checks, then finish.\n{tail}", file=sys.stderr)
    return 2


def suggest(cwd: str) -> int:
    root = repo(cwd) or Path(cwd)
    try:
        scripts = json.loads((root / "package.json").read_text(encoding="utf-8")).get("scripts", {})
    except (OSError, ValueError):
        print("No package.json scripts found; set ai.check by hand.")
        return 1
    lock = {"pnpm-lock.yaml": "pnpm", "yarn.lock": "yarn", "bun.lockb": "bun", "bun.lock": "bun"}
    manager = next((tool for name, tool in lock.items() if (root / name).exists()), "npm run")
    fast = [name for name in ("lint", "typecheck", "type-check", "check", "test:unit") if name in scripts]
    print("Scripts:", ", ".join(sorted(scripts)) or "none")
    if fast:
        print("Candidate: git config --local ai.check " + shlex.quote(" && ".join(f"{manager} {s}" for s in fast)))
    if "prettier" in json.dumps(scripts) or any((root / f).exists() for f in (".prettierrc", ".prettierrc.json", "prettier.config.js", "prettier.config.mjs")):
        runner = "npx" if manager == "npm run" else f"{manager} exec"
        print("Candidate: git config --local ai.format " + shlex.quote(f"{runner} prettier --write --ignore-unknown"))
    return 0


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "suggest":
        return suggest(sys.argv[2] if len(sys.argv) > 2 else ".")
    try:
        event = json.loads(sys.stdin.buffer.read().decode("utf-8") or "{}")
    except ValueError:
        return 0
    try:
        return {"format": format_file, "check": check}.get(mode, lambda _: 0)(event)
    except (OSError, subprocess.SubprocessError) as error:
        print(f"project-gate: {error}", file=sys.stderr)
        return 0


if __name__ == "__main__":
    sys.exit(main())
