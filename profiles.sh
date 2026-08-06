#!/usr/bin/env bash

# Fuente canónica de módulos Stow por perfil. Este archivo se carga desde
# install.sh, el justfile y las validaciones herméticas.
readonly -a COMMON_MODULES=(
	codex fish fonts ghostty git hypr-common kanata mimeapps
	noctalia nvim qutebrowser shell starship vscode zellij
)
readonly -a WORKSTATION_MODULES=(hypr-laptop)
readonly -a DESKTOP_MODULES=(hypr-desktop gaming backup)

profile_is_valid() {
	[[ "${1:-}" == workstation || "${1:-}" == desktop ]]
}

profile_modules() {
	local profile=${1:-}
	profile_is_valid "$profile" || return 2

	printf '%s\n' "${COMMON_MODULES[@]}"
	if [[ "$profile" == workstation ]]; then
		printf '%s\n' "${WORKSTATION_MODULES[@]}"
	else
		printf '%s\n' "${DESKTOP_MODULES[@]}"
	fi
}

all_home_modules() {
	printf '%s\n' \
		"${COMMON_MODULES[@]}" \
		"${WORKSTATION_MODULES[@]}" \
		"${DESKTOP_MODULES[@]}"
}

home_module_is_allowed() {
	local requested=${1:-} module
	while IFS= read -r module; do
		[[ "$module" == "$requested" ]] && return 0
	done < <(all_home_modules)
	return 1
}
