#!/usr/bin/env python3
"""Hermetic regression tests for profileless composition."""
from __future__ import annotations

import argparse
import contextlib
import csv
import io
import json
import os
import subprocess
import hashlib
import importlib.util
import tempfile
import tomllib
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / "scripts" / "dotfiles_host.py"
SPEC = importlib.util.spec_from_file_location("dotfiles_host_under_test", TOOL)
assert SPEC and SPEC.loader
HOST_MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(HOST_MODULE)


class DotfilesHostTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls._original_path = os.environ.get("PATH", "")
        cls._fake_bin = tempfile.TemporaryDirectory()
        systemctl = Path(cls._fake_bin.name) / "systemctl"
        systemctl.write_text(
            """#!/usr/bin/env bash
set -euo pipefail
if [[ -n ${DOTFILES_TEST_SYSTEMCTL_LOG:-} ]]; then
    printf '%s\\n' "$*" >>"$DOTFILES_TEST_SYSTEMCTL_LOG"
fi
if [[ "$*" == '--user daemon-reload' && ${DOTFILES_TEST_SYSTEMCTL_FAIL_RELOAD:-0} == 1 ]]; then
    exit 1
fi
if [[ "$*" == '--user stop reactive-rgb.service' && -n ${DOTFILES_TEST_SYSTEMCTL_REPLACE_WANTS_ON_STOP:-} ]]; then
    rm -f -- "$DOTFILES_TEST_SYSTEMCTL_REPLACE_WANTS_ON_STOP"
    ln -s -- "$DOTFILES_TEST_SYSTEMCTL_REPLACEMENT_TARGET" "$DOTFILES_TEST_SYSTEMCTL_REPLACE_WANTS_ON_STOP"
fi
""",
            encoding="utf-8",
        )
        systemctl.chmod(0o755)
        os.environ["PATH"] = f"{cls._fake_bin.name}:{cls._original_path}"

    @classmethod
    def tearDownClass(cls) -> None:
        os.environ["PATH"] = cls._original_path
        cls._fake_bin.cleanup()

    def run_tool(self, *args: str, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
        runtime = os.environ.copy()
        runtime["PYTHONDONTWRITEBYTECODE"] = "1"
        if env:
            runtime.update(env)
        return subprocess.run(["python3", str(TOOL), "--repo", str(ROOT), *args], text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, env=runtime)

    def test_user_service_journal_and_foreign_enablement_are_guarded(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            migration = root / "migration"
            migration.mkdir()
            (migration / "user-services-format").write_text("v1\n", encoding="utf-8")
            self.assertFalse(HOST_MODULE.user_services_reconciliation_required(migration))
            (migration / "user-services-mutation-intent").write_text("", encoding="utf-8")
            self.assertTrue(HOST_MODULE.user_services_reconciliation_required(migration))
            (migration / "user-services-format").write_text("future\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "formato de estado"):
                HOST_MODULE.user_services_reconciliation_required(migration)

            legacy = root / "legacy"
            legacy.mkdir()
            (legacy / "rgb-state").write_text("active\n", encoding="utf-8")
            self.assertTrue(HOST_MODULE.user_services_reconciliation_required(legacy))

            home = root / "home"
            wants = home / ".config/systemd/user/default.target.wants/reactive-rgb.service"
            wants.parent.mkdir(parents=True)
            foreign = root / "foreign.service"
            foreign.write_text("foreign\n", encoding="utf-8")
            os.symlink(foreign, wants)
            with self.assertRaisesRegex(ValueError, "destino ajeno"):
                HOST_MODULE.validate_reactive_rgb_enablement(home, {root / "managed.service"})
            self.assertTrue(wants.is_symlink())
            self.assertEqual(wants.resolve(), foreign)

    def test_clear_reactive_rgb_revalidates_wants_after_stop_and_restarts_on_race(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            home = root / "home"
            wants = home / ".config/systemd/user/default.target.wants/reactive-rgb.service"
            wants.parent.mkdir(parents=True)
            managed = root / "managed.service"
            foreign = root / "foreign.service"
            managed.write_text("managed\n", encoding="utf-8")
            foreign.write_text("foreign\n", encoding="utf-8")
            os.symlink(managed, wants)
            enablement = HOST_MODULE.validate_reactive_rgb_enablement(home, {managed.resolve()})
            assert enablement is not None
            log = root / "systemctl.log"
            with mock.patch.dict(os.environ, {
                "DOTFILES_TEST_SYSTEMCTL_LOG": str(log),
                "DOTFILES_TEST_SYSTEMCTL_REPLACE_WANTS_ON_STOP": str(wants),
                "DOTFILES_TEST_SYSTEMCTL_REPLACEMENT_TARGET": str(foreign),
            }):
                with self.assertRaisesRegex(ValueError, "cambió durante la operación"):
                    HOST_MODULE.clear_reactive_rgb_service(enablement)
            self.assertTrue(wants.is_symlink())
            self.assertEqual(wants.resolve(), foreign.resolve())
            self.assertEqual(log.read_text(encoding="utf-8").splitlines(), [
                "--user is-active reactive-rgb.service",
                "--user stop reactive-rgb.service",
                "--user start reactive-rgb.service",
            ])

    def test_current_host_fixture_resolves_all_bundles_and_nvidia(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            host = root / "host.toml"
            host.write_text(
                'schema = 1\nbundles = ["gaming-core", "gaming-launchers", "gaming-tools", "backup", "rgb-openrgb", "local-ai", "productivity-extra"]\n\n[backup]\nrepository = "/tmp/restic-test"\n',
                encoding="utf-8",
            )
            caps = root / "caps.json"
            caps.write_text(json.dumps({"schema": 1, "gpu_vendors": ["nvidia"], "openrgb": True}), encoding="utf-8")
            plan = json.loads(self.run_tool("resolve", "--host-config", str(host), "--capabilities", str(caps)).stdout)
        self.assertEqual(plan["bundles"], ["gaming-core", "gaming-launchers", "gaming-tools", "backup", "rgb-openrgb", "local-ai", "productivity-extra"])
        self.assertIn("gpu-nvidia", plan["capabilities"])
        self.assertIn("productivity-extra", plan["modules"])
        self.assertEqual(set(plan["package_scopes"]), {"base", "bundle:gaming-core", "bundle:gaming-launchers", "bundle:gaming-tools", "bundle:backup", "bundle:rgb-openrgb", "bundle:local-ai", "bundle:productivity-extra"})
        self.assertEqual(plan["compatibility"]["packages"]["noctalia"]["minimum"], "5.0.0_beta.9")
        self.assertEqual(plan["compatibility"]["packages"]["noctalia"]["stable_minimum"], "5.0.0")
        self.assertEqual(plan["compatibility"]["packages"]["hyprland"]["minimum"], "0.56.2")
        self.assertEqual(plan["compatibility"]["packages"]["kanata-bin"]["minimum"], "1.12.0")

    def test_compatibility_rejects_malformed_or_unknown_stable_transition(self) -> None:
        valid = {
            "packages": {
                "noctalia": {
                    "minimum": "5.0.0_beta.9",
                    "stable_minimum": "5.0.0",
                    "source": "native",
                }
            }
        }
        self.assertEqual(
            HOST_MODULE.compatibility_requirements({"compatibility": valid}),
            {"noctalia": {"minimum": "5.0.0_beta.9", "stable_minimum": "5.0.0", "source": "native"}},
        )
        invalid = {"packages": {"noctalia": {"minimum": "5.0.0_beta.9", "stable_minimum": "bad version/", "source": "native"}}}
        with self.assertRaisesRegex(ValueError, "Mínimo estable inválido"):
            HOST_MODULE.compatibility_requirements({"compatibility": invalid})
        unknown = {"packages": {"noctalia": {"minimum": "5.0.0_beta.9", "stable_minimum": "5.0.0", "future": "x", "source": "native"}}}
        with self.assertRaisesRegex(ValueError, "Claves desconocidas"):
            HOST_MODULE.compatibility_requirements({"compatibility": unknown})

    def test_migrated_package_scopes_preserve_desktop_and_laptop_counts(self) -> None:
        with (ROOT / "packages.csv").open(encoding="utf-8", newline="") as stream:
            rows = list(csv.reader(stream))
        by_scope: dict[str, set[str]] = {}
        for scope, _category, package, _source in rows:
            by_scope.setdefault(scope, set()).add(package)
        self.assertEqual(len(by_scope["base"]), 120)
        self.assertEqual(len({package for packages in by_scope.values() for package in packages}), 143)
        self.assertIn("bat", by_scope["base"])
        self.assertIn("npm", by_scope["base"])
        self.assertEqual(len(by_scope["bundle:gaming-core"]), 6)
        self.assertEqual(len(by_scope["bundle:gaming-launchers"]), 4)
        self.assertEqual(len(by_scope["bundle:gaming-tools"]), 2)
        self.assertEqual(len(by_scope["bundle:backup"]), 2)
        self.assertEqual(len(by_scope["bundle:rgb-openrgb"]), 2)
        self.assertEqual(len(by_scope["bundle:local-ai"]), 4)
        self.assertIn("wtype", by_scope["bundle:local-ai"])
        self.assertEqual(len(by_scope["bundle:productivity-extra"]), 3)

    def test_old_laptop_and_future_amd_are_base_only(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            host = root / "host.toml"
            host.write_text("schema = 1\nbundles = []\n", encoding="utf-8")
            for vendor in ("intel", "amd"):
                caps = root / f"{vendor}.json"
                caps.write_text(json.dumps({"schema": 1, "gpu_vendors": [vendor]}), encoding="utf-8")
                plan = json.loads(self.run_tool("resolve", "--host-config", str(host), "--capabilities", str(caps)).stdout)
                self.assertNotIn("gpu-nvidia", plan["capabilities"])
                self.assertEqual(plan["package_scopes"], ["base"])

    def test_generated_files_are_xdg_private_and_lua_is_executable(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config, state = root / "other-user" / "config", root / "other-user" / "state"
            host = root / "host.toml"
            host.write_text('''schema = 1
bundles = []
[hardware]
[[hardware.displays]]
name = "HDMI-A-1"
mode = "1920x1080@74.97"
position = "0x0"
scale = 1
vrr = false
[input]
keyboard_layouts = ["us", "es"]
toggle_layouts = true
local_dictation = true
[[input.devices]]
name = "Logitech M720"
accel_profile = "flat"
[workspaces]
left = "HDMI-A-1"
right = "HDMI-A-2"
split_after = 4
[audio]
cycle = true
ensure_on_start = true
''', encoding="utf-8")
            caps = root / "caps.json"
            caps.write_text('{"schema": 1, "gpu_vendors": [], "has_internal_panel": true, "backlights": ["intel_backlight"]}', encoding="utf-8")
            self.run_tool("resolve", "--host-config", str(host), "--capabilities", str(caps), "--write", env={"XDG_CONFIG_HOME": str(config), "XDG_STATE_HOME": str(state), "HOME": str(root / "other-home")})
            generated = state / "dotfiles" / "generated" / "hypr" / "config"
            monitors = (generated / "monitors.lua").read_text(encoding="utf-8")
            binds = (generated / "hardware-binds.lua").read_text(encoding="utf-8")
            self.assertIn("hl.monitor({ output", monitors)
            self.assertIn("ensure-configured-audio", monitors)
            self.assertNotIn("CONTROL + ALT + SUPER + SHIFT + H", binds)
            self.assertIn(
                'hl.dsp.exec_cmd("cycle-desktop-audio-output")',
                (ROOT / "hypr-common/.config/hypr/config/user-binds.lua").read_text(encoding="utf-8"),
            )
            self.assertEqual((generated / "inputs.lua").stat().st_mode & 0o777, 0o600)

    def test_current_fixture_stages_audio_and_rgb_without_overwriting_xdg(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config, state = root / "config", root / "state"
            caps = root / "caps.json"
            caps.write_text(json.dumps({"schema": 1, "gpu_vendors": ["nvidia"], "openrgb": True}), encoding="utf-8")
            self.run_tool("resolve", "--host-config", str(ROOT / "scripts/tests/fixtures/current-host.toml"), "--capabilities", str(caps), "--write", env={"XDG_CONFIG_HOME": str(config), "XDG_STATE_HOME": str(state)})
            audio = (state / "dotfiles/generated/audio.conf").read_text(encoding="utf-8")
            rgb = (state / "dotfiles/staged/reactive-rgb/config.conf").read_text(encoding="utf-8")
            repository = (state / "dotfiles/staged/restic/repository").read_text(encoding="utf-8")
            self.assertIn("DOTFILES_AUDIO_BASE_PROFILE=output:hdmi-stereo", audio)
            self.assertIn("REACTIVE_RGB_NZXT_DEVICE=NZXT Smart Device V2", rgb)
            self.assertNotIn("REACTIVE_RGB_REAPPLY_INTERVAL", rgb)
            self.assertEqual(repository, "/mnt/backups/restic-desktop\n")
            self.assertFalse((config / "reactive-rgb/config.conf").exists())
            monitors = (state / "dotfiles/generated/hypr/config/monitors.lua").read_text(encoding="utf-8")
            inputs = (state / "dotfiles/generated/hypr/config/inputs.lua").read_text(encoding="utf-8")
            user_inputs = (state / "dotfiles/generated/hypr/config/user-inputs.lua").read_text(encoding="utf-8")
            self.assertIn('output = "HDMI-A-1", mode = "1920x1080@74.97", position = "0x0", scale = "1"', monitors)
            self.assertIn('output = "HDMI-A-2", mode = "1920x1080@74.97", position = "1920x0", scale = "1"', monitors)
            self.assertIn('name = "logitech-m720-triathlon-multi-device-mouse-1", accel_profile = "flat"', inputs)
            self.assertIn('kb_layout = "us,es"', user_inputs)
            self.assertIn('HYPR_BIND("SUPER + Space"', user_inputs)
            self.assertIn('HYPR_BIND("CONTROL + ALT + SUPER + SHIFT + R"', user_inputs)
            self.assertIn("MUSIC_WORKSPACE = 3", user_inputs)
            self.assertIn("SCROLLING_WORKSPACE = 6", user_inputs)
            self.assertIn('[1] = ""', user_inputs)

    def test_detection_keeps_openrgb_names_but_not_serial_metadata(self) -> None:
        outputs = {
            ("lspci", "-nn"): "",
            ("hyprctl", "monitors", "-j"): "[]",
            ("pactl", "-f", "json", "list", "sinks"): "[]",
            ("pactl", "-f", "json", "list", "cards"): "[]",
            ("wpctl", "status", "-n"): "Audio\n ├─ Sinks:\n │  * 42. Built-in Audio [vol: 0.50]\n",
            ("openrgb", "--noautoconnect", "--list-devices"): "0: Mainboard RGB\n  Serial: SECRET-123\n  Type: Motherboard\n1: NZXT Smart Device V2\n",
        }

        def fake_output(*args: str, timeout: float = 3.0) -> str:
            del timeout
            return outputs.get(tuple(args), "")

        with mock.patch.object(HOST_MODULE, "command_output", side_effect=fake_output):
            detected = HOST_MODULE.detect()
        self.assertEqual(detected["openrgb_devices"], ["Mainboard RGB", "NZXT Smart Device V2"])
        self.assertNotIn("SECRET-123", json.dumps(detected))
        self.assertIn("Built-in Audio", detected["audio"]["sinks"])

    def test_detection_isolates_clients_that_write_xdg_state(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            fake_bin = root / "bin"
            fake_bin.mkdir()
            writer = fake_bin / "openrgb"
            writer.write_text(
                "#!/usr/bin/env bash\n"
                "set -euo pipefail\n"
                "mkdir -p \"$HOME/.config/OpenRGB\" \"$XDG_CACHE_HOME/openrgb\"\n"
                "printf 'cache\\n' >\"$HOME/.config/OpenRGB/detected\"\n"
                "printf '0: Test RGB Device\\n'\n",
                encoding="utf-8",
            )
            writer.chmod(0o755)
            pactl = fake_bin / "pactl"
            pactl.write_text(
                "#!/usr/bin/env bash\n"
                "set -euo pipefail\n"
                "mkdir -p \"$HOME/.config/pulse\"\n"
                "printf 'cookie\\n' >\"$HOME/.config/pulse/cookie\"\n"
                "printf '[]\\n'\n",
                encoding="utf-8",
            )
            pactl.chmod(0o755)
            caller_home = root / "caller-home"
            caller_config = caller_home / ".config"
            result = self.run_tool(
                "detect",
                env={
                    "HOME": str(caller_home),
                    "XDG_CONFIG_HOME": str(caller_config),
                    "XDG_CACHE_HOME": str(caller_home / ".cache"),
                    "XDG_DATA_HOME": str(caller_home / ".local/share"),
                    "XDG_STATE_HOME": str(caller_home / ".local/state"),
                    "PATH": f"{fake_bin}:{os.environ['PATH']}",
                },
            )
            detected = json.loads(result.stdout)
            self.assertIn("Test RGB Device", detected["openrgb_devices"])
            self.assertFalse(caller_home.exists(), "detect no debe crear HOME/XDG del llamador")

    def test_detection_identifies_intel_without_matching_compatible_as_ati(self) -> None:
        outputs = {
            ("lspci", "-nn"): "00:02.0 VGA compatible controller [0300]: Intel Corporation UHD Graphics 620 [8086:5917] (rev 07)\n",
        }

        def fake_output(*args: str, timeout: float = 3.0) -> str:
            del timeout
            return outputs.get(tuple(args), "")

        with mock.patch.object(HOST_MODULE, "command_output", side_effect=fake_output):
            detected = HOST_MODULE.detect()
        self.assertEqual(detected["gpu_vendors"], ["intel"])

    def test_detection_identifies_mixed_gpu_vendors(self) -> None:
        cases = {
            "intel-nvidia": (
                "00:02.0 VGA compatible controller [0300]: Intel Corporation Iris Xe Graphics [8086:9a49] (rev 01)\n"
                "01:00.0 3D controller [0302]: NVIDIA Corporation GA107M [GeForce RTX 3050 Mobile] [10de:25a2] (rev a1)\n",
                ["intel", "nvidia"],
            ),
            "amd-nvidia": (
                "03:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Rembrandt [Radeon 680M] [1002:1681] (rev c9)\n"
                "04:00.0 3D controller [0302]: NVIDIA Corporation AD107M [GeForce RTX 4060 Max-Q / Mobile] [10de:28a0] (rev a1)\n",
                ["amd", "nvidia"],
            ),
            "intel-amd": (
                "00:02.0 VGA compatible controller [0300]: Intel Corporation UHD Graphics 630 [8086:3e92] (rev 02)\n"
                "01:00.0 Display controller [0380]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 23 [Radeon RX 6600M] [1002:73ff] (rev c1)\n",
                ["amd", "intel"],
            ),
            "numeric-ids-ignore-localized-names": (
                "00:02.0 Controlador gráfico localizado [0301]: Fabricante desconocido [8086:46a6] (rev 0c)\n",
                ["intel"],
            ),
            "unknown": (
                "02:00.0 Display controller [0380]: Example Vendor Example GPU [1234:5678] (rev 01)\n",
                ["unknown"],
            ),
        }

        for name, (lspci, vendors) in cases.items():
            with self.subTest(name=name), mock.patch.object(
                HOST_MODULE,
                "command_output",
                side_effect=lambda *args, timeout=3.0: lspci if args == ("lspci", "-nn") else "",
            ):
                detected = HOST_MODULE.detect()
                self.assertEqual(detected["gpu_vendors"], vendors)
                plan = HOST_MODULE.resolve(ROOT, {"schema": 1, "bundles": []}, detected, True)
                expected_capabilities = ["gpu-nvidia"] if "nvidia" in vendors else []
                self.assertEqual(plan["capabilities"], expected_capabilities)
                self.assertEqual(plan["modules"].count("gpu-nvidia"), len(expected_capabilities))

    def test_invalid_rgb_limits_are_rejected_before_staging(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            host = root / "host.toml"
            host.write_text(
                (ROOT / "scripts/tests/fixtures/current-host.toml").read_text(encoding="utf-8").replace(
                    "cpu_led_count = 12", "cpu_led_count = 60"
                ),
                encoding="utf-8",
            )
            caps = root / "caps.json"
            caps.write_text('{"schema": 1, "gpu_vendors": ["nvidia"]}', encoding="utf-8")
            runtime = os.environ.copy()
            runtime.update({"XDG_STATE_HOME": str(root / "state"), "XDG_CONFIG_HOME": str(root / "config")})
            result = subprocess.run(
                ["python3", str(TOOL), "--repo", str(ROOT), "resolve", "--host-config", str(host), "--capabilities", str(caps), "--write"],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=runtime,
                check=False,
            )
            self.assertEqual(result.returncode, 2)
            self.assertIn("cpu_led_count", result.stderr)
            self.assertFalse((root / "state/dotfiles/staged/reactive-rgb/config.conf").exists())

    def test_read_only_resolve_rejects_invalid_rendered_preferences(self) -> None:
        invalid_hosts = {
            "monitor": '''schema = 1
bundles = []
[hardware]
[[hardware.displays]]
name = "eDP-1"
scale = 9
''',
            "layout": '''schema = 1
bundles = []
[input]
keyboard_layouts = ["english"]
''',
            "audio": '''schema = 1
bundles = []
[audio]
cycle = "yes"
''',
            "rgb": '''schema = 1
bundles = ["rgb-openrgb"]
[rgb]
enabled = true
''',
            "backup": '''schema = 1
bundles = ["backup"]
''',
            "unknown": '''schema = 1
bundles = []
[input]
keyboard_layouts = ["us"]
keybord_layouts = ["es"]
''',
        }
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            caps = root / "caps.json"
            caps.write_text('{"schema": 1, "gpu_vendors": []}', encoding="utf-8")
            for name, contents in invalid_hosts.items():
                with self.subTest(name=name):
                    host = root / f"{name}.toml"
                    host.write_text(contents, encoding="utf-8")
                    result = subprocess.run(
                        ["python3", str(TOOL), "--repo", str(ROOT), "resolve", "--host-config", str(host), "--capabilities", str(caps)],
                        text=True,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        env={**os.environ, "XDG_STATE_HOME": str(root / "state"), "XDG_CONFIG_HOME": str(root / "config")},
                        check=False,
                    )
                    self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertFalse((root / "state/dotfiles").exists())

    def test_qmd_paths_are_yaml_quoted_and_export_omits_hardware(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state, config = root / "state", root / "config"
            caps = root / "caps.json"
            caps.write_text('{"schema": 1, "gpu_vendors": []}', encoding="utf-8")
            env = {
                "XDG_STATE_HOME": str(state),
                "XDG_CONFIG_HOME": str(config),
                "PROJECT_ATLAS_ROOT": str(root / "Atlas # local"),
            }
            self.run_tool(
                "resolve", "--host-config", str(ROOT / "scripts/tests/fixtures/current-host.toml"),
                "--capabilities", str(caps), "--write", env=env,
            )
            qmd = (state / "dotfiles/staged/qmd/index.yml").read_text(encoding="utf-8")
            expected_atlas_path = json.dumps(str(root / "Atlas # local" / "docs"))
            self.assertIn(f"path: {expected_atlas_path}", qmd)
            exported_path = Path(self.run_tool(
                "export", "portable", "--host-config", str(ROOT / "scripts/tests/fixtures/current-host.toml"), env=env,
            ).stdout.strip())
            exported = exported_path.read_text(encoding="utf-8")
            self.assertIn('keyboard_layouts = ["us", "es"]', exported)
            for private_value in ("HDMI-A-1", "alsa_card", "ASUS TUF", "Logitech", "/mnt/backups/restic-desktop"):
                self.assertNotIn(private_value, exported)

    def test_laptop_touchpad_gesture_uses_lua_underscore_keys(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            caps = root / "caps.json"
            caps.write_text('{"schema": 1, "gpu_vendors": ["intel", "nvidia"], "has_internal_panel": true, "backlights": ["intel_backlight"]}', encoding="utf-8")
            plan = json.loads(self.run_tool("resolve", "--host-config", str(ROOT / "scripts/tests/fixtures/laptop-host.toml"), "--capabilities", str(caps), "--write", env={"XDG_STATE_HOME": str(root / "state"), "XDG_CONFIG_HOME": str(root / "config")}).stdout)
            self.assertIn("gpu-nvidia", plan["modules"])
            inputs = (root / "state/dotfiles/generated/hypr/config/inputs.lua").read_text(encoding="utf-8")
            monitors = (root / "state/dotfiles/generated/hypr/config/monitors.lua").read_text(encoding="utf-8")
            self.assertIn("tap_to_click = true", inputs)
            self.assertIn('hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })', inputs)
            self.assertIn('name = "syna7db5:01-06cb:7db7-touchpad"', inputs)
            self.assertLess(monitors.index('output = ""'), monitors.index('output = "eDP-1"'))
            binds = (root / "state/dotfiles/generated/hypr/config/hardware-binds.lua").read_text(encoding="utf-8")
            self.assertIn("XF86MonBrightnessUp", binds)
            self.assertIn("XF86MonBrightnessDown", binds)

    def test_noctalia_overrides_are_local_validated_and_staged(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            host = root / "host.toml"
            host.write_text(
                """schema = 1
bundles = []

[noctalia.location]
auto_locate = false
latitude = 12.345678912345
longitude = -34.5
custom_schedule = true
sunrise = "06:15"
sunset = "21:45"

[noctalia.screen_recorder]
resolution = "2560x1440"
frame_rate = 75
""",
                encoding="utf-8",
            )
            caps = root / "caps.json"
            caps.write_text('{"schema": 1}', encoding="utf-8")
            state, config = root / "state", root / "config"
            plan = json.loads(self.run_tool(
                "resolve", "--host-config", str(host), "--capabilities", str(caps), "--write",
                env={"XDG_STATE_HOME": str(state), "XDG_CONFIG_HOME": str(config)},
            ).stdout)
            self.assertTrue(plan["noctalia_configured"])
            staged = (state / "dotfiles/staged/noctalia/zz-host-overrides.toml").read_text(encoding="utf-8")
            self.assertIn("auto_locate = false", staged)
            self.assertIn("resolution = \"2560x1440\"", staged)
            self.assertEqual(tomllib.loads(staged)["location"]["latitude"], 12.345678912345)
            invalid = host.read_text(encoding="utf-8").replace('sunrise = "06:15"', 'sunrise = "25:00"')
            host.write_text(invalid, encoding="utf-8")
            runtime = os.environ.copy()
            runtime.update({"XDG_STATE_HOME": str(state), "XDG_CONFIG_HOME": str(config), "PYTHONDONTWRITEBYTECODE": "1"})
            result = subprocess.run(
                ["python3", str(TOOL), "--repo", str(ROOT), "resolve", "--host-config", str(host), "--capabilities", str(caps)],
                text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=runtime, check=False,
            )
            self.assertEqual(result.returncode, 2)
            self.assertIn("noctalia.location.sunrise", result.stderr)

    def test_noctalia_safe_defaults_are_valid_without_host_coordinates(self) -> None:
        plan = HOST_MODULE.resolve(ROOT, {}, {"schema": 1}, safe_defaults=True)
        self.assertFalse(plan["noctalia_configured"])
        self.assertFalse(plan["noctalia"]["location"]["auto_locate"])
        self.assertIsNone(HOST_MODULE.rendered_artifacts(plan)["noctalia"])

    def test_configure_round_trips_existing_host_without_erasing_preferences(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            host = root / "host.toml"
            host.write_bytes((ROOT / "scripts/tests/fixtures/current-host.toml").read_bytes())
            original = tomllib.loads(host.read_text(encoding="utf-8"))
            detected = {
                "schema": 1,
                "gpu_vendors": ["nvidia"],
                "monitors": [{"name": "HDMI-A-1"}, {"name": "HDMI-A-2"}],
                "inputs": [],
                "backlights": [],
            }
            args = argparse.Namespace(repo=str(ROOT), host_config=str(host), bundle=None, interactive=False)
            environment = {"XDG_CONFIG_HOME": str(root / "config"), "XDG_STATE_HOME": str(root / "state")}
            with mock.patch.object(HOST_MODULE, "detect", return_value=detected), mock.patch.dict(os.environ, environment):
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(HOST_MODULE.cmd_configure(args), 0)
            restored = tomllib.loads(host.read_text(encoding="utf-8"))
            self.assertEqual(restored, original)
            self.assertEqual(restored["audio"]["default_sink"], "alsa_output.pci-0000_07_00.1.hdmi-stereo-extra1")
            self.assertEqual(restored["rgb"]["nzxt_device"], "NZXT Smart Device V2")
            self.assertEqual(restored["workspaces"]["split_after"], 4)

    def test_configure_enables_only_portable_defaults_implied_by_choices(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            host = root / "host.toml"
            host.write_text(
                'schema = 1\nbundles = ["local-ai"]\n[input]\nkeyboard_layouts = ["us", "es"]\n',
                encoding="utf-8",
            )
            detected = {"schema": 1, "gpu_vendors": [], "monitors": [], "inputs": [], "backlights": []}
            args = argparse.Namespace(repo=str(ROOT), host_config=str(host), bundle=None, interactive=False)
            environment = {"XDG_CONFIG_HOME": str(root / "config"), "XDG_STATE_HOME": str(root / "state")}
            with mock.patch.object(HOST_MODULE, "detect", return_value=detected), mock.patch.dict(os.environ, environment):
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(HOST_MODULE.cmd_configure(args), 0)
            configured = tomllib.loads(host.read_text(encoding="utf-8"))
            self.assertTrue(configured["input"]["toggle_layouts"])
            self.assertTrue(configured["input"]["local_dictation"])

    def test_interactive_configure_accepts_base_and_warns_when_displays_are_not_visible(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            host = root / "host.toml"
            host.write_text(
                'schema = 1\nbundles = ["gaming-core"]\n\n[input]\nkeyboard_layouts = ["us"]\n',
                encoding="utf-8",
            )
            args = argparse.Namespace(repo=str(ROOT), host_config=str(host), bundle=None, interactive=False)
            detected = {"schema": 1, "gpu_vendors": [], "inputs": [], "monitors": []}
            stderr = io.StringIO()
            with mock.patch.object(HOST_MODULE, "detect", return_value=detected), \
                    mock.patch.object(HOST_MODULE.sys.stdin, "isatty", return_value=True), \
                    mock.patch("builtins.input", side_effect=["base", "", "", "", "", "", "", ""]), \
                    mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(root / "config"), "XDG_STATE_HOME": str(root / "state")}), \
                    contextlib.redirect_stderr(stderr), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(HOST_MODULE.cmd_configure(args), 0)
            configured = tomllib.loads(host.read_text(encoding="utf-8"))
            self.assertEqual(configured["bundles"], [])
            self.assertFalse(configured["noctalia"]["location"]["auto_locate"])
            self.assertIn("Hyprland no ha devuelto pantallas", stderr.getvalue())

    def test_interactive_configure_records_noctalia_preferences_outside_git(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            host = root / "host.toml"
            host.write_text('schema = 1\nbundles = []\n\n[input]\nkeyboard_layouts = ["us"]\n', encoding="utf-8")
            args = argparse.Namespace(repo=str(ROOT), host_config=str(host), bundle=None, interactive=False)
            detected = {"schema": 1, "gpu_vendors": [], "inputs": [], "monitors": []}
            answers = ["", "", "n", "12.345678912345", "-45.678912345678", "s", "06:10", "21:50", "2560x1440", "120"]
            with mock.patch.object(HOST_MODULE, "detect", return_value=detected), \
                    mock.patch.object(HOST_MODULE.sys.stdin, "isatty", return_value=True), \
                    mock.patch("builtins.input", side_effect=answers), \
                    mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(root / "config"), "XDG_STATE_HOME": str(root / "state")}), \
                    contextlib.redirect_stderr(io.StringIO()), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(HOST_MODULE.cmd_configure(args), 0)
            configured = tomllib.loads(host.read_text(encoding="utf-8"))
            self.assertEqual(configured["noctalia"]["location"]["latitude"], 12.345678912345)
            self.assertEqual(configured["noctalia"]["screen_recorder"], {"resolution": "2560x1440", "frame_rate": 120})

    def test_noninteractive_configure_refuses_backup_without_repository(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            host = root / "host.toml"
            original = 'schema = 1\nbundles = ["backup"]\n'
            host.write_text(original, encoding="utf-8")
            detected = {"schema": 1, "gpu_vendors": [], "monitors": [], "inputs": [], "backlights": []}
            args = argparse.Namespace(repo=str(ROOT), host_config=str(host), bundle=None, interactive=False)
            environment = {"XDG_CONFIG_HOME": str(root / "config"), "XDG_STATE_HOME": str(root / "state")}
            with mock.patch.object(HOST_MODULE, "detect", return_value=detected), mock.patch.dict(os.environ, environment):
                with self.assertRaisesRegex(ValueError, "backup.repository"):
                    HOST_MODULE.cmd_configure(args)
            self.assertEqual(host.read_text(encoding="utf-8"), original)

    def test_rollback_is_preview_by_default_and_accepts_empty_legacy(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state = root / "state"
            migration = state / "dotfiles/migrations/deployment-test"
            migration.mkdir(parents=True)
            plan = migration / "plan.json"
            plan.write_text(json.dumps({"repo": str(ROOT), "modules": ["hypr-host"]}), encoding="utf-8")
            (migration / "legacy-modules").write_text("", encoding="utf-8")
            (migration / "applied-links.tsv").write_text("", encoding="utf-8")
            (migration / "legacy-links.tsv").write_text("", encoding="utf-8")
            (migration / "previous-applied-links.tsv").write_text("", encoding="utf-8")
            digest = hashlib.sha256(plan.read_bytes()).hexdigest()
            (migration / "SHA256SUMS").write_text(f"{digest}  plan.json\n", encoding="utf-8")
            output = self.run_tool("rollback", "deployment-test", env={"XDG_STATE_HOME": str(state)}).stdout
            preview = json.loads(output)
            self.assertEqual(preview["restore_modules"], [])
            self.assertEqual(preview["remove_modules"], ["hypr-host"])

    def test_manual_rollback_uses_recorded_links_not_checkout_or_stow(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state, home = root / "state", root / "home"
            destination = root / "config/qmd/index.yml"
            destination.parent.mkdir(parents=True)
            destination.write_text("generated", encoding="utf-8")
            migration = state / "dotfiles/migrations/deployment-order"
            legacy_source = migration / "modules/legacy/.config/legacy.conf"
            legacy_source.parent.mkdir(parents=True)
            legacy_source.write_text("old", encoding="utf-8")
            legacy_unit = migration / "modules/legacy/.config/systemd/user/reactive-rgb.service"
            legacy_unit.parent.mkdir(parents=True)
            legacy_unit.write_text("[Service]\nExecStart=/old\n", encoding="utf-8")
            plan = migration / "plan.json"
            plan.write_text(json.dumps({"repo": str(root / "checkout-gone"), "modules": ["hypr-host"]}), encoding="utf-8")
            (migration / "legacy-modules").write_text("legacy\n", encoding="utf-8")
            (migration / "applied-links.tsv").write_text(
                ".config/current.conf\t/current/checkouts/new.conf\n"
                ".config/systemd/user/reactive-rgb.service\t/current/checkouts/reactive-rgb.service\n",
                encoding="utf-8",
            )
            (migration / "previous-applied-links.tsv").write_text("", encoding="utf-8")
            (migration / "legacy-links.tsv").write_text(
                f".config/legacy.conf\t{legacy_source}\n"
                f".config/systemd/user/reactive-rgb.service\t{legacy_unit}\n",
                encoding="utf-8",
            )
            (migration / "legacy-links-removed").write_text("yes\n", encoding="utf-8")
            (migration / "rgb-state").write_text("enabled\nactive\n", encoding="utf-8")
            (migration / "generated-targets.tsv").write_text("qmd\tlegacy\n", encoding="utf-8")
            digest = hashlib.sha256(destination.read_bytes()).hexdigest()
            (migration / "generated-installed.tsv").write_text(f"qmd\t{digest}\n", encoding="utf-8")
            current = home / ".config/current.conf"
            current.parent.mkdir(parents=True)
            os.symlink("/current/checkouts/new.conf", current)
            current_unit = home / ".config/systemd/user/reactive-rgb.service"
            current_unit.parent.mkdir(parents=True)
            os.symlink("/current/checkouts/reactive-rgb.service", current_unit)
            current_wants = home / ".config/systemd/user/default.target.wants/reactive-rgb.service"
            current_wants.parent.mkdir(parents=True)
            os.symlink("/current/checkouts/reactive-rgb.service", current_wants)
            checksummed = [plan, migration / "legacy-modules", migration / "applied-links.tsv", migration / "previous-applied-links.tsv", migration / "legacy-links.tsv", migration / "legacy-links-removed", migration / "generated-targets.tsv", migration / "generated-installed.tsv", migration / "rgb-state", legacy_source, legacy_unit]
            (migration / "SHA256SUMS").write_text("".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(migration)}\n" for path in checksummed), encoding="utf-8")
            systemctl_log = root / "systemctl.log"
            self.run_tool("rollback", "deployment-order", "--apply", env={"XDG_STATE_HOME": str(state), "XDG_CONFIG_HOME": str(root / "config"), "HOME": str(home), "DOTFILES_TEST_SYSTEMCTL_LOG": str(systemctl_log)})
            self.assertFalse(destination.exists())
            self.assertFalse(current.exists())
            self.assertTrue((home / ".config/legacy.conf").is_symlink())
            self.assertTrue(current_unit.is_symlink())
            self.assertEqual(current_unit.resolve(), legacy_unit)
            self.assertFalse(current_wants.exists())
            self.assertFalse(current_wants.is_symlink())
            self.assertEqual(
                systemctl_log.read_text(encoding="utf-8").splitlines(),
                [
                    "--user show-environment",
                    "--user is-active reactive-rgb.service",
                    "--user stop reactive-rgb.service",
                    "--user daemon-reload",
                    "--user enable reactive-rgb.service",
                    "--user start reactive-rgb.service",
                ],
            )
            self.assertEqual((migration / "status").read_text(encoding="utf-8"), "rolled-back\n")
            repeated = self.run_tool("rollback", "deployment-order", "--apply", env={"XDG_STATE_HOME": str(state), "XDG_CONFIG_HOME": str(root / "config"), "HOME": str(home)})
            self.assertEqual(repeated.stdout.strip(), str(migration))

    def test_manual_rollback_recovers_prestow_checkpoint_without_applied_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state, home = root / "state", root / "home"
            migration = state / "dotfiles/migrations/deployment-checkpoint"
            migration.mkdir(parents=True)
            (migration / "plan.json").write_text(json.dumps({"repo": str(root / "checkout-gone"), "modules": ["hypr-host"]}), encoding="utf-8")
            for name in (
                "legacy-modules", "legacy-links.tsv", "previous-applied-links.tsv",
                "generated-installed.tsv", "generated-removed.tsv", "generated-targets.tsv",
                "pre-stow-restore-links.tsv",
            ):
                (migration / name).write_text("", encoding="utf-8")
            (migration / "stow-checkpoint").write_text("", encoding="utf-8")
            expected = "../../checkout-gone/hypr-host/.config/host.lua"
            (migration / "stow-intent.tsv").write_text(f".config/host.lua\t{expected}\n", encoding="utf-8")
            (migration / "stow-before.tsv").write_text(".config/host.lua\tabsent\t\n", encoding="utf-8")
            (migration / "status").write_text("stow-ready\n", encoding="utf-8")
            current = home / ".config/host.lua"
            current.parent.mkdir(parents=True)
            os.symlink(expected, current)
            checksummed = [path for path in migration.rglob("*") if path.is_file() and path.name != "status"]
            (migration / "SHA256SUMS").write_text(
                "".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(migration)}\n" for path in checksummed),
                encoding="utf-8",
            )
            self.run_tool("rollback", "deployment-checkpoint", "--apply", env={"XDG_STATE_HOME": str(state), "HOME": str(home)})
            self.assertFalse(current.exists())
            self.assertFalse(current.is_symlink())
            self.assertEqual((migration / "status").read_text(encoding="utf-8"), "rolled-back\n")

    def test_manual_rollback_reconciles_rgb_for_common_prestow_unit_without_removing_it(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state, home = root / "state", root / "home"
            migration = state / "dotfiles/migrations/deployment-common-rgb"
            migration.mkdir(parents=True)
            unit = ".config/systemd/user/reactive-rgb.service"
            expected = str(root / "checkout/rgb-openrgb/.config/systemd/user/reactive-rgb.service")
            snapshot = migration / "pre-stow/rgb.service"
            snapshot.parent.mkdir(parents=True)
            snapshot.write_text("[Service]\nExecStart=/previous\n", encoding="utf-8")
            (migration / "plan.json").write_text(json.dumps({"repo": str(root / "checkout"), "modules": ["rgb-openrgb"]}), encoding="utf-8")
            for name in (
                "legacy-modules", "legacy-links.tsv", "previous-applied-links.tsv",
                "generated-installed.tsv", "generated-removed.tsv", "generated-targets.tsv",
            ):
                (migration / name).write_text("", encoding="utf-8")
            (migration / "stow-checkpoint").write_text("", encoding="utf-8")
            (migration / "stow-intent.tsv").write_text(f"{unit}\t{expected}\n", encoding="utf-8")
            (migration / "stow-before.tsv").write_text(f"{unit}\tlink\t{expected}\n", encoding="utf-8")
            (migration / "pre-stow-restore-links.tsv").write_text(f"{unit}\t{snapshot}\n", encoding="utf-8")
            (migration / "applied-links.tsv").write_text(f"{unit}\t{expected}\n", encoding="utf-8")
            (migration / "user-services-format").write_text("v1\n", encoding="utf-8")
            (migration / "user-services-mutation-intent").write_text("rgb\n", encoding="utf-8")
            (migration / "rgb-state").write_text("active\n", encoding="utf-8")
            (migration / "status").write_text("stow-ready\n", encoding="utf-8")
            current_unit = home / unit
            current_unit.parent.mkdir(parents=True)
            os.symlink(expected, current_unit)
            wants = home / ".config/systemd/user/default.target.wants/reactive-rgb.service"
            wants.parent.mkdir(parents=True)
            os.symlink("../reactive-rgb.service", wants)
            checksummed = [path for path in migration.rglob("*") if path.is_file() and path.name != "status"]
            (migration / "SHA256SUMS").write_text(
                "".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(migration)}\n" for path in checksummed),
                encoding="utf-8",
            )
            log = root / "systemctl.log"
            self.run_tool(
                "rollback", "deployment-common-rgb", "--apply",
                env={"XDG_STATE_HOME": str(state), "HOME": str(home), "DOTFILES_TEST_SYSTEMCTL_LOG": str(log)},
            )
            self.assertTrue(current_unit.is_symlink())
            self.assertEqual(os.readlink(current_unit), expected)
            self.assertFalse(wants.exists())
            self.assertFalse(wants.is_symlink())
            self.assertEqual(log.read_text(encoding="utf-8").splitlines(), [
                "--user show-environment",
                "--user is-active reactive-rgb.service",
                "--user stop reactive-rgb.service",
                "--user daemon-reload",
                "--user start reactive-rgb.service",
            ])

    def test_manual_rollback_ignores_partial_new_format_stow_manifest_before_checkpoint(self) -> None:
        """A failed checkpoint preparation has not invoked Stow yet.

        ``applied-links.tsv`` may already contain a pre-existing common link at
        that point.  The durable format marker prevents manual rollback from
        treating it as an old-style completed manifest and unlinking it.
        """
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state, home = root / "state", root / "home"
            migration = state / "dotfiles/migrations/deployment-partial-stow-format"
            migration.mkdir(parents=True)
            (migration / "plan.json").write_text(json.dumps({"repo": str(root / "checkout-gone"), "modules": ["hypr-common"]}), encoding="utf-8")
            for name in (
                "legacy-modules", "legacy-links.tsv", "previous-applied-links.tsv",
                "generated-installed.tsv", "generated-removed.tsv", "generated-targets.tsv",
            ):
                (migration / name).write_text("", encoding="utf-8")
            (migration / "stow-checkpoint-format").write_text("v1\n", encoding="utf-8")
            expected = "/common/pre-existing.lua"
            (migration / "applied-links.tsv").write_text(f".config/hypr/common.lua\t{expected}\n", encoding="utf-8")
            current = home / ".config/hypr/common.lua"
            current.parent.mkdir(parents=True)
            os.symlink(expected, current)
            (migration / "status").write_text("prepared\n", encoding="utf-8")
            checksummed = [path for path in migration.rglob("*") if path.is_file() and path.name != "status"]
            (migration / "SHA256SUMS").write_text(
                "".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(migration)}\n" for path in checksummed),
                encoding="utf-8",
            )
            self.run_tool("rollback", "deployment-partial-stow-format", "--apply", env={"XDG_STATE_HOME": str(state), "HOME": str(home)})
            self.assertTrue(current.is_symlink())
            self.assertEqual(os.readlink(current), expected)
            self.assertEqual((migration / "status").read_text(encoding="utf-8"), "rolled-back\n")

    def test_manual_rollback_refuses_checkpoint_that_captured_foreign_preexisting_link(self) -> None:
        """Never promote an old/corrupt checkpoint's foreign link on rollback."""
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state, home = root / "state", root / "home"
            migration = state / "dotfiles/migrations/deployment-foreign-checkpoint"
            migration.mkdir(parents=True)
            (migration / "plan.json").write_text(json.dumps({"repo": str(root / "checkout-gone"), "modules": ["hypr-host"]}), encoding="utf-8")
            for name in (
                "legacy-modules", "legacy-links.tsv", "previous-applied-links.tsv",
                "generated-installed.tsv", "generated-removed.tsv", "generated-targets.tsv",
                "applied-links.tsv", "pre-stow-restore-links.tsv",
            ):
                (migration / name).write_text("", encoding="utf-8")
            expected = "../../checkout/hypr-host/.config/host.lua"
            foreign = "/user/foreign-host.lua"
            (migration / "stow-checkpoint").write_text("", encoding="utf-8")
            (migration / "stow-intent.tsv").write_text(f".config/host.lua\t{expected}\n", encoding="utf-8")
            (migration / "stow-before.tsv").write_text(f".config/host.lua\tlink\t{foreign}\n", encoding="utf-8")
            current = home / ".config/host.lua"; current.parent.mkdir(parents=True); os.symlink(foreign, current)
            (migration / "status").write_text("stow-ready\n", encoding="utf-8")
            checksummed = [path for path in migration.rglob("*") if path.is_file() and path.name != "status"]
            (migration / "SHA256SUMS").write_text(
                "".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(migration)}\n" for path in checksummed),
                encoding="utf-8",
            )
            result = subprocess.run(
                ["python3", str(TOOL), "--repo", str(ROOT), "rollback", "deployment-foreign-checkpoint", "--apply"],
                text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                env={**os.environ, "XDG_STATE_HOME": str(state), "HOME": str(home), "PYTHONDONTWRITEBYTECODE": "1"},
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("enlace previo ajeno", result.stderr)
            self.assertTrue(current.is_symlink())
            self.assertEqual(os.readlink(current), foreign)
            self.assertFalse((migration / "restored-active-links.tsv").exists())

    def test_retire_uses_last_applied_manifest_and_removes_generated(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state, home, config = root / "state", root / "home", root / "config"
            migration = state / "dotfiles/migrations/deployment-applied"
            migration.mkdir(parents=True)
            plan = migration / "plan.json"
            plan.write_text(json.dumps({"repo": str(ROOT), "modules": ["hypr-host"]}), encoding="utf-8")
            (migration / "legacy-modules").write_text("", encoding="utf-8")
            (migration / "legacy-links.tsv").write_text("", encoding="utf-8")
            (migration / "previous-applied-links.tsv").write_text("", encoding="utf-8")
            source = root / "source"; source.write_text("linked", encoding="utf-8")
            linked = home / ".config/host.lua"; linked.parent.mkdir(parents=True)
            os.symlink(source, linked)
            (migration / "applied-links.tsv").write_text(f".config/host.lua\t{source}\n", encoding="utf-8")
            generated = config / "qmd/index.yml"; generated.parent.mkdir(parents=True); generated.write_text("generated", encoding="utf-8")
            digest = hashlib.sha256(generated.read_bytes()).hexdigest()
            noctalia = config / "noctalia/zz-host-overrides.toml"; noctalia.parent.mkdir(parents=True); noctalia.write_text("generated-noctalia", encoding="utf-8")
            noctalia_digest = hashlib.sha256(noctalia.read_bytes()).hexdigest()
            (migration / "generated-installed.tsv").write_text(f"qmd\t{digest}\nnoctalia\t{noctalia_digest}\n", encoding="utf-8")
            (migration / "generated-targets.tsv").write_text("qmd\tabsent\nnoctalia\tabsent\n", encoding="utf-8")
            (migration / "status").write_text("applied\n", encoding="utf-8")
            checksummed = [path for path in migration.rglob("*") if path.is_file() and path.name != "status"]
            (migration / "SHA256SUMS").write_text("".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(migration)}\n" for path in checksummed), encoding="utf-8")
            (state / "dotfiles/last-migration").write_text(str(migration), encoding="utf-8")
            preview = json.loads(self.run_tool("retire", env={"XDG_STATE_HOME": str(state), "XDG_CONFIG_HOME": str(config), "HOME": str(home)}).stdout)
            self.assertEqual(preview["remove_links"], [".config/host.lua"])
            self.assertEqual(preview["remove_generated"], ["noctalia", "qmd"])
            self.run_tool("retire", "--apply", env={"XDG_STATE_HOME": str(state), "XDG_CONFIG_HOME": str(config), "HOME": str(home)})
            self.assertFalse(linked.exists())
            self.assertFalse(generated.exists())
            self.assertFalse(noctalia.exists())
            self.assertEqual((migration / "status").read_text(encoding="utf-8"), "retired\n")

    def test_retire_does_not_claim_success_when_user_manager_reload_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state, home, config = root / "state", root / "home", root / "config"
            migration = state / "dotfiles/migrations/deployment-reload-failure"
            migration.mkdir(parents=True)
            (migration / "plan.json").write_text(json.dumps({"repo": str(ROOT), "modules": ["hypr-host"]}), encoding="utf-8")
            (migration / "legacy-modules").write_text("", encoding="utf-8")
            (migration / "applied-links.tsv").write_text("", encoding="utf-8")
            (migration / "generated-installed.tsv").write_text("", encoding="utf-8")
            (migration / "generated-targets.tsv").write_text("", encoding="utf-8")
            (migration / "status").write_text("applied\n", encoding="utf-8")
            checksummed = [path for path in migration.iterdir() if path.is_file() and path.name != "status"]
            (migration / "SHA256SUMS").write_text(
                "".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n" for path in checksummed),
                encoding="utf-8",
            )
            (state / "dotfiles/last-migration").write_text(str(migration), encoding="utf-8")
            with self.assertRaises(subprocess.CalledProcessError) as failure:
                self.run_tool(
                    "retire",
                    "--apply",
                    env={
                        "XDG_STATE_HOME": str(state),
                        "XDG_CONFIG_HOME": str(config),
                        "HOME": str(home),
                        "DOTFILES_TEST_SYSTEMCTL_FAIL_RELOAD": "1",
                    },
                )
            self.assertIn("daemon-reload", failure.exception.stderr)
            self.assertEqual((migration / "status").read_text(encoding="utf-8"), "retiring\n")

    def test_manual_rollback_recovers_interrupted_retire_without_partial_removal(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state, home = root / "state", root / "home"
            migration = state / "dotfiles/migrations/deployment-retiring"
            migration.mkdir(parents=True)
            (migration / "plan.json").write_text(json.dumps({"repo": str(ROOT), "modules": ["hypr-host"]}), encoding="utf-8")
            for name in ("legacy-modules", "legacy-links.tsv", "previous-applied-links.tsv", "generated-installed.tsv", "generated-targets.tsv"):
                (migration / name).write_text("", encoding="utf-8")
            expected_one, expected_two = "/managed/one", "/managed/two"
            (migration / "applied-links.tsv").write_text(
                f".config/one\t{expected_one}\n.config/two\t{expected_two}\n", encoding="utf-8"
            )
            current = home / ".config/two"
            current.parent.mkdir(parents=True)
            os.symlink(expected_two, current)
            (migration / "retire-intent").write_text("retiring\n", encoding="utf-8")
            (migration / "status").write_text("retiring\n", encoding="utf-8")
            checksummed = [path for path in migration.rglob("*") if path.is_file() and path.name != "status"]
            (migration / "SHA256SUMS").write_text(
                "".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(migration)}\n" for path in checksummed),
                encoding="utf-8",
            )
            self.run_tool("rollback", "deployment-retiring", "--apply", env={"XDG_STATE_HOME": str(state), "HOME": str(home)})
            self.assertFalse(current.exists())
            self.assertFalse(current.is_symlink())
            self.assertEqual((migration / "status").read_text(encoding="utf-8"), "rolled-back\n")

    def test_manual_rollback_refuses_all_changes_when_any_link_changed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state, home = root / "state", root / "home"
            migration = state / "dotfiles/migrations/deployment-guard"
            migration.mkdir(parents=True)
            plan = migration / "plan.json"
            plan.write_text(json.dumps({"repo": str(root / "gone"), "modules": ["hypr-host"]}), encoding="utf-8")
            (migration / "legacy-modules").write_text("", encoding="utf-8")
            (migration / "legacy-links.tsv").write_text("", encoding="utf-8")
            (migration / "previous-applied-links.tsv").write_text("", encoding="utf-8")
            (migration / "generated-installed.tsv").write_text("", encoding="utf-8")
            (migration / "generated-targets.tsv").write_text("", encoding="utf-8")
            (migration / "applied-links.tsv").write_text(".config/one\t/expected/one\n.config/two\t/expected/two\n", encoding="utf-8")
            first, second = home / ".config/one", home / ".config/two"
            first.parent.mkdir(parents=True)
            os.symlink("/expected/one", first)
            os.symlink("/changed/two", second)
            checksummed = [path for path in migration.rglob("*") if path.is_file()]
            (migration / "SHA256SUMS").write_text("".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(migration)}\n" for path in checksummed), encoding="utf-8")
            result = subprocess.run(["python3", str(TOOL), "--repo", str(ROOT), "rollback", "deployment-guard", "--apply"], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env={**os.environ, "XDG_STATE_HOME": str(state), "HOME": str(home), "PYTHONDONTWRITEBYTECODE": "1"})
            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(first.is_symlink(), result.stderr)
            self.assertTrue(second.is_symlink(), result.stderr)

    def test_manual_rollback_restores_derived_state_snapshot(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state = root / "state"
            migration = state / "dotfiles/migrations/deployment-derived"
            migration.mkdir(parents=True)
            for name in ("legacy-modules", "applied-links.tsv", "legacy-links.tsv", "previous-applied-links.tsv", "generated-installed.tsv", "generated-targets.tsv"):
                (migration / name).write_text("", encoding="utf-8")
            (migration / "plan.json").write_text(json.dumps({"repo": str(root / "gone"), "modules": []}), encoding="utf-8")
            before = migration / "derived-before/generated/hypr/config/host.lua"
            before.parent.mkdir(parents=True)
            before.write_text("old-derived", encoding="utf-8")
            current = state / "dotfiles/generated/hypr/config/host.lua"
            current.parent.mkdir(parents=True)
            current.write_text("new-derived", encoding="utf-8")
            env = {"XDG_STATE_HOME": str(state), "HOME": str(root / "home"), "PYTHONDONTWRITEBYTECODE": "1"}
            runtime = os.environ.copy(); runtime.update(env)
            fingerprint = subprocess.run(["python3", "-c", f"import importlib.util; s=importlib.util.spec_from_file_location('m', {str(TOOL)!r}); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(m.derived_fingerprint(), end='')"], text=True, stdout=subprocess.PIPE, check=True, env=runtime).stdout
            (migration / "derived-installed.tsv").write_text(fingerprint, encoding="utf-8")
            (migration / "status").write_text("applied\n", encoding="utf-8")
            checksummed = [path for path in migration.rglob("*") if path.is_file() and path.name != "status"]
            (migration / "SHA256SUMS").write_text("".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(migration)}\n" for path in checksummed), encoding="utf-8")
            self.run_tool("rollback", "deployment-derived", "--apply", env=env)
            self.assertEqual(current.read_text(encoding="utf-8"), "old-derived")

    def test_manual_rollback_restores_deselected_generated_snapshot(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state, config = root / "state", root / "config"
            migration = state / "dotfiles/migrations/deployment-removed"
            migration.mkdir(parents=True)
            for name in ("legacy-modules", "applied-links.tsv", "legacy-links.tsv", "previous-applied-links.tsv", "generated-installed.tsv"):
                (migration / name).write_text("", encoding="utf-8")
            (migration / "plan.json").write_text(json.dumps({"repo": str(root / "gone"), "modules": []}), encoding="utf-8")
            backup = migration / "generated-backups/qmd"; backup.parent.mkdir(parents=True); backup.write_text("old-qmd", encoding="utf-8")
            prior_digest = hashlib.sha256(backup.read_bytes()).hexdigest()
            (migration / "generated-targets.tsv").write_text("qmd\tcopy\nrgb\tabsent\nrestic\tabsent\n", encoding="utf-8")
            (migration / "generated-removed.tsv").write_text(f"qmd\t{prior_digest}\n", encoding="utf-8")
            (migration / "status").write_text("applied\n", encoding="utf-8")
            checksummed = [path for path in migration.rglob("*") if path.is_file() and path.name != "status"]
            (migration / "SHA256SUMS").write_text("".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(migration)}\n" for path in checksummed), encoding="utf-8")
            self.run_tool("rollback", "deployment-removed", "--apply", env={"XDG_STATE_HOME": str(state), "XDG_CONFIG_HOME": str(config), "HOME": str(root / "home")})
            self.assertEqual((config / "qmd/index.yml").read_text(encoding="utf-8"), "old-qmd")

    def test_manual_rollback_restores_noctalia_generated_preimage(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state, config, home = root / "state", root / "config", root / "home"
            migration = state / "dotfiles/migrations/deployment-noctalia"
            migration.mkdir(parents=True)
            for name in ("legacy-modules", "applied-links.tsv", "legacy-links.tsv", "previous-applied-links.tsv"):
                (migration / name).write_text("", encoding="utf-8")
            (migration / "plan.json").write_text(json.dumps({"repo": str(root / "gone"), "modules": []}), encoding="utf-8")
            destination = config / "noctalia/zz-host-overrides.toml"
            destination.parent.mkdir(parents=True)
            destination.write_text("new-override", encoding="utf-8")
            snapshot = migration / "generated-backups/noctalia"
            snapshot.parent.mkdir(parents=True)
            snapshot.write_text("old-override", encoding="utf-8")
            digest = hashlib.sha256(destination.read_bytes()).hexdigest()
            (migration / "generated-targets.tsv").write_text("noctalia\tcopy\n", encoding="utf-8")
            (migration / "generated-installed.tsv").write_text(f"noctalia\t{digest}\n", encoding="utf-8")
            (migration / "status").write_text("applied\n", encoding="utf-8")
            checksummed = [path for path in migration.rglob("*") if path.is_file() and path.name != "status"]
            (migration / "SHA256SUMS").write_text(
                "".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(migration)}\n" for path in checksummed),
                encoding="utf-8",
            )
            self.run_tool("rollback", "deployment-noctalia", "--apply", env={"XDG_STATE_HOME": str(state), "XDG_CONFIG_HOME": str(config), "HOME": str(home)})
            self.assertEqual(destination.read_text(encoding="utf-8"), "old-override")

    def test_manual_rollback_restores_prior_profileless_snapshot_not_checkout(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state, home = root / "state", root / "home"
            migration = state / "dotfiles/migrations/deployment-prior-snapshot"
            migration.mkdir(parents=True)
            (migration / "plan.json").write_text(json.dumps({"repo": str(root / "checkout-gone"), "modules": ["hypr-host"]}), encoding="utf-8")
            for name in ("legacy-modules", "legacy-links.tsv", "generated-installed.tsv", "generated-removed.tsv", "generated-targets.tsv"):
                (migration / name).write_text("", encoding="utf-8")
            current_source = root / "current-source"; current_source.write_text("new", encoding="utf-8")
            current = home / ".config/current.conf"; current.parent.mkdir(parents=True); os.symlink(current_source, current)
            (migration / "applied-links.tsv").write_text(f".config/current.conf\t{current_source}\n", encoding="utf-8")
            (migration / "previous-applied-links.tsv").write_text(".config/old.conf\t/checkout-gone/old.conf\n", encoding="utf-8")
            snapshot = migration / "applied-referents/.config/old.conf"; snapshot.parent.mkdir(parents=True); snapshot.write_text("old-snapshot", encoding="utf-8")
            (migration / "previous-restore-links.tsv").write_text(f".config/old.conf\t{snapshot}\n", encoding="utf-8")
            (migration / "previous-links-removed").write_text("yes\n", encoding="utf-8")
            (migration / "status").write_text("applied\n", encoding="utf-8")
            checksummed = [path for path in migration.rglob("*") if path.is_file() and path.name != "status"]
            (migration / "SHA256SUMS").write_text("".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(migration)}\n" for path in checksummed), encoding="utf-8")
            self.run_tool("rollback", "deployment-prior-snapshot", "--apply", env={"XDG_STATE_HOME": str(state), "HOME": str(home)})
            self.assertFalse(current.exists())
            self.assertEqual((home / ".config/old.conf").read_text(encoding="utf-8"), "old-snapshot")

    def test_manual_rollback_recovers_partial_previous_removal_intent_without_claiming_foreign_link(self) -> None:
        """The durable intent covers a cut between two previous-link unlinks.

        The missing old link is restored from the private snapshot.  A second
        path changed by the user after the intent is deliberately left alone
        and omitted from the successor manifest, so a later apply cannot claim
        or remove it as part of this transaction.
        """
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state, home = root / "state", root / "home"
            migration = state / "dotfiles/migrations/deployment-partial-previous"
            migration.mkdir(parents=True)
            (migration / "plan.json").write_text(json.dumps({"repo": str(root / "checkout-gone"), "modules": ["hypr-host"]}), encoding="utf-8")
            for name in ("legacy-modules", "legacy-links.tsv", "generated-installed.tsv", "generated-removed.tsv", "generated-targets.tsv"):
                (migration / name).write_text("", encoding="utf-8")
            new_source = root / "new-source"; new_source.write_text("new", encoding="utf-8")
            current = home / ".config/current.conf"; current.parent.mkdir(parents=True); os.symlink(new_source, current)
            (migration / "applied-links.tsv").write_text(f".config/current.conf\t{new_source}\n", encoding="utf-8")
            (migration / "previous-applied-links.tsv").write_text(
                ".config/old.conf\t/legacy/old.conf\n.config/foreign.conf\t/legacy/foreign.conf\n", encoding="utf-8"
            )
            old_snapshot = migration / "applied-referents/.config/old.conf"; old_snapshot.parent.mkdir(parents=True); old_snapshot.write_text("old-snapshot", encoding="utf-8")
            foreign_snapshot = migration / "applied-referents/.config/foreign.conf"; foreign_snapshot.write_text("foreign-snapshot", encoding="utf-8")
            (migration / "previous-restore-links.tsv").write_text(
                f".config/old.conf\t{old_snapshot}\n.config/foreign.conf\t{foreign_snapshot}\n", encoding="utf-8"
            )
            # The old path is absent because its unlink completed before a
            # power loss. The other old path now belongs to the user.
            foreign = home / ".config/foreign.conf"; os.symlink("/user/foreign", foreign)
            (migration / "previous-links-removal-intent").write_text("removing\n", encoding="utf-8")
            (migration / "status").write_text("applying\n", encoding="utf-8")
            checksummed = [path for path in migration.rglob("*") if path.is_file() and path.name != "status"]
            (migration / "SHA256SUMS").write_text(
                "".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(migration)}\n" for path in checksummed),
                encoding="utf-8",
            )
            self.run_tool("rollback", "deployment-partial-previous", "--apply", env={"XDG_STATE_HOME": str(state), "HOME": str(home)})
            self.assertFalse(current.exists())
            self.assertEqual((home / ".config/old.conf").read_text(encoding="utf-8"), "old-snapshot")
            self.assertTrue(foreign.is_symlink())
            self.assertEqual(os.readlink(foreign), "/user/foreign")
            restored = (migration / "restored-active-links.tsv").read_text(encoding="utf-8")
            self.assertIn(".config/old.conf\t", restored)
            self.assertNotIn(".config/foreign.conf\t", restored)

    def test_manual_rollback_rejects_checkout_referents_before_removing_links(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state, home = root / "state", root / "home"
            migration = state / "dotfiles/migrations/deployment-unsafe-prior"
            migration.mkdir(parents=True)
            (migration / "plan.json").write_text(json.dumps({"repo": str(root / "checkout-gone"), "modules": ["hypr-host"]}), encoding="utf-8")
            for name in ("legacy-modules", "legacy-links.tsv", "generated-installed.tsv", "generated-targets.tsv"):
                (migration / name).write_text("", encoding="utf-8")
            current = home / ".config/current.conf"
            current.parent.mkdir(parents=True)
            os.symlink("/current/source", current)
            (migration / "applied-links.tsv").write_text(".config/current.conf\t/current/source\n", encoding="utf-8")
            (migration / "previous-applied-links.tsv").write_text(".config/old.conf\t/checkout-gone/old.conf\n", encoding="utf-8")
            (migration / "previous-restore-links.tsv").write_text(".config/old.conf\t/checkout-gone/old.conf\n", encoding="utf-8")
            (migration / "previous-links-removed").write_text("yes\n", encoding="utf-8")
            (migration / "status").write_text("applied\n", encoding="utf-8")
            checksummed = [path for path in migration.rglob("*") if path.is_file() and path.name != "status"]
            (migration / "SHA256SUMS").write_text("".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(migration)}\n" for path in checksummed), encoding="utf-8")
            result = subprocess.run(
                ["python3", str(TOOL), "--repo", str(ROOT), "rollback", "deployment-unsafe-prior", "--apply"],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env={**os.environ, "XDG_STATE_HOME": str(state), "HOME": str(home), "PYTHONDONTWRITEBYTECODE": "1"},
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("snapshot de enlace", result.stderr)
            self.assertTrue(current.is_symlink())

    def test_manual_link_manifests_reject_non_normalized_home_paths(self) -> None:
        """Rollback and retire never map a manifest entry outside HOME."""
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            manifest = root / "links.tsv"
            home = root / "home"
            home.mkdir()
            for relative in ("../outside", ".", "./.config/test", ".config/../normal", "one//two"):
                manifest.write_text(f"{relative}\t/managed/source\n", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "inválido"):
                    HOST_MODULE.read_link_manifest(manifest, "links.tsv")
                with self.assertRaisesRegex(ValueError, "fuera de HOME"):
                    HOST_MODULE.link_path(home, relative)


if __name__ == "__main__":
    unittest.main()
