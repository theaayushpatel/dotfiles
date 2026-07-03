#!/usr/bin/env zsh

choice=$(printf "Open Wi-Fi settings\nOpen NM menu\nRestart NetworkManager\nCancel" | rofi -dmenu --prompt "Network")

case "$choice" in
  "Open Wi-Fi settings")
    nm-connection-editor
    ;;
  "Open NM menu")
    zsh -lc 'kitty -e nmtui'
    ;;
  "Restart NetworkManager")
    pkexec systemctl restart NetworkManager
    ;;
  *)
    exit 0
    ;;
esac