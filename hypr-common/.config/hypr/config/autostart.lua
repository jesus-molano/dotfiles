-- Keep one explicit Noctalia startup path under the UWSM application scope.
-- Do not import the entire shell environment into systemd: it can include
-- credentials. xhost access for root is neither required nor appropriate.
hl.on("hyprland.start", function ()
    -- Start only the selected provider; each client keeps its own special workspace.
    hl.exec_cmd("uwsm app -- start-ai-background")
    -- Espera a que las salidas externas respondan por DDC. No depende de que
    -- haya dos monitores: también arranca con uno solo o únicamente con eDP.
    hl.exec_cmd("uwsm app -- start-noctalia-ready")
    -- Shelly expone las actualizaciones de repositorios, AUR y backends
    -- opcionales en el tray una vez que Noctalia publica su watcher.
    hl.exec_cmd("ensure-shelly-tray")
end)
