function dotf --description "Manage the resolved dotfiles host"
    set -l config_home "$HOME/.config"
    if set -q XDG_CONFIG_HOME
        set config_home "$XDG_CONFIG_HOME"
    end

    set -l registry "$config_home/dotfiles/repo"
    set -l dotfiles_dir
    if test -r "$registry"
        read dotfiles_dir < "$registry"
    end
    if not string match --quiet --regex '^/' -- "$dotfiles_dir"; or not test -f "$dotfiles_dir/justfile"
        set dotfiles_dir "$HOME/.dotfiles"
    end

    set -l justfile "$dotfiles_dir/justfile"
    set -l host_cli "$dotfiles_dir/scripts/dotfiles_host.py"

    if test (count $argv) -eq 0
        echo "Usage: dotf <command>"
        echo ""
        echo "Commands:"
        echo "  apply, a       Simulate and apply the resolved host"
        echo "  remove, u      Remove links for the resolved host"
        echo "  check, c       Run a verbose dry-run"
        echo "  status         Check the complete resolved host"
        echo "  doctor         Audit configuration and live capabilities"
        echo "  packages       List resolved packages and Flatpaks"
        echo "  host           Detect, configure, show, refresh, export or rollback"
        echo "  list, l        List base modules, bundles and selected capabilities"
        echo "  edit, e        Open the canonical checkout"
        return 0
    end

    if not test -f "$justfile"
        echo "Dotfiles checkout not found. Expected registry: $registry" >&2
        return 1
    end

    switch $argv[1]
        case apply a stow s restow r
            test (count $argv) -eq 1; or begin
                echo "Usage: dotf apply" >&2
                return 2
            end
            command just --justfile "$justfile" apply
        case remove unstow u
            test (count $argv) -eq 1; or begin
                echo "Usage: dotf remove" >&2
                return 2
            end
            command just --justfile "$justfile" remove
        case check c
            test (count $argv) -eq 1; or begin
                echo "Usage: dotf check" >&2
                return 2
            end
            command just --justfile "$justfile" check
        case status
            test (count $argv) -eq 1; or begin
                echo "Usage: dotf status" >&2
                return 2
            end
            command just --justfile "$justfile" status
        case doctor
            test (count $argv) -eq 1; or begin
                echo "Usage: dotf doctor" >&2
                return 2
            end
            command just --justfile "$justfile" doctor
        case packages
            test (count $argv) -eq 1; or begin
                echo "Usage: dotf packages" >&2
                return 2
            end
            command just --justfile "$justfile" packages
        case host
            test -x "$host_cli"; or begin
                echo "Host configuration tool not found: $host_cli" >&2
                return 1
            end
            command "$host_cli" $argv[2..-1]
        case list l
            command just --justfile "$justfile" list
        case edit e
            cd "$dotfiles_dir"
            and command $EDITOR .
        case '*'
            echo "Unknown command: $argv[1]" >&2
            dotf
            return 1
    end
end
