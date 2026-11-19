--!strict
-- Egg pipeline rules (design-v3 VS-5, sections 3.2-3.7). Pure: no Roblox services; the caller passes the
-- clock (`now`, server time in seconds) and random numbers. Tested by tests/EggService.spec.luau.
--
-- Egg states: Flight -> Nest -> Washing -> (hatched: becomes a pet). The egg leaves the nest and the pet is
-- granted the moment washing finishes, so leaving during the reveal cannot lose it; the reveal itself is the
-- "Hatching" window (rt.revealUntil) during which the next egg is not loaded after a full reveal.

local Economy = if game
    then require(game:GetService("ReplicatedStorage").Modules.Economy)
    else require("../../shared/Economy")

local EggRules = {}

export type Runtime = {
    chargeStart: number?,
    lastThrowAt: number,
    inWasher: boolean,
    washingId: number?,
    loadAt: number?,
    revealUntil: number,
    lastIncomeAt: number,
}

function EggRules.newRuntime(now: number): Runtime
    return {
        chargeStart = nil,
        lastThrowAt = -math.huge,
        inWasher = false,
        washingId = nil,
        loadAt = nil,
        revealUntil = 0,
        lastIncomeAt = now,
    }
end

-- Loaded eggs have no runtime state yet: they all sit in the nest
function EggRules.prepare(data: any)
    for _, egg in data.nest do
        egg.state = "Nest"
    end
end

-- Needle position 0..1 after holding `elapsed` seconds: ping-pong with a 1.4 s half-cycle (3.2)
function EggRules.needle(elapsed: number): number
    local x = (elapsed / Economy.NEEDLE_HALF_CYCLE) % 2
    return if x <= 1 then x else 2 - x
end

function EggRules.throwLabel(p: number, multiplier: number): string
    if p >= Economy.SWEET_MAX then
        return "Too much!"
    elseif p >= Economy.SWEET_MIN then
        return "SWEET!"
    end
    return string.format("x%.2f", multiplier)
end

local function petIncome(species: string, mutation: string): number
    return Economy.petIncome({ Species = species, Mutation = mutation })
end

function EggRules.penPets(data: any): { Economy.Pet }
    local list = {}
    for _, p in data.pets do
        if p.pen then
            table.insert(list, { Species = p.species, Mutation = p.mutation })
        end
    end
    return list
end

function EggRules.income(data: any): number
    return Economy.incomePerSecond(EggRules.penPets(data), data.rebirths)
end

local function findEgg(data: any, id: number?): (any, number?)
    for i, egg in data.nest do
        if egg.id == id then
            return egg, i
        end
    end
    return nil, nil
end

function EggRules.advance(data: any, now: number)
    for _, egg in data.nest do
        if egg.state == "Flight" and now >= egg.arrivesAt then
            egg.state = "Nest"
        end
    end
end

function EggRules.canThrow(data: any, rt: Runtime, now: number): (boolean, string)
    if rt.inWasher then
        return false, "Leave the washer to throw!"
    elseif now - rt.lastThrowAt < Economy.THROW_COOLDOWN then
        return false, "Wait a moment!"
    elseif #data.nest >= data.nestSlots then
        return false, "Nest full! Wash an egg first."
    elseif #data.pets + #data.nest >= data.penSlots + Economy.STORAGE then
        -- shortcut: blocks throws when pets would overflow storage; Release (P-4) is the way out
        return false, "Storage full! Release a pet first."
    end
    return true, ""
end

function EggRules.startCharge(data: any, rt: Runtime, now: number): (boolean, string)
    local ok, msg = EggRules.canThrow(data, rt, now)
    rt.chargeStart = if ok then now else nil
    return ok, msg
end

-- rMutation, rSpecies: uniform [0, 1). Returns the client reply; species and mutation are never in it.
function EggRules.release(
    data: any,
    rt: Runtime,
    now: number,
    clientElapsed: number?,
    rSpecies: number,
    rMutation: number,
    goldenHour: boolean
): { [string]: any }
    local start = rt.chargeStart
    rt.chargeStart = nil
    if not start then
        return { ok = false, message = "Hold to charge first!" }
    end
    local serverElapsed = now - start
    if serverElapsed > Economy.MAX_HOLD + Economy.ELAPSED_TOLERANCE then
        return { ok = false, message = "Held too long! Try again." }
    end
    local ok, msg = EggRules.canThrow(data, rt, now)
    if not ok then
        return { ok = false, message = msg }
    end

    local elapsed = serverElapsed
    if clientElapsed and math.abs(clientElapsed - serverElapsed) <= Economy.ELAPSED_TOLERANCE then
        elapsed = math.clamp(clientElapsed, 0, Economy.MAX_HOLD)
    end
    local p = EggRules.needle(elapsed)
    local multiplier = Economy.throwMultiplier(p)
    local distance = data.strength * multiplier
    local zone = Economy.zoneForDistance(distance)

    local firstEver = data.stats.throws == 0 and #data.pets == 0
    local creature
    if firstEver then
        creature = Economy.CreatureByName[Economy.FIRST_EGG]
        zone = Economy.Zones[creature.Zone]
    else
        local luck = Economy.Foods[data.foodTier].Luck
        creature = Economy.rollEgg(zone.Id, luck, goldenHour, rSpecies)
    end
    local mutation = Economy.rollMutation(goldenHour, rMutation) or "Normal"

    local egg = {
        id = data.nextId,
        zone = zone.Id,
        species = creature.Name,
        mutation = mutation,
        sparkle = creature.Slot == "C",
        chunks = if firstEver then Economy.TUTORIAL_CHUNKS else Economy.CHUNKS_PER_EGG,
        state = "Flight",
        arrivesAt = now + Economy.FLIGHT_TIME,
    }
    data.nextId += 1
    table.insert(data.nest, egg)
    data.stats.throws += 1
    rt.lastThrowAt = now

    return {
        ok = true,
        message = "",
        eggId = egg.id,
        zone = zone.Id,
        zoneName = zone.Name,
        landingDistance = distance,
        needle = p,
        multiplier = multiplier,
        label = EggRules.throwLabel(p, multiplier),
        sparkle = egg.sparkle,
        throwNumber = data.stats.throws,
        releasedAt = now,
        foodLandsAt = now + Economy.FOOD_FLIGHT,
        eggLaunchAt = now + Economy.EGG_LAUNCH_AT,
        arrivesAt = egg.arrivesAt,
        nestUsed = #data.nest,
        nestSlots = data.nestSlots,
    }
end

-- Unit normal of chunk i (1..n) in the egg's local space. Chunks come in pairs; each pair sits on its own
-- height band (projected y from -BAND_SPAN to +BAND_SPAN), so a fixed aim point can only ever reach one
-- pair while the turntable spins. The wash camera looks along -Z: a chunk faces it when its rotated normal
-- has a large +Z part.
function EggRules.chunkNormal(i: number, n: number): { number }
    local npairs = n // 2
    local c = (i - 1) // 2 -- pair index 0..pairs-1
    local y = if npairs > 1 then -Economy.BAND_SPAN + 2 * Economy.BAND_SPAN * c / (npairs - 1) else 0
    local el = math.asin(y)
    -- shortcut: pair azimuths step by 2/pairs of a turn so neighbouring bands are not side by side;
    -- needs an odd pair count (3 and 5 today)
    local az = 2 * math.pi * ((2 * c) % npairs) / npairs
    local half = math.asin(math.min(Economy.PAIR_HALF_GAP / math.cos(el), 1))
    az += if i % 2 == 1 then -half else half
    return { math.cos(el) * math.sin(az), y, math.cos(el) * math.cos(az) }
end

-- Where a chunk appears in the wash view at a turntable angle: x, y on the unit egg as seen from +Z
function EggRules.projected(normal: { number }, angleDeg: number): (number, number)
    local a = math.rad(angleDeg)
    return normal[1] * math.cos(a) + normal[3] * math.sin(a), normal[2]
end

-- Turntable angle in degrees at `now` (clients render the same formula with GetServerTimeNow)
function EggRules.turntableAngle(egg: any, now: number): number
    return (now - egg.washStart) * Economy.TURNTABLE_DEG_PER_SEC
end

-- +Z part of the normal after rotating about Y by the turntable angle (CFrame.Angles(0, angle, 0))
function EggRules.facing(normal: { number }, angleDeg: number): number
    local a = math.rad(angleDeg)
    return -normal[1] * math.sin(a) + normal[3] * math.cos(a)
end

function EggRules.washInfo(egg: any, nozzleLevel: number): { [string]: any }
    local normals = {}
    for i = 1, egg.chunks do
        normals[i] = EggRules.chunkNormal(i, egg.chunks)
    end
    local zone = Economy.Zones[egg.zone]
    return {
        eggId = egg.id,
        zone = egg.zone,
        zoneName = zone.Name,
        sparkle = egg.sparkle,
        chunks = egg.chunks,
        chunkHP = zone.ChunkHP,
        hp = table.clone(egg.hp),
        normals = normals,
        washStart = egg.washStart,
        degPerSec = Economy.TURNTABLE_DEG_PER_SEC,
        facingMin = Economy.FACING_MIN_DOT,
        nozzleLevel = nozzleLevel,
        maxChunksPerHit = Economy.Nozzles[nozzleLevel].MaxChunksPerHit,
    }
end

local function loadEgg(egg: any, rt: Runtime, now: number)
    egg.state = "Washing"
    egg.washStart = now
    egg.lastHit = now
    if not egg.hp then -- a half-washed egg keeps its chunk HP for the session
        egg.hp = table.create(egg.chunks, Economy.Zones[egg.zone].ChunkHP)
    end
    rt.washingId = egg.id
    rt.loadAt = nil
end

local function oldestInNest(data: any): any
    for _, egg in data.nest do -- nest is in throw order
        if egg.state == "Nest" then
            return egg
        end
    end
    return nil
end

function EggRules.startWash(data: any, rt: Runtime, now: number): { [string]: any }
    EggRules.advance(data, now)
    local egg = findEgg(data, rt.washingId)
    if not egg then
        egg = oldestInNest(data)
        if not egg then
            for _, e in data.nest do
                if e.state == "Flight" then
                    return { ok = false, message = "Egg still flying!" }
                end
            end
            return { ok = false, message = "No eggs in your nest!" }
        end
        loadEgg(egg, rt, now)
    end
    rt.inWasher = true
    local reply = EggRules.washInfo(egg, data.nozzleLevel)
    reply.ok, reply.message = true, ""
    return reply
end

function EggRules.stopWash(data: any, rt: Runtime)
    local egg = findEgg(data, rt.washingId)
    if egg then
        egg.state = "Nest"
    end
    rt.washingId, rt.inWasher, rt.loadAt = nil, false, nil
end

-- Applies one spray batch aimed at `aim` = { x, y }: the spray point on the unit egg as seen by the wash
-- camera (egg-local hit point divided by the egg's radii). Only facing chunks within AIM_RADIUS of the aim
-- take damage, nearest first, up to the nozzle's chunk cap. Returns the chunk ids popped by it, or nil and a
-- reason when the batch is rejected.
function EggRules.spray(data: any, rt: Runtime, now: number, eggId: any, aim: any): ({ number }?, string?)
    local egg = findEgg(data, rt.washingId)
    if not egg or egg.id ~= eggId then
        return nil, "not washing that egg"
    end
    if type(aim) ~= "table" then
        return nil, "bad aim"
    end
    local ax, ay = aim[1], aim[2]
    if type(ax) ~= "number" or type(ay) ~= "number" or not (math.abs(ax) <= 1.5 and math.abs(ay) <= 1.5) then
        return nil, "bad aim" -- written as "not <=" so NaN is rejected too
    end

    local dt = math.min(now - egg.lastHit, Economy.SPRAY_DT_CAP)
    egg.lastHit = now
    local popped = {}
    if dt <= 0 then
        return popped, nil
    end
    local angle = EggRules.turntableAngle(egg, now)
    local hits = {}
    for id = 1, egg.chunks do
        local normal = EggRules.chunkNormal(id, egg.chunks)
        if egg.hp[id] > 0 and EggRules.facing(normal, angle) >= Economy.FACING_MIN_DOT then
            local x, y = EggRules.projected(normal, angle)
            local d = math.sqrt((x - ax) ^ 2 + (y - ay) ^ 2)
            if d <= Economy.AIM_RADIUS then
                table.insert(hits, { id = id, d = d })
            end
        end
    end
    table.sort(hits, function(p, q)
        return p.d < q.d
    end)
    local damage = Economy.Nozzles[data.nozzleLevel].DPS * dt
    for k = 1, math.min(#hits, Economy.Nozzles[data.nozzleLevel].MaxChunksPerHit) do
        local id = hits[k].id
        egg.hp[id] = math.max(0, egg.hp[id] - damage)
        if egg.hp[id] == 0 then
            table.insert(popped, id)
        end
    end
    return popped, nil
end

-- Where a new pet goes (3.6): free pen spot, else swap with the worst pen pet if better, else storage
function EggRules.placePet(data: any, pet: any): { [string]: any }
    local inPen, worst = 0, nil
    for _, p in data.pets do
        if p.pen then
            inPen += 1
            if not worst or petIncome(p.species, p.mutation) < petIncome(worst.species, worst.mutation) then
                worst = p
            end
        end
    end
    local placement: { [string]: any } = { where = "storage" }
    if inPen < data.penSlots then
        pet.pen = true
        placement.where = "pen"
    elseif worst and petIncome(pet.species, pet.mutation) > petIncome(worst.species, worst.mutation) then
        worst.pen = false
        pet.pen = true
        placement = { where = "pen", swappedOutId = worst.id, swappedOutSpecies = worst.species }
    else
        pet.pen = false
    end
    table.insert(data.pets, pet)
    return placement
end

-- Washing is done once every chunk is popped and the minimum wash time has passed
function EggRules.washDoneAt(egg: any): number?
    for _, hp in egg.hp do
        if hp > 0 then
            return nil
        end
    end
    return egg.washStart + Economy.MIN_WASH_TIME
end

-- Turns the washed egg into a pet. Returns the HatchResult payload pushed to the client.
function EggRules.hatch(data: any, rt: Runtime, now: number): { [string]: any }
    local egg, index = findEgg(data, rt.washingId)
    assert(egg and index, "no egg washing")
    table.remove(data.nest, index)
    rt.washingId = nil

    local creature = Economy.CreatureByName[egg.species]
    local entry = data.book[egg.species]
    local firstOfSpecies = not (entry and entry.found)
    if not entry then
        entry = { found = true, claimed = false, mutations = {} }
        data.book[egg.species] = entry
    end
    entry.found = true
    entry.mutations[egg.mutation] = true
    data.stats.hatches += 1

    local pet = { id = egg.id, species = egg.species, mutation = egg.mutation, pen = false }
    local placement = EggRules.placePet(data, pet)

    local rare = table.find(Economy.RarityOrder, creature.Rarity) :: number >= 3
    local full = data.stats.hatches <= Economy.FULL_REVEAL_HATCHES or rare or egg.mutation ~= "Normal" or firstOfSpecies
    local duration = if full then Economy.FULL_REVEAL_TIME else Economy.COMPACT_REVEAL_TIME
    local revealAt = math.max(now, rt.revealUntil) -- reveals queue on the Hatch Pad
    rt.revealUntil = revealAt + duration

    if rt.inWasher and oldestInNest(data) then
        local nextLoad = now + Economy.WASH_LOAD_DELAY
        rt.loadAt = if full then math.max(nextLoad, rt.revealUntil) else nextLoad -- full reveal pauses washing
    else
        rt.inWasher, rt.loadAt = false, nil
    end

    return {
        eggId = egg.id,
        species = egg.species,
        rarity = creature.Rarity,
        mutation = egg.mutation,
        income = petIncome(egg.species, egg.mutation),
        zone = egg.zone,
        mode = if full then "full" else "compact",
        revealAt = revealAt,
        revealSeconds = duration,
        firstOfSpecies = firstOfSpecies,
        placement = placement,
    }
end

-- Advances timers. Returns a list of { eventName, payload } to push to the player, and the coins paid.
function EggRules.update(data: any, rt: Runtime, now: number): ({ { any } }, number)
    local events = {}
    EggRules.advance(data, now)

    local egg = findEgg(data, rt.washingId)
    local doneAt = egg and EggRules.washDoneAt(egg)
    if egg and doneAt and now >= doneAt then
        table.insert(events, { "WashDone", egg.id })
        table.insert(events, { "HatchResult", EggRules.hatch(data, rt, now) })
    end

    if rt.inWasher and not rt.washingId and rt.loadAt and now >= rt.loadAt then
        local nextEgg = oldestInNest(data)
        if nextEgg then
            loadEgg(nextEgg, rt, now)
            table.insert(events, { "WashLoaded", EggRules.washInfo(nextEgg, data.nozzleLevel) })
        else
            rt.inWasher, rt.loadAt = false, nil
        end
    end

    local paid = 0
    local elapsed = now - rt.lastIncomeAt
    if elapsed >= 1 then
        paid = EggRules.income(data) * elapsed
        data.coins += paid
        rt.lastIncomeAt = now
    end
    return events, paid
end

return EggRules
