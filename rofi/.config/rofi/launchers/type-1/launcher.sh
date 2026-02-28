#!/usr/bin/env bash

## Author : Aditya Shakya (adi1090x)
## Github : @adi1090x
#
## Rofi   : Launcher (Modi Drun, Run, File Browser, Window)

dir="$HOME/.config/rofi/launchers/type-1"
theme='style-2'

exec rofi \
    -show drun \
    -matching fuzzy \
    -sort \
    -sorting-method fzf \
    -steal-focus \
    -theme "${dir}/${theme}.rasi"
