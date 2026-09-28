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

    def test_redirections_heredocs_and_templates_are_not_false_positives(self):
        for command in ("git push -u origin feat 2>&1", "git push -u origin feat 2>&1 | tail -5",
                        "git push origin feat > /tmp/log", "git push origin feat &>/dev/null",
                        "cp .env.example .env", "echo '.env' >> .gitignore", "git check-ignore -q .env",
                        "git commit -F - <<'EOF'\nDon't push this yet; rm it later\nEOF",
                        "rm -rf node_modules", "cat .envrc", "grep -rn process.env src"):
            self.assertAllowed(command)

    def test_wrapped_and_nested_commands_are_still_checked(self):
        for command in ("bash -c 'git push --force origin main'", "timeout 60 git push --force",
                        "x=`git push -f`", "true# ; git push --force origin main", 'eval "git push --tags"',
                        "nohup git push --mirror &", "$(git push --force)"):
            self.assertBlocked(command, "git push")
        self.assertBlocked("rm -rf ~/.dotfiles/", "recursive deletion")
        self.assertBlocked('sh -c "cat .env"', "secret files")

    def test_consent_file_cannot_be_written_by_the_agent(self):
        self.assertBlocked("python3 -X utf8 t/tessera.py consent --repo .", "consent")
        self.assertBlocked("echo {} > ~/.local/share/tessera/projects/x/provider-consent.json", "consent")
        event = {"tool_name": "Write", "tool_input": {"file_path": "/h/.local/share/tessera/projects/k/provider-consent.json"}}
        self.assertEqual(run("ai-guard.py", event).returncode, 2)
        patch = {"tool_name": "apply_patch", "tool_input": {"command": "*** Add File: /h/tessera/projects/k/provider-consent.json"}}
        self.assertEqual(run("ai-guard.py", patch).returncode, 2)
        event["tool_input"]["file_path"] = "/h/.local/share/tessera/projects/k/catalog.json"
        self.assertEqual(run("ai-guard.py", event).returncode, 0)

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


def powershell(command):
    return run("ai-guard.py", {"tool_name": "PowerShell", "tool_input": {"command": command}})


class PowerShellGuardTest(unittest.TestCase):
    def test_blocks_the_same_limits_with_powershell_syntax(self):
        for command in ("git push --force origin main", "& git push -f", 'pwsh -Command "git push --tags"',
                        "Remove-Item -Recurse -Force $env:USERPROFILE", "rd /s /q C:\\", "ri -rec ~",
                        "Get-Content .env", "gc .\\app\\.env.local", 'cmd /c "type .env"',
                        "python tessera.py consent --repo . --provider typesafe"):
            self.assertEqual(powershell(command).returncode, 2, command)

    def test_allows_ordinary_powershell_work(self):
        for command in ("git push origin main", "git push origin feat 2>&1 | Out-Null",
                        "Remove-Item -Recurse .\\build", "Copy-Item .env.example .env",
                        "Write-Host 'it''s fine'; git status", "Get-ChildItem -Recurse src"):
            result = powershell(command)
            self.assertEqual((result.returncode, result.stderr), (0, ""), command)


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
