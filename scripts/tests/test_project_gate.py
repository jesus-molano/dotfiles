"""Contract tests for the per-project verification gate in ai/hooks."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

GATE = Path(__file__).resolve().parents[2] / "ai/hooks/project-gate.py"


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

    def gate(self, mode, payload=None):
        event = {"cwd": str(self.repo), **(payload or {})}
        return subprocess.run([sys.executable, str(GATE), mode], input=json.dumps(event),
                              capture_output=True, text=True)

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
