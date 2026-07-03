local primary = "eDP-1"
local secondary = "HDMI-A-1"

-- Function to handle hotplug switching
local function update_workspace_layout()
    local has_hdmi = false

    -- Correctly read the built-in monitor array
    for _, m in ipairs(hl.get_monitors()) do
        if m.name == secondary then
            has_hdmi = true
            break
        end
    end

    if has_hdmi then
    -- Laptop
        for i = 1, 5 do
            hl.workspace_rule({
                workspace = tostring(i),
                monitor = "eDP-1",
                persistent = true,
                default = (i == 1),
            })
        end

    -- External
        for i = 6, 10 do
            hl.workspace_rule({
                workspace = tostring(i),
                monitor = "HDMI-A-1",
                persistent = true,
                default = (i == 6),
            })
        end
    else
        -- Laptop only
        for i = 1, 10 do
            hl.workspace_rule({
                workspace = tostring(i),
                monitor = "eDP-1",
                persistent = true,
                default = (i == 1),
            })
        end
    end
end

-- Hook up the function to listen to dynamic hotplug events safely
hl.on("monitor.added", update_workspace_layout)
hl.on("monitor.removed", update_workspace_layout)

-- Run once on startup to configure initial boot state
update_workspace_layout()


