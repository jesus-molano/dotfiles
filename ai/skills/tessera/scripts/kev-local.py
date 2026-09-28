#!/usr/bin/env python3
"""Install and serve a pinned Kev pilot per host; Python 3.11+, Git and uv.

No system packages, drivers, credentials, autostart or remote services changed.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import tessera_paths  # noqa: E402

sys.dont_write_bytecode = True
UPSTREAM = "https://github.com/jaredpalmer/kev.git"
REVISION = "9c41005b2180347c3c646dfc9e50c4428483ec6b"
SERVE_HASH = "1780dd9f8355a13a09ebe849ac4093b46b59055f7e5c302ab2283b608513418f"
CHECKPOINT = "jaredpalmer/kev-0.8b@9a45d25eb2ab761841196625383fa1dff0e56c1e"
# CPython 3.13 / Windows x86_64, resolved from PyTorch's official cu128 index.
WINDOWS_CUDA_WHEEL = (
    "https://download-r2.pytorch.org/whl/cu128/torch-2.8.0%2Bcu128-cp313-cp313-win_amd64.whl"
    "#sha256=9e20646802b7fc295c1f8b45fefcfc9fb2e4ec9cbe8593443cd2b9cc307c8405"
)


def default_runtime():
    # Same non-virtualized store as the catalogs; see tessera_paths.
    return Path(os.environ.get("TESSERA_KEV_DIR", tessera_paths.data_home() / "kev"))


def legacy_runtimes():
    return [home / "kev" for home in tessera_paths.legacy_homes() if (home / "kev").is_dir()]


def run(*args, cwd=None, capture=False):
    return subprocess.run(list(map(str, args)), cwd=cwd, check=True,
                          text=True, capture_output=capture)


def python_path(runtime):
    return runtime / (".venv/Scripts/python.exe" if os.name == "nt" else ".venv/bin/python")


def verify_source(runtime):
    if not (runtime / ".git").is_dir():
        found = [str(path) for path in legacy_runtimes()]
        hint = f" Earlier runtimes found (pass one with --runtime or TESSERA_KEV_DIR): {found}" if found else ""
        raise ValueError("The Kev checkout is missing; run install into a new target." + hint)
    if run("git", "rev-parse", "HEAD", cwd=runtime, capture=True).stdout.strip() != REVISION:
        raise ValueError("Different Kev revision; an existing runtime is never replaced.")
    if hashlib.sha256((runtime / "kev/serve.py").read_bytes()).hexdigest() != SERVE_HASH:
        raise ValueError("The server lacks the verified anti-truncation patch.")
    run("git", "diff", "--quiet", "--no-ext-diff", "HEAD", "--", ".", ":!kev/serve.py", cwd=runtime)
    unknown = run("git", "ls-files", "--others", "--exclude-standard", cwd=runtime, capture=True)
    if unknown.stdout:
        raise ValueError("Untracked Kev code found; review it before starting.")
    # Git ignores *.pyc, but legacy bytecode outside __pycache__ can shadow
    # source/dependencies. Normal interpreter caches need not be removed.
    if any(runtime.glob("*.pyc")) or any((runtime / "kev").glob("*.pyc")):
        raise ValueError("Foreign importable bytecode in the checkout; review it before starting.")


def apply_server_patch(runtime, patch):
    # Existing Windows clones may retain CRLF even after adding eol=lf rules.
    content = patch.read_bytes().replace(b"\r\n", b"\n")
    for flags in (("--check",), ()):
        subprocess.run(["git", "apply", *flags, "-"], input=content,
                       cwd=runtime, check=True)


def install(runtime):
    # A failed installation is left for inspection; never remove or overwrite it.
    if runtime.exists() or runtime.is_symlink():
        raise ValueError("The target already exists; use check. Nothing is overwritten or deleted.")
    for binary in ("git", "uv"):
        if not shutil.which(binary):
            raise ValueError(f"{binary} is missing; install it through the approved mechanism of this machine.")
    runtime.parent.mkdir(parents=True, exist_ok=True)
    if shutil.disk_usage(runtime.parent).free < 12 * 1024**3:
        raise ValueError("At least 12 GiB of free space is required to prepare the pilot.")
    run("git", "clone", "--filter=blob:none", "--no-checkout", UPSTREAM, runtime)
    run("git", "config", "core.autocrlf", "false", cwd=runtime)
    run("git", "sparse-checkout", "set", "kev", "tests", "docs/model-cards", cwd=runtime)
    run("git", "checkout", "--detach", REVISION, cwd=runtime)
    patch = Path(__file__).resolve().parent.parent / "references/kev-strict-context.patch"
    apply_server_patch(runtime, patch)
    verify_source(runtime)
    run("uv", "sync", "--locked", "--no-dev", "--extra", "serve", "--python", "3.13", cwd=runtime)


def windows_cuda(runtime):
    if platform.system() != "Windows" or platform.machine().lower() not in {"amd64", "x86_64"}:
        raise ValueError("windows-cuda requires Windows x86_64; this machine is not modified.")
    verify_source(runtime)
    if not python_path(runtime).is_file():
        raise ValueError("Run install before windows-cuda.")
    # PyPI's Windows wheel is CPU-only. This explicit, hash-pinned platform
    # overlay changes only torch in the isolated environment, never the lockfile.
    run("uv", "pip", "install", "--python", python_path(runtime), "--no-deps",
        WINDOWS_CUDA_WHEEL, cwd=runtime)


def capabilities(runtime):
    verify_source(runtime)
    python = python_path(runtime)
    if not python.is_file():
        raise ValueError("The .venv environment is missing; incomplete install, see the recovery guide.")
    probe = (
        "import json,torch; cuda=torch.cuda.is_available(); "
        "print(json.dumps({'cuda':cuda,'mps':torch.backends.mps.is_available(),"
        "'bf16':cuda and torch.cuda.is_bf16_supported(),"
        "'gpu':torch.cuda.get_device_name(0) if cuda else None,"
        "'free_vram':torch.cuda.mem_get_info()[0] if cuda else None,"
        "'cuda_build':torch.version.cuda,'torch':torch.__version__}))"
    )
    return json.loads(run(python, "-I", "-c", probe, cwd=runtime, capture=True).stdout)


def serve(runtime, info, allow_cpu=False):
    if info["mps"] and not info["cuda"]:
        raise ValueError("This launcher has not validated Apple Silicon; adapt and verify its backend.")
    if not info["cuda"] and not allow_cpu:
        raise ValueError("CUDA is unavailable. CPU needs --allow-cpu; measure its latency separately.")
    min_vram = 4 if info["bf16"] else 6
    if info["cuda"] and info["free_vram"] < min_vram * 1024**3:
        raise ValueError(f"Less than {min_vram} GiB of free VRAM; free memory and review the context before starting.")
    env = dict(os.environ)
    env.update(HF_HUB_DISABLE_TELEMETRY="1", KEV_BACKEND="torch",
               KEV_DTYPE="bf16" if info["bf16"] else "fp32", KEV_PREFIX_CACHE="1",
               KEV_PREFIX_MAX_TOKENS="8192", KEV_CUDA_GRAPHS="0", KEV_FUSED="0")
    if os.name == "nt":
        # The Hub's concurrent capability probe can race before detecting that
        # unprivileged Windows cannot create symlinks. Use its supported copies.
        env["HF_HUB_DISABLE_SYMLINKS"] = "1"
    command = [str(python_path(runtime)), "-I", "-m", "kev.serve", "--run", CHECKPOINT,
               "--host", "127.0.0.1", "--port", "8009"]
    print(json.dumps({"runtime": str(runtime), "checkpoint": CHECKPOINT, **info}), flush=True)
    try:
        return subprocess.call(command, cwd=runtime, env=env)
    except KeyboardInterrupt:
        return 130


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("install", "windows-cuda", "check", "serve"))
    parser.add_argument("--runtime", type=Path, default=default_runtime())
    parser.add_argument("--allow-cpu", action="store_true")
    args = parser.parse_args()
    runtime = args.runtime.expanduser().absolute()
    if args.command == "install":
        install(runtime)
    elif args.command == "windows-cuda":
        windows_cuda(runtime)
    info = capabilities(runtime)
    if args.command == "windows-cuda" and (info["torch"] != "2.8.0+cu128" or info["cuda_build"] != "12.8"):
        raise ValueError("The installed wheel does not match PyTorch 2.8.0+cu128; do not start.")
    if args.command == "serve":
        return serve(runtime, info, args.allow_cpu)
    print(json.dumps({"runtime": str(runtime), "platform": platform.platform(),
                      "revision": REVISION, "checkpoint": CHECKPOINT, **info}, indent=2))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"Kev: {error}", file=sys.stderr)
        sys.exit(1)
