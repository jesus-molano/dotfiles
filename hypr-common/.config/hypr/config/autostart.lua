-- Keep one explicit Noctalia startup path under the UWSM application scope.
-- Do not import the entire shell environment into systemd: it can include
-- credentials. xhost access for root is neither required nor appropriate.
hl.on("hyprland.start", function ()
    -- Keep Orca's local runtime available for scheduled automations. Its first
    -- window is routed silently to special:orca by the matching window rule.
    hl.exec_cmd("uwsm app -- start-orca-background")
    -- Espera a que las salidas externas respondan por DDC. No depende de que
    -- haya dos monitores: también arranca con uno solo o únicamente con eDP.
    hl.exec_cmd("uwsm app -- start-noctalia-ready")
    -- Shelly expone las actualizaciones de repositorios, AUR y backends
    -- opcionales en el tray una vez que Noctalia publica su watcher.
    hl.exec_cmd("ensure-shelly-tray")
    -- Wait for Noctalia's StatusNotifierWatcher before starting 1Password;
    -- Electron does not re-register its tray item if it wins the startup race.
    hl.exec_cmd("ensure-1password-tray")
end)
