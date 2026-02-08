#!/usr/bin/env bash
set -uo pipefail

# Catppuccin Mocha palette
readonly BLUE='\e[38;2;137;180;250m'
readonly GREEN='\e[38;2;166;227;161m'
readonly YELLOW='\e[38;2;249;226;175m'
readonly RED='\e[38;2;243;139;168m'
readonly MAUVE='\e[38;2;203;166;247m'
readonly TEXT='\e[38;2;205;214;244m'
readonly SUB='\e[38;2;166;173;200m'
readonly RST='\e[0m'

SEP="${SUB} · ${RST}"

# Read JSON from stdin
json=$(cat)

# Extract all fields in one jq call (nested under cost.* and context_window.*)
IFS=$'\t' read -r model ctx_pct ctx_used ctx_total duration_ms lines_added lines_removed cost_usd cwd < <(
  echo "$json" | jq -r '[
    (.model.display_name // "Unknown"),
    (.context_window.used_percentage // 0),
    (.context_window.total_input_tokens // 0),
    (.context_window.context_window_size // 200000),
    (.cost.total_duration_ms // 0),
    (.cost.total_lines_added // 0),
    (.cost.total_lines_removed // 0),
    (.cost.total_cost_usd // 0),
    (.cwd // "")
  ] | @tsv' 2>/dev/null
)

# Fallbacks
model=${model:-Unknown}
ctx_pct=${ctx_pct:-0}
ctx_used=${ctx_used:-0}
ctx_total=${ctx_total:-200000}
duration_ms=${duration_ms:-0}
lines_added=${lines_added:-0}
lines_removed=${lines_removed:-0}
cost_usd=${cost_usd:-0}
cwd=${cwd:-$PWD}

# Directory name
dir=$(basename "$cwd")

# Duration: Xm Ys (only when >0)
total_secs=$(( duration_ms / 1000 ))
mins=$(( total_secs / 60 ))
secs=$(( total_secs % 60 ))

# Tokens in thousands
ctx_used_k=$(( ctx_used / 1000 ))
ctx_total_k=$(( ctx_total / 1000 ))

# Context bar color
if (( ctx_pct < 50 )); then
  bar_color="$GREEN"
elif (( ctx_pct < 75 )); then
  bar_color="$YELLOW"
else
  bar_color="$RED"
fi

# Progress bar (10 chars)
filled=$(( ctx_pct / 10 ))
empty=$(( 10 - filled ))
bar="${bar_color}"
for (( i = 0; i < filled; i++ )); do bar+="▓"; done
for (( i = 0; i < empty; i++ )); do bar+="░"; done
bar+="${RST}"

# Git info with 5s cache
git_info=""
if [[ -d "$cwd/.git" ]] || git -C "$cwd" rev-parse --git-dir &>/dev/null; then
  cache_key=$(echo "$cwd" | md5sum | cut -d' ' -f1)
  cache_file="/tmp/claude-statusline-git-${cache_key}"
  now=$(date +%s)

  if [[ -f "$cache_file" ]] && (( now - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) < 5 )); then
    git_info=$(cat "$cache_file")
  else
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null || echo "")
    if [[ -n "$branch" ]]; then
      staged=$(git -C "$cwd" diff --cached --numstat 2>/dev/null | wc -l)
      modified=$(git -C "$cwd" diff --numstat 2>/dev/null | wc -l)
      staged=${staged// /}
      modified=${modified// /}

      git_info="${MAUVE} ${branch}${RST}"
      (( staged > 0 )) && git_info+=" ${GREEN}+${staged}${RST}"
      (( modified > 0 )) && git_info+=" ${YELLOW}~${modified}${RST}"
    fi
    echo "$git_info" > "$cache_file"
  fi
fi

# Build single line — only show elements with actual data
out="${BLUE} ${model}${RST}"
out+="${SEP}${TEXT} ${dir}${RST}"
[[ -n "$git_info" ]] && out+="${SEP}${git_info}"

# Context: only show bar + percentage when >0%
if (( ctx_pct > 0 )); then
  out+="${SEP}${bar} ${bar_color}${ctx_pct}%${RST} ${SUB}${ctx_used_k}k/${ctx_total_k}k${RST}"
fi

# Lines changed: only when >0
if (( lines_added > 0 || lines_removed > 0 )); then
  changes=""
  (( lines_added > 0 )) && changes+="${GREEN}+${lines_added}${RST}"
  (( lines_added > 0 && lines_removed > 0 )) && changes+="/"
  (( lines_removed > 0 )) && changes+="${RED}-${lines_removed}${RST}"
  out+="${SEP}${changes}"
fi

# Duration: only when >0s
if (( total_secs > 0 )); then
  out+="${SEP}${SUB}${mins}m ${secs}s${RST}"
fi

# Cost USD
if [[ "$cost_usd" != "0" ]]; then
  out+="${SEP}${YELLOW}\$${cost_usd}${RST}"
fi

printf '%b' "$out"
