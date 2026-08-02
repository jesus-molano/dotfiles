-- IDs stay numeric for keyboard navigation; names are presentation metadata
-- consumed by Noctalia's icon-only workspace switcher.
local workspace_icons = {
    "", -- 1: browser
    "", -- 2: terminal
    "", -- 3: code
    "", -- 4: music
    "", -- 5: files
    "", -- 6: communication
    "", -- 7: documentation
    "", -- 8: system / miscellaneous
}

-- Hardware profiles can override presentation and monitor ownership without
-- duplicating the shared workspace rules. The desktop profile groups them by
-- hand: Q/W/E/R on the left display and U/I/O/P on the right.
for workspace = 1, NUM_WORKSPACES do
    local rule = {
        workspace = tostring(workspace),
        persistent = true,
        default_name = (WORKSPACE_ICON_OVERRIDES or {})[workspace] or workspace_icons[workspace],
    }

    if WORKSPACE_MONITORS and WORKSPACE_MONITORS[workspace] then
        rule.monitor = WORKSPACE_MONITORS[workspace]
    end
    if WORKSPACE_DEFAULTS and WORKSPACE_DEFAULTS[workspace] then
        rule.default = true
    end

    hl.workspace_rule(rule)
end
