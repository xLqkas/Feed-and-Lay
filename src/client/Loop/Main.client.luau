--!strict
-- v3 core loop client entry (VS-6, VS-7, VS-8). Finds the player's plot, loads the server state once,
-- starts each module and keeps the objective banner current. Module map: docs/ai/client-v3-notes.md.

local CollectionService = game:GetService("CollectionService")

local Ctx = require(script.Parent.Ctx)
local player = Ctx.player

while not player:GetAttribute("PlotId") do
    player:GetAttributeChangedSignal("PlotId"):Wait()
end
local plotId = player:GetAttribute("PlotId")
while not Ctx.plot do
    for _, plot in CollectionService:GetTagged("FLPlot") do
        if plot:GetAttribute("PlotId") == plotId and plot:IsA("Model") then
            Ctx.plot = plot
        end
    end
    if not Ctx.plot then
        task.wait(0.5)
    end
end

local Hud = require(script.Parent.Hud)
local Nest = require(script.Parent.Nest)
local Pen = require(script.Parent.Pen)
local Throw = require(script.Parent.Throw)
local Wash = require(script.Parent.Wash)
local Hatch = require(script.Parent.Hatch)

local state
repeat
    state = Ctx.invoke("GetState")
    if not state.ok then
        task.wait(1)
    end
until state.ok

Ctx.strength = state.strength
Ctx.foodTier = state.foodTier
Ctx.nozzleLevel = state.nozzleLevel
Ctx.stats = state.stats
Ctx.settings.followThrows = state.settings.followThrows == true
Ctx.settings.reducedMotion = state.settings.reducedMotion == true
local zones: { [number]: boolean } = {}
for _, egg in state.nest do
    -- an egg still on the turntable from before a reconnect is back in the nest once we leave the washer
    table.insert(Ctx.nest, {
        id = egg.id,
        zone = egg.zone,
        sparkle = egg.sparkle,
        state = if egg.state == "Flight" then "Flight" else "Nest",
        arrivesAt = egg.arrivesAt,
    })
    zones[egg.zone] = true
end
for _, pet in state.pets do
    table.insert(Ctx.pets, pet)
    zones[Ctx.Economy.CreatureByName[pet.species].Zone] = true
end
if state.washing then
    task.spawn(Ctx.invoke, "StopWash")
end
player:GetAttributeChangedSignal("Strength"):Connect(function()
    Ctx.strength = player:GetAttribute("Strength") or Ctx.strength
end)

Hud.refreshFood()
Nest.refresh()
Pen.sync()
Hatch.init()
Throw.init(zones)
Wash.init()
for _, egg in Ctx.nest do -- eggs saved mid-flight land when their time comes
    if egg.state == "Flight" then
        Ctx.at(egg.arrivesAt or 0, function()
            egg.state = "Nest"
            Nest.refresh()
        end)
    end
end

-- Objective banner slot (onboarding steps and arrow trail are VS-10)
local function objective(): string?
    if Ctx.washing then
        return nil
    elseif Ctx.revealing then
        return "It's hatching..."
    end
    local flying = false
    for _, egg in Ctx.nest do
        if egg.state == "Flight" then
            flying = true
        end
    end
    if Ctx.waitingEggs() > 0 then
        return if Throw.onLedge and #Ctx.nest < (player:GetAttribute("NestSlots") or 2)
            then "Throw again, or wash your eggs!"
            else "Wash your muddy egg!"
    elseif flying then
        return "Watch Mama Hen eat!"
    elseif Throw.onLedge then
        return "Hold to throw food to Mama Hen!"
    end
    return "Walk to the ledge!"
end

while true do
    Hud.setBanner(objective())
    task.wait(0.2)
end
