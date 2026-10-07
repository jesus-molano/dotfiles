#!/usr/bin/env python3
"""Portable, transactional AI config sync. Preview never prints configuration values."""
from __future__ import annotations

import argparse
import base64
import copy
import hashlib
import json
import os
import re
import runpy
import stat
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path

import tomllib
from ai_sources import NAMED_SKILLS, USER_SKILLS, ROOT, LINUX_SKILLS, RETIRED, hook_scripts, instructions, roles

MISSING = {"$absent": True}
GRANTS = ".local/state/dotfiles/ai/workflow-grants"
# Anchored regex (a plain `A|B` list is exact names, but `mcp__.*` needs the regex path).
# The prompt senders and MCP tools are checked only for the workflow opt-in keyword.
GUARD_MATCHER = ("^(Bash|PowerShell|Monitor|Workflow|Write|Edit|MultiEdit"
                 "|CronCreate|ScheduleWakeup|RemoteTrigger|SendMessage|mcp__.*)$")
MCP = {"linear": "https://mcp.linear.app/mcp/readonly",
       "openaiDeveloperDocs": "https://developers.openai.com/mcp"}
NOTIFY = {"hooks": [{"type": "command", "command": "claude-notify", "timeout": 5}]}
CLAUDE_KEYS = {
    ("language",): "spanish",
    ("permissions", "defaultMode"): "auto",
    # bypassPermissions skips the auto-mode classifier and its soft_deny rules.
    # Claude Desktop honors this key in user settings too (docs: desktop, admin settings).
    ("permissions", "disableBypassPermissionsMode"): "disable",
    ("attribution", "commit"): "",
    ("attribution", "pr"): "",
    ("attribution", "sessionUrl"): False,
    ("pluginConfigs", "agents-md@builtin", "options", "instructionFiles"): "claude-md-and-agents-md",
}
# User skills are hidden from the model; named skills show only their name.
CLAUDE_KEYS.update({("skillOverrides", name): "user-invocable-only" for name in sorted(USER_SKILLS)})
CLAUDE_KEYS.update({("skillOverrides", name): "name-only" for name in sorted(NAMED_SKILLS)})
# Defaults set only when the key is absent and never owned afterwards, so a later
# /model or local choice is kept. Main agent: Opus (the alias follows the latest
# Opus, Opus 5.5 today); reading roles set Sonnet in their own files.
CLAUDE_DEFAULTS = {("model",): "opus"}
# Deny rules apply before the auto-mode classifier. Read and Edit rules cover Claude's
# file tools and only the shell commands Claude Code recognizes (cat, head, sed, tee,
# redirections); indirect reads such as `grep -r`, interpreters or scripts pass them.
# The ai-guard hook blocks shell commands that name these same stores.
DENY = ["Read(**/.env)", "Read(**/.env.*)",
        # gitignore negation: carves templates out of the path rules listed before it,
        # so `cp .env.example .env` reads the template and Claude can edit it.
        "Read(!.env.example)", "Read(!.env.sample)", "Read(!.env.template)",
        "Edit(**/.env)", "Edit(**/.env.*)",
        "Edit(!.env.example)", "Edit(!.env.sample)", "Edit(!.env.template)",
        "Read(~/.ssh/**)", "Read(~/.gnupg/**)", "Read(~/.aws/**)", "Read(~/.git-credentials)",
        "Read(~/.config/gh/hosts.yml)", "Read(~/.claude.json)", "Read(~/.claude/.credentials.json)",
        "Read(~/.codex/auth.json)",
        # Claude applies Edit rules to every file write; Write deny rules are ignored.
        "Edit(~/.local/share/tessera/projects/*/provider-consent.json)",
        "Edit(~/AppData/Local/tessera/projects/*/provider-consent.json)",
        "Edit(~/AppData/Local/Packages/*/LocalCache/Local/tessera/projects/*/provider-consent.json)",
        # Workflow opt-in markers (ai-guard.py grant_path): %USERPROFILE%\.local\state on
        # Windows, the default XDG_STATE_HOME on Linux. Claude Code also adds Edit deny
        # paths to the sandbox denyWrite list.
        f"Edit(~/{GRANTS}/**)"]

# Claude Code sandbox, Linux only (native Windows is not supported). Deny rules stop only
# the reads Claude Code recognizes; the sandbox stops every sandboxed process at the OS level.
SANDBOX_KEYS = {
    ("sandbox", "enabled"): True,
    # Sandboxed commands still go to the auto-mode classifier and its soft_deny rules.
    ("sandbox", "autoAllowBashIfSandboxed"): False,
    # A blocked command may be retried unsandboxed, through the permission flow and ai-guard.
    ("sandbox", "allowUnsandboxedCommands"): True,
}
# Exact paths only: Claude Code expands a read glob to every path it matches, and a
# `~/**` glob walks all of HOME. Dotfiles in the working directory come from the
# Read(**/.env*) deny rules, which Claude Code merges into this list.
SANDBOX_DENY_READ = ["~/.env", "~/.env.op", "~/.ssh", "~/.gnupg", "~/.aws", "~/.git-credentials",
                     "~/.config/gh/hosts.yml", "~/.claude.json", "~/.claude/.credentials.json",
                     "~/.codex/auth.json"]
# Narrower than the ~/.ssh deny, so it re-opens only the public signer list that
# `git log --show-signature` and `git verify-commit` read.
SANDBOX_ALLOW_READ = ["~/.ssh/allowed_signers"]
# The sync ledger, its backups and the workflow opt-in markers.
SANDBOX_DENY_WRITE = ["~/.local/state/dotfiles/ai", f"~/{GRANTS}"]
# Exact commands (or `cmd *` prefixes) that run outside the sandbox. They still go through
# the permission flow, the classifier and ai-guard. Dotfiles recipes read or write HOME by
# design; git over SSH, signed commits (1Password agent socket) and gh (hosts.yml) cannot
# work in the sandbox. See docs/ai.md, Sandbox.
SANDBOX_EXCLUDED = ["just ai-plan", "just ai-sync", "just ai-check", "just apply",
                    "just plan", "just status", "just doctor", "just doctor-live",
                    "git fetch *", "git pull *", "git push *", "git commit *", "gh *"]
# Keys whose local value the sync never adopts over, even with --adopt.
SECURITY_KEYS = {"sandbox", "permissions"}

# Rules for the auto-mode classifier (the default mode). "$defaults" keeps the built-ins.
AUTO_SOFT_DENY = [
    "$defaults",
    "Pushing to a remote unless the user authorized that exact repository, branch and commit in this conversation",
    "Reading, printing or copying secret files such as .env or credential stores, or revealing secret values",
    "Deleting, overwriting or formatting data outside the current task, or without confirming the exact target",
    "Running GNU Stow over every package, or changing /etc, boot, Btrfs, GPU drivers or system services without an explicit request",
    "Creating, editing or commenting on issues or pull requests in Linear or GitHub without explicit authorization",
    "Sending project source or catalog data to an external service the task has not already been authorized to use",
    "Creating, changing or deleting workflow opt-in markers",
]


def hook_command(home: Path, platform: str, script: str, folder: str = ".claude/hooks") -> str:
    # Windows has no reliable `python` on PATH (py launcher, Store alias), and a hook
    # that fails to start is ignored, so pin the interpreter that runs this sync.
    python = f'"{Path(sys.executable).as_posix()}"' if platform == "windows" else "python3"
    return f'{python} "{(home / folder / script).as_posix()}"'


def encode(data: bytes) -> str:
    return base64.b64encode(data).decode("ascii")


def digest(value) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def snapshot(path: Path, *, skip_python_cache=False) -> dict:
    if is_reparse(path) and not path.is_symlink():
        raise ValueError(f"Unsupported reparse point: {path}")
    if path.is_symlink():
        return {"kind": "link", "target": os.readlink(path)}
    if not path.exists():
        return {"kind": "absent"}
    if path.is_file():
        return {"kind": "file", "data": encode(path.read_bytes()),
                "mode": stat.S_IMODE(path.stat().st_mode)}
    if path.is_dir():
        entries = {p.name: snapshot(p, skip_python_cache=skip_python_cache)
                   for p in sorted(path.iterdir())
                   if not (skip_python_cache and (p.name == "__pycache__" or p.suffix in {".pyc", ".pyo"}))}
        # Empty containers have no content to own or remove during rollback.
        entries = {name: child for name, child in entries.items()
                   if child != {"kind": "dir", "entries": {}}}
        return {"kind": "dir", "entries": entries}
    raise ValueError(f"Unsupported file type: {path}")


def file_value(text: str) -> dict:
    return {"kind": "file", "data": encode(text.encode("utf-8")), "mode": 0o600}


def equivalent(a: dict, b: dict) -> bool:
    # Windows permissions differ; the byte content and link identity are authoritative.
    def clean(v):
        if isinstance(v, dict):
            return {k: clean(x) for k, x in v.items() if k != "mode"}
        return v
    return clean(a) == clean(b)


def is_reparse(path: Path) -> bool:
    try:
        return bool(getattr(path.lstat(), "st_file_attributes", 0) & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400))
    except FileNotFoundError:
        return False


def safe_path(path: Path, home: Path) -> None:
    if ".." in path.parts:
        raise ValueError(f"Path traversal not allowed: {path}")
    if not path.is_relative_to(home) or path == home:
        raise ValueError(f"Target outside HOME: {path}")
    for parent in path.parents:
        if parent == home:
            break
        if parent.is_symlink() or is_reparse(parent):
            raise ValueError(f"Linked directory not allowed: {parent}")
    if is_reparse(home) or home.is_symlink():
        raise ValueError("The selected HOME must be a real directory")
    if is_reparse(path) and not path.is_symlink():
        raise ValueError(f"Unsupported reparse point: {path}")


def atomic_file(path: Path, data: bytes, mode=0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".ai-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as out:
            out.write(data)
            out.flush()
            os.fsync(out.fileno())
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def restore(path: Path, value: dict) -> None:
    kind = value["kind"]
    if kind == "file" and not (path.is_dir() and not path.is_symlink()):
        atomic_file(path, base64.b64decode(value["data"]), value.get("mode", 0o600))
        return
    if kind == "dir" or (path.is_dir() and not path.is_symlink()):
        raise ValueError(f"Folders are updated file by file, never replaced: {path}")
    if kind == "link":
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_name(".ai-link-" + uuid.uuid4().hex)
        try:
            temporary.symlink_to(value["target"], target_is_directory=True)
            os.replace(temporary, path)
        finally:
            if temporary.is_symlink():
                temporary.unlink()
        return
    if path.is_symlink() or path.is_file():
        path.unlink()
    if kind == "absent":
        return
    raise ValueError("Invalid backup type")


def read_json(path: Path) -> dict:
    if not path.exists():
        return {}
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(data, dict):
        raise ValueError(f"Expected a JSON object: {path}")
    return data


def get(data: dict, keys: tuple):
    node = data
    for key in keys:
        if not isinstance(node, dict) or key not in node:
            return MISSING
        node = node[key]
    return node


def put(data: dict, keys: tuple, value) -> None:
    node = data
    for key in keys[:-1]:
        node = node.setdefault(key, {})
        if not isinstance(node, dict):
            raise ValueError("A managed key needs a table/object parent")
    node[keys[-1]] = copy.deepcopy(value)


def git_blob(data: bytes) -> str:
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def known_blob(data: bytes, blobs: set[str]) -> bool:
    # A Windows checkout may have converted line endings on the way out.
    return git_blob(data) in blobs or git_blob(data.replace(b"\r\n", b"\n")) in blobs


def json_text(value: dict) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


class Sync:
    def __init__(self, home: Path, platform: str, clients="both", root=ROOT, adopt=False):
        self.home = Path(os.path.abspath(home))
        # Adopt copies left by an earlier deployment of this repository when the
        # ownership ledger is missing (lost state, another machine, a virtualized
        # AppData). Only provably generated or historical content is adopted.
        self.adopt = adopt
        self.adopted = []
        self._history = None
        self.root = root.resolve()
        self.platform = platform
        self.clients = {"codex", "claude"} if clients == "both" else {clients}
        # Same place on every platform: %USERPROFILE%\.local\state is not virtualized
        # by MSIX, unlike AppData\Local (Claude Desktop and Codex are MSIX apps).
        self.state_dir = self.home / ".local/state/dotfiles/ai"
        self.legacy_state_dirs = ([self.home / "AppData/Local/dotfiles/ai",
                                   *sorted(self.home.glob("AppData/Local/Packages/*/LocalCache/Local/dotfiles/ai"))]
                                  if platform == "windows" else [])
        self.state_path = self.state_dir / "managed.json"
        safe_path(self.state_path, self.home)
        self.state_source = self.state_path
        if not self.state_path.exists():
            # Carry the ledger over from the old Windows location; the next apply
            # writes it to the new one and leaves the old file untouched.
            self.state_source = next((d / "managed.json" for d in self.legacy_state_dirs
                                      if (d / "managed.json").is_file()), self.state_path)
        self.state = read_json(self.state_source)
        self.next_state = copy.deepcopy(self.state)
        self.operations = []
        self.asset_expected = {}
        self.baselines = {}
        self.migration = read_json(self.root / "ai/migration.json")

    def observe(self, path):
        safe_path(path, self.home)
        current = snapshot(path)
        if str(path) in self.baselines and not equivalent(current, self.baselines[str(path)]):
            raise ValueError(f"Concurrent change while reading: {path}")
        self.baselines[str(path)] = current
        return current

    def read_config(self, path: Path, kind="json"):
        value = self.observe(path)
        if value["kind"] not in {"file", "absent"}:
            raise ValueError(f"Linked configuration not supported: {path}")
        raw = base64.b64decode(value["data"]).decode("utf-8-sig") if value["kind"] == "file" else ""
        document = (tomllib.loads(raw) if kind == "toml" else json.loads(raw)) if raw else {}
        if not isinstance(document, dict):
            raise ValueError(f"Expected a configuration object: {path}")
        return raw, document

    def asset(self, path: Path, desired: dict, legacy=False):
        current = self.observe(path)
        key = str(path.relative_to(self.home))
        previous = self.state.get(key)
        if previous and not equivalent(current, previous["value"]) and not equivalent(current, desired):
            raise ValueError(f"Conflict: managed file modified: {path}")
        empty_container = current == {"kind": "dir", "entries": {}} and desired["kind"] == "dir"
        if not previous and current["kind"] != "absent" and not empty_container and not equivalent(current, desired) and not legacy:
            if not (self.adopt and self.recognized(path, current)):
                raise ValueError(f"Conflict: foreign target: {path}")
            self.adopted.append(str(path))
        self.next_state[key] = {"value": desired}
        self.asset_expected[str(path)] = desired
        if not equivalent(current, desired):
            self.asset_operations(path, current, desired)

    def asset_operations(self, path: Path, current: dict, desired: dict):
        if current["kind"] == "dir" or desired["kind"] == "dir":
            if current["kind"] not in {"dir", "absent"} or desired["kind"] not in {"dir", "absent"}:
                raise ValueError(f"Folder type change needs review: {path}")
            before_entries = current.get("entries", {})
            after_entries = desired.get("entries", {})
            for name in sorted(set(before_entries) | set(after_entries)):
                before = before_entries.get(name, {"kind": "absent"})
                after = after_entries.get(name, {"kind": "absent"})
                if not equivalent(before, after):
                    self.asset_operations(path / name, before, after)
        else:
            self.operations.append({"path": str(path), "before": current, "after": desired})

    def merged(self, path: Path, original: dict, desired: dict, keys: dict, text: str):
        current = self.observe(path)
        if current["kind"] not in {"file", "absent"}:
            raise ValueError(f"Linked configuration not supported: {path}")
        key = str(path.relative_to(self.home))
        previous = self.state.get(key, {}).get("keys", [])
        for item in previous:
            route = tuple(item["path"])
            # Unrelated JSON/TOML fields may change freely; managed fields may not.
            if get(original, route) != item["value"] and get(original, route) != get(desired, route):
                raise ValueError(f"Conflict: managed key modified: {path} ({'.'.join(route)})")
        owned = {tuple(item["path"]) for item in previous}
        for route in keys:
            # Adopting a key the user already set to something else would erase their choice;
            # for sandbox and permission keys it could also weaken a local hardening.
            adopt = self.adopt and not previous and route[0] not in SECURITY_KEYS
            if (route not in owned and not adopt and get(desired, route) != MISSING
                    and get(original, route) not in (MISSING, get(desired, route))):
                raise ValueError(f"Conflict: new key already has a different local value: {path} ({'.'.join(map(str, route))})")
        projection = [{"path": list(route), "value": get(desired, route)} for route in keys]
        self.next_state[key] = {"keys": projection}
        if original != desired:
            after = file_value(text)
            if current["kind"] == "file":
                after["mode"] = current["mode"]
            self.operations.append({"path": str(path), "before": current, "after": after})

    def managed_entries(self, path: Path, original: dict, desired: dict, wanted: list) -> list:
        """Own single list items (deny rules, hook groups), never the whole list.

        Foreign entries stay untouched. A managed entry that the user removed is a
        conflict; one that the source no longer wants is removed.
        """
        previous = self.state.get(str(path.relative_to(self.home)), {})
        owned = [(tuple(route), entry) for route, entry in previous.get("entries", [])]
        if previous.get("notify"):
            owned.append((("hooks", "Stop"), NOTIFY))
        for route, entry in owned:
            current = get(original, route)
            present = isinstance(current, list) and entry in current
            if (route, entry) in wanted and not present:
                raise ValueError(f"Conflict: managed entry removed: {path} ({'.'.join(route)})")
            if (route, entry) not in wanted and present:
                get(desired, route).remove(entry)
        for route, entry in wanted:
            items = get(desired, route)
            if items == MISSING:
                put(desired, route, [])
                items = get(desired, route)
            if not isinstance(items, list):
                raise ValueError(f"Expected a list: {path} ({'.'.join(route)})")
            if entry not in items:
                items.append(copy.deepcopy(entry))
        return [[list(route), entry] for route, entry in wanted]

    def history_blobs(self) -> set[str]:
        """Git blob ids of every version of ai/ and the old Codex skill folder."""
        if self._history is None:
            try:
                out = subprocess.run(["git", "-C", str(self.root), "log", "--all", "--no-renames", "--format=",
                                      "--raw", "--no-abbrev", "--", "ai", "codex/.agents/skills"],
                                     capture_output=True, text=True, check=True).stdout
                self._history = {line.split()[3] for line in out.splitlines() if line.startswith(":")}
            except (OSError, subprocess.CalledProcessError):
                self._history = set()
        return self._history

    def recognized(self, path: Path, value: dict) -> bool:
        """True when a foreign-looking destination is an earlier copy of this repository's output."""
        if value["kind"] == "link":
            return Path(os.path.abspath(os.path.join(path.parent, value["target"]))).is_relative_to(self.root)
        if value["kind"] == "dir":
            files = []
            def walk(node):
                for child in node.get("entries", {}).values():
                    if child["kind"] == "dir":
                        walk(child)
                    elif child["kind"] == "file":
                        files.append(base64.b64decode(child["data"]))
                    else:
                        files.append(None)
            walk(value)
            blobs = self.history_blobs()
            return bool(files) and all(data is not None and known_blob(data, blobs) for data in files)
        if value["kind"] != "file":
            return False
        data = base64.b64decode(value["data"])
        if data.startswith((b"<!-- Generated by scripts/render-ai.py from ai/", b"# Generated from ai/roles.")):
            return True
        if path.parent.name == "agents" and data.startswith(f"---\nname: {path.stem}\n".encode()):
            return (self.root / "ai/roles" / f"{path.stem}.json").is_file()
        return known_blob(data, self.history_blobs())

    def known_legacy_file(self, path, source):
        if path.is_symlink():
            return path.resolve() == source.resolve()
        if path.is_file():
            return hashlib.sha256(path.read_bytes()).hexdigest() == self.migration.get(str(source.relative_to(self.root)))
        return False

    def skills(self, client):
        folder = self.home / (".agents/skills" if client == "codex" else ".claude/skills")
        for source in sorted((self.root / "ai/skills").iterdir()):
            if not source.is_dir() or (self.platform == "windows" and source.name in LINUX_SKILLS):
                continue
            # Generated bytecode is not a skill asset. Backups and observed
            # destinations still use complete snapshots for safe rollback.
            value = snapshot(source, skip_python_cache=True)
            if any(p.is_symlink() for p in source.rglob("*")):
                raise ValueError(f"Skill source contains links: {source}")
            target = folder / source.name
            desired = value if self.platform == "windows" else {"kind": "link", "target": str(source)}
            legacy = target.is_symlink() and target.resolve() == self.root / "codex/.agents/skills" / source.name
            self.asset(target, desired, legacy)
        for name in RETIRED:
            target = folder / name
            if target.is_symlink() and target.resolve() in {
                self.root / "codex/.agents/skills" / name,
                self.home / "dev/project-atlas/skills" / name,
            }:
                self.asset(target, {"kind": "absent"}, legacy=True)
            elif target.exists() or target.is_symlink():
                raise ValueError(f"Review the foreign Atlas skill before retiring it: {target}")

    def claude(self):
        base = self.home / ".claude"
        self.asset(base / "CLAUDE.md", file_value(instructions("claude", self.platform, self.root)))
        for name, text in roles("claude", self.platform, self.root).items():
            self.asset(base / "agents" / name, file_value(text))
        for name, text in hook_scripts(self.root).items():
            self.asset(base / "hooks" / name, file_value(text))
        path = base / "settings.json"
        _, original = self.read_config(path)
        desired = copy.deepcopy(original)
        keys = dict(CLAUDE_KEYS)
        if self.platform == "linux":
            keys.update(SANDBOX_KEYS)
        keys[("statusLine",)] = {"type": "command", "padding": 0,
                                 "command": hook_command(self.home, self.platform, "statusline.py")}
        for route, value in keys.items():
            put(desired, route, value)
        for route, value in CLAUDE_DEFAULTS.items():
            if get(original, route) == MISSING:
                put(desired, route, value)
        guard_hook = {"type": "command", "command": hook_command(self.home, self.platform, "ai-guard.py"), "timeout": 10}
        guard = {"matcher": GUARD_MATCHER, "hooks": [guard_hook]}
        wanted = [(("permissions", "deny"), rule) for rule in DENY] + [(("hooks", "PreToolUse"), guard)]
        # The same guard records the user's workflow opt-in from a typed prompt or /workflow-authoring.
        wanted.append((("hooks", "UserPromptSubmit"), {"hooks": [guard_hook]}))
        wanted.append((("hooks", "UserPromptExpansion"), {"matcher": "workflow-authoring", "hooks": [guard_hook]}))
        wanted += [(("autoMode", "soft_deny"), rule) for rule in AUTO_SOFT_DENY]
        # Per-project gate: runs project commands only where a repository sets ai.format /
        # ai.check in its Git config; the Stop and pre-commit entries remind Claude to verify edits.
        gate = hook_command(self.home, self.platform, "project-gate.py")
        wanted.append((("hooks", "PostToolUse"), {"matcher": "Write|Edit|MultiEdit", "hooks": [
            {"type": "command", "command": f"{gate} format", "timeout": 30}]}))
        wanted.append((("hooks", "PreToolUse"), {"matcher": "^(Bash|PowerShell)$", "hooks": [
            {"type": "command", "command": f"{gate} commit", "timeout": 30}]}))
        wanted.append((("hooks", "Stop"), {"hooks": [
            {"type": "command", "command": f"{gate} check", "timeout": 300}]}))
        if self.platform == "linux":
            wanted.append((("hooks", "Stop"), NOTIFY))
            wanted += [(("sandbox", "filesystem", "denyRead"), path) for path in SANDBOX_DENY_READ]
            wanted += [(("sandbox", "filesystem", "allowRead"), path) for path in SANDBOX_ALLOW_READ]
            wanted += [(("sandbox", "filesystem", "denyWrite"), path) for path in SANDBOX_DENY_WRITE]
            wanted += [(("sandbox", "excludedCommands"), command) for command in SANDBOX_EXCLUDED]
        entries = self.managed_entries(path, original, desired, wanted)
        self.merged(path, original, desired, keys, json_text(desired))
        self.next_state[str(path.relative_to(self.home))]["entries"] = entries
        path = self.home / ".claude.json"
        _, original = self.read_config(path)
        desired = copy.deepcopy(original)
        keys = {}
        if "linear-write" in original.get("mcpServers", {}):
            raise ValueError("Claude has a persistent linear-write server. Review and remove it explicitly; it is allowed only as a temporary per-session config.")
        for name, url in MCP.items():
            route = ("mcpServers", name)
            old = get(original, route)
            if old != MISSING and (not isinstance(old, dict) or old.get("url") != url or old.get("type") != "http"):
                raise ValueError(f"Different local connection: {name}; kept, not replaced")
            for field, value in {"type": "http", "url": url}.items():
                keys[route + (field,)] = value
                put(desired, route + (field,), value)
        # Retire only the named integration, leaving all other connections untouched.
        desired.get("mcpServers", {}).pop("component-atlas", None)
        keys[("mcpServers", "component-atlas")] = MISSING
        self.merged(path, original, desired, keys, json_text(desired))
        self.skills("claude")

    def codex(self):
        base = self.home / ".codex"
        source = self.root / "codex/.codex/AGENTS.md"
        desired = file_value(instructions("codex", self.platform, self.root))
        if self.platform == "linux":
            desired = {"kind": "link", "target": str(source)}
            # Stow owns this link. Keep its lexical (normally relative) target.
            if (base / "AGENTS.md").is_symlink() and (base / "AGENTS.md").resolve() == source.resolve():
                desired = snapshot(base / "AGENTS.md")
        self.asset(base / "AGENTS.md", desired, self.known_legacy_file(base / "AGENTS.md", source))
        role_files = roles("codex", self.platform, self.root)
        for name, text in role_files.items():
            source = self.root / "codex/.codex/agents" / name
            self.asset(base / "agents" / name, file_value(text), self.known_legacy_file(base / "agents" / name, source))
        if self.platform == "linux":
            # Keep the existing Codex manager's ownership ledger in this transaction.
            path = self.home / ".local/state/dotfiles/codex-agents/managed.json"
            _, original_meta = self.read_config(path)
            desired_meta = copy.deepcopy(original_meta)
            metadata_keys = {}
            for name, content in role_files.items():
                route = ("destinations", str(base / "agents"), name)
                metadata_keys[route] = hashlib.sha256(content.encode()).hexdigest()
                put(desired_meta, route, metadata_keys[route])
            self.merged(path, original_meta, desired_meta, metadata_keys, json_text(desired_meta))
        # Same guard as Claude: Codex hooks.json uses the same schema and stdin
        # contract. Codex runs a new user hook only after it is trusted in /hooks.
        guard_script = hook_scripts(self.root)["ai-guard.py"]
        self.asset(base / "hooks/ai-guard.py", file_value(guard_script))
        path = base / "hooks.json"
        _, original = self.read_config(path)
        desired = copy.deepcopy(original)
        guard = {"matcher": "Bash|apply_patch", "hooks": [{"type": "command", "timeout": 10,
                 "command": hook_command(self.home, self.platform, "ai-guard.py", ".codex/hooks")}]}
        entries = self.managed_entries(path, original, desired, [(("hooks", "PreToolUse"), guard)])
        self.merged(path, original, desired, {}, json_text(desired))
        self.next_state[str(path.relative_to(self.home))]["entries"] = entries
        mod = runpy.run_path(str(self.root / "scripts/sync-codex-config.py"))
        path = base / "config.toml"
        raw, original = self.read_config(path, "toml")
        # Reuse the existing line-preserving merger, with platform-specific notification.
        if self.platform == "windows":
            mod["DESIRED_TOP"].pop("notify", None)
            # render's desired_state is Linux-specific; use the same set_key contract.
        lines = raw.splitlines(keepends=True)
        if lines and not lines[-1].endswith("\n"):
            lines[-1] += "\n"
        keys = {}
        for key, value in mod["DEFAULT_TOP"].items():
            if key not in original or f'"{original[key]}"' in mod["RETIRED_DEFAULTS"].get(key, ()):
                mod["set_key"](lines, None, key, value)
        for key, value in mod["DESIRED_TOP"].items():
            # A foreign notifier is a local integration, not ours to replace.
            if key == "notify" and key in original and original[key] != ["codex-notify"]:
                continue
            mod["set_key"](lines, None, key, value)
            keys[(key,)] = True
        for section, fields in mod["DESIRED_SECTIONS"].items():
            for key, value in fields.items():
                mod["set_key"](lines, section, key, value)
                keys[(section, key)] = True
        # Only a normal named TOML table is removed. Complex forms fail closed below.
        raw = "".join(lines)
        raw = re.sub(r'^\[mcp_servers\.(?:component-atlas|"component-atlas")(?:\.[^\]]+)?\][^\n]*\n.*?(?=^\[|\Z)', '', raw, flags=re.M | re.S)
        lines = raw.splitlines(keepends=True)
        current = tomllib.loads(raw)
        if not isinstance(current.get("mcp_servers", {}), dict):
            raise ValueError("mcp_servers must be a table; configuration kept")
        if "component-atlas" in current.get("mcp_servers", {}):
            raise ValueError("Complex Atlas MCP format: needs an explicit migration")
        for name, url in {**MCP, "linear-write": "https://mcp.linear.app/mcp"}.items():
            old = current.get("mcp_servers", {}).get(name)
            if old is not None and (not isinstance(old, dict) or old.get("url") != url):
                raise ValueError(f"Different local connection: {name}; kept")
            mod["set_key"](lines, f"mcp_servers.{name}", "url", json.dumps(url))
            keys[("mcp_servers", name, "url")] = True
            if name == "linear-write":
                mod["set_key"](lines, f"mcp_servers.{name}", "enabled", "false")
                keys[("mcp_servers", name, "enabled")] = True
        raw = "".join(lines)
        keys[("mcp_servers", "component-atlas")] = MISSING
        self.merged(path, original, tomllib.loads(raw), keys, raw)
        self.skills("codex")

    def plan(self):
        for client in sorted(self.clients):
            getattr(self, client)()
        # The manifest is part of the same transaction, including its first creation.
        current = self.observe(self.state_path)
        desired = file_value(json_text(self.next_state))
        if not equivalent(current, desired):
            self.operations.append({"path": str(self.state_path), "before": current, "after": desired})
        return self.operations

    def validate_baselines(self):
        for name, before in self.baselines.items():
            path = Path(name)
            safe_path(path, self.home)
            if not equivalent(snapshot(path), before):
                raise ValueError(f"Concurrent change detected: {path}")

    def apply(self):
        self.validate_baselines()
        if not self.operations:
            return None
        backup = self.state_dir / "backups" / (time.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:8])
        backup.mkdir(parents=True, mode=0o700)
        os.chmod(self.state_dir, 0o700)
        journal = {"home": str(self.home), "status": "prepared", "operations": self.operations}
        atomic_file(backup / "transaction.json", json_text(journal).encode())
        touched = []
        try:
            for operation in self.operations:
                path = Path(operation["path"])
                safe_path(path, self.home)
                if not equivalent(snapshot(path), operation["before"]):
                    raise ValueError(f"Concurrent change detected: {path}")
                touched.append(operation)
                restore(path, operation["after"])
                if not equivalent(snapshot(path), operation["after"]):
                    raise ValueError(f"Write verification failed: {path}")
            for name, expected in self.asset_expected.items():
                if not equivalent(snapshot(Path(name)), expected):
                    raise ValueError(f"Content verification failed: {name}")
            journal["status"] = "applied"
        except BaseException:
            journal["status"] = "rolled-back"
            for operation in reversed(touched):
                path = Path(operation["path"])
                try:
                    if equivalent(snapshot(path), operation["after"]):
                        restore(path, operation["before"])
                    elif not equivalent(snapshot(path), operation["before"]):
                        journal["status"] = "needs-recovery"
                except (OSError, ValueError):
                    journal["status"] = "needs-recovery"
            raise
        finally:
            atomic_file(backup / "transaction.json", json_text(journal).encode())
        return backup

    def rollback(self, backup: Path):
        expected = {self.state_dir / "backups", *(d / "backups" for d in self.legacy_state_dirs)}
        backup = backup.absolute()
        if backup.parent not in expected or backup.is_symlink():
            raise ValueError("The backup must belong to the selected HOME")
        journal_path = backup / "transaction.json"
        safe_path(journal_path, self.home)
        if journal_path.is_symlink():
            raise ValueError("The journal must be a regular file")
        journal = read_json(journal_path)
        if journal.get("home") != str(self.home) or journal.get("status") not in {
            "applied", "prepared", "failed", "needs-recovery", "rolling-back"
        }:
            raise ValueError("Backup not applicable or already restored")
        operations = journal["operations"]
        for item in operations:
            path = Path(item["path"])
            safe_path(path, self.home)
            current = snapshot(path)
            if not equivalent(current, item["after"]) and not equivalent(current, item["before"]):
                raise ValueError(f"Rollback blocked by a later change: {path}")
        journal["status"] = "rolling-back"
        atomic_file(journal_path, json_text(journal).encode())
        for item in reversed(operations):
            path = Path(item["path"])
            current = snapshot(path)
            if equivalent(current, item["before"]):
                continue
            if not equivalent(current, item["after"]):
                raise ValueError(f"Concurrent change during rollback: {path}")
            restore(path, item["before"])
        journal["status"] = "rolled-back"
        atomic_file(journal_path, json_text(journal).encode())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["plan", "apply", "check", "rollback"])
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--platform", choices=["linux", "windows"], default="windows" if os.name == "nt" else "linux")
    parser.add_argument("--clients", choices=["both", "claude", "codex"], default="both")
    parser.add_argument("--backup", type=Path)
    parser.add_argument("--adopt", action="store_true",
                        help="Adopt copies from an earlier deployment of this repo when the ledger is missing")
    args = parser.parse_args()
    sync = Sync(args.home, args.platform, args.clients, adopt=args.adopt)
    lock = None
    try:
        if args.mode in {"apply", "rollback"}:
            sync.state_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
            lock_path = sync.state_dir / "sync.lock"
            fd = os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
            lock = lock_path
            os.close(fd)
            sync = Sync(args.home, args.platform, args.clients, adopt=args.adopt)
        if args.mode == "rollback":
            if not args.backup:
                raise ValueError("rollback needs --backup")
            sync.rollback(args.backup)
            print("OK: rollback verified")
            return 0
        operations = sync.plan()
        if sync.state_source != sync.state_path:
            print(f"state: ledger carried over from {sync.state_source}")
        for adopted in sync.adopted:
            print(f"adopt: {adopted}")
        for operation in operations:
            print(f"{operation['before']['kind']} -> {operation['after']['kind']}: {operation['path']}")
        if args.mode == "apply":
            backup = sync.apply()
            if backup:
                print(f"Private backup: {backup}")
            else:
                print("OK: no changes")
        else:
            print(f"Pending: {len(operations)}")
        return 1 if args.mode == "check" and operations else 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        # JSON/TOML parser exception strings can include data; report type only.
        if isinstance(error, (json.JSONDecodeError, tomllib.TOMLDecodeError)):
            print(f"ERROR: invalid configuration ({type(error).__name__})", file=sys.stderr)
        else:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2
    finally:
        if lock is not None and lock.exists():
            lock.unlink()


if __name__ == "__main__":
    raise SystemExit(main())
