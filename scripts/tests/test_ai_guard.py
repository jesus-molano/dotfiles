"""Contract tests for the PreToolUse guard and the status line in ai/hooks."""
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest

HOOKS = Path(__file__).resolve().parents[2] / "ai/hooks"


def run(script, payload, env=None):
    return subprocess.run([sys.executable, str(HOOKS / script)], input=json.dumps(payload),
                          capture_output=True, text=True, env={**os.environ, **(env or {})})


def bash(command, env=None):
    return run("ai-guard.py", {"hook_event_name": "PreToolUse", "tool_name": "Bash",
                               "tool_input": {"command": command}}, env)


class GuardTest(unittest.TestCase):
    def assertBlocked(self, command, reason):
        result = bash(command)
        self.assertEqual(result.returncode, 2, command)
        self.assertIn(reason, result.stderr)
        self.assertNotIn(command, result.stderr, "The guard must not echo the command")

    def assertAllowed(self, command):
        result = bash(command)
        self.assertEqual((result.returncode, result.stderr), (0, ""), command)

    def test_ordinary_work_is_allowed(self):
        for command in ("git push origin main", "git push -u origin feature/x",
                        "git push origin 0123456789abcdef0123456789abcdef01234567:refs/heads/main",
                        "git status && git diff --check", "stow -t ~ shell git", "rm -rf build dist",
                        "cat .env.op.example", "with-secrets npm run deploy", "python3 tessera.py index --repo .",
                        "grep -rn TODO src", "echo 'see .env docs'"):
            self.assertAllowed(command)

    def test_destructive_publication_is_blocked(self):
        for command in ("git push --force origin main", "git push -f", "git push --force-with-lease",
                        "git push --mirror", "git push --delete origin old", "git push -d origin old",
                        "git push --tags", "git push --all", "git -C repo push -uf origin main",
                        "echo ok && git push --follow-tags"):
            self.assertBlocked(command, "git push")
        self.assertBlocked("git push origin :old", "refspecs")
        self.assertBlocked("FOO=1 git push origin +main", "refspecs")
        self.assertBlocked("git push origin a b", "one verified ref")

    def test_stow_glob_and_catastrophic_rm_are_blocked(self):
        self.assertBlocked("stow */", "Stow")
        self.assertBlocked("cd ~/.dotfiles; stow -t ~ *", "Stow")
        for target in ("~", "$HOME", "/", "~/.dotfiles", str(Path.home())):
            self.assertBlocked(f"rm -rf {target}", "recursive deletion")
        self.assertBlocked("sudo rm -r --no-preserve-root /", "recursive deletion")

    def test_secrets_and_self_consent_are_blocked(self):
        for command in ("cat .env", "less app/.env.local", "grep -r KEY .env.production",
                        "source ./.env", "cp .env /tmp/x"):
            self.assertBlocked(command, "secret files")
        self.assertBlocked("op read op://vault/item/field", "with-secrets")
        self.assertBlocked("python3 ai/skills/tessera/scripts/tessera.py consent --repo . --provider typesafe",
                           "consent")

    def test_workflow_needs_explicit_opt_in(self):
        event = {"tool_name": "Workflow", "tool_input": {"script": "x"}}
        self.assertEqual(run("ai-guard.py", event).returncode, 2)
        self.assertEqual(run("ai-guard.py", event, {"AI_ALLOW_WORKFLOW": "1"}).returncode, 0)

    def test_other_tools_and_bad_input_pass(self):
        self.assertEqual(run("ai-guard.py", {"tool_name": "Read", "tool_input": {"file_path": "x"}}).returncode, 0)
        result = subprocess.run([sys.executable, str(HOOKS / "ai-guard.py")], input="not json",
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)

    def test_unparseable_risky_command_is_blocked(self):
        self.assertBlocked("git push 'unterminated", "parsed")


class StatusLineTest(unittest.TestCase):
    def test_line_shows_model_project_context_and_limits(self):
        repo = Path(__file__).resolve().parents[2]
        result = run("statusline.py", {"model": {"display_name": "Opus"},
                                       "workspace": {"current_dir": str(repo)},
                                       "context_window": {"used_percentage": 41.6},
                                       "rate_limits": {"five_hour": {"used_percentage": 10},
                                                       "seven_day": {"used_percentage": 9.4}}})
        self.assertEqual(result.returncode, 0)
        line = result.stdout.strip()
        self.assertTrue(line.startswith(f"Opus · {repo.name}"), line)
        self.assertTrue(line.endswith("ctx 42% · 5h 10% · 7d 9%"), line)

    def test_missing_fields_do_not_fail(self):
        self.assertEqual(run("statusline.py", {}).stdout.strip(), "")


if __name__ == "__main__":
    unittest.main()
