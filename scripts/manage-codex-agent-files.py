#!/usr/bin/env python3
"""Despliega los agentes TOML de Codex como ficheros regulares y reversibles."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def exists(path: Path) -> bool:
    return path.exists() or path.is_symlink()


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalized(path: Path) -> Path:
    return Path(os.path.abspath(os.fspath(path)))


def guarded_destination(home: Path, destination: Path) -> None:
    try:
        relative = destination.relative_to(home)
    except ValueError:
        fail(f"el destino de agentes debe estar dentro de HOME: {destination}")
    current = home
    for part in relative.parts:
        current /= part
        if current.is_symlink():
            fail(f"el destino de agentes atraviesa un directorio enlazado: {current}")
        if exists(current) and not current.is_dir():
            fail(f"el destino de agentes atraviesa una ruta que no es directorio: {current}")


def catalog(source: Path) -> list[Path]:
    if source.is_symlink() or not source.is_dir():
        fail(f"el catálogo de agentes no es un directorio regular: {source}")
    agents = sorted(source.glob("*.toml"))
    if not agents:
        fail(f"no hay agentes TOML en {source}")
    for agent in agents:
        if agent.is_symlink() or not agent.is_file():
            fail(f"la fuente de agente no es un archivo regular: {agent}")
    return agents


def metadata_path(state_root: Path) -> Path:
    return state_root / "dotfiles/codex-agents/managed.json"


def read_metadata(state_root: Path, destination: Path) -> dict[str, str]:
    path = metadata_path(state_root)
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"no se puede leer el estado de agentes gestionados: {error}")
    if not isinstance(data, dict):
        fail(f"el estado de agentes gestionados no es válido: {path}")
    entries = data.get("destinations", {}).get(str(destination), {})
    if not isinstance(entries, dict) or not all(
        isinstance(name, str) and isinstance(value, str) for name, value in entries.items()
    ):
        fail(f"el estado de agentes gestionados no es válido: {path}")
    return entries


def write_metadata(
    state_root: Path,
    destination: Path,
    sources: list[Path],
    backup: Path | None = None,
) -> None:
    path = metadata_path(state_root)
    path.parent.mkdir(parents=True, exist_ok=True)
    data: dict[str, object] = {"destinations": {}}
    if path.exists():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            fail(f"no se puede actualizar el estado de agentes gestionados: {error}")
    if not isinstance(data, dict):
        fail(f"el estado de agentes gestionados no es válido: {path}")
    destinations = data.setdefault("destinations", {})
    if not isinstance(destinations, dict):
        fail(f"el estado de agentes gestionados no es válido: {path}")
    destinations[str(destination)] = {source.name: digest(source) for source in sources}
    content = json.dumps(data, sort_keys=True)
    if backup is not None:
        record_metadata_after(backup, content)
    temporary = path.with_name(f".{path.name}.{os.getpid()}")
    temporary.write_text(content, encoding="utf-8")
    os.replace(temporary, path)


def snapshot_metadata(state_root: Path, backup: Path) -> None:
    path = metadata_path(state_root)
    state = {"before": None}
    if exists(path):
        if not path.is_file() or path.is_symlink():
            fail(f"el estado de agentes gestionados no es un archivo regular: {path}")
        shutil.copy2(path, backup / "metadata.json")
        state["before"] = digest(path)
    (backup / "metadata-state.json").write_text(json.dumps(state), encoding="utf-8")


def record_metadata_after(backup: Path, content: str) -> None:
    state_file = backup / "metadata-state.json"
    try:
        state = json.loads(state_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"no se puede leer el snapshot de metadatos: {error}")
    if not isinstance(state, dict) or set(state) != {"before"}:
        fail(f"el snapshot de metadatos no es válido: {backup}")
    state["after"] = hashlib.sha256(content.encode("utf-8")).hexdigest()
    state_file.write_text(json.dumps(state, sort_keys=True), encoding="utf-8")


def validate_metadata_snapshot(state_root: Path, backup: Path) -> dict[str, str | None]:
    try:
        state = json.loads((backup / "metadata-state.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"no se puede leer el snapshot de metadatos: {error}")
    if not isinstance(state, dict) or set(state) != {"before", "after"} or not isinstance(state["after"], str):
        fail(f"el snapshot de metadatos no es válido: {backup}")
    if state["before"] is not None and not isinstance(state["before"], str):
        fail(f"el snapshot de metadatos no es válido: {backup}")
    if state["before"] is not None:
        stored = backup / "metadata.json"
        if not stored.is_file() or stored.is_symlink() or digest(stored) != state["before"]:
            fail(f"falta el snapshot previo de metadatos: {stored}")
    current = metadata_path(state_root)
    if not current.is_file() or current.is_symlink() or digest(current) != state["after"]:
        fail(f"no se sobrescribe el estado de agentes cambiado durante el rollback: {current}")
    return state


def metadata_matches_after(state_root: Path, backup: Path) -> bool:
    try:
        state = json.loads((backup / "metadata-state.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    path = metadata_path(state_root)
    return (
        isinstance(state, dict)
        and isinstance(state.get("after"), str)
        and path.is_file()
        and not path.is_symlink()
        and digest(path) == state["after"]
    )


def write_text_atomically(path: Path, content: str) -> None:
    temporary = path.with_name(f".{path.name}.{os.getpid()}")
    temporary.write_text(content, encoding="utf-8")
    os.replace(temporary, path)


def manifest_rows(path: Path) -> list[tuple[str, str, str]]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    except OSError as error:
        fail(f"no se puede leer el manifiesto de enlaces: {error}")
    rows: list[tuple[str, str, str]] = []
    seen: set[str] = set()
    for line in lines:
        fields = line.rstrip("\n").split("\t")
        if len(fields) != 2 or not all(fields):
            fail(f"el manifiesto de enlaces no es válido: {path}")
        relative = fields[0]
        if relative in seen:
            fail(f"el manifiesto de enlaces repite un destino: {path}")
        seen.add(relative)
        rows.append((relative, line, fields[1]))
    return rows


def filter_manifests(
    live_path: Path,
    snapshot_path: Path,
    home: Path,
    destination: Path,
    sources: list[Path],
    managed: dict[str, str],
    migrate_legacy_links: bool,
) -> None:
    live_rows = manifest_rows(live_path)
    snapshot_rows = manifest_rows(snapshot_path)
    snapshots = {relative for relative, _, _ in snapshot_rows if relative}
    if snapshots != {relative for relative, _, _ in live_rows if relative}:
        fail("los manifiestos de enlaces no cubren los mismos destinos")
    source_by_relative = {
        str(destination.relative_to(home) / source.name): source for source in sources
    }
    removable: set[str] = set()
    for relative, _, _ in live_rows:
        source = source_by_relative.get(relative)
        if source is None or relative not in snapshots:
            continue
        state = target_state(source, destination / source.name, managed)
        if state in {"current", "managed-outdated"} or (
            migrate_legacy_links and state == "legacy-link"
        ):
            removable.add(relative)
    write_text_atomically(live_path, "".join(line for relative, line, _ in live_rows if relative not in removable))
    write_text_atomically(snapshot_path, "".join(line for relative, line, _ in snapshot_rows if relative not in removable))
    print(f"TRANSFERRED: {len(removable)} agente(s) Codex salen de manifiestos Stow.")


def restore_metadata_snapshot(state_root: Path, backup: Path, state: dict[str, str | None]) -> None:
    path = metadata_path(state_root)
    if not path.is_file() or path.is_symlink() or digest(path) != state["after"]:
        fail(f"no se sobrescribe el estado de agentes cambiado durante el rollback: {path}")
    if state["before"] is None:
        path.unlink()
        return
    stored = backup / "metadata.json"
    if not stored.is_file() or digest(stored) != state["before"]:
        fail(f"falta el snapshot previo de metadatos: {stored}")
    temporary = path.with_name(f".{path.name}.{os.getpid()}")
    shutil.copy2(stored, temporary)
    os.replace(temporary, path)


def target_state(source: Path, target: Path, managed: dict[str, str]) -> str:
    if not exists(target):
        return "missing"
    if target.is_symlink():
        try:
            return "legacy-link" if target.resolve(strict=True) == source.resolve() else "foreign"
        except OSError:
            return "foreign"
    if not target.is_file():
        return "foreign"
    target_digest = digest(target)
    if target_digest == digest(source):
        return "current" if managed.get(source.name) == target_digest else "adoptable"
    return "managed-outdated" if managed.get(source.name) == target_digest else "foreign"


def states(sources: list[Path], destination: Path, managed: dict[str, str]) -> dict[str, str]:
    result = {source.name: target_state(source, destination / source.name, managed) for source in sources}
    foreign = [name for name, state in result.items() if state == "foreign"]
    if foreign:
        fail("se conserva contenido ajeno o inesperado: " + ", ".join(str(destination / name) for name in foreign))
    return result


def backup_root(state: Path) -> Path:
    root = state / "dotfiles/codex-agents/backups"
    root.mkdir(parents=True, exist_ok=True)
    return Path(tempfile.mkdtemp(prefix="sync-", dir=root))


def write_manifest(path: Path, entries: list[dict[str, str]]) -> None:
    path.write_text(json.dumps(entries, sort_keys=True), encoding="utf-8")


def injected_replace(index: int) -> None:
    if os.environ.get("CODEX_AGENT_FILES_FAIL_REPLACE_AT") == str(index):
        raise OSError("fallo de reemplazo inyectado")


def restore_partial(backup: Path, destination: Path, entries: list[dict[str, str]]) -> None:
    failed = False
    for entry in reversed(entries):
        target = destination / entry["name"]
        stored = backup / entry["name"]
        phase, prior, expected = entry["phase"], entry["prior"], entry["digest"]
        if phase == "installed":
            if not target.is_file() or target.is_symlink() or digest(target) != expected:
                failed = True
                continue
            target.unlink()
        elif phase == "backup-moved" and exists(target):
            failed = True
            continue
        if prior in {"legacy-link", "managed-outdated"} and phase in {"backup-moved", "installed"}:
            valid_backup = stored.is_symlink() if prior == "legacy-link" else stored.is_file()
            if not valid_backup or exists(target):
                failed = True
                continue
            os.replace(stored, target)
    if failed:
        fail(f"el rollback parcial conserva cambios concurrentes; revisa: {backup}")


def apply(sources: list[Path], destination: Path, state_root: Path, managed: dict[str, str]) -> None:
    current = states(sources, destination, managed)
    pending = [source for source in sources if current[source.name] != "current"]
    if not pending:
        print(f"OK: {len(sources)} agentes Codex ya son archivos regulares sincronizados.")
        return
    destination.mkdir(parents=True, exist_ok=True)
    backup = backup_root(state_root)
    manifest = backup / "manifest.json"
    entries: list[dict[str, str]] = []
    write_manifest(manifest, entries)
    snapshot_metadata(state_root, backup)
    try:
        replacements = 0
        for source in pending:
            prior = current[source.name]
            if prior == "adoptable":
                continue
            target = destination / source.name
            temporary_fd, temporary_name = tempfile.mkstemp(prefix=f".{source.name}.", dir=destination)
            temporary = Path(temporary_name)
            try:
                with os.fdopen(temporary_fd, "wb") as output, source.open("rb") as input_file:
                    shutil.copyfileobj(input_file, output)
                    output.flush()
                    os.fsync(output.fileno())
                os.chmod(temporary, source.stat().st_mode & 0o777)
                previous = digest(target) if prior == "managed-outdated" else ""
                entry = {
                    "name": source.name,
                    "prior": prior,
                    "digest": digest(source),
                    "previous": previous,
                    "phase": "prepared",
                }
                entries.append(entry)
                write_manifest(manifest, entries)
                if prior in {"legacy-link", "managed-outdated"}:
                    os.replace(target, backup / source.name)
                    entry["phase"] = "backup-moved"
                    write_manifest(manifest, entries)
                replacements += 1
                injected_replace(replacements)
                os.replace(temporary, target)
                entry["phase"] = "installed"
                write_manifest(manifest, entries)
            finally:
                if temporary.exists():
                    temporary.unlink()
        write_metadata(state_root, destination, sources, backup)
    except BaseException:
        restore_partial(backup, destination, entries)
        if metadata_matches_after(state_root, backup):
            restore_metadata_snapshot(
                state_root,
                backup,
                validate_metadata_snapshot(state_root, backup),
            )
        raise
    print(f"Codex agents sincronizados como archivos regulares. Backup: {backup}")


def validate_rollback_entry(backup: Path, destination: Path, entry: dict[str, str]) -> None:
    name, prior, expected = entry["name"], entry["prior"], entry["digest"]
    target = destination / name
    if not target.is_file() or target.is_symlink() or digest(target) != expected:
        fail(f"no se sobrescribe un agente cambiado durante el rollback: {target}")
    if prior in {"legacy-link", "managed-outdated"}:
        stored = backup / name
        valid_backup = stored.is_symlink() if prior == "legacy-link" else stored.is_file()
        if not valid_backup:
            fail(f"falta el contenido previo para rollback: {stored}")


def rollback(
    backup: Path,
    sources: list[Path],
    destination: Path,
    state_root: Path,
    apply: bool = True,
) -> None:
    manifest = backup / "manifest.json"
    try:
        entries = json.loads(manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"no se puede leer el manifiesto de rollback: {error}")
    source_names = {source.name for source in sources}
    for entry in entries:
        if not isinstance(entry, dict) or set(entry) != {"name", "prior", "digest", "previous", "phase"}:
            fail(f"manifiesto de rollback no válido: {manifest}")
        name, prior, expected, previous, phase = (
            entry[key] for key in ("name", "prior", "digest", "previous", "phase")
        )
        if name not in source_names or prior not in {"missing", "legacy-link", "managed-outdated"} or phase != "installed":
            fail(f"manifiesto de rollback no válido: {manifest}")
        if not isinstance(previous, str):
            fail(f"manifiesto de rollback no válido: {manifest}")
        validate_rollback_entry(backup, destination, entry)
    metadata = validate_metadata_snapshot(state_root, backup)
    if not apply:
        print(f"OK: rollback de agentes Codex validado: {backup}")
        return
    for entry in reversed(entries):
        target = destination / entry["name"]
        validate_rollback_entry(backup, destination, entry)
        target.unlink()
        if entry["prior"] in {"legacy-link", "managed-outdated"}:
            os.replace(backup / entry["name"], target)
    restore_metadata_snapshot(state_root, backup, metadata)
    print(f"Agentes Codex restaurados desde: {backup}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--verify", action="store_true")
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--rollback", type=Path)
    mode.add_argument("--check-rollback", type=Path)
    mode.add_argument("--filter-manifests", nargs=2, metavar=("LIVE", "SNAPSHOT"), type=Path)
    parser.add_argument("--migrate-legacy-links", action="store_true")
    parser.add_argument("--source-root", type=Path, default=Path(os.environ.get("CODEX_AGENTS_SOURCE_ROOT", ROOT / "codex/.codex/agents")))
    home = normalized(Path(os.environ.get("HOME", str(Path.home()))))
    codex_home = Path(os.environ.get("CODEX_HOME", home / ".codex"))
    parser.add_argument("--destination-root", type=Path, default=Path(os.environ.get("CODEX_AGENTS_ROOT", codex_home / "agents")))
    parser.add_argument("--state-root", type=Path, default=Path(os.environ.get("XDG_STATE_HOME", home / ".local/state")))
    args = parser.parse_args()
    source, destination = args.source_root.resolve(), normalized(args.destination_root)
    guarded_destination(home, destination)
    sources = catalog(source)
    if args.rollback:
        rollback(normalized(args.rollback), sources, destination, args.state_root)
        return
    if args.check_rollback:
        rollback(normalized(args.check_rollback), sources, destination, args.state_root, apply=False)
        return
    managed = read_metadata(args.state_root, destination)
    if args.filter_manifests:
        live, snapshot = args.filter_manifests
        filter_manifests(
            live,
            snapshot,
            home,
            destination,
            sources,
            managed,
            args.migrate_legacy_links,
        )
        return
    current = states(sources, destination, managed)
    pending = sum(state != "current" for state in current.values())
    if args.check or not any((args.verify, args.apply)):
        print(f"SYNC: {pending} agente(s) TOML se copiarán o registrarán como archivos regulares." if pending else f"OK: {len(sources)} agentes Codex ya son archivos regulares sincronizados.")
    elif args.verify:
        if pending:
            fail("los agentes Codex desplegados no están sincronizados; revisa --check antes de aplicar.")
        print(f"OK: {len(sources)} agentes Codex ya son archivos regulares sincronizados.")
    else:
        apply(sources, destination, args.state_root, managed)


if __name__ == "__main__":
    main()
