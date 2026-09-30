"""Portable deployment contracts; Windows tests use copies even on Linux."""
from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location("ai_sync", SCRIPTS / "sync-ai.py")
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)


class AISyncTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="ai sync spaces ")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name) / "User With Spaces"
        self.home.mkdir()

    def build(self, platform="windows", clients="both"):
        obj = sync.Sync(self.home, platform, clients)
        obj.plan()
        return obj

    def json_write(self, name, data):
        path = self.home / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data), encoding="utf-8")

    def test_preview_writes_nothing(self):
        self.assertGreater(len(self.build().operations), 20)
        self.assertEqual(list(self.home.iterdir()), [])

    @unittest.skipIf(os.name == "nt", "Linux skill link contract")
    def test_link_replacement_failure_preserves_previous_target(self):
        path = self.home / "skill"
        path.symlink_to(self.home / "previous", target_is_directory=True)
        before = sync.snapshot(path)
        with patch.object(sync.os, "replace", side_effect=OSError("interrupted")):
            with self.assertRaises(OSError):
                sync.restore(path, {"kind": "link", "target": str(self.home / "next")})
        self.assertEqual(sync.snapshot(path), before)
        self.assertEqual(list(self.home.iterdir()), [path])

    def test_clean_windows_copies_and_second_apply(self):
        self.build().apply()
        self.assertFalse(any(p.is_symlink() for p in self.home.rglob("*")))
        self.assertFalse((self.home / ".claude/skills/cachyos-host-audit").exists())
        self.assertTrue((self.home / ".claude/agents/reviewer-linux.md").exists())
        settings = sync.read_json(self.home / ".claude/settings.json")
        # Windows has no desktop notifier; the only Stop entry is the project gate.
        self.assertEqual([g["hooks"][0]["command"].split()[-1] for g in settings["hooks"]["Stop"]], ["check"])
        self.assertTrue(settings["hooks"]["PostToolUse"][0]["hooks"][0]["command"].endswith("project-gate.py\" format"))
        self.assertEqual(len(settings["hooks"]["PreToolUse"]), 1)
        self.assertTrue((self.home / ".claude/hooks/ai-guard.py").is_file())
        self.assertIn("Read(**/.env)", settings["permissions"]["deny"])
        self.assertIn("Read(~/.codex/auth.json)", settings["permissions"]["deny"])
        self.assertEqual(settings["autoMode"]["soft_deny"][0], "$defaults")
        self.assertEqual(len(settings["autoMode"]["soft_deny"]), len(sync.AUTO_SOFT_DENY))
        self.assertTrue(settings["statusLine"]["command"].startswith(f'"{Path(sys.executable).as_posix()}" '))
        self.assertIn("Write|Edit", settings["hooks"]["PreToolUse"][0]["matcher"])
        self.assertIn("Monitor", settings["hooks"]["PreToolUse"][0]["matcher"].split("|"))
        self.assertNotIn("sandbox", settings, "native Windows has no Claude Code sandbox")
        # The guard also records the user's workflow opt-in; it has no matcher on UserPromptSubmit.
        guard = settings["hooks"]["PreToolUse"][0]["hooks"]
        self.assertEqual(settings["hooks"]["UserPromptSubmit"], [{"hooks": guard}])
        self.assertEqual(settings["hooks"]["UserPromptExpansion"], [{"matcher": "workflow-authoring", "hooks": guard}])
        self.assertEqual(settings["model"], "opus")
        self.assertEqual(settings["permissions"]["defaultMode"], "auto")
        self.assertEqual(settings["permissions"]["disableBypassPermissionsMode"], "disable")
        self.assertEqual(self.build().operations, [])
        self.assertIsNone(self.build().apply())

    def test_windows_skill_exports_exclude_generated_python_cache(self):
        source = Path(self.tmp.name) / "Source With Spaces"
        shutil.copytree(sync.ROOT / "ai", source / "ai")
        shutil.copytree(sync.ROOT / "scripts", source / "scripts")
        skill = source / "ai/skills/tessera"
        cache = skill / "scripts/__pycache__"
        cache.mkdir(exist_ok=True)
        (cache / "generated.pyc").write_bytes(b"generated")
        (skill / "scripts/legacy.pyc").write_bytes(b"legacy")
        (skill / "scripts/legacy.pyo").write_bytes(b"optimized")
        first = sync.Sync(self.home, "windows", "both", root=source)
        first.plan()
        first.apply()
        for client in (".claude", ".agents"):
            deployed = self.home / client / "skills/tessera"
            self.assertTrue((deployed / "scripts/tessera.py").is_file())
            self.assertFalse(list(deployed.rglob("__pycache__")))
            self.assertFalse(list(deployed.rglob("*.pyc")))
            self.assertFalse(list(deployed.rglob("*.pyo")))
        (cache / "generated.pyc").write_bytes(b"regenerated")
        self.assertEqual(sync.Sync(self.home, "windows", "both", root=source).plan(), [])
        # Full snapshots retain cache data when used for backup/rollback.
        self.assertIn("__pycache__", sync.snapshot(skill / "scripts")["entries"])

    def test_keep_models_connections_corporate_preferences_and_hooks(self):
        self.json_write(".claude/settings.json", {"model": "local-choice", "effortLevel": "medium",
            "company": {"keep": True}, "hooks": {"Stop": [{"matcher": "corp", "hooks": []}]}})
        self.json_write(".claude.json", {"oauthAccount": {"private": "fixture"},
            "mcpServers": {"company": {"type": "http", "url": "https://example.com"}},
            "projects": {"C:/Work Space": {"allowedTools": []}}})
        self.build().apply()
        settings = sync.read_json(self.home / ".claude/settings.json")
        self.assertEqual(settings["model"], "local-choice")
        self.assertEqual(settings["effortLevel"], "medium")
        self.assertTrue(settings["company"]["keep"])
        self.assertEqual(settings["hooks"]["Stop"][0]["matcher"], "corp")
        private = sync.read_json(self.home / ".claude.json")
        self.assertEqual(private["oauthAccount"]["private"], "fixture")
        self.assertIn("company", private["mcpServers"])
        self.assertIn("C:/Work Space", private["projects"])

    def test_unmanaged_edit_after_sync_is_preserved(self):
        self.build().apply()
        path = self.home / ".claude/settings.json"
        data = sync.read_json(path)
        data["model"] = "later-choice"
        path.write_text(json.dumps(data), encoding="utf-8")
        self.assertEqual(self.build().operations, [])

    def test_managed_key_edit_conflicts(self):
        self.build().apply()
        path = self.home / ".claude/settings.json"
        data = sync.read_json(path)
        data["language"] = "french"
        path.write_text(json.dumps(data), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "managed key modified"):
            self.build()

    def test_modified_role_conflicts(self):
        self.build().apply()
        path = self.home / ".claude/agents/reuse-scout.md"
        path.write_text("foreign", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "managed file modified"):
            self.build()

    def test_foreign_skill_conflicts_without_overwrite(self):
        path = self.home / ".claude/skills/handoff/SKILL.md"
        path.parent.mkdir(parents=True)
        path.write_text("personal", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "foreign target"):
            self.build()
        self.assertEqual(path.read_text(), "personal")

    def test_exact_rollback_restores_original_config(self):
        self.json_write(".claude/settings.json", {"theme": "existing"})
        original = (self.home / ".claude/settings.json").read_bytes()
        obj = self.build()
        backup = obj.apply()
        obj.rollback(backup)
        self.assertEqual((self.home / ".claude/settings.json").read_bytes(), original)
        self.assertFalse((self.home / ".claude/CLAUDE.md").exists())
        self.assertFalse(obj.state_path.exists())
        with self.assertRaisesRegex(ValueError, "already restored"):
            obj.rollback(backup)
        # Per-file rollback retains empty folders; a fresh deployment can adopt
        # these without treating them as foreign user content.
        self.build().apply()
        self.assertEqual(self.build().operations, [])

    def test_rollback_refuses_any_later_edit(self):
        obj = self.build()
        backup = obj.apply()
        path = self.home / ".claude/settings.json"
        path.write_text(path.read_text() + " ", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "later change"):
            obj.rollback(backup)
        self.assertTrue((self.home / ".claude/CLAUDE.md").exists())

    def test_toctou_stops_before_write(self):
        obj = self.build()
        self.json_write(".claude/settings.json", {"company": True})
        with self.assertRaisesRegex(ValueError, "Concurrent change"):
            obj.apply()
        self.assertFalse((self.home / ".claude/CLAUDE.md").exists())

    def test_failed_apply_rolls_back_completed_operations(self):
        obj = self.build()
        real = sync.restore
        count = 0
        def failing(path, value):
            nonlocal count
            count += 1
            if count == 3:
                raise OSError("fixture failure")
            return real(path, value)
        with patch.object(sync, "restore", side_effect=failing):
            with self.assertRaises(OSError):
                obj.apply()
        self.assertFalse((self.home / ".claude/CLAUDE.md").exists())
        self.assertFalse(obj.state_path.exists())

    def test_codex_model_and_unrelated_tables_preserved_atlas_removed(self):
        path = self.home / ".codex/config.toml"
        path.parent.mkdir()
        path.write_text('model = "chosen"\nmodel_reasoning_effort = "xhigh"\n'
                        '[mcp_servers.component-atlas]\ncommand = "old"\n'
                        '[hooks]\ncustom = true\n', encoding="utf-8")
        self.build().apply()
        data = sync.tomllib.loads(path.read_text())
        self.assertEqual(data["model"], "chosen")
        self.assertEqual(data["model_reasoning_effort"], "xhigh")
        self.assertTrue(data["hooks"]["custom"])
        self.assertNotIn("component-atlas", data["mcp_servers"])
        self.assertFalse(data["mcp_servers"]["linear-write"]["enabled"])

    def test_mcp_collision_fails_closed(self):
        self.json_write(".claude.json", {"mcpServers": {"linear": {"url": "https://company"}}})
        with self.assertRaisesRegex(ValueError, "Different local connection"):
            self.build()

    def test_persistent_linear_write_is_rejected(self):
        self.json_write(".claude.json", {"mcpServers": {"linear-write": {"type": "http", "url": "https://mcp.linear.app/mcp"}}})
        with self.assertRaisesRegex(ValueError, "persistent linear-write"):
            self.build()

    def test_atlas_reintroduction_is_conflict(self):
        self.build().apply()
        path = self.home / ".claude.json"
        document = sync.read_json(path)
        document["mcpServers"]["component-atlas"] = {"command": "changed"}
        self.json_write(".claude.json", document)
        with self.assertRaisesRegex(ValueError, "managed key modified"):
            self.build()

    def test_scalar_codex_connection_is_controlled_error(self):
        path = self.home / ".codex/config.toml"
        path.parent.mkdir()
        path.write_text('[mcp_servers]\nlinear = "custom"\n', encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Different local connection"):
            self.build()

    def test_scalar_codex_mcp_container_is_controlled_error(self):
        path = self.home / ".codex/config.toml"
        path.parent.mkdir()
        path.write_text('mcp_servers = "corporate"\n', encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "must be a table"):
            self.build()

    def test_windows_update_copies_files_without_displacing_directory(self):
        source = Path(self.tmp.name) / "Source With Spaces"
        shutil.copytree(sync.ROOT / "ai", source / "ai")
        first = sync.Sync(self.home, "windows", "claude", root=source)
        first.plan()
        first.apply()
        skill = source / "ai/skills/handoff/SKILL.md"
        original = skill.read_text(encoding="utf-8")
        skill.write_text(original + "\nUpdated fixture.\n", encoding="utf-8")
        (skill.parent / "new-reference.md").write_text("New fixture.\n", encoding="utf-8")
        update = sync.Sync(self.home, "windows", "claude", root=source)
        operations = update.plan()
        self.assertFalse(any(item["before"]["kind"] == "dir" or item["after"]["kind"] == "dir" for item in operations))
        # Simulate a crash after the first file replacement and before the next.
        backup = update.state_dir / "backups/interrupted-fixture"
        backup.mkdir()
        (backup / "transaction.json").write_text(json.dumps({
            "home": str(self.home), "status": "prepared", "operations": operations}), encoding="utf-8")
        sync.restore(Path(operations[0]["path"]), operations[0]["after"])
        update.rollback(backup)
        self.assertEqual((self.home / ".claude/skills/handoff/SKILL.md").read_text(encoding="utf-8"), original)
        update = sync.Sync(self.home, "windows", "claude", root=source)
        update.plan()
        update.apply()
        self.assertEqual((self.home / ".claude/skills/handoff/SKILL.md").read_bytes(), skill.read_bytes())

    def test_rollback_path_traversal_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "traversal"):
            sync.safe_path(self.home / "../outside", self.home)

    def test_interrupted_transaction_is_recoverable(self):
        obj = self.build()
        backup = obj.apply()
        journal = sync.read_json(backup / "transaction.json")
        journal["status"] = "prepared"
        first = journal["operations"][0]
        sync.restore(Path(first["path"]), first["before"])
        (backup / "transaction.json").write_text(json.dumps(journal), encoding="utf-8")
        obj.rollback(backup)
        self.assertFalse(obj.state_path.exists())

    def test_failed_automatic_restore_can_be_retried(self):
        obj = self.build()
        real = sync.restore
        count = 0
        def failing(path, value):
            nonlocal count
            count += 1
            if count in {3, 4}:
                raise OSError("fixture failure")
            return real(path, value)
        with patch.object(sync, "restore", side_effect=failing):
            with self.assertRaises(OSError):
                obj.apply()
        backup = next((obj.state_dir / "backups").iterdir())
        self.assertEqual(sync.read_json(backup / "transaction.json")["status"], "needs-recovery")
        obj.rollback(backup)
        self.assertFalse((self.home / ".claude/CLAUDE.md").exists())

    @unittest.skipUnless(os.name == "nt", "Native Windows junction protection")
    def test_windows_junction_parent_rejected(self):
        outside = Path(self.tmp.name) / "Outside"
        outside.mkdir()
        subprocess.run(["cmd", "/c", "mklink", "/J", str(self.home / ".claude"), str(outside)], check=True, capture_output=True)
        with self.assertRaisesRegex(ValueError, "Linked directory"):
            self.build()
        self.assertEqual(list(outside.iterdir()), [])

    def test_selected_client_only(self):
        self.build(clients="claude").apply()
        self.assertFalse((self.home / ".codex").exists())
        self.assertFalse((self.home / ".agents").exists())
        self.build(clients="codex").apply()
        self.assertEqual(self.build().operations, [])

    def test_lock_not_deleted_by_second_invocation(self):
        state = self.home / ".local/state/dotfiles/ai"
        state.mkdir(parents=True)
        lock = state / "sync.lock"
        lock.write_text("owner", encoding="utf-8")
        result = subprocess.run([sys.executable, str(SCRIPTS / "sync-ai.py"), "apply",
            "--platform", "windows", "--home", str(self.home)], capture_output=True)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(lock.read_text(), "owner")

    @unittest.skipIf(os.name == "nt", "Linux symlink deployment only")
    def test_linux_links_hooks_and_legacy_migration(self):
        path = self.home / ".agents/skills/handoff"
        path.parent.mkdir(parents=True)
        path.symlink_to(sync.ROOT / "codex/.agents/skills/handoff")
        atlas = path.parent / "frontend-task"
        atlas.symlink_to(self.home / "dev/project-atlas/skills/frontend-task")
        self.json_write(".claude/settings.json", {"hooks": {"Stop": [{"hooks": [{"command": "company"}]}]}})
        self.build("linux").apply()
        self.assertEqual(path.resolve(), sync.ROOT / "ai/skills/handoff")
        self.assertFalse(atlas.is_symlink())
        self.assertFalse((self.home / ".codex/agents/reuse-scout.toml").is_symlink())
        settings = sync.read_json(self.home / ".claude/settings.json")
        self.assertEqual(len(settings["hooks"]["Stop"]), 3)  # company, project gate, notify
        self.assertEqual(self.build("linux").operations, [])
        result = subprocess.run([sys.executable, str(SCRIPTS / "manage-codex-agent-files.py"), "--verify"],
            env=dict(os.environ, HOME=str(self.home), CODEX_HOME=str(self.home / ".codex"),
                     XDG_STATE_HOME=str(self.home / ".local/state")), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipIf(os.name == "nt", "Linux symlink deployment only")
    def test_linux_sandbox_keys_and_entries(self):
        self.json_write(".claude/settings.json", {"sandbox": {"filesystem": {"denyRead": ["~/private"]},
                                                              "network": {"allowedDomains": ["github.com"]}}})
        self.build("linux", "claude").apply()
        sandbox = sync.read_json(self.home / ".claude/settings.json")["sandbox"]
        self.assertIs(sandbox["enabled"], True)
        self.assertIs(sandbox["autoAllowBashIfSandboxed"], False)
        self.assertIs(sandbox["allowUnsandboxedCommands"], True)
        self.assertEqual(sandbox["network"], {"allowedDomains": ["github.com"]}, "network stays the user's")
        self.assertEqual(sandbox["filesystem"]["denyRead"], ["~/private", *sync.SANDBOX_DENY_READ])
        for path in ("~/**/.env", "~/.ssh", "~/.gnupg", "~/.aws", "~/.git-credentials", "~/.config/gh/hosts.yml",
                     "~/.claude.json", "~/.claude/.credentials.json", "~/.codex/auth.json"):
            self.assertIn(path, sandbox["filesystem"]["denyRead"])
        self.assertEqual(sandbox["filesystem"]["denyWrite"], ["~/.local/state/dotfiles/ai"])
        self.assertEqual(sandbox["excludedCommands"], ["just ai-plan", "just ai-sync", "just ai-check", "just apply"])
        self.assertEqual(self.build("linux", "claude").operations, [])
        path = self.home / ".claude/settings.json"
        data = sync.read_json(path)
        data["sandbox"]["enabled"] = False
        path.write_text(json.dumps(data), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "managed key modified"):
            self.build("linux", "claude")

    @unittest.skipIf(os.name == "nt", "Linux symlink deployment only")
    def test_linux_sandbox_never_overrides_a_local_choice(self):
        self.json_write(".claude/settings.json", {"sandbox": {"enabled": False}})
        with self.assertRaisesRegex(ValueError, "different local value.*sandbox.enabled"):
            self.build("linux", "claude")

    @unittest.skipIf(os.name == "nt", "Linux symlink deployment only")
    def test_adopt_never_overwrites_a_local_security_key(self):
        for local in ({"sandbox": {"enabled": False}}, {"sandbox": {"allowUnsandboxedCommands": False}},
                      {"permissions": {"defaultMode": "default"}}):
            self.json_write(".claude/settings.json", local)
            adopted = sync.Sync(self.home, "linux", "claude", adopt=True)
            with self.assertRaisesRegex(ValueError, "different local value"):
                adopted.plan()
        # Other keys are still adopted from an earlier deployment.
        self.json_write(".claude/settings.json", {"language": "english"})
        sync.Sync(self.home, "linux", "claude", adopt=True).plan()

    def test_list_entries_keep_foreign_items_and_conflict_when_removed(self):
        self.json_write(".claude/settings.json", {"permissions": {"deny": ["Bash(curl *)"]},
                                                  "hooks": {"PreToolUse": [{"matcher": "Edit", "hooks": []}]}})
        self.build().apply()
        settings = sync.read_json(self.home / ".claude/settings.json")
        self.assertEqual(settings["permissions"]["deny"][0], "Bash(curl *)")
        self.assertEqual(len(settings["permissions"]["deny"]), 1 + len(sync.DENY))
        self.assertEqual(len(settings["hooks"]["PreToolUse"]), 2)
        settings["permissions"]["deny"].remove("Read(**/.env)")
        self.json_write(".claude/settings.json", settings)
        with self.assertRaisesRegex(ValueError, "managed entry removed"):
            self.build()

    def test_codex_gets_the_same_guard_and_keeps_foreign_hooks(self):
        # Native platform: Linux mode needs symlinks, which Windows runners lack.
        platform = "windows" if os.name == "nt" else "linux"
        foreign = {"matcher": "Bash", "hooks": [{"type": "command", "command": "company-audit"}]}
        self.json_write(".codex/hooks.json", {"hooks": {"PreToolUse": [foreign], "Stop": []}})
        self.build(platform, "codex").apply()
        hooks = sync.read_json(self.home / ".codex/hooks.json")["hooks"]
        self.assertEqual(hooks["PreToolUse"][0], foreign)
        self.assertEqual(hooks["PreToolUse"][1]["matcher"], "Bash|apply_patch")
        self.assertIn(".codex/hooks/ai-guard.py", hooks["PreToolUse"][1]["hooks"][0]["command"])
        self.assertNotIn("UserPromptSubmit", hooks, "Codex has no Workflow tool to opt in to")
        self.assertEqual((self.home / ".codex/hooks/ai-guard.py").read_text(),
                         (sync.ROOT / "ai/hooks/ai-guard.py").read_text())
        self.assertEqual(self.build(platform, "codex").operations, [])

    def test_new_key_never_overwrites_a_different_local_value(self):
        self.json_write(".claude/settings.json", {"statusLine": {"type": "command", "command": "my-status"}})
        with self.assertRaisesRegex(ValueError, "new key already has"):
            self.build()
        self.json_write(".claude/settings.json", {})
        self.build().apply()
        self.assertEqual(sync.read_json(self.home / ".claude/settings.json")["model"], "opus")
        self.assertEqual(self.build().operations, [])
        # The model is a default, never owned: a later /model or local choice survives.
        settings = sync.read_json(self.home / ".claude/settings.json")
        settings["model"] = "sonnet"
        self.json_write(".claude/settings.json", settings)
        self.assertEqual(self.build().operations, [])

    @unittest.skipIf(os.name == "nt", "Linux mode links skills; no symlink privilege on Windows")
    def test_entries_no_longer_wanted_are_removed_and_legacy_notify_state_migrates(self):
        self.build("linux").apply()
        state_path = self.home / ".local/state/dotfiles/ai/managed.json"
        state = sync.read_json(state_path)
        key = ".claude/settings.json"
        state[key]["entries"] = [e for e in state[key]["entries"] if e[0] != ["hooks", "Stop"]]
        state[key]["entries"].append([["permissions", "deny"], "Read(~/retired/**)"])
        state[key]["notify"] = True
        state_path.write_text(sync.json_text(state))
        settings = sync.read_json(self.home / ".claude/settings.json")
        settings["permissions"]["deny"].append("Read(~/retired/**)")
        self.json_write(".claude/settings.json", settings)
        self.build("linux").apply()
        settings = sync.read_json(self.home / ".claude/settings.json")
        self.assertNotIn("Read(~/retired/**)", settings["permissions"]["deny"])
        self.assertEqual(settings["hooks"]["Stop"][-1], sync.NOTIFY)
        self.assertEqual(len(settings["hooks"]["Stop"]), 2)
        self.assertNotIn("notify", sync.read_json(state_path)[key])
        self.assertEqual(self.build("linux").operations, [])

    def test_invocation_policy_roles_and_hooks_come_from_one_source(self):
        sources = sys.modules["ai_sources"]
        skills = {p.name for p in (sync.ROOT / "ai/skills").iterdir() if p.is_dir()}
        self.assertEqual(skills, sources.IMPLICIT_SKILLS | sources.EXPLICIT_SKILLS)
        overrides = {route[1]: value for route, value in sync.CLAUDE_KEYS.items() if route[0] == "skillOverrides"}
        self.assertEqual({k for k, v in overrides.items() if v == "user-invocable-only"}, set(sources.USER_SKILLS))
        self.assertEqual({k for k, v in overrides.items() if v == "name-only"}, set(sources.NAMED_SKILLS))
        agents = sources.roles("claude", "linux")
        self.assertEqual(set(agents), {p.stem + ".md" for p in (sync.ROOT / "ai/roles").glob("*.json")})
        for text in agents.values():
            header = text.split("---")[1]
            self.assertIn("tools: Read, Glob, Grep", header)
            self.assertNotIn("Bash", header, "Roles are read-only")
        self.assertIn("maxTurns: 25", agents["reuse-scout.md"])
        # Reading roles run on Sonnet; Haiku stalled on multi-step reading.
        for name in ("reuse-scout.md", "catalog-writer.md"):
            self.assertIn("model: sonnet", agents[name])
        self.assertNotIn("haiku", "".join(agents.values()))
        self.assertEqual(set(sources.hook_scripts()), {"ai-guard.py", "project-gate.py", "statusline.py"})

    def test_adopt_takes_over_an_earlier_deployment_without_a_ledger(self):
        revision = "ffd31373936d8ef55ba5f95db5ca9bd12ed326ab"
        if subprocess.run(["git", "-C", str(sync.ROOT), "cat-file", "-e", revision],
                          capture_output=True).returncode:
            # A skip must not hide a shallow checkout in CI (validate.yml uses fetch-depth: 0).
            if os.environ.get("GITHUB_ACTIONS") == "true":
                self.fail(f"CI checkout lacks {revision}: set fetch-depth: 0")
            self.skipTest("history not available in this checkout")
        def old(path):
            return subprocess.run(["git", "-C", str(sync.ROOT), "show", f"{revision}:{path}"],
                                  capture_output=True, check=True).stdout
        skill = self.home / ".claude/skills/handoff"
        for name in ("SKILL.md", "agents/openai.yaml"):
            (skill / name).parent.mkdir(parents=True, exist_ok=True)
            data = old(f"ai/skills/handoff/{name}")
            # Use the other line ending than this checkout (autocrlf may give CRLF),
            # so the old copy is a real conflict whether or not the skill changed since.
            if b"\r\n" not in (sync.ROOT / f"ai/skills/handoff/{name}").read_bytes():
                data = data.replace(b"\n", b"\r\n")
            (skill / name).write_bytes(data)
        claude_md = self.home / ".claude/CLAUDE.md"
        claude_md.write_bytes(b"<!-- Generated by scripts/render-ai.py from ai/. Edit the source. -->\n\nold rules\n")
        self.json_write(".claude/settings.json", {"skillOverrides": {"test-driven-development": "user-invocable-only"}})
        with self.assertRaisesRegex(ValueError, "foreign target"):
            self.build(clients="claude")
        adopted = sync.Sync(self.home, "windows", "claude", adopt=True)
        adopted.plan()
        self.assertIn(str(skill), adopted.adopted)
        self.assertIn(str(claude_md), adopted.adopted)
        adopted.apply()
        self.assertEqual(sync.read_json(self.home / ".claude/settings.json")["skillOverrides"]["test-driven-development"],
                         "name-only")
        self.assertEqual(self.build(clients="claude").operations, [])

    def test_windows_ledger_moves_out_of_appdata_and_old_backups_still_roll_back(self):
        self.build().apply()
        new = self.home / ".local/state/dotfiles/ai"
        old = self.home / "AppData/Local/dotfiles/ai"
        old.parent.mkdir(parents=True)
        new.rename(old)
        # A later user edit of a managed key must still be caught from the old ledger.
        carried = self.build()
        self.assertEqual(carried.state_source, old / "managed.json")
        self.assertEqual([op["path"] for op in carried.operations], [str(new / "managed.json")])
        carried.apply()
        self.assertTrue((new / "managed.json").is_file() and (old / "managed.json").is_file())
        self.assertEqual(self.build().operations, [])
        settings = sync.read_json(self.home / ".claude/settings.json")
        settings["language"] = "french"
        self.json_write(".claude/settings.json", settings)
        with self.assertRaisesRegex(ValueError, "managed key modified"):
            self.build()

    def test_msix_virtualized_ledger_is_found(self):
        self.build().apply()
        new = self.home / ".local/state/dotfiles/ai"
        msix = self.home / "AppData/Local/Packages/Claude_x/LocalCache/Local/dotfiles/ai"
        msix.parent.mkdir(parents=True)
        new.rename(msix)
        carried = self.build()
        self.assertEqual(carried.state_source, msix / "managed.json")
        self.assertEqual(len(carried.operations), 1)

    def test_adopt_never_takes_foreign_content(self):
        path = self.home / ".claude/skills/handoff/SKILL.md"
        path.parent.mkdir(parents=True)
        path.write_text("my own handoff skill", encoding="utf-8")
        adopted = sync.Sync(self.home, "windows", "claude", adopt=True)
        with self.assertRaisesRegex(ValueError, "foreign target"):
            adopted.plan()
        self.assertEqual(path.read_text(encoding="utf-8"), "my own handoff skill")

    @unittest.skipIf(os.name == "nt", "No privileged symlink creation on Windows")
    def test_symlink_parent_rejected(self):
        other = self.home / "elsewhere"
        other.mkdir()
        (self.home / ".claude").symlink_to(other)
        with self.assertRaisesRegex(ValueError, "Linked directory"):
            self.build()


if __name__ == "__main__":
    unittest.main()
