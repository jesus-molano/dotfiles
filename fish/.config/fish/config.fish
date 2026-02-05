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

# 1Password secrets — run `secrets` to load on demand

zoxide init fish | source
starship init fish | source
fish_add_path -g "$HOME/.local/bin"

# Dev abbreviations
abbr -a dev 'pnpm dev'
abbr -a build 'pnpm build'
abbr -a lint 'pnpm lint'
abbr -a test 'pnpm test'
abbr -a g 'git'
abbr -a gs 'git status'
abbr -a gd 'git diff'
abbr -a gl 'git log --oneline -20'
abbr -a lg 'lazygit'
