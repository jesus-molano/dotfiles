function dotf --description "Manage dotfiles with GNU Stow"
    set -l dotfiles_dir ~/dotfiles

    if test (count $argv) -eq 0
        echo "Usage: dotf <command> [packages...]"
        echo ""
        echo "Commands:"
        echo "  stow, s    [pkg...]  Stow packages (all if none specified)"
        echo "  unstow, u  <pkg...>  Unstow packages"
        echo "  restow, r  <pkg...>  Restow packages (unstow + stow)"
        echo "  list, l              List available packages"
        echo "  edit, e              Open dotfiles in editor"
        echo "  check, c   [pkg...]  Dry-run (show what would change)"
        return 0
    end

    switch $argv[1]
        case stow s
            if test (count $argv) -lt 2
                for pkg in (dotf list)
                    stow -d $dotfiles_dir -t ~ $pkg 2>/dev/null
                    and echo "  $pkg"
                    or echo "  $pkg"
                end
            else
                for pkg in $argv[2..]
                    stow -d $dotfiles_dir -t ~ $pkg
                    and echo "  $pkg"
                    or echo "  $pkg"
                end
            end
        case unstow u
            for pkg in $argv[2..]
                stow -d $dotfiles_dir -t ~ -D $pkg
                and echo "  $pkg"
                or echo "  $pkg"
            end
        case restow r
            if test (count $argv) -lt 2
                for pkg in (dotf list)
                    stow -d $dotfiles_dir -t ~ -R $pkg 2>/dev/null
                    and echo "  $pkg"
                    or echo "  $pkg"
                end
            else
                for pkg in $argv[2..]
                    stow -d $dotfiles_dir -t ~ -R $pkg
                    and echo "  $pkg"
                    or echo "  $pkg"
                end
            end
        case list l
            for item in $dotfiles_dir/*/
                set -l name (basename $item)
                # Skip non-package dirs
                string match -rq '^[A-Z]' $name; and continue
                echo $name
            end
        case edit e
            cd $dotfiles_dir
            and $EDITOR .
        case check c
            if test (count $argv) -lt 2
                for pkg in (dotf list)
                    echo "--- $pkg ---"
                    stow -d $dotfiles_dir -t ~ -n $pkg 2>&1
                end
            else
                for pkg in $argv[2..]
                    echo "--- $pkg ---"
                    stow -d $dotfiles_dir -t ~ -n $pkg 2>&1
                end
            end
        case '*'
            echo "Unknown command: $argv[1]"
            dotf
            return 1
    end
end
