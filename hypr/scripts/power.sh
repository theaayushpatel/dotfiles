#!/usr/bin/env zsh

choice=$(printf "Shutdown\nReboot\nSuspend\nCancel" | rofi -dmenu --prompt "Power")

case "$choice" in
  "Shutdown")
    systemctl poweroff
    ;;
  "Reboot")
    systemctl reboot
    ;;
  "Suspend")
    systemctl suspend
    ;;
  *)
    exit 0
    ;;
esac
