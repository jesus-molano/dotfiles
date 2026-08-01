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

-- Persistent workspaces are not pinned to connector names, so an external
-- display can be attached or removed without invalidating the layout.
for workspace = 1, NUM_WORKSPACES do
    hl.workspace_rule({
        workspace = tostring(workspace),
        persistent = true,
        default_name = workspace_icons[workspace],
    })
end
