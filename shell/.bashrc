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

export FNM_DIR="$HOME/.local/share/fnm"
if command -v fnm >/dev/null 2>&1; then
	eval "$(fnm env --use-on-cd --shell bash)"
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

alias p='pnpm'
alias px='pnpm dlx'
alias g='git'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline -20'
alias lg='lazygit'

with-secrets() {
	if (($# == 0)); then
		printf 'Uso: with-secrets <comando> [argumentos...]\n' >&2
		return 2
	fi
	command -v op >/dev/null 2>&1 || {
		printf '1Password CLI no está instalado.\n' >&2
		return 1
	}
	local env_file="$HOME/.env.op"
	[[ -f "$env_file" ]] || {
		printf 'No existe el archivo de referencias: %s\n' "$env_file" >&2
		return 1
	}
	command op run --env-file "$env_file" -- "$@"
}
