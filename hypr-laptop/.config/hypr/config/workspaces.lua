-- Persistent numbered workspaces are not pinned to connector names, so an
-- external display can be attached or removed without invalidating the layout.
for workspace = 1, NUM_WORKSPACES do
    hl.workspace_rule({ workspace = tostring(workspace), persistent = true })
end
