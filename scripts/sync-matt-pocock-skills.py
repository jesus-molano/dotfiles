#!/usr/bin/env python3
"""Actualiza de forma transaccional el caché de mattpocock/skills."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

UPSTREAM = "https://github.com/mattpocock/skills.git"
METADATA = ".dotfiles-upstream.json"
EXPECTED_PATHS = (
    "skills/engineering/diagnosing-bugs/SKILL.md",
    "skills/engineering/tdd/SKILL.md",
    "skills/engineering/to-spec/SKILL.md",
    "skills/productivity/grilling/SKILL.md",
)
COMMIT_SHA = re.compile(r"[0-9a-f]{40}\Z")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument(
        "--check", action="store_true", help="valida el caché sin escribir"
    )
    modes.add_argument(
        "--apply", action="store_true", help="descarga y reemplaza el caché"
    )
    parser.add_argument("--source", default=UPSTREAM, help="repositorio Git de origen")
    parser.add_argument(
        "--target",
        type=Path,
        default=Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
        / "codex/upstreams/mattpocock-skills",
        help="directorio exacto del caché",
    )
    return parser.parse_args()


def run(*command: str, cwd: Path | None = None) -> str:
    result = subprocess.run(
        command, cwd=cwd, text=True, capture_output=True, check=False
    )
    if result.returncode:
        raise RuntimeError(f"{' '.join(command[:2])} falló: {result.stderr.strip()}")
    return result.stdout.strip()


def canonical_origin(value: str) -> str:
    value = value.strip().removesuffix("/")
    value = value.removesuffix(".git")
    if value == "git@github.com:mattpocock/skills":
        return "https://github.com/mattpocock/skills"
    return value


def validate_checkout(checkout: Path, *, allow_metadata: bool = False) -> str:
    origin = canonical_origin(run("git", "remote", "get-url", "origin", cwd=checkout))
    if origin != "https://github.com/mattpocock/skills":
        raise ValueError("origen no permitido; se exige mattpocock/skills oficial")
    branch = run("git", "branch", "--show-current", cwd=checkout)
    if branch != "main":
        raise ValueError(f"rama no permitida: {branch or '(detached)'}")
    license_path = checkout / "LICENSE"
    if license_path.is_symlink() or not license_path.is_file():
        raise ValueError("LICENSE debe ser un archivo regular del checkout")
    license_text = license_path.read_text(encoding="utf-8", errors="replace")
    if "MIT License" not in license_text:
        raise ValueError("LICENSE no declara MIT License")
    for relative in EXPECTED_PATHS:
        expected = checkout / relative
        if expected.is_symlink() or not expected.is_file():
            raise ValueError(f"falta la ruta esperada: {relative}")
    metadata_path = checkout / METADATA
    if not allow_metadata and (metadata_path.exists() or metadata_path.is_symlink()):
        raise ValueError(f"el upstream reserva la ruta local {METADATA}")
    tracked_changes = run(
        "git", "status", "--porcelain", "--untracked-files=no", cwd=checkout
    )
    if tracked_changes:
        raise ValueError("el checkout contiene modificaciones tracked")
    untracked = set(
        filter(None, run("git", "ls-files", "--others", cwd=checkout).splitlines())
    )
    allowed = {METADATA} if allow_metadata else set()
    unexpected = sorted(untracked - allowed)
    if unexpected:
        raise ValueError(
            f"el checkout contiene archivos no registrados: {unexpected[0]}"
        )
    commit = run("git", "rev-parse", "HEAD", cwd=checkout)
    if not COMMIT_SHA.fullmatch(commit):
        raise ValueError("Git no devolvió un SHA completo válido")
    return commit


def validate_source(source: str) -> None:
    """Permite fixtures locales solo si conservan el origin oficial verificable."""
    local = Path(source).expanduser()
    if local.is_dir():
        origin = canonical_origin(run("git", "remote", "get-url", "origin", cwd=local))
    else:
        origin = canonical_origin(source)
    if origin != "https://github.com/mattpocock/skills":
        raise ValueError("origen no permitido; se exige mattpocock/skills oficial")


def validate_cache(target: Path) -> str:
    if not target.is_dir():
        raise ValueError(f"no existe el caché: {target}")
    commit = validate_checkout(target, allow_metadata=True)
    metadata = target / METADATA
    if metadata.is_symlink() or not metadata.is_file():
        raise ValueError(f"falta el registro de commit: {metadata}")
    recorded = json.loads(metadata.read_text(encoding="utf-8"))
    if recorded.get("source") != UPSTREAM or recorded.get("branch") != "main":
        raise ValueError("el registro de origen o rama no coincide con el upstream")
    if recorded.get("commit") != commit:
        raise ValueError("el commit registrado no coincide con el checkout")
    return commit


def safe_target(value: Path) -> Path:
    requested = value.expanduser()
    if requested.is_symlink():
        raise ValueError("el destino exacto no puede ser un enlace simbólico")
    target = requested.resolve(strict=False)
    if target.name != "mattpocock-skills":
        raise ValueError("el destino debe terminar exactamente en mattpocock-skills")
    protected = {
        Path("/").resolve(),
        Path.home().resolve(),
        Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")).resolve(),
        Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")).resolve(),
    }
    if target in protected:
        raise ValueError("el destino coincide con un directorio amplio protegido")
    backups = backup_root().expanduser().resolve(strict=False)
    if target == backups or target in backups.parents or backups in target.parents:
        raise ValueError("el destino y el directorio de backups no pueden solaparse")
    return target


def backup_root() -> Path:
    return (
        Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
        / "dotfiles/codex-upstreams/mattpocock-skills"
    )


def replace(
    target: Path, staged: Path, commit: str, previous_commit: str | None
) -> Path | None:
    previous: Path | None = None
    retired: Path | None = None
    if target.exists() or target.is_symlink():
        stamp = time.strftime("%Y%m%d-%H%M%S") + f"-{time.time_ns()}"
        previous = backup_root() / stamp / target.name
        previous.parent.mkdir(parents=True, mode=0o700, exist_ok=False)
        if target.is_dir():
            shutil.copytree(target, previous, symlinks=True)
        else:
            shutil.copy2(target, previous, follow_symlinks=False)
        retired = target.parent / f".{target.name}.previous-{stamp}"
        target.replace(retired)
    try:
        staged.replace(target)
    except OSError:
        if retired is not None and not target.exists():
            retired.replace(target)
        raise
    if retired is not None:
        try:
            if retired.is_dir():
                shutil.rmtree(retired)
            else:
                retired.unlink()
        except OSError as error:
            print(
                f"Aviso: copia anterior temporal conservada en {retired}: {error}",
                file=sys.stderr,
            )
    print(f"Destino exacto: {target}")
    print(f"Commit anterior: {previous_commit or '(ninguno o no validado)'}")
    print(f"Commit upstream nuevo: {commit}")
    if previous is not None:
        print(f"Backup recuperable: {previous}")
    return previous


def main() -> int:
    args = parse_args()
    try:
        target = safe_target(args.target)
        if args.check:
            commit = validate_cache(target)
            print(f"✓ Caché Matt Pocock válida: {target}")
            print(f"Commit upstream: {commit}")
            return 0

        previous_commit: str | None = None
        if target.exists():
            try:
                previous_commit = validate_cache(target)
            except (OSError, RuntimeError, ValueError, json.JSONDecodeError):
                # Un caché viejo no válido también se conserva como backup.
                previous_commit = None

        target.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(
            prefix=f".{target.name}.fetch-", dir=target.parent
        ) as temporary:
            checkout = Path(temporary) / "checkout"
            validate_source(args.source)
            run(
                "git",
                "clone",
                "--depth",
                "1",
                "--branch",
                "main",
                args.source,
                str(checkout),
            )
            # Un clon local usa su ruta como origin; se normaliza tras validarlo.
            run("git", "remote", "set-url", "origin", UPSTREAM, cwd=checkout)
            commit = validate_checkout(checkout)
            metadata = checkout / METADATA
            with metadata.open("x", encoding="utf-8") as handle:
                json.dump(
                    {"source": UPSTREAM, "branch": "main", "commit": commit},
                    handle,
                    indent=2,
                )
                handle.write("\n")
            staged = Path(temporary) / target.name
            checkout.replace(staged)
            replace(target, staged, commit, previous_commit)
        return 0
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as error:
        print(
            f"Sincronización Matt Pocock cancelada sin tocar el caché anterior: {error}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
