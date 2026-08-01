source /usr/share/cachyos-zsh-config/cachyos-config.zsh

export EDITOR=nvim
export VISUAL=nvim
export SUDO_EDITOR=nvim

# fnm (Fast Node Manager)
export FNM_DIR="$HOME/.local/share/fnm"
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
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

# Abreviaturas sin ocultar comandos comunes.
alias p='pnpm'
alias px='pnpm dlx'
alias g='git'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline -20'
alias lg='lazygit'

with-secrets() {
  if (($# == 0)); then
    print -u2 'Uso: with-secrets <comando> [argumentos...]'
    return 2
  fi
  command -v op >/dev/null 2>&1 || {
    print -u2 '1Password CLI no está instalado.'
    return 1
  }
  local env_file="$HOME/.env.op"
  [[ -f "$env_file" ]] || {
    print -u2 "No existe el archivo de referencias: $env_file"
    return 1
  }
  command op run --env-file "$env_file" -- "$@"
}
