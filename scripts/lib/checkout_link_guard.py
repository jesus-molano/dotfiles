#!/usr/bin/env python3
"""Reject links from HOME into the checkout that no declared owner manages."""

from __future__ import annotations

import os
import re
import stat
import sys


def valid_relative(value: str) -> bool:
    return (
        bool(value)
        and not value.startswith("/")
        and not value.endswith("/")
        and "//" not in value
        and "\n" not in value
        and "\t" not in value
        and all(part not in ("", ".", "..") for part in value.split("/"))
    )


def load_manifest(path: str, fields: int) -> set[tuple[str, str]]:
    entries: set[tuple[str, str]] = set()
    if not os.path.isfile(path):
        return entries
    with open(path, encoding="utf-8", errors="surrogateescape") as handle:
        for number, line in enumerate(handle, 1):
            line = line.rstrip("\n")
            if not line:
                continue
            values = line.split("\t")
            if len(values) != fields or not valid_relative(values[0]) or not values[1]:
                print(f"[AVISO] Manifiesto de enlaces no válido: {path}:{number}")
                raise SystemExit(1)
            entries.add((values[0], values[1]))
    return entries


def is_under(path: str, root: str) -> bool:
    try:
        return os.path.commonpath((path, root)) == root and path != root
    except ValueError:
        return False


def is_declared_systemd_dependency(
    link: str,
    relative: str,
    destination: str,
    known: set[tuple[str, str]],
    home: str,
) -> bool:
    """Allow only systemd's derived wants/requires link for an exact unit."""
    parts = relative.split("/")
    if (
        len(parts) != 5
        or parts[:3] != [".config", "systemd", "user"]
        or not (parts[3].endswith(".wants") or parts[3].endswith(".requires"))
    ):
        return False
    unit = parts[4]
    expected_relative = f".config/systemd/user/{unit}"
    direct_targets = {value for key, value in known if key == expected_relative}
    if len(direct_targets) != 1:
        return False
    direct_link = os.path.normpath(os.path.join(home, expected_relative))
    if not os.path.islink(direct_link):
        return False
    direct_destination = os.readlink(direct_link)
    if direct_destination not in direct_targets:
        return False

    logical_target = os.path.normpath(os.path.join(os.path.dirname(link), destination))
    if logical_target == direct_link:
        return True
    try:
        return os.path.realpath(logical_target) == os.path.realpath(direct_link)
    except OSError:
        return False


def is_declared_mise_tracked_config(
    link: str,
    relative: str,
    destination: str,
    known: set[tuple[str, str]],
    home: str,
) -> bool:
    """Allow mise's hashed cache link only when it indexes a declared link."""
    parts = relative.split("/")
    if (
        len(parts) != 5
        or parts[:4] != [".local", "state", "mise", "tracked-configs"]
        or re.fullmatch(r"[0-9a-f]{16}", parts[4]) is None
    ):
        return False
    logical_target = os.path.normpath(os.path.join(os.path.dirname(link), destination))
    if not is_under(logical_target, home) or not os.path.islink(logical_target):
        return False
    direct_relative = os.path.relpath(logical_target, home)
    if not valid_relative(direct_relative):
        return False
    try:
        if (direct_relative, os.readlink(logical_target)) not in known:
            return False
        return os.path.realpath(link) == os.path.realpath(logical_target)
    except OSError:
        return False


def is_declared_codex_skill_link(
    destination: str,
    relative: str,
    checkout: str,
    codex_selected: bool,
) -> bool:
    """Allow only exact directory links owned by the Codex skill manager."""
    if not codex_selected:
        return False
    parts = relative.split("/")
    if len(parts) != 3 or parts[:2] != [".agents", "skills"] or not parts[2]:
        return False
    source = os.path.join(checkout, "codex", ".agents", "skills", parts[2])
    if not os.path.isdir(source) or os.path.islink(source):
        return False
    return destination == source


def walk_error(error: OSError) -> None:
    print(f"[AVISO] No se pudo inspeccionar HOME durante el preflight: {error}")
    raise SystemExit(1)


def reject_untracked_links(
    home: str,
    checkout: str,
    state: str,
    plan_path: str,
    previous_path: str,
    legacy_path: str,
    codex_selected: bool,
) -> None:
    try:
        home_device = os.stat(home).st_dev
    except OSError as error:
        print(f"[AVISO] No se pudo inspeccionar HOME para el preflight: {error}")
        raise SystemExit(1) from error

    known = (
        load_manifest(plan_path, 3)
        | load_manifest(previous_path, 2)
        | load_manifest(legacy_path, 2)
    )
    pruned = {
        os.path.normpath(path)
        for path in (
            checkout,
            state,
            os.path.join(home, ".dotfiles"),
            os.path.join(home, "orca", "workspaces", ".dotfiles"),
        )
    }

    for directory, names, files in os.walk(
        home,
        topdown=True,
        followlinks=False,
        onerror=walk_error,
    ):
        kept_names: list[str] = []
        for name in names:
            candidate = os.path.normpath(os.path.join(directory, name))
            if candidate in pruned:
                continue
            try:
                metadata = os.lstat(candidate)
            except OSError as error:
                print(f"[AVISO] No se pudo inspeccionar HOME durante el preflight: {error}")
                raise SystemExit(1) from error
            if not stat.S_ISLNK(metadata.st_mode) and metadata.st_dev != home_device:
                continue
            kept_names.append(name)
        names[:] = kept_names

        for name in (*names, *files):
            link = os.path.join(directory, name)
            if not os.path.islink(link):
                continue
            resolved = os.path.realpath(link)
            if not is_under(resolved, checkout):
                continue
            relative = os.path.relpath(link, home)
            destination = os.readlink(link)
            if (relative, destination) in known:
                continue
            if is_declared_systemd_dependency(
                link,
                relative,
                destination,
                known,
                home,
            ):
                continue
            if is_declared_mise_tracked_config(
                link,
                relative,
                destination,
                known,
                home,
            ):
                continue
            if is_declared_codex_skill_link(
                destination,
                relative,
                checkout,
                codex_selected,
            ):
                continue
            print(f"[AVISO] Enlace del checkout fuera de la composición declarada: {link}")
            raise SystemExit(1)


def main() -> None:
    if len(sys.argv) != 8:
        raise SystemExit(
            "Uso: checkout_link_guard.py HOME CHECKOUT STATE "
            "PLAN PREVIOUS LEGACY CODEX_SELECTED"
        )
    home, checkout, state, plan_path, previous_path, legacy_path = map(
        os.path.abspath,
        sys.argv[1:7],
    )
    reject_untracked_links(
        home,
        checkout,
        state,
        plan_path,
        previous_path,
        legacy_path,
        sys.argv[7] == "1",
    )


if __name__ == "__main__":
    main()
