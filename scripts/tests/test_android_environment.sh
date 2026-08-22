#!/usr/bin/env bash
# shellcheck disable=SC2016 # Los literales verifican expansión diferida en config.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
environment="$repo_root/android/.config/environment.d/80-android-sdk.conf"
fish_config="$repo_root/android/.config/fish/conf.d/android.fish"
checker="$repo_root/android/.local/bin/android-sdk-check"

grep -Fqx 'ANDROID_HOME=${HOME}/.local/share/android-sdk' "$environment"
grep -Fqx 'ANDROID_SDK_ROOT=${HOME}/.local/share/android-sdk' "$environment"
grep -Fq '/emulator:${PATH}' "$environment"
grep -Fq 'fish_add_path --append "$android_sdk/platform-tools" "$android_sdk/cmdline-tools/latest/bin"' "$fish_config"
grep -Fq 'fish_add_path --append "$android_sdk/emulator"' "$fish_config"

test_root=$(mktemp -d)
trap 'find "$test_root" -depth -delete' EXIT
sdk="$test_root/sdk"
mkdir -p "$sdk/cmdline-tools/latest/bin" "$sdk/platform-tools" "$sdk/emulator" "$sdk/platforms/android-36"
for tool in cmdline-tools/latest/bin/sdkmanager cmdline-tools/latest/bin/avdmanager platform-tools/adb emulator/emulator; do
	: >"$sdk/$tool"
	chmod 755 "$sdk/$tool"
done
ANDROID_SDK_ROOT="$sdk" "$checker" >/dev/null
rm -f -- "$sdk/emulator/emulator"
if ANDROID_SDK_ROOT="$sdk" "$checker" >/dev/null 2>&1; then
	printf '%s\n' 'FAIL: android-sdk-check aceptó un SDK sin emulador.' >&2
	exit 1
fi

printf '%s\n' 'PASS: Android publica platform-tools, cmdline-tools y emulator cuando están disponibles'
