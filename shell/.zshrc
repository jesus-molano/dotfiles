source /usr/share/cachyos-zsh-config/cachyos-config.zsh

export EDITOR=nvim
export VISUAL=nvim
export SUDO_EDITOR=nvim

# mise conserva .node-version/.nvmrc y centraliza runtimes por proyecto.
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
if [[ ":$PATH:" != *":$PNPM_HOME:"* ]]; then
  export PATH="$PNPM_HOME:$PATH"
fi

# Local binaries
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

if [[ -S "$HOME/.1password/agent.sock" ]]; then
  export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# direnv
if command -v direnv &>/dev/null; then
  eval "$(direnv hook zsh)"
fi
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh --disable-ai)"
fi

# Abreviaturas sin ocultar comandos comunes.
alias p='pnpm'
alias px='pnpm dlx'
alias g='git'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline -20'
alias lg='lazygit'

with-secrets() {
  command "$HOME/.local/bin/with-secrets" "$@"
}
