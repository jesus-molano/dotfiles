#!/bin/bash

# Open the video in mpv, in a new window detached from the terminal.
# This script is meant to be used from qutebrowser.
#

URL=$(echo "$QUTE_URL" | awk -F'[?]' '{print $1}')
youtube-dl -g -f best "$URL" | xargs mpv --force-window=immediate
