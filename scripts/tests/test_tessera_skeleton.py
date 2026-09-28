"""Curation skeleton through the CLI: evidence only, never tests or protected paths."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "ai/skills/tessera/scripts/tessera.py"


class SkeletonTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="tessera skeleton ")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / "project"
        self.env = dict(os.environ, XDG_DATA_HOME=str(self.root / "data"),
                        LOCALAPPDATA=str(self.root / "data"), PYTHONDONTWRITEBYTECODE="1")
        files = {
            "src/components/Button.vue": "<template><button><slot /></button></template>\n",
            "src/components/Button.css": ".button { color: red; }\n",
            "src/components/Unused.vue": "<template><div /></template>\n",
            "src/pages/Home.vue": "<script setup>\nimport Button from '@/components/Button.vue'\n"
                                  "import { formatDate } from '@/utils/format'\n</script>\n"
                                  "<template><Button>{{ formatDate(now) }}</Button></template>\n",
            "src/router.js": "export const routes = [{ component: () => import('@/pages/Home.vue') }]\n",
            "src/utils/format.ts": "export function formatDate(value: Date) { return value.toISOString() }\n",
            "src/vendor/bundle.min.js": "var a=1;" + "x" * 2100 + "\n",
            "public/index.html": '<script src="<%= BASE_URL %>boot.js"></script>\n',
            "public/boot.js": "window.boot = true\n",
            "vue.config.js": "module.exports = {}\n",
            "src/main.js": "import './router'\n",
            ".eslintrc.js": "module.exports = {}\n",
            "README.md": "Project\n",
            # Must never be read: a test consumer and a protected file that mention Unused.
            "tests/unit/Unused.spec.ts": "import Unused from '@/components/Unused.vue'\n<Unused />\n",
            "src/components/Unused.test.ts": "<Unused />\n",
            ".env.local": "<Unused /> TOKEN=secret\n",
        }
        for name, content in files.items():
            path = self.repo / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        self.git("init", "-q")
        self.git("add", "-f", ".")
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "fixture")

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.repo), *args], stderr=subprocess.PIPE).decode().strip()

    def call(self, *args, ok=True):
        result = subprocess.run([sys.executable, str(SCRIPT), "skeleton", "--repo", str(self.repo), *map(str, args)],
                                env=self.env, capture_output=True, text=True)
        if not ok:
            self.assertNotEqual(result.returncode, 0)
            return result
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def skeleton(self):
        report = self.call()
        data = json.loads(Path(report["skeleton"]).read_text(encoding="utf-8"))
        return report, data, {entry["source"]: entry for entry in data["entries"]}

    def test_default_output_is_external_and_repo_stays_clean(self):
        report, data, _ = self.skeleton()
        store = Path(json.loads(subprocess.check_output(
            [sys.executable, str(SCRIPT), "locate", "--repo", str(self.repo)], env=self.env))["root"])
        self.assertEqual(Path(report["skeleton"]).parent, store / "curation")
        self.assertEqual(data["frameworks"], ["vue-cli"])
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.assertFalse((self.repo / ".tessera").exists())
        second = self.call()
        self.assertNotEqual(second["skeleton"], report["skeleton"])

    def test_output_inside_repository_is_refused(self):
        result = self.call("--output", self.repo / "skeleton.json", ok=False)
        self.assertIn("repositorio Git", result.stderr)
        self.assertFalse((self.repo / "skeleton.json").exists())

    def test_tests_and_protected_paths_are_never_sources_or_consumers(self):
        _, data, entries = self.skeleton()
        dumped = json.dumps(data)
        self.assertNotIn("Unused.spec.ts", dumped)
        self.assertNotIn("Unused.test.ts", dumped)
        self.assertNotIn(".env.local", dumped)
        self.assertNotIn("secret", dumped)
        self.assertEqual(entries["src/components/Unused.vue"]["usages"], [])
        self.assertIn("No non-test consumer", entries["src/components/Unused.vue"]["usage_gap"])

    def test_detects_imports_tags_dynamic_imports_and_html_scripts(self):
        _, _, entries = self.skeleton()
        self.assertIn("src/pages/Home.vue", {u["path"] for u in entries["src/components/Button.vue"]["usages"]})
        self.assertIn("src/pages/Home.vue", {u["path"] for u in entries["src/utils/format.ts"]["usages"]})
        self.assertEqual(entries["src/utils/format.ts"]["exports"], ["formatDate"])
        self.assertEqual([u["path"] for u in entries["src/pages/Home.vue"]["usages"]], ["src/router.js"])
        self.assertEqual([u["path"] for u in entries["public/boot.js"]["usages"]], ["public/index.html"])

    def test_conventions_hints_ids_and_other_paths(self):
        _, data, entries = self.skeleton()
        self.assertIn("vue-cli-service", entries["vue.config.js"]["usage_gap"])
        self.assertIn("Vue CLI build", entries["src/main.js"]["usage_gap"])
        self.assertIn("hints", entries["src/vendor/bundle.min.js"])
        self.assertEqual(entries["src/components/Button.vue"]["id"], "components-button")
        self.assertEqual(entries["src/components/Button.css"]["id"], "components-button-css")
        self.assertEqual(data["duplicate_ids"], [])
        self.assertNotIn(".eslintrc.js", entries)
        self.assertIn(".eslintrc.js", data["other_paths"])
        self.assertIn("README.md", data["other_paths"])


if __name__ == "__main__":
    unittest.main()
