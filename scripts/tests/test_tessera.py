"""Contract tests only. No Jev call and no claim about model quality."""
import json
import copy
import importlib.util
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[2] / "ai/skills/tessera/scripts/tessera.py"
sys.path.insert(0, str(SCRIPT.parent))
SPEC = importlib.util.spec_from_file_location("tessera", SCRIPT)
tessera = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(tessera)


class TesseraTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="tessera test ")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / "repo"
        (self.repo / "src/ui").mkdir(parents=True)
        (self.repo / "src/ui/Button.tsx").write_text("export function Button() {}\n")
        (self.repo / "src/use.tsx").write_text("Button();\n")
        (self.repo / "src/ui/Button.test.tsx").write_text("// contract test\n")
        for command in (["init", "-q"], ["add", "."],
                        ["-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                         "commit", "-qm", "fixture"]):
            subprocess.run(["git", "-C", str(self.repo), *command], check=True,
                           capture_output=True)
        self.catalog = self.root / "catalog.json"
        self.data = {
            "schema": 1, "project": "fixture", "scope": ["src/ui"],
            "entries": [{"id": "button", "kind": "component", "summary": "Action.",
                         "contract": "Native button.", "constraints": ["Not navigation."],
                         "source": "src/ui/Button.tsx",
                         "usages": [{"path": "src/use.tsx", "start": 1, "end": 1}],
                         "tests": ["src/ui/Button.test.tsx"]}],
        }
        self.catalog.write_text(json.dumps(self.data))
        self.task = self.root / "task.json"
        self.task.write_text(json.dumps({"id": "action", "requirement": "A button",
                                         "acceptance": ["Native button semantics"]}))
        self.run_dir = self.root / "run"

    def call(self, *args):
        env = dict(os.environ)
        env.pop("TYPESAFE_API_KEY", None)
        return subprocess.run([sys.executable, str(SCRIPT), *map(str, args)],
                              capture_output=True, text=True, env=env)

    def prepare(self):
        self.catalog.write_text(json.dumps(self.data))
        return self.call("prepare", "--catalog", self.catalog, "--repo", self.repo,
                         "--task", self.task, "--output", self.run_dir)

    def test_tests_never_opened_or_sent_even_from_legacy_catalog(self):
        original = Path.open

        def guarded(path, *args, **kwargs):
            if path.is_relative_to(self.repo) and tessera.is_test_path(path.relative_to(self.repo).as_posix()):
                raise AssertionError("Tessera opened a test")
            return original(path, *args, **kwargs)

        # A legacy test reference need not even exist: it is never resolved.
        self.data["entries"][0]["tests"].append("tests/missing.py")
        with patch.object(Path, "open", guarded):
            evidence = tessera.build_evidence(self.data, self.repo)
            context = tessera.build_context(self.data, evidence, json.loads(self.task.read_text()))
        self.assertEqual(set(evidence["files"]), {"src/ui/Button.tsx", "src/use.tsx"})
        self.assertNotIn("tests", context["catalog"]["entries"][0])
        self.assertNotIn("Button.test.tsx", json.dumps(context))
        self.assertIn("tests", self.data["entries"][0], "Do not mutate the original catalog")
        for role in ("source", "usages", "supporting_files"):
            value = copy.deepcopy(self.data)
            if role == "source":
                value["entries"][0]["source"] = "src/ui/Button.test.tsx"
            elif role == "usages":
                value["entries"][0]["usages"][0]["path"] = "src/ui/Button.test.tsx"
            else:
                value[role] = ["src/ui/Button.test.tsx"]
            with self.subTest(role=role), patch.object(Path, "open", guarded):
                with self.assertRaisesRegex(ValueError, "Tests fuera"):
                    tessera.build_evidence(value, self.repo)

    def test_test_config_patterns_preserve_similarly_named_production_files(self):
        for name in ("test.ts", "spec.ts", "conftest.py", "vitest.config.ts", "vitest.setup.ts",
                     "jest.config.js", "playwright.config.ts", "cypress.config.ts"):
            with self.subTest(name=name):
                self.assertTrue(tessera.is_test_path(name))
        for name in ("app/types/testimonial.ts", "Testimonial.vue", "contest.ts"):
            with self.subTest(name=name):
                self.assertFalse(tessera.is_test_path(name))

    def test_test_only_commits_do_not_stale_catalog_or_changes(self):
        self.data["reviewed_revision"] = tessera.git(self.repo, "rev-parse", "HEAD").decode().strip()
        (self.repo / "src/ui/Button.test.tsx").write_text("changed test\n")
        tessera.git(self.repo, "add", ".")
        tessera.git(self.repo, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                    "commit", "-qm", "tests only")
        self.catalog.write_text(json.dumps(self.data))
        report = tessera.catalog_changes(self.catalog, self.repo)
        self.assertEqual(report["status"], "current")
        self.assertEqual(report["changed_paths"], [])
        self.assertEqual(report["outside_catalog_changes"], [])
        self.assertEqual(tessera.build_evidence(self.data, self.repo)["curation"]["status"], "current")

    def test_prepare_full_catalog_with_local_code_and_provenance(self):
        result = self.prepare()
        self.assertEqual(result.returncode, 0, result.stderr)
        request = json.loads((self.run_dir / "request.json").read_text())
        self.assertEqual(set(request), {"state", "model", "questions"})
        self.assertEqual(request["model"], "jev-1.13.0")
        self.assertEqual(set(request["questions"]["decision"]["criteria"]),
                         {"reuse:button", "modify:button", "wrap:button", "create", "insufficient_evidence"})
        expected = copy.deepcopy(self.data)
        expected["entries"][0].pop("tests")
        self.assertEqual(request["state"]["catalog"], expected)
        evidence = request["state"]["evidence"]
        self.assertFalse(evidence["source_text_included"])
        derived = json.loads((self.run_dir / "derived.json").read_text())
        self.assertEqual(derived["inventory"], ["src/ui/Button.tsx"])
        self.assertIn("export function Button", derived["files"]["src/ui/Button.tsx"]["text"])
        self.assertNotIn("export function Button", (self.run_dir / "request.json").read_text())
        self.assertEqual(len(evidence["revision"]), 40)
        self.assertFalse((self.run_dir / "decision.json").exists())

    def test_storage_is_external_and_shared_only_by_linked_worktrees(self):
        env = {"XDG_DATA_HOME": str(self.root / "data"), "LOCALAPPDATA": str(self.root / "data")}
        with patch.dict(os.environ, env):
            paths = tessera.storage_paths(self.repo)
            self.assertEqual(paths, tessera.storage_paths(self.repo / "src"))
            self.assertFalse(Path(paths["root"]).exists(), "locate must be read-only")
            worktree = self.root / "linked worktree"
            subprocess.run(["git", "-C", str(self.repo), "worktree", "add", "--detach", str(worktree)],
                           check=True, capture_output=True)
            self.assertEqual(paths, tessera.storage_paths(worktree))
            clone = self.root / "separate clone"
            subprocess.run(["git", "clone", str(self.repo), str(clone)], check=True, capture_output=True)
            self.assertNotEqual(paths["root"], tessera.storage_paths(clone)["root"])
            self.assertFalse((self.repo / ".tessera").exists())

    def test_default_prepare_uses_local_catalog_and_leaves_repo_untouched(self):
        env = {"XDG_DATA_HOME": str(self.root / "data"), "LOCALAPPDATA": str(self.root / "data")}
        with patch.dict(os.environ, env):
            paths = json.loads(self.call("locate", "--repo", self.repo).stdout)
            catalog = Path(paths["catalog"])
            catalog.parent.mkdir(parents=True, mode=0o700)
            catalog.write_text(json.dumps(self.data))
            catalog.chmod(0o600)
            result = self.call("prepare", "--repo", self.repo, "--task", self.task)
            self.assertEqual(result.returncode, 0, result.stderr)
            run = Path(json.loads(result.stdout)["run"])
            self.assertEqual(run.parent, Path(paths["runs"]))
            request = json.loads((run / "request.json").read_text())
            expected = copy.deepcopy(self.data)
            expected["entries"][0].pop("tests")
            self.assertEqual(request["state"]["catalog"], expected)
            if os.name != "nt":
                self.assertEqual(run.stat().st_mode & 0o777, 0o700)
                self.assertEqual(run.parent.stat().st_mode & 0o777, 0o700)
                self.assertEqual((run / "request.json").stat().st_mode & 0o777, 0o600)
        status = subprocess.check_output(["git", "-C", str(self.repo), "status", "--porcelain"])
        self.assertEqual(status, b"")

    @unittest.skipIf(os.name == "nt", "POSIX permission bits")
    def test_inputs_require_private_file_or_private_parent(self):
        self.root.chmod(0o755)
        self.catalog.chmod(0o644)
        self.task.chmod(0o644)
        with self.assertRaisesRegex(ValueError, "accesible por otros"):
            tessera.prepare(self.catalog, self.repo, self.task, self.run_dir)
        self.assertFalse(self.run_dir.exists())
        self.catalog.chmod(0o600)
        with self.assertRaisesRegex(ValueError, "accesible por otros"):
            tessera.prepare(self.catalog, self.repo, self.task, self.run_dir)
        self.task.chmod(0o600)
        tessera.prepare(self.catalog, self.repo, self.task, self.run_dir)
        self.catalog.chmod(0o644)
        self.root.chmod(0o700)
        tessera.require_private_input(self.catalog)

    def test_repo_storage_requires_opt_in_even_in_another_repository(self):
        self.catalog.write_text(json.dumps(self.data))
        for kind in ("catalog", "task", "output"):
            with self.subTest(kind=kind):
                catalog, task, output = self.catalog, self.task, self.run_dir
                target = self.repo / (kind + ".json")
                if kind == "catalog":
                    target.write_text(self.catalog.read_text()); catalog = target
                elif kind == "task":
                    target.write_text(self.task.read_text()); task = target
                else:
                    output = target
                result = self.call("prepare", "--repo", self.repo, "--catalog", catalog,
                                   "--task", task, "--output", output)
                self.assertIn("Almacenamiento dentro", result.stderr)
                self.assertFalse(output.exists())
        result = self.call("prepare", "--repo", self.repo, "--catalog", self.repo / "catalog.json",
                           "--task", self.task, "--output", self.run_dir, "--allow-repo-storage")
        self.assertEqual(result.returncode, 0, result.stderr)
        other = self.root / "personal dotfiles"
        subprocess.run(["git", "init", "-q", str(other)], check=True)
        with self.assertRaisesRegex(ValueError, "Almacenamiento dentro"):
            tessera.require_external(other / "work-catalog.json")

    @unittest.skipIf(os.name == "nt", "Requires POSIX symlinks")
    def test_storage_cannot_be_redirected_into_repo(self):
        link = self.root / "external looking"
        link.symlink_to(self.repo, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "Almacenamiento dentro"):
            tessera.require_external(link / "new-run")
        with patch.dict(os.environ, {"XDG_DATA_HOME": str(self.repo / "data")}):
            with self.assertRaisesRegex(ValueError, "Almacenamiento dentro"):
                tessera.storage_paths(self.repo)

    def commit_all(self):
        subprocess.run(["git", "-C", str(self.repo), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.repo), "-c", "user.name=Test",
                        "-c", "user.email=test@example.invalid", "commit", "-qm", "colleague change"], check=True)

    def reviewed_catalog(self):
        self.data["reviewed_revision"] = subprocess.check_output(
            ["git", "-C", str(self.repo), "rev-parse", "HEAD"], text=True).strip()
        self.catalog.write_text(json.dumps(self.data))

    def test_changes_detects_colleague_additions_removals_and_modified_usages(self):
        self.reviewed_catalog()
        before = self.catalog.read_bytes()
        self.assertEqual(tessera.catalog_changes(self.catalog, self.repo)["status"], "current")
        (self.repo / "src/ui/Button.tsx").rename(self.repo / "src/ui/PrimaryButton.tsx")
        (self.repo / "src/ui/New.tsx").write_text("export function New() {}\n")
        (self.repo / "src/use.tsx").write_text("PrimaryButton();\n")
        self.commit_all()
        changes = tessera.catalog_changes(self.catalog, self.repo)
        self.assertEqual(changes["status"], "needs_review")
        self.assertEqual(changes["added_sources"], ["src/ui/New.tsx", "src/ui/PrimaryButton.tsx"])
        self.assertEqual(changes["removed_sources"], ["src/ui/Button.tsx"])
        self.assertIn("src/use.tsx", changes["changed_paths"])
        self.assertEqual(changes["affected_entries"], ["button"])
        self.assertIn("src/ui/Button.tsx", changes["missing_references"])
        self.assertEqual(self.catalog.read_bytes(), before, "report must not invent updated contracts")

    def test_changes_reports_untracked_and_uncommitted_sources(self):
        self.reviewed_catalog()
        (self.repo / "src/ui/Button.tsx").write_text("export function Button() { return 'changed'; }\n")
        (self.repo / "src/ui/New.tsx").write_text("export function New() {}\n")
        changes = tessera.catalog_changes(self.catalog, self.repo)
        self.assertEqual(changes["status"], "needs_review")
        self.assertEqual(changes["working_changes"], ["src/ui/Button.tsx", "src/ui/New.tsx"])
        self.assertEqual(changes["affected_entries"], ["button"])

    def test_changes_distinguishes_unrelated_commits_and_missing_baselines(self):
        self.reviewed_catalog()
        (self.repo / "README.md").write_text("Unrelated documentation\n")
        self.commit_all()
        changes = tessera.catalog_changes(self.catalog, self.repo)
        self.assertEqual(changes["status"], "current")
        self.assertEqual(changes["affected_entries"], [])
        self.assertEqual(changes["outside_catalog_changes"], ["README.md"])
        self.data["reviewed_revision"] = "0" * 40
        self.catalog.write_text(json.dumps(self.data))
        changes = tessera.catalog_changes(self.catalog, self.repo)
        self.assertEqual(changes["status"], "needs_review")
        self.assertEqual(changes["reason"], "missing_or_unavailable_baseline")
        self.assertEqual(changes["affected_entries"], ["button"])

    def test_changes_reports_local_additions_and_edits_outside_catalog(self):
        helper = self.repo / "src/helper.ts"
        helper.write_text("export const value = 1;\n")
        self.commit_all()
        self.reviewed_catalog()
        helper.write_text("export const value = 2;\n")
        (self.repo / "src/new-helper.ts").write_text("export const added = true;\n")
        changes = tessera.catalog_changes(self.catalog, self.repo)
        self.assertEqual(changes["outside_catalog_changes"], ["src/helper.ts", "src/new-helper.ts"])
        self.assertEqual(changes["working_changes"], [])
        self.assertEqual(changes["affected_entries"], [])

    def test_evaluate_rejects_run_moved_inside_repository_before_network(self):
        self.assertEqual(self.prepare().returncode, 0)
        moved = self.repo / "copied-run"
        shutil.move(self.run_dir, moved)
        with patch.object(tessera.tessera_typesafe, "invoke") as invoke:
            with self.assertRaisesRegex(ValueError, "Almacenamiento dentro"):
                tessera.evaluate(moved)
            if os.name != "nt":
                self.run_dir.symlink_to(moved, target_is_directory=True)
                with self.assertRaisesRegex(ValueError, "Almacenamiento dentro"):
                    tessera.evaluate(self.run_dir)
            invoke.assert_not_called()
        self.assertFalse((moved / "attempt.json").exists())
        _, response = self.request_and_answer()
        with patch.object(tessera.tessera_typesafe, "check_credentials"), \
             patch.object(tessera.tessera_typesafe, "invoke", return_value=tessera.encoded(response)):
            decision = tessera.evaluate(moved, allow_repo_storage=True)
        self.assertEqual(decision["action"], "wrap")

    def test_evaluate_rechecks_checkout_after_preparation_before_network(self):
        self.assertEqual(self.prepare().returncode, 0)
        (self.repo / "src/ui/Button.tsx").write_text("export function Button() { return 'new contract'; }\n")
        self.commit_all()
        with patch.object(tessera.tessera_typesafe, "invoke") as invoke:
            with self.assertRaisesRegex(ValueError, "proyecto cambió"):
                tessera.evaluate(self.run_dir)
            invoke.assert_not_called()
        self.assertFalse((self.run_dir / "attempt.json").exists())

    def test_new_candidate_cannot_disappear_and_can_be_curated(self):
        (self.repo / "src/ui/New.tsx").write_text("export function New() {}\n")
        subprocess.run(["git", "-C", str(self.repo), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.repo), "-c", "user.name=Test",
                        "-c", "user.email=test@example.invalid", "commit", "-qm", "new"], check=True)
        self.assertIn("Cobertura incompleta", self.prepare().stderr)
        entry = dict(self.data["entries"][0], id="new", source="src/ui/New.tsx")
        self.data["entries"].append(entry)
        self.assertEqual(self.prepare().returncode, 0)
        request = json.loads((self.run_dir / "request.json").read_text())
        self.assertIn("wrap:new", request["questions"]["decision"]["criteria"])

    def test_dirty_snapshot_is_not_claimed_as_revision(self):
        (self.repo / "src/ui/Button.tsx").write_text("changed\n")
        self.assertIn("Checkout con cambios", self.prepare().stderr)
        self.assertFalse(self.run_dir.exists())

    def test_private_traversal_and_symlink_references_fail(self):
        for source in ("../secret", ".env", "src/.env.local", "/etc/passwd"):
            with self.subTest(source=source):
                self.data["entries"][0]["source"] = source
                self.assertNotEqual(self.prepare().returncode, 0)
                self.assertFalse(self.run_dir.exists())
        if os.name != "nt":
            (self.repo / "src/link").symlink_to(self.repo / "src/ui/Button.tsx")
            self.data["entries"][0]["source"] = "src/link"
            self.assertIn("Enlaces", self.prepare().stderr)

    def test_duplicate_ids_and_invalid_usage_ranges_fail(self):
        self.data["entries"].append(copy.deepcopy(self.data["entries"][0]))
        self.assertIn("ID inválido o duplicado", self.prepare().stderr)
        self.data["entries"].pop()
        self.data["entries"][0]["usages"][0]["end"] = 999
        self.assertIn("Rango de uso inválido", self.prepare().stderr)

    def test_prepare_never_overwrites_and_evaluate_requires_credential(self):
        self.assertEqual(self.prepare().returncode, 0)
        before = (self.run_dir / "request.json").read_bytes()
        self.assertNotEqual(self.prepare().returncode, 0)
        self.assertEqual((self.run_dir / "request.json").read_bytes(), before)
        result = self.call("evaluate", "--run", self.run_dir)
        self.assertIn("no se llamó a Jev", result.stderr)
        self.assertFalse((self.run_dir / "attempt.json").exists())

    def test_modified_request_is_rejected_before_network(self):
        self.prepare()
        with (self.run_dir / "request.json").open("a") as stream:
            stream.write(" ")
        self.assertIn("petición cambió", self.call("evaluate", "--run", self.run_dir).stderr)

    def test_unknown_fields_cannot_leak_into_request(self):
        for target in (self.data, self.data["entries"][0], self.data["entries"][0]["usages"][0]):
            target["expected_action"] = "unexpected-content"
            result = self.prepare()
            self.assertIn("Campos ausentes o desconocidos", result.stderr)
            self.assertNotIn("unexpected-content", result.stderr)
            self.assertFalse(self.run_dir.exists())
            del target["expected_action"]

    def test_manifest_revision_cannot_forge_decision_provenance(self):
        self.prepare()
        path = self.run_dir / "manifest.json"
        manifest = json.loads(path.read_text())
        manifest["revision"] = "0" * 40
        path.write_text(json.dumps(manifest))
        self.assertIn("petición cambió", self.call("evaluate", "--run", self.run_dir).stderr)
        self.assertFalse((self.run_dir / "attempt.json").exists())

    def test_older_curation_is_explicitly_stale(self):
        self.data["reviewed_revision"] = "0" * 40
        self.assertEqual(self.prepare().returncode, 0)
        context = json.loads((self.run_dir / "context.json").read_text())
        self.assertEqual(context["evidence"]["curation"]["status"], "stale")
        self.assertIn("Curación obsoleta", self.call("evaluate", "--run", self.run_dir).stderr)
        self.assertFalse((self.run_dir / "attempt.json").exists())

    def test_unrelated_commit_does_not_make_curation_stale(self):
        self.data["reviewed_revision"] = subprocess.check_output(
            ["git", "-C", str(self.repo), "rev-parse", "HEAD"], text=True).strip()
        (self.repo / "README.md").write_text("unrelated docs\n")
        subprocess.run(["git", "-C", str(self.repo), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.repo), "-c", "user.name=Test", "-c",
                        "user.email=test@example.invalid", "commit", "-qm", "docs"], check=True)
        self.assertEqual(self.prepare().returncode, 0)
        context = json.loads((self.run_dir / "context.json").read_text())
        self.assertEqual(context["evidence"]["curation"]["status"], "current")

    def test_checkout_change_during_capture_is_rejected(self):
        real_git = tessera.git
        head_reads = 0

        def changing_git(repo, *args):
            nonlocal head_reads
            if args == ("rev-parse", "HEAD"):
                head_reads += 1
                if head_reads > 1:
                    return b"0000000000000000000000000000000000000000\n"
            return real_git(repo, *args)

        with patch.object(tessera, "git", side_effect=changing_git):
            with self.assertRaisesRegex(ValueError, "checkout cambió"):
                tessera.build_evidence(self.data, self.repo)

    def test_crlf_checkout_does_not_make_unchanged_git_contract_stale(self):
        self.data["reviewed_revision"] = subprocess.check_output(
            ["git", "-C", str(self.repo), "rev-parse", "HEAD"], text=True).strip()
        subprocess.run(["git", "-C", str(self.repo), "config", "core.autocrlf", "true"], check=True)
        for path in (self.repo / "src").rglob("*.tsx"):
            path.write_bytes(path.read_bytes().replace(b"\r\n", b"\n").replace(b"\n", b"\r\n"))
        subprocess.run(["git", "-C", str(self.repo), "-c", "user.name=Test", "-c",
                        "user.email=test@example.invalid", "commit", "--allow-empty", "-qm", "unrelated"], check=True)
        self.assertEqual(self.prepare().returncode, 0)
        context = json.loads((self.run_dir / "context.json").read_text())
        self.assertEqual(context["evidence"]["curation"]["status"], "current")

    def test_derived_artifact_tampering_blocks_call(self):
        self.prepare()
        with (self.run_dir / "derived.json").open("a") as stream:
            stream.write(" ")
        self.assertIn("petición cambió", self.call("evaluate", "--run", self.run_dir).stderr)
        self.assertFalse((self.run_dir / "attempt.json").exists())

    def test_compact_context_keeps_all_cards_and_raw_evidence_local(self):
        (self.repo / "theme.css").write_text("/* private-code-marker */\n" * 1000)
        subprocess.run(["git", "-C", str(self.repo), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.repo), "-c", "user.name=Test", "-c",
                        "user.email=test@example.invalid", "commit", "-qm", "theme"], check=True)
        self.data["supporting_files"] = ["theme.css"]
        self.data["entries"][0].update(name="Button", tags=["action", "native"])
        result = self.prepare()
        self.assertEqual(result.returncode, 0, result.stderr)
        context = json.loads((self.run_dir / "context.json").read_text())
        derived = json.loads((self.run_dir / "derived.json").read_text())
        self.assertEqual(len(context["options"]), 5)
        expected = copy.deepcopy(self.data)
        expected["entries"][0].pop("tests")
        self.assertEqual(context["catalog"], expected)
        self.assertIn("private-code-marker", derived["files"]["theme.css"]["text"])
        self.assertNotIn("private-code-marker", (self.run_dir / "request.json").read_text())
        self.assertNotIn("export function", (self.run_dir / "context.json").read_text())
        self.assertFalse(context["evidence"]["source_text_included"])

    @unittest.skipIf(os.name == "nt", "POSIX permission bits")
    def test_sensitive_artifacts_private_even_with_permissive_umask(self):
        previous = os.umask(0)
        try:
            self.assertEqual(self.prepare().returncode, 0)
        finally:
            os.umask(previous)
        self.assertEqual(self.run_dir.stat().st_mode & 0o777, 0o700)
        for path in self.run_dir.iterdir():
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def request_and_answer(self):
        request = tessera.PROVIDERS["typesafe"].build_request(tessera.build_context(self.data, {"revision": "0" * 40, "curation": {"status": "unverified"}}, json.loads(self.task.read_text())))
        options = request["questions"]["decision"]["criteria"]
        response = {"model": "jev-1.13.0", "answers": {"decision": {
            "type": "choice", "choice": "wrap:button", "confidence": 0.8,
            "probabilities": {name: float(name == "wrap:button") for name in options}}},
            "usage": {"input_tokens": 1200, "output_tokens": 40}}
        return request, response

    def test_joint_decision_keeps_confidence_and_rationale_separate(self):
        request, response = self.request_and_answer()
        answer = tessera.PROVIDERS["typesafe"].validate_response(request, response)
        decision = tessera.normalize_decision(tessera.build_context(self.data, {"revision": "0" * 40, "curation": {"status": "unverified"}}, json.loads(self.task.read_text())), answer)
        self.assertEqual(decision, {"action": "wrap", "primary": "button",
                                   "review_status": "pending", "agent_explanation": None})
        self.assertEqual(response["answers"]["decision"]["confidence"], 0.8)

    def test_malformed_response_never_becomes_decision(self):
        request, original = self.request_and_answer()
        for field, value in (("choice", "reuse:missing"), ("confidence", float("nan")),
                             ("confidence", True), ("probabilities", {"wrap:button": 1.0})):
            response = copy.deepcopy(original)
            response["answers"]["decision"][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                tessera.PROVIDERS["typesafe"].validate_response(request, response)
        response = copy.deepcopy(original)
        response["answers"]["decision"]["probabilities"]["wrap:button"] = 0.2
        with self.assertRaises(ValueError):
            tessera.PROVIDERS["typesafe"].validate_response(request, response)

    def test_rounded_live_distribution_is_preserved_without_normalizing(self):
        request, response = self.request_and_answer()
        response["answers"]["decision"]["probabilities"]["wrap:button"] = 0.99
        answer = tessera.PROVIDERS["typesafe"].validate_response(request, response)
        self.assertEqual(answer["probabilities"]["wrap:button"], 0.99)
        self.assertEqual(answer["probability_sum"], 0.99)

    def test_kev_receives_identical_catalog_and_uses_distinct_identity(self):
        context = tessera.build_context(self.data, {"revision": "0" * 40,
                                       "curation": {"status": "unverified"}}, json.loads(self.task.read_text()))
        jev = tessera.PROVIDERS["typesafe"].build_request(context)
        kev = tessera.PROVIDERS["kev"].build_request(context)
        self.assertEqual(jev["state"], kev["state"])
        self.assertEqual(jev["questions"], kev["questions"])
        self.assertEqual(kev["model"], "kev-latest")

    def test_kev_endpoint_is_explicit_and_checked_again_before_network(self):
        provider = tessera.PROVIDERS["kev"]
        with patch.dict(os.environ, {"TESSERA_KEV_ENDPOINT": "http://127.0.0.1:8009/v1/systemone"}):
            tessera.prepare(self.catalog, self.repo, self.task, self.run_dir, "kev")
        with patch.dict(os.environ, {"TESSERA_KEV_ENDPOINT": "https://different.example/v1/systemone"}), \
                patch.object(provider, "invoke") as send:
            with self.assertRaisesRegex(ValueError, "petición cambió"):
                tessera.evaluate(self.run_dir)
            send.assert_not_called()
        self.assertFalse((self.run_dir / "attempt.json").exists())

    def test_kev_rejects_missing_and_unsafe_destinations(self):
        provider = tessera.PROVIDERS["kev"]
        for endpoint in ("", "http://remote.example/v1/systemone", "https://u:private@kev.example/v1/systemone",
                         "https://kev.example/v1/systemone?key=private", "file:///v1/systemone"):
            with self.subTest(endpoint=endpoint), patch.dict(os.environ, {"TESSERA_KEV_ENDPOINT": endpoint}):
                with self.assertRaises(ValueError):
                    provider.endpoint()

    def test_kev_never_uses_typesafe_credentials(self):
        provider = tessera.PROVIDERS["kev"]
        with patch.dict(os.environ, {"TESSERA_KEV_ENDPOINT": "http://127.0.0.1:8009/v1/systemone",
                                    "TYPESAFE_API_KEY": "test-only-jev", "KEV_API_KEY": ""}), \
                patch.object(provider.wire, "invoke", return_value=b"{}") as send:
            provider.invoke(b"{}")
            self.assertIsNone(send.call_args.kwargs["api_key"])
            self.assertEqual(send.call_args.kwargs["endpoint"], provider.endpoint())

    def test_kev_remote_requires_own_credential_and_records_kev_identity(self):
        provider = tessera.PROVIDERS["kev"]
        with patch.dict(os.environ, {"TESSERA_KEV_ENDPOINT": "https://kev.example/v1/systemone",
                                    "TYPESAFE_API_KEY": "test-only-jev", "KEV_API_KEY": ""}):
            with self.assertRaisesRegex(ValueError, "Falta KEV_API_KEY"):
                provider.check_credentials()
        with patch.dict(os.environ, {"TESSERA_KEV_ENDPOINT": "http://127.0.0.1:8009/v1/systemone",
                                    "KEV_API_KEY": ""}):
            tessera.prepare(self.catalog, self.repo, self.task, self.run_dir, "kev")
            _, response = self.request_and_answer()
            response["model"] = "kev-latest"
            with patch.object(provider, "invoke", return_value=json.dumps(response).encode()):
                decision = tessera.evaluate(self.run_dir)
        self.assertEqual(decision["provider"], "kev")
        self.assertEqual(decision["model"], "kev-latest")
        self.assertEqual(decision["action"], "wrap")

    def test_official_option_limit_fails_without_selecting_subset(self):
        self.data["entries"] = [dict(self.data["entries"][0], id=f"item-{i}") for i in range(85)]
        context = tessera.build_context(self.data, {"revision": "0" * 40, "curation": {"status": "unverified"}}, json.loads(self.task.read_text()))
        self.assertEqual(len(context["options"]), 257)
        self.assertNotIn("provider", context)
        self.assertNotIn("model", context)
        for provider in tessera.PROVIDERS.values():
            with self.subTest(provider=provider.ID), self.assertRaisesRegex(ValueError, "255"):
                provider.build_request(context)

    def test_http_failure_reserves_one_attempt_and_hides_response_body(self):
        self.prepare()
        error = tessera.PROVIDERS["typesafe"].wire.urllib.error.HTTPError(tessera.PROVIDERS["typesafe"].ENDPOINT, 401, "private error text", {}, io.BytesIO(b'private response text'))
        with patch.dict(os.environ, {"TYPESAFE_API_KEY": "test-only-not-a-real-key"}), \
                patch.object(tessera.PROVIDERS["typesafe"].wire.urllib.request.OpenerDirector, "open", side_effect=error) as send:
            with self.assertRaisesRegex(ValueError, "TypeSafe HTTP 401"):
                tessera.evaluate(self.run_dir)
            with self.assertRaises(FileExistsError):
                tessera.evaluate(self.run_dir)
            self.assertEqual(send.call_count, 1)
        self.assertTrue((self.run_dir / "attempt.json").exists())
        self.assertFalse((self.run_dir / "decision.json").exists())
        failure = (self.run_dir / "failure.json").read_text()
        self.assertIn("TypeSafe HTTP 401", failure)
        self.assertNotIn("private error text", failure)
        self.assertNotIn("private response text", failure)
        self.assertEqual((self.run_dir / "http-error.bin").read_bytes(), b'private response text')

    def test_malformed_success_body_is_preserved_without_decision(self):
        self.prepare()
        provider = tessera.PROVIDERS["typesafe"]
        raw = b'{not-valid-json'
        with patch.dict(os.environ, {"TYPESAFE_API_KEY": "test-only-not-a-real-key"}), \
                patch.object(provider, "invoke", return_value=raw):
            with self.assertRaises(ValueError):
                tessera.evaluate(self.run_dir)
        self.assertEqual((self.run_dir / "response.json").read_bytes(), raw)
        self.assertIn("parse-response", (self.run_dir / "failure.json").read_text())
        self.assertFalse((self.run_dir / "decision.json").exists())

    def test_existing_result_blocks_call_before_billing(self):
        self.prepare()
        (self.run_dir / "response.json").write_text("existing")
        provider = tessera.PROVIDERS["typesafe"]
        with patch.dict(os.environ, {"TYPESAFE_API_KEY": "test-only-not-a-real-key"}), \
                patch.object(provider, "invoke") as send:
            with self.assertRaises(FileExistsError):
                tessera.evaluate(self.run_dir)
            send.assert_not_called()
        self.assertEqual((self.run_dir / "response.json").read_text(), "existing")

    def test_valid_wire_response_produces_traceable_neutral_decision(self):
        self.prepare()
        _, response = self.request_and_answer()
        raw = json.dumps(response).encode()
        provider = tessera.PROVIDERS["typesafe"]
        with patch.dict(os.environ, {"TYPESAFE_API_KEY": "test-only-not-a-real-key"}), \
                patch.object(provider, "invoke", return_value=raw):
            result = tessera.evaluate(self.run_dir)
        self.assertEqual((result["action"], result["primary"]), ("wrap", "button"))
        self.assertEqual(result["response_sha256"], tessera.digest(raw))
        self.assertEqual((self.run_dir / "response.json").read_bytes(), raw)


if __name__ == "__main__":
    unittest.main()
