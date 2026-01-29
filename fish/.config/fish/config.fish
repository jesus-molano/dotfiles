source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
function fish_greeting
end

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
# direnv
if command -q direnv
    direnv hook fish | source
end

zoxide init fish | source
starship init fish | source
