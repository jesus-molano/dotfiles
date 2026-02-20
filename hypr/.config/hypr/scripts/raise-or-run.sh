#!/bin/bash
set -euo pipefail
# Focus existing window by class, or launch if not running
# Usage: raise-or-run.sh <window_class> <command...>

CLASS="$1"
shift
CMD="$*"

if hyprctl clients -j | jq -e ".[] | select(.class == \"$CLASS\")" > /dev/null 2>&1; then
    hyprctl dispatch focuswindow "class:$CLASS"
else
    exec $CMD
fi
