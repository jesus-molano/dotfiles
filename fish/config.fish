if status is-interactive
    # Commands to run in interactive sessions can go here
    set fish_greeting
    set -x PATH $HOME/.cargo/bin $PATH 
    source $HOME/.cargo/env

    nvm use lts
    clear
    source ~/.config/fish/alias/cfg.fish
    source ~/.config/fish/alias/exa.fish
    starship init fish | source
end

