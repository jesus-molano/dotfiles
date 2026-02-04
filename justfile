# Dotfiles management with GNU Stow

dotfiles_dir := env_var("HOME") / "dotfiles"

# List all stow packages
list:
    @for dir in {{dotfiles_dir}}/*/; do \
        pkg="$(basename "$dir")"; \
        case "$pkg" in [A-Z]*|justfile) continue;; esac; \
        echo "$pkg"; \
    done

# Stow packages (all if none specified)
stow *packages:
    #!/usr/bin/env bash
    cd {{dotfiles_dir}}
    if [ -z "{{packages}}" ]; then
        for dir in */; do
            pkg="${dir%/}"
            case "$pkg" in [A-Z]*) continue;; esac
            stow -t ~ "$pkg" 2>/dev/null && echo "✓ $pkg" || echo "✗ $pkg"
        done
    else
        for pkg in {{packages}}; do
            stow -t ~ "$pkg" && echo "✓ $pkg" || echo "✗ $pkg"
        done
    fi

# Unstow packages
unstow +packages:
    #!/usr/bin/env bash
    cd {{dotfiles_dir}}
    for pkg in {{packages}}; do
        stow -t ~ -D "$pkg" && echo "✓ unstowed $pkg" || echo "✗ $pkg"
    done

# Restow packages (unstow + stow) — useful after changes
restow *packages:
    #!/usr/bin/env bash
    cd {{dotfiles_dir}}
    if [ -z "{{packages}}" ]; then
        for dir in */; do
            pkg="${dir%/}"
            case "$pkg" in [A-Z]*) continue;; esac
            stow -t ~ -R "$pkg" 2>/dev/null && echo "✓ $pkg" || echo "✗ $pkg"
        done
    else
        for pkg in {{packages}}; do
            stow -t ~ -R "$pkg" && echo "✓ $pkg" || echo "✗ $pkg"
        done
    fi

# Dry-run: show what would change
check *packages:
    #!/usr/bin/env bash
    cd {{dotfiles_dir}}
    if [ -z "{{packages}}" ]; then
        for dir in */; do
            pkg="${dir%/}"
            case "$pkg" in [A-Z]*) continue;; esac
            echo "--- $pkg ---"
            stow -t ~ -n "$pkg" 2>&1
        done
    else
        for pkg in {{packages}}; do
            echo "--- $pkg ---"
            stow -t ~ -n "$pkg" 2>&1
        done
    fi
