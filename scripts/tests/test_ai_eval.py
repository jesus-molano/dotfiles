"""Contract tests for scripts/ai-eval.sh with a fake `claude` on PATH."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts/ai-eval.sh"
sys.path.insert(0, str(REPO / "scripts"))
from ai_sources import instructions  # noqa: E402

# The fake records its arguments, copies the assembled cases and exits with
# FAKE_STATUS, as `claude plugin eval` does after a threshold or cost-cap stop.
FAKE_CLAUDE = """#!/usr/bin/env bash
printf '%s\\n' "$@" >"$FAKE_OUT/args"
cp -R -- "$3/evals" "$FAKE_OUT/evals"
exit "${FAKE_STATUS:-0}"
"""


@unittest.skipUnless(shutil.which("bash"), "bash is required")
class AiEvalScriptTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.out = root / "out"
        self.out.mkdir()
        bin_dir = root / "bin"
        bin_dir.mkdir()
        fake = bin_dir / "claude"
        fake.write_text(FAKE_CLAUDE, encoding="utf-8")
        fake.chmod(0o755)
        self.env = {
            **os.environ,
            "PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}",
            "FAKE_OUT": str(self.out),
            "XDG_STATE_HOME": str(root / "state"),
            "TMPDIR": str(root),
            "PYTHONDONTWRITEBYTECODE": "1",
        }

    def tearDown(self):
        self.tmp.cleanup()

    def run_eval(self, *args, status=0):
        env = {**self.env, "FAKE_STATUS": str(status)}
        return subprocess.run(["bash", str(SCRIPT), *args], env=env,
                              capture_output=True, text=True, timeout=60)

    def frontmatter(self, case):
        text = (self.out / "evals" / case / "prompt.md").read_text(encoding="utf-8")
        return re.match(r"---\n(.*?)\n---\n", text, re.DOTALL).group(1)

    def test_rules_cases_get_the_rendered_rules(self):
        result = self.run_eval()
        self.assertEqual(result.returncode, 0, result.stderr)
        rules = json.dumps(instructions("claude", "linux"))
        cases = sorted(p.parent.name for p in (REPO / "ai/evals/cases").glob("*/prompt.md"))
        tagged = [c for c in cases
                  if re.search(r"^tags:.*\brules\b", self.frontmatter(c), re.MULTILINE)]
        self.assertTrue(tagged)
        for case in cases:
            head = self.frontmatter(case)
            if case in tagged:
                line = re.search(r"^append_system_prompt: (.*)$", head, re.MULTILINE)
                self.assertIsNotNone(line, case)
                self.assertEqual(line.group(1), rules, case)
            else:
                self.assertNotIn("append_system_prompt:", head, case)

    def test_routing_defaults(self):
        result = self.run_eval("--case", "handoff")
        self.assertEqual(result.returncode, 0, result.stderr)
        args = (self.out / "args").read_text(encoding="utf-8").splitlines()
        self.assertEqual(args[:2], ["plugin", "eval"])
        self.assertIn("--max-cost-usd", args)
        self.assertEqual(args[args.index("--max-cost-usd") + 1], "4")
        self.assertEqual(args[-2:], ["--case", "handoff"])

    def test_failed_run_prints_results_and_keeps_status(self):
        for status in (1, 2):
            with self.subTest(status=status):
                result = self.run_eval(status=status)
                self.assertEqual(result.returncode, status)
                self.assertRegex(result.stdout, r"(?m)^Results: .+-routing$")


if __name__ == "__main__":
    unittest.main()
