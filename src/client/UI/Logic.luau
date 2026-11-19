--!strict
-- Pure UI logic (no Roblox instances), so tests/test_ui_logic.luau can assert it with Lune.

local Logic = {}

export type LayoutInfo = {
    compact: boolean, -- phone or small window: switch composition, not just size
    scale: number, -- UIScale for the screen root; all offsets are reference pixels at 1080p
    refWidth: number, -- usable screen size in reference pixels
    refHeight: number,
    touchMin: number, -- minimum button height in reference pixels (56 real px on phones)
    toastMax: number,
    panelWidth: number,
    panelHeight: number,
    toastWidth: number,
}

export type PanelState = { open: string? }

local REF_HEIGHT = 1080
local MIN_SCALE, MAX_SCALE = 0.55, 1.2 -- design-v3 section 7.1
local TOUCH_PX = 56
local SUFFIXES = { "K", "M", "B", "T", "Qa" }

-- width/height are the ScreenGui's real AbsoluteSize (inside the safe insets).
function Logic.layoutFor(width: number, height: number): LayoutInfo
    -- Same breakpoint as Bobux Gang hud.ts layout().
    local compact = width < 700 or height < 500
    local scale = math.clamp(height / REF_HEIGHT, MIN_SCALE, MAX_SCALE)
    local refWidth, refHeight = width / scale, height / scale
    return {
        compact = compact,
        scale = scale,
        refWidth = refWidth,
        refHeight = refHeight,
        touchMin = if compact then math.ceil(TOUCH_PX / scale) else TOUCH_PX,
        toastMax = if compact then 2 else 3,
        -- Phone: 94% x 86%. PC: 900 x 620 at 1080p, but never wider than the screen (tablets, small windows).
        panelWidth = if compact then refWidth * 0.94 else math.min(900, refWidth * 0.94),
        panelHeight = if compact then refHeight * 0.86 else math.min(620, refHeight * 0.86),
        toastWidth = math.min(640, refWidth - 32),
    }
end

-- 999 -> "999", 1234 -> "1.2K", 45300 -> "45.3K", 150000 -> "150K", 999999 -> "999K" (floors, never rounds up).
function Logic.formatNumber(n: number): string
    if n < 0 then
        return "-" .. Logic.formatNumber(-n)
    end
    local value = math.floor(n)
    if value < 1000 then
        return tostring(value)
    end
    local index = 0
    while value >= 1000 and index < #SUFFIXES do
        value /= 1000
        index += 1
    end
    local text = if value < 100 then string.format("%.1f", math.floor(value * 10) / 10) else tostring(math.floor(value))
    return (text:gsub("%.0$", "")) .. SUFFIXES[index]
end

function Logic.newPanelState(): PanelState
    return { open = nil }
end

-- One panel at a time: returns the panel that must be hidden first, if any.
function Logic.openPanel(state: PanelState, name: string): string?
    local previous = state.open
    state.open = name
    return if previous ~= name then previous else nil
end

-- Returns true when the panel was the open one (so the backdrop must fade out).
function Logic.closePanel(state: PanelState, name: string): boolean
    if state.open ~= name then
        return false
    end
    state.open = nil
    return true
end

return Logic
