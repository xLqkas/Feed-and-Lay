--!strict
-- Nest rack (design-v3 3.4): egg return arc into the next free cup, landing juice, eggs sitting in cups,
-- padlocks on locked cups and the "used/size" billboard. The server's egg list is the truth (Ctx.nest).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Cam = require(script.Parent.Cam)
local Ctx = require(script.Parent.Ctx)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer
local NEST_SCALE = 0.42 -- egg in a cup: about 1.0 x 1.26 studs
local FLIGHT_SCALE = 1.2 -- bigger in the air so it reads from far away
local MAX_SLOTS = 8

local Nest = {}
local slotOf: { [number]: number } = {}
local models: { [number]: BasePart } = {}

local function slotPoint(i: number): Attachment
    local slot = Ctx.station("Nest"):FindFirstChild("Slot" .. i) :: BasePart
    return slot:FindFirstChild("EggPoint") :: Attachment
end

local function reserve(id: number): number?
    if slotOf[id] then
        return slotOf[id]
    end
    local used = {}
    for _, i in slotOf do
        used[i] = true
    end
    for i = 1, MAX_SLOTS do
        if not used[i] then
            slotOf[id] = i
            return i
        end
    end
    return nil
end

local function cupPosition(id: number): Vector3
    local i = reserve(id)
    return if i then slotPoint(i).WorldPosition else Ctx.station("Nest"):GetPivot().Position + Vector3.new(0, 1, 0)
end

-- Padlocks, count billboard, and eggs that are in the nest without a model (loaded from a save, wash stopped)
function Nest.refresh()
    local nest = Ctx.station("Nest")
    local slots = player:GetAttribute("NestSlots") or Ctx.Economy.START_NEST
    for i = 1, MAX_SLOTS do
        local slot = nest:FindFirstChild("Slot" .. i)
        local lock = slot and slot:FindFirstChild("Lock")
        if lock and lock:IsA("BillboardGui") then
            lock.Enabled = i > slots
        end
    end
    local count = nest:FindFirstChild("Rack") and nest.Rack:FindFirstChild("Count")
    local label = count and count:FindFirstChild("Text")
    if label and label:IsA("TextLabel") then
        label.Text = (player:GetAttribute("NestUsed") or #Ctx.nest) .. "/" .. slots
    end
    for _, egg in Ctx.nest do
        if egg.state == "Nest" and not models[egg.id] then
            local part = Fx.egg(egg.zone, egg.sparkle, NEST_SCALE)
            part.CFrame = CFrame.new(cupPosition(egg.id))
            models[egg.id] = part
        end
    end
end
player:GetAttributeChangedSignal("NestUsed"):Connect(Nest.refresh)
player:GetAttributeChangedSignal("NestSlots"):Connect(Nest.refresh)

local function trail(egg: BasePart, color: Color3)
    local a0 = Instance.new("Attachment")
    a0.Position = Vector3.new(0, 0.6, 0)
    a0.Parent = egg
    local a1 = Instance.new("Attachment")
    a1.Position = Vector3.new(0, -0.6, 0)
    a1.Parent = egg
    local t = Instance.new("Trail")
    t.Attachment0, t.Attachment1 = a0, a1
    t.Color = ColorSequence.new(color)
    t.Lifetime = 0.35
    t.Transparency = NumberSequence.new(0.2, 1)
    t.LightEmission = if color == Fx.MUD[1] then 0 else 0.6
    t.Parent = egg
end

-- Egg return leg: launched at launchAt from `from`, lands in its cup at arrivesAt (server times).
-- onLaunch gets the flying part (throw cam rides with it).
function Nest.incoming(
    eggId: number,
    zone: number,
    sparkle: boolean,
    from: Vector3,
    launchAt: number,
    arrivesAt: number,
    onLaunch: ((BasePart) -> ())?
)
    Ctx.at(launchAt, function()
        local target = cupPosition(eggId)
        local egg = Fx.egg(zone, sparkle, FLIGHT_SCALE)
        trail(egg, Fx.MUD[zone] or Fx.MUD[1])
        if sparkle then
            trail(egg, Color3.fromRGB(255, 215, 80))
            Sfx.play("ding", 1.5, 0.5)
        end
        local seconds = math.max(0.2, arrivesAt - Ctx.now())
        Fx.tween(egg, seconds, { Size = Fx.EGG_SIZE * NEST_SCALE }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        if onLaunch then
            onLaunch(egg)
        end
        Fx.arc(egg, from, target, 60, seconds, 2, function()
            for _, c in egg:GetChildren() do
                if c:IsA("Trail") then
                    c.Enabled = false
                end
            end
            local mine = Ctx.findEgg(eggId)
            if not mine then -- washed or gone meanwhile
                egg:Destroy()
                return
            end
            mine.state = "Nest"
            models[eggId] = egg
            egg.CFrame = CFrame.new(target)
            Fx.squash(egg, Fx.EGG_SIZE * NEST_SCALE)
            Fx.burst(target, Color3.fromRGB(205, 180, 140), 12, 6, 0.4, 0.5)
            Sfx.play("thunk", 1, 1, target)
            local camera = Workspace.CurrentCamera
            if (camera.CFrame.Position - target).Magnitude < 40 then
                Cam.shake(0.15, 0.3)
            end
            Ctx.emit("nest")
        end)
    end)
end

-- The egg leaves its cup (onto the turntable). Returns its part, if one is shown.
function Nest.take(eggId: number): BasePart?
    local part = models[eggId]
    models[eggId] = nil
    slotOf[eggId] = nil
    return part
end

function Nest.remove(eggId: number)
    local part = Nest.take(eggId)
    if part then
        part:Destroy()
    end
end

return Nest
