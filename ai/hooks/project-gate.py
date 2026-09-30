#!/usr/bin/env python3
"""Per-project verification gate for Claude Code hooks.

Opt-in per repository through local Git config, so nothing is written to the
project tree or its history:

    git config --local ai.format "pnpm exec prettier --write --ignore-unknown"
    git config --local ai.check  "pnpm lint && pnpm typecheck"

Only the repository's own config counts, never ~/.gitconfig or its includes.
`format` (PostToolUse on Write|Edit|MultiEdit) runs `ai.format` with the edited
file appended; it never blocks. `check` (Stop) runs `ai.check` when HEAD, the
working tree or the command changed since the last passing run; a failure exits
2, so Claude keeps working on it instead of ending the turn. `suggest` prints
candidate commands from package.json. A repository without the config is never
touched.
"""
import hashlib
import json
import os
import shlex
import signal
import subprocess
import sys
import time
from pathlib import Path

# Budget for the whole hook, git calls included, below the hook entry timeouts
# (Stop: 300 s, PostToolUse: 30 s).
BUDGET = {"check": 290, "format": 27}
GIT_TIMEOUT = 20
# Kept free inside the budget so a timed-out command can still be killed and reaped.
KILL_TIME = 8
TAIL = 40
deadline = time.monotonic() + BUDGET["check"]


def remaining() -> float:
    return deadline - time.monotonic()


def git(root: Path, *args: str, raw: bool = False):
    result = subprocess.run(["git", "-C", str(root), *args], capture_output=True,
                            timeout=max(1, min(GIT_TIMEOUT, remaining())))
    if raw:
        return result.stdout
    return result.stdout.decode("utf-8", "replace").strip() if result.returncode == 0 else ""


def repo(cwd: str) -> Path | None:
    top = git(Path(cwd or "."), "rev-parse", "--show-toplevel")
    return Path(top) if top else None


def setting(root: Path | None, key: str) -> str:
    # --local: a global or included config must not run commands in every repository.
    return git(root, "config", "--local", "--get", key) if root else ""


def fingerprint(root: Path, command: str, status: bytes) -> str:
    """HEAD, the command and the working tree: after a commit or a stash the state is new."""
    digest = hashlib.sha256()
    for part in (git(root, "rev-parse", "--verify", "-q", "HEAD").encode(), command.encode(),
                 status, git(root, "diff", "HEAD", "--binary", raw=True)):
        digest.update(hashlib.sha256(part).digest())
    # Untracked files have no diff; hash their content too.
    for entry in status.split(b"\0"):
        if entry.startswith(b"?? "):
            path = root / entry[3:].decode("utf-8", "replace")
            if path.is_file():
                digest.update(path.read_bytes())
    return digest.hexdigest()


def kill_tree(process: subprocess.Popen) -> None:
    if os.name == "nt":
        try:
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(process.pid)], capture_output=True,
                           timeout=KILL_TIME / 2)
        except (OSError, subprocess.SubprocessError):
            pass  # process.kill() below still stops the shell itself
    else:
        try:
            os.killpg(process.pid, signal.SIGKILL)  # the shell leads its own process group
        except ProcessLookupError:
            pass
    process.kill()


def run(command: str, root: Path, timeout: float) -> tuple[int, str]:
    timeout -= KILL_TIME
    if timeout < 1:
        return 124, "no time left in the hook budget"
    group = ({"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == "nt"
             else {"start_new_session": True})
    process = subprocess.Popen(command, shell=True, cwd=root, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, **group)
    try:
        output, _ = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        kill_tree(process)  # children would keep running and hold the output pipe open
        try:
            # A descendant that left the process group can keep the pipe open: do not wait for it.
            process.communicate(timeout=KILL_TIME / 4)
        except subprocess.TimeoutExpired:
            pass
        finally:
            try:
                process.stdout.close()
                process.wait(timeout=1)  # the shell is dead; reap it
            except (OSError, subprocess.TimeoutExpired):
                pass
        return 124, f"timed out after {int(timeout)} s"
    return process.returncode, output.decode("utf-8", "replace")


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def format_file(event: dict) -> int:
    root = repo(event.get("cwd", ""))
    path = (event.get("tool_input") or {}).get("file_path")
    command = setting(root, "ai.format")
    if not (command and path):
        return 0
    file = Path(path) if Path(path).is_absolute() else root / path
    if not file.is_file() or not file.resolve().is_relative_to(root.resolve()):
        return 0
    quoted = f'"{file}"' if sys.platform == "win32" else shlex.quote(str(file))
    run(f"{command} {quoted}", root, remaining() - 1)
    return 0


def check(event: dict) -> int:
    root = repo(event.get("cwd", ""))
    command = setting(root, "ai.check")
    if not command:
        return 0
    git_dir = git(root, "rev-parse", "--absolute-git-dir")
    if not git_dir:  # never write the state files into the working tree
        return 0
    passed, failed = Path(git_dir) / "ai-gate-pass", Path(git_dir) / "ai-gate-fail"
    status = git(root, "status", "--porcelain=v1", "-uall", "-z", raw=True)
    state = fingerprint(root, command, status)
    if state == read(passed):
        return 0
    if not status and not (read(passed) or read(failed)):
        # First visit with a clean tree: take it as the baseline instead of checking
        # work that no gated session made (a fresh clone, an old repository).
        passed.write_text(state, encoding="utf-8")
        return 0
    again = event.get("stop_hook_active")
    # Claude already continued once for this gate and changed nothing: do not run it again.
    if not (again and state == read(failed)):
        code, output = run(command, root, remaining() - 2)
        if code == 0:
            passed.write_text(state, encoding="utf-8")
            failed.unlink(missing_ok=True)
            return 0
        failed.write_text(state, encoding="utf-8")
    if again:
        # Report and let the turn end instead of looping.
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
    global deadline
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "suggest":
        return suggest(sys.argv[2] if len(sys.argv) > 2 else ".")
    deadline = time.monotonic() + BUDGET.get(mode, BUDGET["format"])
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
