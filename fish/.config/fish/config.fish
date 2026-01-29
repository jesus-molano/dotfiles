source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

# fnm (Fast Node Manager)
set -gx FNM_PATH "$HOME/.local/share/fnm"
if test -d "$FNM_PATH"
    fish_add_path -g "$FNM_PATH"
    fnm env --shell fish | source
end

# pnpm
set -gx PNPM_HOME "$HOME/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
    fish_add_path -g "$PNPM_HOME"
end
starship init fish | source
