#!/bin/bash
set -uo pipefail

CACHE="/tmp/waybar-updates-count"
LOCK="/tmp/waybar-updates.lock"
MAX_AGE=300 # 5 min cache

# If cache is fresh, use it
if [[ -f "$CACHE" ]]; then
    age=$(( $(date +%s) - $(stat -c %Y "$CACHE") ))
    if (( age < MAX_AGE )); then
        count=$(cat "$CACHE")
        (( count > 0 )) && echo "$count"
        exit 0
    fi
fi

# Acquire lock to prevent parallel runs
exec 9>"$LOCK"
if ! flock -n 9; then
    # Another instance is updating, use stale cache
    [[ -f "$CACHE" ]] && { count=$(cat "$CACHE"); (( count > 0 )) && echo "$count"; }
    exit 0
fi

official=$(checkupdates 2>/dev/null | wc -l)
aur=$(paru -Qua 2>/dev/null | wc -l)
total=$((official + aur))

echo "$total" > "$CACHE"
(( total > 0 )) && echo "$total"
