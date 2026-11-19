--!strict
-- Every economy number from design-v3.md section 4, plus pure functions the server uses.
-- No Roblox services: runs in Studio, Lune or plain Luau. Tested by tests/Economy.spec.luau.

local Economy = {}

export type Zone = {
    Id: number,
    Name: string,
    MinDist: number,
    MaxDist: number, -- math.huge for the last zone
    StrengthGate: number, -- Strength that reaches MinDist with a SWEET throw
    ChunkHP: number,
    Tint: string,
}

export type Creature = {
    Name: string,
    Zone: number,
    Slot: string, -- "A" | "B" | "C"
    Rarity: string,
    Income: number,
    BookClaim: number,
}

export type Pet = { Species: string, Mutation: string? }

export type IncomeBonuses = {
    x2Coins: boolean?,
    vip: boolean?,
    friends: number?,
    bookPages: number?,
}

-- Starting state (section 2.2)
Economy.START_STRENGTH = 50
Economy.START_NEST = 2
Economy.MAX_NEST = 8
Economy.START_PEN = 6
Economy.MAX_PEN = 16
Economy.BIG_PEN_BONUS = 4
Economy.STORAGE = 60
Economy.FIRST_EGG = "Moss Turtle" -- the first egg ever is always this (section 4.5)

-- 4.1 Zones. Distance = Strength x throw multiplier (max 1.25).
Economy.Zones = {
    { Id = 1, Name = "Dewdrop Meadow", MinDist = 0, MaxDist = 100, StrengthGate = 0, ChunkHP = 10, Tint = "cream" },
    { Id = 2, Name = "Bog Marsh", MinDist = 100, MaxDist = 1000, StrengthGate = 80, ChunkHP = 20, Tint = "green" },
    {
        Id = 3,
        Name = "Ember Volcano",
        MinDist = 1000,
        MaxDist = 10000,
        StrengthGate = 800,
        ChunkHP = 100,
        Tint = "charcoal",
    },
    {
        Id = 4,
        Name = "Coral Reef",
        MinDist = 10000,
        MaxDist = 100000,
        StrengthGate = 8000,
        ChunkHP = 300,
        Tint = "teal",
    },
    {
        Id = 5,
        Name = "Starfield",
        MinDist = 100000,
        MaxDist = math.huge,
        StrengthGate = 80000,
        ChunkHP = 1000,
        Tint = "violet",
    },
} :: { Zone }

-- 3.2 Throw meter
Economy.SWEET_MIN = 0.82
Economy.SWEET_MAX = 0.96
Economy.SWEET_MULTIPLIER = 1.25

-- 4.2 Dumbbells (Strength per good rep; perfect = 2 reps)
Economy.Dumbbells = {
    { Tier = 1, Name = "Twig Weights", PerRep = 1, Cost = 0 },
    { Tier = 2, Name = "Stone Weights", PerRep = 10, Cost = 50e3 },
    { Tier = 3, Name = "Iron Weights", PerRep = 100, Cost = 6e6 },
    { Tier = 4, Name = "Gold Weights", PerRep = 1000, Cost = 1.5e9 },
}
Economy.LIFT_REPS_PER_SECOND = 1.2 -- measured target for an active player (3.1)

-- 3.1 Lift ring timing. Each ring waits a random gap (hidden), then shrinks from 2x the target radius to the
-- target in a random time T; the tap is judged by how far the ring is from the target, as a share of T.
-- Gaps and T come from Economy.liftRing(seed, k), so the server and the client agree on every ring.
Economy.LIFT_GAP_MIN = 0.25
Economy.LIFT_GAP_MAX = 1.1
Economy.LIFT_RING_MIN = 0.75
Economy.LIFT_RING_MAX = 1.1
Economy.LIFT_PERFECT = 0.06 -- ring within 6% of the target radius
Economy.LIFT_GOOD = 0.18
Economy.LIFT_LATE = 0.3 -- no tap until the ring is 30% inside the target: miss, next ring
Economy.LIFT_MIN_REP_GAP = 0.6 -- seconds between accepted reps
Economy.LIFT_MAX_PER_MINUTE = 75
Economy.LIFT_MAX_PER_10_MIN = 650
Economy.LIFT_PERFECT_MAX = 30 -- perfects allowed in any 50 accepted reps; more are downgraded to good
Economy.LIFT_PERFECT_WINDOW = 50
Economy.LIFT_IDLE_CLOSE = 20 -- seconds without a tap closes the Lift HUD

-- 4.3 Food (luck L). Lucky Food pass doubles L.
Economy.Foods = {
    { Tier = 1, Name = "Apple", Luck = 1, Cost = 0 },
    { Tier = 2, Name = "Carrot", Luck = 2, Cost = 500 },
    { Tier = 3, Name = "Blueberries", Luck = 4, Cost = 15e3 },
    { Tier = 4, Name = "Pancakes", Luck = 8, Cost = 1e6 },
    { Tier = 5, Name = "Strawberry", Luck = 16, Cost = 300e6 },
    { Tier = 6, Name = "Star Cookie", Luck = 32, Cost = 10e9 },
}

-- 4.4 Rarities, in order, with colour hex (Secret is an animated rainbow gradient)
Economy.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
Economy.RarityColors = {
    Common = "#B8C0CC",
    Uncommon = "#5BD45B",
    Rare = "#3BA7FF",
    Epic = "#B65CFF",
    Legendary = "#FFC800",
    Mythic = "#FF4B6E",
    Secret = "rainbow",
}

local function bookClaim(income: number): number
    return math.max(100, 30 * income)
end

local function creature(name: string, zone: number, slot: string, rarity: string, income: number): Creature
    return { Name = name, Zone = zone, Slot = slot, Rarity = rarity, Income = income, BookClaim = bookClaim(income) }
end

-- 4.4 The 15 creatures, ordered by zone then slot
Economy.Creatures = {
    creature("Meadow Bunny", 1, "A", "Common", 1),
    creature("Moss Turtle", 1, "B", "Uncommon", 3),
    creature("Clover Fawn", 1, "C", "Rare", 10),
    creature("Bog Frog", 2, "A", "Uncommon", 25),
    creature("Slime Drake", 2, "B", "Rare", 60),
    creature("Lily Croc", 2, "C", "Epic", 200),
    creature("Ember Hound", 3, "A", "Rare", 600),
    creature("Magma Newt", 3, "B", "Epic", 1.5e3),
    creature("Ash Phoenix", 3, "C", "Legendary", 5e3),
    creature("Bubble Seal", 4, "A", "Epic", 15e3),
    creature("Coral Leviathan", 4, "B", "Legendary", 40e3),
    creature("Pearl Whale", 4, "C", "Mythic", 120e3),
    creature("Comet Fox", 5, "A", "Legendary", 400e3),
    creature("Nebula Kirin", 5, "B", "Mythic", 1.2e6),
    creature("Galaxy Titan", 5, "C", "Secret", 5e6),
} :: { Creature }

Economy.CreatureByName = {} :: { [string]: Creature }
for _, c in Economy.Creatures do
    Economy.CreatureByName[c.Name] = c
end

-- 4.5 Odds weights: A = 80, B = 18 x sqrt(L), C = c x L x G
Economy.WEIGHT_A = 80
Economy.WEIGHT_B = 18
Economy.WEIGHT_C = 2
Economy.WEIGHT_C_STARFIELD = 0.2
Economy.GOLDEN_HOUR_C = 2

-- 4.5 Mutations, rarest first so a single roll can walk the list. Golden Hour triples the chances.
Economy.Mutations = {
    { Name = "Rainbow", Multiplier = 10, Chance = 0.001 },
    { Name = "Golden", Multiplier = 5, Chance = 0.005 },
    { Name = "Shiny", Multiplier = 2, Chance = 0.02 },
}
Economy.GOLDEN_HOUR_MUTATION = 3

-- 4.6 Nozzle. AvgChunksHit: average blobs' worth of full damage per second of spraying, fitted to the lune wash
-- simulation (tests/EggService.spec.luau 5b), used for wash-time estimates.
Economy.Nozzles = {
    { Level = 1, Name = "Garden Hose", DPS = 10, Radius = 1.5, MaxChunksPerHit = 2, AvgChunksHit = 1.05, Cost = 0 },
    {
        Level = 2,
        Name = "Pressure Wand",
        DPS = 30,
        Radius = 2.0,
        MaxChunksPerHit = 3,
        AvgChunksHit = 1.7,
        Cost = 1.5e3,
    },
    { Level = 3, Name = "Turbo Jet", DPS = 100, Radius = 2.5, MaxChunksPerHit = 4, AvgChunksHit = 2.0, Cost = 60e3 },
    { Level = 4, Name = "Hydro Cannon", DPS = 300, Radius = 3.0, MaxChunksPerHit = 5, AvgChunksHit = 2.3, Cost = 4e6 },
    {
        Level = 5,
        Name = "Star Blaster",
        DPS = 1000,
        Radius = 3.5,
        MaxChunksPerHit = 6,
        AvgChunksHit = 2.6,
        Cost = 300e6,
    },
}
Economy.CHUNKS_PER_EGG = 5
Economy.TUTORIAL_CHUNKS = 4
Economy.MIN_WASH_TIME = 1.5
Economy.WASH_SWEEP_FLOOR = 3.5 -- even an instant nozzle waits for the back blobs to turn into view

-- Discovery meter (catchiness pass): every hatch from a zone still missing a creature fills that zone's meter;
-- once it reaches the missing creature's number, the next egg thrown into the zone is that creature. The meter
-- empties on every new discovery in the zone. "Missing" = the first unfound creature of the zone in slot order.
Economy.DISCOVERY_PITY = { Common = 1, Uncommon = 4, Rare = 8, Epic = 12, Legendary = 20, Mythic = 30, Secret = 50 }

-- Scripted first-time gift (catchiness pass): from this throw on, the first Meadow egg is a sparkly Clover Fawn,
-- once per save. Shown to the player as a gift from Mama Hen, never as luck, and never sold.
Economy.GIFT_THROW = 4
Economy.GIFT_SPECIES = "Clover Fawn"

-- 4.6 Slot costs, keyed by the slot being bought
Economy.NestSlotCost = { [3] = 100, [4] = 1e3, [5] = 20e3, [6] = 500e3, [7] = 20e6, [8] = 1e9 }
Economy.PenSlotCost = {
    [7] = 300,
    [8] = 2e3,
    [9] = 10e3,
    [10] = 50e3,
    [11] = 250e3,
    [12] = 1.5e6,
    [13] = 10e6,
    [14] = 80e6,
    [15] = 600e6,
    [16] = 5e9,
}

-- Server timings and ranges for the egg pipeline (sections 3.2-3.6)
Economy.THROW_COOLDOWN = 1.5
Economy.MAX_HOLD = 6 -- charge auto-cancels after this
Economy.NEEDLE_HALF_CYCLE = 1.4 -- needle goes 0 -> 1 in this many seconds, then back
Economy.ELAPSED_TOLERANCE = 0.15 -- client hold time accepted within this of the server's
Economy.FOOD_FLIGHT = 1.2
Economy.EGG_LAUNCH_AT = 2.5
Economy.FLIGHT_TIME = 4.0 -- release to egg in nest
Economy.TURNTABLE_DEG_PER_SEC = 60
Economy.FACING_MIN_DOT = 0.1 -- chunk normal . view direction below this takes no damage
Economy.SPRAY_DT_CAP = 0.15
-- Wash (playtest Q2): a few big mud blobs. Unit-egg units (1 = the egg's radius). Every batch whose aim point
-- is on the egg and has moved at least AIM_MOVE_MIN since the last batch scrubs every facing blob at
-- SCRUB_SHARE of the nozzle DPS; blobs within AIM_RADIUS of the aim (nearest first, up to the nozzle's cap) take
-- full damage. Spraying with a direct hit builds a combo (+COMBO_STEP per 0.1 s, up to COMBO_MAX steps); a
-- parked aim does nothing and resets the combo. AIM_MOVE_MIN is per 0.1 s of spraying.
Economy.AIM_RADIUS = 0.45
Economy.AIM_MOVE_MIN = 0.04
Economy.SCRUB_SHARE = 0.4
Economy.COMBO_STEP = 0.05
Economy.COMBO_MAX = 10
Economy.BLOB_STAGES = 4 -- a blob knocks off a visible chunk (ChunkHit) at each quarter of its HP
Economy.WASH_LOAD_DELAY = 0.6 -- next egg hops onto the turntable this long after the last one
Economy.FULL_REVEAL_TIME = 6.5 -- 3.0 wobble + 2.0 roll + 1.5 hold
Economy.COMPACT_REVEAL_TIME = 2.5
Economy.FULL_REVEAL_HATCHES = 5 -- hatches 1-5 ever always get the full reveal
Economy.LEDGE_RADIUS = 6 -- studs from the Ledge station
Economy.LIFT_RADIUS = 8 -- studs from the Lift Bench station (3.1)
Economy.WASHER_RADIUS = 10

-- 3.7 Income bonuses
Economy.REBIRTH_INCOME_BONUS = 0.5
Economy.X2_COINS = 2
Economy.VIP_BONUS = 1.1
Economy.FRIEND_BONUS = 0.1
Economy.MAX_FRIENDS_BONUS = 3
Economy.BOOK_PAGE_BONUS = 0.05
Economy.RELEASE_REFUND = 20 -- x base income

-- 4.8 Rebirth
Economy.REBIRTH_BASE_COST = 40e9
Economy.REBIRTH_COST_GROWTH = 4
Economy.MAX_REBIRTHS = 10

-- p is the needle position 0..1 at release (3.2)
function Economy.throwMultiplier(p: number): number
    p = math.clamp(p, 0, 1)
    if p < Economy.SWEET_MIN then
        return 0.05 + p
    elseif p < Economy.SWEET_MAX then
        return Economy.SWEET_MULTIPLIER
    end
    return 1
end

function Economy.zoneForDistance(distance: number): Zone
    for i = #Economy.Zones, 1, -1 do
        if distance >= Economy.Zones[i].MinDist then
            return Economy.Zones[i]
        end
    end
    return Economy.Zones[1]
end

-- Farthest zone a SWEET throw reaches: what this Strength has unlocked
function Economy.zoneForStrength(strength: number): Zone
    return Economy.zoneForDistance(strength * Economy.SWEET_MULTIPLIER)
end

-- Ring k (1, 2, ...) of a lift session: hidden gap before it shows, and its shrink time T. Pure and
-- deterministic (Park-Miller steps on the session seed), so the client can draw rings the server will judge.
function Economy.liftRing(seed: number, k: number): (number, number)
    local x = (seed * 7919 + k * 104729) % 2147483647
    x = (x * 48271) % 2147483647
    local u1 = x / 2147483647
    x = (x * 48271) % 2147483647
    local u2 = x / 2147483647
    return Economy.LIFT_GAP_MIN + (Economy.LIFT_GAP_MAX - Economy.LIFT_GAP_MIN) * u1,
        Economy.LIFT_RING_MIN + (Economy.LIFT_RING_MAX - Economy.LIFT_RING_MIN) * u2
end

-- Judges a tap `elapsed` seconds after ring start for a ring of shrink time T: "perfect", "good" or "miss"
function Economy.liftJudge(elapsed: number, T: number): string
    local off = math.abs(elapsed - T) / T
    if off <= Economy.LIFT_PERFECT then
        return "perfect"
    elseif off <= Economy.LIFT_GOOD then
        return "good"
    end
    return "miss"
end

function Economy.strengthPerRep(dumbbellTier: number, rebirths: number): number
    return Economy.Dumbbells[dumbbellTier].PerRep * (1 + rebirths)
end

-- Odds for slots A, B, C in a zone; L is food luck after passes
function Economy.eggOdds(zoneId: number, luck: number, goldenHour: boolean): { number }
    local c = if zoneId == 5 then Economy.WEIGHT_C_STARFIELD else Economy.WEIGHT_C
    local a = Economy.WEIGHT_A
    local b = Economy.WEIGHT_B * math.sqrt(luck)
    local cw = c * luck * (if goldenHour then Economy.GOLDEN_HOUR_C else 1)
    local sum = a + b + cw
    return { a / sum, b / sum, cw / sum }
end

-- r is a uniform random number in [0, 1) supplied by the caller (Random:NextNumber())
function Economy.rollEgg(zoneId: number, luck: number, goldenHour: boolean, r: number): Creature
    local odds = Economy.eggOdds(zoneId, luck, goldenHour)
    local slot = 3
    if r < odds[1] then
        slot = 1
    elseif r < odds[1] + odds[2] then
        slot = 2
    end
    return Economy.Creatures[(zoneId - 1) * 3 + slot]
end

-- Returns the mutation name or nil for Normal, and its income multiplier
function Economy.rollMutation(goldenHour: boolean, r: number): (string?, number)
    local scale = if goldenHour then Economy.GOLDEN_HOUR_MUTATION else 1
    local edge = 0
    for _, m in Economy.Mutations do
        edge += m.Chance * scale
        if r < edge then
            return m.Name, m.Multiplier
        end
    end
    return nil, 1
end

function Economy.mutationMultiplier(mutation: string?): number
    for _, m in Economy.Mutations do
        if m.Name == mutation then
            return m.Multiplier
        end
    end
    return 1
end

-- Expected seconds to wash one egg at a nozzle level, floored at WASH_SWEEP_FLOOR
function Economy.washTimeEstimate(zoneId: number, nozzleLevel: number, chunks: number?): number
    local nozzle = Economy.Nozzles[nozzleLevel]
    local hp = Economy.Zones[zoneId].ChunkHP * (chunks or Economy.CHUNKS_PER_EGG)
    return math.max(Economy.WASH_SWEEP_FLOOR, hp / (nozzle.DPS * nozzle.AvgChunksHit))
end

-- First creature of a zone (slot order A, B, C) the player has not found, or nil when the zone is complete
function Economy.missingCreature(zoneId: number, found: { [string]: boolean }): Creature?
    for slot = 1, 3 do
        local c = Economy.Creatures[(zoneId - 1) * 3 + slot]
        if not found[c.Name] then
            return c
        end
    end
    return nil
end

function Economy.petIncome(pet: Pet): number
    return Economy.CreatureByName[pet.Species].Income * Economy.mutationMultiplier(pet.Mutation)
end

-- Coins per second for the pets in the pen (3.7)
function Economy.incomePerSecond(penPets: { Pet }, rebirths: number, bonuses: IncomeBonuses?): number
    local b: IncomeBonuses = bonuses or {}
    local total = 0
    for _, pet in penPets do
        total += Economy.petIncome(pet)
    end
    local friends = math.min(b.friends or 0, Economy.MAX_FRIENDS_BONUS)
    return total
        * (1 + Economy.REBIRTH_INCOME_BONUS * rebirths)
        * (if b.x2Coins then Economy.X2_COINS else 1)
        * (if b.vip then Economy.VIP_BONUS else 1)
        * (1 + Economy.FRIEND_BONUS * friends)
        * (1 + Economy.BOOK_PAGE_BONUS * (b.bookPages or 0))
end

-- Cost of the next level of a track, or nil when maxed.
-- current = food tier, dumbbell tier, nozzle level, nest slots, pen slots (without Big Pen) or rebirths.
function Economy.upgradeCost(track: string, current: number): number?
    if track == "Food" then
        local nextFood = Economy.Foods[current + 1]
        return if nextFood then nextFood.Cost else nil
    elseif track == "Dumbbell" then
        local nextBell = Economy.Dumbbells[current + 1]
        return if nextBell then nextBell.Cost else nil
    elseif track == "Nozzle" then
        local nextNozzle = Economy.Nozzles[current + 1]
        return if nextNozzle then nextNozzle.Cost else nil
    elseif track == "Nest" then
        return Economy.NestSlotCost[current + 1]
    elseif track == "Pen" then
        return Economy.PenSlotCost[current + 1]
    elseif track == "Rebirth" then
        if current >= Economy.MAX_REBIRTHS then
            return nil
        end
        return Economy.REBIRTH_BASE_COST * Economy.REBIRTH_COST_GROWTH ^ current
    end
    error("unknown upgrade track " .. track)
end

return Economy
