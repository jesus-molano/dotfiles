source /usr/share/cachyos-zsh-config/cachyos-config.zsh

# Load dev keys from 1Password
if command -v op &>/dev/null; then
  eval "$(op inject -i ~/.env.op 2>/dev/null)"
fi

eval "$(zoxide init zsh)"
