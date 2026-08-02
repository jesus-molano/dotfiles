-- Desktop-only integration. This file disappears cleanly with `just remove
-- gaming`, so the keybind and launcher rules disappear on the next reload too.
local games_workspace = 7
local hyper = "CONTROL + ALT + SUPER + SHIFT"

HYPR_BIND(hyper .. " + G", hl.dsp.exec_cmd("hypr-gaming"), {
    description = "Enfocar o abrir Steam",
})

-- Route launcher UIs only. Anchored initial classes deliberately exclude
-- Steam's steam_app_* windows and games spawned by the other launchers.
local game_launchers = {
    { name = "steam", initial_class = "^[Ss]team$" },
    { name = "heroic", initial_class = "^([Hh]eroic|com\\.heroicgameslauncher\\.hgl)$" },
    { name = "lutris", initial_class = "^([Ll]utris|net\\.lutris\\.Lutris)$" },
    { name = "faugus", initial_class = "^([Ff]augus|faugus-launcher|io\\.github\\.Faugus\\.faugus-launcher)$" },
}

for _, launcher in ipairs(game_launchers) do
    hl.window_rule({
        name = "route-" .. launcher.name .. "-to-games",
        match = { initial_class = launcher.initial_class },
        workspace = tostring(games_workspace) .. " silent",
    })
end
