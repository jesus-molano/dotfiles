#!/usr/bin/env bash
YT_CLASS="com.github.th_ch.youtube_music"

window=$(hyprctl clients -j | jq -r ".[] | select(.class == \"$YT_CLASS\") | .address" | head -1)

if [[ -n "$window" ]]; then
    ws=$(hyprctl activeworkspace -j | jq '.id')
    hyprctl dispatch movetoworkspacesilent "$ws,class:$YT_CLASS"
    hyprctl dispatch focuswindow "class:$YT_CLASS"
else
    youtube-music &
fi
