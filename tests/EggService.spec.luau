-- Script-driven test for src/server/v3/EggService.luau + EggRules.luau (design-v3 VS-5).
-- Run: lune run tests/EggService.spec.luau
local Economy = require("../src/shared/Economy")
local SaveSchema = require("../src/server/v3/SaveSchema")
local EggRules = require("../src/server/v3/EggRules")
local EggService = require("../src/server/v3/EggService")

local checks = 0
local function check(ok: any, msg: string)
    assert(ok, "FAIL: " .. msg)
    checks += 1
end

-- Fake world: clock, deterministic random, station checks, captured pushes
local t = 1000
local seed = 12345
local near = { Ledge = true, Washer = true }
local sent = {}
local logs = {}
local svc = EggService.new({
    now = function()
        return t
    end,
    random = function()
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 2147483648
    end,
    isNear = function(_player, kind)
        if near[kind] == "error" then
            error("boom")
        end
        return near[kind] == true
    end,
    send = function(player, event, ...)
        table.insert(sent, { player = player, event = event, args = { ... } })
    end,
    goldenHour = function()
        return false
    end,
    log = function(msg)
        table.insert(logs, msg)
    end,
})
local R = svc.remotes

local creatureNames = {}
for _, c in Economy.Creatures do
    creatureNames[c.Name] = true
end
-- True if any key or value anywhere in v is a creature name
local function leaksSpecies(v: any): boolean
    if type(v) == "string" then
        return creatureNames[v] == true
    elseif type(v) == "table" then
        for k, x in v do
            if leaksSpecies(k) or leaksSpecies(x) then
                return true
            end
        end
    end
    return false
end
local clientBound = {} -- every reply and push the client could see
local function call(name: string, player: any, ...: any)
    local reply = R[name](player, ...)
    table.insert(clientBound, reply)
    return reply
end
local function pushes(event: string, player: any?): { any }
    local list = {}
    for _, s in sent do
        if s.event == event and (player == nil or s.player == player) then
            table.insert(list, s)
        end
    end
    return list
end

local function throwOnce(player: any, hold: number, clientElapsed: number?)
    t += 2
    local c = call("StartCharge", player)
    if not c.ok then
        return c
    end
    t += hold
    return call("ReleaseThrow", player, clientElapsed or hold)
end

-- Where chunk `id` of `egg` appears in the wash view right now (the aim point that hits it)
local function aimAt(egg: any, id: number): { number }
    local x, y = EggRules.projected(EggRules.chunkNormal(id, egg.chunks), EggRules.turntableAngle(egg, t))
    return { x, y }
end

local function washingEgg(s: any): any
    for _, e in s.data.nest do
        if e.id == s.rt.washingId then
            return e
        end
    end
    return nil
end

-- Sprays like an honest player: every 0.1 s the aim moves (at most AIM_SPEED unit-egg radii per second, a
-- quick mouse flick, plus a little hand jitter) toward the visible mud blob nearest to it.
local AIM_SPEED = 6
local jitter = 7
local function shake(): number
    jitter = (jitter * 1103515245 + 12345) % 2147483648
    return (jitter / 2147483648 - 0.5) * 0.08
end
local function washUntilDone(player: any, maxSeconds: number): number
    local s = svc:get(player)
    local start = t
    local doneCount = #pushes("WashDone", player)
    local aim = { 0, 0 }
    while t - start < maxSeconds do
        t += 0.1
        local egg = washingEgg(s)
        if egg then
            local angle = EggRules.turntableAngle(egg, t)
            local best, bestD = nil, math.huge
            for i = 1, egg.chunks do
                if egg.hp[i] > 0 and EggRules.facing(EggRules.chunkNormal(i, egg.chunks), angle) >= 0.3 then
                    local p = aimAt(egg, i)
                    local d = math.sqrt((p[1] - aim[1]) ^ 2 + (p[2] - aim[2]) ^ 2)
                    if d < bestD then
                        best, bestD = p, d
                    end
                end
            end
            if best then
                local step = math.min(1, AIM_SPEED * 0.1 / math.max(bestD, 1e-9))
                aim = { aim[1] + (best[1] - aim[1]) * step + shake(), aim[2] + (best[2] - aim[2]) * step + shake() }
            end
            svc:sprayHits(player, { eggId = egg.id, aim = aim })
        end
        svc:update()
        if #pushes("WashDone", player) > doneCount then
            return t - start
        end
    end
    return math.huge
end

-- Scrubs without aiming: a zigzag over the egg's face at about 3 radii per second
local function scrubUntilDone(player: any, maxSeconds: number): number
    local s = svc:get(player)
    local start = t
    local doneCount = #pushes("WashDone", player)
    local aim, vx, vy = { 0, 0 }, 3, 1.3
    while t - start < maxSeconds do
        t += 0.1
        aim = { aim[1] + vx * 0.1, aim[2] + vy * 0.1 }
        vx = if math.abs(aim[1]) > 0.8 then -vx else vx
        vy = if math.abs(aim[2]) > 0.8 then -vy else vy
        local egg = washingEgg(s)
        if egg then
            svc:sprayHits(player, { eggId = egg.id, aim = aim })
        end
        svc:update()
        if #pushes("WashDone", player) > doneCount then
            return t - start
        end
    end
    return math.huge
end

-- 1. VS-5 acceptance: release without StartCharge rejected; 3 throws accepted, 4th rejected "Nest full";
--    species never in a client-bound payload before hatch
local p1 = { Name = "p1" }
do
    local data = SaveSchema.new()
    data.nestSlots = 3
    svc:add(p1, data)

    local r = call("ReleaseThrow", p1, 1.0)
    check(not r.ok and r.message == "Hold to charge first!", "release without StartCharge rejected")

    for i = 1, 3 do
        local reply = throwOnce(p1, 0.5)
        check(reply.ok, "throw " .. i .. " accepted: " .. tostring(reply.message))
        check(reply.eggId and reply.arrivesAt == reply.releasedAt + Economy.FLIGHT_TIME, "throw reply has egg timing")
        check(reply.nestUsed == i, "nest counts eggs in flight")
    end
    t += 2
    local fourth = call("StartCharge", p1)
    check(not fourth.ok and fourth.message == "Nest full! Wash an egg first.", "4th throw rejected Nest full")
    -- Even with a charge already running, release re-checks the nest
    svc:get(p1).rt.chargeStart = t
    t += 0.5
    local fourthRelease = call("ReleaseThrow", p1, 0.5)
    check(not fourthRelease.ok and fourthRelease.message == "Nest full! Wash an egg first.", "4th release rejected")

    check(svc:get(p1).data.nest[1].species == Economy.FIRST_EGG, "first egg ever is Moss Turtle")
    check(svc:get(p1).data.nest[1].chunks == Economy.TUTORIAL_CHUNKS, "first egg is the small tutorial egg")

    t += 0.6
    table.insert(clientBound, call("GetState", p1))
    for _, s in sent do
        table.insert(clientBound, s.args)
    end
    check(not leaksSpecies(clientBound), "no creature name in any reply or push before hatch")
end

-- 2. Cooldowns, positions, types, busy flag, pcall
do
    local p = { Name = "p2" }
    svc:add(p, SaveSchema.new())
    check(R.GetState(p).ok, "GetState ok")
    check(R.GetState(p).message == "Slow down!", "GetState spam hits the cooldown")
    check(R.GetState({}).message == "Still loading, one moment!", "unknown player rejected")

    local first = throwOnce(p, 0.5)
    check(first.ok, "first throw ok")
    t += 0.5
    local quick = R.StartCharge(p)
    check(not quick.ok and quick.message == "Wait a moment!", "1.5 s throw cooldown")

    t += 2
    near.Ledge = false
    check(R.StartCharge(p).message == "Walk to your ledge to throw!", "StartCharge off the ledge rejected")
    near.Ledge = true

    t += 2
    check(R.StartCharge(p).ok, "charge")
    t += 0.5
    check(R.ReleaseThrow(p, "abc").message == "Bad request.", "non-number elapsed rejected")
    t += 2
    check(R.StartCharge(p).ok, "charge again")
    t += 0.5
    check(R.ReleaseThrow(p, 0 / 0).message == "Bad request.", "NaN elapsed rejected")
    t += 2
    check(R.StartCharge(p).ok, "charge for long hold")
    t += Economy.MAX_HOLD + 1
    check(R.ReleaseThrow(p, 1).message == "Held too long! Try again.", "hold over 6 s cancelled")

    svc:get(p).busy.StartWash = true
    t += 1
    check(R.StartWash(p).message == "Busy, one moment!", "busy flag blocks a double request")
    svc:get(p).busy.StartWash = false

    near.Washer = "error"
    t += 1
    local crashed = R.StartWash(p)
    check(not crashed.ok and crashed.message == "Something went wrong. Try again!", "handler error caught by pcall")
    check(#logs > 0, "handler error logged")
    near.Washer = true
    svc:remove(p)
end

-- 3. Hold time: client value accepted within 0.15 s of the server's, otherwise the server's is used
do
    local p = { Name = "p3" }
    local data = SaveSchema.new()
    data.stats.throws = 10 -- past the tutorial egg
    data.nestSlots = 8
    svc:add(p, data)
    local close = throwOnce(p, 0.5, 0.6)
    check(math.abs(close.needle - 0.6 / Economy.NEEDLE_HALF_CYCLE) < 1e-9, "client elapsed within tolerance used")
    local far = throwOnce(p, 0.5, 1.25)
    check(math.abs(far.needle - 0.5 / Economy.NEEDLE_HALF_CYCLE) < 1e-9, "client elapsed outside tolerance ignored")
    local sweet = throwOnce(p, 1.25)
    check(sweet.label == "SWEET!" and sweet.multiplier == 1.25, "1.25 s hold is SWEET")
    check(sweet.landingDistance == data.strength * 1.25, "distance = Strength x multiplier")
    local back = throwOnce(p, 1.4 + 0.3) -- needle on its way back down: p = 0.786
    check(back.needle < Economy.SWEET_MIN and back.label ~= "SWEET!", "needle ping-pongs back")
    check(EggRules.needle(1.4 * 0.97) >= Economy.SWEET_MAX and EggRules.throwLabel(0.97, 1) == "Too much!", "too much")
    svc:remove(p)
end

-- 4. Washing: flight, chunk validation, facing, dt cap, min wash time, hatch, auto-load
do
    -- p1 has 3 eggs; the oldest landed long ago
    local s = svc:get(p1)
    local nestBefore = #s.data.nest
    local wash = call("StartWash", p1)
    check(wash.ok and wash.chunks == Economy.TUTORIAL_CHUNKS and #wash.normals == wash.chunks, "wash starts")
    check(not leaksSpecies(wash), "wash info has no species")
    check(R.ReleaseThrow(p1, 0.5).ok == false, "cannot throw while washing")

    local egg = s.data.nest[1]
    local hp0 = egg.hp[1]
    t += 0.1
    svc:sprayHits(p1, { eggId = egg.id, aim = { 5, 0 } })
    check(egg.hp[1] == hp0, "aim off the egg: batch ignored")
    t += 0.1
    svc:sprayHits(p1, { eggId = egg.id, aim = { 0 / 0, 0 } })
    check(egg.hp[1] == hp0, "NaN aim: batch ignored")
    t += 0.1
    svc:sprayHits(p1, { eggId = egg.id + 99, aim = aimAt(egg, 1) })
    check(egg.hp[1] == hp0, "wrong egg id ignored")
    t += 0.1
    svc:sprayHits(p1, "junk")
    svc:sprayHits(p1, { eggId = egg.id, aim = "x" })
    check(egg.hp[1] == hp0, "junk payloads ignored")
    svc:update()
    check(#pushes("WashDone", p1) == 0, "nothing done yet")

    local took = washUntilDone(p1, 30)
    check(took >= 2.5 and took <= 8, "tutorial egg washes in 2.5-8 s with honest aim (" .. took .. " s)")
    check(#pushes("ChunkPopped", p1) == Economy.TUTORIAL_CHUNKS, "one ChunkPopped per chunk")
    local hatch = pushes("HatchResult", p1)
    check(#hatch == 1, "one HatchResult")
    local h = hatch[1].args[1]
    check(h.species == Economy.FIRST_EGG and h.rarity == "Uncommon", "first hatch: Moss Turtle, Uncommon")
    check(h.mode == "full" and h.revealSeconds == Economy.FULL_REVEAL_TIME, "first hatch uses the full reveal")
    check(h.placement.where == "pen", "pet goes to the pen")
    check(#s.data.nest == nestBefore - 1 and #s.data.pets == 1, "egg left the nest, pet granted")
    check(s.data.book[Economy.FIRST_EGG].found, "book records the species")

    -- Remaining eggs still secret
    t += 1
    local state = call("GetState", p1)
    check(not leaksSpecies(state.nest), "unhatched eggs in GetState have no species")
    check(state.pets[1].species == Economy.FIRST_EGG, "hatched pet is visible")

    -- Full reveal pauses washing: next egg loads only after the reveal
    local loaded = pushes("WashLoaded", p1)
    check(#loaded == 0, "next egg waits for the full reveal")
    t = s.rt.revealUntil + 0.01
    svc:update()
    loaded = pushes("WashLoaded", p1)
    check(#loaded == 1 and loaded[1].args[1].chunks == Economy.CHUNKS_PER_EGG, "next egg auto-loads after the reveal")
    check(not leaksSpecies(loaded), "WashLoaded has no species")
end

-- 5. Aim matters: chunks facing away take no damage. Spraying faster than 10 Hz washes no faster.
do
    local function freshWasher(name: string)
        local p = { Name = name }
        local data = SaveSchema.new()
        data.stats.throws = 10
        data.pets = { { id = 1, species = "Meadow Bunny", mutation = "Normal", pen = true } }
        data.nextId = 2
        svc:add(p, data)
        throwOnce(p, 0.5)
        t += Economy.FLIGHT_TIME
        check(R.StartWash(p).ok, name .. " wash starts")
        local s = svc:get(p)
        return p, s.data.nest[1]
    end

    -- Aiming at where a chunk on the back would project hits nothing on the back
    local pBack, eggBack = freshWasher("back")
    local back
    for i = 1, eggBack.chunks do
        if EggRules.facing(EggRules.chunkNormal(i, eggBack.chunks), 0) < -0.3 then
            back = i
        end
    end
    local hpBack = eggBack.hp[back]
    t += 0.1
    svc:sprayHits(pBack, { eggId = eggBack.id, aim = aimAt(eggBack, back) })
    check(eggBack.hp[back] == hpBack, "spraying the back of the egg does nothing")

    local p10, egg10 = freshWasher("hz10")
    svc:sprayHits(p10, { eggId = egg10.id, aim = aimAt(egg10, 1) }) -- the first batch only sets the aim point
    local start10 = t
    for _ = 1, 5 do
        t += 0.1
        svc:sprayHits(p10, { eggId = egg10.id, aim = aimAt(egg10, 1) })
    end
    local hp10 = egg10.hp[1]
    local p60, egg60 = freshWasher("hz60")
    svc:sprayHits(p60, { eggId = egg60.id, aim = aimAt(egg60, 1) })
    local start60 = t
    for _ = 1, 30 do
        t += 1 / 60
        svc:sprayHits(p60, { eggId = egg60.id, aim = aimAt(egg60, 1) })
    end
    check(math.abs(t - start60 - 0.5) < 1e-6 and start10 < start60, "both sprayed for 0.5 s")
    check(egg60.hp[1] >= hp10 - 1e-6, "60 Hz spraying washes no faster than 10 Hz")
    -- 5 moving direct batches of 0.1 s at combo 1..5
    check(math.abs(egg10.hp[1] - (10 - (1.05 + 1.1 + 1.15 + 1.2 + 1.25))) < 1e-6, "10 Hz: DPS x time x combo")

    -- Minimum wash time: a perfect instant wash still takes 1.5 s
    local s = svc:get(p10)
    for i = 1, egg10.chunks do
        egg10.hp[i] = 0
    end
    egg10.washStart = t - 0.2
    svc:update()
    check(s.rt.washingId == egg10.id, "not done before the 1.5 s minimum")
    t += 1.4
    svc:update()
    check(s.rt.washingId == nil and #s.data.pets == 2, "done after the minimum")
    for _, p in { pBack, p10, p60 } do
        svc:remove(p)
    end
end

-- 5b. Wash feel (catchiness pass, playtest Q2): a stationary aim stalls wherever it is parked; a moving aim
--     finishes. An aiming player washes a Meadow egg at Lv1 in 4-8 s, a random scrub in at most 8 s but
--     slower than aiming, a Marsh egg at Lv1 aimed in at most about 10 s.
do
    local function washer(name: string, zone: number)
        local p = { Name = name }
        local data = SaveSchema.new()
        data.stats.throws = 10
        data.pets = { { id = 1, species = "Meadow Bunny", mutation = "Normal", pen = true } }
        data.nextId = 2
        data.strength = if zone == 2 then 100 else 50
        svc:add(p, data)
        throwOnce(p, if zone == 2 then 1.25 else 0.5) -- 1.25 s lands on SWEET: 125 studs, the Marsh
        t += Economy.FLIGHT_TIME
        check(R.StartWash(p).ok, name .. " wash starts")
        local egg = data.nest[1]
        check(egg.zone == zone and egg.chunks == Economy.CHUNKS_PER_EGG, name .. ": egg in zone " .. zone)
        return p, egg
    end

    local worst = 0
    for gx = -9, 9, 3 do
        for gy = -9, 9, 3 do
            local p, egg = washer("fixed", 1)
            for _ = 1, 300 do
                t += 0.1
                svc:sprayHits(p, { eggId = egg.id, aim = { gx / 10, gy / 10 } })
                svc:update()
            end
            for i = 1, egg.chunks do
                worst = math.max(worst, Economy.Zones[1].ChunkHP - egg.hp[i])
            end
            check(#svc:get(p).data.pets == 1, "a stationary aim never finishes the egg")
            svc:remove(p)
        end
    end
    check(worst == 0, "a stationary aim does no damage anywhere on the egg")

    local function runs(label: string, zone: number, wash: (any, number) -> number, lo: number, hi: number)
        local times, sum = {}, 0
        for run = 1, 5 do
            local p = washer(label .. run, zone)
            t += run * 1.3 -- different turntable phase each run
            local took = wash(p, 40)
            sum += took
            table.insert(times, string.format("%.1f", took))
            check(took >= lo and took <= hi, string.format("%s in %g-%g s (%.1f s)", label, lo, hi, took))
            svc:remove(p)
        end
        print("  " .. label .. ": " .. table.concat(times, " / ") .. " s")
        return sum / 5
    end
    local aimed = runs("aimed Meadow egg at Lv1", 1, washUntilDone, 4, 8)
    local scrubbed = runs("scrubbed Meadow egg at Lv1", 1, scrubUntilDone, 4, 8)
    check(aimed < scrubbed, "aiming is faster than scrubbing")
    runs("aimed Marsh egg at Lv1", 2, washUntilDone, 4, 10.5)
end

-- 6. Stop washing keeps the half-washed egg in the nest with its chunk HP (session only)
do
    local p = { Name = "stop" }
    local data = SaveSchema.new()
    data.stats.throws = 10
    data.pets = { { id = 1, species = "Meadow Bunny", mutation = "Normal", pen = true } }
    data.nextId = 2
    svc:add(p, data)
    throwOnce(p, 0.5)
    t += 1
    check(R.StartWash(p).message == "Egg still flying!", "wash rejected while the egg flies")
    t += Economy.FLIGHT_TIME
    check(R.StartWash(p).ok, "wash after landing")
    local egg = data.nest[1]
    for _ = 1, 2 do -- the first batch only sets the aim point
        t += 0.1
        svc:sprayHits(p, { eggId = egg.id, aim = aimAt(egg, 1) })
    end
    local hp = egg.hp[1]
    check(hp < Economy.Zones[egg.zone].ChunkHP, "damage applied")
    t += 1
    check(R.StopWash(p).ok and egg.state == "Nest", "stop puts the egg back")
    t += 1
    check(R.StartWash(p).hp[1] == hp, "restart keeps chunk HP")
    near.Washer = false
    t += 0.1
    svc:sprayHits(p, { eggId = egg.id, aim = aimAt(egg, 1) })
    check(egg.hp[1] == hp, "spraying from outside the washer ignored")
    near.Washer = true
    svc:remove(p)
end

-- 7. Pen placement and swap
do
    local data = SaveSchema.new()
    for i = 1, 6 do
        table.insert(data.pets, { id = i, species = "Moss Turtle", mutation = "Normal", pen = true })
    end
    data.pets[3].species = "Meadow Bunny"
    local worse = EggRules.placePet(data, { id = 7, species = "Meadow Bunny", mutation = "Normal", pen = false })
    check(worse.where == "storage", "worse pet goes to storage when the pen is full")
    local better = EggRules.placePet(data, { id = 8, species = "Bog Frog", mutation = "Normal", pen = false })
    check(better.where == "pen" and better.swappedOutId == 3, "better pet swaps out the worst pen pet")
    check(data.pets[3].pen == false and data.pets[8].pen == true, "swap applied")
    local penCount = 0
    for _, p in data.pets do
        penCount += if p.pen then 1 else 0
    end
    check(penCount == 6, "pen never exceeds its slots")
end

-- 8. Income tick: pen pets only, once per second, on the server
do
    local p = { Name = "income" }
    local data = SaveSchema.new()
    data.pets = {
        { id = 1, species = "Bog Frog", mutation = "Golden", pen = true }, -- 25 x 5
        { id = 2, species = "Moss Turtle", mutation = "Normal", pen = true }, -- 3
        { id = 3, species = "Galaxy Titan", mutation = "Normal", pen = false }, -- storage: earns nothing
    }
    svc:add(p, data)
    t += 0.5
    svc:update()
    check(data.coins == 0, "no pay before a full second")
    t += 0.5
    svc:update()
    check(data.coins == 128, "pays 128 after 1 s")
    t += 3
    svc:update()
    check(data.coins == 128 * 4, "pays for the elapsed seconds")
    svc:remove(p)
end

-- 9. Leave with 2 eggs in the nest (one still flying), rejoin: eggs still there
do
    local p = { Name = "rejoin" }
    local data = SaveSchema.new()
    data.stats.throws = 10
    data.pets = { { id = 1, species = "Meadow Bunny", mutation = "Normal", pen = true } }
    data.nextId = 2
    svc:add(p, data)
    throwOnce(p, 0.5)
    t += Economy.FLIGHT_TIME
    throwOnce(p, 0.5) -- still in flight when the player leaves
    local saved = SaveSchema.serialize(svc:remove(p))
    local back = assert(SaveSchema.load(saved))
    svc:add(p, back)
    t += 1
    local state = R.GetState(p)
    check(#state.nest == 2 and state.nest[1].state == "Nest" and state.nest[2].state == "Nest", "both eggs back")
    check(back.nest[1].species == data.nest[1].species, "egg contents survive the rejoin")
    svc:remove(p)
end

-- 10. The old exploits are gone: no client-reported wash progress, no sell remote
do
    local names = {}
    for name in R do
        table.insert(names, name)
    end
    table.sort(names)
    check(
        table.concat(names, ",")
            == "Buy,ClaimBook,GetState,Lift,ReleaseThrow,StartCharge,StartLift,StartWash,StopLift,StopWash",
        "remote whitelist"
    )
end

print(string.format("PASS EggService (%d checks)", checks))
return true
