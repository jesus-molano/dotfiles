# Native Windows adapter

- Use PowerShell and native paths. Do not assume WSL, Bash, Stow or symlinks.
- Respect managed policies and corporate configuration. Never bypass them.
- Do not run Hyprland, Pacman, Polkit, systemd or other Linux-only tools.
- Use Git and `gh` when available. Inspect the environment before installing tools.
