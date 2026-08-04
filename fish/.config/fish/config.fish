source /usr/share/cachyos-fish-config/cachyos-config.fish

# Editor común para shell, Git, Codex y comandos elevados.
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx SUDO_EDITOR nvim

# Sin saludo adicional.
function fish_greeting
end

# mise conserva .node-version/.nvmrc y centraliza runtimes por proyecto.
if command -q mise
    mise activate fish | source
end

# Binarios globales explícitos de pnpm. La versión de Node la decide mise.
set -gx PNPM_HOME "$HOME/.local/share/pnpm"
fish_add_path -g "$PNPM_HOME"

# direnv
if command -q direnv
    direnv hook fish | source
end

# El agente SSH no exporta secretos de aplicación al shell.
if test -S "$HOME/.1password/agent.sock"
    set -gx SSH_AUTH_SOCK "$HOME/.1password/agent.sock"
end

if command -q zoxide
    zoxide init fish | source
end
if command -q starship
    starship init fish | source
end
if status is-interactive; and command -q atuin
    atuin init fish --disable-ai | source
end
fish_add_path -g "$HOME/.local/bin"

# Abreviaturas sin reemplazar comandos comunes como test, build o lint.
abbr -a p pnpm
abbr -a px 'pnpm dlx'
abbr -a g 'git'
abbr -a gs 'git status'
abbr -a gd 'git diff'
abbr -a gl 'git log --oneline -20'
abbr -a lg 'lazygit'
