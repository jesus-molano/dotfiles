#!/usr/bin/env bash
# Auditoría portable: composición base, capabilities y bundles, sin perfiles.
# shellcheck disable=SC2015 # Los helpers ok/info/warn/fail siempre devuelven cero.
set -uo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mode=all
case "${1:-}" in
'') ;;
--config-only) mode=config ;;
--live-only) mode=live ;;
*) printf 'Uso: %s [--config-only|--live-only]\n' "$0" >&2; exit 2 ;;
esac

failures=0
warnings=0
ok() { printf '✓ %s\n' "$1"; }
info() { printf '· %s\n' "$1"; }
warn() { printf '! %s\n' "$1"; warnings=$((warnings + 1)); }
fail() { printf '✗ %s\n' "$1" >&2; failures=$((failures + 1)); }
check_command() { command -v "$2" >/dev/null 2>&1 && ok "$1" || fail "$1"; }
check() {
  local label=$1 output
  shift
  if output="$("$@" 2>&1)"; then ok "$label"; else printf '%s\n' "$output" >&2; fail "$label"; fi
}

plan_json=$(python3 "$repo_root/scripts/dotfiles_host.py" show --safe-defaults 2>&1) || {
  printf '%s\n' "$plan_json" >&2
  fail 'No se pudo resolver la composición local'
  plan_json='{}'
}
has() {
  python3 -c 'import json,sys; print("yes" if sys.argv[2] in json.load(sys.stdin).get(sys.argv[1], []) else "no")' "$1" "$2" <<<"$plan_json" 2>/dev/null | grep -qx yes
}
bundle_packages() {
  awk -F, -v scope="bundle:$1" '$1 == scope { print $3 }' "$repo_root/packages.csv"
}
check_bundle_packages() {
  local bundle=$1 package
  if ! has bundles "$bundle"; then info "Bundle $bundle no seleccionado"; return; fi
  while IFS= read -r package; do
    [[ -n "$package" ]] || continue
    pacman -Qq "$package" >/dev/null 2>&1 && ok "$bundle: $package instalado" || fail "$bundle seleccionado: falta $package"
  done < <(bundle_packages "$bundle")
}
check_minimum_versions() {
  local package minimum stable_minimum source version floor comparison
  command -v pacman >/dev/null 2>&1 || { fail 'Pacman no está disponible para comprobar versiones'; return; }
  command -v vercmp >/dev/null 2>&1 || { fail 'vercmp no está disponible para comprobar versiones'; return; }
  while IFS=$'\t' read -r package minimum stable_minimum source; do
    [[ -n "$package" ]] || continue
    version=$(pacman -Q "$package" 2>/dev/null | awk 'NR == 1 { print $2 }')
    if [[ -z "$version" ]]; then
      fail "Falta runtime compatible: $package >= $minimum ($source)"
      continue
    fi
    floor=$minimum
    if [[ "$stable_minimum" != - && "$version" != *_beta.* ]]; then
      floor=$stable_minimum
    fi
    comparison=$(vercmp "$version" "$floor")
    if [[ "$comparison" =~ ^-?[0-9]+$ ]] && ((comparison >= 0)); then
      ok "$package $version >= $floor"
    else
      fail "$package $version es anterior al mínimo $floor"
    fi
  done < <(python3 -c '
import json, sys
for package, item in sorted(json.load(sys.stdin).get("compatibility", {}).get("packages", {}).items()):
    print(package, item["minimum"], item.get("stable_minimum", "-"), item["source"], sep="\t")
' <<<"$plan_json")
}
check_snapshot() {
  local snapshot="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/hardware/capabilities.json" current
  [[ -f "$snapshot" ]] || { info 'Sin snapshot previo de hardware'; return; }
  current=$(python3 "$repo_root/scripts/dotfiles_host.py" detect 2>/dev/null || true)
  [[ -n "$current" ]] || { warn 'No se pudo actualizar la detección de hardware'; return; }
  if python3 - "$snapshot" "$current" <<'PY'
import json, sys
old = json.load(open(sys.argv[1], encoding="utf-8"))
new = json.loads(sys.argv[2])
keys = ("gpu_vendors", "monitors", "has_internal_panel", "backlights", "batteries", "pipewire", "openrgb")
raise SystemExit(0 if all(old.get(key) == new.get(key) for key in keys) else 1)
PY
  then ok 'Hardware coincide con el último snapshot'
  else warn 'El hardware cambió desde el snapshot; ejecuta dotf host refresh antes de aplicar preferencias'
  fi
}
check_rgb() {
  if ! has bundles rgb-openrgb; then info 'Bundle rgb-openrgb no seleccionado'; return; fi
  check_command 'OpenRGB disponible para rgb-openrgb' openrgb
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/reactive-rgb/config.conf"
  if [[ -r "$config" ]]; then ok 'Targets RGB locales presentes'
  else warn 'rgb-openrgb sin targets locales: el servicio debe permanecer desactivado'
  fi
  if systemctl --user is-enabled --quiet reactive-rgb.service 2>/dev/null; then
    [[ -r "$config" ]] && ok 'Servicio RGB habilitado con targets' || fail 'Servicio RGB habilitado sin targets exactos'
    local rgb_health
    if rgb_health="$("$HOME/.local/bin/reactive-rgb" health 2>/dev/null)" &&
      grep -Fxq 'health_status=ok' <<<"$rgb_health" &&
      grep -Fxq 'health_scope=liveness-with-hardware-on-change' <<<"$rgb_health" &&
      grep -Fxq 'health_fresh=1' <<<"$rgb_health"; then
      ok 'Reactive RGB activo y saludable'
    else
      warn 'Reactive RGB no informa salud reciente'
    fi
  else info 'Servicio RGB no habilitado'
  fi
}
check_backup() {
  if ! has bundles backup; then info 'Bundle backup no seleccionado'; return; fi
  check_command 'Restic disponible para backup' restic
  check_command 'rclone disponible para backup' rclone
  systemctl --user is-enabled --quiet restic-backup.timer restic-maintenance.timer 2>/dev/null && ok 'Timers Restic habilitados' || info 'Timers Restic no habilitados'
}
check_android() {
  if "$repo_root/android/.local/bin/android-sdk-check" >/dev/null 2>&1; then
    ok 'SDK Android CLI y emulador disponibles'
  else
    warn 'SDK Android externo incompleto; ejecuta just android-check'
  fi
}
check_base_workflows() {
	check 'Contrato de teclado Alt/Hyper y Kanata' "$repo_root/scripts/tests/test_keyboard_contract.sh"
	check 'Fallback portable de Hyprland' "$repo_root/scripts/tests/test_hypr_host_fallback.sh"
	check 'Resolución y generación del host' env PYTHONDONTWRITEBYTECODE=1 python "$repo_root/scripts/tests/test_dotfiles_host.py"
	check 'Versiones mínimas sin pins' "$repo_root/scripts/tests/test_runtime_compatibility.sh"
	check 'CLI dotf sin perfiles' "$repo_root/scripts/tests/test_dotf_function.sh"
	check 'Migración y rollback transaccional' "$repo_root/scripts/tests/test_install_transaction.sh"
	check 'Superficie y atajos portables' "$repo_root/scripts/tests/test_desktop_surface.sh"
  check 'Captura OCR a contexto' "$repo_root/scripts/tests/test_capture_context.sh"
  check 'Modo foco y demo reversible' "$repo_root/scripts/tests/test_desktop_focus_mode.sh"
  check 'Acciones locales del launcher' "$repo_root/scripts/tests/test_desktop_launcher_commands.sh"
  check 'Compartir con LocalSend' "$repo_root/scripts/tests/test_local_share.sh"
  check 'Launcher multimedia' "$repo_root/scripts/tests/test_desktop_launcher_media.sh"
  check 'Práctica de mecanografía' "$repo_root/scripts/tests/test_desktop_launcher_typing.sh"
  check 'Apariencias coordinadas' "$repo_root/scripts/tests/test_appearance_switch.sh"
  check 'Temas terminales generados' env PYTHONDONTWRITEBYTECODE=1 python "$repo_root/scripts/tests/test_terminal_theme_generation.py"
  check 'Colección de fondos al iniciar' "$repo_root/scripts/tests/test_start_noctalia_ready.sh"
  check 'Arranque único de 1Password' "$repo_root/scripts/tests/test_ensure_1password_tray.sh"
  check 'Paleta activa de Orca' "$repo_root/scripts/tests/test_orca_safe_settings.sh"
  check 'Orca en segundo plano' "$repo_root/scripts/tests/test_orca_background.sh"
  check 'Caja de herramientas de captura' "$repo_root/scripts/tests/test_capture_toolbox.sh"
  check 'Demo Studio' "$repo_root/scripts/tests/test_demo_studio.sh"
  check 'Puertos de desarrollo' "$repo_root/scripts/tests/test_dev_ports.sh"
  check 'Contexto de crashes' "$repo_root/scripts/tests/test_crash_context.sh"
  check 'Anchos de ventana' "$repo_root/scripts/tests/test_window_width.sh"
  check 'Migración de enlaces retirados' "$repo_root/scripts/tests/test_migrate_retired_desktop_links.sh"
  check 'Direct scanout reversible' "$repo_root/scripts/tests/test_direct_scanout_toggle.sh"
  check 'Configuración qutebrowser' env PYTHONDONTWRITEBYTECODE=1 python "$repo_root/scripts/tests/test_qutebrowser_config.py"
  check 'Enlaces Markdown qutebrowser' "$repo_root/scripts/tests/test_qutebrowser_yank_markdown.sh"
  check 'Kanata' kanata --check -c "$repo_root/kanata/.config/kanata/config.kbd"
}
check_optional_config() {
  if has bundles gaming-core; then
    check 'Sesión gaming sin notificaciones' "$repo_root/scripts/tests/test_game_run_dnd.sh"
  else info 'Checks gaming-core no seleccionados'; fi
  if has bundles gaming-launchers; then
    check 'Noctalia gaming' noctalia config validate "$repo_root/gaming-launchers/.config/noctalia/gaming.toml"
    check 'Launcher gaming por bundles' "$repo_root/scripts/tests/test_gaming_launcher.sh"
  else info 'Checks gaming-launchers no seleccionados'; fi
  if has bundles gaming-tools; then
    check 'Informes gaming' "$repo_root/scripts/tests/test_game_bench_report.sh"
  else info 'Checks gaming-tools no seleccionados'; fi
  if has bundles backup; then
    check 'Unidades Restic' "$repo_root/scripts/verify-restic-units.sh"
    check 'Backup portable' "$repo_root/scripts/tests/test_backup_portable.sh"
  else info 'Checks backup no seleccionados'; fi
  if has bundles rgb-openrgb; then
    check 'RGB térmico sin targets versionados' "$repo_root/scripts/tests/test_reactive_rgb.sh"
    check 'Unidad Reactive RGB' env HOME="$repo_root/rgb-openrgb" \
      systemd-analyze --user verify "$repo_root/rgb-openrgb/.config/systemd/user/reactive-rgb.service"
  else info 'Checks rgb-openrgb no seleccionados'; fi
  check 'Acciones audio genéricas' "$repo_root/scripts/tests/test_cycle_desktop_audio_output.sh"
  check 'Selector HDMI configurable' "$repo_root/scripts/tests/test_cycle_desktop_hdmi_audio.sh"
  check 'Audio configurado al iniciar' "$repo_root/scripts/tests/test_ensure_main_hdmi_audio.sh"
}
check_gaming_packages() {
  if ! has bundles gaming-core && ! has bundles gaming-launchers && ! has bundles gaming-tools; then
    info 'Paquetes gaming no seleccionados'
    return
  fi
  local -a packages=()
  mapfile -t packages < <(bundle_packages gaming-core; bundle_packages gaming-launchers; bundle_packages gaming-tools)
  ((${#packages[@]})) || { fail 'El manifiesto no declara paquetes gaming'; return; }
  ok "Manifiesto gaming resuelto (${#packages[@]} paquetes)"
}
check_nvidia_stack() {
  has capabilities gpu-nvidia || { info 'Stack NVIDIA no seleccionado'; return; }
  if command -v chwd >/dev/null 2>&1; then
    local chwd_profiles
    if chwd_profiles="$(LC_ALL=C chwd --list-installed 2>/dev/null)" && grep -Eqi 'nvidia[-_[:alnum:].+]*' <<<"$chwd_profiles"; then
      ok 'CHWD reconoce un perfil NVIDIA instalado'
    else
      warn 'CHWD no confirmó un perfil NVIDIA instalado'
    fi
  else
    info 'CHWD no está disponible para revisar NVIDIA'
  fi
  if nvidia-smi --query-gpu=name,driver_version --format=csv,noheader >/dev/null 2>&1; then
    ok 'NVIDIA operativo'
  else
    fail 'gpu-nvidia seleccionado pero nvidia-smi no puede consultar la GPU'
  fi
  if has bundles gaming-core; then
    pacman -Qq lib32-nvidia-utils lib32-vulkan-icd-loader >/dev/null 2>&1 && ok 'Runtime NVIDIA/Vulkan de 32 bits' || fail 'Falta runtime NVIDIA/Vulkan de 32 bits'
  else
    info 'Runtime NVIDIA de 32 bits no requerido sin gaming-core'
  fi
}
check_gaming_scheduler() {
  has bundles gaming-core || { info 'Scheduler gaming no seleccionado'; return; }
  if systemctl is-active --quiet ananicy-cpp.service; then ok 'ananicy-cpp activo'; else fail 'ananicy-cpp no está activo'; fi
  if pacman -Qq gamemode >/dev/null 2>&1 || command -v gamemoderun >/dev/null 2>&1 || pgrep -x gamemoded >/dev/null 2>&1; then
    warn 'GameMode coexiste con ananicy-cpp; no los envuelvas juntos'
  else
    ok 'Sin coexistencia activa de GameMode y ananicy-cpp'
  fi
  command -v game-performance >/dev/null 2>&1 && ok 'game-performance disponible' || fail 'game-performance no está disponible'
  if command -v powerprofilesctl >/dev/null 2>&1; then
    powerprofilesctl get >/dev/null 2>&1 && ok 'Perfil energético consultable' || fail 'No se pudo consultar el perfil energético'
  else
    info 'powerprofilesctl no disponible en este host'
  fi
  if [[ "$(cat /sys/kernel/sched_ext/state 2>/dev/null || true)" == enabled ]]; then ok 'sched-ext activo'; else info 'sched-ext sin scheduler activo'; fi
}
check_gaming_firmware_state() {
  has capabilities gpu-nvidia || { info 'Firmware NVIDIA no seleccionado'; return; }
  if command -v inxi >/dev/null 2>&1; then
    inxi -mxxx --no-host --filter --color 0 >/dev/null 2>&1 && ok 'Memoria consultable para auditoría' || warn 'No se pudo leer la memoria efectiva'
  else
    info 'inxi no disponible para auditar memoria'
  fi
  local bar_total bar_amount bar_unit
  bar_total="$(nvidia-smi -q 2>/dev/null | awk '/BAR1 Memory Usage/ { in_bar = 1; next } in_bar && /Total/ { print $(NF - 1), $NF; exit }')"
  read -r bar_amount bar_unit <<<"$bar_total"
  if [[ "$bar_amount" =~ ^[0-9]+$ ]]; then
    if [[ "$bar_unit" == GiB || "$bar_unit" == TiB || ( "$bar_unit" == MiB && "$bar_amount" -gt 256 ) ]]; then ok "BAR1 NVIDIA ampliada: $bar_total"; else warn "BAR1 NVIDIA limitada: $bar_total"; fi
  else info 'No se pudo determinar BAR1 NVIDIA'; fi
}
check_gaming_monitors() {
  has bundles gaming-core || { info 'Monitores gaming no seleccionados'; return; }
  [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || { info 'Monitor gaming no comprobado: Hyprland no está accesible'; return; }
  local monitor_json workspace_json
  monitor_json="$(hyprctl -j monitors 2>/dev/null)" || { fail 'No se pudieron consultar los monitores activos'; return; }
  workspace_json="$(hyprctl -j workspaces 2>/dev/null)" || { fail 'No se pudieron consultar los workspaces activos'; return; }
  if jq -e 'type == "array" and length > 0 and all(.[]; (.name | type) == "string" and (.activeWorkspace.id | type) == "number")' >/dev/null 2>&1 <<<"$monitor_json" && jq -e 'type == "array"' >/dev/null 2>&1 <<<"$workspace_json"; then
    ok 'Topología Hyprland disponible para gaming'
  else fail 'Topología Hyprland inválida para gaming'; fi
}
check_steam_filesystems() {
  has bundles gaming-core || { info 'Bibliotecas Steam no seleccionadas'; return; }
  local -a steam_paths=("$HOME/.local/share/Steam" "$HOME/.steam/steam" "$HOME/.var/app/com.valvesoftware.Steam/data/Steam") library_files=()
  local steam_path library_file resolved fstype found=0
  local -A seen_paths=()
  for steam_path in "${steam_paths[@]}"; do [[ -f "$steam_path/steamapps/libraryfolders.vdf" ]] && library_files+=("$steam_path/steamapps/libraryfolders.vdf"); done
  for library_file in "${library_files[@]}"; do while IFS= read -r steam_path; do [[ -n "$steam_path" ]] && steam_paths+=("$steam_path"); done < <(sed -nE 's/^[[:space:]]*"path"[[:space:]]*"([^"]+)".*/\1/p' "$library_file"); done
  for steam_path in "${steam_paths[@]}"; do
    [[ -d "$steam_path" ]] || continue; resolved="$(readlink -f -- "$steam_path" 2>/dev/null || true)"; [[ -n "$resolved" && -z "${seen_paths[$resolved]+x}" ]] || continue; seen_paths["$resolved"]=1; found=$((found + 1)); fstype="$(findmnt -n -o FSTYPE -T "$resolved" 2>/dev/null || true)"
    case "$fstype" in btrfs) ok "Biblioteca Steam en Btrfs: $resolved" ;; ntfs|ntfs3|fuseblk) fail "Biblioteca Steam en NTFS no admitida: $resolved" ;; *) warn "Biblioteca Steam fuera de Btrfs ($fstype): $resolved" ;; esac
  done
  ((found > 0)) || info 'Steam aún no tiene una biblioteca local que comprobar'
}
check_dualsense() {
  has bundles gaming-core || { info 'DualSense no requerido sin gaming-core'; return; }
  modinfo hid_playstation >/dev/null 2>&1 && ok 'Driver hid-playstation disponible' || info 'Driver hid-playstation no disponible (mando opcional)'
  systemctl is-active --quiet bluetooth.service && ok 'Bluetooth activo para mando' || warn 'Bluetooth no está activo; el mando queda disponible por USB'
  if grep -Eiq 'Name=.*(DualSense|Sony Interactive Entertainment.*Wireless Controller)' /proc/bus/input/devices 2>/dev/null || { command -v lsusb >/dev/null 2>&1 && lsusb | grep -Eiq '054c:(0ce6|0df2)'; }; then ok 'DualSense conectado'; else info 'DualSense no conectado (opcional)'; fi
}
check_nvidia_cache() {
  has capabilities gpu-nvidia || { info 'Caché NVIDIA no seleccionada'; return; }
  local cache_config="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d/90-nvidia-game-cache.conf" manager_cache=''
  if [[ ! -f "$cache_config" ]]; then fail "Falta configuración de caché NVIDIA: $cache_config"
  elif grep -qx '__GL_SHADER_DISK_CACHE=1' "$cache_config" && grep -qx '__GL_SHADER_DISK_CACHE_SIZE=12000000000' "$cache_config"; then ok 'Caché de shaders NVIDIA configurada'
  else fail 'La configuración de caché NVIDIA no coincide con la política'; fi
  if [[ "${__GL_SHADER_DISK_CACHE:-}" == 1 && "${__GL_SHADER_DISK_CACHE_SIZE:-}" == 12000000000 ]]; then ok 'Variables de caché NVIDIA cargadas en sesión'
  elif manager_cache="$(systemctl --user show-environment 2>/dev/null | grep -E '^__GL_SHADER_DISK_CACHE(=1|_SIZE=12000000000)$' || true)" && [[ "$manager_cache" == *'__GL_SHADER_DISK_CACHE=1'* && "$manager_cache" == *'__GL_SHADER_DISK_CACHE_SIZE=12000000000'* ]]; then ok 'Variables NVIDIA cargadas para UWSM'
  else warn 'La sesión aún no cargó variables de caché NVIDIA'; fi
}
check_ignored_nvidia_parameter() {
  has capabilities gpu-nvidia || return
  local kernel_log
  kernel_log="$(journalctl -b -k --no-pager 2>/dev/null || true)"
  [[ -n "$kernel_log" ]] || { info 'Journal del kernel no accesible'; return; }
  grep -Fq "nvidia: unknown parameter 'NVreg_UsePageAttributeTable' ignored" <<<"$kernel_log" && warn 'NVIDIA ignoró un parámetro conocido' || ok 'Sin parámetros NVIDIA ignorados conocidos'
}
check_backup_runtime() {
  has bundles backup || { info 'Runtime backup no seleccionado'; return; }
  local repository_file="${XDG_CONFIG_HOME:-$HOME/.config}/restic/repository"
  [[ -f "$HOME/.env.op" ]] && ok 'Referencias secretas locales presentes (sin leer)' || warn 'Faltan referencias secretas locales para Restic'
  [[ -s "$repository_file" && ! -L "$repository_file" ]] && ok 'Repositorio Restic local configurado (sin mostrarlo)' || fail 'Falta el repositorio Restic local generado'
  if systemctl --user is-enabled --quiet restic-backup.timer restic-maintenance.timer; then
    [[ -f "$HOME/.local/share/systemd/credentials/restic-password.cred" ]] && ok 'Credencial Restic cifrada presente (sin leer)' || fail 'Timers Restic activos sin credencial cifrada'
    ok 'Timers Restic activos'
  else
    [[ -f "$HOME/.local/share/systemd/credentials/restic-password.cred" ]] && ok 'Credencial Restic cifrada presente (sin leer)' || info 'Credencial Restic aún no creada'
    info 'Timers Restic no activados'
  fi
}
check_desktop_runtime() {
  local command plugin_list timer_manifest
  for command in zenity localsend wl-paste systemd-run tesseract zbarimg ffmpeg magick mpv ss coredumpctl; do command -v "$command" >/dev/null 2>&1 && ok "Base runtime: $command" || fail "Falta base runtime: $command"; done
  if has bundles local-ai; then
    command -v whisper-cli >/dev/null 2>&1 && ok 'Whisper disponible' || fail 'Falta whisper-cli para local-ai'
    command -v wtype >/dev/null 2>&1 && ok 'Pegado de dictado disponible' || fail 'Falta wtype para local-ai'
    pacman -Qq ggml-cpu ggml-vulkan >/dev/null 2>&1 && ok 'Backends GGML instalados' || fail 'Faltan backends GGML'
    [[ -s "${XDG_DATA_HOME:-$HOME/.local/share}/whisper.cpp/ggml-base.bin" ]] && ok 'Modelo Whisper base presente' || warn 'Falta modelo Whisper base'
  else info 'Runtime local-ai no seleccionado'; fi
  if has bundles productivity-extra; then for command in ttyper codexbar qmd; do command -v "$command" >/dev/null 2>&1 && ok "Productividad: $command" || fail "Falta productividad: $command"; done; else info 'Runtime productivity-extra no seleccionado'; fi
  command -v gpu-screen-recorder >/dev/null 2>&1 && ok 'gpu-screen-recorder disponible' || fail 'Falta gpu-screen-recorder'
  if command -v ddcutil >/dev/null 2>&1; then ddcutil detect --brief >/dev/null 2>&1 && ok 'DDC/CI responde' || warn 'No hay pantalla DDC/CI accesible'; else info 'ddcutil no disponible'; fi
  if plugin_list="$(noctalia msg plugins list 2>/dev/null)"; then
    grep -Fxq 'jamesfeeder/special-workspaces [community] 1.4.0 enabled' <<<"$plugin_list" && ok 'Noctalia Special Workspaces 1.4.0 habilitado' || fail 'Noctalia Special Workspaces cambió o no está habilitado'
    grep -Fxq 'noctalia/notes [official] 1.0.3 enabled' <<<"$plugin_list" && ok 'Noctalia Notes 1.0.3 habilitado' || fail 'Noctalia Notes 1.0.3 no está habilitado'
    timer_manifest="${XDG_DATA_HOME:-$HOME/.local/share}/noctalia/plugins/timer/plugin.toml"
    grep -Fxq 'noctalia/timer [local] 1.2.1 enabled' <<<"$plugin_list" && [[ -f "$timer_manifest" ]] && ok 'Noctalia Timer 1.2.1 habilitado' || fail 'Noctalia Timer 1.2.1 no está habilitado o desplegado'
    if has bundles productivity-extra; then grep -Fxq 'salemsayed/codexbar-meter [community] 1.0.0 enabled' <<<"$plugin_list" && ok 'Noctalia CodexBar 1.0.0 habilitado' || fail 'Noctalia CodexBar 1.0.0 no está habilitado'; fi
  else warn 'No se pudo consultar plugins Noctalia activos'; fi
}

if [[ "$mode" != live ]]; then
  printf 'Configuración reproducible\n'
  check_command 'Python 3 para resolver el host' python3
  check_command 'GNU Stow disponible' stow
  check_command 'Hyprland disponible' Hyprland
  check_command 'Noctalia disponible' noctalia
  check_minimum_versions
  if command -v noctalia >/dev/null 2>&1; then
    noctalia config validate "$repo_root/noctalia/.config/noctalia/config.toml" >/dev/null 2>&1 && ok 'Noctalia base válido' || fail 'Noctalia base inválido'
  fi
	check 'Hyprland host genérico' env \
		HYPR_HOST_DIR="$repo_root/hypr-host/.config/hypr" \
		DOTFILES_DEPLOYED_HYPR_DIR="$repo_root/hypr-host/.config/hypr" \
		DOTFILES_GENERATED_HYPR_DIR="$repo_root/hypr-host/.config/hypr" \
		Hyprland --verify-config -c "$repo_root/hypr-common/.config/hypr/hyprland.lua"
	check_base_workflows
	check_optional_config
  for bundle in gaming-core gaming-launchers gaming-tools backup rgb-openrgb local-ai productivity-extra; do check_bundle_packages "$bundle"; done
  if has capabilities gpu-nvidia; then
    command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi --query-gpu=name --format=csv,noheader >/dev/null 2>&1 && ok 'Capacidad gpu-nvidia operativa' || fail 'Capacidad gpu-nvidia seleccionada pero no operativa'
  else info 'Capacidad gpu-nvidia no seleccionada'
  fi
  "$repo_root/scripts/tests/test_qmd_template.sh" && ok 'Plantilla QMD portable' || fail 'Plantilla QMD no portable'
	check 'Stow hermético resuelto' "$repo_root/scripts/stow-lint.sh"
  git -C "$repo_root" diff --check && ok 'Whitespace Git' || fail 'Whitespace Git'
fi

if [[ "$mode" != config ]]; then
  printf '\nHost vivo\n'
  check_snapshot
	check 'Base CachyOS' "$repo_root/hypr-common/.local/bin/hypr-check-cachyos-base"
	if command -v noctalia >/dev/null 2>&1; then
		noctalia_config="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia"
		if [[ -d "$noctalia_config" ]]; then
			check 'Noctalia desplegado válido, incluidos overrides de host' noctalia config validate "$noctalia_config"
		else
			fail 'Falta el directorio Noctalia desplegado'
		fi
	else
		fail 'Noctalia no está disponible en el host vivo'
	fi
	system_failed="$(systemctl --failed --no-legend --plain 2>/dev/null || true)"
	[[ -z "$system_failed" ]] && ok 'Sin unidades del sistema fallidas' || fail 'Hay unidades del sistema fallidas'
	user_failed="$(systemctl --user --failed --no-legend --plain 2>/dev/null || true)"
	[[ -z "$user_failed" ]] && ok 'Sin unidades de usuario fallidas' || fail 'Hay unidades de usuario fallidas'
	systemctl is-enabled --quiet btrfs-scrub@-.timer && ok 'Scrub Btrfs periódico activo' || warn 'Scrub Btrfs periódico desactivado'
	systemctl is-enabled --quiet smartd.service && ok 'SMART periódico activo' || warn 'smartd.service desactivado'
	if journalctl -b --no-pager 2>/dev/null | grep -q 'Timed out waiting for device /dev/tpm'; then warn 'El arranque esperó por un TPM inexistente'; else ok 'Sin timeout TPM'; fi
  if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    if hyprctl configerrors 2>/dev/null | grep -q .; then fail 'Hyprland tiene errores activos'; else ok 'Hyprland sin errores activos'; fi
  else info 'Hyprland no está disponible en esta sesión'
  fi
  check_rgb
  check_backup
  check_desktop_runtime
  check_backup_runtime
  check_android
  check_gaming_packages
  check_nvidia_stack
  check_gaming_scheduler
  check_gaming_firmware_state
  check_gaming_monitors
  check_steam_filesystems
  check_dualsense
  check_nvidia_cache
  check_ignored_nvidia_parameter
  if has bundles local-ai; then check_command 'Whisper disponible para local-ai' whisper-cli; else info 'Bundle local-ai no seleccionado'; fi
  if has bundles productivity-extra; then check_command 'QMD disponible para productivity-extra' qmd; else info 'Bundle productivity-extra no seleccionado'; fi
  if has bundles gaming-core; then
    check_command 'Steam disponible para gaming-core' steam
    check_command 'Gamescope disponible para gaming-core' gamescope
  else info 'Bundle gaming-core no seleccionado'
  fi
fi

printf '\nResultado: %d fallo(s), %d aviso(s)\n' "$failures" "$warnings"
((failures == 0))
