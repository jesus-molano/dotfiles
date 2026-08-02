-- Keep one explicit Noctalia startup path under the UWSM application scope.
-- Do not import the entire shell environment into systemd: it can include
-- credentials. xhost access for root is neither required nor appropriate.
hl.on("hyprland.start", function ()
    -- Orca owns its settings while running. Apply the tracked Project Atlas
    -- terminal palette before the app can restore or open a window.
    hl.exec_cmd("orca-safe-settings")
    hl.exec_cmd("uwsm app -- noctalia")
    -- Keep 1Password resident as a StatusNotifierItem without opening its main
    -- window. Noctalia exposes it through the inline tray on the bar.
    hl.exec_cmd("uwsm app -- 1password --silent")
end)
