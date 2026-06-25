#!/usr/bin/env bash

# 1. Search both paths. Add '--hidden' if you want to see dotfiles.
selection=$(fd --type f . "$HOME" "/mnt/volume" | rofi -dmenu -i -p "Search Files:")


# 2. Open the selection (file or folder) directly
if [[ -n "$selection" ]]; then
    xdg-open "$selection"
fi
