-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
hl.on("hyprland.start", function () 
--   hl.exec_cmd(terminal)
--   hl.exec_cmd("nm-applet")
--   hl.exec_cmd("waybar & hyprpaper & firefox")
   hl.exec_cmd("waybar")
   hl.exec_cmd("swaync")
   hl.exec_cmd("spotify")
   hl.exec_cmd("wl-paste --type text --watch cliphist store &")
   hl.exec_cmd("wl-paste --type image --watch cliphist store &")
   hl.exec_cmd("discord --start-minimized")
   hl.exec_cmd("zapzap")
   hl.exec_cmd("spotify")
end)