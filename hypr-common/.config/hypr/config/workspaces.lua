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
local scrolling_workspace = SCROLLING_WORKSPACE or 3

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
        if workspace == scrolling_workspace then
            rule.layout = "scrolling"
            rule.layout_opts = { direction = "right" }
        end

        if monitors[workspace] then rule.monitor = monitors[workspace] end
        hl.workspace_rule(rule)
    end

    -- Outputs can appear one by one during startup. Hyprland may create the
    -- next free workspace (9) before the persistent 5-8 rules reach the right
    -- monitor. Replace only that unmanaged fallback; preserve any deliberate
    -- selection inside the configured 1-8 range. The workspace dispatcher is
    -- compatible with icon-renamed workspaces; restore the original focus when
    -- repairing a different monitor.
    for default_workspace, enabled in pairs(defaults) do
        local monitor_name = monitors[default_workspace]
        local monitor = monitor_name and hl.get_monitor(monitor_name)
        local active = monitor and monitor.active_workspace
        if enabled and active and (active.id < 1 or active.id > NUM_WORKSPACES) then
            local focused_monitor = hl.get_active_monitor()
            local focused_workspace = focused_monitor and focused_monitor.active_workspace
            hl.dispatch(hl.dsp.focus({ workspace = default_workspace }))
            if focused_monitor and focused_monitor ~= monitor and focused_workspace then
                hl.dispatch(hl.dsp.focus({ workspace = focused_workspace }))
            end
        end
    end
end

apply_workspace_rules()

-- Hyprland emits this after an output is added, removed or rearranged. Updating
-- the persistent rules creates missing empty workspaces and moves existing ones.
-- An unmanaged startup fallback is replaced with the monitor default without
-- changing the focused monitor or any key binding.
if WORKSPACE_MONITOR_POLICY then hl.on("monitor.layout_changed", apply_workspace_rules) end
