"""Pruebas del uso seguro del directorio temporal de reglas Codex."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "clean-codex-rules.sh"


class CleanCodexRulesTest(unittest.TestCase):
    def test_check_falls_back_when_runtime_directory_is_unavailable(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            home = root / "home"
            rules = home / ".codex/rules/default.rules"
            rules.parent.mkdir(parents=True)
            rules.write_text("prefix_rule(pattern=[\"git\"], decision=\"allow\")\n")
            result = subprocess.run(
                [str(SCRIPT), "--check"],
                text=True,
                capture_output=True,
                check=False,
                env=os.environ
                | {"HOME": str(home), "XDG_RUNTIME_DIR": str(root / "missing-runtime")},
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Sin reglas temporales", result.stdout)


if __name__ == "__main__":
    unittest.main()
