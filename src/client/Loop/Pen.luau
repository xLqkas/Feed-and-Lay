--!strict
-- Pen (design-v3 3.7, VS-8): pet models (Creatures) on the pen spots, wandering inside their 6 x 6 spot with an
-- idle bob, a hop on every income tick, name + rarity billboard (40 studs), and "+X" floating up over each pen
-- pet once a second (12 nearest).

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Creatures = require(script.Parent.Creatures)
local Ctx = require(script.Parent.Ctx)
local Fx = require(script.Parent.Fx)
local Logic = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Logic"))
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme"))

local Pen = {}

local WALK_SPEED = 4
local SPOT_HALF = 2.5 -- wander inside the 6 x 6 spot, keeping clear of its edge
local MAX_FLOATERS = 12
local SPOTS = 16

type Entry = {
    model: Model,
    body: BasePart,
    spot: number,
    home: Vector3,
    pos: Vector3,
    target: Vector3,
    nextMove: number,
    income: number,
    rainbow: boolean,
    hopping: boolean,
    hopAt: number,
}
local entries: { [number]: Entry } = {}

local function rarityIndex(rarity: string): number
    return table.find(Theme.RarityOrder, rarity) or 1
end

-- Builds a pet model (PrimaryPart Body, pivot at the body centre, attribute FootDrop). Used by the reveal too.
function Pen.makePet(species: string, mutation: string, rarity: string): Model
    local radius = 0.8 + 0.12 * rarityIndex(rarity)
    local model = Creatures.build(species, radius, mutation, rarity)
    local body = model.PrimaryPart :: BasePart
    model:SetAttribute("FootDrop", Creatures.footDrop(species, radius))
    local _, extents = model:GetBoundingBox()

    local gui = Instance.new("BillboardGui")
    gui.Name = "Tag"
    gui.Size = UDim2.fromOffset(130, 36) -- small and short-range so a full pen does not bury the HUD (m5)
    gui.StudsOffset = Vector3.new(0, extents.Y / 2 + 0.8, 0)
    gui.MaxDistance = 28
    gui.LightInfluence = 0
    gui.Parent = body
    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1
    name.Size = UDim2.fromScale(1, 0.55)
    name.Text = if mutation ~= "Normal" then mutation .. " " .. species else species
    name.TextScaled = true
    name.FontFace = Theme.Fonts.title
    name.TextColor3 = Color3.new(1, 1, 1)
    local stroke = Instance.new("UIStroke") -- thick dark stroke like every HUD text (ui-style-spec C6)
    stroke.Color = Theme.Colors.outline
    stroke.Thickness = 2.5
    stroke.Parent = name
    name.Parent = gui
    local word = name:Clone()
    word.Position = UDim2.fromScale(0, 0.55)
    word.Size = UDim2.fromScale(1, 0.45)
    word.Text = string.upper(rarity)
    word.TextColor3 = (Theme.Rarity :: any)[rarity] or Color3.new(1, 1, 1)
    word.Parent = gui
    model.Parent = Fx.folder
    return model
end

-- Puts a pet model in a ViewportFrame, framed by its bounding box (Book cards, next-creature card)
function Pen.viewport(vp: ViewportFrame, species: string, rarity: string)
    vp:ClearAllChildren()
    local model = Pen.makePet(species, "Normal", rarity)
    local tag = model:FindFirstChild("Tag", true)
    if tag then
        tag:Destroy()
    end
    for _, d in model:GetDescendants() do
        if d:IsA("ParticleEmitter") or d:IsA("Sparkles") then
            d:Destroy()
        end
    end
    model:PivotTo(CFrame.Angles(0, math.rad(200), 0))
    model.Parent = vp
    local cf, size = model:GetBoundingBox()
    local camera = Instance.new("Camera")
    camera.FieldOfView = 30
    local dist = size.Magnitude * 1.9
    camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, size.Y * 0.25, -dist), cf.Position)
    camera.Parent = vp
    vp.CurrentCamera = camera
end

local function spotPoint(i: number): Vector3
    local floor = Ctx.station("Pen"):FindFirstChild("PenFloor") :: BasePart
    return (floor:FindFirstChild("Spot" .. i) :: Attachment).WorldPosition
end

local function freeSpot(): number?
    local used = {}
    for _, e in entries do
        used[e.spot] = true
    end
    for i = 1, SPOTS do
        if not used[i] then
            return i
        end
    end
    return nil
end

-- Adds a pen pet. With `model` (from the reveal) it jumps there in a 0.6 s arc; otherwise it appears.
function Pen.add(pet: Ctx.Pet, model: Model?)
    if entries[pet.id] then
        return
    end
    local spot = freeSpot()
    if not spot then
        if model then
            model:Destroy()
        end
        return
    end
    local m = model or Pen.makePet(pet.species, pet.mutation, pet.rarity)
    local body = m.PrimaryPart :: BasePart
    local radius = (m:GetAttribute("FootDrop") :: number?) or body.Size.Y / 2
    local home = spotPoint(spot) + Vector3.new(0, radius, 0)
    local entry: Entry = {
        model = m,
        body = body,
        spot = spot,
        home = home,
        pos = home,
        target = home,
        nextMove = os.clock() + 1 + math.random() * 3,
        income = pet.income,
        rainbow = pet.mutation == "Rainbow",
        hopping = model ~= nil,
        hopAt = -math.huge,
    }
    entries[pet.id] = entry
    if model then
        local from = m:GetPivot().Position
        local mover = Instance.new("Part") -- Fx.arc drives a part; the model follows it
        mover.Transparency = 1
        mover.Anchored = true
        mover.CanCollide = false
        mover.Parent = Fx.folder
        local conn = RunService.RenderStepped:Connect(function()
            m:PivotTo(CFrame.new(mover.Position) * m:GetPivot().Rotation)
        end)
        Fx.arc(mover, from, home, 6, 0.6, 0, function()
            conn:Disconnect()
            mover:Destroy()
            entry.hopping = false
            Fx.burst(home - Vector3.new(0, radius, 0), Color3.fromRGB(205, 180, 140), 8, 5, 0.4)
        end)
    else
        m:PivotTo(CFrame.new(home))
    end
end

function Pen.remove(id: number)
    local e = entries[id]
    if e then
        e.model:Destroy()
        entries[id] = nil
    end
end

-- Matches the pen to Ctx.pets (join, swaps)
function Pen.sync()
    local keep = {}
    for _, pet in Ctx.pets do
        if pet.pen then
            keep[pet.id] = true
            Pen.add(pet)
        end
    end
    for id in entries do
        if not keep[id] then
            Pen.remove(id)
        end
    end
end

RunService.Heartbeat:Connect(function(dt)
    local now = os.clock()
    for _, e in entries do
        if e.hopping then
            continue
        end
        if now >= e.nextMove then
            e.target = e.home + Vector3.new((math.random() * 2 - 1) * SPOT_HALF, 0, (math.random() * 2 - 1) * SPOT_HALF)
            e.nextMove = now + 3 + math.random() * 3
        end
        local delta = e.target - e.pos
        local step = math.min(delta.Magnitude, WALK_SPEED * dt)
        local facing = e.model:GetPivot().Rotation
        if step > 0.01 then
            e.pos += delta.Unit * step
            facing = CFrame.lookAt(Vector3.zero, delta * Vector3.new(1, 0, 1)).Rotation
        end
        local bob = math.abs(math.sin(now * (if step > 0.01 then 10 else 3))) * (if step > 0.01 then 0.35 else 0.15)
        local t = (now - e.hopAt) / 0.35 -- income hop: a quick 0.6-stud jump with a squash-free arc
        if t < 1 then
            bob += math.sin(t * math.pi) * 0.6
        end
        e.model:PivotTo(CFrame.new(e.pos + Vector3.new(0, bob, 0)) * facing)
        if e.rainbow then
            e.body.Color = Color3.fromHSV((now * 0.25) % 1, 0.6, 1)
        end
    end
end)

-- Income floaters: once a second over the 12 pen pets nearest the camera, rippling by index x 0.08 s
task.spawn(function()
    while true do
        task.wait(1)
        local camPos = Workspace.CurrentCamera.CFrame.Position
        local list = {}
        for _, e in entries do
            table.insert(list, e)
        end
        table.sort(list, function(a, b)
            return (a.pos - camPos).Magnitude < (b.pos - camPos).Magnitude
        end)
        for i = 1, math.min(#list, MAX_FLOATERS) do
            local e = list[i]
            task.delay((i - 1) * 0.08, function()
                if e.model.Parent then
                    e.hopAt = os.clock()
                    Fx.floatText(
                        e.pos + Vector3.new(0, e.body.Size.Y, 0),
                        "+" .. Logic.formatNumber(e.income),
                        Theme.Colors.money,
                        3,
                        0.9
                    )
                end
            end)
        end
    end
end)

return Pen
