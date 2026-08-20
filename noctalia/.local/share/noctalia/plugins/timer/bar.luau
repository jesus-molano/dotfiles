--!nonstrict

local STATE = "IDLE"
local formattedTime = "00:00"
local isVertical = false

local Tooltip = {
	hasTooltip = false,
}

function Tooltip.show()
	barWidget.setTooltip(formattedTime)
	Tooltip.hasTooltip = true
end

function Tooltip.hide()
	if Tooltip.hasTooltip then
		barWidget.clearTooltip()
		Tooltip.hasTooltip = false
	end
end

local HOURGLASS_COLORS = {
	IDLE = "on_surface",
	RUNNING = "primary",
	NOTIFY = "error",
}

local function getHourglassColor()
	return HOURGLASS_COLORS[STATE] or HOURGLASS_COLORS.IDLE
end

local function render()
	local showCounterWhenIdle = noctalia.getConfig("show_idle_on_horizontal")
	local hourGlassColor = getHourglassColor()

	if isVertical then
		barWidget.render(ui.column({ align = "center" }, {
			ui.glyph({ name = "hourglass", color = hourGlassColor }),
		}))

		if STATE == "RUNNING" then
			Tooltip.show()
		end
	else
		if STATE == "IDLE" and showCounterWhenIdle == false then
			barWidget.render(ui.row({ align = "center" }, {
				ui.glyph({ name = "hourglass", color = hourGlassColor }),
			}))
			return
		end

		barWidget.render(ui.row({ gap = 6, align = "center" }, {
			ui.glyph({ name = "hourglass", color = hourGlassColor }),
			ui.label({ text = formattedTime, fontWeight = "bold", color = hourGlassColor }),
		}))
	end
end

function update()
	isVertical = barWidget.isVertical()
	render()
end

noctalia.state.watch("timer.state", function(value)
	if isVertical and STATE == "RUNNING" and value ~= "RUNNING" then
		Tooltip.hide()
	end

	STATE = value
	render()
end)

noctalia.state.watch("timer.formattedTime", function(value)
	formattedTime = value
	if STATE == "RUNNING" then
		render()
	end
end)

function onClick()
	if STATE == "NOTIFY" then
		noctalia.state.set("timer.cmd", "RESET")
		return
	end
	noctalia.togglePanel("noctalia/timer:panel")
end
