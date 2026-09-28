"""Where Tessera keeps per-user data, outside every repository.

Windows packages Claude Desktop and Codex as MSIX apps, and MSIX redirects each
app's writes under %LOCALAPPDATA% to a private per-app copy. Catalogs written
there are invisible to a normal shell and to the other app. The store therefore
lives in the user profile (~/.local/share/tessera) on every platform, which MSIX
does not virtualize; older stores are discovered so they can be adopted.
"""
from __future__ import annotations

import os
from pathlib import Path


def data_home() -> Path:
    if os.environ.get("TESSERA_HOME"):
        return Path(os.environ["TESSERA_HOME"])
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "tessera"


def legacy_homes() -> list[Path]:
    """Earlier Windows stores: the real %LOCALAPPDATA% and each MSIX app's private copy."""
    local = os.environ.get("LOCALAPPDATA") or (str(Path.home() / "AppData/Local") if os.name == "nt" else "")
    if not local:
        return []
    base = Path(local)
    candidates = [base / "tessera", *sorted(base.glob("Packages/*/LocalCache/Local/tessera"))]
    current = data_home().resolve()
    return [path for path in candidates if path.is_dir() and path.resolve() != current]
