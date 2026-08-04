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

local function resolve_workspace_layout()
    if not WORKSPACE_MONITOR_POLICY then
        return WORKSPACE_MONITORS or {}, WORKSPACE_DEFAULTS or {}
    end

    local active_names = {}
    local active_monitors = hl.get_monitors()
    for _, monitor in ipairs(active_monitors) do
        active_names[monitor.name] = true
    end

    local policy = WORKSPACE_MONITOR_POLICY
    local targets = {}
    local defaults = {}

    if active_names[policy.left] and active_names[policy.right] then
        for workspace = 1, NUM_WORKSPACES do
            targets[workspace] = workspace <= policy.split_after and policy.left or policy.right
        end
        defaults[1] = true
        defaults[policy.split_after + 1] = true
        return targets, defaults
    end

    -- Prefer either known desktop output. The generic fallback keeps every
    -- workspace usable if a temporary replacement display is the only output.
    local active_monitor = hl.get_active_monitor()
    local only_monitor = active_names[policy.left] and policy.left
        or active_names[policy.right] and policy.right
        or (active_monitor and active_monitor.name)
        or (active_monitors[1] and active_monitors[1].name)

    if only_monitor then
        for workspace = 1, NUM_WORKSPACES do
            targets[workspace] = only_monitor
        end
        defaults[1] = true
    end

    return targets, defaults
end

local function apply_workspace_rules()
    local monitors, defaults = resolve_workspace_layout()

    for workspace = 1, NUM_WORKSPACES do
        local rule = {
            workspace = tostring(workspace),
            persistent = true,
            default = defaults[workspace] == true,
            default_name = (WORKSPACE_ICON_OVERRIDES or {})[workspace] or workspace_icons[workspace],
        }

        -- El workspace de código usa la cinta nativa de Hyprland. El resto
        -- conserva dwindle para no cambiar la memoria muscular global.
        if workspace == 3 then
            rule.layout = "scrolling"
            rule.layout_opts = { direction = "right" }
        end

        if monitors[workspace] then rule.monitor = monitors[workspace] end
        hl.workspace_rule(rule)
    end
end

apply_workspace_rules()

-- Hyprland emits this after an output is added, removed or rearranged. Updating
-- the persistent rules creates missing empty workspaces and moves existing ones
-- without changing the currently focused workspace or any key binding.
if WORKSPACE_MONITOR_POLICY then hl.on("monitor.layout_changed", apply_workspace_rules) end
