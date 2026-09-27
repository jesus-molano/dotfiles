"""Hermetic provider/focus/startup/fallback tests. Never launch a real desktop."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
PROVIDER = ROOT / 'shell/.local/bin/ai-provider'
APP = ROOT / 'hypr-common/.local/bin/hypr-ai'


@unittest.skipIf(os.name == 'nt', 'Hyprland Linux adapter')
class AIDesktopTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='ai desktop ')
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.clients = self.home / 'clients.json'
        self.clients.write_text('[]')
        self.log = self.home / 'calls'
        self.log.touch()
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / '.config'),
            XDG_STATE_HOME=str(self.home / '.state'), XDG_RUNTIME_DIR=str(self.home / 'run'),
            PATH=str(self.bin) + ':' + os.environ['PATH'], AI_PROVIDER_BIN=str(PROVIDER),
            HYPRCTL_BIN=str(self.bin / 'hyprctl'), UWSM_BIN=str(self.bin / 'uwsm'),
            CLAUDE_DESKTOP_BIN=str(self.bin / 'desktop'), CLAUDE_DESKTOP_RUNTIME=str(self.bin / 'desktop'),
            CHATGPT_BIN=str(self.bin / 'desktop'), CHATGPT_RUNTIME=str(self.bin / 'desktop'),
            TEST_LOG=str(self.log), TEST_CLIENTS=str(self.clients), TEST_VISIBLE='false',
            TEST_CLASS='com.anthropic.Claude', TEST_WORKSPACE='claude')
        self.script('desktop', 'exit 0')
        self.script('claude', 'exit 0')
        self.script('codex', 'exit 0')
        self.script('desktop-notify', 'printf "notify:%s\\n" "$*" >> "$TEST_LOG"')
        self.script('hyprctl', '''case "$1" in
clients) cat "$TEST_CLIENTS" ;;
monitors) if [[ $TEST_VISIBLE == true ]]; then printf '[{"specialWorkspace":{"name":"special:%s"}}]\\n' "$TEST_WORKSPACE"; else echo '[]'; fi ;;
eval) printf 'eval:%s\\n' "$2" >> "$TEST_LOG" ;;
esac''')
        self.script('uwsm', '''printf 'launch:%s\\n' "$*" >> "$TEST_LOG"
if [[ "$*" != *ghostty* ]]; then
printf '[{"class":"%s","workspace":{"name":"special:%s"}}]\\n' "$TEST_CLASS" "$TEST_WORKSPACE" > "$TEST_CLIENTS"
fi''')

    def script(self, name, body):
        path = self.bin / name
        path.write_text('#!/usr/bin/env bash\nset -eu\n' + body + '\n')
        path.chmod(0o755)

    def run_app(self, *args, **env):
        result = subprocess.run([str(APP), *args], env=dict(self.env, **env), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return self.log.read_text()

    def provider(self, *args):
        return subprocess.run([str(PROVIDER), *args], env=self.env, capture_output=True, text=True, check=True).stdout.strip()

    def test_default_and_switch_preserves_host_no_launch(self):
        self.assertEqual(self.provider(), 'claude')
        path = self.home / '.config/dotfiles/host.toml'
        path.parent.mkdir(parents=True)
        path.write_text('schema = 1\nbundles = []\n[audio]\nmode = "keep"\n')
        self.assertEqual(self.provider('set', 'codex'), 'codex')
        self.assertIn('mode = "keep"', path.read_text())
        self.assertEqual(self.provider(), 'codex')
        self.assertEqual(self.log.read_text(), '')
        self.provider('set', 'claude')
        self.assertEqual(self.provider(), 'claude')
        self.assertEqual(path.read_text().count('[ai]'), 1)
        # A stale lock file is harmless: the kernel owns the actual flock.
        self.assertTrue((path.parent / '.ai-provider.lock').exists())
        self.provider('set', 'codex')
        self.assertEqual(self.provider(), 'codex')

    def test_startup_does_not_wait_for_desktop_process_exit(self):
        release = self.home / 'release'
        body = (self.bin / 'uwsm').read_text() + '\nwhile [[ ! -e "$TEST_RELEASE" ]]; do sleep 0.05; done\n'
        (self.bin / 'uwsm').write_text(body)
        try:
            result = subprocess.run([str(APP), '--focus'], env=dict(self.env, TEST_RELEASE=str(release)),
                                    capture_output=True, text=True, timeout=4)
            self.assertEqual(result.returncode, 0, result.stderr)
        finally:
            release.touch()

    def test_toggle_and_focus_visible_do_not_launch(self):
        self.clients.write_text(json.dumps([{'class': 'com.anthropic.Claude', 'workspace': {'name': 'special:claude'}}]))
        self.assertIn('toggle_special("claude")', self.run_app())
        self.log.write_text('')
        result = self.run_app('--focus', TEST_VISIBLE='true')
        self.assertIn('hl.dsp.focus', result)
        self.assertNotIn('toggle_special', result)
        self.assertNotIn('launch:', result)
        self.assertIn(r'com\\.anthropic\\.Claude', result)

    def test_two_background_starts_launch_once_no_focus(self):
        self.run_app('--background')
        result = self.run_app('--background')
        self.assertEqual(result.count('launch:'), 1)
        self.assertNotIn('eval:', result)

    def test_explicit_codex_independent_of_preference(self):
        result = self.run_app('--provider', 'codex', TEST_CLASS='codex-desktop', TEST_WORKSPACE='chatgpt')
        self.assertIn('toggle_special("chatgpt")', result)
        self.assertEqual(self.provider(), 'claude')

    def test_fallback_preserves_provider_and_directory(self):
        repo = self.home / 'Repo With Spaces'
        repo.mkdir()
        result = self.run_app('--directory', str(repo), CLAUDE_DESKTOP_RUNTIME=str(self.home / 'missing'))
        self.assertIn('ghostty --working-directory=' + str(repo), result)
        self.assertIn('claude', result)
        self.assertNotIn('codex', result)
        self.assertNotIn('eval:', result)

    def test_missing_desktop_background_does_not_launch_cli(self):
        result = self.run_app('--background', CLAUDE_DESKTOP_RUNTIME=str(self.home / 'missing'))
        self.assertEqual(result, '')


if __name__ == '__main__':
    unittest.main()
