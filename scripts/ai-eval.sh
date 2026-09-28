#!/usr/bin/env bash
# Run the routing evals in ai/evals/cases against the shared skills in ai/skills.
# The plugin is assembled in a private temporary folder: the repository keeps a
# single copy of each skill and no symlinks. Extra arguments go to
# `claude plugin eval` (for example --case NAME, --runs 3, --model sonnet).
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
command -v claude >/dev/null || { printf '%s\n' 'claude is not installed.' >&2; exit 1; }

work=$(mktemp -d "${TMPDIR:-/tmp}/ai-eval.XXXXXX")
trap 'chmod -R u+rwX -- "$work" 2>/dev/null; rm -rf -- "$work"' EXIT
plugin="$work/dotfiles-ai"
mkdir -p "$plugin/.claude-plugin"
cp -R -- "$repo_root/ai/skills" "$plugin/skills"
cp -R -- "$repo_root/ai/evals/cases" "$plugin/evals"
find "$plugin" \( -name __pycache__ -o -name '*.pyc' \) -prune -exec rm -rf -- {} +
cat >"$plugin/.claude-plugin/plugin.json" <<'JSON'
{"name": "dotfiles-ai", "version": "1.0.0", "description": "Shared skills from dotfiles ai/ (local eval build)."}
JSON

results="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/ai-evals/$(date +%Y%m%d-%H%M%S)"
mkdir -p -- "$results"
# Defaults keep a check cheap: one run per case, one arm (the no-plugin arm would
# still see skills installed in ~/.claude), no published report, a cost cap.
# Later arguments override them.
claude plugin eval "$plugin" --trust-plugin --no-publish --ablation none --runs 1 --max-cost-usd 2 \
	--output-dir "$results" "$@"
printf 'Results: %s\n' "$results"
