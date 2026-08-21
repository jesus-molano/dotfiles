#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
doctor="$repo_root/scripts/doctor.sh"

test -x "$doctor"
if grep -Eq '(desktop|workstation)[[:space:]]*[|]' "$doctor"; then exit 1; fi
grep -Fq "env HOME=\"\$repo_root/rgb-openrgb\"" "$doctor"
if grep -Eq '/home/[^[:space:]]+|HDMI-A-[0-9]|pci-[0-9]|TUF GAMING|NZXT Smart' "$doctor"; then exit 1; fi
grep -Fq "Bundle \$bundle no seleccionado" "$doctor"
grep -Fq "\$bundle seleccionado: falta \$package" "$doctor"
grep -Fq 'Servicio RGB habilitado sin targets exactos' "$doctor"
grep -Fq 'El hardware cambió desde el snapshot' "$doctor"
grep -Fq 'Capacidad gpu-nvidia no seleccionada' "$doctor"
grep -Fq 'check_base_workflows' "$doctor"
grep -Fq 'check_optional_config' "$doctor"
grep -Fq 'Scrub Btrfs periódico' "$doctor"
grep -Fq 'ananicy-cpp activo' "$doctor"
grep -Fq 'check_steam_filesystems' "$doctor"
grep -Fq 'check_dualsense' "$doctor"
grep -Fq 'check_nvidia_cache' "$doctor"
grep -Fq 'check_backup_runtime' "$doctor"
grep -Fq 'check_desktop_runtime' "$doctor"
grep -Fq 'check_minimum_versions' "$doctor"
grep -Fq 'Bundle gaming-core no seleccionado' "$doctor"

printf '%s\n' 'PASS: doctor clasifica base, bundles, capacidades y hardware sin perfiles'
