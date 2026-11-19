--!strict
-- Next-zone teaser (catchiness pass): a glowing beacon down the canyon where the next locked zone starts, and a
-- padlock sign at the Ledge's edge with its name and the Strength it needs. Moves on when Strength unlocks it.

local Ctx = require(script.Parent.Ctx)
local Fx = require(script.Parent.Fx)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Theme = require(UI:WaitForChild("Theme"))

local Economy = Ctx.Economy
local TINTS = {
    Color3.fromRGB(255, 240, 200),
    Color3.fromRGB(120, 220, 90),
    Color3.fromRGB(255, 120, 40),
    Color3.fromRGB(50, 215, 205),
    Color3.fromRGB(175, 120, 255),
}

local Teaser = {}
local shown = 0
local parts: { Instance } = {}

local function clear()
    for _, p in parts do
        p:Destroy()
    end
    table.clear(parts)
end

function Teaser.update(strength: number)
    local nextId = Economy.zoneForStrength(strength).Id + 1
    if nextId == shown then
        return
    end
    shown = nextId
    clear()
    local zone = Economy.Zones[nextId]
    if not zone then
        return -- every zone unlocked
    end
    local floor = Fx.landingPoint(nextId, zone.MinDist)
    local tint = TINTS[nextId]
    -- the zone is far down the canyon (over 1000 studs): a tall, bright beacon keeps it visible
    local pillar = Fx.part("ZoneTeaser", Vector3.new(500, 40, 40), tint, Enum.PartType.Cylinder)
    pillar.CFrame = CFrame.new(floor + Vector3.new(0, 250, 0)) * CFrame.Angles(0, 0, math.rad(90))
    pillar.Material = Enum.Material.Neon
    pillar.Transparency = 0.3
    table.insert(parts, pillar)
    local loop = game:GetService("TweenService"):Create(
        pillar,
        TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Transparency = 0.6 }
    )
    loop:Play()

    -- the sign stands at the Ledge's canyon edge, toward the beacon (a billboard 1000+ studs away does not draw)
    local ledge = Ctx.station("Ledge"):GetPivot().Position
    local toward = (floor - ledge) * Vector3.new(1, 0, 1)
    local anchor = Fx.part("ZoneTeaserSign", Vector3.one, tint)
    anchor.Transparency = 1
    anchor.Position = ledge + toward.Unit * 24 + Vector3.new(0, 6, 0)
    table.insert(parts, anchor)
    local gui = Instance.new("BillboardGui")
    gui.Name = "Sign"
    gui.Size = UDim2.fromScale(7, 3.5)
    gui.LightInfluence = 0
    gui.MaxDistance = 120
    gui.Parent = anchor
    local lock = Kit.image(gui, "lock")
    lock.AnchorPoint = Vector2.new(0.5, 0)
    lock.Position = UDim2.fromScale(0.5, 0)
    lock.Size = UDim2.fromScale(0.3, 0.42)
    lock.ScaleType = Enum.ScaleType.Fit
    local name = Kit.text(gui, string.upper(zone.Name), 40, tint, nil, 3)
    name.TextScaled = true
    name.Position = UDim2.fromScale(0, 0.44)
    name.Size = UDim2.fromScale(1, 0.3)
    local need = Kit.text(gui, "Strength " .. zone.StrengthGate, 32, Theme.Colors.paper, nil, 3)
    need.TextScaled = true
    need.Position = UDim2.fromScale(0, 0.74)
    need.Size = UDim2.fromScale(1, 0.24)
end

return Teaser
