#!/usr/bin/env python3
"""
Dynamic Quickshell Panel Auto-Centering Toggler for Waybar.
Finds the target Waybar module's exact center on the active monitor,
then invokes Quickshell IPC to display the panel centered at that location.
"""
import sys
import os
import json
import re
import glob
import socket
import subprocess

CONFIG_PATH = os.path.expanduser("~/.config/waybar/config.jsonc")
CACHE_FILE = "/tmp/waybar_module_centers.json"

PANEL_TO_MODULES = {
    "clock": ["clock"],
    "network": ["network"],
    "bluetooth": ["bluetooth"],
    "brightness": ["backlight"],
    "audio": ["pulseaudio#output", "pulseaudio#input", "pulseaudio"],
    "power": ["battery", "power-profiles-daemon", "custom/power"],
    "media": ["mpris"],
}

DEFAULT_MODULE_CENTERS = {
    "clock": 120,
    "network": 1436,
    "bluetooth": 1521,
    "brightness": 1565,
    "audio": 1722,
    "power": 1876,
    "media": 960,
}

def get_hypr_info():
    """Retrieve cursor position and monitor geometry from Hyprland."""
    cursor = None
    # 1. Direct unix socket (fastest, <1ms)
    try:
        sock_paths = glob.glob(os.environ.get("XDG_RUNTIME_DIR", "") + "/hypr/*/.socket.sock")
        if sock_paths:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(0.1)
            s.connect(sock_paths[0])
            s.sendall(b"cursorpos")
            data = s.recv(1024).decode("utf-8")
            s.close()
            parts = [int(p.strip()) for p in data.split(",")]
            cursor = (parts[0], parts[1])
    except Exception:
        pass

    # 2. hyprctl fallback
    if not cursor:
        try:
            out = subprocess.check_output(["hyprctl", "cursorpos"], text=True)
            parts = [int(p.strip()) for p in out.strip().split(",")]
            cursor = (parts[0], parts[1])
        except Exception:
            cursor = (960, 540)

    # Monitor info
    monitors = []
    try:
        out = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
        monitors = json.loads(out)
    except Exception:
        monitors = [{"name": "eDP-1", "x": 0, "y": 0, "width": 1920, "height": 1080}]

    active_mon = monitors[0]
    for m in monitors:
        mx = m.get("x", 0)
        my = m.get("y", 0)
        mw = m.get("width", 1920)
        mh = m.get("height", 1080)
        if mx <= cursor[0] < mx + mw and my <= cursor[1] < my + mh:
            active_mon = m
            break

    return cursor, active_mon, monitors

def parse_waybar_config(path):
    """Parse JSONC waybar configuration."""
    if not os.path.exists(path):
        return {"left": [], "center": [], "right": []}
    try:
        with open(path, "r", encoding="utf-8") as f:
            text = f.read()
        text = re.sub(r"//.*", "", text)
        text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
        text = re.sub(r",\s*([\]}])", r"\1", text)
        conf = json.loads(text)
        return {
            "left": conf.get("modules-left", []),
            "center": conf.get("modules-center", []),
            "right": conf.get("modules-right", []),
        }
    except Exception:
        return {"left": [], "center": [], "right": []}

def query_atspi_modules(config_path, mon):
    """Query AT-SPI accessibility tree to find Waybar widget coordinates."""
    mon_w = mon.get("width", 1920)
    mon_h = mon.get("height", 1080)
    mon_x = mon.get("x", 0)
    mon_y = mon.get("y", 0)

    config_mods = parse_waybar_config(config_path)
    modules = []

    try:
        import gi
        gi.require_version("Atspi", "2.0")
        from gi.repository import Atspi

        desktop = Atspi.get_desktop(0)
        for i in range(desktop.get_child_count()):
            app = desktop.get_child_at_index(i)
            if app and app.get_name() == "waybar":
                for f_idx in range(app.get_child_count()):
                    frame = app.get_child_at_index(f_idx)
                    f_comp = frame.get_component_iface()
                    if f_comp:
                        f_rect = f_comp.get_extents(Atspi.CoordType.SCREEN)
                        if not (mon_x <= f_rect.x < mon_x + mon_w):
                            continue
                    if frame.get_child_count() == 0:
                        continue
                    top_box = frame.get_child_at_index(0)
                    sec_keys = ["left", "center", "right"]
                    for s_idx in range(min(top_box.get_child_count(), 3)):
                        sec_obj = top_box.get_child_at_index(s_idx)
                        k = sec_keys[s_idx]
                        mod_list = config_mods[k]
                        for m_idx in range(min(sec_obj.get_child_count(), len(mod_list))):
                            mod_name = mod_list[m_idx]
                            child = sec_obj.get_child_at_index(m_idx)
                            comp = child.get_component_iface()
                            if comp:
                                rect = comp.get_extents(Atspi.CoordType.SCREEN)
                                if rect.x > -100000 and rect.width > 0:
                                    modules.append({
                                        "name": mod_name,
                                        "x": rect.x,
                                        "y": rect.y,
                                        "w": rect.width,
                                        "h": rect.height,
                                        "center_x": rect.x + rect.width // 2,
                                    })
                                elif k == "center":
                                    modules.append({
                                        "name": mod_name,
                                        "x": mon_x + mon_w // 2 - 100,
                                        "y": mon_y,
                                        "w": 200,
                                        "h": 32,
                                        "center_x": mon_x + mon_w // 2,
                                    })
                break
    except Exception:
        pass

    return modules

def get_waybar_modules(config_path, mon, force_refresh=False):
    """Retrieve modules with caching for ultra-low latency."""
    mon_name = mon.get("name", "default")
    config_mtime = os.path.getmtime(config_path) if os.path.exists(config_path) else 0

    if not force_refresh and os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r") as f:
                cache = json.load(f)
            if cache.get("config_mtime") == config_mtime and mon_name in cache.get("monitors", {}):
                cached_mods = cache["monitors"][mon_name]
                if cached_mods:
                    return cached_mods
        except Exception:
            pass

    mods = query_atspi_modules(config_path, mon)
    if mods:
        try:
            cache = {}
            if os.path.exists(CACHE_FILE):
                try:
                    with open(CACHE_FILE, "r") as f:
                        cache = json.load(f)
                except Exception:
                    cache = {}
            cache["config_mtime"] = config_mtime
            if "monitors" not in cache:
                cache["monitors"] = {}
            cache["monitors"][mon_name] = mods
            with open(CACHE_FILE, "w") as f:
                json.dump(cache, f)
        except Exception:
            pass

    return mods

def resolve_target_center(panel_name, explicit_module, cursor, mon, modules):
    """Determine the exact horizontal center coordinate for the target panel."""
    mon_w = mon.get("width", 1920)
    mon_x = mon.get("x", 0)
    cx, cy = cursor
    local_cy = cy - mon.get("y", 0)

    # 1. If explicit module name passed and we have module data, find it directly
    if explicit_module and modules:
        for m in modules:
            if m["name"] == explicit_module:
                return m["center_x"]

    candidates = PANEL_TO_MODULES.get(panel_name, [panel_name])

    # 2. If click happened on the bar (local_cy <= 60):
    if local_cy <= 60:
        # If we have modules from AT-SPI, check if cursor is on a matching module
        if modules:
            for m in modules:
                if m["x"] <= cx <= m["x"] + m["w"]:
                    if any(cand in m["name"] or m["name"] in cand for cand in candidates):
                        return m["center_x"]
                    if m["name"].startswith("custom/"):
                        return m["center_x"]
        # If no module matched or AT-SPI wasn't running, the cursor position itself
        # is the exact click point on the Waybar module!
        return cx

    # 3. If not clicked on bar, match from candidates dictionary in AT-SPI modules
    if modules:
        for cand in candidates:
            for m in modules:
                if m["name"] == cand:
                    return m["center_x"]
        for cand in candidates:
            cand_base = cand.split("#")[0]
            for m in modules:
                if cand_base in m["name"]:
                    return m["center_x"]

    # 4. Fallback: default module position or center of monitor
    if panel_name in DEFAULT_MODULE_CENTERS:
        return mon_x + DEFAULT_MODULE_CENTERS[panel_name]

    return mon_x + (mon_w // 2)

def main():
    if len(sys.argv) < 2:
        print("Usage: toggle.py <panel_name> [module_name]")
        sys.exit(1)

    panel_name = sys.argv[1].lower().replace("panel", "").replace("toggle", "")
    explicit_module = sys.argv[2] if len(sys.argv) > 2 else None

    # Step 1: Query Hyprland for cursor and monitor
    cursor, active_mon, _ = get_hypr_info()

    # Step 2: Get module positions
    modules = get_waybar_modules(CONFIG_PATH, active_mon)

    # Step 3: Resolve center
    global_center_x = resolve_target_center(panel_name, explicit_module, cursor, active_mon, modules)

    # Convert to monitor-relative coordinate
    local_center_x = global_center_x - active_mon.get("x", 0)
    mon_name = active_mon.get("name", "")

    # Step 4: Call Quickshell IPC
    cmd = [
        "quickshell", "ipc", "-p", os.path.expanduser("~/.config/quickshell"),
        "call", "shell", "togglePanel", panel_name, str(local_center_x), mon_name
    ]
    subprocess.run(cmd)

if __name__ == "__main__":
    main()
