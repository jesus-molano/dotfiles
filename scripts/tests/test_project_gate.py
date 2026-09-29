"""Contract tests for the per-project verification gate in ai/hooks."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

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


class ProjectGateTest(unittest.TestCase):
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
        code, output = gate.run(f"sleep 30 & echo $! > '{pid_file}'; wait", self.repo, 1)
        self.assertEqual(code, 124)
        self.assertLess(time.monotonic() - started, 10, "a child held the output pipe open")
        pid = int(pid_file.read_text())
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline and alive(pid):
            time.sleep(0.05)
        self.assertFalse(alive(pid), "the background child survived the timeout")

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


if __name__ == "__main__":
    unittest.main()
