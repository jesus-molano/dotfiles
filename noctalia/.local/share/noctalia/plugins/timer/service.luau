--!nonstrict

noctalia.setUpdateInterval(1000)

local ALARM_NAME = "timer-alarm"
local ALARM_PATH = "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
local alarmReady = false

local alarmAccepted = noctalia.sound.load(ALARM_NAME, ALARM_PATH, function(ok, errorMessage)
	alarmReady = ok
	if ok then
		noctalia.log("timer: alarm sound ready")
	else
		noctalia.log("timer: could not load alarm sound: " .. (errorMessage or "unknown error"))
	end
end)
if not alarmAccepted then
	noctalia.log("timer: alarm sound request was not accepted")
end

local function formatTime(seconds)
	local m = seconds // 60
	local s = seconds % 60
	if m >= 60 then
		return `{m // 60}:{string.format("%02d", m % 60)}:{string.format("%02d", s)}`
	end
	return `{m}:{string.format("%02d", s)}`
end

noctalia.state.set("timer.state", "IDLE")
noctalia.state.set("timer.remaining", 0)
noctalia.state.set("timer.formattedTime", "0")
noctalia.state.set("timer.duration", 0)

noctalia.state.watch("timer.remaining", function(value)
	noctalia.state.set("timer.formattedTime", formatTime(value))
end)

noctalia.state.watch("timer.cmd", function(cmd)
	local actions = {
		PAUSE = function()
			noctalia.state.set("timer.state", "PAUSED")
		end,
		START = function()
			local remaining = noctalia.state.get("timer.remaining")
			local state = noctalia.state.get("timer.state")

			if (state == "IDLE" or state == "PAUSED") and remaining > 0 then
				if state == "IDLE" then
					noctalia.state.set("timer.duration", remaining)
				end
				noctalia.state.set("timer.state", "RUNNING")
			end
		end,
		RESET = function()
			noctalia.state.set("timer.remaining", 0)
			noctalia.state.set("timer.duration", 0)
			noctalia.state.set("timer.state", "IDLE")
		end,
	}

	local action = actions[cmd]
	if action then
		action()
	else
		noctalia.log(`Unknown command: {cmd}`)
	end
end)

local function playAlarm()
	if alarmReady then
		noctalia.sound.play(ALARM_NAME)
		noctalia.log("timer: alarm playback requested")
		return true
	end

	noctalia.log("timer: alarm playback requested before sound was ready")
	return false
end

local function notifyUser()
	noctalia.notify(noctalia.tr("ui.notify_title"), noctalia.tr("ui.notify_body"))
	playAlarm()
end

function onIpc(event, _payload)
	if event == "preview-alarm" then
		return playAlarm()
	end

	noctalia.log(`timer: unknown IPC event: {event}`)
	return false
end

function update()
	local state = noctalia.state.get("timer.state")
	local remaining = noctalia.state.get("timer.remaining")

	if state == "RUNNING" then
		if remaining > 0 then
			noctalia.state.set("timer.remaining", remaining - 1)
		else
			noctalia.state.set("timer.state", "NOTIFY")
			notifyUser()
		end
	end
end
