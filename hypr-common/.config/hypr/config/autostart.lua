-- Keep one explicit Noctalia startup path under the UWSM application scope.
-- Do not import the entire shell environment into systemd: it can include
-- credentials. xhost access for root is neither required nor appropriate.
hl.on("hyprland.start", function ()
    hl.exec_cmd("uwsm app -- noctalia")
end)
