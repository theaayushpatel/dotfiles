#!/usr/bin/env bash

# 1. Search both paths. Add '--hidden' if you want to see dotfiles.
selection=$(fd . "$HOME" "/mnt/volume" | rofi -dmenu -i -p "Search Files:")


# 2. Open the selection (file or folder) directly
if [[ -n "$selection" ]]; then
    if [[ -d "$selection" ]]; then
        dolphin "$selection" &
    else
        xdg-open "$selection" &
    fi
fi
