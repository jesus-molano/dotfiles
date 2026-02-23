#!/usr/bin/env bash

CAVA_CONFIG="/tmp/cava-waybar.conf"

cat > "$CAVA_CONFIG" <<EOF
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

cava -p "$CAVA_CONFIG" | while IFS=';' read -ra values; do
    bars=""
    silent=true
    for val in "${values[@]}"; do
        case $val in
            0) bars+="▁";;
            1) bars+="▂"; silent=false;;
            2) bars+="▃"; silent=false;;
            3) bars+="▄"; silent=false;;
            4) bars+="▅"; silent=false;;
            5) bars+="▆"; silent=false;;
            6) bars+="▇"; silent=false;;
            7) bars+="█"; silent=false;;
        esac
    done
    if $silent; then
        echo ""
    else
        echo "$bars"
    fi
done
