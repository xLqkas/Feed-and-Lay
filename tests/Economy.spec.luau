-- Assert test for src/shared/Economy.luau (design-v3 VS-1).
-- Run: `lune run tests/Economy.spec.luau` from the repo root, or in Studio with the module in ReplicatedStorage.Modules.
local Economy = if game
    then require(game:GetService("ReplicatedStorage").Modules.Economy)
    else require("../src/shared/Economy")

local checks = 0
local function check(ok: boolean, msg: string)
    assert(ok, "FAIL: " .. msg)
    checks += 1
end

local function near(a: number, b: number, tol: number): boolean
    return math.abs(a - b) <= tol
end

-- 1. Design acceptance: throwMultiplier and the meter bands (3.2)
check(Economy.throwMultiplier(0.9) == 1.25, "throwMultiplier(0.9) == 1.25")
check(near(Economy.throwMultiplier(0.5), 0.55, 1e-9), "throwMultiplier(0.5) == 0.55")
check(Economy.throwMultiplier(0.97) == 1, "throwMultiplier(0.97) == 1")

-- 2. Zones and Strength gates (4.1)
check(Economy.zoneForDistance(99.9).Id == 1 and Economy.zoneForDistance(100).Id == 2, "Meadow/Marsh boundary")
check(Economy.zoneForDistance(1e6).Id == 5, "Starfield is open-ended")
check(Economy.zoneForStrength(Economy.START_STRENGTH).Id == 1, "start Strength reaches Meadow only")
for i, zone in Economy.Zones do
    if i > 1 then
        check(Economy.zoneForStrength(zone.StrengthGate).Id == i, zone.Name .. " unlocks at its Strength gate")
        check(Economy.zoneForStrength(zone.StrengthGate - 1).Id == i - 1, zone.Name .. " locked below its gate")
    end
end

-- 3. Odds match table 4.5 to 0.1% (percentage points), and every table sums to 1
local zones1to4 = {
    { { 80.0, 18.0, 2.0 }, { 78.4, 17.6, 3.9 } },
    { { 73.1, 23.3, 3.7 }, { 70.5, 22.4, 7.1 } },
    { { 64.5, 29.0, 6.5 }, { 60.6, 27.3, 12.1 } },
    { { 54.5, 34.7, 10.9 }, { 49.1, 31.3, 19.6 } },
    { { 43.5, 39.1, 17.4 }, { 37.0, 33.3, 29.6 } },
    { { 32.5, 41.4, 26.0 }, { 25.8, 32.9, 41.3 } },
}
local starfield = {
    { { 81.5, 18.3, 0.2 }, { 81.3, 18.3, 0.4 } },
    { { 75.6, 24.0, 0.4 }, { 75.3, 24.0, 0.8 } },
    { { 68.5, 30.8, 0.7 }, { 68.0, 30.6, 1.4 } },
    { { 60.4, 38.4, 1.2 }, { 59.7, 38.0, 2.4 } },
    { { 51.5, 46.4, 2.1 }, { 50.5, 45.5, 4.0 } },
    { { 42.5, 54.1, 3.4 }, { 41.1, 52.3, 6.6 } },
}
for zoneId = 1, 5 do
    local expected = if zoneId == 5 then starfield else zones1to4
    for tier, food in Economy.Foods do
        for g = 1, 2 do
            local odds = Economy.eggOdds(zoneId, food.Luck, g == 2)
            check(near(odds[1] + odds[2] + odds[3], 1, 1e-9), "odds sum to 1")
            for slot = 1, 3 do
                check(
                    near(odds[slot] * 100, expected[tier][g][slot], 0.1),
                    string.format("odds zone %d %s gh=%s slot %d", zoneId, food.Name, tostring(g == 2), slot)
                )
            end
        end
    end
end
local mutationSum = 0
for _, m in Economy.Mutations do
    mutationSum += m.Chance * Economy.GOLDEN_HOUR_MUTATION
end
check(mutationSum < 1, "mutation chances (Golden Hour) leave room for Normal")

-- 4. Every creature is reachable through rollEgg, in its own zone, with the starting food
local seen = {}
for zoneId = 1, 5 do
    for i = 0, 99999 do
        local c = Economy.rollEgg(zoneId, 1, false, i / 100000)
        check(c.Zone == zoneId, "rolled creature belongs to its zone")
        seen[c.Name] = true
    end
end
check(#Economy.Creatures == 15, "15 creatures")
for _, c in Economy.Creatures do
    check(seen[c.Name] == true, c.Name .. " reachable")
    check(c.BookClaim == math.max(100, 30 * c.Income), c.Name .. " book claim")
end
check(Economy.rollMutation(false, 0.0005) == "Rainbow", "rollMutation Rainbow")
check(Economy.rollMutation(false, 0.5) == nil, "rollMutation Normal")

-- 5. Costs strictly increase on every track
local function strictlyIncreasing(track: string, from: number, to: number)
    local last = -1
    for level = from, to do
        local cost = Economy.upgradeCost(track, level)
        check(cost ~= nil and cost > last, string.format("%s cost increases at %d", track, level))
        last = cost :: number
    end
    check(Economy.upgradeCost(track, to + 1) == nil, track .. " maxes out")
end
strictlyIncreasing("Food", 1, 5)
strictlyIncreasing("Dumbbell", 1, 3)
strictlyIncreasing("Nozzle", 1, 4)
strictlyIncreasing("Nest", Economy.START_NEST, Economy.MAX_NEST - 1)
strictlyIncreasing("Pen", Economy.START_PEN, Economy.MAX_PEN - 1)
strictlyIncreasing("Rebirth", 0, Economy.MAX_REBIRTHS - 1)
check(Economy.upgradeCost("Rebirth", 2) == 640e9, "rebirth 3 costs 640B")

-- 6. Wash times (catchiness pass, playtest Q2): Meadow at Lv1 4-8 s, Marsh at Lv1 at most about 10 s, the
-- matching nozzle of every later zone at the sweep floor; and the income formula (3.7)
check(near(Economy.washTimeEstimate(1, 1), 4.76, 0.05), "Meadow egg at Lv1 about 4.8 s")
check(near(Economy.washTimeEstimate(2, 1), 9.52, 0.05), "Marsh egg at Lv1 about 9.5 s")
for i = 2, 5 do
    check(Economy.washTimeEstimate(i, i) == Economy.WASH_SWEEP_FLOOR, "matching nozzle washes zone " .. i .. " fast")
    check(Economy.washTimeEstimate(i, i - 1) > 6, "one nozzle level short is slow in zone " .. i)
end
check(
    Economy.incomePerSecond({ { Species = "Moss Turtle" }, { Species = "Bog Frog", Mutation = "Shiny" } }, 0) == 53,
    "income sums species x mutation"
)
check(
    near(
        Economy.incomePerSecond({ { Species = "Bog Frog" } }, 1, { x2Coins = true, friends = 5 }),
        25 * 1.5 * 2 * 1.3,
        1e-9
    ),
    "income bonuses, friends capped at 3"
)

-- 7. Pacing simulation: an active new player follows the 4.9 path.
-- Timing model from sections 2.2, 3.2-3.6: throw cooldown 1.5 s, flight 4.0 s, wash per egg plus 0.6 s load,
-- full reveal pauses washing 6.5 s (hatches 1-5, Rare+, mutations, new species), Book claim 5 s,
-- purchase 2 s, lifting at 1.2 reps/s, Golden Hour the last 2 of every 10 minutes.
local TOLERANCE = 0.25 -- fixed before running: each target must be met within +-25% (min +-15 s)

local RARE_RANK = table.find(Economy.RarityOrder, "Rare") :: number

local function lcg(seed: number): () -> number
    local s = seed
    return function()
        s = (s * 1103515245 + 12345) % 2147483648
        return s / 2147483648
    end
end

local PATH = {
    { "Batch" }, -- tutorial step 8-9: throw and wash 2 more eggs
    { "Nest", 3 },
    { "Batch" }, -- 2.2: one loop before the Lift banner
    { "Lift", 2 },
    { "Food", 2 },
    { "Nozzle", 2 },
    { "Pen", 7 },
    { "Pen", 8 },
    { "Nest", 4 },
    { "Food", 3 },
    { "Dumbbell", 2 },
    { "Lift", 3 },
    { "Nozzle", 3 },
    { "Pen", 9 },
    { "Nest", 5 },
    { "Pen", 10 },
    { "Food", 4 },
    { "Dumbbell", 3 },
    { "Lift", 4 },
    { "Nozzle", 4 },
    { "Pen", 11 },
    { "Nest", 6 },
    { "Pen", 12 },
    { "Food", 5 },
    { "Dumbbell", 4 },
    { "Lift", 5 },
    { "Nozzle", 5 },
    { "Pen", 13 },
    { "Pen", 14 },
    { "Nest", 7 },
    { "Food", 6 },
    { "Rebirth", 0 },
}

local function simulate(seed: number): { [string]: number }
    local rand = lcg(seed)
    local s = {
        t = 0,
        coins = 0,
        strength = Economy.START_STRENGTH,
        Food = 1,
        Dumbbell = 1,
        Nozzle = 1,
        Nest = Economy.START_NEST,
        Pen = Economy.START_PEN,
        pets = {},
        found = {},
        hatches = 0,
        income = 0,
    }
    local times: { [string]: number } = {}

    local function advance(dt: number)
        s.t += dt
        s.coins += s.income * dt
    end
    local function recomputeIncome()
        table.sort(s.pets, function(a, b)
            return Economy.petIncome(a) > Economy.petIncome(b)
        end)
        local pen = table.move(s.pets, 1, math.min(#s.pets, s.Pen), 1, {})
        local pages = 0
        for z = 1, 5 do
            local all = true
            for slot = 1, 3 do
                all = all and s.found[Economy.Creatures[(z - 1) * 3 + slot].Name] == true
            end
            pages += if all then 1 else 0
        end
        s.income = Economy.incomePerSecond(pen, 0, { bookPages = pages })
    end
    local function goldenHour(): boolean
        return s.t % 600 >= 480
    end
    -- Washes and hatches one egg; returns nothing, advances time.
    local function hatch(c: Economy.Creature, mutation: string?, chunks: number?)
        advance(Economy.washTimeEstimate(c.Zone, s.Nozzle, chunks) + 0.6)
        s.hatches += 1
        local isNew = not s.found[c.Name]
        local full = s.hatches <= 5
            or isNew
            or mutation ~= nil
            or table.find(Economy.RarityOrder, c.Rarity) :: number >= RARE_RANK
        table.insert(s.pets, { Species = c.Name, Mutation = mutation })
        s.found[c.Name] = true
        recomputeIncome()
        if full then
            advance(6.5)
        end
        if isNew then
            advance(5)
            s.coins += c.BookClaim
        end
    end
    local function batch()
        local zoneId = Economy.zoneForStrength(s.strength).Id
        local luck = Economy.Foods[s.Food].Luck
        local eggs = {}
        advance(1) -- walk to the Ledge
        for _ = 1, s.Nest do
            local gh = goldenHour()
            table.insert(eggs, { Economy.rollEgg(zoneId, luck, gh, rand()), (Economy.rollMutation(gh, rand())) })
            advance(1.5)
        end
        advance(math.max(1, 4 - 1.5 * (s.Nest - 1))) -- walk to the Washer, wait for the first egg if needed
        for _, egg in eggs do
            hatch(egg[1], egg[2])
        end
    end

    -- First egg (2.2): release at 5.5 s, egg in nest 4.0 s later, 1.5 s to the Washer, tutorial egg of 6 chunks,
    -- 0.5 s hop; the reveal itself is counted inside hatch(). First egg is always Moss Turtle.
    advance(5.5 + 4.0 + 1.5)
    local firstWashStart = s.t
    hatch(Economy.CreatureByName[Economy.FIRST_EGG], nil, Economy.TUTORIAL_CHUNKS)
    -- hatch() added wash + 0.6 load, 6.5 reveal and 5 claim; first-hatch moment is wash end + 0.5 hop + 5 reveal
    times.firstHatch = firstWashStart + Economy.washTimeEstimate(1, 1, Economy.TUTORIAL_CHUNKS) + 0.5 + 5

    for _, step in PATH do
        local kind = step[1] :: string
        if kind == "Batch" then
            batch()
        elseif kind == "Lift" then
            local zone = Economy.Zones[step[2] :: number]
            local perSecond = Economy.strengthPerRep(s.Dumbbell, 0) * Economy.LIFT_REPS_PER_SECOND
            advance(1 + (zone.StrengthGate - s.strength) / perSecond)
            s.strength = zone.StrengthGate
            times[zone.Name] = s.t
            times[zone.Name .. " income"] = s.income
        else
            local current = if kind == "Rebirth" then 0 else (s :: any)[kind] :: number
            local cost = Economy.upgradeCost(kind, current) :: number
            while s.coins < cost do
                batch()
                if s.t > 4 * 3600 then
                    error(string.format("simulation stuck before %s (coins %.0f, need %.0f)", kind, s.coins, cost))
                end
            end
            s.coins -= cost
            advance(2)
            if kind ~= "Rebirth" then
                (s :: any)[kind] = current + 1
            end
            recomputeIncome()
            times[kind .. (current + 1)] = s.t
        end
    end
    times.income = s.income
    return times
end

local RUNS = 25
local results: { [string]: { number } } = {}
for seed = 1, RUNS do
    for key, value in simulate(seed * 7919) do
        results[key] = results[key] or {}
        table.insert(results[key], value)
    end
end
local function median(key: string): number
    local list = results[key]
    table.sort(list)
    return list[math.ceil(#list / 2)]
end
local function clock(secs: number): string
    return string.format("%d:%02d", secs // 60, secs % 60)
end

local TARGETS = {
    { "firstHatch", 22 },
    { "Bog Marsh", 137 },
    { "Ember Volcano", 570 },
    { "Coral Reef", 1200 },
    { "Starfield", 2400 },
}
local pacingFailures = {}
for _, target in TARGETS do
    local got = median(target[1])
    local ok = math.abs(got - target[2]) <= math.max(15, target[2] * TOLERANCE)
    local income = results[target[1] .. " income"] and median(target[1] .. " income") or 0
    print(
        string.format(
            "%-14s target %s  sim median %s (income %.0f/s)  %s",
            target[1],
            clock(target[2]),
            clock(got),
            income,
            if ok then "ok" else "MISS"
        )
    )
    if not ok then
        table.insert(pacingFailures, target[1])
    end
end
-- Informational: other 4.9 milestones
for _, key in
    {
        "Nest3",
        "Food2",
        "Nozzle2",
        "Food3",
        "Dumbbell2",
        "Food4",
        "Dumbbell3",
        "Food5",
        "Dumbbell4",
        "Food6",
        "Rebirth1",
    }
do
    print(string.format("  %-10s sim median %s", key, clock(median(key))))
end

-- 8. Idling cannot unlock a zone: a Marsh player idling 20 min (4.9) buys every coin upgrade it can,
-- but Strength only comes from reps, so the zone does not change.
do
    local idleCoins = 440 * 20 * 60
    local strength = Economy.Zones[2].StrengthGate
    local tiers = { Dumbbell = 1, Food = 1, Nozzle = 1, Nest = Economy.START_NEST, Pen = Economy.START_PEN }
    local bought = true
    while bought do
        bought = false
        for track, level in tiers do
            local cost = Economy.upgradeCost(track, level)
            if cost and cost <= idleCoins then
                idleCoins -= cost
                tiers[track] = level + 1
                bought = true
            end
        end
    end
    check(tiers.Dumbbell >= 2, "idle Marsh player can afford Stone Weights")
    check(Economy.zoneForStrength(strength).Id == 2, "idling leaves the player in the Marsh")
    check((Economy.upgradeCost("Rebirth", 0) :: number) > 440 * 20 * 60, "idle earnings cannot buy a rebirth")
end

check(#pacingFailures == 0, "pacing targets missed: " .. table.concat(pacingFailures, ", "))
print(string.format("PASS (%d checks)", checks))
return true
