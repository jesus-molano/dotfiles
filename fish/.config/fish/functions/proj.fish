function proj --description "Quick project switcher with fzf"
    set -l search_dirs "$HOME/projects" "$HOME/work" "$HOME/.dotfiles" "$HOME/orca/workspaces"

    # Direct match via zoxide
    if test (count $argv) -gt 0
        if test (count $argv) -eq 1; and test -d "$argv[1]"
            cd "$argv[1]"
            return
        end
        if command -q zoxide
            set -l match (zoxide query -- $argv 2>/dev/null)
            if test -n "$match"
                cd "$match"
                return
            end
        end
        echo "Project not found: $argv" >&2
        return 1
    end

    # Collect existing search dirs
    set -l existing_dirs
    for dir in $search_dirs
        test -d $dir; and set -a existing_dirs $dir
    end

    if test (count $existing_dirs) -eq 0
        echo "No project directories found"
        return 1
    end

    # Interactive fzf selection
    set -l selection (find $existing_dirs -maxdepth 4 -name '.git' \( -type d -o -type f \) 2>/dev/null | \
        string replace -r '/\.git$' '' | sort -u | \
        fzf --prompt="Project > " --preview="ls --color=always -la {}" --height=40%)

    if test -n "$selection"
        cd $selection
        echo " $selection"
    end
end
