-- CachyOS Hyprland configuration with personal overrides.
--
-- The reviewed base comes from cachyos-hypr-noctalia 1.2.5-1. Resolve modules
-- relative to this file so both the deployed symlink and an in-repository
-- `hyprland --verify-config` use exactly the version tracked here.
local source = debug.getinfo(1, "S").source
local config_file = source:sub(1, 1) == "@" and source:sub(2) or source
local hypr_config = config_file:match("^(.*[/\\])") or "./"
local function add_module_dir(directory)
    if directory and directory ~= "" then
        package.path = directory .. "/?.lua;" .. directory .. "/?/init.lua;" .. package.path
    end
end

-- Hardware choices are generated outside the repository. They take precedence
-- over the merged Stow directory so a machine can retain its own displays,
-- inputs and optional adapters without committing its identity. The deployed
-- directory remains on the path for optional modules such as gaming.lua and
-- Noctalia's generated theme, even when Hyprland resolves this entrypoint's
-- symlink back to the canonical checkout.
local state_home = os.getenv("XDG_STATE_HOME")
    or ((os.getenv("HOME") or ".") .. "/.local/state")
local config_home = os.getenv("XDG_CONFIG_HOME")
    or ((os.getenv("HOME") or ".") .. "/.config")
local generated_dir = os.getenv("DOTFILES_GENERATED_HYPR_DIR")
    or (state_home .. "/dotfiles/generated/hypr")
local deployed_dir = os.getenv("DOTFILES_DEPLOYED_HYPR_DIR")
    or (config_home .. "/hypr")
local host_dir = os.getenv("HYPR_HOST_DIR")

add_module_dir(hypr_config)
add_module_dir(host_dir)
add_module_dir(deployed_dir)
add_module_dir(generated_dir)

local function require_optional(module)
    local loaded, result = pcall(require, module)
    if loaded then return result end

    local not_found = "module '" .. module .. "' not found:"
    if not tostring(result):find(not_found, 1, true) then error(result) end
end

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
require("config.hardware-binds")
require("config.user-binds")
require("config.misc")
require("config.monitors")
require("config.windowrules")
require("config.workspaces")
-- The optional gaming-core module contributes this file. Removing that bundle
-- also removes its bind and window rules on the next Hyprland reload.
require_optional("config.gaming")

-- Noctalia owns the live palette. Keep the tracked colors above as a fallback
-- so Hyprland also validates and starts before the generated module exists.
local has_noctalia_theme, noctalia_theme = pcall(function() return require("noctalia") end)
if has_noctalia_theme then noctalia_theme.apply_theme() end
