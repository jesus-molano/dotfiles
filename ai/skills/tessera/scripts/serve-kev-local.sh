#!/usr/bin/env bash
# Convenience wrapper; portable installation and hardware checks live in Python.
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec python3 "$script_dir/kev-local.py" serve "$@"
