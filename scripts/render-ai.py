#!/usr/bin/env python3
"""Render tracked Codex adapters; Claude/Windows adapters render at sync time."""
import argparse
from ai_sources import codex_outputs

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--check", action="store_true")
args = parser.parse_args()
pending = 0
for path, content in codex_outputs().items():
    if not path.exists() or path.read_text(encoding="utf-8") != content:
        pending += 1
        if args.check:
            print(f"STALE: {path}")
        else:
            path.write_text(content, encoding="utf-8")
if args.check and pending:
    raise SystemExit(1)
print("OK: adaptadores generados desde ai/" if not pending else f"Generados: {pending}")
