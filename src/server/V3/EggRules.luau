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

-- Species the player has found, counting eggs already thrown (their species is decided at release)
function EggRules.foundOrPending(data: any): { [string]: boolean }
    local found = {}
    for species, entry in data.book do
        found[species] = entry.found
    end
    for _, egg in data.nest do
        found[egg.species] = true
    end
    return found
end

-- Discovery meter as sent to the client: string keys, since a sparse number-keyed table does not cross a remote
function EggRules.pityView(data: any): { [string]: number }
    local view = {}
    for zone, n in data.pity do
        view[tostring(zone)] = n
    end
    return view
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
        return false, "Inventory full! Wash an egg first."
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
    local gift = false
    local found = EggRules.foundOrPending(data)
    local missing = Economy.missingCreature(zone.Id, found)
    if firstEver then
        creature = Economy.CreatureByName[Economy.FIRST_EGG]
        zone = Economy.Zones[creature.Zone]
    elseif not data.gifts.rareEgg and data.stats.throws + 1 >= Economy.GIFT_THROW and zone.Id == 1 then
        data.gifts.rareEgg = true -- saved: the gift happens once per save
        if not found[Economy.GIFT_SPECIES] then
            creature, gift = Economy.CreatureByName[Economy.GIFT_SPECIES], true
        end
    end
    if not creature and missing and (data.pity[zone.Id] or 0) >= Economy.DISCOVERY_PITY[missing.Rarity] then
        creature = missing
    end
    if not creature then
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
        gift = if gift then true else nil,
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
        gift = gift,
        throwNumber = data.stats.throws,
        releasedAt = now,
        foodLandsAt = now + Economy.FOOD_FLIGHT,
        eggLaunchAt = now + Economy.EGG_LAUNCH_AT,
        arrivesAt = egg.arrivesAt,
        nestUsed = #data.nest,
        nestSlots = data.nestSlots,
    }
end

-- Unit normal of mud blob i (1..n) in the egg's local space: blobs spread evenly around the egg, heights
-- staggered so each side shows two or three. The wash camera looks along -Z: a blob faces it when its rotated
-- normal has a large +Z part.
function EggRules.chunkNormal(i: number, n: number): { number }
    local y = 0.45 * math.sin(i * 2.4)
    local az = 2 * math.pi * (i - 1) / n
    local r = math.sqrt(1 - y * y)
    return { r * math.sin(az), y, r * math.cos(az) }
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

function EggRules.startWash(data: any, rt: Runtime, now: number, wantId: any): { [string]: any }
    EggRules.advance(data, now)
    local egg = findEgg(data, rt.washingId)
    if not egg then
        -- The bag can name the egg it wants; anything unknown falls back to the oldest.
        local want = if wantId ~= nil then findEgg(data, wantId) else nil
        if want and want.state == "Flight" then
            return { ok = false, message = "Egg still flying!" }
        end
        if want and want.state == "Nest" then
            egg = want
        else
            egg = oldestInNest(data)
        end
        if not egg then
            for _, e in data.nest do
                if e.state == "Flight" then
                    return { ok = false, message = "Egg still flying!" }
                end
            end
            return { ok = false, message = "No eggs in your bag!" }
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
-- camera (egg-local hit point divided by the egg's radii). See Economy's wash block for the rule: a moving aim
-- on the egg scrubs every facing blob, blobs near the aim take full damage with a combo, a parked aim does
-- nothing. Returns the blob ids popped, nil (or nil and a reason when rejected), and the visible knocks
-- { { id, hpFraction } } plus the combo count after this batch.
function EggRules.spray(
    data: any,
    rt: Runtime,
    now: number,
    eggId: any,
    aim: any
): ({ number }?, string?, { { number } }?, number?)
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
    local last = egg.lastAim
    egg.lastAim = { ax, ay }
    local popped, knocks = {}, {}
    -- movement and combo are per second of spraying, so sending faster gives nothing
    local moved = last ~= nil and math.sqrt((ax - last[1]) ^ 2 + (ay - last[2]) ^ 2) >= Economy.AIM_MOVE_MIN * dt / 0.1
    if dt <= 0 or not moved or ax * ax + ay * ay > 1.1 then
        egg.comboTime = 0 -- parked or off the egg
        return popped, nil, knocks, 0
    end
    local angle = EggRules.turntableAngle(egg, now)
    local hits = {}
    for id = 1, egg.chunks do
        local normal = EggRules.chunkNormal(id, egg.chunks)
        if egg.hp[id] > 0 and EggRules.facing(normal, angle) >= Economy.FACING_MIN_DOT then
            local x, y = EggRules.projected(normal, angle)
            table.insert(hits, { id = id, d = math.sqrt((x - ax) ^ 2 + (y - ay) ^ 2) })
        end
    end
    table.sort(hits, function(p, q)
        return p.d < q.d
    end)
    local nozzle = Economy.Nozzles[data.nozzleLevel]
    local direct = #hits > 0 and hits[1].d <= Economy.AIM_RADIUS
    egg.comboTime = if direct then (egg.comboTime or 0) + dt else 0
    local combo = math.min(math.floor(egg.comboTime * 10 + 1e-6), Economy.COMBO_MAX)
    local damage = nozzle.DPS * dt * (1 + Economy.COMBO_STEP * combo)
    local maxHP = Economy.Zones[egg.zone].ChunkHP
    for k, h in hits do
        local share = if k <= nozzle.MaxChunksPerHit and h.d <= Economy.AIM_RADIUS then 1 else Economy.SCRUB_SHARE
        local before = egg.hp[h.id]
        egg.hp[h.id] = math.max(0, before - damage * share)
        local stages = Economy.BLOB_STAGES
        if egg.hp[h.id] == 0 then
            table.insert(popped, h.id)
        elseif math.ceil(egg.hp[h.id] / maxHP * stages) < math.ceil(before / maxHP * stages) then
            table.insert(knocks, { h.id, egg.hp[h.id] / maxHP })
        end
    end
    return popped, nil, knocks, combo
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
    -- Resolve every lookup that can fail before removing the egg from the bag.
    local creature = Economy.CreatureByName[egg.species]
    assert(creature, "unknown washing species")
    local rarity = creature.Rarity
    local rare = (table.find(Economy.RarityOrder, rarity) :: number) >= 3
    local income = petIncome(egg.species, egg.mutation)
    local entry = data.book[egg.species]
    local firstOfSpecies = not (entry and entry.found)
    local missingForPity = not firstOfSpecies and Economy.missingCreature(egg.zone, EggRules.foundOrPending(data))
    if not entry then
        entry = { found = true, claimed = false, mutations = {} }
        data.book[egg.species] = entry
    end
    entry.found = true
    entry.mutations[egg.mutation] = true
    data.stats.hatches += 1
    -- discovery meter: empties on a new find, fills while the zone still misses a creature
    if firstOfSpecies then
        data.pity[egg.zone] = 0
    elseif missingForPity then
        data.pity[egg.zone] = (data.pity[egg.zone] or 0) + 1
    end

    local pet = { id = egg.id, species = egg.species, mutation = egg.mutation, pen = false }
    local placement = EggRules.placePet(data, pet)

    local full = data.stats.hatches <= Economy.FULL_REVEAL_HATCHES
        or rare
        or egg.mutation ~= "Normal"
        or firstOfSpecies
        or egg.gift == true
    local duration = if full then Economy.FULL_REVEAL_TIME else Economy.COMPACT_REVEAL_TIME
    local revealAt = math.max(now, rt.revealUntil) -- reveals queue on the Hatch Pad
    rt.revealUntil = revealAt + duration

    if rt.inWasher and oldestInNest(data) then
        local nextLoad = now + Economy.WASH_LOAD_DELAY
        rt.loadAt = if full then math.max(nextLoad, rt.revealUntil) else nextLoad -- full reveal pauses washing
    else
        rt.inWasher, rt.loadAt = false, nil
    end

    table.remove(data.nest, index)
    rt.washingId = nil

    return {
        eggId = egg.id,
        species = egg.species,
        rarity = rarity,
        mutation = egg.mutation,
        income = income,
        zone = egg.zone,
        mode = if full then "full" else "compact",
        revealAt = revealAt,
        revealSeconds = duration,
        firstOfSpecies = firstOfSpecies,
        gift = egg.gift == true,
        pity = EggRules.pityView(data),
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
