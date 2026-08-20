-- Desktop-only integration. This file disappears cleanly with `just remove
-- gaming`, so the keybind and launcher rules disappear on the next reload too.
local games_workspace = 7
local hyper = "CONTROL + ALT + SUPER + SHIFT"

HYPR_BIND(hyper .. " + G", hl.dsp.exec_cmd("hypr-gaming"), {
    description = "Focus or open Steam",
})

-- Route launcher UIs without treating them as games.
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

-- Route game windows conservatively. Do not force fullscreen or decoration:
-- those policies remain game-specific and require physical validation.
local game_window_rules = {
    { name = "route-game-content-to-games", match = { content = "game" } },
    { name = "route-game-tag-to-games", match = { xdg_tag = "^(.*game.*)$" } },
    { name = "route-steam-apps-and-gamescope-to-games", match = { class = "^(steam_app_.*|gamescope)$" } },
}

for _, rule in ipairs(game_window_rules) do
    hl.window_rule({
        name = rule.name,
        match = rule.match,
        workspace = tostring(games_workspace) .. " silent",
    })
end
