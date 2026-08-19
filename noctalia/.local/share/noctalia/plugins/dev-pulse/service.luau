--!nonstrict

-- Dev Pulse keeps the bar passive. It derives status from the currently active
-- Hyprland window and never opens a project, sends a prompt or changes Git.

local STATE_KEY = "dev_pulse"
local refreshInFlight = false

local function publishUnavailable(message)
    noctalia.state.set(STATE_KEY, {
        available = false,
        message = message,
    })
end

local function refresh()
    if refreshInFlight then return end
    refreshInFlight = true

    local started = noctalia.runAsync("dev-pulse-status --json", function(result)
        refreshInFlight = false
        if result.exitCode ~= 0 then
            publishUnavailable("status command failed")
            return
        end

        local value, errorMessage = noctalia.json.decode(result.stdout or "")
        if type(value) ~= "table" then
            noctalia.log("dev-pulse: invalid JSON" .. (errorMessage and (": " .. errorMessage) or ""))
            publishUnavailable("invalid status response")
            return
        end

        noctalia.state.set(STATE_KEY, value)
    end)

    if not started then
        refreshInFlight = false
        publishUnavailable("could not start status command")
    end
end

noctalia.setUpdateInterval(30000)
refresh()

function update()
    refresh()
end
