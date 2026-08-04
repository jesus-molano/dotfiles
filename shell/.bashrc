# shellcheck shell=bash
#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

export EDITOR=nvim
export VISUAL=nvim
export SUDO_EDITOR=nvim

if command -v mise >/dev/null 2>&1; then
	eval "$(mise activate bash)"
fi

export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
*":$PNPM_HOME:"*) ;;
*) export PATH="$PNPM_HOME:$PATH" ;;
esac

case ":$PATH:" in
*":$HOME/.local/bin:"*) ;;
*) export PATH="$HOME/.local/bin:$PATH" ;;
esac

if [[ -S "$HOME/.1password/agent.sock" ]]; then
	export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
fi

if command -v zoxide >/dev/null 2>&1; then
	eval "$(zoxide init bash)"
fi
if command -v direnv >/dev/null 2>&1; then
	eval "$(direnv hook bash)"
fi
if command -v atuin >/dev/null 2>&1; then
	eval "$(atuin init bash --disable-ai)"
fi

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
