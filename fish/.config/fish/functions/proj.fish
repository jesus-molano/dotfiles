function proj --description "Quick project switcher with fzf"
    set -l search_dirs ~/projects ~/work ~/dotfiles

    # Direct match via zoxide
    if test (count $argv) -gt 0
        z $argv
        return
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
    set -l selection (find $existing_dirs -maxdepth 2 -name '.git' -type d 2>/dev/null | \
        string replace '/.git' '' | sort | \
        fzf --prompt="Project > " --preview="ls --color=always -la {}" --height=40%)

    if test -n "$selection"
        cd $selection
        echo " $selection"
    end
end
