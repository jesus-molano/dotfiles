#!/usr/bin/env python3
"""Detecta y resuelve la composición local de dotfiles sin depender de HOME.

El script solamente escribe bajo XDG cuando el subcomando lo solicita. Su salida
JSON es estable para que el instalador y los tests puedan usar fixtures.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib
from pathlib import Path
from typing import Any

SCHEMA = 1
SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]*$")
SAFE_VERSION = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.+_:-]*$")


def xdg_path(variable: str, fallback: str) -> Path:
    return Path(os.environ.get(variable, os.path.expanduser(fallback))).expanduser()


def config_root() -> Path:
    return xdg_path("XDG_CONFIG_HOME", "~/.config") / "dotfiles"


def state_root() -> Path:
    return xdg_path("XDG_STATE_HOME", "~/.local/state") / "dotfiles"


def host_path(value: str | None = None) -> Path:
    return Path(value).expanduser() if value else config_root() / "host.toml"


def capabilities_path() -> Path:
    return state_root() / "hardware" / "capabilities.json"


def plan_path() -> Path:
    return state_root() / "plans" / "resolved.json"


def repo_registry_path() -> Path:
    return config_root() / "repo"


def write_private(path: Path, contents: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    os.chmod(path.parent, 0o700)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(contents)
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
        os.chmod(path, 0o600)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def command_output(*args: str, timeout: float = 3.0) -> str:
    executable = shutil.which(args[0])
    if not executable:
        return ""
    try:
        completed = subprocess.run((executable, *args[1:]), text=True, stdout=subprocess.PIPE,
                                   stderr=subprocess.DEVNULL, check=False, timeout=timeout)
    except subprocess.TimeoutExpired:
        return ""
    return completed.stdout if completed.returncode == 0 else ""


def detect() -> dict[str, Any]:
    gpus: list[str] = []
    for line in command_output("lspci", "-nn").splitlines():
        lower = line.lower()
        if "vga compatible controller" in lower or "3d controller" in lower or "display controller" in lower:
            if "nvidia" in lower:
                gpus.append("nvidia")
            elif "amd" in lower or "ati" in lower:
                gpus.append("amd")
            elif "intel" in lower:
                gpus.append("intel")
            else:
                gpus.append("unknown")
    monitors: list[dict[str, str]] = []
    hypr = command_output("hyprctl", "monitors", "-j")
    if hypr:
        try:
            for monitor in json.loads(hypr):
                name = str(monitor.get("name", ""))
                if SAFE_NAME.fullmatch(name):
                    monitors.append({"name": name})
        except json.JSONDecodeError:
            pass
    backlights = [entry.name for entry in Path("/sys/class/backlight").glob("*") if entry.is_dir()]
    inputs: list[dict[str, str]] = []
    for node in Path("/sys/class/input").glob("input*/name"):
        try:
            name = node.read_text(encoding="utf-8").strip()
        except OSError:
            continue
        lowered = name.lower()
        kind = "touchpad" if "touchpad" in lowered else "keyboard" if "keyboard" in lowered else "pointer"
        inputs.append({"class": kind, "name": name[:160]})
    audio_sinks: list[str] = []
    audio_cards: list[str] = []
    for command, destination in (("sinks", audio_sinks), ("cards", audio_cards)):
        raw = command_output("pactl", "-f", "json", "list", command)
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if isinstance(parsed, list):
            destination.extend(
                str(item["name"])[:160]
                for item in parsed
                if isinstance(item, dict) and isinstance(item.get("name"), str)
            )
    wpctl = command_output("wpctl", "status", "-n")
    audio_section = ""
    for line in wpctl.splitlines():
        heading = re.sub(r"^[^A-Za-z]+", "", line).strip().lower()
        if heading.startswith("sinks:"):
            audio_section = "sinks"
            continue
        if heading.startswith("devices:"):
            audio_section = "cards"
            continue
        entry = re.search(r"(?:\*\s*)?[0-9]+\.\s+(.+?)(?:\s+\[vol:.*)?$", line.strip())
        if entry and audio_section in ("sinks", "cards"):
            value = entry.group(1).strip()[:160]
            (audio_sinks if audio_section == "sinks" else audio_cards).append(value)
    audio_sinks = sorted(set(audio_sinks))
    audio_cards = sorted(set(audio_cards))
    rgb_devices: list[str] = []
    for line in command_output("openrgb", "--noautoconnect", "--list-devices", timeout=10).splitlines():
        # OpenRGB may print serials and USB metadata below each device. Persist
        # only numbered display names, which are sufficient for exact matching.
        match = re.fullmatch(r"\s*[0-9]+:\s*(.+?)\s*", line)
        if match and not any(character in match.group(1) for character in "\r\n\x00"):
            rgb_devices.append(match.group(1)[:160])
    detected = {
        "schema": SCHEMA,
        "gpu_vendors": sorted(set(gpus)),
        "monitors": monitors,
        "has_internal_panel": any(item["name"].startswith("eDP") for item in monitors),
        "backlights": sorted(backlights),
        "batteries": sorted(item.name for item in Path("/sys/class/power_supply").glob("BAT*") if item.is_dir()),
        "inputs": sorted(inputs, key=lambda item: (item["class"], item["name"])),
        "pipewire": bool(shutil.which("wpctl")),
        "audio": {"sinks": audio_sinks, "cards": audio_cards},
        "openrgb": bool(shutil.which("openrgb")),
        "openrgb_devices": rgb_devices,
    }
    detected["detected_at"] = int(time.time())
    fingerprint_input = {key: value for key, value in detected.items() if key != "detected_at"}
    detected["fingerprint"] = hashlib.sha256(json.dumps(fingerprint_input, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return detected


def load_toml(path: Path) -> dict[str, Any]:
    try:
        with path.open("rb") as stream:
            data = tomllib.load(stream)
    except FileNotFoundError:
        return {}
    if not isinstance(data, dict):
        raise ValueError(f"Configuración inválida: {path}")
    return data


def load_contract(repo: Path) -> dict[str, Any]:
    contract = load_toml(repo / "dotfiles.toml")
    if contract.get("schema") != SCHEMA:
        raise ValueError("dotfiles.toml tiene un esquema no compatible")
    return contract


def string_list(value: Any, label: str) -> list[str]:
    if value is None:
        return []
    if not isinstance(value, list) or not all(isinstance(item, str) and SAFE_NAME.fullmatch(item) for item in value):
        raise ValueError(f"{label} debe ser una lista de identificadores seguros")
    return list(dict.fromkeys(value))


def compatibility_requirements(contract: dict[str, Any]) -> dict[str, dict[str, str]]:
    compatibility = contract.get("compatibility", {})
    if not isinstance(compatibility, dict):
        raise ValueError("compatibility debe ser una tabla")
    reject_unknown(compatibility, {"packages"}, "compatibility")
    packages = compatibility.get("packages", {})
    if not isinstance(packages, dict):
        raise ValueError("compatibility.packages debe ser una tabla")
    normalized: dict[str, dict[str, str]] = {}
    for package, requirement in packages.items():
        if not isinstance(package, str) or not SAFE_NAME.fullmatch(package):
            raise ValueError("compatibility.packages contiene un paquete no seguro")
        if not isinstance(requirement, dict):
            raise ValueError(f"compatibility.packages.{package} debe ser una tabla")
        reject_unknown(requirement, {"minimum", "stable_minimum", "source"}, f"compatibility.packages.{package}")
        minimum, stable_minimum, source = requirement.get("minimum"), requirement.get("stable_minimum"), requirement.get("source")
        if not isinstance(minimum, str) or not SAFE_VERSION.fullmatch(minimum):
            raise ValueError(f"Mínimo inválido para {package}")
        if stable_minimum is not None and (not isinstance(stable_minimum, str) or not SAFE_VERSION.fullmatch(stable_minimum)):
            raise ValueError(f"Mínimo estable inválido para {package}")
        if source not in ("native", "aur"):
            raise ValueError(f"Origen inválido para {package}")
        normalized[package] = {"minimum": minimum, "source": source}
        if stable_minimum is not None:
            normalized[package]["stable_minimum"] = stable_minimum
    return dict(sorted(normalized.items()))


def reject_unknown(mapping: dict[str, Any], allowed: set[str], label: str) -> None:
    unknown = sorted(set(mapping) - allowed)
    if unknown:
        raise ValueError(f"Claves desconocidas en {label}: {', '.join(unknown)}")


def toml_value(value: Any, label: str) -> str:
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        if not value == value or value in (float("inf"), float("-inf")):
            raise ValueError(f"{label} no es un número finito")
        return format(value, "g")
    if isinstance(value, str):
        if "\x00" in value:
            raise ValueError(f"{label} contiene NUL")
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list) and all(isinstance(item, str) and "\x00" not in item for item in value):
        return json.dumps(value, ensure_ascii=False)
    raise ValueError(f"Tipo TOML no admitido en {label}")


def serialize_host(host: dict[str, Any]) -> str:
    reject_unknown(host, {"schema", "bundles", "hardware", "input", "workspaces", "audio", "rgb", "backup"}, "host")
    lines = [f"schema = {SCHEMA}", "bundles = " + toml_value(string_list(host.get("bundles"), "bundles"), "bundles")]

    hardware = host.get("hardware", {})
    if not isinstance(hardware, dict):
        raise ValueError("hardware debe ser una tabla")
    reject_unknown(hardware, {"displays"}, "hardware")
    lines.extend(["", "[hardware]"])
    displays = hardware.get("displays", [])
    if not isinstance(displays, list):
        raise ValueError("hardware.displays debe ser una lista")
    for index, display in enumerate(displays):
        if not isinstance(display, dict):
            raise ValueError("Pantalla inválida")
        keys = {"name", "role", "mode", "position", "scale", "vrr"}
        reject_unknown(display, keys, f"hardware.displays[{index}]")
        lines.extend(["", "[[hardware.displays]]"])
        for key in ("name", "role", "mode", "position", "scale", "vrr"):
            if key in display:
                lines.append(f"{key} = {toml_value(display[key], f'hardware.displays.{key}')}")

    input_config = host.get("input", {})
    if not isinstance(input_config, dict):
        raise ValueError("input debe ser una tabla")
    reject_unknown(input_config, {"keyboard_layouts", "toggle_layouts", "local_dictation", "touchpad", "gestures", "devices"}, "input")
    lines.extend(["", "[input]"])
    for key in ("keyboard_layouts", "toggle_layouts", "local_dictation"):
        if key in input_config:
            lines.append(f"{key} = {toml_value(input_config[key], f'input.{key}')}")
    for section, ordered_keys in (
        ("touchpad", ("tap_to_click", "natural_scroll", "disable_while_typing")),
        ("gestures", ("workspace_swipe", "fingers")),
    ):
        values = input_config.get(section)
        if values is None:
            continue
        if not isinstance(values, dict):
            raise ValueError(f"input.{section} debe ser una tabla")
        reject_unknown(values, set(ordered_keys), f"input.{section}")
        lines.extend(["", f"[input.{section}]"])
        for key in ordered_keys:
            if key in values:
                lines.append(f"{key} = {toml_value(values[key], f'input.{section}.{key}')}")
    devices = input_config.get("devices", [])
    if not isinstance(devices, list):
        raise ValueError("input.devices debe ser una lista")
    for index, device in enumerate(devices):
        if not isinstance(device, dict):
            raise ValueError("Dispositivo de entrada inválido")
        reject_unknown(device, {"name", "accel_profile"}, f"input.devices[{index}]")
        lines.extend(["", "[[input.devices]]"])
        for key in ("name", "accel_profile"):
            if key in device:
                lines.append(f"{key} = {toml_value(device[key], f'input.devices.{key}')}")

    workspaces = host.get("workspaces")
    if workspaces is not None:
        if not isinstance(workspaces, dict):
            raise ValueError("workspaces debe ser una tabla")
        reject_unknown(workspaces, {"left", "right", "split_after", "music", "scrolling", "icons"}, "workspaces")
        lines.extend(["", "[workspaces]"])
        for key in ("left", "right", "split_after", "music", "scrolling"):
            if key in workspaces:
                lines.append(f"{key} = {toml_value(workspaces[key], f'workspaces.{key}')}")
        icons = workspaces.get("icons")
        if icons is not None:
            if not isinstance(icons, dict):
                raise ValueError("workspaces.icons debe ser una tabla")
            lines.extend(["", "[workspaces.icons]"])
            for key, value in sorted(icons.items(), key=lambda item: int(item[0]) if str(item[0]).isdigit() else 1000):
                if not isinstance(key, str) or not key.isdigit():
                    raise ValueError("Clave de icono de workspace inválida")
                lines.append(f"{toml_value(key, 'workspaces.icons')} = {toml_value(value, 'workspaces.icons')}")

    for section, ordered_keys in (
        ("audio", ("cycle", "ensure_on_start", "card", "base_profile", "secondary_profile", "sink_prefix", "base_sink", "secondary_sink", "default_profile", "default_sink")),
        ("rgb", ("enabled", "mode", "ambient_color", "openrgb_device", "nzxt_device", "static_color", "openrgb_zone", "openrgb_zone_size", "cpu_led_count", "cpu_green_threshold", "cpu_orange_threshold", "cpu_red_threshold", "gpu_green_threshold", "gpu_orange_threshold", "gpu_red_threshold", "interval", "debounce", "hysteresis", "reapply_interval")),
        ("backup", ("repository",)),
    ):
        values = host.get(section)
        if values is None:
            continue
        if not isinstance(values, dict):
            raise ValueError(f"{section} debe ser una tabla")
        reject_unknown(values, set(ordered_keys), section)
        lines.extend(["", f"[{section}]"])
        for key in ordered_keys:
            if key in values:
                lines.append(f"{key} = {toml_value(values[key], f'{section}.{key}')}")
    return "\n".join(lines) + "\n"


def read_capabilities(path: Path | None = None) -> dict[str, Any]:
    candidate = path or capabilities_path()
    try:
        raw = json.loads(candidate.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {}
    if not isinstance(raw, dict) or raw.get("schema") != SCHEMA:
        raise ValueError("capabilities.json tiene un esquema no compatible")
    return raw


def resolve(repo: Path, host: dict[str, Any], capabilities: dict[str, Any], safe_defaults: bool) -> dict[str, Any]:
    contract = load_contract(repo)
    if host and host.get("schema", SCHEMA) != SCHEMA:
        raise ValueError("host.toml tiene un esquema no compatible")
    if host:
        serialize_host(host)
    bundles = string_list(host.get("bundles") if host else [], "bundles")
    hardware = host.get("hardware", {}) if host else {}
    if not isinstance(hardware, dict):
        raise ValueError("hardware debe ser una tabla")
    capability_names: list[str] = []
    known_bundles = contract.get("bundles", {})
    known_capabilities = contract.get("capabilities", {})
    for name, capability in known_capabilities.items():
        if not isinstance(capability, dict):
            continue
        key, expected = capability.get("detector_key"), capability.get("detector_value")
        observed = capabilities.get(key, [])
        if isinstance(key, str) and expected in observed:
            capability_names.append(name)
    unknown = sorted(set(bundles) - set(known_bundles))
    if unknown:
        raise ValueError("Identificadores desconocidos: " + ", ".join(unknown))

    modules = list(contract["base"]["modules"])
    selected_scopes = {"base"}
    for name in capability_names:
        modules.extend(known_capabilities[name].get("modules", []))
    for name in bundles:
        bundle = known_bundles[name]
        required = string_list(bundle.get("requires"), f"bundles.{name}.requires")
        unavailable = [item for item in required if not capabilities.get(item, False)]
        if unavailable:
            raise ValueError(f"El bundle {name} requiere: {', '.join(unavailable)}")
        modules.extend(bundle.get("modules", []))
        selected_scopes.add("bundle:" + name)
    modules = list(dict.fromkeys(modules))
    for module in modules:
        if not SAFE_NAME.fullmatch(module):
            raise ValueError(f"Nombre de módulo inválido: {module}")
    stale = not bool(capabilities)
    plan = {
        "schema": SCHEMA,
        "repo": str(repo),
        "modules": modules,
        "bundles": bundles,
        "capabilities": capability_names,
        "package_scopes": sorted(selected_scopes),
        "compatibility": {"packages": compatibility_requirements(contract)},
        "safe_defaults": safe_defaults,
        "stale_capabilities": stale,
        "hardware": host.get("hardware", {}) if host else {},
        "input": host.get("input", {}) if host else {},
        "workspaces": host.get("workspaces", {}) if host else {},
        "audio": host.get("audio", {}) if host else {},
        "rgb": host.get("rgb", {}) if host else {},
        "backup": host.get("backup", {}) if host else {},
        "hardware_facts": {
            "has_internal_panel": capabilities.get("has_internal_panel") is True,
            "backlights": [item for item in capabilities.get("backlights", []) if isinstance(item, str) and SAFE_NAME.fullmatch(item)],
        },
    }
    # All read-only resolution paths validate the same renderers used by apply.
    # This prevents package installation from starting with an invalid host.
    rendered_artifacts(plan)
    plan["hash"] = hashlib.sha256(json.dumps(plan, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return plan


def lua_string(value: str) -> str:
    if not isinstance(value, str) or "\x00" in value:
        raise ValueError("Cadena Lua inválida")
    return json.dumps(value, ensure_ascii=False)


def generated_hypr(plan: dict[str, Any]) -> dict[str, str]:
    hardware = plan.get("hardware", {})
    displays = hardware.get("displays", [])
    if not isinstance(displays, list):
        raise ValueError("hardware.displays debe ser una lista")
    facts = plan.get("hardware_facts", {})
    if not isinstance(facts, dict):
        facts = {}
    monitor_lines = ["-- Generated by dotfiles_host.py. Do not edit."]
    for display in displays:
        if not isinstance(display, dict):
            raise ValueError("Pantalla inválida")
        name = str(display.get("name", ""))
        if not SAFE_NAME.fullmatch(name):
            raise ValueError("Nombre de pantalla inválido")
        mode = str(display.get("mode", "preferred"))
        scale = display.get("scale", 1)
        if mode != "preferred" and not re.fullmatch(r"[0-9]{2,5}x[0-9]{2,5}@[0-9]+(?:\.[0-9]+)?", mode):
            raise ValueError("Modo de pantalla inválido")
        if isinstance(scale, bool) or not isinstance(scale, (int, float)) or not 0.5 <= scale <= 4:
            raise ValueError("Escala de pantalla inválida")
        position = str(display.get("position", "auto"))
        if position != "auto" and not re.fullmatch(r"-?[0-9]{1,5}x-?[0-9]{1,5}", position):
            raise ValueError("Posición de pantalla inválida")
        if "vrr" in display and not isinstance(display["vrr"], bool):
            raise ValueError("VRR de pantalla inválido")
        vrr = "true" if display.get("vrr") is True else "false"
        monitor_lines.append(
            "hl.monitor({ output = " + lua_string(name) + ", mode = " + lua_string(mode) +
            ", position = " + lua_string(position) + ", scale = " + lua_string(format(scale, "g")) +
            ", vrr = " + vrr + " })"
        )
    fallback_monitor = 'hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "1", vrr = false })'
    has_internal_panel = facts.get("has_internal_panel") is True or any(
        isinstance(display, dict) and str(display.get("name", "")).startswith(("eDP", "LVDS", "DSI"))
        for display in displays
    )
    if has_internal_panel:
        # Keep the generic rule before the internal panel override. This
        # preserves the laptop's non-default scale when Hyprland matches both.
        monitor_lines.insert(1, fallback_monitor)
    else:
        monitor_lines.append(fallback_monitor)
    audio_config = plan.get("audio", {})
    if isinstance(audio_config, dict) and audio_config.get("ensure_on_start") is True:
        monitor_lines.append("hl.on('hyprland.start', function() hl.exec_cmd('ensure-configured-audio') end)")
    user_input = plan.get("input", {})
    if not isinstance(user_input, dict):
        raise ValueError("input debe ser una tabla")
    keyboard = user_input.get("keyboard_layouts", ["us"])
    if not isinstance(keyboard, list) or not keyboard or not all(isinstance(x, str) and re.fullmatch(r"[a-z]{2}(?:,[a-z]{2})*", x) for x in keyboard):
        raise ValueError("keyboard_layouts inválido")
    layout = ",".join(keyboard)
    input_lines = [
        "-- Generated by dotfiles_host.py. Do not edit.",
        "hl.config({ input = { follow_mouse = 0, mouse_refocus = false, repeat_delay = 300, repeat_rate = 40 } })",
    ]
    touchpad = user_input.get("touchpad", {})
    if not isinstance(touchpad, dict):
        raise ValueError("input.touchpad debe ser una tabla")
    allowed = {"tap_to_click": "tap_to_click", "natural_scroll": "natural_scroll", "disable_while_typing": "disable_while_typing"}
    rendered = []
    for key, lua_key in allowed.items():
        if key in touchpad:
            if not isinstance(touchpad[key], bool):
                raise ValueError(f"input.touchpad.{key} debe ser booleano")
            rendered.append(f"{lua_key} = {str(touchpad[key]).lower()}")
    if rendered:
        input_lines.append("hl.config({ input = { touchpad = { " + ", ".join(rendered) + " } } })")
    gestures = user_input.get("gestures", {})
    if gestures is not None and not isinstance(gestures, dict):
        raise ValueError("input.gestures debe ser una tabla")
    if isinstance(gestures, dict) and "workspace_swipe" in gestures and not isinstance(gestures["workspace_swipe"], bool):
        raise ValueError("input.gestures.workspace_swipe debe ser booleano")
    if isinstance(gestures, dict) and gestures.get("workspace_swipe") is True:
        fingers = gestures.get("fingers", 4)
        if not isinstance(fingers, int) or not 3 <= fingers <= 5:
            raise ValueError("input.gestures.fingers debe estar entre 3 y 5")
        input_lines.append('hl.gesture({ fingers = ' + str(fingers) + ', direction = "horizontal", action = "workspace" })')
    devices = user_input.get("devices", [])
    if not isinstance(devices, list):
        raise ValueError("input.devices debe ser una lista")
    for device in devices:
        if not isinstance(device, dict) or not isinstance(device.get("name"), str):
            raise ValueError("Dispositivo de entrada inválido")
        name, accel = device["name"], device.get("accel_profile")
        if not name or len(name) > 160 or any(character in name for character in "\r\n\x00") or not isinstance(accel, str) or accel not in ("flat", "adaptive"):
            raise ValueError("Dispositivo de entrada inválido")
        input_lines.append("hl.device({ name = " + lua_string(name) + ", accel_profile = " + lua_string(accel) + " })")
    workspaces = plan.get("workspaces", {})
    if not isinstance(workspaces, dict):
        raise ValueError("workspaces debe ser una tabla")
    split_after = workspaces.get("split_after")
    left, right = workspaces.get("left"), workspaces.get("right")
    workspace_policy_present = any(key in workspaces for key in ("left", "right", "split_after"))
    if all(isinstance(item, str) and SAFE_NAME.fullmatch(item) for item in (left, right)) and isinstance(split_after, int) and not isinstance(split_after, bool) and 1 <= split_after <= 8:
        policy = "{ left = " + lua_string(left) + ", right = " + lua_string(right) + ", split_after = " + str(split_after) + " }"
    elif workspace_policy_present:
        raise ValueError("workspaces requiere left, right y split_after válidos")
    else:
        policy = "nil"
    user_lines = ["-- Generated by dotfiles_host.py. Do not edit.", "WORKSPACE_MONITOR_POLICY = " + policy,
                  "hl.config({ input = { kb_layout = " + lua_string(layout) + " } })"]
    icons = workspaces.get("icons", {})
    if not isinstance(icons, dict) or not all(isinstance(key, str) and key.isdigit() and 1 <= int(key) <= 99 and isinstance(value, str) and "\x00" not in value for key, value in icons.items()):
        raise ValueError("workspaces.icons inválido")
    if icons:
        rendered_icons = ", ".join("[" + key + "] = " + lua_string(value) for key, value in sorted(icons.items(), key=lambda item: int(item[0])))
        user_lines.append("WORKSPACE_ICON_OVERRIDES = { " + rendered_icons + " }")
    for source, lua_name in (("music", "MUSIC_WORKSPACE"), ("scrolling", "SCROLLING_WORKSPACE")):
        value = workspaces.get(source)
        if source in workspaces and (not isinstance(value, int) or isinstance(value, bool) or not 1 <= value <= 99):
            raise ValueError(f"workspaces.{source} inválido")
        if isinstance(value, int):
            user_lines.append(lua_name + " = " + str(value))
    for boolean_key in ("toggle_layouts", "local_dictation"):
        if boolean_key in user_input and not isinstance(user_input[boolean_key], bool):
            raise ValueError(f"input.{boolean_key} debe ser booleano")
    if user_input.get("toggle_layouts") is True and len(keyboard) > 1:
        user_lines.append('HYPR_BIND("SUPER + Space", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"), { description = "Toggle English and Spanish keyboard" })')
    if "local-ai" in plan.get("bundles", []) and user_input.get("local_dictation") is True:
        user_lines.append('HYPR_BIND("CONTROL + ALT + SUPER + SHIFT + R", hl.dsp.exec_cmd("local-dictation toggle --paste"), { description = "Toggle local dictation" })')
    audio = plan.get("audio", {})
    if not isinstance(audio, dict):
        raise ValueError("audio debe ser una tabla")
    for boolean_key in ("cycle", "ensure_on_start"):
        if boolean_key in audio and not isinstance(audio[boolean_key], bool):
            raise ValueError(f"audio.{boolean_key} debe ser booleano")
    bind_lines = ["-- Generated by dotfiles_host.py. Do not edit."]
    if isinstance(facts, dict) and facts.get("backlights"):
        bind_lines.extend([
            'HYPR_BIND("XF86MonBrightnessUp", hl.dsp.exec_cmd("noctalia msg brightness-up"), { description = "Increase brightness", locked = true, repeating = true })',
            'HYPR_BIND("XF86MonBrightnessDown", hl.dsp.exec_cmd("noctalia msg brightness-down"), { description = "Decrease brightness", locked = true, repeating = true })',
        ])
    return {
        "monitors.lua": "\n".join(monitor_lines) + "\n",
        "inputs.lua": "\n".join(input_lines) + "\n",
        "user-inputs.lua": "\n".join(user_lines) + "\n",
        "hardware-binds.lua": "\n".join(bind_lines) + "\n",
    }


def rendered_audio(plan: dict[str, Any]) -> str | None:
    audio = plan.get("audio", {})
    if not isinstance(audio, dict):
        raise ValueError("audio debe ser una tabla")
    if not audio:
        return None
    allowed = {
        "card": "DOTFILES_AUDIO_CARD", "base_profile": "DOTFILES_AUDIO_BASE_PROFILE", "secondary_profile": "DOTFILES_AUDIO_SECONDARY_PROFILE",
        "sink_prefix": "DOTFILES_AUDIO_SINK_PREFIX", "base_sink": "DOTFILES_AUDIO_BASE_SINK", "secondary_sink": "DOTFILES_AUDIO_SECONDARY_SINK",
        "default_profile": "DOTFILES_AUDIO_DEFAULT_PROFILE", "default_sink": "DOTFILES_AUDIO_DEFAULT_SINK",
    }
    lines = ["# Generated by dotfiles_host.py. Do not edit."]
    for source, destination in allowed.items():
        value = audio.get(source)
        if value is None:
            continue
        if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9_.:-]+", value):
            raise ValueError(f"audio.{source} inválido")
        lines.append(destination + "=" + value)
    return "\n".join(lines) + "\n"


def rendered_rgb(plan: dict[str, Any]) -> str | None:
    rgb = plan.get("rgb", {})
    if not isinstance(rgb, dict):
        raise ValueError("rgb debe ser una tabla")
    if "rgb-openrgb" in plan.get("bundles", []) and "enabled" in rgb and not isinstance(rgb["enabled"], bool):
        raise ValueError("rgb.enabled debe ser booleano")
    if "rgb-openrgb" not in plan.get("bundles", []) or rgb.get("enabled") is not True:
        return None
    required_strings = ("mode", "ambient_color", "openrgb_device", "nzxt_device", "static_color")
    required_numbers = ("openrgb_zone", "openrgb_zone_size", "cpu_led_count", "cpu_green_threshold", "cpu_orange_threshold", "cpu_red_threshold", "gpu_green_threshold", "gpu_orange_threshold", "gpu_red_threshold", "interval", "debounce", "hysteresis", "reapply_interval")
    if any(not isinstance(rgb.get(name), str) or not rgb[name] or len(rgb[name]) > 160 or any(char in rgb[name] for char in "\r\n\x00") for name in required_strings):
        raise ValueError("rgb requiere todos los targets y umbrales válidos")
    if rgb["mode"] not in ("ambient", "thermal", "gaming", "recording", "build-pass", "build-fail"):
        raise ValueError("rgb.mode inválido")
    for color in ("ambient_color", "static_color"):
        if not re.fullmatch(r"[0-9A-Fa-f]{6}", rgb[color]):
            raise ValueError(f"rgb.{color} debe ser un color hexadecimal de seis dígitos")
    limits = {
        "openrgb_zone": (0, 99), "openrgb_zone_size": (1, 999), "cpu_led_count": (1, 998),
        "cpu_green_threshold": (1, 150), "cpu_orange_threshold": (1, 150), "cpu_red_threshold": (1, 150),
        "gpu_green_threshold": (1, 150), "gpu_orange_threshold": (1, 150), "gpu_red_threshold": (1, 150),
        "interval": (1, 3600), "debounce": (1, 20), "hysteresis": (0, 15), "reapply_interval": (30, 3600),
    }
    for name in required_numbers:
        value = rgb.get(name)
        minimum, maximum = limits[name]
        if isinstance(value, bool) or not isinstance(value, int) or not minimum <= value <= maximum:
            raise ValueError(f"rgb.{name} debe estar entre {minimum} y {maximum}")
    if rgb["cpu_led_count"] >= rgb["openrgb_zone_size"]:
        raise ValueError("rgb.cpu_led_count debe ser menor que rgb.openrgb_zone_size")
    if not (rgb["cpu_green_threshold"] < rgb["cpu_orange_threshold"] < rgb["cpu_red_threshold"]):
        raise ValueError("Los umbrales CPU de RGB deben estar ordenados")
    if not (rgb["gpu_green_threshold"] < rgb["gpu_orange_threshold"] < rgb["gpu_red_threshold"]):
        raise ValueError("Los umbrales GPU de RGB deben estar ordenados")
    lines = ["REACTIVE_RGB_ENABLED=1"]
    for name in required_strings + required_numbers:
        lines.append("REACTIVE_RGB_" + name.upper() + "=" + str(rgb[name]))
    return "\n".join(lines) + "\n"


def rendered_qmd(plan: dict[str, Any]) -> str | None:
    if "productivity-extra" not in plan.get("bundles", []):
        return None
    template = Path(plan["repo"]) / "templates" / "qmd" / "index.yml.in"
    if not template.is_file():
        raise ValueError("Falta la plantilla QMD")
    atlas = Path(os.environ.get("PROJECT_ATLAS_ROOT", "~/dev/project-atlas")).expanduser()
    return template.read_text(encoding="utf-8").replace(
        "__DOTFILES_REPO__/docs", json.dumps(str(Path(plan["repo"]) / "docs"), ensure_ascii=False)
    ).replace("__PROJECT_ATLAS_ROOT__/docs", json.dumps(str(atlas / "docs"), ensure_ascii=False))


def rendered_backup_repository(plan: dict[str, Any]) -> str | None:
    backup = plan.get("backup", {})
    if not isinstance(backup, dict):
        raise ValueError("backup debe ser una tabla")
    if "backup" not in plan.get("bundles", []):
        return None
    if not isinstance(backup.get("repository"), str):
        raise ValueError("El bundle backup requiere backup.repository en host.toml")
    repository = backup["repository"].strip()
    if not repository or len(repository) > 2048 or any(character in repository for character in "\x00\n\r"):
        raise ValueError("backup.repository debe ser un destino Restic no vacío y de una sola línea")
    return repository + "\n"


def rendered_artifacts(plan: dict[str, Any]) -> dict[str, Any]:
    return {
        "hypr": generated_hypr(plan),
        "audio": rendered_audio(plan),
        "rgb": rendered_rgb(plan),
        "qmd": rendered_qmd(plan),
        "restic": rendered_backup_repository(plan),
    }


def write_plan_and_hypr(plan: dict[str, Any]) -> None:
    artifacts = rendered_artifacts(plan)
    write_private(plan_path(), json.dumps(plan, indent=2, sort_keys=True) + "\n")
    directory = state_root() / "generated" / "hypr" / "config"
    for name, contents in artifacts["hypr"].items():
        write_private(directory / name, contents)
    for key, path in (
        ("audio", state_root() / "generated" / "audio.conf"),
        ("rgb", state_root() / "staged" / "reactive-rgb" / "config.conf"),
        ("qmd", state_root() / "staged" / "qmd" / "index.yml"),
        ("restic", state_root() / "staged" / "restic" / "repository"),
    ):
        contents = artifacts[key]
        if contents is None:
            path.unlink(missing_ok=True)
        else:
            write_private(path, contents)


def repository(value: str | None) -> Path:
    if value:
        repo = Path(value).expanduser().resolve()
    else:
        repo = Path(__file__).resolve().parent.parent
    if not (repo / "dotfiles.toml").is_file():
        raise ValueError(f"No es un checkout de dotfiles: {repo}")
    return repo


def cmd_detect(args: argparse.Namespace) -> int:
    detected = detect()
    if args.write:
        write_private(capabilities_path(), json.dumps(detected, indent=2, sort_keys=True) + "\n")
    print(json.dumps(detected, indent=2, sort_keys=True))
    return 0


def cmd_configure(args: argparse.Namespace) -> int:
    repo = repository(args.repo)
    path = host_path(args.host_config)
    existing = load_toml(path)
    if existing and existing.get("schema", SCHEMA) != SCHEMA:
        raise ValueError("host.toml tiene un esquema no compatible")
    host: dict[str, Any] = copy.deepcopy(existing) or {"schema": SCHEMA, "bundles": [], "hardware": {}, "input": {"keyboard_layouts": ["us"]}}
    if not isinstance(host, dict):
        raise ValueError("host.toml inválido")
    host["schema"] = SCHEMA
    host["bundles"] = string_list(args.bundle if args.bundle is not None else host.get("bundles"), "bundles")
    detected = detect()
    write_private(capabilities_path(), json.dumps(detected, indent=2, sort_keys=True) + "\n")
    if args.interactive and not sys.stdin.isatty():
        raise ValueError("--interactive requiere una terminal")
    interactive = sys.stdin.isatty()
    if interactive:
        known = ", ".join(load_contract(repo).get("bundles", {}).keys())
        current = ",".join(host["bundles"]) or "base"
        answer = input(
            f"Bundles disponibles: {known}\n"
            f"Bundles separados por comas; usa base/none para ninguno [{current}]: "
        ).strip()
        if answer:
            if answer.lower() in ("base", "none"):
                host["bundles"] = []
            else:
                host["bundles"] = string_list(
                    [item.strip() for item in answer.split(",") if item.strip()], "bundles"
                )
        input_config = host.setdefault("input", {})
        if not isinstance(input_config, dict):
            raise ValueError("input debe ser una tabla")
        current_layouts = input_config.get("keyboard_layouts", ["us"])
        layout_answer = input("Layouts de teclado, en orden [" + ",".join(current_layouts) + "]: ").strip()
        if layout_answer:
            keyboard_layouts = [item.strip() for item in layout_answer.split(",") if item.strip()]
            if not keyboard_layouts or not all(re.fullmatch(r"[a-z]{2}", item) for item in keyboard_layouts):
                raise ValueError("Layouts de teclado inválidos")
            input_config["keyboard_layouts"] = keyboard_layouts
    touchpad = any(item.get("class") == "touchpad" for item in detected.get("inputs", []) if isinstance(item, dict))
    input_config = host.setdefault("input", {})
    if not isinstance(input_config, dict):
        raise ValueError("input debe ser una tabla")
    input_config.setdefault("keyboard_layouts", ["us"])
    configured_layouts = input_config["keyboard_layouts"]
    if isinstance(configured_layouts, list) and len(configured_layouts) > 1:
        input_config.setdefault("toggle_layouts", True)
    if "local-ai" in host["bundles"]:
        input_config.setdefault("local_dictation", True)
    if "backup" in host["bundles"]:
        backup_config = host.setdefault("backup", {})
        if not isinstance(backup_config, dict):
            raise ValueError("backup debe ser una tabla")
        if not isinstance(backup_config.get("repository"), str) or not backup_config["repository"].strip():
            if not interactive:
                raise ValueError("El bundle backup requiere backup.repository")
            repository_answer = input("Repositorio Restic de este equipo: ").strip()
            if not repository_answer:
                raise ValueError("El bundle backup requiere backup.repository")
            backup_config["repository"] = repository_answer
    if interactive and touchpad and "natural_scroll" not in input_config.get("touchpad", {}):
        natural_answer = input("Scroll natural del touchpad [s/N]: ").strip().lower()
        if natural_answer not in ("", "s", "si", "sí", "n", "no"):
            raise ValueError("Respuesta de scroll natural inválida")
        input_config.setdefault("touchpad", {})["natural_scroll"] = natural_answer in ("s", "si", "sí")
    if touchpad:
        touchpad_config = input_config.setdefault("touchpad", {})
        if not isinstance(touchpad_config, dict):
            raise ValueError("input.touchpad debe ser una tabla")
        for key, value in (("tap_to_click", True), ("natural_scroll", False), ("disable_while_typing", True)):
            touchpad_config.setdefault(key, value)
        gestures = input_config.setdefault("gestures", {})
        if not isinstance(gestures, dict):
            raise ValueError("input.gestures debe ser una tabla")
        gestures.setdefault("workspace_swipe", True)
        gestures.setdefault("fingers", 4)
    hardware = host.setdefault("hardware", {})
    if not isinstance(hardware, dict):
        raise ValueError("hardware debe ser una tabla")
    displays = hardware.setdefault("displays", [])
    if not isinstance(displays, list):
        raise ValueError("hardware.displays debe ser una lista")
    known_displays = {item.get("name") for item in displays if isinstance(item, dict)}
    if interactive and not detected.get("monitors"):
        print(
            "Aviso: Hyprland no ha devuelto pantallas. Se conservarán las reglas existentes "
            "y se usará el fallback automático si no hay ninguna.",
            file=sys.stderr,
        )
    for monitor in detected.get("monitors", []):
        if isinstance(monitor, dict) and SAFE_NAME.fullmatch(str(monitor.get("name", ""))) and monitor["name"] not in known_displays:
            position, scale, vrr = "auto", 1.0, False
            if interactive:
                position_answer = input(f"Posición de {monitor['name']} [auto]: ").strip()
                scale_answer = input(f"Escala de {monitor['name']} [1]: ").strip()
                vrr_answer = input(f"VRR de {monitor['name']} [s/N]: ").strip().lower()
                if position_answer:
                    if not re.fullmatch(r"-?[0-9]{1,5}x-?[0-9]{1,5}", position_answer):
                        raise ValueError(f"Posición inválida para {monitor['name']}")
                    position = position_answer
                if scale_answer:
                    try:
                        scale = float(scale_answer)
                    except ValueError as error:
                        raise ValueError(f"Escala inválida para {monitor['name']}") from error
                    if not 0.5 <= scale <= 4:
                        raise ValueError(f"Escala inválida para {monitor['name']}")
                if vrr_answer not in ("", "s", "si", "sí", "n", "no"):
                    raise ValueError(f"Respuesta VRR inválida para {monitor['name']}")
                vrr = vrr_answer in ("s", "si", "sí")
            displays.append({"name": monitor["name"], "mode": "preferred", "position": position, "scale": scale, "vrr": vrr})
    plan = resolve(repo, host, detected, safe_defaults=True)
    generated_hypr(plan)
    write_private(path, serialize_host(host))
    write_private(repo_registry_path(), str(repo) + "\n")
    print(path)
    return 0


def cmd_resolve(args: argparse.Namespace) -> int:
    repo = repository(args.repo)
    configured_host = host_path(args.host_config)
    if not configured_host.is_file() and not args.safe_defaults:
        raise ValueError("Falta host.toml; ejecuta configure o usa --safe-defaults")
    host = load_toml(configured_host)
    caps = read_capabilities(Path(args.capabilities) if args.capabilities else None)
    plan = resolve(repo, host, caps, args.safe_defaults)
    if args.write:
        write_plan_and_hypr(plan)
        write_private(repo_registry_path(), str(repo) + "\n")
    print(json.dumps(plan, indent=2, sort_keys=True))
    return 0


def cmd_show(args: argparse.Namespace) -> int:
    return cmd_resolve(args)


def cmd_refresh(args: argparse.Namespace) -> int:
    detected = detect()
    previous = read_capabilities()
    if previous and previous.get("fingerprint") != detected.get("fingerprint"):
        keys = ("gpu_vendors", "monitors", "has_internal_panel", "backlights", "batteries", "inputs", "audio", "openrgb", "openrgb_devices")
        changes = {key: {"before": previous.get(key), "after": detected.get(key)} for key in keys if previous.get(key) != detected.get(key)}
        print("Cambios detectados (host.toml no se modifica):\n" + json.dumps(changes, indent=2, ensure_ascii=False), file=sys.stderr)
        if not args.yes:
            if not sys.stdin.isatty():
                raise ValueError("El snapshot cambió; revisa el diff y repite con --yes")
            print("Escribe ACTUALIZAR para guardar el snapshot: ", end="", file=sys.stderr)
            if input().strip() != "ACTUALIZAR":
                return 1
    write_private(capabilities_path(), json.dumps(detected, indent=2, sort_keys=True) + "\n")
    args.capabilities = str(capabilities_path())
    return cmd_resolve(args)


def cmd_export(args: argparse.Namespace) -> int:
    host = load_toml(host_path(args.host_config))
    # Las elecciones son exportables; nunca incluimos datos detectados de hardware.
    if not SAFE_NAME.fullmatch(args.name):
        raise ValueError("Nombre de exportación inválido")
    lines = ["# Export saneado: sin pantallas, dispositivos, audio ni RGB", "schema = 1", "bundles = " + json.dumps(string_list(host.get("bundles"), "bundles"))]
    input_config = host.get("input", {})
    if not isinstance(input_config, dict):
        raise ValueError("input debe ser una tabla")
    layouts = input_config.get("keyboard_layouts", [])
    if layouts:
        if not isinstance(layouts, list) or not all(isinstance(item, str) and re.fullmatch(r"[a-z]{2}", item) for item in layouts):
            raise ValueError("input.keyboard_layouts inválido")
        lines.extend(["", "[input]", "keyboard_layouts = " + json.dumps(layouts)])
        for key in ("toggle_layouts", "local_dictation"):
            if key in input_config:
                if not isinstance(input_config[key], bool):
                    raise ValueError(f"input.{key} debe ser booleano")
                lines.append(f"{key} = {str(input_config[key]).lower()}")
    for section, allowed in (("touchpad", ("tap_to_click", "natural_scroll", "disable_while_typing")), ("gestures", ("workspace_swipe",))):
        values = input_config.get(section)
        if values is None:
            continue
        if not isinstance(values, dict):
            raise ValueError(f"input.{section} debe ser una tabla")
        exported = []
        for key in allowed:
            if key in values:
                if not isinstance(values[key], bool):
                    raise ValueError(f"input.{section}.{key} debe ser booleano")
                exported.append(f"{key} = {str(values[key]).lower()}")
        if section == "gestures" and values.get("workspace_swipe") is True:
            fingers = values.get("fingers", 4)
            if not isinstance(fingers, int) or isinstance(fingers, bool) or not 3 <= fingers <= 5:
                raise ValueError("input.gestures.fingers inválido")
            exported.append(f"fingers = {fingers}")
        if exported:
            lines.extend(["", f"[input.{section}]", *exported])
    contents = "\n".join(lines) + "\n"
    destination = state_root() / "exports" / (args.name + ".toml")
    write_private(destination, contents)
    print(destination)
    return 0


def migration_target(requested: str | None) -> Path:
    root = state_root() / "migrations"
    if requested:
        if "/" in requested or requested in (".", ".."):
            raise ValueError("Identificador de migración inválido")
        target = (root / requested).resolve()
    else:
        last = state_root() / "last-migration"
        if not last.is_file():
            raise ValueError("No existe una migración para restaurar")
        target = Path(last.read_text(encoding="utf-8").strip()).resolve()
    root_resolved = root.resolve()
    if target.parent != root_resolved or not (target / "plan.json").is_file() or not (target / "legacy-modules").is_file():
        raise ValueError("Migración fuera del directorio seguro o incompleta")
    return target


def verify_migration_checksums(target: Path) -> None:
    checksums = target / "SHA256SUMS"
    if not checksums.is_file():
        raise ValueError("La migración no tiene SHA256SUMS")
    for line in checksums.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})\s+\*?(.+)", line)
        if not match:
            raise ValueError("SHA256SUMS inválido")
        expected, relative = match.groups()
        candidate = (target / relative).resolve()
        if candidate != target and target not in candidate.parents or not candidate.is_file():
            raise ValueError("SHA256SUMS referencia una ruta insegura")
        actual = hashlib.sha256(candidate.read_bytes()).hexdigest()
        if actual != expected:
            raise ValueError(f"Checksum inválido: {relative}")


def rewrite_migration_checksums(target: Path) -> None:
    checksum_lines = []
    for path in sorted(item for item in target.rglob("*") if item.is_file() and not item.is_symlink() and item.name not in ("SHA256SUMS", "status")):
        checksum_lines.append(hashlib.sha256(path.read_bytes()).hexdigest() + "  " + str(path.relative_to(target)))
    write_private(target / "SHA256SUMS", "\n".join(checksum_lines) + "\n")


def fsync_path(path: Path) -> None:
    flags = os.O_RDONLY
    if path.is_dir():
        flags |= getattr(os, "O_DIRECTORY", 0)
    try:
        descriptor = os.open(path, flags)
    except OSError as error:
        raise ValueError(f"No se pudo abrir el checkpoint durable: {path}") from error
    try:
        os.fsync(descriptor)
    except OSError as error:
        raise ValueError(f"No se pudo sincronizar el checkpoint durable: {path}") from error
    finally:
        os.close(descriptor)


def persist_migration_checkpoint(target: Path) -> None:
    """Flush the newest journal and checksum before a Python-side mutation."""
    rewrite_migration_checksums(target)
    for path in sorted(item for item in target.rglob("*") if item.is_file() and not item.is_symlink()):
        fsync_path(path)
    fsync_path(target)
    fsync_path(target.parent)


def valid_link_relative(relative: str) -> bool:
    """Return true only for a normalized lexical descendant of HOME."""
    return (
        bool(relative)
        and not relative.startswith("/")
        and not relative.endswith("/")
        and "//" not in relative
        and "\x00" not in relative
        and "\n" not in relative
        and "\t" not in relative
        and all(part not in ("", ".", "..") for part in relative.split("/"))
    )


def read_link_manifest(path: Path, label: str) -> list[tuple[str, str]]:
    if not path.is_file():
        raise ValueError(f"Falta {label}; esta migración no tiene un rollback seguro")
    entries: list[tuple[str, str]] = []
    seen: set[str] = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) != 2:
            raise ValueError(f"{label} inválido")
        relative, link = parts
        if (not valid_link_relative(relative) or "\x00" in link or not link or relative in seen):
            raise ValueError(f"{label} inválido")
        seen.add(relative)
        entries.append((relative, link))
    return entries


def link_path(home: Path, relative: str) -> Path:
    if not valid_link_relative(relative):
        raise ValueError("Destino de enlace fuera de HOME")
    path = home / relative
    if home not in path.parents:
        raise ValueError("Destino de enlace fuera de HOME")
    return path


def preflight_remove_links(home: Path, entries: list[tuple[str, str]], *, allow_absent: bool = False) -> None:
    for relative, link in entries:
        destination = link_path(home, relative)
        if allow_absent and not destination.exists() and not destination.is_symlink():
            continue
        if not destination.is_symlink() or os.readlink(destination) != link:
            raise ValueError(f"El enlace gestionado cambió y no se puede retirar: {destination}")


def remove_links(home: Path, entries: list[tuple[str, str]], *, allow_absent: bool = False) -> None:
    for relative, expected in entries:
        destination = link_path(home, relative)
        if allow_absent and not destination.exists() and not destination.is_symlink():
            continue
        if not destination.is_symlink() or os.readlink(destination) != expected:
            raise ValueError(f"El enlace cambió durante la retirada: {destination}")
        destination.unlink()


def preflight_restore_links(home: Path, entries: list[tuple[str, str]], removable: set[Path]) -> None:
    for relative, _ in entries:
        destination = link_path(home, relative)
        if (destination.exists() or destination.is_symlink()) and destination not in removable:
            raise ValueError(f"Destino de enlace ocupado: {destination}")


def restore_links(home: Path, entries: list[tuple[str, str]]) -> None:
    for relative, link in entries:
        destination = link_path(home, relative)
        destination.parent.mkdir(parents=True, exist_ok=True)
        os.symlink(link, destination)


def write_restored_active_links(target: Path, previous: list[tuple[str, str]], legacy: list[tuple[str, str]], checkpoint: list[tuple[str, str]] | None = None) -> None:
    entries = [*previous, *legacy, *(checkpoint or [])]
    if len({relative for relative, _ in entries}) != len(entries):
        raise ValueError("Los enlaces restaurados se solapan")
    write_private(target / "restored-active-links.tsv", "".join(f"{relative}\t{link}\n" for relative, link in sorted(entries)))


def write_restored_snapshot_links(target: Path, previous: list[tuple[str, str]], legacy: list[tuple[str, str]], checkpoint: list[tuple[str, str]] | None = None) -> None:
    """Persist only private referents for a retry after this rollback.

    The active manifest can intentionally retain an unmodified legacy or
    previous link when failure happened before removal.  It must therefore not
    become the source for a later rollback; this separate manifest always uses
    the snapshots captured by the transaction.
    """
    entries = [*previous, *legacy, *(checkpoint or [])]
    if len({relative for relative, _ in entries}) != len(entries):
        raise ValueError("Los snapshots de enlaces restaurados se solapan")
    preflight_snapshot_links(entries)
    write_private(target / "restored-snapshot-links.tsv", "".join(f"{relative}\t{link}\n" for relative, link in sorted(entries)))


def preflight_snapshot_links(entries: list[tuple[str, str]]) -> None:
    migrations = (state_root() / "migrations").resolve()
    for _, referent in entries:
        snapshot = Path(referent).resolve()
        if migrations not in snapshot.parents or not snapshot.is_file():
            raise ValueError(f"El snapshot de enlace no es privado o falta: {referent}")


def read_stow_before(path: Path, intents: dict[str, str]) -> dict[str, tuple[str, str]]:
    if not path.is_file():
        raise ValueError("Falta stow-before.tsv; el checkpoint Stow no es recuperable")
    entries: dict[str, tuple[str, str]] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) != 3:
            raise ValueError("stow-before.tsv inválido")
        relative, kind, destination = parts
        if (not valid_link_relative(relative)
                or relative not in intents or relative in entries or kind not in ("absent", "link")):
            raise ValueError("stow-before.tsv inválido")
        if kind == "link" and not destination:
            raise ValueError("stow-before.tsv inválido")
        if "\x00" in destination:
            raise ValueError("stow-before.tsv inválido")
        if kind == "link" and destination != intents[relative]:
            # Only an exact lexical Stow link can be a pre-existing common
            # entry.  Treat an older/corrupt checkpoint that captured another
            # symlink as unsafe rather than promoting it to the live manifest.
            raise ValueError("stow-before.tsv contiene un enlace previo ajeno")
        entries[relative] = (kind, destination)
    if set(entries) != set(intents):
        raise ValueError("stow-before.tsv no cubre la intención Stow")
    return entries


def stow_checkpoint_actions(target: Path, home: Path) -> tuple[list[tuple[str, str]], list[tuple[str, str]]] | None:
    """Return exact owned-link removals and private pre-Stow restorations.

    The checkpoint is written and checksummed before the real Stow invocation.
    It therefore remains sufficient after a power cut even if applied-links.tsv
    was never finished.  An exact link that already existed before Stow is not
    an owned removal, while a changed source link is restored from its private
    referent rather than from the checkout.
    """
    checkpoint = target / "stow-checkpoint"
    format_marker = target / "stow-checkpoint-format"
    if not checkpoint.is_file():
        if format_marker.exists() or format_marker.is_symlink():
            if format_marker.is_symlink() or not format_marker.is_file() or format_marker.read_text(encoding="utf-8") != "v1\n":
                raise ValueError("El marcador de formato del checkpoint Stow no es válido")
            # The marker is written durably in begin_migration. Without the
            # later checkpoint, prepare_stow_checkpoint may have left a partial
            # applied-links.tsv, but the real Stow command was never reached.
            # Returning an empty authoritative checkpoint prevents the legacy
            # fallback from deleting a pre-existing common link.
            return [], []
        return None
    intents = dict(read_link_manifest(target / "stow-intent.tsv", "stow-intent.tsv"))
    before = read_stow_before(target / "stow-before.tsv", intents)
    snapshots = dict(read_link_manifest(target / "pre-stow-restore-links.tsv", "pre-stow-restore-links.tsv"))
    required_snapshots = {relative for relative, (kind, _) in before.items() if kind == "link"}
    if set(snapshots) != required_snapshots:
        raise ValueError("pre-stow-restore-links.tsv no cubre el estado previo Stow")
    preflight_snapshot_links(list(snapshots.items()))
    removals: list[tuple[str, str]] = []
    restorations: list[tuple[str, str]] = []
    for relative, expected in intents.items():
        kind, previous = before[relative]
        destination = link_path(home, relative)
        exists = destination.exists() or destination.is_symlink()
        current = os.readlink(destination) if destination.is_symlink() else None
        if kind == "absent":
            if current == expected:
                removals.append((relative, expected))
            elif exists:
                raise ValueError(f"No se retira un enlace/archivo ajeno de carrera: {destination}")
            continue
        if current == previous or (current == expected and previous == expected):
            continue
        if current == expected:
            removals.append((relative, expected))
            restorations.append((relative, snapshots[relative]))
        elif not exists:
            restorations.append((relative, snapshots[relative]))
        else:
            raise ValueError(f"No se sobrescribe un enlace/archivo ajeno de carrera: {destination}")
    return removals, restorations


def checkpoint_restored_entries(target: Path, home: Path) -> tuple[list[tuple[str, str]], list[tuple[str, str]]]:
    """Record active/recovery manifests for pre-existing links after rollback."""
    if not (target / "stow-checkpoint").is_file():
        return [], []
    intents = dict(read_link_manifest(target / "stow-intent.tsv", "stow-intent.tsv"))
    before = read_stow_before(target / "stow-before.tsv", intents)
    snapshots = dict(read_link_manifest(target / "pre-stow-restore-links.tsv", "pre-stow-restore-links.tsv"))
    active: list[tuple[str, str]] = []
    restored_snapshots: list[tuple[str, str]] = []
    for relative, (kind, previous) in before.items():
        if kind != "link":
            continue
        destination = link_path(home, relative)
        if not destination.is_symlink():
            raise ValueError(f"El enlace previo Stow no sobrevivió al rollback: {destination}")
        current = os.readlink(destination)
        snapshot = snapshots[relative]
        if current not in (previous, snapshot):
            raise ValueError(f"El enlace previo Stow cambió durante el rollback: {destination}")
        active.append((relative, current))
        restored_snapshots.append((relative, snapshot))
    return active, restored_snapshots


def removal_intent_actions(
    home: Path,
    live: list[tuple[str, str]],
    snapshots: list[tuple[str, str]],
    *,
    completed: bool,
    removable: set[Path] | None = None,
) -> list[tuple[str, str]]:
    """Return missing links to restore after a durable removal intent.

    The completion marker is only written after the all-or-nothing unlink
    loop.  Before it exists, an unmatched live target can be an edit that made
    the preflight fail, so preserve it and do not call it transaction-owned.
    """
    live_map = dict(live)
    snapshot_map = dict(snapshots)
    if set(live_map) != set(snapshot_map) or len(live_map) != len(live) or len(snapshot_map) != len(snapshots):
        raise ValueError("Los manifiestos de retirada no cubren la misma composición")
    preflight_snapshot_links(snapshots)
    removable = removable or set()
    restore: list[tuple[str, str]] = []
    for relative, expected in live:
        destination = link_path(home, relative)
        # A previous/legacy target can be occupied by an exact link from this
        # transaction.  ``stow_removals`` was preflighted separately and will
        # free it before restoration.  Treat it as a missing former link here;
        # otherwise the all-or-nothing rollback would reject normal module
        # replacement as though it were an unrelated race.
        if destination in removable:
            restore.append((relative, snapshot_map[relative]))
            continue
        exists = destination.exists() or destination.is_symlink()
        if not exists:
            restore.append((relative, snapshot_map[relative]))
            continue
        if destination.is_symlink() and os.readlink(destination) in (expected, snapshot_map[relative]):
            continue
        if completed:
            raise ValueError(f"No se sobrescribe un enlace/archivo ajeno durante el rollback: {destination}")
    return restore


def removal_active_entries(
    home: Path,
    live: list[tuple[str, str]],
    snapshots: list[tuple[str, str]],
    *,
    completed: bool,
) -> tuple[list[tuple[str, str]], list[tuple[str, str]]]:
    """Keep only known-live links and their private snapshot referents."""
    live_map = dict(live)
    snapshot_map = dict(snapshots)
    if set(live_map) != set(snapshot_map):
        raise ValueError("Los manifiestos de retirada no cubren la misma composición")
    active: list[tuple[str, str]] = []
    active_snapshots: list[tuple[str, str]] = []
    for relative, expected in live:
        destination = link_path(home, relative)
        if destination.is_symlink() and os.readlink(destination) in (expected, snapshot_map[relative]):
            active.append((relative, os.readlink(destination)))
            active_snapshots.append((relative, snapshot_map[relative]))
        elif completed:
            raise ValueError(f"El enlace retirado no se restauró: {destination}")
    return active, active_snapshots


def write_restored_active_generated(target: Path, generated: dict[str, tuple[Path, str]]) -> None:
    previous = target / "previous-generated-installed.tsv"
    if not previous.is_file():
        write_private(target / "restored-active-generated.tsv", "")
        return
    entries: list[str] = []
    for line in previous.read_text(encoding="utf-8").splitlines():
        key, digest = line.split("\t", 1)
        if key not in generated or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("previous-generated-installed.tsv inválido")
        destination = generated[key][0]
        if destination.is_file() and not destination.is_symlink() and hashlib.sha256(destination.read_bytes()).hexdigest() == digest:
            entries.append(f"{key}\t{digest}\n")
    write_private(target / "restored-active-generated.tsv", "".join(sorted(entries)))


def generated_entries(target: Path) -> tuple[dict[str, tuple[Path, str]], dict[str, str], dict[str, str], dict[str, str]]:
    generated: dict[str, tuple[Path, str]] = {
        "qmd": (xdg_path("XDG_CONFIG_HOME", "~/.config") / "qmd" / "index.yml", "qmd"),
        "rgb": (xdg_path("XDG_CONFIG_HOME", "~/.config") / "reactive-rgb" / "config.conf", "rgb"),
        "restic": (xdg_path("XDG_CONFIG_HOME", "~/.config") / "restic" / "repository", "restic"),
    }
    installed: dict[str, str] = {}
    installed_file = target / "generated-installed.tsv"
    if installed_file.is_file():
        for line in installed_file.read_text(encoding="utf-8").splitlines():
            key, digest = line.split("\t", 1)
            if key not in generated or not re.fullmatch(r"[0-9a-f]{64}", digest):
                raise ValueError("generated-installed.tsv inválido")
            installed[key] = digest
    previous: dict[str, str] = {}
    targets_file = target / "generated-targets.tsv"
    if targets_file.is_file():
        for line in targets_file.read_text(encoding="utf-8").splitlines():
            key, status = line.split("\t", 1)
            if key not in generated or status not in ("absent", "legacy", "copy"):
                raise ValueError("generated-targets.tsv inválido")
            previous[key] = status
    removed: dict[str, str] = {}
    removed_file = target / "generated-removed.tsv"
    if removed_file.is_file():
        for line in removed_file.read_text(encoding="utf-8").splitlines():
            key, digest = line.split("\t", 1)
            if key not in generated or not re.fullmatch(r"[0-9a-f]{64}", digest):
                raise ValueError("generated-removed.tsv inválido")
            removed[key] = digest
    return generated, installed, previous, removed


def preflight_generated(generated: dict[str, tuple[Path, str]], installed: dict[str, str], *, allow_absent: bool = False) -> list[str]:
    actions: list[str] = []
    config = xdg_path("XDG_CONFIG_HOME", "~/.config")
    for key, (destination, _) in generated.items():
        if key not in installed:
            continue
        if not destination.is_relative_to(config):
            raise ValueError("Destino generado fuera de XDG")
        if allow_absent and not destination.exists() and not destination.is_symlink():
            continue
        if not destination.is_file() or destination.is_symlink() or hashlib.sha256(destination.read_bytes()).hexdigest() != installed[key]:
            raise ValueError(f"El archivo generado cambió y no se puede restaurar: {destination}")
        actions.append(key)
    return actions


def generated_snapshot_matches(destination: Path, snapshot: Path) -> bool:
    if snapshot.is_symlink():
        return destination.is_symlink() and os.readlink(destination) == os.readlink(snapshot)
    return (
        snapshot.is_file()
        and not snapshot.is_symlink()
        and destination.is_file()
        and not destination.is_symlink()
        and hashlib.sha256(snapshot.read_bytes()).hexdigest() == hashlib.sha256(destination.read_bytes()).hexdigest()
    )


def rollback_generated_actions(
    target: Path,
    generated: dict[str, tuple[Path, str]],
    installed: dict[str, str],
    previous: dict[str, str],
    removed: dict[str, str],
) -> tuple[list[str], list[str]]:
    """Derive rollback actions from write-ahead generated journals.

    ``generated-installed.tsv`` and ``generated-removed.tsv`` are persisted
    before mv/rm.  A journal entry can therefore exist while the old file is
    still present.  Treat that preimage as a no-op, never as a foreign edit.
    """
    if set(installed) & set(removed):
        raise ValueError("Un generado no puede estar instalado y retirado en la misma transacción")
    remove_actions: list[str] = []
    restore_actions: list[str] = []
    for key, digest in installed.items():
        destination, backup_key = generated[key]
        prior = previous.get(key, "absent")
        snapshot = target / "generated-backups" / backup_key
        if destination.is_file() and not destination.is_symlink():
            actual = hashlib.sha256(destination.read_bytes()).hexdigest()
            if actual == digest:
                remove_actions.append(key)
            elif prior == "copy" and generated_snapshot_matches(destination, snapshot):
                pass
            else:
                raise ValueError(f"El archivo generado cambió y no se puede restaurar: {destination}")
        elif destination.is_symlink():
            if prior == "legacy" or (prior == "copy" and generated_snapshot_matches(destination, snapshot)):
                pass
            else:
                raise ValueError(f"El archivo generado cambió y no se puede restaurar: {destination}")
        elif destination.exists():
            raise ValueError(f"El archivo generado cambió y no se puede restaurar: {destination}")
    for key, digest in removed.items():
        destination, _ = generated[key]
        if destination.is_file() and not destination.is_symlink():
            if hashlib.sha256(destination.read_bytes()).hexdigest() != digest:
                raise ValueError(f"El archivo generado reapareció y no se puede restaurar: {destination}")
        elif destination.exists() or destination.is_symlink():
            raise ValueError(f"El archivo generado reapareció y no se puede restaurar: {destination}")
    for key in set(installed) | set(removed):
        if previous.get(key, "absent") != "copy":
            continue
        destination, backup_key = generated[key]
        snapshot = target / "generated-backups" / backup_key
        if not (snapshot.exists() or snapshot.is_symlink()):
            raise ValueError(f"Falta backup generado para {key}")
        if key in remove_actions or not (destination.exists() or destination.is_symlink()):
            restore_actions.append(key)
        elif not generated_snapshot_matches(destination, snapshot):
            raise ValueError(f"El archivo generado cambió y no se puede restaurar: {destination}")
    return remove_actions, restore_actions


def restore_generated_actions(
    target: Path,
    generated: dict[str, tuple[Path, str]],
    remove_actions: list[str],
    restore_actions: list[str],
) -> None:
    for key in remove_actions:
        generated[key][0].unlink()
    for key in restore_actions:
        destination, backup_key = generated[key]
        snapshot = target / "generated-backups" / backup_key
        destination.parent.mkdir(parents=True, exist_ok=True)
        if snapshot.is_symlink():
            os.symlink(os.readlink(snapshot), destination)
        else:
            shutil.copy2(snapshot, destination, follow_symlinks=False)


def restore_generated(target: Path, generated: dict[str, tuple[Path, str]], actions: list[str], previous: dict[str, str], removed: dict[str, str]) -> None:
    for key in actions:
        destination, backup_key = generated[key]
        prior = previous.get(key, "absent")
        destination.unlink()
        if prior == "copy":
            backup = target / "generated-backups" / backup_key
            if not backup.is_file():
                raise ValueError(f"Falta backup generado para {key}")
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(backup.read_bytes())
    for key in removed:
        destination, backup_key = generated[key]
        if destination.exists() or destination.is_symlink():
            raise ValueError(f"El archivo generado reapareció y no se puede restaurar: {destination}")
        if previous.get(key) == "copy":
            backup = target / "generated-backups" / backup_key
            if not backup.is_file():
                raise ValueError(f"Falta backup generado para {key}")
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(backup.read_bytes())


def backup_restore_moves(target: Path, home: Path, removable: set[Path]) -> list[tuple[Path, Path]]:
    manifest = target / "backup-dir"
    if not manifest.is_file():
        return []
    backup_dir = Path(manifest.read_text(encoding="utf-8").strip()).resolve()
    journal = target / "backup-moves.tsv"
    legacy_manifest = backup_dir / "manifest.txt"
    if state_root().resolve() not in backup_dir.parents or not (journal.is_file() or legacy_manifest.is_file()):
        raise ValueError("backup-dir inseguro")
    entries = journal if journal.is_file() else legacy_manifest
    moves: list[tuple[Path, Path]] = []
    for relative in entries.read_text(encoding="utf-8").splitlines():
        relative_path = Path(relative)
        if not relative or relative_path.is_absolute() or ".." in relative_path.parts:
            raise ValueError("Manifest de backup inseguro")
        destination = link_path(home, relative)
        source = backup_dir / relative
        if backup_dir not in source.parents:
            raise ValueError(f"Backup inseguro: {source}")
        if not (source.exists() or source.is_symlink()):
            # The write-ahead backup journal can survive a cut before mv.  Its
            # original target still exists and requires no rollback action.
            if destination.exists() or destination.is_symlink():
                continue
            raise ValueError(f"Falta backup: {source}")
        if (destination.exists() or destination.is_symlink()) and destination not in removable:
            raise ValueError(f"Destino de backup ocupado: {destination}")
        moves.append((source, destination))
    return moves


def restore_backup_moves(moves: list[tuple[Path, Path]]) -> None:
    for source, destination in moves:
        destination.parent.mkdir(parents=True, exist_ok=True)
        source.replace(destination)


def derived_state_roots() -> tuple[tuple[str, Path], ...]:
    root = state_root()
    return (("generated", root / "generated"), ("staged", root / "staged"), ("plans/resolved.json", root / "plans" / "resolved.json"))


def derived_fingerprint() -> str:
    root = state_root()
    lines: list[str] = []
    for relative, path in derived_state_roots():
        if path.is_symlink():
            lines.append(f"L\t{relative}\t{os.readlink(path)}")
        elif path.is_file():
            lines.append(f"F\t{relative}\t{hashlib.sha256(path.read_bytes()).hexdigest()}")
        elif path.is_dir():
            lines.append(f"D\t{relative}")
            for entry in sorted(path.rglob("*"), key=lambda item: str(item)):
                entry_relative = str(entry.relative_to(root))
                if entry.is_symlink():
                    lines.append(f"L\t{entry_relative}\t{os.readlink(entry)}")
                elif entry.is_file():
                    lines.append(f"F\t{entry_relative}\t{hashlib.sha256(entry.read_bytes()).hexdigest()}")
                elif entry.is_dir():
                    lines.append(f"D\t{entry_relative}")
        else:
            lines.append(f"A\t{relative}")
    return "\n".join(lines) + "\n"


def verify_derived_state(target: Path) -> bool:
    installed = target / "derived-installed.tsv"
    intent = target / "derived-mutation-intent"
    if not installed.is_file() or not installed.read_text(encoding="utf-8").strip():
        if intent.is_file():
            before = target / "derived-before.tsv"
            if not before.is_file() or before.read_text(encoding="utf-8") != derived_fingerprint():
                raise ValueError("El resolutor se interrumpió antes de registrar el estado derivado; no se sobrescribe")
        return False
    if installed.read_text(encoding="utf-8") != derived_fingerprint():
        raise ValueError("El estado derivado cambió y no se puede restaurar")
    return True


def restore_derived_state(target: Path) -> None:
    if not verify_derived_state(target):
        return
    for _, destination in derived_state_roots():
        if destination.is_dir() and not destination.is_symlink():
            shutil.rmtree(destination)
        else:
            destination.unlink(missing_ok=True)
    before = target / "derived-before"
    for relative, destination in derived_state_roots():
        source = before / relative
        if not source.exists() and not source.is_symlink():
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        if source.is_symlink():
            os.symlink(os.readlink(source), destination)
        elif source.is_dir():
            shutil.copytree(source, destination, symlinks=True)
        else:
            shutil.copy2(source, destination, follow_symlinks=False)


def cmd_rollback(args: argparse.Namespace) -> int:
    target = migration_target(args.id)
    verify_migration_checksums(target)
    plan = json.loads((target / "plan.json").read_text(encoding="utf-8"))
    modules = string_list(plan.get("modules"), "plan.modules")
    status = (target / "status").read_text(encoding="utf-8").strip() if (target / "status").is_file() else ""
    if status == "rolled-back":
        preview = {"migration": target.name, "already_rolled_back": True, "remove_modules": modules}
        if not args.apply:
            print(json.dumps(preview, indent=2))
        else:
            print(target)
        return 0
    home = Path.home().resolve()
    checkpoint = stow_checkpoint_actions(target, home)
    if checkpoint is None:
        applied = read_link_manifest(target / "applied-links.tsv", "applied-links.tsv")
        stow_removals = applied
        stow_restorations: list[tuple[str, str]] = []
    else:
        # applied-links is a live-composition manifest, not an ownership claim:
        # it can include an exact common link that existed before this Stow run.
        # The checkpoint above is authoritative after an interrupted Stow.
        applied = []
        stow_removals, stow_restorations = checkpoint
    # ``legacy-links.tsv`` and ``previous-restore-links.tsv`` contain private
    # snapshots used only when this transaction actually removed the former
    # composition.  Keep their corresponding live manifests separate: a
    # failure before that removal must leave the next apply responsible for the
    # links that are still live, not for snapshot paths that were never used.
    legacy = read_link_manifest(target / "legacy-links.tsv", "legacy-links.tsv")
    legacy_live_manifest = target / "symlinks.tsv"
    legacy_live = read_link_manifest(legacy_live_manifest, "symlinks.tsv") if legacy_live_manifest.is_file() else legacy
    previous = read_link_manifest(target / "previous-applied-links.tsv", "previous-applied-links.tsv")
    restore_manifest = target / "previous-restore-links.tsv"
    if previous and not restore_manifest.is_file():
        raise ValueError("Falta previous-restore-links.tsv; esta migración no tiene un rollback seguro")
    previous_restore = read_link_manifest(restore_manifest, "previous-restore-links.tsv") if restore_manifest.is_file() else []
    generated, installed, generated_previous, removed = generated_entries(target)
    allow_absent = status in ("retired", "retiring") or (target / "retire-intent").is_file()
    preflight_snapshot_links([*stow_restorations, *previous_restore, *legacy])
    if checkpoint is None:
        preflight_remove_links(home, stow_removals, allow_absent=allow_absent)
    generated_remove_actions, generated_restore_actions = rollback_generated_actions(
        target, generated, installed, generated_previous, removed
    )
    removable = {link_path(home, relative) for relative, _ in stow_removals}
    backup_moves = backup_restore_moves(target, home, removable)
    previous_was_removed = (target / "previous-links-removed").is_file()
    legacy_was_removed = (target / "legacy-links-removed").is_file()
    previous_removal_started = previous_was_removed or (target / "previous-links-removal-intent").is_file()
    legacy_removal_started = legacy_was_removed or (target / "legacy-links-removal-intent").is_file()
    # The intent is durable before any unlink.  A crash before the completion
    # marker can therefore leave only part of the former composition absent.
    # Restore just those known-missing entries; an unmatched target before
    # completion is preserved as a user/race change rather than overwritten.
    previous_restore_actions = (
        removal_intent_actions(
            home, previous, previous_restore, completed=previous_was_removed, removable=removable
        )
        if previous_removal_started
        else []
    )
    legacy_restore_actions = (
        removal_intent_actions(
            home, legacy_live, legacy, completed=legacy_was_removed, removable=removable
        )
        if legacy_removal_started
        else []
    )
    restore_relatives = [relative for relative, _ in [*stow_restorations, *previous_restore_actions, *legacy_restore_actions]]
    if len(restore_relatives) != len(set(restore_relatives)):
        raise ValueError("Los manifiestos de restauración se solapan; no se aplica un rollback parcial")
    verify_derived_state(target)
    preview = {
        "migration": target.name,
        "remove_modules": modules,
        "restore_modules": [relative for relative, _ in [*stow_restorations, *previous, *legacy_live]],
        "restore_generated": sorted(set(generated_remove_actions) | set(generated_restore_actions)),
    }
    if not args.apply:
        print(json.dumps(preview, indent=2))
        return 0
    remove_links(home, stow_removals, allow_absent=allow_absent)
    restore_generated_actions(target, generated, generated_remove_actions, generated_restore_actions)
    restore_backup_moves(backup_moves)
    restore_links(home, stow_restorations)
    restore_links(home, previous_restore_actions)
    restore_links(home, legacy_restore_actions)
    restore_derived_state(target)
    rgb_state = target / "rgb-state"
    if rgb_state.is_file() and shutil.which("systemctl"):
        desired = set(rgb_state.read_text(encoding="utf-8").splitlines())
        subprocess.run(["systemctl", "--user", "disable", "--now", "reactive-rgb.service"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if "enabled" in desired: subprocess.run(["systemctl", "--user", "enable", "reactive-rgb.service"], check=True)
        if "active" in desired: subprocess.run(["systemctl", "--user", "start", "reactive-rgb.service"], check=True)
    checkpoint_active, checkpoint_snapshots = checkpoint_restored_entries(target, home)
    if previous_removal_started:
        previous_active, previous_snapshots = removal_active_entries(
            home, previous, previous_restore, completed=previous_was_removed
        )
    else:
        previous_active, previous_snapshots = previous, previous_restore
    if legacy_removal_started:
        legacy_active, legacy_snapshots = removal_active_entries(
            home, legacy_live, legacy, completed=legacy_was_removed
        )
    else:
        legacy_active, legacy_snapshots = legacy_live, legacy
    write_restored_active_links(
        target,
        previous_active,
        legacy_active,
        checkpoint_active,
    )
    write_restored_snapshot_links(target, previous_snapshots, legacy_snapshots, checkpoint_snapshots)
    write_restored_active_generated(target, generated)
    write_private(target / "status", "rolled-back\n")
    persist_migration_checkpoint(target)
    print(target)
    return 0


def cmd_retire(args: argparse.Namespace) -> int:
    """Remove only the exact composition recorded by the last applied plan.

    This deliberately does not infer modules from current hardware: a monitor,
    GPU, or optional device disappearing must never broaden a removal.
    """
    target = migration_target(None)
    verify_migration_checksums(target)
    status = (target / "status").read_text(encoding="utf-8").strip() if (target / "status").is_file() else ""
    if status != "applied":
        raise ValueError("La última migración no está aplicada; no hay una composición activa que retirar")
    applied = read_link_manifest(target / "applied-links.tsv", "applied-links.tsv")
    generated, installed, _, _ = generated_entries(target)
    home = Path.home().resolve()
    preflight_remove_links(home, applied)
    generated_actions = preflight_generated(generated, installed)
    preview = {
        "migration": target.name,
        "remove_links": [relative for relative, _ in applied],
        "remove_generated": generated_actions,
        "scope": "Solo elimina enlaces Stow y generados registrados; conserva backups y paquetes.",
    }
    if not args.apply:
        print(json.dumps(preview, indent=2))
        return 0
    # The exact applied manifests already describe all removable targets.  Mark
    # this retirement durable before unlinking so an interrupted `just remove`
    # can be recovered by rollback with absent targets accepted.
    write_private(target / "retire-intent", "retiring\n")
    write_private(target / "status", "retiring\n")
    persist_migration_checkpoint(target)
    remove_links(home, applied)
    for key in generated_actions:
        destination = generated[key][0]
        if (not destination.is_file() or destination.is_symlink()
                or hashlib.sha256(destination.read_bytes()).hexdigest() != installed[key]):
            raise ValueError(f"El archivo generado cambió durante la retirada: {destination}")
        destination.unlink()
    if shutil.which("systemctl"):
        subprocess.run(["systemctl", "--user", "disable", "--now", "reactive-rgb.service"], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["systemctl", "--user", "daemon-reload"], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    write_private(target / "status", "retired\n")
    persist_migration_checkpoint(target)
    print(target)
    return 0


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(prog="dotf host")
    root.add_argument("--repo")
    commands = root.add_subparsers(dest="command", required=True)
    detect_parser = commands.add_parser("detect")
    detect_parser.add_argument("--write", action="store_true")
    detect_parser.set_defaults(handler=cmd_detect)
    configure = commands.add_parser("configure")
    configure.add_argument("--host-config")
    configure.add_argument("--bundle", action="append")
    configure.add_argument("--interactive", action="store_true")
    configure.set_defaults(handler=cmd_configure)
    for command in ("resolve", "show", "refresh"):
        item = commands.add_parser(command)
        item.add_argument("--host-config")
        item.add_argument("--capabilities")
        item.add_argument("--safe-defaults", action="store_true")
        item.add_argument("--write", action="store_true")
        if command == "refresh": item.add_argument("--yes", action="store_true")
        item.set_defaults(handler={"resolve": cmd_resolve, "show": cmd_show, "refresh": cmd_refresh}[command])
    export = commands.add_parser("export")
    export.add_argument("name")
    export.add_argument("--host-config")
    export.set_defaults(handler=cmd_export)
    rollback = commands.add_parser("rollback")
    rollback.add_argument("id", nargs="?")
    rollback.add_argument("--apply", action="store_true")
    rollback.set_defaults(handler=cmd_rollback)
    retire = commands.add_parser("retire")
    retire.add_argument("--apply", action="store_true")
    retire.set_defaults(handler=cmd_retire)
    return root


def main() -> int:
    try:
        args = parser().parse_args()
        return args.handler(args)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"dotf host: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
