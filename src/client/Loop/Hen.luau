--!strict
-- Mama Hen (design-v3 3.3): a client-local hen at the landing point runs to the food, pecks 3 times, sits and
-- lays; the Eat Card shows the same beat in a ViewportFrame when the throw cam is off. Cosmetic only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ctx = require(script.Parent.Ctx)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)
local Sfx = require(script.Parent.Sfx)
local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme"))

local models = ReplicatedStorage:WaitForChild("Models")
local template = models:WaitForChild("MamaHen") :: Model
local hats = models:WaitForChild("MamaHenHats")

local Hen = {}
local RUN, PECK, SIT = 0.5, 0.6, 0.2 -- seconds after the food lands; the egg launches right after SIT
local RUN_FROM = 12
local MAX_CARDS = 3

-- Tinted hen with its zone hat, all parts anchored and non-colliding
local function build(zone: number): Model
    local hen = template:Clone()
    local tint = hen:GetAttribute("Tint_" .. zone) or hen:GetAttribute("Tint_1")
    for _, d in hen:GetDescendants() do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
            if d:GetAttribute("Tint") and typeof(tint) == "Color3" then
                d.Color = tint
            end
        end
    end
    local hatTemplate = hats:FindFirstChild(tostring(zone))
    local head = hen:FindFirstChild("Head")
    local point = head and head:FindFirstChild("HatPoint")
    if hatTemplate and hatTemplate:IsA("Model") and hatTemplate.PrimaryPart and point and point:IsA("Attachment") then
        local hat = hatTemplate:Clone()
        hat:PivotTo(point.WorldCFrame * (hatTemplate.PrimaryPart :: BasePart).CFrame)
        for _, d in hat:GetDescendants() do
            if d:IsA("BasePart") then
                d.Anchored, d.CanCollide, d.CanQuery = true, false, false
            end
        end
        hat.Parent = hen
    end
    return hen
end

-- Hen pose at time t (seconds after the food lands): run in with a bob, peck x3, sit, then idle
local function pose(base: CFrame, stop: CFrame, t: number): CFrame
    if t < RUN then
        local a = t / RUN
        return base:Lerp(stop, a) * CFrame.new(0, math.abs(math.sin(a * math.pi * 4)) * 0.8, 0)
    elseif t < RUN + PECK then
        local a = (t - RUN) / PECK
        return stop * CFrame.Angles(-math.rad(28) * math.abs(math.sin(a * math.pi * 3)), 0, 0)
    elseif t < RUN + PECK + SIT then
        local a = (t - RUN - PECK) / SIT
        return stop * CFrame.new(0, -1.2 * math.sin(a * math.pi), 0)
    end
    return stop
end

-- Plays the world hen for a throw reply. food = the thrown food part (eaten during the pecks).
-- Returns where the egg leaves from (hen's tail at lay time).
function Hen.play(r: any, landing: Vector3, food: BasePart?): Vector3
    local angle = math.random() * math.pi * 2
    local start = landing + Vector3.new(math.cos(angle), 0, math.sin(angle)) * RUN_FROM
    local toFood = (landing - start).Unit
    local stopPos = landing - toFood * 3
    local base = CFrame.lookAt(start, start + toFood) + Vector3.new(0, 0.5, 0)
    local stop = CFrame.lookAt(stopPos, stopPos + toFood) + Vector3.new(0, 0.5, 0)
    local tail = stopPos - toFood * 3 + Vector3.new(0, 3, 0)

    Ctx.at(r.foodLandsAt, function()
        local hen = build(r.zone)
        hen:PivotTo(base)
        hen.Parent = Fx.folder
        local t0 = os.clock()
        local pecks = 0
        local laid = false
        local conn: RBXScriptConnection
        conn = RunService.Heartbeat:Connect(function()
            local t = os.clock() - t0
            hen:PivotTo(pose(base, stop, t))
            local peck = math.floor((t - RUN) / (PECK / 3) + 0.5)
            if t >= RUN and peck > pecks and pecks < 3 then
                pecks += 1
                Sfx.play("nom", 0.9 + pecks * 0.1, 1, landing)
                Fx.burst(
                    landing + Vector3.new(0, 0.5, 0),
                    if food then food.Color else Color3.new(1, 0.3, 0.3),
                    8,
                    8,
                    0.35
                )
                if food then
                    food.Size *= 0.6
                    if pecks == 3 then
                        food:Destroy()
                    end
                end
                Fx.floatText(landing + Vector3.new(0, 7, 0), "\u{2665}", Color3.fromRGB(255, 90, 120), 3, 0.8, 1.5)
            end
            if not laid and t >= RUN + PECK then
                laid = true
                Sfx.play("cluck", 1, 1, landing)
            end
            if t > RUN + PECK + SIT + 1.2 then
                conn:Disconnect()
                for _, d in hen:GetDescendants() do
                    if d:IsA("BasePart") then
                        Fx.tween(d, 0.4, { Transparency = 1 })
                    end
                end
                task.delay(0.45, function()
                    hen:Destroy()
                end)
            end
        end)
    end)
    return tail
end

-- Eat Card (throw cam off): 2.2 s ViewportFrame of the hen eating, zone floor behind her, zone name, egg leaving.
function Hen.card(r: any)
    local row = Hud.eatRow
    local shown = 0
    for _, c in row:GetChildren() do
        if c:IsA("ViewportFrame") then
            shown += 1
        end
    end
    if shown >= MAX_CARDS then
        return -- eggs still arrive; the card is skipped
    end
    local compact = Hud.screen.info.compact
    local vp = Instance.new("ViewportFrame")
    vp.Name = "EatCard"
    vp.Size = if compact then UDim2.fromOffset(160, 120) else UDim2.fromOffset(220, 160)
    vp.BackgroundColor3 = Fx.FLOOR[r.zone] or Fx.FLOOR[1]
    vp.Ambient = Color3.fromRGB(200, 200, 200)
    vp.LightColor = Color3.new(1, 1, 1)
    Kit.corner(vp, UDim.new(0, 16))
    Kit.stroke(vp, Theme.Colors.outline, Theme.Stroke.panel, true)
    local title = Kit.text(vp, r.zoneName, Theme.TextSize.small)
    title.Size = UDim2.new(1, 0, 0, 22)
    title.Position = UDim2.fromOffset(0, 4)
    local camera = Instance.new("Camera")
    camera.FieldOfView = 40
    camera.CFrame = CFrame.lookAt(Vector3.new(9, 8, -18), Vector3.new(0, 4, 0))
    camera.Parent = vp
    vp.CurrentCamera = camera
    local hen = build(r.zone)
    local stand = CFrame.lookAt(Vector3.new(0, 0.5, 0), Vector3.new(0, 0.5, -1))
    hen:PivotTo(stand)
    hen.Parent = vp
    local food = Instance.new("Part")
    food.Shape = Enum.PartType.Ball
    food.Size = Vector3.new(1.4, 1.4, 1.4)
    food.Color = Color3.fromRGB(230, 50, 50)
    food.Position = Vector3.new(0, 0.7, -5)
    food.Parent = vp
    local egg = Fx.egg(r.zone, r.sparkle, 0.9)
    egg.Parent = vp
    egg.CFrame = CFrame.new(0, -10, 0)
    vp.Parent = row
    Kit.pop(vp, 0.6)
    local t0 = os.clock()
    local conn: RBXScriptConnection
    conn = RunService.Heartbeat:Connect(function()
        local t = os.clock() - t0
        if t < 1.2 then
            hen:PivotTo(stand * CFrame.Angles(-math.rad(25) * math.abs(math.sin(t / 1.2 * math.pi * 3)), 0, 0))
            food.Size = Vector3.one * 1.4 * (1 - t / 1.2)
        else
            food.Transparency = 1
            local a = math.min((t - 1.2) / 0.8, 1)
            egg.CFrame = CFrame.new(0, 2 + a * 14, 4 - a * 6) * CFrame.Angles(a * 8, 0, 0)
        end
        if t >= 2.2 then
            conn:Disconnect()
            vp:Destroy()
        end
    end)
end

return Hen
