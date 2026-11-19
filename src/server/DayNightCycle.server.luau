--!strict
-- Day cycle (v3 playtest fix, 2026-11-19). The old script ran a full 24 h clock and made half of every play
-- session dark. design-v3 section 0 cuts dark nights and 6.2 turns night into a warm "Golden Hour", so this
-- keeps the cycle but never goes dark: 8 minutes of day (clock 8:00 -> 16:30), then 2 minutes of warm dusk
-- (clock 17.4), and Ambient never below (120, 120, 130). The old 24 h keyframes are in git history
-- (tag backup/pre-v3). Golden Hour gameplay (odds, announcements, GameClock attributes) is P-5.

local Lighting = game:GetService("Lighting")

local CYCLE = 600
local DAY = 480
local UPDATE = 1 -- seconds; the clock moves about 1 minute of game time per update, too slow to see steps

type Look = {
    clock: number,
    ambient: Color3,
    outdoor: Color3,
    brightness: number,
    tint: Color3,
    atmosphere: Color3,
}
local MORNING: Look = {
    clock = 8,
    ambient = Color3.fromRGB(128, 128, 136),
    outdoor = Color3.fromRGB(140, 150, 170),
    brightness = 2.5,
    tint = Color3.fromRGB(255, 252, 248), -- the place's own ColorCorrection tint
    atmosphere = Color3.fromRGB(160, 190, 230),
}
local AFTERNOON: Look = {
    clock = 16.5,
    ambient = Color3.fromRGB(128, 126, 130),
    outdoor = Color3.fromRGB(150, 145, 150),
    brightness = 2.5,
    tint = Color3.fromRGB(255, 252, 248), -- the place's own ColorCorrection tint
    atmosphere = Color3.fromRGB(185, 185, 210),
}
local DUSK: Look = {
    clock = 17.4,
    ambient = Color3.fromRGB(140, 125, 120),
    outdoor = Color3.fromRGB(190, 150, 120),
    brightness = 2.2,
    tint = Color3.fromRGB(255, 230, 200),
    atmosphere = Color3.fromRGB(240, 160, 110),
}
local FLOOR = Color3.fromRGB(120, 120, 130)

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")

local function mix(a: Look, b: Look, t: number): Look
    return {
        clock = a.clock + (b.clock - a.clock) * t,
        ambient = a.ambient:Lerp(b.ambient, t),
        outdoor = a.outdoor:Lerp(b.outdoor, t),
        brightness = a.brightness + (b.brightness - a.brightness) * t,
        tint = a.tint:Lerp(b.tint, t),
        atmosphere = a.atmosphere:Lerp(b.atmosphere, t),
    }
end

-- 15 s blends at each phase change so the switch to dusk and back is not a jump
local function lookAt(s: number): Look
    if s < DAY then
        local look = mix(MORNING, AFTERNOON, s / DAY)
        if s < 15 then
            local blended = mix(DUSK, look, s / 15)
            blended.clock = look.clock -- the sun jumps back once; colours blend
            return blended
        end
        return look
    end
    return mix(AFTERNOON, DUSK, math.min((s - DAY) / 15, 1))
end

while true do
    local look = lookAt(os.time() % CYCLE)
    Lighting.ClockTime = look.clock
    Lighting.Ambient = Color3.new(
        math.max(look.ambient.R, FLOOR.R),
        math.max(look.ambient.G, FLOOR.G),
        math.max(look.ambient.B, FLOOR.B)
    )
    Lighting.OutdoorAmbient = look.outdoor
    Lighting.Brightness = look.brightness
    if grade then
        grade.TintColor = look.tint
    end
    if atmosphere then
        atmosphere.Color = look.atmosphere
    end
    task.wait(UPDATE)
end
