#!/usr/bin/env python3
"""PreToolUse guard: turns the hard limits in ai/rules into checks the model cannot skip.

Claude Code sends one JSON event on stdin. Exit 0 allows the call; exit 2 blocks
it and the stderr reason is shown to the model. Only commands that are never
part of a normal task are blocked, so the guard stays cheap and quiet:

- publication that forces, deletes, mirrors or sends tags or several refs;
- Stow over a glob of packages;
- recursive deletion of HOME, the dotfiles checkout or the filesystem root;
- reading secret files (.env*) or 1Password items directly;
- `tessera.py consent`, which only the user may run;
- the Workflow tool, unless the user started the session with AI_ALLOW_WORKFLOW=1.

The guard never prints the command, file contents or environment values.
"""
from __future__ import annotations

import json
import os
import re
import shlex
import sys

SEPARATORS = {";", "&&", "||", "|", "&", "|&", "(", ")", "\n"}
PUSH_FLAGS = {"-f", "--force", "--mirror", "--delete", "-d", "--tags", "--all", "--prune",
              "--follow-tags", "--force-if-includes"}
PUSH_VALUE_FLAGS = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}
GIT_VALUE_FLAGS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}
SECRET = re.compile(r"(^|/)\.env(\.[^/]*)?$")
SAFE_SECRET_SUFFIXES = (".example", ".template", ".sample")
OP_READS = {"read", "inject", "item", "document"}


def home_variants() -> set[str]:
    home = os.path.expanduser("~").rstrip("/")
    dotfiles = os.environ.get("DOTFILES_DIR", f"{home}/.dotfiles").rstrip("/")
    return {"/", "/*", "~", "~/", "~/*", "$HOME", "$HOME/", "$HOME/*", "${HOME}", "${HOME}/",
            home, home + "/", home + "/*", "~/.dotfiles", "$HOME/.dotfiles", dotfiles, dotfiles + "/"}


def segments(command: str) -> list[list[str]]:
    lexer = shlex.shlex(command.replace("\n", " ; "), posix=True, punctuation_chars=";&|()")
    lexer.whitespace_split = True
    result, current = [], []
    for token in lexer:
        if token in SEPARATORS:
            if current:
                result.append(current)
            current = []
        else:
            current.append(token)
    if current:
        result.append(current)
    return result


def strip_prefix(words: list[str]) -> list[str]:
    """Drop env assignments and wrappers so `FOO=1 sudo git push` is still seen."""
    index = 0
    while index < len(words):
        word = words[index]
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", word) or word in {"sudo", "command", "exec", "env", "nice", "time"}:
            index += 1
            continue
        break
    return words[index:]


def git_push(words: list[str]) -> str | None:
    index = 1
    while index < len(words) and words[index].startswith("-"):
        index += 2 if words[index] in GIT_VALUE_FLAGS else 1
    if index >= len(words) or words[index] != "push":
        return None
    positional, args = [], words[index + 1:]
    skip = False
    for arg in args:
        if skip:
            skip = False
            continue
        name = arg.split("=", 1)[0]
        if name in PUSH_FLAGS or name.startswith("--force") or re.fullmatch(r"-[a-zA-Z]*[fd][a-zA-Z]*", arg):
            return "git push with force, delete, mirror, tags or all refs is never allowed"
        if arg in PUSH_VALUE_FLAGS:
            skip = True
        elif not arg.startswith("-"):
            positional.append(arg)
    refspecs = positional[1:]
    if len(refspecs) > 1:
        return "publish one verified ref per push"
    if any(ref.startswith(("+", ":")) for ref in refspecs):
        return "forced or deleting refspecs are never allowed"
    return None


def check_bash(command: str) -> str | None:
    try:
        parts = segments(command)
    except ValueError:
        return "command could not be parsed safely; simplify the quoting" if re.search(
            r"\b(push|stow|rm|\.env|consent)\b", command) else None
    for raw in parts:
        words = strip_prefix(raw)
        if not words:
            continue
        program = os.path.basename(words[0])
        if program == "git" and (reason := git_push(words)):
            return reason
        if program == "stow" and any(ch in arg for arg in words[1:] for ch in "*?["):
            return "never run Stow over a glob of packages; name each package"
        if program == "rm" and any(re.fullmatch(r"-[a-zA-Z]*r[a-zA-Z]*", a) or a in {"--recursive", "-R"}
                                   for a in words[1:]):
            if set(words[1:]) & home_variants():
                return "recursive deletion of HOME, the dotfiles checkout or / is never allowed"
        if program == "op" and len(words) > 1 and words[1] in OP_READS:
            return "read secrets only through with-secrets for the process that needs them"
        if any(os.path.basename(w) == "tessera.py" for w in words[:3]) and "consent" in words:
            return "provider consent is granted by the user in their own terminal"
        for word in words[1:]:
            target = word.split("=", 1)[-1]
            if SECRET.search(target) and not target.endswith(SAFE_SECRET_SUFFIXES):
                return "secret files (.env*) are never read or shown; use with-secrets"
    return None


def decide(event: dict) -> str | None:
    tool = event.get("tool_name")
    data = event.get("tool_input") or {}
    if tool == "Workflow" and os.environ.get("AI_ALLOW_WORKFLOW") != "1":
        return ("multi-agent workflows need an explicit request; ask the user, who can start "
                "the session with AI_ALLOW_WORKFLOW=1")
    if tool in {"Bash", "PowerShell"} and isinstance(data.get("command"), str):
        return check_bash(data["command"])
    return None


def main() -> int:
    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return 0
    reason = decide(event) if isinstance(event, dict) else None
    if reason:
        print(f"Blocked by ai-guard: {reason}.", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
