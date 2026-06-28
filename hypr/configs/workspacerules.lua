local primary = "eDP-1"
local secondary = "HDMI-A-1"

for i = 1, 5 do
    hl.workspace_rule({
        workspace = tostring(i),
        monitor = primary,
        persistent = true,
        default = (i == 1),
    })
end

for i = 6, 10 do
    hl.workspace_rule({
        workspace = tostring(i),
        monitor = secondary,
        persistent = true,
        default = (i == 6),
    })
end