function fish_user_key_bindings
    # Alt+. — insert last argument from previous command (like bash/zsh)
    bind \e. history-token-search-backward

    # Ctrl+Z — toggle foreground/background job
    bind \cz 'fg 2>/dev/null; commandline -f repaint'
end
