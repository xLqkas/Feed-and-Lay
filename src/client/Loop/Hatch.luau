--!strict
-- Hatch Pad (design-v3 3.6, VS-8): full reveal (3 s wobble with cracks, 2 s slot roll, burst, 1.5 s hold, camera
-- on the pad) or compact reveal (1.5 s crack, 1.0 s roll on a small card). The server already made the pet
-- (HatchResult); this only shows it, then the pet jumps to its pen spot.

local RunService = game:GetService("RunService")

local Cam = require(script.Parent.Cam)
local Ctx = require(script.Parent.Ctx)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)
local Nest = require(script.Parent.Nest)
local Pen = require(script.Parent.Pen)
local Sfx = require(script.Parent.Sfx)
local UI = script.Parent.Parent:WaitForChild("UI")
local Logic = require(UI:WaitForChild("Logic"))
local Theme = require(UI:WaitForChild("Theme"))

local Economy = Ctx.Economy
local Hatch = {}
local handed: { [number]: BasePart } = {}
local shelfUsed: { [number]: boolean } = {}

local function rarityColor(rarity: string): Color3
    return (Theme.Rarity :: any)[rarity] or Color3.new(1, 1, 1)
end

local function padPoint(): Vector3
    local pedestal = Ctx.station("HatchPad"):FindFirstChild("Pedestal") :: BasePart
    return (pedestal:FindFirstChild("EggPoint") :: Attachment).WorldPosition + Vector3.new(0, 0.5, 0)
end

-- The washer hands over the clean egg part when washing ends
function Hatch.handOver(eggId: number, part: BasePart)
    handed[eggId] = part
end

-- The pet's name billboard would sit under the reveal text; it is shown again when the reveal ends
local function showTag(pet: Model, on: boolean)
    local tag = pet:FindFirstChild("Tag", true) :: BillboardGui?
    if tag then
        tag.Enabled = on
    end
end

-- Slot roll: the zone's 3 creature names cycle `ticks` times with growing intervals, then land on the result
local function roll(card: Hud.Card, r: any, ticks: number, seconds: number)
    local names = {}
    for _, c in Economy.Creatures do
        if c.Zone == r.zone then
            table.insert(names, c)
        end
    end
    -- interval_i = a + b * (i / ticks)^2, scaled so the ticks fill `seconds`
    local weights, total = {}, 0
    for i = 1, ticks do
        weights[i] = 0.06 + 0.24 * ((i - 1) / math.max(ticks - 1, 1)) ^ 2
        total += weights[i]
    end
    for i = 1, ticks do
        local c = names[(i % #names) + 1]
        if i == ticks then
            c = Economy.CreatureByName[r.species]
        end
        card.name.Text = c.Name
        card.rarity.Text = string.upper(c.Rarity)
        card.rarity.TextColor3 = rarityColor(c.Rarity)
        Sfx.play("tick", 0.9 + i * 0.03, 0.6)
        task.wait(weights[i] * seconds / total)
    end
    if r.mutation ~= "Normal" then
        card.mutation.Text = "..." .. string.upper(r.mutation) .. "!"
        Sfx.play("tick", 1.5)
    end
end

-- Final card text with a pop; burst in rarity colour; fanfare by tier
local function burst(card: Hud.Card, r: any, at: Vector3, big: boolean)
    local color = rarityColor(r.rarity)
    card.rarity.Text = string.upper(r.rarity)
    card.rarity.TextColor3 = color
    card.name.Text = r.species
    card.mutation.Text = if r.mutation ~= "Normal"
        then string.upper(r.mutation)
        elseif r.gift then "MAMA HEN'S GIFT"
        else ""
    card.income.Text = "+" .. Logic.formatNumber(r.income) .. "/s"
    local edge = card.frame:FindFirstChild("Edge") :: UIStroke?
    if edge then
        edge.Color = color
    end
    Hud.revealLand(card, r.firstOfSpecies == true)
    -- the scripted first-time gift egg (server flag) gets the biggest reveal: confetti, top fanfare, FOV punch
    local rank = math.max(table.find(Economy.RarityOrder, r.rarity) or 1, if r.gift then 5 else 1)
    Fx.burst(at, color, if big then 30 else 14, 14, 0.6, 0.8)
    if big and rank >= 5 then
        for _, c in { Color3.fromRGB(255, 80, 80), Color3.fromRGB(80, 200, 255), Color3.fromRGB(255, 220, 60) } do
            Fx.burst(at + Vector3.new(0, 2, 0), c, 12, 18, 0.4, 1)
        end
    end
    Sfx.play(if rank >= 5 then "fanfare3" elseif rank >= 3 then "fanfare2" else "fanfare1", 1, if big then 1 else 0.5)
    if big and rank >= 3 then
        Cam.punch(64)
    end
end

local function shards(at: Vector3)
    for i = 1, 8 do
        local s = Fx.part("Shard", Vector3.new(0.6, 0.15, 0.5), Fx.SHELL)
        s.CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
        local a = (i / 8) * math.pi * 2
        local out = at + Vector3.new(math.cos(a) * 4, -1, math.sin(a) * 4)
        Fx.tween(s, 0.5, { Position = out, Transparency = 1 })
        task.delay(0.55, function()
            s:Destroy()
        end)
    end
end

local function placementToast(r: any)
    local p = r.placement
    if p.where == "storage" then
        Hud.toast(r.species .. " went to storage. Your pen is full!", "gain")
    elseif p.swappedOutSpecies then
        Hud.toast(r.species .. " joined your pen. " .. p.swappedOutSpecies .. " moved to storage.", "gain")
    end
end

-- Wobble the egg on the pad for `seconds`, cracking at each time in `cracks`
local function wobble(egg: BasePart, at: Vector3, seconds: number, cracks: { number }, amp: number)
    local lines: { { part: BasePart, offset: CFrame } } = {}
    local t0 = os.clock()
    local nextCrack = 1
    while os.clock() - t0 < seconds do
        local t = os.clock() - t0
        local cf = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(amp) * math.sin(t * 22) * (0.3 + 0.7 * t / seconds))
        egg.CFrame = cf
        for _, l in lines do
            l.part.CFrame = cf * l.offset
        end
        if cracks[nextCrack] and t >= cracks[nextCrack] then
            Sfx.play("crack", 0.9 + nextCrack * 0.1, 1, at)
            Fx.burst(at, Fx.SHELL, 6, 6, 0.25)
            local line = Fx.part("Crack", Vector3.new(0.12, 1.4, 0.12), Color3.fromRGB(60, 45, 35))
            local yaw = math.random() * math.pi * 2
            local offset = CFrame.Angles(0, yaw, 0)
                * CFrame.new(0, 0.2 * nextCrack, -egg.Size.Z / 2)
                * CFrame.Angles(0, 0, math.rad(math.random(-40, 40)))
            table.insert(lines, { part = line, offset = offset })
            nextCrack += 1
        end
        RunService.Heartbeat:Wait()
    end
    for _, l in lines do
        l.part:Destroy()
    end
end

local function full(r: any, egg: BasePart)
    Ctx.revealing = true
    local at = padPoint()
    local rot = Ctx.plotRotation()
    local camPos = at + rot:VectorToWorldSpace(Vector3.new(-0.55, 0.5, 1).Unit)
    local t0 = os.clock()
    local current = workspace.CurrentCamera.CFrame
    Cam.set("reveal", 30, function(dt)
        local push = 10 - math.min((os.clock() - t0) / 3, 1) -- slow push-in 10%
        -- look 1 stud above the egg so it sits below the reveal card, not behind it
        local look = at + Vector3.new(0, 1, 0)
        current = Cam.smooth(current, CFrame.lookAt(at + (camPos - at) * push, look), dt, 10)
        return current
    end)
    -- hop to the pad (0.5 s) inside the 3 s wobble window
    Fx.arc(egg, egg.Position, at, 3, 0.5, 0)
    task.wait(0.5)
    wobble(egg, at, 2.5, { 0.5, 1.5, 2.5 }, 12)
    local card = Hud.card(false)
    roll(card, r, 14, 2.0)
    egg:Destroy()
    shards(at)
    local pet = Pen.makePet(r.species, r.mutation, r.rarity)
    showTag(pet, false)
    pet:PivotTo(CFrame.lookAt(at, Vector3.new(camPos.X, at.Y, camPos.Z)))
    burst(card, r, at, true)
    task.wait(1.5)
    card.frame:Destroy()
    showTag(pet, true)
    Cam.clear("reveal")
    Ctx.revealing = false
    placementToast(r)
    if r.placement.where == "pen" then
        Pen.add({
            id = r.eggId,
            species = r.species,
            mutation = r.mutation,
            rarity = r.rarity,
            pen = true,
            income = r.income,
        }, pet)
    else
        pet:Destroy()
    end
    Ctx.emit("revealDone", r)
end

local function compact(r: any, egg: BasePart)
    local at = padPoint()
    Fx.arc(egg, egg.Position, at, 3, 0.4, 0)
    task.wait(0.4)
    wobble(egg, at, 1.1, { 0.4, 1.0 }, 8)
    local card = Hud.card(true)
    roll(card, r, 7, 0.9)
    egg:Destroy()
    shards(at)
    local pet = Pen.makePet(r.species, r.mutation, r.rarity)
    pet:PivotTo(CFrame.new(at))
    burst(card, r, at, false)
    task.wait(0.1)
    placementToast(r)
    if r.placement.where == "pen" then
        Pen.add({
            id = r.eggId,
            species = r.species,
            mutation = r.mutation,
            rarity = r.rarity,
            pen = true,
            income = r.income,
        }, pet)
    else
        pet:Destroy()
    end
    task.delay(0.6, function()
        card.frame:Destroy()
    end)
    Ctx.emit("revealDone", r)
end

function Hatch.init()
    Ctx.remotes:WaitForChild("HatchResult").OnClientEvent:Connect(function(r: any)
        Ctx.removeEgg(r.eggId)
        local pet = {
            id = r.eggId,
            species = r.species,
            mutation = r.mutation,
            rarity = r.rarity,
            pen = r.placement.where == "pen",
            income = r.income,
        }
        table.insert(Ctx.pets, pet)
        local swapped = r.placement.swappedOutId
        if swapped then
            for _, p in Ctx.pets do
                if p.id == swapped then
                    p.pen = false
                end
            end
            Pen.remove(swapped)
        end
        Ctx.stats.hatches += 1
        Ctx.emit("hatched", r)
        Ctx.emit("nest")

        local egg = handed[r.eggId] or Nest.take(r.eggId) or Fx.egg(r.zone, false, 1)
        handed[r.eggId] = nil
        egg.Color = Fx.SHELL
        egg.Material = Enum.Material.SmoothPlastic
        local shelf: number? = nil
        if r.revealAt - Ctx.now() > 0.3 then -- waits for an earlier reveal: sit on the queue shelf
            for i = 1, 8 do
                if not shelfUsed[i] then
                    shelf = i
                    shelfUsed[i] = true
                    break
                end
            end
            local queue = Ctx.station("HatchPad"):FindFirstChild("QueueShelf")
            local point = shelf and queue and queue:FindFirstChild("Queue" .. shelf)
            if point and point:IsA("Attachment") then
                Fx.tween(egg, 0.4, { Size = Fx.EGG_SIZE * 0.5 })
                Fx.arc(egg, egg.Position, point.WorldPosition + Vector3.new(0, 0.7, 0), 2, 0.4, 0)
            end
        end
        Ctx.at(r.revealAt, function()
            if shelf then
                shelfUsed[shelf] = nil
                Fx.tween(egg, 0.3, { Size = Fx.EGG_SIZE })
            end
            if r.mode == "full" then
                full(r, egg)
            else
                compact(r, egg)
            end
        end)
    end)
end

return Hatch
