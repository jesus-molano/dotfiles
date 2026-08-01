-- CachyOS Hyprland configuration with personal overrides.
--
-- The vendored base comes from cachyos-hypr-noctalia 1.2.3-1. Resolve modules
-- relative to this file so both the deployed symlink and an in-repository
-- `hyprland --verify-config` use exactly the version tracked here.
local source = debug.getinfo(1, "S").source
local config_file = source:sub(1, 1) == "@" and source:sub(2) or source
local hypr_config = config_file:match("^(.*[/\\])") or "./"
package.path = hypr_config .. "?.lua;" .. hypr_config .. "?/init.lua;" .. package.path

-- Register every key once and always expose a description to Hyprland tools.
-- Normalising modifiers catches aliases such as Hyper already containing Shift.
local registered_binds = {}
local modifier_names = {
    ALT = "ALT",
    CONTROL = "CONTROL",
    CTRL = "CONTROL",
    META = "SUPER",
    SHIFT = "SHIFT",
    SUPER = "SUPER",
}

local function normalise_bind(keys)
    local modifiers, key = {}, nil
    for raw in keys:gmatch("[^+]+") do
        local token = raw:match("^%s*(.-)%s*$"):upper()
        local modifier = modifier_names[token]
        if modifier then
            modifiers[modifier] = true
        elseif key then
            error("Atajo inválido con más de una tecla: " .. keys)
        else
            key = token
        end
    end

    assert(key, "Atajo sin tecla: " .. keys)
    local ordered = {}
    for _, name in ipairs({ "CONTROL", "ALT", "SUPER", "SHIFT" }) do
        if modifiers[name] then table.insert(ordered, name) end
    end
    table.insert(ordered, key)
    return table.concat(ordered, "+")
end

function HYPR_BIND(keys, dispatcher, options)
    options = options or {}
    local id = normalise_bind(keys)
    local previous = registered_binds[id]
    assert(not previous, string.format("Atajo duplicado %s (%s / %s)", id, previous, options.description or keys))
    options.description = options.description or ("CachyOS: " .. keys)
    registered_binds[id] = options.description
    return hl.bind(keys, dispatcher, options)
end

require("config.animations")
require("config.autostart")
require("config.colors")
require("config.decorations")
require("config.variables")
require("config.environment")
require("config.inputs")
require("config.user-inputs")
require("config.binds")
require("config.user-binds")
require("config.misc")
require("config.monitors")
require("config.windowrules")
require("config.workspaces")

-- Noctalia owns the live palette. Keep the tracked colors above as a fallback
-- so Hyprland also validates and starts before the generated module exists.
local has_noctalia_theme, noctalia_theme = pcall(function() return require("noctalia") end)
if has_noctalia_theme then noctalia_theme.apply_theme() end
