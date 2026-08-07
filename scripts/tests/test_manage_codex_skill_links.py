"""Pruebas del despliegue de skills mediante enlaces de carpeta."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1]
MANAGER = SCRIPTS / "manage-codex-skill-links.sh"


def create_source(root: Path, name: str = "example") -> Path:
    source = root / "source"
    skill = source / name
    (skill / "agents").mkdir(parents=True)
    (skill / "SKILL.md").write_text(
        f"---\nname: {name}\ndescription: Fixture.\n---\n", encoding="utf-8"
    )
    (skill / "agents/openai.yaml").write_text("interface: {}\n", encoding="utf-8")
    return source


def create_legacy_tree(source: Path, skills: Path, name: str = "example") -> Path:
    target = skills / name
    for item in (source / name).rglob("*"):
        relative = item.relative_to(source / name)
        destination = target / relative
        if item.is_dir():
            destination.mkdir(parents=True, exist_ok=True)
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.symlink_to(os.path.relpath(item, destination.parent))
    return target


def run_manager(
    home: Path, source: Path, skills: Path, state: Path, mode: str
) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    environment.update(
        {
            "HOME": str(home),
            "XDG_STATE_HOME": str(state),
            "CODEX_SKILLS_SOURCE_ROOT": str(source),
            "CODEX_SKILLS_ROOT": str(skills),
        }
    )
    return subprocess.run(
        [str(MANAGER), mode],
        text=True,
        capture_output=True,
        check=False,
        env=environment,
    )


class ManageCodexSkillLinksTest(unittest.TestCase):
    def test_apply_converts_legacy_file_links_to_one_directory_link(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            home = root / "home"
            source = create_source(root)
            skills = home / ".agents/skills"
            target = create_legacy_tree(source, skills)

            applied = run_manager(home, source, skills, root / "state", "--apply")

            self.assertEqual(applied.returncode, 0, applied.stderr)
            self.assertTrue(target.is_symlink())
            self.assertEqual(target.resolve(), source / "example")
            backups = list(
                (root / "state/dotfiles/codex-skills/backups").glob(
                    "sync-*/skills/example/SKILL.md"
                )
            )
            self.assertEqual(len(backups), 1)
            self.assertTrue(backups[0].is_symlink())

    def test_foreign_skill_is_preserved(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            home = root / "home"
            source = create_source(root)
            skills = home / ".agents/skills"
            foreign = skills / "example"
            foreign.mkdir(parents=True)
            (foreign / "SKILL.md").write_text("foreign\n", encoding="utf-8")

            applied = run_manager(home, source, skills, root / "state", "--apply")

            self.assertNotEqual(applied.returncode, 0)
            self.assertEqual((foreign / "SKILL.md").read_text(), "foreign\n")
            self.assertFalse((root / "state").exists())

    def test_symlinked_parent_is_preserved(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            home = root / "home"
            source = create_source(root)
            external = root / "external-skills"
            external.mkdir()
            (home / ".agents").mkdir(parents=True)
            skills = home / ".agents/skills"
            skills.symlink_to(external, target_is_directory=True)

            applied = run_manager(home, source, skills, root / "state", "--apply")

            self.assertNotEqual(applied.returncode, 0)
            self.assertIn("directorio enlazado", applied.stderr)
            self.assertEqual(list(external.iterdir()), [])

    def test_remove_backs_up_only_the_managed_directory_link(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            home = root / "home"
            source = create_source(root)
            skills = home / ".agents/skills"
            skills.mkdir(parents=True)
            target = skills / "example"
            target.symlink_to(source / "example", target_is_directory=True)

            removed = run_manager(home, source, skills, root / "state", "--remove")

            self.assertEqual(removed.returncode, 0, removed.stderr)
            self.assertFalse(target.exists())
            backups = list(
                (root / "state/dotfiles/codex-skills/backups").glob(
                    "sync-*/skills/example"
                )
            )
            self.assertEqual(len(backups), 1)
            self.assertTrue(backups[0].is_symlink())


if __name__ == "__main__":
    unittest.main()
