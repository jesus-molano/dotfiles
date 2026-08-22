# SDK local y portable. Los directorios pueden no existir tras una instalación
# nueva: fish_add_path los ignora hasta que el bootstrap de Android los cree.
set -l android_sdk "$HOME/.local/share/android-sdk"
if test -d "$android_sdk"
    fish_add_path --append "$android_sdk/platform-tools" "$android_sdk/cmdline-tools/latest/bin"
    if test -d "$android_sdk/emulator"
        fish_add_path --append "$android_sdk/emulator"
    end
end
