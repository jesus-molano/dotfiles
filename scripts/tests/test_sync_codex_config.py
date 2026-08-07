"""Pruebas de la fusión conservadora de config.toml de Codex."""

from __future__ import annotations

import runpy
import unittest
from pathlib import Path

import tomllib

SCRIPT = Path(__file__).resolve().parents[1] / "sync-codex-config.py"
SYNC = runpy.run_path(SCRIPT, run_name="sync_codex_config_test")


class SyncCodexConfigTest(unittest.TestCase):
    def test_render_preserves_personal_mcp_sections(self) -> None:
        original = """\
model = "gpt-5.6-sol"

[features]
memories = false

[mcp_servers.linear]
url = "https://mcp.linear.app/mcp/readonly"

[mcp_servers.linear-write]
url = "https://mcp.linear.app/mcp"
enabled = false

[mcp_servers.component-atlas]
command = "/opt/atlas/node"
args = ["/opt/atlas/server.js"]
"""

        rendered = SYNC["render"](original)
        document = tomllib.loads(rendered)

        self.assertEqual(
            document["mcp_servers"]["linear"],
            {"url": "https://mcp.linear.app/mcp/readonly"},
        )
        self.assertEqual(
            document["mcp_servers"]["linear-write"],
            {"url": "https://mcp.linear.app/mcp", "enabled": False},
        )
        self.assertEqual(
            document["mcp_servers"]["component-atlas"]["command"],
            "/opt/atlas/node",
        )
        self.assertTrue(document["features"]["memories"])


if __name__ == "__main__":
    unittest.main()
