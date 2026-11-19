--!strict
-- 3D helpers for the loop: client-only parts, eggs, particle bursts, floating world text, arcs and squash.
-- Everything here is cosmetic and lives in Workspace.FLClientFx on this client only.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Ctx = require(script.Parent.Ctx)

local Fx = {}

Fx.folder = Instance.new("Folder")
Fx.folder.Name = "FLClientFx"
Fx.folder.Parent = Workspace

-- Zone colours: mud crust on eggs, splats and trails; floor colour behind the Eat Card
Fx.MUD = {
    Color3.fromRGB(122, 86, 52),
    Color3.fromRGB(78, 98, 44),
    Color3.fromRGB(58, 50, 52),
    Color3.fromRGB(52, 116, 112),
    Color3.fromRGB(92, 64, 140),
}
Fx.FLOOR = {
    Color3.fromRGB(150, 205, 110),
    Color3.fromRGB(96, 130, 70),
    Color3.fromRGB(90, 60, 50),
    Color3.fromRGB(70, 150, 170),
    Color3.fromRGB(50, 40, 90),
}
Fx.SHELL = Color3.fromRGB(255, 246, 222)
Fx.EGG_SIZE = Vector3.new(2.4, 3, 2.4) -- wash and hatch size; nest cups use 0.45 of it

function Fx.tween(
    target: Instance,
    seconds: number,
    goal: { [string]: any },
    style: Enum.EasingStyle?,
    dir: Enum.EasingDirection?
): Tween
    local t = TweenService:Create(
        target,
        TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        goal
    )
    t:Play()
    return t
end

function Fx.part(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Color = color
    p.Shape = shape or Enum.PartType.Block
    p.Material = Enum.Material.SmoothPlastic
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = Fx.folder
    return p
end

-- Egg: a stretched sphere. Muddy eggs wear the zone crust colour; sparkle eggs glint (rare slot hint).
function Fx.egg(zone: number, sparkle: boolean, scale: number?): Part
    local s = scale or 1
    local egg = Fx.part("Egg", Fx.EGG_SIZE * s, Fx.MUD[zone] or Fx.MUD[1])
    egg.Material = Enum.Material.Sand
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = egg
    if sparkle then
        local glint = Instance.new("ParticleEmitter")
        glint.Name = "Glint"
        glint.Color = ColorSequence.new(Color3.fromRGB(255, 215, 80))
        glint.LightEmission = 1
        glint.Rate = 3
        glint.Lifetime = NumberRange.new(0.5, 0.9)
        glint.Speed = NumberRange.new(0.5, 1.5)
        glint.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * s), NumberSequenceKeypoint.new(1, 0) })
        glint.Parent = egg
    end
    return egg
end

-- Resizes an egg made by Fx.egg (scale relative to the wash size)
function Fx.setEggScale(egg: BasePart, scale: number)
    egg.Size = Fx.EGG_SIZE * scale
end

-- One-off particle burst at a point (count is halved in reduced motion)
function Fx.burst(position: Vector3, color: Color3, count: number, speed: number?, size: number?, lifetime: number?)
    local a = Instance.new("Attachment")
    a.WorldPosition = position
    a.Parent = Workspace.Terrain
    local e = Instance.new("ParticleEmitter")
    e.Color = ColorSequence.new(color)
    e.Rate = 0
    e.Speed = NumberRange.new((speed or 10) * 0.5, speed or 10)
    e.SpreadAngle = Vector2.new(180, 180)
    e.Lifetime = NumberRange.new((lifetime or 0.6) * 0.6, lifetime or 0.6)
    e.Acceleration = Vector3.new(0, -20, 0)
    e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 0.5), NumberSequenceKeypoint.new(1, 0) })
    e.Parent = a
    e:Emit(if Ctx.reducedMotion() then math.ceil(count / 2) else count)
    task.delay((lifetime or 0.6) + 0.2, function()
        a:Destroy()
    end)
end

-- Text that floats `rise` studs up from a point and fades over `seconds` (income ticks, hearts, labels)
function Fx.floatText(position: Vector3, text: string, color: Color3, rise: number?, seconds: number?, height: number?)
    local a = Instance.new("Attachment")
    a.WorldPosition = position
    a.Parent = Workspace.Terrain
    local gui = Instance.new("BillboardGui")
    gui.Size = UDim2.fromScale(4, height or 1.2)
    gui.LightInfluence = 0
    gui.AlwaysOnTop = true
    gui.MaxDistance = 60
    gui.Parent = a
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Text = text
    label.TextScaled = true
    label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
    label.TextColor3 = color
    label.TextStrokeTransparency = 1
    local stroke = Instance.new("UIStroke") -- thick dark stroke like every HUD text (ui-style-spec C6)
    stroke.Color = Color3.fromHex("2A2B31")
    stroke.Thickness = 2.5
    stroke.Parent = label
    label.Parent = gui
    local time = seconds or 0.9
    Fx.tween(a, time, { WorldPosition = position + Vector3.new(0, rise or 3, 0) })
    Fx.tween(label, time, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    Fx.tween(stroke, time, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    task.delay(time + 0.05, function()
        a:Destroy()
    end)
end

-- Moves a part along a quadratic Bezier from -> to with the control point `apex` studs above the higher end.
-- spins = full turns about its X axis. Calls onDone at the end. Returns a cancel function.
function Fx.arc(
    part: BasePart,
    from: Vector3,
    to: Vector3,
    apex: number,
    seconds: number,
    spins: number?,
    onDone: (() -> ())?
): () -> ()
    local control = (from + to) / 2
    control = Vector3.new(control.X, math.max(from.Y, to.Y) + apex, control.Z)
    local start = os.clock()
    local conn: RBXScriptConnection
    conn = RunService.RenderStepped:Connect(function()
        local a = math.clamp((os.clock() - start) / math.max(seconds, 0.01), 0, 1)
        local p = from:Lerp(control, a):Lerp(control:Lerp(to, a), a)
        part.CFrame = CFrame.new(p) * CFrame.Angles(a * (spins or 0) * 2 * math.pi, 0, 0)
        if a >= 1 then
            conn:Disconnect()
            if onDone then
                onDone()
            end
        end
    end)
    return function()
        conn:Disconnect()
    end
end

-- Landing squash: Y to 0.7 in 0.08 s, then back with Back easing in 0.25 s
function Fx.squash(part: BasePart, size: Vector3)
    part.Size = Vector3.new(size.X * 1.15, size.Y * 0.7, size.Z * 1.15)
    task.delay(0.08, function()
        Fx.tween(part, 0.25, { Size = size }, Enum.EasingStyle.Back)
    end)
end

-- Where food for a zone and game distance lands on the canyon floor (design-v3 3.4)
function Fx.landingPoint(zoneId: number, distance: number): Vector3
    local floor
    for _, f in game:GetService("CollectionService"):GetTagged("FLZoneFloor") do
        local id = f:GetAttribute("ZoneId")
        if type(id) == "number" and id <= zoneId and (not floor or id > (floor:GetAttribute("ZoneId") :: number)) then
            floor = f
        end
    end
    if not floor then
        return Vector3.new(-55, -76.8, 400)
    end
    local zone = Ctx.Economy.Zones[zoneId]
    local fraction = 1
    if (floor:GetAttribute("ZoneId") :: number) == zoneId and zone.MaxDist < math.huge then
        fraction = math.clamp((distance - zone.MinDist) / (zone.MaxDist - zone.MinDist), 0.02, 0.98)
    end
    local z = (floor:GetAttribute("FloorStartZ") :: number) + fraction * (floor:GetAttribute("FloorLength") :: number)
    local x = (floor:GetAttribute("CenterX") :: number) + (math.random() - 0.5) * 24
    return Vector3.new(x, floor:GetAttribute("SurfaceY") :: number, z)
end

return Fx
