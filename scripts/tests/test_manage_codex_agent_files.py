"""Pruebas del despliegue de agentes TOML de Codex como ficheros regulares."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
from unittest.mock import patch


SCRIPTS = Path(__file__).resolve().parents[1]
MANAGER = SCRIPTS / "manage-codex-agent-files.py"


def load_manager():
    spec = spec_from_file_location("manage_codex_agent_files", MANAGER)
    assert spec and spec.loader
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def source_catalog(root: Path) -> Path:
    source = root / "source"
    source.mkdir()
    for name in ("one", "two", "three", "four", "reuse-scout"):
        (source / f"{name}.toml").write_text(f'name = "{name}"\n', encoding="utf-8")
    return source


def run(
    root: Path,
    source: Path,
    destination: Path,
    mode: str,
    *extra: str,
    extra_env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    environment.update(
        {
            "HOME": str(root / "home"),
            "XDG_STATE_HOME": str(root / "state"),
            "CODEX_AGENTS_SOURCE_ROOT": str(source),
            "CODEX_AGENTS_ROOT": str(destination),
        }
    )
    if extra_env:
        environment.update(extra_env)
    return subprocess.run(
        ["python3", str(MANAGER), mode, *extra],
        text=True,
        capture_output=True,
        check=False,
        env=environment,
    )


class ManageCodexAgentFilesTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.source = source_catalog(self.root)
        self.destination = self.root / "home/.codex/agents"

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def bootstrap_regular_files(self) -> None:
        self.destination.mkdir(parents=True)
        for source in self.source.glob("*.toml"):
            (self.destination / source.name).write_text(source.read_text(), encoding="utf-8")
        applied = run(self.root, self.source, self.destination, "--apply")
        self.assertEqual(applied.returncode, 0, applied.stderr)

    def test_check_plans_missing_and_verify_rejects_without_writing(self) -> None:
        self.assertEqual(run(self.root, self.source, self.destination, "--check").returncode, 0)
        self.assertNotEqual(run(self.root, self.source, self.destination, "--verify").returncode, 0)
        self.assertFalse(self.destination.exists())

    def test_apply_migrates_links_and_adopts_identical_regular_file(self) -> None:
        self.destination.mkdir(parents=True)
        for name in ("one", "two", "three", "four"):
            (self.destination / f"{name}.toml").symlink_to(self.source / f"{name}.toml")
        reuse = self.destination / "reuse-scout.toml"
        reuse.write_text((self.source / "reuse-scout.toml").read_text(), encoding="utf-8")
        applied = run(self.root, self.source, self.destination, "--apply")
        self.assertEqual(applied.returncode, 0, applied.stderr)
        self.assertTrue(
            all(
                (self.destination / f"{name}.toml").is_file()
                and not (self.destination / f"{name}.toml").is_symlink()
                for name in ("one", "two", "three", "four", "reuse-scout")
            )
        )
        self.assertEqual(run(self.root, self.source, self.destination, "--verify").returncode, 0)

    def test_adoption_is_pending_until_applied_and_rolls_back_metadata(self) -> None:
        self.destination.mkdir(parents=True)
        for source in self.source.glob("*.toml"):
            (self.destination / source.name).write_text(source.read_text(), encoding="utf-8")
        planned = run(self.root, self.source, self.destination, "--check")
        self.assertIn("SYNC: 5", planned.stdout)
        self.assertNotEqual(run(self.root, self.source, self.destination, "--verify").returncode, 0)
        applied = run(self.root, self.source, self.destination, "--apply")
        self.assertEqual(applied.returncode, 0, applied.stderr)
        self.assertIn("Backup:", applied.stdout)
        backup = sorted((self.root / "state/dotfiles/codex-agents/backups").glob("sync-*"))[-1]
        self.assertTrue((backup / "metadata-state.json").is_file())
        rolled_back = run(self.root, self.source, self.destination, "--rollback", str(backup))
        self.assertEqual(rolled_back.returncode, 0, rolled_back.stderr)
        self.assertFalse((self.root / "state/dotfiles/codex-agents/managed.json").exists())

    def test_updates_registered_file_after_source_change_but_rejects_local_edit(self) -> None:
        self.bootstrap_regular_files()
        source = self.source / "one.toml"
        source.write_text('name = "one new"\n', encoding="utf-8")
        updated = run(self.root, self.source, self.destination, "--apply")
        self.assertEqual(updated.returncode, 0, updated.stderr)
        target = self.destination / "one.toml"
        self.assertEqual(target.read_text(), 'name = "one new"\n')
        source.write_text('name = "one newer"\n', encoding="utf-8")
        target.write_text('name = "local edit"\n', encoding="utf-8")
        rejected = run(self.root, self.source, self.destination, "--apply")
        self.assertNotEqual(rejected.returncode, 0)
        self.assertEqual(target.read_text(), 'name = "local edit"\n')

    def test_second_replace_failure_restores_original_links(self) -> None:
        self.destination.mkdir(parents=True)
        for source in self.source.glob("*.toml"):
            (self.destination / source.name).symlink_to(source)
        failed = run(
            self.root,
            self.source,
            self.destination,
            "--apply",
            extra_env={"CODEX_AGENT_FILES_FAIL_REPLACE_AT": "2"},
        )
        self.assertNotEqual(failed.returncode, 0)
        for source in self.source.glob("*.toml"):
            target = self.destination / source.name
            self.assertTrue(target.is_symlink())
            self.assertEqual(target.resolve(), source)

    def test_rollback_validates_missing_backup_before_removing_target(self) -> None:
        self.destination.mkdir(parents=True)
        target = self.destination / "one.toml"
        target.symlink_to(self.source / "one.toml")
        applied = run(self.root, self.source, self.destination, "--apply")
        self.assertEqual(applied.returncode, 0, applied.stderr)
        backup = next((self.root / "state/dotfiles/codex-agents/backups").glob("sync-*"))
        (backup / "one.toml").unlink()
        rejected = run(self.root, self.source, self.destination, "--rollback", str(backup))
        self.assertNotEqual(rejected.returncode, 0)
        self.assertTrue(target.is_file())
        self.assertFalse(target.is_symlink())

    def test_rollback_revalidates_each_target_before_mutating_it(self) -> None:
        self.destination.mkdir(parents=True)
        for source in self.source.glob("*.toml"):
            (self.destination / source.name).symlink_to(source)
        applied = run(self.root, self.source, self.destination, "--apply")
        self.assertEqual(applied.returncode, 0, applied.stderr)
        backup = next((self.root / "state/dotfiles/codex-agents/backups").glob("sync-*"))
        manager = load_manager()
        original = manager.validate_rollback_entry
        calls = 0

        def mutate_before_second_validation(*args):
            nonlocal calls
            calls += 1
            if calls == 6:
                (self.destination / "two.toml").write_text("edición concurrente\n", encoding="utf-8")
            return original(*args)

        with patch.object(manager, "validate_rollback_entry", side_effect=mutate_before_second_validation):
            with self.assertRaises(SystemExit):
                manager.rollback(backup, list(self.source.glob("*.toml")), self.destination, self.root / "state")
        changed = self.destination / "two.toml"
        self.assertEqual(changed.read_text(), "edición concurrente\n")

    def test_rollback_validates_metadata_preimage_before_touching_agents(self) -> None:
        self.bootstrap_regular_files()
        source = self.source / "one.toml"
        source.write_text('name = "updated"\n', encoding="utf-8")
        applied = run(self.root, self.source, self.destination, "--apply")
        self.assertEqual(applied.returncode, 0, applied.stderr)
        backup = next(
            item
            for item in (self.root / "state/dotfiles/codex-agents/backups").glob("sync-*")
            if (item / "metadata.json").is_file()
        )
        (backup / "metadata.json").unlink()
        target = self.destination / "one.toml"
        rejected = run(self.root, self.source, self.destination, "--rollback", str(backup))
        self.assertNotEqual(rejected.returncode, 0)
        self.assertEqual(target.read_text(), 'name = "updated"\n')

    def test_failure_after_metadata_write_restores_agents_and_metadata(self) -> None:
        self.destination.mkdir(parents=True)
        for source in self.source.glob("*.toml"):
            (self.destination / source.name).symlink_to(source)
        manager = load_manager()
        original = manager.write_metadata

        def write_then_fail(*args, **kwargs):
            original(*args, **kwargs)
            raise OSError("fallo posterior a metadatos")

        with patch.object(manager, "write_metadata", side_effect=write_then_fail):
            with self.assertRaises(OSError):
                manager.apply(list(self.source.glob("*.toml")), self.destination, self.root / "state", {})
        for source in self.source.glob("*.toml"):
            self.assertTrue((self.destination / source.name).is_symlink())
        self.assertFalse((self.root / "state/dotfiles/codex-agents/managed.json").exists())

    def test_rejects_symlinked_parent_and_normalized_path_escape(self) -> None:
        external = self.root / "external"
        external.mkdir()
        codex = self.root / "home/.codex"
        codex.parent.mkdir(parents=True)
        codex.symlink_to(external, target_is_directory=True)
        linked = run(self.root, self.source, self.destination, "--apply")
        self.assertNotEqual(linked.returncode, 0)
        escaped = self.root / "home/.codex/../../outside/agents"
        rejected = run(self.root, self.source, escaped, "--check")
        self.assertNotEqual(rejected.returncode, 0)
        self.assertIn("dentro de HOME", rejected.stderr)

    def test_rejects_existing_parent_that_is_not_a_directory(self) -> None:
        codex = self.root / "home/.codex"
        codex.parent.mkdir(parents=True)
        codex.write_text("not a directory\n", encoding="utf-8")
        rejected = run(self.root, self.source, self.destination, "--check")
        self.assertNotEqual(rejected.returncode, 0)
        self.assertIn("no es directorio", rejected.stderr)

    def test_filters_only_managed_agents_from_temporary_manifest_pair(self) -> None:
        self.bootstrap_regular_files()
        canonical = self.destination / "three.toml"
        canonical.unlink()
        canonical.symlink_to(self.source / "three.toml")
        (self.destination / "two.toml").write_text("local edit\n", encoding="utf-8")
        live = self.root / "live.tsv"
        snapshot = self.root / "snapshot.tsv"
        rows = [
            ".codex/agents/one.toml\told-one\n",
            ".codex/agents/two.toml\tforeign-two\n",
            ".codex/agents/three.toml\told-three\n",
            ".config/foreign\tforeign\n",
        ]
        live.write_text("".join(rows), encoding="utf-8")
        snapshot.write_text("".join(rows), encoding="utf-8")
        filtered = run(
            self.root,
            self.source,
            self.destination,
            "--filter-manifests",
            str(live),
            str(snapshot),
            "--migrate-legacy-links",
        )
        self.assertEqual(filtered.returncode, 0, filtered.stderr)
        for path in (live, snapshot):
            content = path.read_text(encoding="utf-8")
            self.assertNotIn("one.toml", content)
            self.assertNotIn("three.toml", content)
            self.assertIn("two.toml", content)
            self.assertIn(".config/foreign", content)

    def test_filter_preserves_legacy_link_without_explicit_migration_flag(self) -> None:
        self.destination.mkdir(parents=True)
        target = self.destination / "one.toml"
        target.symlink_to(self.source / "one.toml")
        live = self.root / "live.tsv"
        snapshot = self.root / "snapshot.tsv"
        row = ".codex/agents/one.toml\tlegacy\n"
        live.write_text(row, encoding="utf-8")
        snapshot.write_text(row, encoding="utf-8")
        filtered = run(self.root, self.source, self.destination, "--filter-manifests", str(live), str(snapshot))
        self.assertEqual(filtered.returncode, 0, filtered.stderr)
        self.assertEqual(live.read_text(encoding="utf-8"), row)
        self.assertEqual(snapshot.read_text(encoding="utf-8"), row)

    def test_filter_rejects_malformed_or_mismatched_manifest_pair(self) -> None:
        self.bootstrap_regular_files()
        live = self.root / "live.tsv"
        snapshot = self.root / "snapshot.tsv"
        live.write_text(".codex/agents/one.toml\told\n", encoding="utf-8")
        snapshot.write_text("broken\n", encoding="utf-8")
        rejected = run(self.root, self.source, self.destination, "--filter-manifests", str(live), str(snapshot))
        self.assertNotEqual(rejected.returncode, 0)
        self.assertEqual(live.read_text(encoding="utf-8"), ".codex/agents/one.toml\told\n")


if __name__ == "__main__":
    unittest.main()
