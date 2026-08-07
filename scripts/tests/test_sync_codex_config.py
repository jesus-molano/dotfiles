"""Pruebas de la fusión conservadora de config.toml de Codex."""

from __future__ import annotations

import runpy
import unittest
from pathlib import Path

import tomllib

SCRIPT = Path(__file__).resolve().parents[1] / "sync-codex-config.py"
SYNC = runpy.run_path(SCRIPT, run_name="sync_codex_config_test")


class SyncCodexConfigTest(unittest.TestCase):
    def test_render_sets_model_defaults_when_missing(self) -> None:
        document = tomllib.loads(SYNC["render"](""))

        self.assertEqual(document["model"], "gpt-5.6-sol")
        self.assertEqual(document["model_reasoning_effort"], "medium")

    def test_render_sets_policy_without_overwriting_interactive_reasoning(self) -> None:
        rendered = SYNC["render"]('model_reasoning_effort = "xhigh"\n')
        document = tomllib.loads(rendered)

        self.assertEqual(document["model"], "gpt-5.6-sol")
        self.assertEqual(document["model_reasoning_effort"], "xhigh")
        self.assertEqual(document["approval_policy"], "on-request")
        self.assertEqual(document["approvals_reviewer"], "user")
        self.assertEqual(document["sandbox_mode"], "workspace-write")
        self.assertFalse(document["sandbox_workspace_write"]["network_access"])
        self.assertEqual(document["notify"], ["codex-notify"])
        self.assertTrue(document["features"]["hooks"])
        self.assertTrue(document["features"]["memories"])
        self.assertEqual(document["agents"]["max_concurrent_threads_per_session"], 3)
        self.assertEqual(document["agents"]["default_subagent_model"], "gpt-5.6-terra")
        self.assertEqual(document["agents"]["default_subagent_reasoning_effort"], "medium")
        self.assertEqual(
            document["tui"]["status_line"],
            ["model-with-reasoning", "context-remaining", "git-branch", "current-dir"],
        )

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

    def test_render_preserves_hooks_trusts_and_unknown_values_idempotently(self) -> None:
        original = '''\
model = "custom"
approval_policy = "never"

[hooks]
enabled = true

[projects."/work"]
trust_level = "trusted"

[mcp_servers.linear]
url = "https://mcp.linear.app/mcp/readonly"

[custom]
keep = "yes"
'''

        rendered = SYNC["render"](original)
        self.assertEqual(SYNC["render"](rendered), rendered)
        document = tomllib.loads(rendered)
        self.assertEqual(document["model"], "custom")
        self.assertEqual(document["hooks"], {"enabled": True})
        self.assertEqual(document["projects"]["/work"], {"trust_level": "trusted"})
        self.assertEqual(
            document["mcp_servers"]["linear"],
            {"url": "https://mcp.linear.app/mcp/readonly"},
        )
        self.assertEqual(document["custom"], {"keep": "yes"})

    def test_render_preserves_official_inline_hook_arrays(self) -> None:
        original = '''\
[[hooks.PreToolUse]]
matcher = "^Bash$"

[[hooks.PreToolUse.hooks]]
type = "command"
command = "/opt/orca/pre-tool-use"
timeout = 30
'''

        rendered = SYNC["render"](original)
        document = tomllib.loads(rendered)

        self.assertTrue(document["features"]["hooks"])
        self.assertEqual(document["hooks"]["PreToolUse"][0]["matcher"], "^Bash$")
        self.assertEqual(
            document["hooks"]["PreToolUse"][0]["hooks"][0],
            {
                "type": "command",
                "command": "/opt/orca/pre-tool-use",
                "timeout": 30,
            },
        )
        self.assertEqual(SYNC["render"](rendered), rendered)


if __name__ == "__main__":
    unittest.main()
