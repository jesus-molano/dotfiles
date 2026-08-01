function dotf --description "Manage dotfiles with GNU Stow"
    set -l dotfiles_dir "$HOME/.dotfiles"
    set -l justfile "$dotfiles_dir/justfile"

    if test (count $argv) -eq 0
        echo "Usage: dotf <command> [workstation|module]"
        echo ""
        echo "Commands:"
        echo "  apply, a   <target>  Simulate and apply an allowed target"
        echo "  remove, u  <target>  Remove links for an allowed target"
        echo "  check, c   <target>  Verbose dry-run"
        echo "  status               Check the workstation profile"
        echo "  list, l              List allowed targets"
        echo "  edit, e              Open dotfiles in the editor"
        return 0
    end

    if not test -f "$justfile"
        echo "Dotfiles justfile not found: $justfile" >&2
        return 1
    end

    switch $argv[1]
        case apply a stow s restow r
            if test (count $argv) -ne 2
                echo "Usage: dotf apply <workstation|module>" >&2
                return 2
            end
            command just --justfile "$justfile" apply "$argv[2]"
        case remove unstow u
            if test (count $argv) -ne 2
                echo "Usage: dotf remove <workstation|module>" >&2
                return 2
            end
            command just --justfile "$justfile" remove "$argv[2]"
        case list l
            command just --justfile "$justfile" list
        case edit e
            cd "$dotfiles_dir"
            and command $EDITOR .
        case check c
            if test (count $argv) -ne 2
                echo "Usage: dotf check <workstation|module>" >&2
                return 2
            end
            command just --justfile "$justfile" check "$argv[2]"
        case status
            command just --justfile "$justfile" status
        case '*'
            echo "Unknown command: $argv[1]"
            dotf
            return 1
    end
end
