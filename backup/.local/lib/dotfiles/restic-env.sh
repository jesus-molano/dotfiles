#!/usr/bin/env bash

# Load the unversioned repository selected for this host. The file contains one
# literal Restic repository value; it is data and is never evaluated as shell.
load_dotfiles_restic_repository() {
	[[ -n ${RESTIC_REPOSITORY:-} ]] && return 0
	local repository_file="${XDG_CONFIG_HOME:-$HOME/.config}/restic/repository"
	local -a repositories=()
	[[ -f "$repository_file" && ! -L "$repository_file" ]] || return 1
	mapfile -t repositories <"$repository_file"
	((${#repositories[@]} == 1)) || return 1
	[[ -n "${repositories[0]}" && "${repositories[0]}" != *$'\r'* ]] || return 1
	export RESTIC_REPOSITORY="${repositories[0]}"
}
