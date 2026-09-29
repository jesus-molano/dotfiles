#!/usr/bin/env bash
# Run the evals in ai/evals/cases against the shared skills in ai/skills.
# The plugin is assembled in a private temporary folder: the repository keeps a
# single copy of each skill and no symlinks. Extra arguments go to
# `claude plugin eval` (for example --case NAME, --runs 3, --model sonnet).
#
# Modes:
#   (default)  routing: one arm (skills loaded), one run per case, $4 cap.
#   --outcome  outcome: cases tagged `outcome`, with and without the skills
#              (the no-plugin baseline), three runs per arm, $4 cap.
#
# Eval runs are isolated and never load your CLAUDE.md. A case tagged `rules`
# depends on the global rules, so this script appends the rendered Claude
# rules (ai/rules + ai/adapters, Linux) to its system prompt in both arms.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
command -v claude >/dev/null || { printf '%s\n' 'claude is not installed.' >&2; exit 1; }

mode=routing
passthrough=()
for arg in "$@"; do
	if [[ $arg == --outcome ]]; then
		mode=outcome
	else
		passthrough+=("$arg")
	fi
done

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

# A JSON string is a valid YAML double-quoted scalar, so the rules go into the
# frontmatter as one line. A case that sets its own append_system_prompt keeps it.
PYTHONDONTWRITEBYTECODE=1 python3 - "$repo_root/scripts" "$plugin/evals" <<'PY'
import json, re, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
from ai_sources import instructions
rules = json.dumps(instructions("claude", "linux"))
for prompt in sorted(Path(sys.argv[2]).glob("*/prompt.md")):
    text = prompt.read_text(encoding="utf-8")
    head = re.match(r"---\n(.*?)\n---\n", text, re.DOTALL)
    if not head or not re.search(r"^tags:.*\brules\b", head.group(1), re.MULTILINE):
        continue
    if re.search(r"^append_system_prompt:", head.group(1), re.MULTILINE):
        continue
    prompt.write_text(text.replace("\n---\n", f"\nappend_system_prompt: {rules}\n---\n", 1),
                      encoding="utf-8")
PY

results="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/ai-evals/$(date +%Y%m%d-%H%M%S)-$mode"
mkdir -p -- "$results"
# Defaults keep a check cheap and capped; later arguments override them.
# Routing graders on the Skill tool score only in the with-arm, so the routing
# mode skips the baseline. The outcome mode keeps it: its graders check what the
# agent did or said, and Δ is what the skills add to that result.
if [[ $mode == outcome ]]; then
	defaults=(--ablation with-without --runs 3 --max-cost-usd 4 --tag outcome)
else
	defaults=(--ablation none --runs 1 --max-cost-usd 4)
fi
# Exit 1 (a case below the threshold) and exit 2 (cost cap, partial results)
# still write results, so print their path before the status goes back.
status=0
claude plugin eval "$plugin" --trust-plugin --no-publish "${defaults[@]}" \
	--output-dir "$results" ${passthrough[@]+"${passthrough[@]}"} || status=$?
printf 'Results: %s\n' "$results"
exit "$status"
