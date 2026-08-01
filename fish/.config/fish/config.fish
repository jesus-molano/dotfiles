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

# npm global
fish_add_path -g "$HOME/.npm-global/bin"

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
if test -S "$HOME/.1password/agent.sock"
    set -gx SSH_AUTH_SOCK "$HOME/.1password/agent.sock"
end

if command -q zoxide
    zoxide init fish | source
end
if command -q starship
    starship init fish | source
end
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

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
