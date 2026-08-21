#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
common="$repo_root/hypr-common/.config/hypr"
host="$repo_root/hypr-host/.config/hypr"

for fragment in inputs user-inputs hardware-binds monitors; do
    test -f "$host/config/$fragment.lua"
done

# Generated state wins, then the merged deployed Stow directory, then
# HYPR_HOST_DIR provides an isolated fallback. This is intentionally a
# source-level contract: no live Hyprland session is needed to validate it.
loader="$common/hyprland.lua"
grep -Fq 'local generated_dir = os.getenv("DOTFILES_GENERATED_HYPR_DIR")' "$loader"
grep -Fq 'local deployed_dir = os.getenv("DOTFILES_DEPLOYED_HYPR_DIR")' "$loader"
grep -Fq 'local host_dir = os.getenv("HYPR_HOST_DIR")' "$loader"
generated_line=$(grep -nF 'add_module_dir(generated_dir)' "$loader" | cut -d: -f1)
deployed_line=$(grep -nF 'add_module_dir(deployed_dir)' "$loader" | cut -d: -f1)
host_line=$(grep -nF 'add_module_dir(host_dir)' "$loader" | cut -d: -f1)
fallback_line=$(grep -nF 'add_module_dir(hypr_config)' "$loader" | tail -n1 | cut -d: -f1)
(( generated_line > deployed_line && deployed_line > host_line && host_line > fallback_line ))

grep -Fq 'mode = "preferred"' "$host/config/monitors.lua"
grep -Fq 'position = "auto"' "$host/config/monitors.lua"
grep -Fq 'scale = "1"' "$host/config/monitors.lua"
grep -Fq 'vrr = false' "$host/config/monitors.lua"
grep -Fq 'kb_layout = "us"' "$host/config/user-inputs.lua"
grep -Fq 'cycle-desktop-audio-output' "$common/config/user-binds.lua"
if grep -Fq 'HYPR_BIND(' "$host/config/hardware-binds.lua"; then exit 1; fi

printf '%s\n' 'PASS: los fragmentos Hypr generados tienen fallback portable seguro'
