"""Local runtime safety checks; no model downloads or GPU inference in tests."""
import hashlib
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[2] / "ai/skills/tessera/scripts/kev-local.py"
SPEC = importlib.util.spec_from_file_location("kev_local", SCRIPT)
kev = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(kev)


class KevLocalTest(unittest.TestCase):
    def test_patch_accepts_lf_and_crlf_without_changing_result_bytes(self):
        for newline in (b"\n", b"\r\n"):
            with self.subTest(newline=newline), tempfile.TemporaryDirectory(prefix="kev patch ") as directory:
                root = Path(directory)
                kev.run("git", "init", "-q", root, capture=True)
                kev.run("git", "config", "core.autocrlf", "false", cwd=root)
                (root / "kev").mkdir()
                target = root / "kev/serve.py"
                target.write_bytes(b"strict = False\n")
                patch_file = root / "input.patch"
                patch_file.write_bytes(newline.join([
                    b"diff --git a/kev/serve.py b/kev/serve.py",
                    b"--- a/kev/serve.py", b"+++ b/kev/serve.py", b"@@ -1 +1 @@",
                    b"-strict = False", b"+strict = True", b"",
                ]))
                kev.apply_server_patch(root, patch_file)
                self.assertEqual(target.read_bytes(), b"strict = True\n")

    def test_existing_destination_is_never_replaced(self):
        with tempfile.TemporaryDirectory(prefix="kev runtime ") as directory:
            root = Path(directory)
            sentinel = root / "keep.txt"
            sentinel.write_text("existing")
            with patch.object(kev, "run") as command:
                with self.assertRaisesRegex(ValueError, "already exists"):
                    kev.install(root)
                command.assert_not_called()
            self.assertEqual(sentinel.read_text(), "existing")

    def test_modified_source_and_extra_code_are_rejected(self):
        with tempfile.TemporaryDirectory(prefix="kev source ") as directory:
            root = Path(directory)
            (root / "kev").mkdir()
            serve = root / "kev/serve.py"
            serve.write_text("strict = True\n")
            other = root / "kev/api.py"
            other.write_text("original = True\n")
            (root / ".gitignore").write_text("*.pyc\n")
            for args in (["init", "-q"], ["add", "."],
                         ["-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "fixture"]):
                kev.run("git", *args, cwd=root, capture=True)
            revision = kev.run("git", "rev-parse", "HEAD", cwd=root, capture=True).stdout.strip()
            with patch.object(kev, "REVISION", revision), patch.object(kev, "SERVE_HASH", hashlib.sha256(serve.read_bytes()).hexdigest()):
                kev.verify_source(root)
                extra = root / "kev/shadow.py"
                extra.write_text("unexpected = True\n")
                with self.assertRaisesRegex(ValueError, "Untracked Kev code"):
                    kev.verify_source(root)
                extra.unlink()
                shadow = root / "torch.py"
                shadow.write_text("unexpected = True\n")
                with self.assertRaisesRegex(ValueError, "Untracked Kev code"):
                    kev.verify_source(root)
                shadow.unlink()
                bytecode = root / "torch.pyc"
                bytecode.write_bytes(b"ignored but importable")
                with self.assertRaisesRegex(ValueError, "bytecode"):
                    kev.verify_source(root)
                bytecode.unlink()
                other.write_text("changed = True\n")
                with self.assertRaises(subprocess.CalledProcessError):
                    kev.verify_source(root)
                other.write_text("original = True\n")
                serve.write_text("strict = False\n")
                with self.assertRaisesRegex(ValueError, "anti-truncation"):
                    kev.verify_source(root)

    def test_cpu_and_memory_require_explicit_handling(self):
        cpu = {"cuda": False, "mps": False, "bf16": False, "free_vram": None}
        with patch.object(kev.subprocess, "call") as command:
            with self.assertRaisesRegex(ValueError, "allow-cpu"):
                kev.serve(Path("runtime"), cpu)
            gpu = {**cpu, "cuda": True, "free_vram": 3 * 1024**3}
            with self.assertRaisesRegex(ValueError, "VRAM"):
                kev.serve(Path("runtime"), gpu)
            with self.assertRaisesRegex(ValueError, "6 GiB"):
                kev.serve(Path("runtime"), {**gpu, "free_vram": 5 * 1024**3})
            command.assert_not_called()

    def test_windows_cuda_is_explicit_and_hash_pinned(self):
        with patch.object(kev.platform, "system", return_value="Linux"), patch.object(kev, "run") as command:
            with self.assertRaisesRegex(ValueError, "Windows x86_64"):
                kev.windows_cuda(Path("runtime"))
            command.assert_not_called()
        with tempfile.TemporaryDirectory() as directory:
            python = Path(directory) / "python.exe"
            python.touch()
            with patch.object(kev.platform, "system", return_value="Windows"), \
                 patch.object(kev.platform, "machine", return_value="AMD64"), \
                 patch.object(kev, "verify_source"), patch.object(kev, "python_path", return_value=python), \
                 patch.object(kev, "run") as command:
                kev.windows_cuda(Path(directory))
                args = command.call_args.args
                self.assertIn("--no-deps", args)
                self.assertEqual(args[-1], kev.WINDOWS_CUDA_WHEEL)
                self.assertIn("cp313-cp313-win_amd64.whl#sha256=", args[-1])

    def test_cpu_launch_keeps_pinned_checkpoint_loopback_and_fp32(self):
        cpu = {"cuda": False, "mps": False, "bf16": False, "free_vram": None}
        with patch.object(kev.subprocess, "call", return_value=0) as command:
            self.assertEqual(kev.serve(Path("runtime with spaces"), cpu, allow_cpu=True), 0)
            args, kwargs = command.call_args
            self.assertIn(kev.CHECKPOINT, args[0])
            self.assertIn("-I", args[0])
            self.assertEqual(args[0][-4:], ["--host", "127.0.0.1", "--port", "8009"])
            self.assertEqual(kwargs["env"]["KEV_DTYPE"], "fp32")
            self.assertEqual(kwargs["env"]["KEV_BACKEND"], "torch")
            if os.name == "nt":
                self.assertEqual(kwargs["env"]["HF_HUB_DISABLE_SYMLINKS"], "1")

    @unittest.skipIf(os.name == "nt", "XDG is the Linux path contract")
    def test_per_host_xdg_path(self):
        with patch.dict(os.environ, {"XDG_DATA_HOME": "/tmp/different host data"}, clear=True):
            self.assertEqual(kev.default_runtime(), Path("/tmp/different host data/tessera/kev"))


if __name__ == "__main__":
    unittest.main()
