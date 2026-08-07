"""Pruebas autocontenidas del sincronizador de caché Matt Pocock."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1]
SYNC = SCRIPTS / "sync-matt-pocock-skills.py"
UPSTREAM = "https://github.com/mattpocock/skills.git"


def command(*args: str, cwd: Path | None = None) -> None:
    subprocess.run(args, cwd=cwd, check=True, capture_output=True, text=True)


def run_sync(
    *args: str, environment: dict[str, str]
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(SYNC), *args],
        text=True,
        capture_output=True,
        env=environment,
        check=False,
    )


def fixture(root: Path, *, valid_origin: bool = True) -> Path:
    repo = root / "fixture"
    repo.mkdir()
    command("git", "init", "--initial-branch", "main", str(repo))
    command("git", "config", "user.email", "test@example.invalid", cwd=repo)
    command("git", "config", "user.name", "Fixture", cwd=repo)
    expected = (
        "skills/engineering/diagnosing-bugs/SKILL.md",
        "skills/engineering/tdd/SKILL.md",
        "skills/engineering/to-spec/SKILL.md",
        "skills/productivity/grilling/SKILL.md",
    )
    for relative in expected:
        path = repo / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("fixture\n", encoding="utf-8")
    (repo / "LICENSE").write_text("MIT License\n", encoding="utf-8")
    command("git", "add", ".", cwd=repo)
    command("git", "commit", "-m", "fixture", cwd=repo)
    command(
        "git",
        "remote",
        "add",
        "origin",
        UPSTREAM if valid_origin else "https://example.invalid/not-allowed.git",
        cwd=repo,
    )
    return repo


class SyncMattPocockSkillsTest(unittest.TestCase):
    def test_apply_records_commit_and_check_is_read_only(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, target = fixture(root), root / "mattpocock-skills"
            environment = os.environ | {"XDG_STATE_HOME": str(root / "state")}
            applied = run_sync(
                "--apply",
                "--source",
                str(source),
                "--target",
                str(target),
                environment=environment,
            )
            self.assertEqual(applied.returncode, 0, applied.stderr)
            metadata = json.loads(
                (target / ".dotfiles-upstream.json").read_text(encoding="utf-8")
            )
            self.assertEqual(metadata["source"], UPSTREAM)
            before = (target / ".dotfiles-upstream.json").read_bytes()
            checked = run_sync(
                "--check", "--target", str(target), environment=environment
            )
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertEqual(before, (target / ".dotfiles-upstream.json").read_bytes())

    def test_invalid_origin_preserves_existing_target(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            target = root / "mattpocock-skills"
            target.mkdir()
            (target / "sentinel").write_text("previous cache", encoding="utf-8")
            environment = os.environ | {"XDG_STATE_HOME": str(root / "state")}
            failed = run_sync(
                "--apply",
                "--source",
                str(fixture(root, valid_origin=False)),
                "--target",
                str(target),
                environment=environment,
            )
            self.assertNotEqual(failed.returncode, 0)
            self.assertEqual(
                (target / "sentinel").read_text(encoding="utf-8"), "previous cache"
            )

    def test_update_keeps_a_recoverable_backup(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, target = fixture(root), root / "mattpocock-skills"
            environment = os.environ | {"XDG_STATE_HOME": str(root / "state")}
            first = run_sync(
                "--apply",
                "--source",
                str(source),
                "--target",
                str(target),
                environment=environment,
            )
            self.assertEqual(first.returncode, 0, first.stderr)
            old_commit = json.loads(
                (target / ".dotfiles-upstream.json").read_text(encoding="utf-8")
            )["commit"]

            changed = source / "skills/engineering/tdd/SKILL.md"
            changed.write_text("second version\n", encoding="utf-8")
            command("git", "add", str(changed.relative_to(source)), cwd=source)
            command("git", "commit", "-m", "second", cwd=source)
            second = run_sync(
                "--apply",
                "--source",
                str(source),
                "--target",
                str(target),
                environment=environment,
            )
            self.assertEqual(second.returncode, 0, second.stderr)

            backups = list(
                (root / "state/dotfiles/codex-upstreams/mattpocock-skills").glob(
                    "*/mattpocock-skills/.dotfiles-upstream.json"
                )
            )
            self.assertEqual(len(backups), 1)
            self.assertEqual(
                json.loads(backups[0].read_text(encoding="utf-8"))["commit"],
                old_commit,
            )

    def test_update_supports_separate_data_and_state_filesystems(self) -> None:
        shared_memory = Path("/dev/shm")
        temporary_root = Path(tempfile.gettempdir())
        if not shared_memory.is_dir() or not os.access(shared_memory, os.W_OK):
            self.skipTest("/dev/shm no está disponible")
        if shared_memory.stat().st_dev == temporary_root.stat().st_dev:
            self.skipTest("no hay dos filesystems temporales para probar EXDEV")

        with (
            tempfile.TemporaryDirectory(dir=temporary_root) as data_temporary,
            tempfile.TemporaryDirectory(dir=shared_memory) as state_temporary,
        ):
            root = Path(data_temporary)
            source, target = fixture(root), root / "mattpocock-skills"
            environment = os.environ | {"XDG_STATE_HOME": state_temporary}
            first = run_sync(
                "--apply",
                "--source",
                str(source),
                "--target",
                str(target),
                environment=environment,
            )
            self.assertEqual(first.returncode, 0, first.stderr)

            changed = source / "skills/engineering/tdd/SKILL.md"
            changed.write_text("cross-filesystem update\n", encoding="utf-8")
            command("git", "add", str(changed.relative_to(source)), cwd=source)
            command("git", "commit", "-m", "cross filesystem", cwd=source)
            second = run_sync(
                "--apply",
                "--source",
                str(source),
                "--target",
                str(target),
                environment=environment,
            )

            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertIn("Backup recuperable:", second.stdout)

    def test_check_rejects_dirty_or_injected_cache_content(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, target = fixture(root), root / "mattpocock-skills"
            environment = os.environ | {"XDG_STATE_HOME": str(root / "state")}
            applied = run_sync(
                "--apply",
                "--source",
                str(source),
                "--target",
                str(target),
                environment=environment,
            )
            self.assertEqual(applied.returncode, 0, applied.stderr)

            tracked = target / "skills/engineering/tdd/SKILL.md"
            original = tracked.read_text(encoding="utf-8")
            tracked.write_text("tampered\n", encoding="utf-8")
            dirty = run_sync(
                "--check", "--target", str(target), environment=environment
            )
            self.assertNotEqual(dirty.returncode, 0)
            tracked.write_text(original, encoding="utf-8")

            (target / "injected.txt").write_text("unexpected\n", encoding="utf-8")
            injected = run_sync(
                "--check", "--target", str(target), environment=environment
            )
            self.assertNotEqual(injected.returncode, 0)

    def test_versioned_metadata_symlink_cannot_escape_staging(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = fixture(root)
            sentinel = root / "sentinel"
            sentinel.write_text("preserve me\n", encoding="utf-8")
            (source / ".dotfiles-upstream.json").symlink_to(sentinel)
            command("git", "add", ".dotfiles-upstream.json", cwd=source)
            command("git", "commit", "-m", "malicious metadata path", cwd=source)
            target = root / "mattpocock-skills"
            environment = os.environ | {"XDG_STATE_HOME": str(root / "state")}

            failed = run_sync(
                "--apply",
                "--source",
                str(source),
                "--target",
                str(target),
                environment=environment,
            )

            self.assertNotEqual(failed.returncode, 0)
            self.assertEqual(sentinel.read_text(encoding="utf-8"), "preserve me\n")
            self.assertFalse(target.exists())

    def test_rejects_a_broad_custom_target(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            failed = run_sync(
                "--apply",
                "--source",
                str(fixture(root)),
                "--target",
                str(root),
                environment=os.environ.copy(),
            )
            self.assertNotEqual(failed.returncode, 0)
            self.assertIn("debe terminar exactamente", failed.stderr)


if __name__ == "__main__":
    unittest.main()
