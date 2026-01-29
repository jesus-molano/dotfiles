#!/usr/bin/env bash
class=$(hyprctl activewindow -j | jq -r '.class')
case "$class" in
    kitty|Alacritty|foot|org.wezfurlong.wezterm|com.mitchellh.ghostty)
        hyprctl dispatch sendshortcut "CTRL SHIFT, c,"
        ;;
    *)
        hyprctl dispatch sendshortcut "CTRL, c,"
        ;;
esac
