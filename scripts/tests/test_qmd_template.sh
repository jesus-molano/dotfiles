#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
template="$repo_root/templates/qmd/index.yml.in"

test -f "$template"
grep -Fq 'path: __DOTFILES_REPO__/docs' "$template"
grep -Fq 'path: __PROJECT_ATLAS_ROOT__/docs' "$template"
if grep -Eq '/home/[[:alnum:]_.-]+' "$template"; then exit 1; fi

printf '%s\n' 'PASS: la plantilla QMD no fija checkout ni usuario'
