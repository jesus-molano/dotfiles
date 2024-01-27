#!/bin/bash

yay -S ttf-cascadia-code-nerd
sudo pacman -S neovim ripgrep lazygit gdu bottom

git clone --depth 1 https://github.com/AstroNvim/AstroNvim ~/.config/nvim
nvim
