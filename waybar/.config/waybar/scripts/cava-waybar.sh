#!/usr/bin/env bash
cava -p <(cat <<EOF
[general]
bars = 12
framerate = 30
autosens = 1
noise_reduction = 0.77

[input]
method = pipewire
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
bar_delimiter = 59
EOF
) | while IFS=';' read -ra values; do
    bars=""
    for val in "${values[@]}"; do
        case $val in
            0) bars+="▁";;
            1) bars+="▂";;
            2) bars+="▃";;
            3) bars+="▄";;
            4) bars+="▅";;
            5) bars+="▆";;
            6) bars+="▇";;
            7) bars+="█";;
        esac
    done
    echo "$bars"
done
