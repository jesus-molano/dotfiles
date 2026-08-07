"""Pruebas del validador estático de skills y agentes Codex."""

from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1]
CHECKER = SCRIPTS / "check-codex-skills.py"


def run_checker(skills: Path, agents: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            str(CHECKER),
            "--skills-root",
            str(skills),
            "--agents-root",
            str(agents),
        ],
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


class CheckCodexSkillsTest(unittest.TestCase):
    def test_valid_minimal_skill(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            skills, agents, _ = roots(Path(temporary))
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
            skills, agents, skill = roots(Path(temporary), "codebase-design")
            write_metadata(skill, implicit=True)
            checked = run_checker(skills, agents)
            self.assertNotEqual(checked.returncode, 0)
            self.assertIn("requiere invocación explícita", checked.stderr)

    def test_explicit_skill_accepts_disabled_implicit_invocation(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            skills, agents, skill = roots(Path(temporary), "linear-workflow")
            write_metadata(skill, implicit=False)
            checked = run_checker(skills, agents)
            self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_implicit_discipline_rejects_disabled_invocation(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            skills, agents, skill = roots(Path(temporary), "research-primary-sources")
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


if __name__ == "__main__":
    unittest.main()
