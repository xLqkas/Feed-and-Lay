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
    { Id = 2, Name = "Bog Marsh", MinDist = 100, MaxDist = 1000, StrengthGate = 80, ChunkHP = 30, Tint = "green" },
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

-- 4.6 Nozzle. AvgChunksHit is the design's expected chunks hit per spray, used for wash-time estimates.
Economy.Nozzles = {
    { Level = 1, Name = "Garden Hose", DPS = 10, Radius = 1.5, MaxChunksPerHit = 2, AvgChunksHit = 1.4, Cost = 0 },
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
Economy.CHUNKS_PER_EGG = 10
Economy.TUTORIAL_CHUNKS = 6
Economy.MIN_WASH_TIME = 1.5

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

-- Expected seconds to wash one egg at a nozzle level (4.6 table), floored at MIN_WASH_TIME
function Economy.washTimeEstimate(zoneId: number, nozzleLevel: number, chunks: number?): number
    local nozzle = Economy.Nozzles[nozzleLevel]
    local hp = Economy.Zones[zoneId].ChunkHP * (chunks or Economy.CHUNKS_PER_EGG)
    return math.max(Economy.MIN_WASH_TIME, hp / (nozzle.DPS * nozzle.AvgChunksHit))
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
