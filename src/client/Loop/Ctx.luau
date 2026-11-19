--!strict
-- Shared client context for the v3 loop: remotes, own plot, the client's copy of nest and pets, a tiny event bus.
-- The server decides every outcome (docs/ai/server-v3-notes.md); this copy only drives what is shown.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

export type Egg = { id: number, zone: number, sparkle: boolean, state: string, arrivesAt: number? }
export type Pet = { id: number, species: string, mutation: string, rarity: string, pen: boolean, income: number }

local Ctx = {}
Ctx.player = Players.LocalPlayer
Ctx.remotes = ReplicatedStorage:WaitForChild("RemotesV3")
Ctx.Economy = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Economy")) :: any
Ctx.plot = nil :: Model?
Ctx.nest = {} :: { Egg } -- throw order (ids ascending)
Ctx.pets = {} :: { Pet }
Ctx.stats = { throws = 0, hatches = 0 }
Ctx.settings = { followThrows = false, reducedMotion = false }
Ctx.strength = 50
Ctx.foodTier = 1
Ctx.nozzleLevel = 1
Ctx.dumbbellTier = 1
Ctx.book = {} :: { [string]: boolean } -- found species -> claimed
Ctx.pity = {} :: { [number]: number } -- discovery meter per zone id (server HatchResult / GetState)
Ctx.lifting = false -- on the Lift Bench
Ctx.washing = false -- in the wash view
Ctx.revealing = false -- full reveal playing: spraying paused

local listeners: { [string]: { (...any) -> () } } = {}

function Ctx.on(name: string, fn: (...any) -> ())
    listeners[name] = listeners[name] or {}
    table.insert(listeners[name], fn)
end

function Ctx.emit(name: string, ...: any)
    for _, fn in listeners[name] or {} do
        task.spawn(fn, ...)
    end
end

function Ctx.now(): number
    return Workspace:GetServerTimeNow()
end

-- Runs fn at a server time (compare with the server's timestamps directly)
function Ctx.at(serverTime: number, fn: () -> ())
    task.delay(math.max(0, serverTime - Ctx.now()), fn)
end

-- InvokeServer that never throws: a dropped call looks like any other failed reply
function Ctx.invoke(name: string, ...: any): any
    local remote = Ctx.remotes:FindFirstChild(name) :: RemoteFunction?
    if not remote then
        return { ok = false, message = "Still loading, one moment!" }
    end
    local ok, reply = pcall(remote.InvokeServer, remote, ...)
    if not ok or type(reply) ~= "table" then
        warn("[Loop] " .. name .. " failed: " .. tostring(reply))
        return { ok = false, message = "Something went wrong. Try again!" }
    end
    return reply
end

function Ctx.root(): BasePart?
    local char = Ctx.player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return if root and root:IsA("BasePart") then root else nil
end

function Ctx.station(name: string): Model
    local plot = Ctx.plot :: Model
    return plot:FindFirstChild(name) :: Model
end

-- Horizontal distance from the character to a station's pivot (math.huge when there is no character)
function Ctx.distanceTo(name: string): number
    local root = Ctx.root()
    if not root or not Ctx.plot then
        return math.huge
    end
    local d = root.Position - Ctx.station(name):GetPivot().Position
    if math.abs(d.Y) > 8 then
        return math.huge
    end
    return Vector2.new(d.X, d.Z).Magnitude
end

-- Plot rotation: +Z points away from the canyon (toward spawn and pen)
function Ctx.plotRotation(): CFrame
    return (Ctx.plot :: Model):GetPivot().Rotation
end

function Ctx.findEgg(id: number): (Egg?, number?)
    for i, egg in Ctx.nest do
        if egg.id == id then
            return egg, i
        end
    end
    return nil, nil
end

function Ctx.removeEgg(id: number)
    local _, i = Ctx.findEgg(id)
    if i then
        table.remove(Ctx.nest, i)
    end
end

-- Eggs that are landed and waiting (not flying, not on the turntable)
function Ctx.waitingEggs(): number
    local n = 0
    for _, egg in Ctx.nest do
        if egg.state == "Nest" or (egg.state == "Flight" and (egg.arrivesAt or 0) <= Ctx.now()) then
            n += 1
        end
    end
    return n
end

function Ctx.reducedMotion(): boolean
    return GuiService.ReducedMotionEnabled or Ctx.settings.reducedMotion
end

return Ctx
