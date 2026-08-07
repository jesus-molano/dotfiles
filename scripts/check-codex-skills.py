#!/usr/bin/env python3
"""Comprueba la estructura estática de las skills y agentes locales de Codex."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import tomllib

FRONTMATTER = re.compile(r"\A---\r?\n(.*?)\r?\n---\r?\n", re.DOTALL)
MARKDOWN_LINK = re.compile(r"!?\[[^]]*]\(([^)\s]+)(?:\s+[^)]*)?\)")
YAML_KEY = re.compile(r"^( {2})([a-z_]+):\s*(.*)$")
SKILL_NAME = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")
EXPLICIT_SKILLS = {
    "codebase-design",
    "domain-modeling",
    "engineering-flow",
    "grill-with-docs",
    "handoff",
    "implement-ticket",
    "linear-workflow",
    "spec-and-standards-review",
    "to-spec",
    "to-tickets",
}
IMPLICIT_SKILLS = {
    "research-primary-sources",
    "systematic-debugging",
    "test-driven-development",
}


def parse_args() -> argparse.Namespace:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--skills-root", type=Path, default=root / "codex/.agents/skills"
    )
    parser.add_argument(
        "--agents-root", type=Path, default=root / "codex/.codex/agents"
    )
    return parser.parse_args()


def parse_frontmatter(path: Path) -> dict[str, str]:
    match = FRONTMATTER.match(path.read_text(encoding="utf-8"))
    if not match:
        raise ValueError("frontmatter YAML ausente o mal delimitado")
    values: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if not line or line.lstrip().startswith("#"):
            continue
        if ":" not in line or line.startswith((" ", "\t", "-")):
            raise ValueError(
                "frontmatter debe contener solo pares simples name/description"
            )
        key, value = line.split(":", 1)
        if key not in {"name", "description"} or key in values:
            raise ValueError(f"clave de frontmatter no permitida: {key}")
        values[key] = parse_yaml_string(value, key)
    if set(values) != {"name", "description"} or not all(values.values()):
        raise ValueError("frontmatter requiere name y description no vacíos")
    if not SKILL_NAME.fullmatch(values["name"]) or len(values["name"]) > 64:
        raise ValueError("name debe ser kebab-case válido de hasta 64 caracteres")
    if len(values["description"]) > 1024 or any(
        marker in values["description"] for marker in "<>"
    ):
        raise ValueError("description supera límites o contiene < >")
    return values


def parse_yaml_string(raw: str, key: str) -> str:
    """Valida el subconjunto escalar usado por el frontmatter local."""
    value = raw.strip()
    if not value:
        raise ValueError(f"{key} no puede estar vacío")
    if value.startswith('"'):
        try:
            parsed = json.loads(value)
        except json.JSONDecodeError as error:
            raise ValueError(f"YAML no válido en {key}: {error.msg}") from error
        if not isinstance(parsed, str):
            raise ValueError(f"{key} debe ser texto")
        return parsed.strip()
    if value.startswith("'"):
        if len(value) < 2 or not value.endswith("'"):
            raise ValueError(f"YAML no válido en {key}: comilla sin cerrar")
        inner = value[1:-1]
        if "'" in inner.replace("''", ""):
            raise ValueError(f"YAML no válido en {key}: comilla simple sin escapar")
        return inner.replace("''", "'").strip()

    lowered = value.casefold()
    if lowered in {"null", "true", "false", "yes", "no", "on", "off", "~"}:
        raise ValueError(f"{key} debe ser texto, no un escalar reservado")
    if re.fullmatch(r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)", value):
        raise ValueError(f"{key} debe ser texto, no un número")
    if value.startswith(("[", "{", "&", "*", "!", "|", ">", "- ", "? ")):
        raise ValueError(f"{key} usa una construcción YAML no admitida")
    if re.search(r":(?:\s|$)|\s#", value):
        raise ValueError(f"{key} debe entrecomillarse para usar ':' o comentarios")
    return value


def check_openai_yaml(path: Path) -> bool | None:
    if not path.exists():
        return None
    section: str | None = None
    fields: dict[str, set[str]] = {"interface": set(), "policy": set()}
    seen_sections: set[str] = set()
    implicit: bool | None = None
    allowed = {
        "interface": {
            "display_name",
            "short_description",
            "default_prompt",
            "brand_color",
        },
        "policy": {"allow_implicit_invocation"},
    }
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if raw.startswith("\t"):
            raise ValueError("openai.yaml no permite tabuladores")
        if not raw.startswith(" "):
            if raw not in {"interface:", "policy:"}:
                raise ValueError(f"sección YAML no permitida: {raw}")
            section = raw[:-1]
            if section in seen_sections:
                raise ValueError(f"sección YAML duplicada: {section}")
            seen_sections.add(section)
            continue
        match = YAML_KEY.match(raw)
        if not match or section is None:
            raise ValueError("estructura YAML no admitida")
        key, value = match.group(2), match.group(3).strip()
        if key not in allowed[section] or key in fields[section] or not value:
            raise ValueError(f"campo YAML no válido: {key}")
        if section == "policy" and (
            key != "allow_implicit_invocation" or value not in {"true", "false"}
        ):
            raise ValueError("policy.allow_implicit_invocation debe ser true o false")
        if section == "interface":
            try:
                scalar = json.loads(value)
            except json.JSONDecodeError as error:
                raise ValueError(
                    f"{key} debe ser una cadena YAML entre comillas: {error.msg}"
                ) from error
            if not isinstance(scalar, str) or not scalar.strip():
                raise ValueError(f"{key} debe ser texto no vacío")
            if key == "brand_color" and not re.fullmatch(r"#[0-9A-Fa-f]{6}", scalar):
                raise ValueError("brand_color debe usar #RRGGBB")
        else:
            implicit = value == "true"
        fields[section].add(key)
    if (
        not {"display_name", "short_description", "default_prompt"}
        <= fields["interface"]
    ):
        raise ValueError(
            "openai.yaml requiere interface.display_name, short_description y default_prompt"
        )
    return implicit


def check_agent(path: Path) -> str:
    document = tomllib.loads(path.read_text(encoding="utf-8"))
    for key in ("name", "description", "developer_instructions"):
        if not isinstance(document.get(key), str) or not document[key].strip():
            raise ValueError(f"falta el texto obligatorio: {key}")
    if document["name"] != path.stem:
        raise ValueError(f"name {document['name']} no coincide con {path.stem}")
    if (
        document["name"].startswith("reviewer-")
        and document.get("sandbox_mode") != "read-only"
    ):
        raise ValueError("todo reviewer debe declarar sandbox_mode = read-only")
    if (
        document["name"].startswith("reviewer-")
        and document.get("model") != "gpt-5.6-sol"
    ):
        raise ValueError("todo reviewer debe usar el modelo comprobado gpt-5.6-sol")
    if (
        document["name"].startswith("reviewer-")
        and document.get("model_reasoning_effort") != "high"
    ):
        raise ValueError("todo reviewer debe declarar model_reasoning_effort = high")
    return document["name"]


def check_links(skill: Path, document: Path) -> None:
    content = document.read_text(encoding="utf-8")
    for target in MARKDOWN_LINK.findall(content):
        target = target.strip("<>").split("#", 1)[0]
        if not target or "://" in target or target.startswith(("#", "/", "mailto:")):
            continue
        resolved = (document.parent / target).resolve()
        if skill not in resolved.parents and resolved != skill:
            raise ValueError(f"referencia fuera de la skill: {target}")
        if not resolved.exists():
            raise ValueError(f"referencia relativa inexistente: {target}")


def main() -> int:
    args = parse_args()
    failures: list[str] = []
    names: dict[str, Path] = {}
    for skill in sorted(path for path in args.skills_root.iterdir() if path.is_dir()):
        try:
            descriptor = skill / "SKILL.md"
            if not descriptor.is_file():
                raise ValueError("falta SKILL.md")
            frontmatter = parse_frontmatter(descriptor)
            if frontmatter["name"] != skill.name:
                raise ValueError(
                    f"carpeta {skill.name} no coincide con name {frontmatter['name']}"
                )
            if frontmatter["name"] in names:
                raise ValueError(f"name duplicado con {names[frontmatter['name']]}")
            names[frontmatter["name"]] = skill
            implicit = check_openai_yaml(skill / "agents/openai.yaml")
            if skill.name in EXPLICIT_SKILLS and implicit is not False:
                raise ValueError("la skill requiere invocación explícita")
            if skill.name in IMPLICIT_SKILLS and implicit is False:
                raise ValueError(
                    "la disciplina de referencia debe permitir invocación implícita"
                )
            for markdown in skill.rglob("*.md"):
                check_links(skill, markdown)
        except (OSError, ValueError) as error:
            failures.append(f"{skill}: {error}")
    agent_names: dict[str, Path] = {}
    for agent in sorted(args.agents_root.glob("*.toml")):
        try:
            name = check_agent(agent)
            if name in agent_names:
                raise ValueError(f"name duplicado con {agent_names[name]}")
            agent_names[name] = agent
        except (OSError, ValueError, tomllib.TOMLDecodeError) as error:
            failures.append(f"{agent}: TOML no válido: {error}")
    if failures:
        print("Skills Codex inválidas:", file=sys.stderr)
        print("\n".join(f"- {failure}" for failure in failures), file=sys.stderr)
        return 1
    print(f"✓ {len(names)} skills Codex y {len(agent_names)} agentes TOML válidos")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
