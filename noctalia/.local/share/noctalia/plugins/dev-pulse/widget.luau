--!nonstrict

-- Compact bar client for the service state. Long project paths stay in the
-- tooltip so the bar remains calm on both 1080p displays.

local STATE_KEY = "dev_pulse"
local status = noctalia.state.get(STATE_KEY) or { available = false }

local function render()
    if status.available ~= true then
        barWidget.setGlyph("activity")
        barWidget.setGlyphColor("on_surface_variant")
        barWidget.setText("")
        barWidget.setTooltip("Dev Pulse: no project in the active window")
        return
    end

    local project = tostring(status.project or "project")
    local branch = tostring(status.branch or "detached")
	local dirty = tonumber(status.dirty) or 0
	local dirtyAvailable = status.dirty_available ~= false
    local codex = tonumber(status.codex) or 0
    local label = project .. " " .. branch
	if dirtyAvailable and dirty > 0 then label = label .. " +" .. dirty end

	barWidget.setGlyph(if dirtyAvailable and dirty > 0 then "git-branch" else "code")
	barWidget.setGlyphColor(if dirtyAvailable and dirty > 0 then "secondary" else "primary")
    barWidget.setText(label)
    barWidget.setTooltip(
        "Dev Pulse\n"
            .. tostring(status.path or "")
			.. "\nCambios: " .. (if dirtyAvailable then dirty else "sin calcular")
            .. " · Codex activos: " .. codex
    )
end

noctalia.state.watch(STATE_KEY, function(value)
    status = type(value) == "table" and value or { available = false }
    render()
end)

function update()
    local current = noctalia.state.get(STATE_KEY)
    if type(current) == "table" then status = current end
    render()
end

render()
