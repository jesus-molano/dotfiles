#!/usr/bin/env python3
"""PreToolUse guard: turns the hard limits in ai/rules into checks the model cannot skip.

Claude Code sends one JSON event on stdin. Exit 0 allows the call; exit 2 blocks
it and the stderr reason is shown to the model. Only commands that are never
part of a normal task are blocked, so the guard stays cheap and quiet:

- publication that forces, deletes, mirrors or sends tags or several refs;
- Stow over a glob of packages;
- recursive deletion of HOME, the dotfiles checkout or the filesystem root;
- reading secret files (.env*) or 1Password items directly;
- `tessera.py consent` or touching `provider-consent.json`, which only the user may do;
- the Workflow tool, unless the user started the session with AI_ALLOW_WORKFLOW=1.

The guard never prints the command, file contents or environment values. It is
a guardrail against mistakes, not a sandbox: code running as the same user can
still reach anything that user can.
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
WRAPPERS = {"sudo", "command", "exec", "env", "nice", "time", "nohup", "xargs", "timeout", "doas"}
SHELLS = {"bash", "sh", "zsh", "dash", "fish", "eval"}
HEREDOC = re.compile(r"<<-?[ \t]*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1[^\n]*\n.*?\n[ \t]*\2[ \t]*(?=\n|$)", re.S)


def home_variants() -> set[str]:
    home = os.path.expanduser("~").rstrip("/")
    dotfiles = os.environ.get("DOTFILES_DIR", f"{home}/.dotfiles").rstrip("/")
    return {"/", "/*", "~", "~/*", "$HOME", "$HOME/*", "${HOME}", "${HOME}/*", home, home + "/*",
            "~/.dotfiles", "$HOME/.dotfiles", "${HOME}/.dotfiles", dotfiles}


def normalized(word: str) -> str:
    return word.rstrip("/") or "/"


def segments(command: str) -> list[list[str]]:
    # Heredoc bodies are data, and command substitutions are commands of their own.
    command = HEREDOC.sub(" ", command).replace("`", " ; ").replace("\n", " ; ")
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|()<>")
    lexer.whitespace_split = True
    lexer.commenters = ""
    result, current, skip = [], [], False
    for token in lexer:
        if skip:
            skip = False
        elif token and set(token) <= set("<>&|") and ("<" in token or ">" in token):
            # Redirection: drop its file descriptor and its target, keep the command.
            if current and current[-1].isdigit():
                current.pop()
            skip = True
        elif token in SEPARATORS:
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
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", word) or os.path.basename(word) in WRAPPERS:
            index += 1
            continue
        if word.startswith("-") and index and os.path.basename(words[index - 1]) in WRAPPERS | {"-n"}:
            index += 1
            continue
        if re.fullmatch(r"\d+[smhd]?", word) and index and os.path.basename(words[index - 1]) == "timeout":
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


def check_bash(command: str, depth: int = 0) -> str | None:
    if "provider-consent" in command:
        return "provider consent is granted by the user in their own terminal"
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
        if program in SHELLS and depth < 3:
            if program == "eval":
                inner = " ".join(words[1:])
            elif "-c" in words[1:-1]:
                inner = words[words.index("-c") + 1]
            else:
                continue
            if reason := check_bash(inner, depth + 1):
                return reason
            continue
        if program == "git" and (reason := git_push(words)):
            return reason
        if program == "stow" and any(ch in arg for arg in words[1:] for ch in "*?["):
            return "never run Stow over a glob of packages; name each package"
        if program == "rm" and any(re.fullmatch(r"-[a-zA-Z]*[rR][a-zA-Z]*", a) or a == "--recursive"
                                   for a in words[1:]):
            if {normalized(w) for w in words[1:]} & home_variants():
                return "recursive deletion of HOME, the dotfiles checkout or / is never allowed"
        if program == "op" and len(words) > 1 and words[1] in OP_READS:
            return "read secrets only through with-secrets for the process that needs them"
        if ("consent" in words and any(os.path.basename(w) == "tessera.py" for w in words)):
            return "provider consent is granted by the user in their own terminal"
        if reason := secret_use(program, words):
            return reason
    return None


def secret_use(program: str, words: list[str]) -> str | None:
    """Block reading a secret file; writing or naming it in text is fine."""
    if program in {"echo", "printf", "touch"} or (program == "git" and "check-ignore" in words):
        return None
    secrets = [i for i, w in enumerate(words) if i and SECRET.search(w.split("=", 1)[-1])
               and not w.endswith(SAFE_SECRET_SUFFIXES)]
    if not secrets:
        return None
    # `cp .env.example .env` writes the destination; only reading a secret is blocked.
    if program in {"cp", "mv", "install"} and secrets == [len(words) - 1]:
        return None
    return "secret files (.env*) are never read or shown; use with-secrets"


def decide(event: dict) -> str | None:
    tool = event.get("tool_name")
    data = event.get("tool_input") or {}
    if tool == "Workflow" and os.environ.get("AI_ALLOW_WORKFLOW") != "1":
        return ("multi-agent workflows need an explicit request; ask the user, who can start "
                "the session with AI_ALLOW_WORKFLOW=1")
    if tool in {"Write", "Edit", "MultiEdit"} and "provider-consent" in str(data.get("file_path", "")):
        return "provider consent is granted by the user in their own terminal"
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
