#!/bin/bash
set -uo pipefail

official=$(checkupdates 2>/dev/null | wc -l)
aur=$(paru -Qua 2>/dev/null | wc -l)

echo $((official + aur))
