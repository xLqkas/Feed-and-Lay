--!strict
-- Day/Night cycle: advances ClockTime through a full 24-hour cycle
-- and smoothly blends lighting + atmosphere between night, dawn, day, and dusk.

local Lighting = game:GetService("Lighting")

-- Seconds for one full in-game day (10 minutes). Tweak to taste.
local CYCLE_DURATION = 600
local HOURS_PER_SECOND = 24 / CYCLE_DURATION

-- Keyframes describing the look at a given hour.
-- Colors chosen to blend nicely with the existing Sanctuary lighting setup.
local KEYFRAMES = {
	{
		hour = 0, -- midnight
		ambient = Color3.fromRGB(30, 34, 48),
		outdoorAmbient = Color3.fromRGB(46, 50, 68),
		brightness = 1,
		atmosphereColor = Color3.fromRGB(17, 20, 32),
		atmosphereDensity = 0.35,
		atmosphereHaze = 1.5,
	},
	{
		hour = 5, -- pre-dawn
		ambient = Color3.fromRGB(45, 42, 58),
		outdoorAmbient = Color3.fromRGB(72, 62, 78),
		brightness = 1.2,
		atmosphereColor = Color3.fromRGB(46, 40, 58),
		atmosphereDensity = 0.33,
		atmosphereHaze = 1.8,
	},
	{
		hour = 6.5, -- sunrise
		ambient = Color3.fromRGB(90, 78, 70),
		outdoorAmbient = Color3.fromRGB(160, 120, 95),
		brightness = 1.8,
		atmosphereColor = Color3.fromRGB(232, 148, 96),
		atmosphereDensity = 0.3,
		atmosphereHaze = 2.2,
	},
	{
		hour = 9, -- morning
		ambient = Color3.fromRGB(110, 115, 125),
		outdoorAmbient = Color3.fromRGB(140, 150, 165),
		brightness = 2.4,
		atmosphereColor = Color3.fromRGB(160, 190, 230),
		atmosphereDensity = 0.29,
		atmosphereHaze = 1.6,
	},
	{
		hour = 12, -- noon
		ambient = Color3.fromRGB(128, 128, 128),
		outdoorAmbient = Color3.fromRGB(128, 140, 160),
		brightness = 2.6,
		atmosphereColor = Color3.fromRGB(140, 175, 225),
		atmosphereDensity = 0.28,
		atmosphereHaze = 1.4,
	},
	{
		hour = 15, -- afternoon
		ambient = Color3.fromRGB(128, 128, 128),
		outdoorAmbient = Color3.fromRGB(150, 145, 150),
		brightness = 2.5,
		atmosphereColor = Color3.fromRGB(185, 185, 210),
		atmosphereDensity = 0.29,
		atmosphereHaze = 1.5,
	},
	{
		hour = 18, -- sunset
		ambient = Color3.fromRGB(95, 78, 68),
		outdoorAmbient = Color3.fromRGB(175, 120, 90),
		brightness = 1.8,
		atmosphereColor = Color3.fromRGB(240, 140, 90),
		atmosphereDensity = 0.32,
		atmosphereHaze = 2.4,
	},
	{
		hour = 19.5, -- dusk
		ambient = Color3.fromRGB(50, 44, 58),
		outdoorAmbient = Color3.fromRGB(80, 68, 82),
		brightness = 1.2,
		atmosphereColor = Color3.fromRGB(52, 42, 60),
		atmosphereDensity = 0.34,
		atmosphereHaze = 1.9,
	},
	{
		hour = 21, -- night
		ambient = Color3.fromRGB(30, 34, 48),
		outdoorAmbient = Color3.fromRGB(46, 50, 68),
		brightness = 1,
		atmosphereColor = Color3.fromRGB(17, 20, 32),
		atmosphereDensity = 0.35,
		atmosphereHaze = 1.5,
	},
	{
		hour = 24, -- wraps to midnight (same as hour 0)
		ambient = Color3.fromRGB(30, 34, 48),
		outdoorAmbient = Color3.fromRGB(46, 50, 68),
		brightness = 1,
		atmosphereColor = Color3.fromRGB(17, 20, 32),
		atmosphereDensity = 0.35,
		atmosphereHaze = 1.5,
	},
}

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return Color3.new(lerp(a.R, b.R, t), lerp(a.G, b.G, t), lerp(a.B, b.B, t))
end

-- Samples the keyframe table at a given hour (0-24) and applies the look.
local function applyLook(hour: number)
	-- Clamp into [0, 24)
	hour = hour % 24

	-- Find the two keyframes surrounding this hour
	local i = 1
	while i < #KEYFRAMES and KEYFRAMES[i + 1].hour < hour do
		i += 1
	end
	local a = KEYFRAMES[i]
	local b = KEYFRAMES[i + 1] or KEYFRAMES[#KEYFRAMES]
	local span = math.max(b.hour - a.hour, 1e-6)
	local t = math.clamp((hour - a.hour) / span, 0, 1)

	Lighting.Ambient = lerpColor(a.ambient, b.ambient, t)
	Lighting.OutdoorAmbient = lerpColor(a.outdoorAmbient, b.outdoorAmbient, t)
	Lighting.Brightness = lerp(a.brightness, b.brightness, t)

	if atmosphere then
		atmosphere.Color = lerpColor(a.atmosphereColor, b.atmosphereColor, t)
		atmosphere.Density = lerp(a.atmosphereDensity, b.atmosphereDensity, t)
		atmosphere.Haze = lerp(a.atmosphereHaze, b.atmosphereHaze, t)
	end
end

-- Main loop: advance time and refresh the look ~20 times per second.
while true do
	local dt = task.wait(0.05)
	Lighting.ClockTime = (Lighting.ClockTime + HOURS_PER_SECOND * dt) % 24
	applyLook(Lighting.ClockTime)
end
