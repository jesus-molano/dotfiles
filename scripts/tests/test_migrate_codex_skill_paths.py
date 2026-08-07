"""Pruebas de la migración conservadora de la skill Linear local."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1]
MIGRATOR = SCRIPTS / "migrate-codex-skill-paths.sh"
MANAGED_LINKS = ("LICENSE.txt", "SKILL.md", "SOURCE.md", "agents/openai.yaml")


def create_managed_legacy(home: Path) -> Path:
    legacy = home / ".agents/skills/linear"
    source = home / ".dotfiles/codex/.agents/skills/linear"
    for relative in MANAGED_LINKS:
        link = legacy / relative
        link.parent.mkdir(parents=True, exist_ok=True)
        link.symlink_to(os.path.relpath(source / relative, link.parent))
    return legacy


def run_migrator(home: Path, state: Path, mode: str) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    environment.update({"HOME": str(home), "XDG_STATE_HOME": str(state)})
    return subprocess.run(
        [str(MIGRATOR), mode],
        text=True,
        capture_output=True,
        check=False,
        env=environment,
    )


class MigrateCodexSkillPathsTest(unittest.TestCase):
    def test_check_recognizes_only_the_managed_legacy_links(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            legacy = create_managed_legacy(root / "home")
            checked = run_migrator(root / "home", root / "state", "--check")
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertIn("MIGRATE:", checked.stdout)
            self.assertTrue(legacy.is_dir())

    def test_apply_moves_the_managed_legacy_directory_to_a_backup(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            home = root / "home"
            legacy = create_managed_legacy(home)
            applied = run_migrator(home, root / "state", "--apply")
            self.assertEqual(applied.returncode, 0, applied.stderr)
            self.assertFalse(legacy.exists())
            backups = list(
                (root / "state/dotfiles/backups").glob(
                    "codex-linear-workflow.*/linear/SKILL.md"
                )
            )
            self.assertEqual(len(backups), 1)
            self.assertTrue(backups[0].is_symlink())

    def test_foreign_linear_directory_is_preserved(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            legacy = root / "home/.agents/skills/linear"
            legacy.mkdir(parents=True)
            (legacy / "SKILL.md").write_text("foreign\n", encoding="utf-8")
            applied = run_migrator(root / "home", root / "state", "--apply")
            self.assertNotEqual(applied.returncode, 0)
            self.assertTrue((legacy / "SKILL.md").is_file())
            self.assertFalse((root / "state").exists())

    def test_symlinked_skills_parent_is_preserved(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            home = root / "home"
            external_skills = root / "external-skills"
            external_skills.mkdir()
            (home / ".agents").mkdir(parents=True)
            (home / ".agents/skills").symlink_to(
                external_skills, target_is_directory=True
            )
            legacy = external_skills / "linear"
            legacy.mkdir()
            (legacy / "SKILL.md").symlink_to("missing")

            applied = run_migrator(home, root / "state", "--apply")

            self.assertNotEqual(applied.returncode, 0)
            self.assertIn("su padre es un enlace simbólico", applied.stderr)
            self.assertTrue(legacy.is_dir())
            self.assertFalse((root / "state").exists())


if __name__ == "__main__":
    unittest.main()
