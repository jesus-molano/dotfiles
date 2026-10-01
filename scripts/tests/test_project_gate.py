"""Contract tests for the per-project verification gate in ai/hooks."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

GATE = Path(__file__).resolve().parents[2] / "ai/hooks/project-gate.py"


def load_gate():
    spec = importlib.util.spec_from_file_location("project_gate", GATE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def alive(pid):
    """True while the process exists and is not a zombie waiting for its parent."""
    try:
        return Path(f"/proc/{pid}/stat").read_text().split(") ")[1][0] != "Z"
    except FileNotFoundError:
        return False
    except OSError:
        try:
            os.kill(pid, 0)
            return True
        except ProcessLookupError:
            return False


class GateCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name) / "project with spaces"
        self.repo.mkdir()
        self.git("init", "-q")
        self.git("config", "user.email", "t@example.com")
        self.git("config", "user.name", "t")
        (self.repo / "a.txt").write_text("one\n")
        self.git("add", "a.txt")
        self.git("commit", "-qm", "init")

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args):
        subprocess.run(["git", "-C", str(self.repo), *args], check=True, capture_output=True)

    def gate(self, mode, payload=None, env=None):
        event = {"cwd": str(self.repo), **(payload or {})}
        return subprocess.run([sys.executable, str(GATE), mode], input=json.dumps(event),
                              capture_output=True, text=True, env={**os.environ, **(env or {})})

    def counting(self, exit_code=0):
        """A check command that appends to a counter file, then exits with exit_code."""
        counter = self.repo.parent / "count"
        return counter, self.python(f"import sys; open(r'{counter}', 'a').write('x'); sys.exit({exit_code})")

    def runs(self, counter):
        return len(counter.read_text()) if counter.exists() else 0

    def python(self, code):
        return f'"{Path(sys.executable).as_posix()}" -c "{code}"'


class ProjectGateTest(GateCase):
    def test_unconfigured_repository_is_never_touched(self):
        (self.repo / "a.txt").write_text("changed\n")
        self.assertEqual(self.gate("check").returncode, 0)
        self.assertEqual(self.gate("format", {"tool_input": {"file_path": str(self.repo / "a.txt")}}).returncode, 0)
        self.assertEqual((self.repo / "a.txt").read_text(), "changed\n")

    def test_failing_check_blocks_once_then_lets_the_turn_end(self):
        self.git("config", "ai.check", self.python("import sys; print('lint broke'); sys.exit(3)"))
        self.assertEqual(self.gate("check").returncode, 0, "clean tree: nothing to check")
        (self.repo / "a.txt").write_text("changed\n")
        result = self.gate("check")
        self.assertEqual(result.returncode, 2)
        self.assertIn("lint broke", result.stderr)
        self.assertIn("exit 3", result.stderr)
        self.assertEqual(self.gate("check", {"stop_hook_active": True}).returncode, 0)

    def test_passing_check_is_cached_until_the_tree_changes(self):
        counter = self.repo.parent / "count"
        self.git("config", "ai.check", self.python(f"open(r'{counter}', 'a').write('x')"))
        (self.repo / "new.txt").write_text("untracked\n")
        self.assertEqual(self.gate("check").returncode, 0)
        self.assertEqual(self.gate("check").returncode, 0)
        self.assertEqual(counter.read_text(), "x")
        (self.repo / "new.txt").write_text("edited untracked\n")
        self.assertEqual(self.gate("check").returncode, 0)
        self.assertEqual(counter.read_text(), "xx")

    def test_global_and_included_config_is_ignored(self):
        counter, command = self.counting()
        global_config = self.repo.parent / "global.gitconfig"
        global_config.write_text(f"[ai]\n\tcheck = {command}\n\tformat = {command}\n")
        env = {"GIT_CONFIG_GLOBAL": str(global_config)}
        (self.repo / "a.txt").write_text("changed\n")
        self.assertEqual(self.gate("check", env=env).returncode, 0)
        self.gate("format", {"tool_input": {"file_path": str(self.repo / "a.txt")}}, env=env)
        self.assertEqual(self.runs(counter), 0)

    def test_commit_and_command_change_are_new_states(self):
        counter, command = self.counting()
        self.git("config", "ai.check", command)
        self.gate("check")  # first visit, clean tree: the baseline, not checked
        self.assertEqual(self.runs(counter), 0)
        (self.repo / "a.txt").write_text("changed\n")
        self.git("commit", "-qam", "change")  # clean tree, new HEAD: still unchecked
        self.gate("check")
        self.gate("check")
        self.assertEqual(self.runs(counter), 1)
        self.git("config", "ai.check", command + " --again")
        self.gate("check")
        self.assertEqual(self.runs(counter), 2)
        (self.repo / "a.txt").write_text("checked edit\n")
        self.gate("check")
        self.assertEqual(self.runs(counter), 3)
        (self.repo / "a.txt").write_text("unchecked edit\n")
        self.git("stash", "-q")  # clean tree, but not the state that passed last
        self.gate("check")
        self.assertEqual(self.runs(counter), 4)

    def test_unchanged_failure_is_not_checked_again_in_the_same_stop_cycle(self):
        counter, command = self.counting(exit_code=1)
        self.git("config", "ai.check", command)
        (self.repo / "a.txt").write_text("changed\n")
        self.assertEqual(self.gate("check").returncode, 2)
        result = self.gate("check", {"stop_hook_active": True})
        self.assertEqual(result.returncode, 0)
        self.assertIn("still fails", result.stderr)
        self.assertEqual(self.runs(counter), 1)
        (self.repo / "a.txt").write_text("attempted fix\n")
        self.assertEqual(self.gate("check", {"stop_hook_active": True}).returncode, 0)
        self.assertEqual(self.runs(counter), 2)

    @unittest.skipIf(os.name == "nt", "POSIX process groups; Windows uses taskkill /T")
    def test_timeout_kills_the_whole_process_tree(self):
        gate = load_gate()
        gate.deadline = time.monotonic() + 60
        pid_file = self.repo.parent / "child.pid"
        started = time.monotonic()
        code, output = gate.run(f"sleep 30 & echo $! > '{pid_file}'; wait", self.repo, gate.KILL_TIME + 1)
        self.assertEqual(code, 124)
        self.assertLess(time.monotonic() - started, gate.KILL_TIME + 1, "a child held the output pipe open")
        pid = int(pid_file.read_text())
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline and alive(pid):
            time.sleep(0.05)
        self.assertFalse(alive(pid), "the background child survived the timeout")

    @unittest.skipIf(os.name == "nt" or not shutil.which("setsid"), "POSIX sessions")
    def test_a_descendant_outside_the_group_cannot_hold_the_hook(self):
        gate = load_gate()
        gate.deadline = time.monotonic() + 60
        pid_file = self.repo.parent / "escaped.pid"
        started = time.monotonic()
        code, _ = gate.run(f"setsid sh -c 'echo $$ > \"{pid_file}\"; exec sleep 30' & wait",
                           self.repo, gate.KILL_TIME + 1)
        try:
            self.assertEqual(code, 124)
            # The run budget, then at most a quarter of the kill reserve to read the pipe.
            self.assertLess(time.monotonic() - started, 1 + gate.KILL_TIME / 4 + 3)
        finally:
            if pid_file.exists():
                try:
                    os.kill(int(pid_file.read_text()), signal.SIGKILL)
                except (ProcessLookupError, ValueError):
                    pass

    def test_a_taskkill_timeout_still_kills_the_shell(self):
        gate = load_gate()
        process = mock.Mock(pid=4242)
        with mock.patch.object(gate.os, "name", "nt"), mock.patch.object(
                gate.subprocess, "run", side_effect=subprocess.TimeoutExpired("taskkill", 4)):
            gate.kill_tree(process)
        process.kill.assert_called_once()

    def test_the_kill_reserve_keeps_the_hook_inside_its_entry_timeout(self):
        gate = load_gate()
        gate.deadline = time.monotonic() + gate.KILL_TIME + 0.5
        # Less than one second is left after the kill reserve: the command does not start.
        self.assertEqual(gate.run("echo never", self.repo, gate.remaining())[1], "no time left in the hook budget")
        self.assertLess(gate.BUDGET["check"] + 2, 300)

    def test_no_git_dir_means_no_state_files_in_the_tree(self):
        gate = load_gate()
        self.git("config", "ai.check", self.python("raise SystemExit(1)"))
        (self.repo / "a.txt").write_text("changed\n")
        real = gate.git
        gate.git = lambda root, *args, **kw: "" if args[:2] == ("rev-parse", "--absolute-git-dir") else real(root, *args, **kw)
        before = os.getcwd()
        os.chdir(self.repo)  # a relative state path would land here
        try:
            self.assertEqual(gate.check({"cwd": str(self.repo)}), 0)
        finally:
            os.chdir(before)
        self.assertEqual(sorted(p.name for p in self.repo.iterdir() if p.name.startswith("ai-gate")), [])

    def test_git_calls_and_the_check_share_one_budget(self):
        gate = load_gate()
        gate.deadline = time.monotonic() + 0.5
        self.assertEqual(gate.run("echo never", self.repo, gate.remaining() - 2)[0], 124)
        self.assertLessEqual(max(gate.BUDGET.values()), 290, "the Stop hook entry allows 300 s")

    def test_format_appends_the_edited_file_and_ignores_outside_paths(self):
        self.git("config", "ai.format", self.python("import sys; open(sys.argv[1], 'w').write('formatted')"))
        target = self.repo / "a.txt"
        self.assertEqual(self.gate("format", {"tool_input": {"file_path": str(target)}}).returncode, 0)
        self.assertEqual(target.read_text(), "formatted")
        outside = self.repo.parent / "outside.txt"
        outside.write_text("keep")
        self.gate("format", {"tool_input": {"file_path": str(outside)}})
        self.assertEqual(outside.read_text(), "keep")

    def test_suggest_reads_package_scripts(self):
        (self.repo / "package.json").write_text(json.dumps({"scripts": {"lint": "eslint .", "typecheck": "vue-tsc", "dev": "nuxt dev"}}))
        (self.repo / "pnpm-lock.yaml").write_text("")
        (self.repo / ".prettierrc").write_text("{}")
        result = subprocess.run([sys.executable, str(GATE), "suggest", str(self.repo)], capture_output=True, text=True)
        self.assertIn("pnpm lint && pnpm typecheck", result.stdout)
        self.assertIn("pnpm exec prettier --write --ignore-unknown", result.stdout)


class VerifyReminderTest(GateCase):
    """The Stop reminder reads the session transcript; it needs no ai.check."""

    def setUp(self):
        super().setUp()
        self.transcript = Path(self.tmp.name) / "session.jsonl"
        self.transcript.write_text("")
        temp = Path(self.tmp.name) / "temp"
        temp.mkdir()
        self.env = {"TMPDIR": str(temp), "TEMP": str(temp), "TMP": str(temp)}

    def tool(self, name, **args):
        self.tool_count = getattr(self, "tool_count", 0) + 1
        message = {"role": "assistant", "content": [
            {"type": "tool_use", "id": f"toolu_{self.tool_count}", "name": name, "input": args}]}
        self.line({"type": "assistant", "message": message})
        return f"toolu_{self.tool_count}"

    def line(self, entry):
        with self.transcript.open("a") as lines:
            # Compact separators, as Claude Code writes its transcripts.
            lines.write((entry if isinstance(entry, str) else json.dumps(entry, separators=(",", ":"))) + "\n")

    def typed(self, text):
        self.line({"type": "user", "message": {"role": "user", "content": text}})

    def failed(self, tool_id):
        self.line({"type": "user", "message": {"role": "user", "content": [
            {"type": "tool_result", "tool_use_id": tool_id, "content": "denied", "is_error": True}]}})

    def stop(self, again=False):
        return self.gate("check", {"transcript_path": str(self.transcript), "session_id": "s1",
                                   "stop_hook_active": again}, env=self.env)

    def test_an_unverified_edit_blocks_one_stop(self):
        self.tool("Edit", file_path=str(self.repo / "a.txt"))
        first = self.stop()
        self.assertEqual(first.returncode, 2)
        self.assertIn("verification-before-completion", first.stderr)
        self.assertEqual(self.stop(again=True).returncode, 0)
        self.assertEqual(self.stop().returncode, 0)

    def test_a_new_edit_after_a_correction_blocks_again(self):
        self.tool("Write", file_path=str(self.repo / "a.txt"))
        self.assertEqual(self.stop().returncode, 2)
        self.typed("the logo is too big")
        self.tool("Edit", file_path=str(self.repo / "a.txt"))
        self.assertEqual(self.stop().returncode, 2)

    def test_verification_after_the_last_edit_lets_the_turn_end(self):
        self.tool("Edit", file_path=str(self.repo / "a.txt"))
        self.tool("Skill", skill="verification-before-completion")
        self.assertEqual(self.stop().returncode, 0)
        self.tool("Edit", file_path=str(self.repo / "a.txt"))
        self.typed("<command-name>/verify</command-name>")
        self.assertEqual(self.stop().returncode, 0)

    def test_edits_outside_the_repository_are_ignored(self):
        self.tool("Write", file_path=str(Path(self.tmp.name) / "memory.md"))
        self.tool("Skill", skill="engineering-flow")
        self.assertEqual(self.stop().returncode, 0)

    def test_the_repository_can_opt_out_with_any_git_false(self):
        self.git("config", "ai.remind", "no")
        self.tool("Edit", file_path=str(self.repo / "a.txt"))
        self.assertEqual(self.stop().returncode, 0)

    def test_a_failed_edit_is_not_a_change(self):
        self.tool("Edit", file_path=str(self.repo / "a.txt"))
        self.tool("Skill", skill="verify")
        self.failed(self.tool("Edit", file_path=str(self.repo / "a.txt")))
        self.assertEqual(self.stop().returncode, 0)
        self.failed(self.tool("NotebookEdit", notebook_path=str(self.repo / "n.ipynb")))
        self.tool("NotebookEdit", notebook_path=str(self.repo / "n.ipynb"))
        self.assertEqual(self.stop().returncode, 2)

    def test_a_namespaced_verification_skill_counts(self):
        self.tool("Edit", file_path=str(self.repo / "a.txt"))
        self.tool("Skill", skill="dotfiles-ai:verification-before-completion")
        self.assertEqual(self.stop().returncode, 0)

    def test_only_a_user_command_message_counts(self):
        self.tool("Edit", file_path=str(self.repo / "a.txt"))
        self.line({"type": "assistant", "message": {"role": "assistant", "content": [
            {"type": "text", "text": "type <command-name>/verify</command-name> next"}]}})
        self.assertEqual(self.stop().returncode, 2)

    def test_malformed_lines_do_not_break_the_reminder(self):
        self.line('{"type": "assistant", "message": "tool_use"}')
        self.line('{"message": {"content": [{"type": "tool_use", "name": "Edit", "input": "x"}]}}')
        self.line('{"truncated": "tool_use')
        self.tool("Edit", file_path=str(self.repo / "a.txt"))
        self.tool("Write", file_path="bad\u0000path")
        self.tool("Write", file_path=7)
        result = self.stop()
        self.assertEqual(result.returncode, 2, result.stderr)

    def commit(self, command, tool="Bash", cwd=None):
        return self.gate("commit", {"transcript_path": str(self.transcript), "session_id": "s1",
                                    "tool_name": tool, "tool_input": {"command": command},
                                    **({"cwd": str(cwd)} if cwd else {})}, env=self.env)

    def test_a_commit_of_unverified_edits_is_blocked_once(self):
        self.tool("Edit", file_path=str(self.repo / "a.txt"))
        first = self.commit('git add a.txt && git commit -q -m "feat: x"')
        self.assertEqual(first.returncode, 2)
        self.assertIn("a commit is not a verification", first.stderr)
        self.assertEqual(self.commit('git commit -m "feat: x"').returncode, 0)
        # The commit reminder has its own marker: the Stop still reminds.
        self.assertEqual(self.stop().returncode, 2)

    def test_a_verified_commit_and_other_commands_pass(self):
        self.tool("Edit", file_path=str(self.repo / "a.txt"))
        self.assertEqual(self.commit("git status && git log -1").returncode, 0)
        self.assertEqual(self.commit("git commit-tree HEAD^{tree}").returncode, 0)
        self.assertEqual(self.commit("git commit -m x", tool="Read").returncode, 0)
        self.tool("Skill", skill="verify")
        self.assertEqual(self.commit("git commit -m x").returncode, 0)

    def test_commit_with_dash_c_checks_that_repository(self):
        # The session starts in the parent folder, which is not a repository.
        self.tool("Edit", file_path=str(self.repo / "a.txt"))
        command = '& git -C "project with spaces" --no-pager commit -m x'
        self.assertEqual(self.commit(command, tool="PowerShell", cwd=self.repo.parent).returncode, 2)

    def test_a_quoted_mention_does_not_spend_the_commit_reminder(self):
        self.tool("Edit", file_path=str(self.repo / "a.txt"))
        self.assertEqual(self.commit('rg "git commit" docs/ && echo "then git commit"').returncode, 0)
        self.assertEqual(self.commit("git add . && git commit -m x").returncode, 2)

    def test_the_commit_pattern_scans_long_commands_quickly(self):
        start = time.monotonic()
        self.assertIsNone(load_gate().COMMIT.search('git -c a="' + "x " * 20000 + " status"))
        self.assertLess(time.monotonic() - start, 1)

    def test_the_stop_reminder_asks_for_a_review_line(self):
        self.tool("Edit", file_path=str(self.repo / "a.txt"))
        self.assertIn("Review: small|medium|large", self.stop().stderr)

    def test_a_check_that_still_fails_ends_the_turn_without_a_reminder(self):
        self.git("config", "ai.check", self.python("import sys; print('lint broke'); sys.exit(3)"))
        (self.repo / "a.txt").write_text("changed\n")
        self.tool("Edit", file_path=str(self.repo / "a.txt"))
        self.assertEqual(self.stop().returncode, 2)
        second = self.stop(again=True)
        self.assertEqual(second.returncode, 0)
        self.assertIn("still fails", second.stderr)
        self.assertNotIn("verification-before-completion", second.stderr)

    def test_a_failing_check_reports_before_the_reminder(self):
        self.git("config", "ai.check", self.python("import sys; print('lint broke'); sys.exit(3)"))
        (self.repo / "a.txt").write_text("changed\n")
        self.tool("Edit", file_path=str(self.repo / "a.txt"))
        first = self.stop()
        self.assertEqual(first.returncode, 2)
        self.assertIn("lint broke", first.stderr)
        self.assertNotIn("verification-before-completion", first.stderr)


if __name__ == "__main__":
    unittest.main()
