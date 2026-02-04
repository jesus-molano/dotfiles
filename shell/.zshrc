source /usr/share/cachyos-zsh-config/cachyos-config.zsh

# Load dev keys from 1Password
if command -v op &>/dev/null; then
  eval "$(op inject -i ~/.env.op 2>/dev/null)"
fi

# fnm (Fast Node Manager) — needed for Claude Code
export FNM_PATH="$HOME/.local/share/fnm"
if [[ -d "$FNM_PATH" ]]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env)"
fi

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
if [[ -d "$PNPM_HOME" ]]; then
  export PATH="$PNPM_HOME:$PATH"
fi

# Local binaries
export PATH="$HOME/.local/bin:$PATH"

eval "$(zoxide init zsh)"
