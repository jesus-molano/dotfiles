#!/usr/bin/env python3
"""PreToolUse guard: turns the hard limits in ai/rules into checks the model cannot skip.

Claude Code and Codex send the same JSON event on stdin. Exit 0 allows the call; exit 2 blocks
it and the stderr reason is shown to the model. Only commands that are never
part of a normal task are blocked, so the guard stays cheap and quiet:

- publication: only a plain top-level `git push [-u] [remote] [branch]` passes;
  forcing, deleting, tags, several refs, aliases and hidden pushes are blocked,
  and so are `gh repo delete`, `gh pr merge --admin` and ref writes through `gh api`;
- Stow over a glob of packages;
- recursive deletion of HOME, the dotfiles checkout or the filesystem root;
- reading secret files (.env*), credential stores (Claude, Codex, gh, Git, SSH,
  GnuPG, AWS) or 1Password items directly;
- `tessera.py consent` or writing `provider-consent.json`, which only the user may do;
- the Workflow tool, unless the user opted in for this session: a prompt that starts
  with `ultracode` or `/workflow-authoring`, or AI_ALLOW_WORKFLOW=1 at CLI start;
- any tool call that names the opt-in state directory, and any call that could
  put the opt-in keyword into a prompt of this session: a scheduled prompt
  (CronCreate, ScheduleWakeup, RemoteTrigger), a message to a session
  (SendMessage, MCP tools) or a shell command that names the keyword or the
  session messaging socket. So the model cannot grant the opt-in to itself.

The same script also runs on UserPromptSubmit and UserPromptExpansion. There it
records the opt-in for the session and never blocks the prompt.

Secrets and publication fail closed: every mention of them in the raw command
text must lie inside a part that the parser understood as harmless, or the
command is blocked. The other limits rely on the parser alone.

The guard never prints the command, file contents or environment values. It is
a guardrail against mistakes, not a sandbox: code running as the same user can
still reach anything that user can.
"""
from __future__ import annotations

import bisect
import fnmatch
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

MAX_DEPTH = 8
PUSH_FLAGS = {"-f", "--force", "--mirror", "--delete", "-d", "--tags", "--all", "--prune",
              "--follow-tags", "--force-if-includes"}
PUSH_VALUE_FLAGS = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}
GIT_VALUE_FLAGS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--config-env"}
BRANCH = r"(?!refs/)(?![-.])[\w./-]+"
PLAIN_REFSPEC = re.compile(rf"(?:(?:HEAD|{BRANCH}):)?(?:refs/heads/)?{BRANCH}")
PLAIN_REMOTE = re.compile(r"(?!-)[\w.@:/~%-]+")
TAG_NAME = re.compile(r"v?\d+(?:\.\d+)+(?:[-+.][\w.-]*)?", re.I)
# Settings that change what or where a plain push sends.
PUSH_CONFIG = re.compile(r"remote\..+\.(mirror|push|pushurl|receivepack)|url\..+\.pushinsteadof|push\..+", re.I)
# oh-my-zsh git plugin names (loaded in the Claude Bash tool) that push or wipe work.
PUSH_ALIASES = {"gp", "gpd", "gpf", "gpf!", "gpoat", "gpod", "gpristine", "gpsup", "gpsupf", "gpu", "gpv",
                "ggpush", "ggp", "ggf", "ggfl", "ggpnp"}

DOTENV = re.compile(r"(^|/)\.env(\.[^/]*)?$")
CREDENTIAL = re.compile(
    r"(^|/)\.claude\.json(\.[^/]*)?$"                         # Claude config, with MCP tokens
    r"|(\.claude|CLAUDE_CONFIG_DIR)\}?/\.credentials\.json$"  # Claude Code login
    r"|(\.codex|CODEX_HOME)\}?/auth\.json$"                   # Codex login
    r"|(^|/)(gh|CLI)/hosts\.yml$|GH_CONFIG_DIR\}?/hosts\.yml$"  # GitHub CLI tokens (Windows: `GitHub CLI`)
    r"|(^|/)\.git-credentials$|(^|/)\.(aws|gnupg)(/|$)|(^|/)\.ssh(/(?!.*\.pub$)|$)")
SAFE_SECRET_SUFFIXES = (".example", ".template", ".sample")
# The part of a credential path that makes it secret, for globs such as `~/.codex/*.json`.
CREDENTIAL_SAMPLES = (".claude.json", ".claude/.credentials.json", ".codex/auth.json", "gh/hosts.yml",
                      ".git-credentials", ".aws/credentials", ".gnupg/pubring.kbx", ".ssh/id_ed25519")
CREDENTIAL_TEXT = re.compile(
    r"(?<![\w./-])op(?:\.exe)?(?:\s+-[\w-]+(?:[=\s]+(?!-)\S+)?){0,16}\s+(?:read|inject|item|document)\b"
    r"|(?<![\w./-])op(?:\.exe)?\s[^\n;&|]{0,400}--no-masking"
    r"|\bgh\s+auth\s+token\b|\bgh\s+auth\s+status\b[^\n;&|]{0,400}\s(?:-t|--show-token)\b"
    r"|\bgit\s+credential(?:-\w+)?\s+(?:fill|get)\b", re.I)
# Git text anywhere, even inside interpreter code: `git`, its global options, then a subcommand.
# Each option must match one way only (`-c` also covers `-C` under re.I), or the scan backtracks exponentially.
_SEP = r"[\s'\",]+"
_VALUE = r"(?:(?<=[\"'])[^'\"\n;&|]+(?=[\"'])|[^\s'\",;&|]+)"  # a quoted value may hold spaces
_OPTION = rf"(?:(?:-c|--git-dir|--work-tree|--namespace|--config-env){_SEP}(?!-){_VALUE}|-[\w-]+(?:=[^\s'\",;&|]*)?)"
_GIT = rf"(?<![\w.-])git(?:\.exe)?(?:{_SEP}{_OPTION}){{0,16}}{_SEP}"  # bounded: repeated starts stay linear
PUSH_TEXT = re.compile(
    rf"{_GIT}(?:(?:subtree|lfs){_SEP})?(?:push|send-pack|http-push)\b|(?<![\w.-])git-(?:push|send-pack|http-push)\b"
    r"|\bgh\s+repo\s+delete\b|\bgh\s+pr\s+merge\b[^\n;&|]{0,400}\s--admin\b"
    r"|\bgh\s+api\b[^\n;&|]{0,400}\s(?:-X[\s=]*|--method[\s=]+)DELETE\b"
    r"|\bgh\s+api\s+graphql\b[^;&|]{0,4000}?\b(?:deleteRef|updateRefs?|createRef)\b", re.I)
ALIAS_TEXT = re.compile(rf"(?<![\w./!-])(?:{'|'.join(re.escape(a) for a in sorted(PUSH_ALIASES, key=len, reverse=True))})"
                        r"(?![\w./!-])")
TAG_TEXT = re.compile(rf"{_GIT}tag\b", re.I)
GIT_ENV = re.compile(r"\bGIT_(CONFIG\w*|DIR|WORK_TREE|NAMESPACE)\b")
TOKEN = re.compile(r"(?:[^\s;&|()<>'\"`=@:,{}]|\{[^{}\s;&|'\"]*\})+")  # a path-like word; braces stay whole
KINDS = ("dotenv", "credential", "push", "alias")
RISKY = re.compile(r"\b(push|rm|stow|consent)\b")
OP_READS = {"read", "inject", "item", "document"}
SHELLS = {"bash", "sh", "zsh", "dash", "ksh", "mksh", "fish"}
# Programs that run the rest of their words as a command. Their options are not
# all known, so every later word is also tried as the start of that command.
WRAPPERS = {"sudo", "doas", "run0", "pkexec", "command", "builtin", "exec", "env", "nice", "ionice", "time",
            "nohup", "setsid", "stdbuf", "timeout", "xargs", "watch", "flock", "noglob", "nocorrect", "-",
            "with-secrets", "unbuffer", "chronic", "busybox", "systemd-run", "strace", "ltrace"}
FIND_EXEC = {"-exec", "-execdir", "-ok", "-okdir"}
RESERVED = {"!", "if", "then", "elif", "else", "fi", "do", "done", "while", "until", "case", "esac", "for",
            "foreach", "select", "coproc", "always"}
ASSIGNMENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?\+?=.*", re.S)
# Programs that only name, create or describe a file; they never show its contents.
NAMES_ONLY = {"echo", "printf", "print", "touch", "ls", "stat", "du", "test", "[", "[[", "chmod", "mkdir",
              "test-path", "write-host", "write-output"}
WRITERS = {"set-content", "add-content", "new-item", "out-file"}  # PowerShell cmdlets that write the named file
ECHOES = {"echo", "printf", "print"}

SECRET_REASON = "secret files (.env*) and credential stores are never read or shown; use with-secrets"
PLAIN_PUSH = "git push runs only in the plain form `git push [-u] [remote] [branch]` as its own command"
ALIAS_REASON = "zsh git aliases hide what they push or reset; write the git command itself"
HIDDEN = "; text that only mentions it belongs in a file (for example `git commit -F <file>`)"

# Workflow opt-in. Hook input has no field that tells a typed prompt from a relayed
# one, so only a prompt that starts with the keyword counts (see docs/ai.md).
GRANT_DIR = "workflow-grants"
GRANT_TTL = 6 * 3600  # seconds
GRANT_REASON = "only the user grants the workflow opt-in; its state directory is off limits"
SESSION_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}")
OPT_IN = re.compile(r"\s*(?:ultracode\b|/workflow-authoring(?:\s|$))", re.I)
# The keyword anywhere, as a word. A scheduled prompt or a message to a session can
# arrive as a prompt of this session, and the hook cannot see where a prompt came from.
OPT_IN_TEXT = re.compile(r"(?<![\w-])ultracode(?![\w-])|/workflow-authoring(?![\w-])", re.I)
OPT_IN_REASON = ("text that starts a workflow opt-in (`ultracode`, `/workflow-authoring`) never goes into a "
                 "scheduled prompt, a message or a shell command; only the user types it (to find it in files, "
                 "use the Grep tool)")
# Tools that send text into a session as a prompt; MCP tools may do the same.
PROMPT_SENDERS = {"CronCreate", "ScheduleWakeup", "RemoteTrigger", "SendMessage"}
# The inbox socket of this session (Linux and macOS default directory: /tmp/cc-socks-<uid>).
MESSAGING = re.compile(r"CLAUDE_CODE_MESSAGING_|cc-socks-", re.I)
MESSAGING_REASON = "shell commands never use the session messaging socket; only the user sends to a session"


def home_variants() -> set[str]:
    home = os.path.expanduser("~").rstrip("/")
    dotfiles = os.environ.get("DOTFILES_DIR", f"{home}/.dotfiles").rstrip("/")
    home, dotfiles = home.replace("\\", "/"), dotfiles.replace("\\", "/")
    return {"/", "/*", "~", "~/*", "$HOME", "$HOME/*", "${HOME}", "${HOME}/*", home, home + "/*",
            "~/.dotfiles", "$HOME/.dotfiles", "${HOME}/.dotfiles", dotfiles, "C:", "C:/"}


def normalized(word: str) -> str:
    word = re.sub(r"^\$\{HOME[^}]*\}", "$HOME", word)  # ${HOME:?}, ${HOME%/}
    return word.rstrip("/") or "/"


# --- Mentions of secrets and publication -------------------------------------------------------

def expand_braces(word: str, limit: int = 32) -> list[str]:
    """`.en{v,}` -> `.env`, `.en`; a word with many brace groups is left as it is."""
    if word.count("{") > 8:
        return [word]
    pending, found = [word], []
    while pending and len(found) < limit:
        current = pending.pop()
        match = re.search(r"\{([^{}]*,[^{}]*)\}", current)
        if not match:
            found.append(current)
            continue
        pending += [current[:match.start()] + part + current[match.end():] for part in match.group(1).split(",")]
    return found or [word]


def glob_matches(pattern: str, sample: str, dotted: bool = True) -> bool:
    """Whether a shell glob may expand to sample; with dotted, a wildcard never matches a leading dot."""
    parts, names = pattern.split("/"), sample.split("/")
    return len(parts) >= len(names) and all(
        (not dotted or name[:1] != "." or part[:1] == ".") and fnmatch.fnmatchcase(name, part)
        for part, name in zip(parts[-len(names):], names))


def secret_kind(token: str) -> str | None:
    """'credential' or 'dotenv' when a path-like token names one, directly, with braces or as a glob."""
    kinds = set()
    for name in expand_braces(token):
        if name.endswith(SAFE_SECRET_SUFFIXES):
            continue
        glob, last = bool(re.search(r"[*?[]", name)), name.rsplit("/", 1)[-1]
        if CREDENTIAL.search(name) or glob and any(glob_matches(name, s) for s in CREDENTIAL_SAMPLES):
            kinds.add("credential")
        # `find -name` and `grep --include` match a leading dot, so `*.env` counts too.
        elif DOTENV.search(name) or glob and (last.startswith(".env") or any(
                glob_matches(last, s, dotted="env" not in last.lower()) for s in (".env", ".env.local"))):
            kinds.add("dotenv")
    return "credential" if "credential" in kinds else "dotenv" if kinds else None


def secret_kinds(text: str) -> set[str]:
    flat = text.replace("\\", "/")
    kinds = {kind for match in TOKEN.finditer(flat) if (kind := secret_kind(match.group()))}
    return kinds | ({"credential"} if CREDENTIAL_TEXT.search(flat) else set())


def mentions(text: str) -> list[tuple[str, tuple[int, int]]]:
    """Each secret or publication mention in raw text, with its kind and its span."""
    flat = text.replace("\\", "/")  # same length, so spans still point into text
    found = [(kind, match.span()) for match in TOKEN.finditer(flat) if (kind := secret_kind(match.group()))]
    found += [("credential", match.span()) for match in CREDENTIAL_TEXT.finditer(flat)]
    found += [("push", match.span()) for match in PUSH_TEXT.finditer(text)]
    return found + [("alias", match.span()) for match in ALIAS_TEXT.finditer(text)]


Span = "tuple[int, int] | None"


class Context:
    """One command line: the spans the parser accounted for, and facts about the whole line."""

    def __init__(self, command: str) -> None:
        self.credits: dict[str, list[tuple[int, int]]] = {kind: [] for kind in KINDS}
        self.makes_tags = bool(TAG_TEXT.search(command))
        self.git_env = bool(GIT_ENV.search(command))

    def credit(self, spans: list, *kinds: str) -> None:
        """Mentions inside these spans are harmless for these kinds (all kinds by default)."""
        for span in filter(None, spans):
            for kind in kinds or KINDS:
                self.credits[kind].append(span)

    def unaccounted(self, command: str) -> str | None:
        """Fail closed: a mention outside every credited span blocks the command."""
        merged = {}
        for kind, spans in self.credits.items():
            merged[kind] = []
            for start, end in sorted(spans):
                if merged[kind] and start <= merged[kind][-1][1]:
                    merged[kind][-1] = (merged[kind][-1][0], max(end, merged[kind][-1][1]))
                else:
                    merged[kind].append((start, end))
        for kind, (start, end) in mentions(command):
            spans = merged[kind]
            index = bisect.bisect_right(spans, (start, float("inf"))) - 1
            if index < 0 or spans[index][1] < end:
                return (SECRET_REASON if kind in ("dotenv", "credential") else PLAIN_PUSH) + HIDDEN
        return None


# --- POSIX and zsh command reader ----------------------------------------------------------------

WORD_END = set(" \t\r\n;&|()<>")
REDIRECTIONS = ("&>>", "<<<", "<<-", "&>", ">>", ">|", ">!", "<>", "<&", ">&", "<<", "<", ">")
OPERATORS = (";;&", ";;", ";&", "&&", "||", "|&", "&|", "&!", ";", "&", "|", "(", ")", "\n")


def ansi_c(body: str) -> str:
    """Decode a $'...' string, so `$'\\x2df'` is seen as `-f`."""
    simple = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "e": "\x1b", "E": "\x1b", "f": "\f", "v": "\v"}

    def decode(match: re.Match) -> str:
        code = match.group(1)
        if code[0] in "xuU":
            return chr(int(code[1:], 16))
        if code[0] in "01234567":
            return chr(int(code, 8))
        if code[0] == "c":
            return chr(ord(code[1]) & 31)
        return simple.get(code, code)
    return re.sub(r"\\(x[0-9A-Fa-f]{1,2}|u[0-9A-Fa-f]{1,4}|U[0-9A-Fa-f]{1,8}|[0-7]{1,3}|c.|.)", decode, body,
                  flags=re.S)


class Simple:
    """One simple command: its words and their spans, the files it writes and the text its stdin gets."""

    def __init__(self, nested: bool = False) -> None:
        self.words: list[str] = []
        self.spans: list = []
        self.writes: list[tuple[str, Span]] = []
        self.stdin: list[list[tuple[str, list]]] = []  # (text, spans); here-doc bodies arrive at the line end
        self.inherited = 0                            # leading stdin entries that came through a pipe
        self.piped = False                            # its output feeds the next command
        self.nested = nested                          # inside a substitution: its output becomes words

    def add(self, word: str, span: Span) -> Simple:
        self.words.append(word)
        self.spans.append(span)
        return self


class ShellParser:
    """Reads a command line the way the shell splits it: quotes, escapes, comments,
    substitutions (also inside double quotes), arithmetic, case, here-docs and grouping.
    It finds every simple command the line runs; it does not expand variables. Spans
    point into the checked text, or are None where the text was unescaped from it."""

    def __init__(self, text: str, level: int = 0, offset: int | None = 0) -> None:
        self.text, self.level, self.offset, self.commands, self.comments = text, level, offset, [], []

    def at(self, start: int, end: int) -> Span:
        return None if self.offset is None else (start + self.offset, end + self.offset)

    def parse(self) -> list[Simple]:
        self.block(0, None)
        return self.commands

    def block(self, i: int, closer: str | None) -> int:
        """Read commands from i up to an unmatched closer; return the index after it."""
        text, tokens, heredocs, depth, cases, start = self.text, [], [], 0, 0, True
        while i < len(text):
            ch = text[i]
            if ch == "\\" and text.startswith("\n", i + 1):
                i += 2
            elif ch in " \t\r":
                i += 1
            elif ch == "#":
                end = text.find("\n", i)
                end = len(text) if end < 0 else end
                self.comments.append(self.at(i, end))  # never run
                i = end
            elif ch == "\n":
                tokens.append(("op", "\n", None))
                i, heredocs, start = self.heredoc_bodies(i + 1, heredocs), [], True
            elif ch == ")" and closer and not depth and not cases:
                self.group(tokens, True)
                return i + 1
            elif start and text.startswith("((", i) and (end := self.arithmetic(i + 2)):
                i = end  # an arithmetic command runs only its substitutions
            elif text.startswith(("<(", ">("), i):
                word_start = i
                value, i = self.word(i)
                tokens.append(("word", value, self.at(word_start, i)))
                start = False
            elif op := next((r for r in REDIRECTIONS if text.startswith(r, i)), None):
                i += len(op)
                if op in ("<<", "<<-"):
                    while i < len(text) and text[i] in " \t":
                        i += 1
                    word_start = i
                    delimiter, i = self.word(i) if i < len(text) and text[i] not in WORD_END else ("", i)
                    holder: list = []
                    heredocs.append((holder, delimiter, op == "<<-", not re.search(r"['\"\\]", text[word_start:i])))
                    tokens.append(("heredoc", holder, None))
                else:
                    tokens.append(("redir", op, None))
            elif op := next((o for o in OPERATORS if text.startswith(o, i)), None):
                if not (cases and op in "()"):  # case patterns end with `)`
                    depth = max(0, depth + (op == "(") - (op == ")"))
                tokens.append(("op", op, None))
                i, start = i + len(op), True
            else:
                word_start = i
                value, i = self.word(i)
                raw = text[word_start:i]
                if raw in ("{", "}"):  # reserved words that group commands
                    tokens.append(("op", raw, None))
                    start = True
                elif not (i < len(text) and text[i] in "<>" and re.fullmatch(r"\d+|\{\w+\}", raw)):
                    if start and raw in ("case", "esac"):
                        cases = cases + 1 if raw == "case" else max(0, cases - 1)
                    tokens.append(("word", value, self.at(word_start, i)))  # a number glued to `>` is an fd
                    start = False
        if closer:
            raise ValueError("unterminated substitution")
        self.group(tokens, self.level > 0)
        return i

    def group(self, tokens: list, nested: bool) -> None:
        command, pending = Simple(nested), None
        for kind, value, span in tokens:
            if kind == "redir":
                pending = value
            elif kind == "heredoc":
                command.stdin.append(value)
            elif kind == "word" and pending:
                if pending in ("<", "<>"):
                    self.commands.append(Simple(nested).add("<", None).add(value, span))  # an input file is read
                elif pending == "<<<":
                    command.stdin.append([(value, [span])])
                elif pending != "<&":
                    command.writes.append((value, span))
                pending = None
            elif kind == "word":
                command.add(value, span)
            else:
                command.piped = value in ("|", "|&")
                if command.words or command.stdin or command.writes:
                    self.commands.append(command)
                follow = Simple(nested)
                if command.piped:  # a shell at the end of a pipe runs what it reads
                    follow.stdin = list(command.stdin)
                    if command.words and os.path.basename(command.words[0]) in ECHOES:
                        follow.stdin.append([(" ".join(command.words[1:]), command.spans[1:])])
                    follow.inherited = len(follow.stdin)
                command = follow
        if command.words or command.stdin or command.writes:
            self.commands.append(command)

    def heredoc_bodies(self, i: int, pending: list) -> int:
        text = self.text
        for holder, delimiter, strip_tabs, expands in pending:
            start, lines = i, []
            while i < len(text):
                end = text.find("\n", i)
                end = len(text) if end < 0 else end
                line, i = text[i:end], end + 1
                if (line.lstrip("\t") if strip_tabs else line) == delimiter:
                    break
                lines.append(line)
            body = "\n".join(lines)
            if expands:  # an unquoted here-doc still runs its substitutions
                sub = ShellParser(body, self.level + 1, None if self.offset is None else self.offset + start)
                sub.expansions()
                self.commands += sub.commands
            holder.append((body, [self.at(start, start + len(body))]))
        return min(i, len(text))

    def expansions(self) -> None:
        """Collect the commands of the substitutions in text that is otherwise data."""
        i = 0
        while i < len(self.text):
            if self.text[i] == "\\":
                i += 2
            elif self.text[i] in "$`":
                i = self.expansion(i)[1]
            else:
                i += 1

    def arithmetic(self, i: int) -> int | None:
        """The index after the `))` that ends an arithmetic body, or None when it is not one."""
        text, depth = self.text, 0
        while i < len(text):
            if text[i] in "$`":
                i = self.expansion(i)[1]
                continue
            if text[i] == "(":
                depth += 1
            elif text[i] == ")":
                if not depth:
                    return i + 2 if text.startswith("))", i) else None
                depth -= 1
            i += 1
        return None

    def word(self, i: int) -> tuple[str, int]:
        text, out = self.text, []
        if text.startswith(("<(", ">(", "=("), i):  # process substitution
            return "$(…)", self.block(i + 2, ")")
        while i < len(text) and text[i] not in WORD_END:
            ch = text[i]
            if ch == "\\":
                if not text.startswith("\n", i + 1):
                    out.append(text[i + 1:i + 2])
                i += 2
            elif ch == "'":
                end = text.find("'", i + 1)
                if end < 0:
                    raise ValueError("unterminated quote")
                out.append(text[i + 1:end])
                i = end + 1
            elif text.startswith("$'", i):
                end = i + 2
                while end < len(text) and text[end] != "'":
                    end += 2 if text[end] == "\\" else 1
                if end >= len(text):
                    raise ValueError("unterminated quote")
                out.append(ansi_c(text[i + 2:end]))
                i = end + 1
            elif ch == '"' or text.startswith('$"', i):
                value, i = self.double_quoted(i + (2 if ch == "$" else 1))
                out.append(value)
            elif ch in "$`":
                value, i = self.expansion(i)
                out.append(value)
            else:
                out.append(ch)
                i += 1
        return "".join(out), i

    def double_quoted(self, i: int) -> tuple[str, int]:
        text, out = self.text, []
        while i < len(text):
            ch = text[i]
            if ch == '"':
                return "".join(out), i + 1
            if ch == "\\" and i + 1 < len(text):
                if text[i + 1] != "\n":
                    out.append(text[i + 1] if text[i + 1] in '$`"\\' else text[i:i + 2])
                i += 2
            elif ch in "$`":
                value, i = self.expansion(i)
                out.append(value)
            else:
                out.append(ch)
                i += 1
        raise ValueError("unterminated double quote")

    def expansion(self, i: int) -> tuple[str, int]:
        """Read a `$...` or backtick expansion; commands inside are collected, and a
        command substitution becomes the placeholder `$(…)` because its output is unknown."""
        text = self.text
        if text[i] == "`":
            end, body = i + 1, []
            while end < len(text) and text[end] != "`":
                if text[end] == "\\" and text[end + 1:end + 2] in ("$", "`", "\\"):
                    end += 1
                body.append(text[end])
                end += 1
            if end >= len(text):
                raise ValueError("unterminated backtick")
            code = "".join(body)
            offset = self.offset + i + 1 if self.offset is not None and code == text[i + 1:end] else None
            sub = ShellParser(code, self.level + 1, offset)
            self.commands += sub.parse()
            self.comments += sub.comments
            return "$(…)", end + 1
        if text.startswith("$((", i) and (end := self.arithmetic(i + 3)):
            return "$(…)", end
        if text.startswith("$(", i):
            return "$(…)", self.block(i + 2, ")")
        if not text.startswith("${", i):
            return "$", i + 1
        out, end, depth = ["${"], i + 2, 1
        while end < len(text):
            ch = text[end]
            if ch == "\\":
                out.append(text[end:end + 2])
                end += 2
            elif ch == "'":
                close = text.find("'", end + 1)
                if close < 0:
                    raise ValueError("unterminated quote")
                out.append(text[end + 1:close])
                end = close + 1
            elif ch == '"':
                value, end = self.double_quoted(end + 1)
                out.append(value)
            elif ch in "$`":
                value, end = self.expansion(end)
                out.append(value)
            else:
                depth += (ch == "{") - (ch == "}")
                out.append(ch)
                end += 1
                if not depth:
                    return "".join(out), end
        raise ValueError("unterminated ${")


# --- Checks --------------------------------------------------------------------------------------

def check_bash(command: str, depth: int = 0) -> str | None:
    if depth > MAX_DEPTH:
        return "nested shells are too deep to check; run the command directly"
    if reason := consent_write(command):
        return reason
    try:
        parser = ShellParser(command)
        commands = parser.parse()
    except (ValueError, RecursionError):
        if mentions(command) or RISKY.search(command):
            return "command could not be parsed safely; simplify the quoting"
        return None
    context = Context(command)
    context.credit(parser.comments)
    for simple in commands:
        if reason := check_simple(simple, depth, context):
            return reason
    return context.unaccounted(command)


def command_start(words: list[str]) -> tuple[list[str], bool]:
    """Drop reserved words and assignments; say whether an assignment was dropped."""
    index, assigned = 0, False
    while index < len(words):
        if words[index] in RESERVED:
            index += 1
        elif words[index] in ("function", "repeat"):  # `function name`, zsh `repeat N`
            index += 2
        elif ASSIGNMENT.fullmatch(words[index]):
            index, assigned = index + 1, True
        else:
            break
    return words[index:], assigned


def candidates(words: list[str]) -> list[int]:
    """Where a command may start: the command itself and, after a wrapper, `find -exec` or
    `op run`, every later word (wrapper option values are not all known)."""
    first = command_start(words)[0]
    if not first:
        return []
    program = os.path.basename(first[0])
    if program in WRAPPERS:
        start = 1
    elif program == "op" and first[1:2] == ["run"]:
        start = 2
    elif program == "find":
        start = next((i + 1 for i, word in enumerate(first) if word in FIND_EXEC), len(first))
    else:
        start = len(first)
    found = [len(words) - len(first)]
    for index in range(start, len(first)):
        if not first[index].startswith("-") and (rest := command_start(first[index:])[0]):
            found.append(len(words) - len(rest))
    return found


def check_simple(simple: Simple, depth: int, context: Context) -> str | None:
    context.credit([span for _, span in simple.writes], "dotenv")  # a credential store is never written
    starts = candidates(simple.words)
    # Text that ends on the screen or in a file is data; text piped on or substituted may become code.
    data = not simple.piped and not simple.nested
    program = os.path.basename(simple.words[starts[0]]) if starts else ""
    if program not in SHELLS | {"eval"} and (data or program not in ECHOES):
        context.credit(simple.spans[1:], "alias")  # an alias name as an argument is only data
    copies = data and starts and os.path.basename(simple.words[starts[0]]) in ("cat", "tee")
    for index, holder in enumerate(simple.stdin):
        for _, spans in holder:
            own = index >= simple.inherited
            context.credit(spans, "alias", *(("dotenv", "credential") if copies and own else ()))
    plain = depth == 0 and not simple.nested and not command_start(simple.words)[1]
    for index, start in enumerate(starts):
        words, spans = simple.words[start:], simple.spans[start:]
        if index and re.search(r"\s", words[0]):  # `watch 'cmd'` and friends run a joined string
            reason = nested(" ".join(words), spans, depth, context)
        else:
            reason = check_segment(words, spans, depth, context, simple.stdin, plain and not index, data)
        if reason:
            return reason
    return None


def nested(text: str, spans: list, depth: int, context: Context, powershell: bool = False) -> str | None:
    """Check code that another command runs; once it passes, its mentions are accounted for,
    unless it runs a substitution's output, which the nested check never saw."""
    reason = (check_powershell if powershell else check_bash)(text, depth + 1)
    if not reason and "$(…)" not in text:
        context.credit(spans)
    return reason


def shell_code(words: list[str], spans: list, stdin: list, depth: int, context: Context) -> tuple[str | None, set[int]]:
    """Check the code a shell runs: its -c string, or its stdin when it has no -c."""
    code: set[int] = set()
    for index, word in enumerate(words[1:], 1):
        if word.startswith("--command="):
            return nested(word.split("=", 1)[1], [spans[index]], depth, context), {index}
        if re.fullmatch(r"-[a-zA-Z]*c[a-zA-Z]*", word) or word == "--command":
            code = {i for i in range(index + 1, len(words)) if not words[i].startswith("-")}
            break
    texts = [(words[i], [spans[i]]) for i in sorted(code)] if code else [item for holder in stdin for item in holder]
    for text, span in texts:
        if reason := nested(text, span, depth, context):
            return reason, code
    return None, code


def check_segment(words: list[str], spans: list, depth: int, context: Context, stdin: list = (),
                  plain: bool = False, data: bool = True) -> str | None:
    """Check one simple command, already split into POSIX-style words with their spans."""
    if not words:
        return None
    program = os.path.basename(words[0])
    if program in PUSH_ALIASES:
        return ALIAS_REASON
    if program in ("git-push", "git-send-pack", "git-http-push") or ("$" in words[0] and "push" in words[1:]):
        return PLAIN_PUSH
    if program in SHELLS:
        reason, code = shell_code(words, spans, list(stdin), depth, context)
        if reason:
            return reason
        kept = [index for index in range(len(words)) if index not in code]
        words, spans = [words[index] for index in kept], [spans[index] for index in kept]
    if program == "eval":
        return nested(" ".join(words[1:]), spans[1:], depth, context)
    if program == "git" and (reason := git_command(words, spans, context, plain)):
        return reason
    if program == "gh" and (reason := gh_command(words[1:])):
        return reason
    if program == "stow" and any(ch in arg for arg in words[1:] for ch in "*?["):
        return "never run Stow over a glob of packages; name each package"
    if program == "rm" and any(re.fullmatch(r"-[a-zA-Z]*[rR][a-zA-Z]*", a) or a == "--recursive"
                               for a in words[1:]):
        if {normalized(w) for w in words[1:]} & home_variants():
            return "recursive deletion of HOME, the dotfiles checkout or / is never allowed"
    head = words[1:words.index("--")] if "--" in words else words[1:]  # `op run ... -- cmd` runs cmd
    if program == "op" and (OP_READS & set(head) or "--no-masking" in head):
        return "read secrets only through with-secrets for the process that needs them"
    if "consent" in words and any(os.path.basename(w) == "tessera.py" for w in words):
        return "provider consent is granted by the user in their own terminal"
    return secret_use(program, words, spans, context, data)


def git_parts(words: list[str]) -> tuple[list[str], str, list[str]]:
    """Split `git [global options] subcommand args`."""
    index = 1
    while index < len(words) and words[index].startswith("-"):
        index += 2 if words[index] in GIT_VALUE_FLAGS else 1
    return words[1:index], (words[index] if index < len(words) else ""), words[index + 1:]


def git_command(words: list[str], spans: list, context: Context, plain: bool) -> str | None:
    options, sub, args = git_parts(words)
    index, repo, simple_options = 0, [], True
    while index < len(options):
        option, value = options[index], options[index + 1] if index + 1 < len(options) else ""
        if (option in ("-c", "--config-env") and value.lower().startswith("alias.")) or \
                option.lower().startswith("--config-env=alias."):
            return "inline git aliases are never allowed; write the git command itself"
        if option == "-C":
            repo += ["-C", value]
        simple_options = simple_options and option in ("-C", "--no-pager")
        index += 2 if option in GIT_VALUE_FLAGS else 1
    if sub == "config":
        for key, value in zip(args, args[1:]):
            if key.lower().startswith("alias.") and (value.startswith("!") or re.search(r"\bpush\b", value)):
                return "git aliases that push or run shell commands are defined by the user"
            if PUSH_CONFIG.fullmatch(key):
                return "git settings that change what a push sends are set by the user"
    if sub == "remote" and (any(arg.startswith("--mirror") for arg in args) or {"set-url", "--push"} <= set(args)):
        return "git settings that change what a push sends are set by the user"
    if sub == "credential" and {"fill", "get"} & set(args):
        return SECRET_REASON
    if sub in ("send-pack", "http-push") or (sub in ("subtree", "lfs") and "push" in args):
        return PLAIN_PUSH
    if sub != "push":
        return None
    if context.makes_tags:
        return "git push of a tag is never allowed; run `git tag` and `git push` as separate commands"
    reason = git_push(args, repo, plain and simple_options and not context.git_env)
    if not reason and None not in spans:  # a push mention spans several words; only `push` is credited
        context.credit([(spans[0][0], spans[-1][1])], "push")
    return reason


def git_push(args: list[str], repo: list[str], plain: bool) -> str | None:
    positional, flags, skip = [], [], False
    for arg in args:
        if skip:
            skip = False
            continue
        name = arg.split("=", 1)[0]
        if name in PUSH_FLAGS or name.startswith("--force") or re.fullmatch(r"-[a-zA-Z]*[fd][a-zA-Z]*", arg):
            return "git push with force, delete, mirror, tags or all refs is never allowed"
        if arg.startswith("-"):
            flags.append(arg)
            skip = arg in PUSH_VALUE_FLAGS
        else:
            positional.append(arg)
    refspecs = positional[1:]
    if len(refspecs) > 1:
        return "publish one verified ref per push"
    if any(ref.startswith(("+", ":")) for ref in refspecs):
        return "forced or deleting refspecs are never allowed"
    if any("*" in ref for ref in refspecs):
        return "wildcard refspecs are never allowed"
    if any(is_tag(ref, repo) for ref in refspecs):
        return "git push of a tag is never allowed"
    if (not plain or set(flags) - {"-u", "--set-upstream"} or positional and not PLAIN_REMOTE.fullmatch(positional[0])
            or refspecs and not PLAIN_REFSPEC.fullmatch(refspecs[0])):
        return PLAIN_PUSH
    return None


def is_tag(ref: str, repo: list[str]) -> bool:
    """A refspec side that names a tag: refs/tags/, a version number or an existing local tag."""
    for name in filter(None, ref.split(":")):
        if name.startswith("refs/tags/") or TAG_NAME.fullmatch(name.removeprefix("refs/heads/")):
            return True
        if not re.fullmatch(BRANCH, name):
            continue
        try:
            found = subprocess.run(["git", *repo, "show-ref", "--verify", "--quiet", f"refs/tags/{name}"],
                                   stdin=subprocess.DEVNULL, capture_output=True, timeout=3)
        except (OSError, subprocess.SubprocessError):
            continue
        if found.returncode == 0:
            return True
    return False


def gh_command(args: list[str]) -> str | None:
    if args[:2] == ["repo", "delete"] or (args[:2] == ["pr", "merge"] and "--admin" in args):
        return "deleting repositories and admin merges are done by the user"
    if args[:2] == ["auth", "token"] or (args[:2] == ["auth", "status"] and {"-t", "--show-token"} & set(args)):
        return SECRET_REASON
    if args[:1] == ["api"]:
        method = ""
        for index, arg in enumerate(args):
            if arg in ("-X", "--method") and index + 1 < len(args):
                method = args[index + 1]
            elif arg.startswith(("--method=", "-X")) and arg not in ("-X", "--method"):
                method = arg.removeprefix("--method=").removeprefix("-X").lstrip("=")
        writes = method.upper() not in ("", "GET") or any(re.match(r"-[fF]|--(raw-)?field|--input", a) for a in args)
        refs = any(re.search(r"(^|/)git/(refs|tags)\b|\b(deleteRef|updateRefs?|createRef)\b", a) for a in args)
        if method.upper() == "DELETE" or (writes and refs):
            return "deleting or rewriting refs through the GitHub API is done by the user"
    return None


def secret_use(program: str, words: list[str], spans: list, context: Context, data: bool = True) -> str | None:
    """Block reading a secret file or credential store; naming it, or writing a dotenv file, is fine.
    Without data (output piped on or substituted), naming it counts as using it."""
    args, arg_spans = words[1:], spans[1:]
    kinds = [secret_kinds(word) for word in args]
    found = [index for index, kind in enumerate(kinds) if kind]
    if not found:
        return None
    lower, sub = program.lower(), git_parts(words)[1] if program == "git" else ""
    names = data and (lower in NAMES_ONLY or sub == "check-ignore" or (sub == "rm" and "--cached" in args))
    # `cp .env.example .env` writes the destination; only reading a secret is blocked.
    writes = lower in WRITERS or (lower in {"cp", "mv", "install"} and found == [len(args) - 1]
                                  and not any(re.fullmatch(r"-t.*|--target-directory(=.*)?", a) for a in args))
    if names or (writes and all(kinds[index] == {"dotenv"} for index in found)):
        context.credit([arg_spans[index] for index in found], *(("dotenv", "credential") if names else ("dotenv",)))
        return None
    return SECRET_REASON


CONSENT_WRITERS = re.compile(
    r"(>\|?|>>)\s*\S*provider-consent"                     # shell or PowerShell redirection into it
    r"|\b(cp|mv|tee|rm|install|ln|truncate|dd|touch|rsync|copy|move|del|ren)\b[^;&|]{0,400}provider-consent"
    r"|\bsed\b[^;&|]{0,400}\s-i[^;&|]{0,400}provider-consent"
    r"|\b(python3?|py|node|perl|ruby|bash|sh|zsh|pwsh|powershell)\b[^;&|]{0,400}\s(-c|-e|-Command)\b[^;&|]{0,400}provider-consent"
    r"|\b(set-content|add-content|out-file|new-item|copy-item|move-item|remove-item|rename-item"
    r"|clear-content|ni|cpi|mi|ri|rni|sc|ac)\b[^;&|]{0,400}provider-consent",
    re.I)


def consent_write(command: str) -> str | None:
    """Only writes to the consent file are the user's; reading or searching it is fine."""
    if "provider-consent" in command and CONSENT_WRITERS.search(command):
        return "provider consent is granted by the user in their own terminal"
    return None


# PowerShell: its own quoting and cmdlet names, mapped onto the POSIX checks.
PS_TOKEN = re.compile(r"""'(?:[^']|'')*'|"(?:[^"`]|`.)*"|\$\{[^}]*\}\S*|\|\||&&|[;|(){}\n]|[^\s;|(){}]+""")
PS_SEPARATORS = {";", "|", "||", "&&", "(", ")", "{", "}", "\n"}
PS_PROGRAMS = {
    "rm": {"remove-item", "ri", "rm", "del", "erase", "rd", "rmdir"},
    "cat": {"get-content", "gc", "cat", "type"},
    "cp": {"copy-item", "cpi", "cp", "copy"},
    "mv": {"move-item", "mi", "mv", "move"},
}
PS_HOME = re.compile(r"^(\$env:(userprofile|home)|\$\{env:(userprofile|home)\}|\$home|\$\{home\}"
                     r"|%userprofile%|%homedrive%%homepath%|~)(?=$|[\\/])", re.I)


def ps_word(token: str) -> str:
    if len(token) > 1 and token[0] == token[-1] == "'":
        token = token[1:-1].replace("''", "'")
    elif len(token) > 1 and token[0] == token[-1] == '"':
        token = re.sub(r"`(.)", r"\1", token[1:-1])
    token = PS_HOME.sub("~", token.replace("\\", "/"))
    return token


def check_powershell(command: str, depth: int = 0) -> str | None:
    if depth > MAX_DEPTH:
        return "nested shells are too deep to check; run the command directly"
    if reason := consent_write(command):
        return reason
    context = Context(command)
    segments_ps, current, skip, comment = [], [], False, -1
    for match in PS_TOKEN.finditer(command):
        token, span = match.group(), match.span()
        if span[0] < comment:
            continue
        if token.startswith("#"):  # a comment runs to the end of the line and never runs
            end = command.find("\n", span[0])
            comment = len(command) if end < 0 else end
            context.credit([(span[0], comment)])
        elif skip:
            skip = False
            context.credit([span], "dotenv")  # a redirection target is written
        elif re.fullmatch(r"[0-9*&]?>>?(&[0-9])?", token):
            skip = not token.endswith(("&1", "&2"))
        elif re.fullmatch(r"[0-9*&]?>>?\S+", token):
            context.credit([span], "dotenv")  # redirection with its target attached
        elif token in PS_SEPARATORS:
            if current:
                segments_ps.append((current, token == "|"))  # piped output may become code (`| iex`)
            current = []
        else:
            current.append((ps_word(token), span))
    if current:
        segments_ps.append((current, False))
    for segment, piped in segments_ps:
        while segment and segment[0][0] in {"&", "."}:
            segment = segment[1:]
        if not segment:
            continue
        words, spans = [word for word, _ in segment], [span for _, span in segment]
        context.credit(spans[1:], "alias")
        name = os.path.basename(words[0]).lower().removesuffix(".exe")
        if name in {"gp", "gpv"}:  # Get-ItemProperty(Value) here, not the zsh push aliases
            context.credit(spans[:1], "alias")
            continue
        if name in {"powershell", "pwsh"}:
            flags = [i for i, w in enumerate(words) if w.lower() in {"-command", "-c"}]
            if flags and flags[0] + 1 < len(words):
                if reason := nested(" ".join(words[flags[0] + 1:]), spans[flags[0] + 1:], depth, context, True):
                    return reason
            continue
        program = next((posix for posix, names in PS_PROGRAMS.items() if name in names), name)
        if name in {"iex", "invoke-expression"}:
            if reason := nested(" ".join(words[1:]), spans[1:], depth, context, True):
                return reason
            continue
        if name == "cmd":
            flags = [i for i, w in enumerate(words) if w.lower() in {"/c", "/k"}]
            if flags and (reason := nested(" ".join(words[flags[0] + 1:]), spans[flags[0] + 1:],
                                           depth, context, True)):
                return reason
            continue
        recursive = re.compile(r"-r(e(c(u(r(s(e)?)?)?)?)?)?(:\$true)?|/s", re.I)
        args = ["-r" if program == "rm" and recursive.fullmatch(w) else w for w in words[1:]]
        if reason := check_segment([program, *args], spans, depth, context, plain=depth == 0, data=not piped):
            return reason
    return context.unaccounted(command)


def strings(value) -> list[str]:
    """Every string inside a tool input, whatever its field names."""
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        return [text for item in value.values() for text in strings(item)]
    if isinstance(value, list):
        return [text for item in value for text in strings(item)]
    return []


def patch_paths(data) -> list[str]:
    """Files that a Codex apply_patch call adds, updates, deletes or moves to."""
    return [path for text in strings(data) for path in re.findall(r"^\*\*\* (?:(?:Add|Update|Delete) File|Move to): (.+)$", text, re.M)]


def grant_path(session) -> Path | None:
    """The opt-in marker of one session. Linux honors XDG_STATE_HOME; Windows uses
    %USERPROFILE%\\.local\\state, which MSIX apps do not virtualize."""
    if not (isinstance(session, str) and SESSION_ID.fullmatch(session)):
        return None
    base = os.environ.get("XDG_STATE_HOME", "") if os.name != "nt" else ""
    root = Path(base) if os.path.isabs(base) else Path.home() / ".local/state"
    return root / "dotfiles/ai" / GRANT_DIR / f"{session}.json"


def opted_in(event: dict) -> bool:
    if event.get("agent_id"):  # subagents never speak for the user
        return False
    if event.get("hook_event_name") == "UserPromptSubmit":
        return isinstance(event.get("prompt"), str) and OPT_IN.match(event["prompt"]) is not None
    # UserPromptExpansion fires only for a command the user typed, never for the Skill tool.
    return (event.get("hook_event_name") == "UserPromptExpansion"
            and event.get("expansion_type") == "slash_command"
            and event.get("command_name") == "workflow-authoring")


def record_grant(event: dict) -> str | None:
    path = grant_path(event.get("session_id"))
    if path is None or not opted_in(event):
        return None
    path.parent.mkdir(parents=True, exist_ok=True)
    now = time.time()
    for old in path.parent.glob("*.json"):  # expired markers of other sessions
        try:
            if now - old.stat().st_mtime > GRANT_TTL:
                old.unlink()
        except OSError:
            pass
    temporary = path.with_name(f".{path.stem}.{os.getpid()}.tmp")
    temporary.write_text(json.dumps({"granted_at": now}), encoding="utf-8")
    os.replace(temporary, path)
    return f"ai-guard: the user opted in to multi-agent workflows for this session ({GRANT_TTL // 3600} h)."


def workflow_granted(session) -> bool:
    path = grant_path(session)
    try:
        granted = json.loads(path.read_text(encoding="utf-8"))["granted_at"]
    except (AttributeError, OSError, ValueError, KeyError, TypeError):
        return False
    return isinstance(granted, (int, float)) and 0 <= time.time() - granted <= GRANT_TTL


def names_grants(text) -> bool:
    return isinstance(text, str) and GRANT_DIR in text.lower()


def carries_opt_in(data) -> bool:
    """Whether any string of a tool input holds the opt-in keyword. A cheap substring test
    comes first, so a normal MCP call costs almost nothing."""
    for text in strings(data):
        lower = text.lower()
        if ("ultracode" in lower or "workflow-authoring" in lower) and OPT_IN_TEXT.search(text):
            return True
    return False


def decide(event: dict) -> str | None:
    tool = event.get("tool_name")
    data = event.get("tool_input") or {}
    if tool == "Workflow" and os.environ.get("AI_ALLOW_WORKFLOW") != "1" and not workflow_granted(event.get("session_id")):
        return ("multi-agent workflows need the user's opt-in; ask the user, who can start a prompt "
                "with `ultracode` or run /workflow-authoring")
    if isinstance(tool, str) and (tool in PROMPT_SENDERS or tool.startswith("mcp__")):
        return OPT_IN_REASON if carries_opt_in(data) else None
    # Reads are blocked too: interpreter code cannot be told apart from a write.
    if tool in {"Bash", "Monitor", "PowerShell"} and names_grants(data.get("command")):
        return GRANT_REASON
    if tool in {"Bash", "Monitor", "PowerShell"} and isinstance(data.get("command"), str):
        if MESSAGING.search(data["command"]):
            return MESSAGING_REASON
        if carries_opt_in(data["command"]):
            return OPT_IN_REASON
    if tool in {"Write", "Edit", "MultiEdit"} and names_grants(data.get("file_path")):
        return GRANT_REASON
    if tool == "apply_patch" and any(names_grants(path) for path in patch_paths(data)):
        return GRANT_REASON
    if tool in {"Write", "Edit", "MultiEdit"} and "provider-consent" in str(data.get("file_path", "")):
        return "provider consent is granted by the user in their own terminal"
    if tool == "apply_patch" and any("provider-consent" in path for path in patch_paths(data)):
        return "provider consent is granted by the user in their own terminal"
    # Monitor runs a shell command in the background, with the same shell as Bash.
    if tool in {"Bash", "Monitor"} and isinstance(data.get("command"), str):
        # Codex on Windows may report PowerShell commands as Bash: check both there.
        return check_bash(data["command"]) or (check_powershell(data["command"]) if os.name == "nt" else None)
    if tool == "PowerShell" and isinstance(data.get("command"), str):
        return check_powershell(data["command"])
    return None


def main() -> int:
    for stream in (sys.stdin, sys.stdout, sys.stderr):
        # Windows defaults to the ANSI code page; hooks exchange UTF-8.
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return 0
    if not isinstance(event, dict):
        return 0
    if event.get("hook_event_name") in {"UserPromptSubmit", "UserPromptExpansion"}:
        # Exit 2 here would erase the user's prompt: always let it through.
        try:
            note = record_grant(event)
        except Exception:
            note = "ai-guard: the workflow opt-in could not be recorded; workflows stay blocked."
        if note:
            print(note)  # plain stdout on these events becomes context for Claude
        return 0
    if isinstance(event.get("cwd"), str) and os.path.isdir(event["cwd"]):
        os.chdir(event["cwd"])  # tag lookups run in the session's repository
    try:
        reason = decide(event)
    except Exception:  # an exit other than 0 or 2 would let the call run
        reason = "the guard failed on this input and blocks it; simplify the command"
    if reason:
        print(f"Blocked by ai-guard: {reason}.", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
