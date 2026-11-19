--!strict
-- v3 core loop client entry (VS-6 to VS-10). Finds the player's plot, loads the server state once, starts
-- each module and keeps the objective banner and arrow trail current for the saved onboarding step
-- (player attribute TutorialStep, advanced by the server). Module map: docs/ai/client-v3-notes.md.

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
local Lift = require(script.Parent.Lift)
local Menus = require(script.Parent.Menus)
local Trail = require(script.Parent.Trail)
local Teaser = require(script.Parent.Teaser)
local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))
local Logic = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Logic"))
local Goals = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Goals"))

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
Ctx.dumbbellTier = state.dumbbellTier
Ctx.stats = state.stats
local function readPity(view: any)
    table.clear(Ctx.pity)
    for k, v in view or {} do
        local zone = tonumber(k)
        if zone and type(v) == "number" then
            Ctx.pity[zone] = v
        end
    end
end
readPity(state.pity)
Ctx.on("hatched", function(r: any)
    readPity(r.pity)
end)
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
for attr, field in { FoodTier = "foodTier", NozzleLevel = "nozzleLevel", DumbbellTier = "dumbbellTier" } do
    player:GetAttributeChangedSignal(attr):Connect(function()
        local v = player:GetAttribute(attr)
        if type(v) == "number" and v ~= (Ctx :: any)[field] then
            (Ctx :: any)[field] = v
            Hud.refreshFood()
        end
    end)
end

Hud.refreshFood()
Nest.refresh()
Pen.sync()
Hatch.init()
Throw.init(zones)
Wash.init()
Lift.init()
Menus.init(state)
Trail.init()
for _, egg in Ctx.nest do -- eggs saved mid-flight land when their time comes
    if egg.state == "Flight" then
        Ctx.at(egg.arrivesAt or 0, function()
            egg.state = "Nest"
            Nest.refresh()
        end)
    end
end

-- Objective banner and trail. During onboarding (steps 1-15, design-v3 section 5) the saved step decides;
-- afterwards Goals picks the player's real next goal (never a tutorial line).
local function nestFull(): boolean
    return #Ctx.nest >= (player:GetAttribute("NestSlots") or 2)
end

local function goalState(): Goals.State
    local found, unclaimed = {}, 0
    for species, claimed in Ctx.book do
        found[species] = true
        if not claimed then
            unclaimed += 1
        end
    end
    return {
        coins = player:GetAttribute("Coins") or 0,
        strength = Ctx.strength,
        foodTier = Ctx.foodTier,
        nozzleLevel = Ctx.nozzleLevel,
        dumbbellTier = Ctx.dumbbellTier,
        nestSlots = player:GetAttribute("NestSlots") or 2,
        found = found,
        unclaimed = unclaimed,
        pity = Ctx.pity,
        nestFull = nestFull(),
        waitingEggs = Ctx.waitingEggs(),
    }
end

-- Returns banner text and trail target (station name) for the current step
local function objective(step: number): (string?, string?)
    if Ctx.washing then
        return nil, nil
    elseif Ctx.revealing then
        return "It's hatching...", nil
    end
    local marsh = Ctx.Economy.Zones[2].StrengthGate
    if step <= 1 then
        return "Walk to the ledge!", "Ledge"
    elseif step == 2 then
        return if Throw.onLedge then "Hold to throw food to Mama Hen!" else "Walk to the ledge!", "Ledge"
    elseif step == 3 then
        return "Watch Mama Hen eat!", nil
    elseif step == 4 then
        return "Wash your muddy egg!", "Washer"
    elseif step == 5 then
        return "Spray all the mud off!", "Washer"
    elseif step == 6 then
        return "It's hatching...", nil
    elseif step == 7 then
        return "New creature! Claim it in your Book", nil
    elseif step == 8 then
        if nestFull() then
            return "Wash your eggs!", "Washer"
        end
        return "Throw 2 more eggs!", "Ledge"
    elseif step == 9 then
        return "Wash your eggs!", if Ctx.waitingEggs() > 0 then "Washer" else nil
    elseif step == 10 then
        if (player:GetAttribute("Coins") or 0) >= Ctx.Economy.NestSlotCost[3] then
            return "Buy a bigger nest!", "Sign_Nest"
        end
        return "Earn 100 coins: your pets are working!", nil
    elseif step == 11 then
        return "Throw farther: train at the Lift Bench!", "LiftBench"
    elseif step == 12 then
        return "Lift until Strength " .. marsh .. "!", if Ctx.lifting then nil else "LiftBench"
    elseif step == 13 then
        for _, egg in Ctx.nest do
            if egg.zone >= 2 then -- the Marsh egg is already caught: wash it, do not throw more Meadow eggs
                return "Wash your Bog Marsh egg!", if egg.state == "Flight" then nil else "Washer"
            end
        end
        if nestFull() then
            return "Nest full! Wash your eggs first.", "Washer"
        end
        return "Throw into the Bog Marsh: release on SWEET!", "Ledge"
    elseif step == 14 then
        return "Claim your new creature in your Book!", nil
    elseif step == 15 then
        return "Buy Carrots for better eggs!", "Sign_Food"
    end
    return nil, nil -- after the tutorial: the goal line (Goals.next)
end

-- Next creature card (Hud.nextCreature): "???" silhouette of the next creature and the bar toward it
local card = Hud.nextCreature
local cardSpecies = ""
local function refreshCard(step: number)
    local t = if step >= 8 then Goals.nextCreature(goalState()) else nil
    card.frame.Visible = t ~= nil
    if not t then
        return
    end
    if t.creature.Name ~= cardSpecies then
        cardSpecies = t.creature.Name
        card.holder:ClearAllChildren()
        local c = Kit.rarityCard(card.holder, t.creature.Rarity, true)
        Pen.viewport(c.viewport, t.creature.Name, t.creature.Rarity)
        Kit.pop(card.frame, 1.15)
    end
    local ready = not t.locked and t.current >= t.target
    card.title.Text = if ready then "NEXT EGG!" else "NEXT"
    local label = if t.locked
        then "Str " .. Logic.formatNumber(t.current) .. "/" .. Logic.formatNumber(t.target)
        else t.current .. "/" .. t.target .. " eggs"
    Kit.setProgress(card.bar, t.current / t.target, if ready then "Guaranteed!" else label)
end

local keeperUntil = 0
local lastGoal = ""
local goalTrailUntil = 0
local lastStep = math.max(player:GetAttribute("TutorialStep") or 0, state.tutorialStep or 0)
player:GetAttributeChangedSignal("TutorialStep"):Connect(function()
    local step = player:GetAttribute("TutorialStep") or 0
    if step >= 16 and lastStep < 16 then
        keeperUntil = os.clock() + 3 -- shown live only, never to a returning player
    end
    lastStep = step
    Hud.setStep(step)
end)
Hud.setStep(lastStep)

while true do
    local step = player:GetAttribute("TutorialStep") or 0
    if os.clock() < keeperUntil then
        Hud.setBanner("You're a Sanctuary Keeper! Keep hatching!")
        Trail.set(nil)
    else
        local text, target = objective(step)
        -- count goals get the mini bar under the objective (ui-style-spec 2.4)
        local current, goal = nil, nil
        local cost = Ctx.Economy.NestSlotCost[3]
        if step >= 16 and not Ctx.washing and not Ctx.revealing then
            local g = Goals.next(goalState(), Logic.formatNumber)
            if g.text ~= lastGoal then
                lastGoal = g.text
                goalTrailUntil = os.clock() + 6 -- a new goal shows the way briefly, then the trail steps aside
            end
            text, target = g.text, if os.clock() < goalTrailUntil then g.trail else nil
            current, goal = g.current, g.target
        elseif step == 10 and (player:GetAttribute("Coins") or 0) < cost then
            current, goal = player:GetAttribute("Coins") or 0, cost
        elseif step == 12 and not Ctx.lifting then -- the lift HUD has its own Strength bar
            current, goal = Ctx.strength, Ctx.Economy.Zones[2].StrengthGate
        end
        Hud.setBanner(text)
        Trail.set(target)
        Hud.setGoal(current, goal)
    end
    refreshCard(step)
    Teaser.update(Ctx.strength)
    task.wait(0.2)
end
