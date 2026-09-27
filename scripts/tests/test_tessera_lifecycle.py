"""Project-wide catalog lifecycle through the CLI; no provider/network calls."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "ai/skills/tessera/scripts"))
import tessera

SCRIPT = Path(__file__).resolve().parents[2] / "ai/skills/tessera/scripts/tessera.py"


class LifecycleTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="tessera lifecycle ")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / "project"
        self.repo.mkdir()
        self.env = dict(os.environ, XDG_DATA_HOME=str(self.root / "data"),
                        LOCALAPPDATA=str(self.root / "data"), PYTHONDONTWRITEBYTECODE="1")
        self.git("init", "-q")
        (self.repo / "helper.ts").write_text("export const helper = () => 1;\n")
        (self.repo / "consumer.ts").write_text("helper();\n")
        (self.repo / "README.md").write_text("Project\n")
        self.commit()
        self.paths = self.call("locate")

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.repo), *args], stderr=subprocess.PIPE).decode().strip()

    def commit(self):
        self.git("add", ".")
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "fixture")

    def call(self, command, *args, ok=True):
        result = subprocess.run([sys.executable, str(SCRIPT), command, "--repo", str(self.repo), *map(str, args)],
                                env=self.env, capture_output=True, text=True)
        if not ok:
            self.assertNotEqual(result.returncode, 0)
            return result
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_status_is_read_only_and_initialization_has_full_inventory(self):
        self.assertEqual(self.call("status")["status"], "uninitialized")
        self.assertFalse(Path(self.paths["root"]).exists())
        report = self.call("init")
        self.assertEqual(report["status"], "initializing")
        self.assertEqual(report["pending_paths"], ["README.md", "consumer.ts", "helper.ts"])
        self.assertEqual(report["coverage"]["total"], 3)
        before = Path(self.paths["inventory"]).read_bytes()
        self.call("status")
        self.assertEqual(Path(self.paths["inventory"]).read_bytes(), before)
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.assertFalse((self.repo / ".tessera").exists())

    def catalog(self, unused=False):
        entry = {"id": "helper", "kind": "utility", "summary": "Constant factory",
                 "contract": "No arguments; returns 1", "constraints": [], "source": "helper.ts",
                 "usages": [] if unused else [{"path": "consumer.ts", "start": 1, "end": 1}], "tests": []}
        if unused:
            entry["usage_gap"] = "No consumers found after searching the complete source tree"
        value = {"schema": 1, "project": "fixture", "scope": ["helper.ts"],
                 "reviewed_revision": self.git("rev-parse", "HEAD"), "entries": [entry]}
        path = Path(self.paths["catalog"])
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value))
        path.chmod(0o600)
        return value

    def review(self, files, report=None, ok=True):
        report = report or self.call("status")
        batch = self.root / "batch.json"
        batch.write_text(json.dumps({"schema": 1, "revision": report["revision"],
                                    "inventory_sha256": report["inventory_sha256"], "files": files}))
        return self.call("review", "--batch", batch, ok=ok)

    def records(self):
        return [{"path": "helper.ts", "kind": "catalogued", "reason": "Contract and implementation inspected"},
                {"path": "consumer.ts", "kind": "supporting", "reason": "Actual consumer inspected"},
                {"path": "README.md", "kind": "excluded", "reason": "Project documentation, no implementation"}]

    def ready(self):
        self.call("init")
        self.catalog()
        self.review(self.records())
        return self.call("finalize")

    def test_batches_resume_and_only_finalize_certifies_coverage(self):
        self.call("init")
        self.catalog()
        report = self.review(self.records()[:1])
        self.assertEqual(report["coverage"]["reviewed"], 1)
        self.assertEqual(self.call("init")["coverage"]["reviewed"], 1, "init must preserve progress")
        self.call("finalize", ok=False)
        report = self.review(self.records()[1:])
        self.assertEqual(report["status"], "initializing")
        self.assertEqual(report["next_action"], "finalize")
        report = self.call("finalize")
        self.assertEqual(report["status"], "ready")
        self.assertEqual(report["coverage"], {"total": 3, "reviewed": 3, "protected": 0, "pending": 0})
        self.assertTrue(list(Path(self.paths["history"]).glob("inventory-*.json")))
        self.assertEqual(self.git("status", "--porcelain"), "")

    def test_catalogues_without_full_inventory_require_full_review(self):
        self.catalog()
        self.assertEqual(self.call("status")["status"], "needs_full_review")
        self.assertEqual(self.call("init")["coverage"]["pending"], 3)

    def test_new_deleted_and_renamed_files_require_incremental_review(self):
        self.ready()
        (self.repo / "new.utility").write_text("a new language-independent candidate\n")
        (self.repo / "README.md").rename(self.repo / "GUIDE.md")
        self.commit()
        status = self.call("status")
        self.assertEqual(status["status"], "needs_update")
        self.assertEqual(status["pending_paths"], ["GUIDE.md", "new.utility"])
        self.assertEqual(status["removed_paths"], ["README.md"])
        status = self.call("scan")
        self.assertEqual(status["coverage"]["reviewed"], 2)
        self.assertEqual(status["next_action"], "review")

    def test_source_and_consumer_edits_invalidate_readiness(self):
        self.ready()
        (self.repo / "consumer.ts").write_text("helper(); helper();\n")
        self.assertEqual(self.call("status")["status"], "blocked")
        self.commit()
        status = self.call("scan")
        self.assertEqual(status["pending_paths"], ["consumer.ts"])
        self.assertEqual(status["status"], "needs_update")
        self.review([self.records()[1]])
        self.assertIn("Curación", self.call("finalize", ok=False).stderr)
        self.catalog()
        self.assertEqual(self.call("finalize")["status"], "ready")

    def test_missing_baseline_requires_full_scan_and_preserves_catalog(self):
        self.ready()
        path = Path(self.paths["inventory"])
        state = json.loads(path.read_text())
        state["revision"] = "0" * 40
        path.write_text(json.dumps(state))
        catalog_before = Path(self.paths["catalog"]).read_bytes()
        self.assertEqual(self.call("status")["status"], "needs_full_review")
        self.call("scan", ok=False)
        report = self.call("scan", "--full")
        self.assertEqual(report["status"], "initializing")
        self.assertEqual(report["coverage"]["pending"], 3)
        self.assertEqual(Path(self.paths["catalog"]).read_bytes(), catalog_before)

    def test_stale_batch_and_lock_do_not_overwrite_progress(self):
        old = self.call("init")
        self.catalog()
        self.review(self.records()[:1])
        before = Path(self.paths["inventory"]).read_bytes()
        self.review(self.records()[1:], report=old, ok=False)
        lock = Path(self.paths["root"]) / "inventory.lock"
        lock.write_text("another process")
        self.call("scan", ok=False)
        self.assertEqual(Path(self.paths["inventory"]).read_bytes(), before)
        self.assertTrue(lock.exists())

    def test_unused_utility_can_be_catalogued_without_inventing_consumers(self):
        self.call("init")
        self.catalog(unused=True)
        self.review(self.records())
        self.assertEqual(self.call("finalize")["status"], "ready")

    def test_catalog_edit_requires_validation_and_prepare_can_require_ready(self):
        self.ready()
        catalog = Path(self.paths["catalog"])
        value = json.loads(catalog.read_text())
        value["entries"][0]["contract"] = "Returns constant 1"
        catalog.write_text(json.dumps(value))
        self.assertEqual(self.call("status")["status"], "needs_update")
        task = self.root / "task.json"
        task.write_text(json.dumps({"id": "fixture", "requirement": "Use the constant", "acceptance": ["Returns 1"]}))
        self.call("prepare", "--task", task, "--require-ready", ok=False)
        self.call("finalize")
        self.assertEqual(self.call("prepare", "--task", task, "--require-ready")["project_status"], "ready")

    def test_private_files_links_and_submodules_are_metadata_only(self):
        private_names = [".env.fixture", ".npmrc", ".netrc", ".pypirc", "credentials.json", "secrets.yaml",
                         "store.jks", "store.keystore", ".git-credentials"]
        for name in private_names:
            (self.repo / name).write_text("synthetic fixture, not a credential\n")
            self.git("add", "-f", name)
        if os.name != "nt":
            (self.repo / "external-link").symlink_to(self.root / "unavailable-target")
        self.commit()
        (self.repo / "nested-project").mkdir()
        self.git("update-index", "--add", "--cacheinfo", "160000", self.git("rev-parse", "HEAD"), "nested-project")
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "gitlink")
        original = Path.open

        def protected_open(path, *args, **kwargs):
            if path.name in {*private_names, "external-link", "nested-project"}:
                raise AssertionError("protected path content was opened")
            return original(path, *args, **kwargs)

        with patch.dict(os.environ, self.env), patch.object(Path, "open", protected_open):
            report = tessera.scan_project(self.repo, initialize=True)
            self.assertEqual(report["coverage"]["protected"], len(private_names) + (1 if os.name == "nt" else 2))
            tessera.project_status(self.repo)
        self.assertNotIn(".env.fixture", report["pending_paths"])
        self.review([{"path": ".env.fixture", "kind": "supporting", "reason": "must not read"}], ok=False)

    def test_finalization_rejects_excluded_sources_and_missing_usage_evidence(self):
        self.call("init")
        value = self.catalog()
        records = self.records()
        records[0]["kind"] = "excluded"
        self.review(records)
        self.call("finalize", ok=False)
        self.review([self.records()[0]])
        value["entries"][0]["usages"] = []
        Path(self.paths["catalog"]).write_text(json.dumps(value))
        self.assertIn("usage_gap", self.call("finalize", ok=False).stderr)

    def test_untracked_and_branch_switch_are_not_reported_ready(self):
        self.ready()
        before = self.git("rev-parse", "HEAD")
        (self.repo / "pending.ts").write_text("new module\n")
        report = self.call("status")
        self.assertEqual(report["status"], "blocked")
        self.assertEqual(report["checkout_changes"], ["pending.ts"])
        self.commit()
        self.assertEqual(self.call("status")["status"], "needs_update")
        self.git("checkout", "--detach", before)
        self.assertEqual(self.call("status")["status"], "ready")

    def test_failed_atomic_replace_keeps_previous_inventory_and_backup(self):
        self.ready()
        target = Path(self.paths["inventory"])
        before = target.read_bytes()
        with patch.dict(os.environ, self.env), patch.object(tessera.os, "replace", side_effect=OSError("interrupted")):
            with self.assertRaises(OSError):
                tessera.scan_project(self.repo, full=True)
        self.assertEqual(target.read_bytes(), before)
        self.assertTrue(any(p.read_bytes() == before for p in Path(self.paths["history"]).glob("inventory-*.json")))
        self.assertFalse((target.parent / "inventory.lock").exists())

    def test_repository_mutation_during_scan_does_not_save_stale_inventory(self):
        self.call("init")
        target = Path(self.paths["inventory"])
        before = target.read_bytes()
        original = tessera.project_snapshot
        calls = 0

        def changing(repo):
            nonlocal calls
            calls += 1
            if calls == 2:
                (self.repo / "README.md").write_text("changed during capture\n")
                self.commit()
            return original(repo)

        with patch.dict(os.environ, self.env), patch.object(tessera, "project_snapshot", side_effect=changing):
            with self.assertRaisesRegex(ValueError, "proyecto cambió"):
                tessera.scan_project(self.repo)
        self.assertEqual(target.read_bytes(), before)

    def test_ready_run_rechecks_live_catalog_before_network(self):
        self.ready()
        task = self.root / "task.json"
        task.write_text(json.dumps({"id": "fixture", "requirement": "Use the constant", "acceptance": ["Returns 1"]}))
        run = self.call("prepare", "--task", task, "--require-ready")["run"]
        value = self.catalog()
        value["entries"][0]["constraints"] = ["Changed contract"]
        Path(self.paths["catalog"]).write_text(json.dumps(value))
        with patch.dict(os.environ, self.env), patch.object(tessera.tessera_typesafe, "invoke") as invoke:
            with self.assertRaisesRegex(ValueError, "cobertura cambió"):
                tessera.evaluate(Path(run))
            invoke.assert_not_called()
        self.assertFalse((Path(run) / "attempt.json").exists())

    def test_empty_catalog_still_requires_review_of_every_file(self):
        self.call("init")
        path = Path(self.paths["catalog"])
        path.write_text(json.dumps({"schema": 1, "project": "fixture", "scope": [], "entries": [],
                                    "reviewed_revision": self.git("rev-parse", "HEAD")}))
        path.chmod(0o600)
        self.call("finalize", ok=False)
        self.review([{**record, "kind": "excluded", "reason": "Inspected fixture; deliberately excluded for this test"}
                     for record in self.records()])
        self.assertEqual(self.call("finalize")["status"], "ready")

    def test_status_hash_and_report_refer_to_same_inventory_version(self):
        self.call("init")
        inventory = Path(self.paths["inventory"])
        original = inventory.read_bytes()
        replacement = json.loads(original)
        replacement["files"]["README.md"]["review"] = {"kind": "excluded", "reason": "Concurrent review"}
        original_read = Path.read_bytes
        switched = False

        def read_then_replace(path):
            nonlocal switched
            data = original_read(path)
            if path == inventory and not switched:
                switched = True
                candidate = inventory.with_suffix(".tmp")
                candidate.write_bytes(tessera.encoded(replacement))
                os.replace(candidate, inventory)
            return data

        with patch.dict(os.environ, self.env), patch.object(Path, "read_bytes", read_then_replace):
            report = tessera.project_status(self.repo)
        self.assertEqual(report["inventory_sha256"], tessera.digest(original))
        self.assertIn("README.md", report["pending_paths"])
        self.review(self.records(), report=report, ok=False)

    def test_prepare_rejects_concurrent_changes_outside_catalog(self):
        self.ready()
        task = self.root / "task.json"
        task.write_text(json.dumps({"id": "fixture", "requirement": "Use constant", "acceptance": ["Returns 1"]}))
        original = tessera.build_evidence

        def capture_with_new_file(catalog, repo):
            (self.repo / "outside-scope.ts").write_text("new reusable module\n")
            self.commit()
            return original(catalog, repo)

        output = self.root / "never-created"
        with patch.dict(os.environ, self.env), patch.object(tessera, "build_evidence", side_effect=capture_with_new_file):
            with self.assertRaisesRegex(ValueError, "cobertura cambió"):
                tessera.prepare(Path(self.paths["catalog"]), self.repo, task, output, require_ready=True)
        self.assertFalse(output.exists())

    def test_sha256_repository_can_reach_ready(self):
        target = self.root / "sha256-project"
        result = subprocess.run(["git", "init", "-q", "--object-format=sha256", str(target)], capture_output=True)
        if result.returncode:
            self.skipTest("This Git does not support SHA-256 repositories")
        for name in ("helper.ts", "consumer.ts", "README.md"):
            (target / name).write_bytes((self.repo / name).read_bytes())
        self.repo = target
        self.commit()
        self.paths = self.call("locate")
        self.assertEqual(len(self.git("rev-parse", "HEAD")), 64)
        self.assertEqual(self.ready()["status"], "ready")


if __name__ == "__main__":
    unittest.main()
