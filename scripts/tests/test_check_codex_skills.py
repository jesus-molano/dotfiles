"""Pruebas del validador estático de skills y agentes Codex."""

from __future__ import annotations

import runpy
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1]
CHECKER = SCRIPTS / "check-codex-skills.py"
CHECKS = runpy.run_path(str(CHECKER), run_name="check_codex_skills_test")


def run_checker(
    skills: Path,
    agents: Path,
    *,
    required_agents: tuple[str, ...] = (),
    installed_skills_roots: tuple[Path, ...] = (),
) -> subprocess.CompletedProcess[str]:
    command = [
        str(CHECKER),
        "--skills-root",
        str(skills),
        "--agents-root",
        str(agents),
    ]
    for agent in required_agents:
        command.extend(("--required-agent", agent))
    for installed_root in installed_skills_roots:
        command.extend(("--installed-skills-root", str(installed_root)))
    return subprocess.run(
        command,
        text=True,
        capture_output=True,
        check=False,
    )


def roots(root: Path, name: str = "example") -> tuple[Path, Path, Path]:
    skills = root / "skills"
    agents = root / "agents"
    skill = skills / name
    skill.mkdir(parents=True)
    agents.mkdir()
    (skill / "SKILL.md").write_text(
        f"---\nname: {name}\ndescription: Valid example skill.\n---\n\n# Example\n",
        encoding="utf-8",
    )
    return skills, agents, skill


def write_metadata(skill: Path, *, implicit: bool) -> None:
    metadata = skill / "agents"
    metadata.mkdir()
    (metadata / "openai.yaml").write_text(
        'interface:\n  display_name: "Example Skill"\n'
        '  short_description: "Valid example skill metadata"\n'
        f'  default_prompt: "Use ${skill.name} for this task."\n'
        "policy:\n"
        f"  allow_implicit_invocation: {str(implicit).lower()}\n",
        encoding="utf-8",
    )


def write_installed_skill(root: Path, directory: str, name: str) -> Path:
    skill = root / directory
    skill.mkdir(parents=True)
    (skill / "SKILL.md").write_text(
        f"---\nname: {name}\n---\n\n# External skill\n", encoding="utf-8"
    )
    return skill


class CheckCodexSkillsTest(unittest.TestCase):
    def test_installed_skills_reject_duplicate_frontmatter_names(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            skills, agents, skill = roots(root, "engineering-flow")
            write_metadata(skill, implicit=True)
            installed = root / "installed"
            write_installed_skill(installed, "active", "frontend-task")
            write_installed_skill(installed, "backup", "frontend-task")
            checked = run_checker(
                skills, agents, installed_skills_roots=(installed,)
            )
            self.assertNotEqual(checked.returncode, 0)
            self.assertIn("name instalado duplicado frontend-task", checked.stderr)

    def test_installed_skills_compare_all_repeated_roots(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            skills, agents, skill = roots(root, "engineering-flow")
            write_metadata(skill, implicit=True)
            first = root / "first"
            second = root / "second"
            write_installed_skill(first, "first-layout", "shared-name")
            write_installed_skill(second, "second-layout", "shared-name")
            checked = run_checker(
                skills, agents, installed_skills_roots=(first, second)
            )
            self.assertNotEqual(checked.returncode, 0)
            self.assertIn("name instalado duplicado shared-name", checked.stderr)

    def test_installed_symlink_and_backup_with_same_name_are_duplicates(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            skills, agents, skill = roots(root, "engineering-flow")
            write_metadata(skill, implicit=True)
            installed = root / "installed"
            source = write_installed_skill(root / "sources", "active", "reuse-first")
            installed.mkdir()
            (installed / "reuse-first").symlink_to(source, target_is_directory=True)
            write_installed_skill(installed, "reuse-first.backup", "reuse-first")
            checked = run_checker(
                skills, agents, installed_skills_roots=(installed,)
            )
            self.assertNotEqual(checked.returncode, 0)
            self.assertIn("name instalado duplicado reuse-first", checked.stderr)

    def test_installed_external_skills_only_require_distinct_names(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            skills, agents, skill = roots(root, "engineering-flow")
            write_metadata(skill, implicit=True)
            installed = root / "installed"
            write_installed_skill(installed, "different-layout", "third-party-skill")
            write_installed_skill(installed, "another-layout", "another-skill")
            checked = run_checker(
                skills, agents, installed_skills_roots=(installed,)
            )
            self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_installed_skill_walk_handles_directory_symlink_cycles(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            skills, agents, skill = roots(root, "engineering-flow")
            write_metadata(skill, implicit=True)
            installed = root / "installed"
            active = write_installed_skill(installed, "active", "external-skill")
            (active / "cycle").symlink_to(installed, target_is_directory=True)
            (installed / "broken").symlink_to(root / "missing", target_is_directory=True)
            checked = run_checker(
                skills, agents, installed_skills_roots=(installed,)
            )
            self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_installed_skills_do_not_traverse_linked_containers(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            skills, agents, skill = roots(root, "engineering-flow")
            write_metadata(skill, implicit=True)
            installed = root / "installed"
            installed.mkdir()
            outside = root / "unrelated-home"
            write_installed_skill(outside, "private-subtree", "must-not-be-read")
            (installed / "escape").symlink_to(outside, target_is_directory=True)

            checked = run_checker(
                skills, agents, installed_skills_roots=(installed,)
            )
            self.assertNotEqual(checked.returncode, 0)
            self.assertIn("no se recorrerá su destino", checked.stderr)
            self.assertNotIn("must-not-be-read", checked.stderr)

    def test_installed_skill_resources_are_not_discovered_as_extra_skills(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            skills, agents, skill = roots(root, "engineering-flow")
            write_metadata(skill, implicit=True)
            installed = root / "installed"
            active = write_installed_skill(installed, "active", "external-skill")
            write_installed_skill(active, "examples/template", "external-skill")
            checked = run_checker(
                skills, agents, installed_skills_roots=(installed,)
            )
            self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_catalog_budget_rejects_skill_or_description_growth(self) -> None:
        with self.assertRaisesRegex(ValueError, "skills"):
            CHECKS["check_catalog_budget"](21, 10)
        with self.assertRaisesRegex(ValueError, "descripciones"):
            CHECKS["check_catalog_budget"](19, 701)

    def test_valid_minimal_skill(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            skills, agents, skill = roots(Path(temporary), "engineering-flow")
            write_metadata(skill, implicit=True)
            checked = run_checker(skills, agents)
            self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_rejects_unterminated_frontmatter_quote(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            skills, agents, skill = roots(Path(temporary))
            (skill / "SKILL.md").write_text(
                '---\nname: example\ndescription: "unterminated\n---\n',
                encoding="utf-8",
            )
            checked = run_checker(skills, agents)
            self.assertNotEqual(checked.returncode, 0)
            self.assertIn("YAML no válido", checked.stderr)

    def test_rejects_malformed_openai_yaml(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            skills, agents, skill = roots(Path(temporary))
            metadata = skill / "agents"
            metadata.mkdir()
            (metadata / "openai.yaml").write_text(
                'interface:\n  display_name: "unterminated\n'
                '  short_description: "Still long enough"\n'
                '  default_prompt: "Use $example."\n',
                encoding="utf-8",
            )
            checked = run_checker(skills, agents)
            self.assertNotEqual(checked.returncode, 0)
            self.assertIn("entre comillas", checked.stderr)

    def test_explicit_skill_requires_disabled_implicit_invocation(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            skills, agents, skill = roots(Path(temporary), "reuse-first")
            write_metadata(skill, implicit=True)
            checked = run_checker(skills, agents)
            self.assertNotEqual(checked.returncode, 0)
            self.assertIn("requiere invocación explícita", checked.stderr)

    def test_explicit_skill_accepts_disabled_implicit_invocation(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            skills, agents, skill = roots(Path(temporary), "reuse-first")
            write_metadata(skill, implicit=False)
            checked = run_checker(skills, agents)
            self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_implicit_discipline_rejects_disabled_invocation(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            skills, agents, skill = roots(Path(temporary), "frontend-task")
            write_metadata(skill, implicit=False)
            checked = run_checker(skills, agents)
            self.assertNotEqual(checked.returncode, 0)
            self.assertIn("debe permitir invocación implícita", checked.stderr)

    def test_rejects_skill_missing_from_routing_inventory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            skills, agents, skill = roots(Path(temporary), "unclassified-skill")
            write_metadata(skill, implicit=True)
            checked = run_checker(skills, agents)
            self.assertNotEqual(checked.returncode, 0)
            self.assertIn("no figura en el inventario de routing", checked.stderr)

    def test_routing_inventory_requires_exact_invocation_policy(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            skills, agents, skill = roots(Path(temporary), "engineering-flow")
            write_metadata(skill, implicit=False)
            checked = run_checker(skills, agents)
            self.assertNotEqual(checked.returncode, 0)
            self.assertIn("debe permitir invocación implícita", checked.stderr)

    def test_rejects_unapproved_reviewer_model(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            skills, agents, _ = roots(Path(temporary))
            (agents / "reviewer-fake.toml").write_text(
                'name = "reviewer-fake"\n'
                'description = "Fixture"\n'
                'developer_instructions = "Read only."\n'
                'model = "does-not-exist"\n'
                'model_reasoning_effort = "high"\n'
                'sandbox_mode = "read-only"\n',
                encoding="utf-8",
            )
            checked = run_checker(skills, agents)
            self.assertNotEqual(checked.returncode, 0)
            self.assertIn("gpt-5.6-sol", checked.stderr)

    def test_reuse_scout_accepts_its_lightweight_read_only_configuration(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            skills, agents, skill = roots(Path(temporary), "engineering-flow")
            write_metadata(skill, implicit=True)
            (agents / "reuse-scout.toml").write_text(
                'name = "reuse-scout"\n'
                'description = "Fixture"\n'
                'developer_instructions = "Read only."\n'
                'model = "gpt-5.6-luna"\n'
                'model_reasoning_effort = "low"\n'
                'sandbox_mode = "read-only"\n',
                encoding="utf-8",
            )
            checked = run_checker(
                skills, agents, required_agents=("reuse-scout",)
            )
            self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_required_reuse_scout_cannot_be_omitted(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            skills, agents, skill = roots(Path(temporary), "engineering-flow")
            write_metadata(skill, implicit=True)
            checked = run_checker(
                skills, agents, required_agents=("reuse-scout",)
            )
            self.assertNotEqual(checked.returncode, 0)
            self.assertIn("faltan agentes requeridos: reuse-scout", checked.stderr)

    def test_reuse_scout_rejects_wrong_resource_configuration(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            skills, agents, _ = roots(Path(temporary))
            agent = agents / "reuse-scout.toml"
            agent.write_text(
                'name = "reuse-scout"\n'
                'description = "Fixture"\n'
                'developer_instructions = "Read only."\n'
                'model = "gpt-5.6-sol"\n'
                'model_reasoning_effort = "low"\n'
                'sandbox_mode = "read-only"\n',
                encoding="utf-8",
            )
            checked = run_checker(skills, agents)
            self.assertNotEqual(checked.returncode, 0)
            self.assertIn("modelo ligero gpt-5.6-luna", checked.stderr)

            agent.write_text(
                'name = "reuse-scout"\n'
                'description = "Fixture"\n'
                'developer_instructions = "Read only."\n'
                'model = "gpt-5.6-luna"\n'
                'model_reasoning_effort = "low"\n'
                'sandbox_mode = "workspace-write"\n',
                encoding="utf-8",
            )
            checked = run_checker(skills, agents)
            self.assertNotEqual(checked.returncode, 0)
            self.assertIn("sandbox_mode = read-only", checked.stderr)

            agent.write_text(
                'name = "reuse-scout"\n'
                'description = "Fixture"\n'
                'developer_instructions = "Read only."\n'
                'model = "gpt-5.6-luna"\n'
                'model_reasoning_effort = "medium"\n'
                'sandbox_mode = "read-only"\n',
                encoding="utf-8",
            )
            checked = run_checker(skills, agents)
            self.assertNotEqual(checked.returncode, 0)
            self.assertIn("model_reasoning_effort = low", checked.stderr)


if __name__ == "__main__":
    unittest.main()
