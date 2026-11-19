-- Assert test for src/server/v3/SaveSchema.luau (design-v3 VS-2). Run: lune run tests/SaveSchema.spec.luau
local serde = require("@lune/serde")
local SaveSchema = require("../src/server/v3/SaveSchema")
local Economy = require("../src/shared/Economy")

local checks = 0
local function check(ok: any, msg: string)
    assert(ok, "FAIL: " .. msg)
    checks += 1
end

local function deepEqual(a: any, b: any): boolean
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end
    for k, v in a do
        if not deepEqual(v, b[k]) then
            return false
        end
    end
    for k in b do
        if a[k] == nil then
            return false
        end
    end
    return true
end

-- DataStores store JSON: every save must survive an encode/decode unchanged
local function throughJson(t: any): any
    return serde.decode("json", serde.encode("json", t))
end

local function countPen(d): number
    local n = 0
    for _, p in d.pets do
        if p.pen then
            n += 1
        end
    end
    return n
end

-- 1. Fresh player: no v7 record, no old record
do
    local d, notes = SaveSchema.load(nil, nil)
    assert(d, "load returned nil")
    check(#notes == 0, "fresh load has no notes")
    check(d.version == 7 and d.coins == 0 and d.strength == Economy.START_STRENGTH, "fresh defaults")
    check(d.nestSlots == 2 and d.penSlots == 6 and d.nozzleLevel == 1 and d.foodTier == 1, "fresh slots and tiers")
    check(#d.pets == 0 and #d.nest == 0 and d.migratedFrom == nil, "fresh player has no pets, eggs or migration")
    check(deepEqual(SaveSchema.serialize(d), throughJson(SaveSchema.serialize(d))), "fresh save is JSON-safe")
end

-- 2. v6 record (EggSanctuary_SaveData_v6) with all 5 old species and every mutation
local oldSpecies = { "Meadow Bunny", "Slime Drake", "Ember Hound", "Coral Leviathan", "Galaxy Titan" }
local oldMutations = { "Normal", "Shiny", "Golden", "Rainbow" }
local function oldPet(i: number, name: string, mutation: string?)
    return {
        PetId = "guid-" .. i,
        Name = name,
        Rarity = "Legendary",
        Mutation = mutation,
        Income = 999999,
        RelX = 3,
        RelZ = -4,
    }
end
do
    local garden = {}
    for _, name in oldSpecies do
        for _, m in oldMutations do
            table.insert(garden, oldPet(#garden + 1, name, m))
        end
    end
    local v6 = {
        Strength = 123456,
        BioEssence = 9e9,
        FoodTier = 8,
        EggsCleaned = 40,
        MaxSlots = 24,
        GardenPets = garden,
        CleanerUpgrades = { PSILevel = 5, WidthLevel = 3, Tier = 4 },
        LastSaveTime = 1763400000,
    }
    v6 = throughJson(v6) -- as read back from the DataStore
    local d, notes = SaveSchema.load(nil, v6, 6)
    assert(d, "load returned nil")
    check(#notes == 0, "clean v6 record converts without notes")
    check(d.migratedFrom == 6, "marked migratedFrom = 6")
    check(#d.pets == 20, "all 20 old pets kept")
    local seen = {}
    for i, p in d.pets do
        local src = garden[i]
        check(p.species == src.Name, "pet " .. i .. " keeps its species name")
        check(p.mutation == src.Mutation, "pet " .. i .. " keeps its mutation")
        check(Economy.CreatureByName[p.species] ~= nil, "species exists in v3")
        check(p.Rarity == nil and p.Income == nil and p.RelX == nil, "old Rarity, Income, RelX dropped")
        seen[p.id] = true
    end
    local ids = 0
    for _ in seen do
        ids += 1
    end
    check(ids == 20 and d.nextId == 21, "unique pet ids and nextId")
    check(countPen(d) == Economy.START_PEN, "pen filled to its 6 slots")
    -- The pen holds the 6 best by v3 income: Galaxy Titan x4 then Coral Leviathan Rainbow and Golden
    local penIncome, storageBest = math.huge, 0
    for _, p in d.pets do
        local inc = Economy.petIncome({ Species = p.species, Mutation = p.mutation })
        if p.pen then
            penIncome = math.min(penIncome, inc)
        else
            storageBest = math.max(storageBest, inc)
        end
    end
    check(penIncome >= storageBest, "pen holds the best-income pets")
    check(d.coins == 0 and d.strength == Economy.START_STRENGTH and d.foodTier == 1, "old economy not carried")
    check(d.nestSlots == Economy.START_NEST and d.nozzleLevel == 1, "old MaxSlots and CleanerUpgrades not carried")
    check(d.tutorialStep == 0, "tutorial still runs for converted players")
end

-- 3. v5 record (EggSanctuary_SaveData_v5: no CleanerUpgrades, earliest builds had no MaxSlots)
do
    local v5 = throughJson({
        Strength = 150,
        BioEssence = 50,
        FoodTier = 1,
        EggsCleaned = 0,
        GardenPets = {
            { PetId = "starter_bunny_1", Name = "Meadow Bunny", Rarity = "Common", Mutation = "Normal", Income = 3 },
            oldPet(2, "Slime Drake", "Shiny"),
        },
    })
    local d = SaveSchema.load(nil, v5, 5)
    assert(d, "load returned nil")
    check(d.migratedFrom == 5 and #d.pets == 2, "v5 record converts with both pets")
    check(d.pets[1].species == "Meadow Bunny" and d.pets[2].mutation == "Shiny", "v5 pets mapped")
    check(countPen(d) == 2, "both in the pen")
end

-- 4. Old records with odd pets: unknown names become Meadow Bunny (logged), missing mutation is Normal
do
    local d, notes = SaveSchema.load(nil, {
        GardenPets = {
            oldPet(1, "Mystery Beast", "Golden"),
            oldPet(2, "Ember Hound", nil),
            oldPet(3, "Galaxy Titan", "Sparkly"),
            "not a pet",
        },
    }, 6)
    assert(d, "load returned nil")
    check(#d.pets == 3, "3 table pets kept, junk entry dropped")
    check(d.pets[1].species == "Meadow Bunny" and d.pets[1].mutation == "Golden", "unknown name -> Meadow Bunny")
    check(d.pets[2].mutation == "Normal", "missing mutation -> Normal")
    check(d.pets[3].mutation == "Normal", "unknown mutation -> Normal")
    check(#notes == 3, "unknown name, unknown mutation and junk entry are logged")
    -- Old record with no GardenPets at all, and an old record that is not a table
    local d2 = SaveSchema.load(nil, { Strength = 10 }, 6)
    check(d2 and #d2.pets == 0 and d2.migratedFrom == 6, "old record without pets converts")
    local d3 = SaveSchema.load(nil, "garbage", 6)
    check(d3 and #d3.pets == 0 and d3.migratedFrom == nil, "non-table old record treated as new player")
end

-- 5. A lock-only v7 record (first join wrote the lock before conversion) still converts the old save
do
    local lockOnly = { lock = { jobId = "a", t = 100 } }
    check(not SaveSchema.isV3(lockOnly), "lock-only record is not v3 data")
    local d = SaveSchema.load(lockOnly, { GardenPets = { oldPet(1, "Slime Drake", "Normal") } }, 6)
    check(d and #d.pets == 1 and d.migratedFrom == 6, "lock-only v7 + v6 converts")
    -- Once v3 data exists the old record is ignored
    local v7 = SaveSchema.serialize(SaveSchema.new())
    local d2 = SaveSchema.load(v7, { GardenPets = { oldPet(1, "Slime Drake", "Normal") } }, 6)
    check(d2 and #d2.pets == 0 and d2.migratedFrom == nil, "v7 data wins over the old record")
end

-- 6. Corrupt or partial v7 data is cleaned without errors
do
    local nan = 0 / 0
    local bad = {
        version = 7,
        coins = nan,
        strength = -5,
        foodTier = 99,
        dumbbellTier = "3",
        nestSlots = 1.7,
        penSlots = 7.9,
        nozzleLevel = math.huge,
        rebirths = -1,
        tutorialStep = 400,
        pets = {
            { id = 1, species = "Galaxy Titan", mutation = "Rainbow", pen = true },
            { id = 1, species = "Bog Frog", mutation = "Shiny", pen = true }, -- duplicate id
            { id = 2.5, species = "Moss Turtle", pen = "yes" }, -- bad id, bad pen, no mutation
            { id = 3, species = "Not A Creature", pen = true },
            "junk",
            { id = 4, species = "Meadow Bunny", mutation = "Normal", pen = true },
            { id = 5, species = "Meadow Bunny", mutation = "Normal", pen = true },
            { id = 6, species = "Meadow Bunny", mutation = "Normal", pen = true },
            { id = 7, species = "Meadow Bunny", mutation = "Normal", pen = true },
            { id = 8, species = "Meadow Bunny", mutation = "Normal", pen = true },
            { id = 9, species = "Meadow Bunny", mutation = "Normal", pen = true },
        },
        nest = {
            { id = 20, zone = 5, species = "Bog Frog", mutation = "Golden", chunks = Economy.TUTORIAL_CHUNKS }, -- zone mismatch
            { id = 21, species = "Nope" },
            42,
        },
        book = { ["Bog Frog"] = { found = true, claimed = "x", mutations = { Shiny = true, Fake = true } }, Fake = {} },
        daily = "x",
        settings = { music = false, sfx = 3 },
        receipts = { abc = true, [5] = true },
        stats = { throws = -3, hatches = 12 },
        nextId = 2,
    }
    local ok, d, notes = pcall(SaveSchema.load, bad)
    check(ok, "corrupt record does not error: " .. tostring(d))
    assert(d, "load returned nil")
    check(d.coins == 0 and d.strength == Economy.START_STRENGTH, "NaN coins and negative Strength reset")
    check(d.foodTier == #Economy.Foods and d.dumbbellTier == 1, "tiers clamped / defaulted")
    check(d.nestSlots == 2 and d.penSlots == 7 and d.nozzleLevel == 1, "slots clamped, inf defaulted")
    check(d.rebirths == 0 and d.tutorialStep == SaveSchema.TUTORIAL_STEPS, "rebirths and tutorial clamped")
    check(#d.pets == 9, "valid pets kept (unknown species and junk dropped)")
    local ids = {}
    for _, p in d.pets do
        check(not ids[p.id], "pet ids unique after cleaning")
        ids[p.id] = true
        check(type(p.pen) == "boolean" and type(p.mutation) == "string", "pet fields typed")
    end
    check(countPen(d) == 7, "pen overflow moved to storage")
    local titan
    for _, p in d.pets do
        if p.species == "Galaxy Titan" then
            titan = p
        end
    end
    check(titan and titan.pen, "best pet stays in the pen")
    check(
        #d.nest == 1 and d.nest[1].zone == 2 and d.nest[1].chunks == Economy.TUTORIAL_CHUNKS,
        "egg zone follows species"
    )
    check(not ids[d.nest[1].id], "egg id does not collide with a pet id")
    check(d.nextId > 21, "nextId above every id")
    check(d.book["Bog Frog"].claimed == false and d.book["Bog Frog"].mutations.Fake == nil, "book cleaned")
    check(d.book.Fake == nil, "unknown book species dropped")
    check(d.daily.streak == 0 and d.settings.music == false and d.settings.sfx == true, "daily/settings cleaned")
    check(d.receipts.abc == true and d.receipts[5 :: any] == nil, "receipts keep string keys")
    check(d.stats.throws == 0 and d.stats.hatches == 12, "stats clamped")
    check(#notes >= 4, "fixes are reported")

    -- Partial record: only a version and some coins
    local p = SaveSchema.load({ version = 7, coins = 500 })
    check(p and p.coins == 500 and p.penSlots == 6 and #p.pets == 0, "partial record fills defaults")
    -- Non-table pets/nest and an empty table
    local e = SaveSchema.load({ version = 7, pets = "x", nest = 5 })
    check(e and #e.pets == 0 and #e.nest == 0, "non-table lists become empty")
    local s = SaveSchema.sanitize(nil)
    check(s.version == 7, "sanitize(nil) gives a fresh record")
end

-- 7. Newer schema is refused instead of being overwritten
do
    local d, notes = SaveSchema.load({ version = 8, coins = 5 })
    check(d == nil and #notes == 1, "newer version not loaded")
end

-- 8. Round trip: leave with 2 eggs in the nest (one still flying, one half washed), rejoin: eggs still there
do
    local d = SaveSchema.new()
    d.coins = 1234.5
    d.strength = 81
    d.nestSlots = 3
    d.tutorialStep = 9
    d.pets = {
        { id = 1, species = "Moss Turtle", mutation = "Normal", pen = true },
        { id = 2, species = "Bog Frog", mutation = "Golden", pen = false },
    }
    -- Runtime fields EggRules adds must not be saved
    local flying: any = {
        id = 3,
        zone = 1,
        species = "Clover Fawn",
        mutation = "Shiny",
        sparkle = true,
        chunks = Economy.CHUNKS_PER_EGG,
        gift = true,
    }
    flying.state, flying.arrivesAt = "Flight", 99
    local washing: any = {
        id = 4,
        zone = 2,
        species = "Bog Frog",
        mutation = "Normal",
        sparkle = false,
        chunks = Economy.CHUNKS_PER_EGG,
    }
    washing.state, washing.hp, washing.washStart = "Washing", { 0, 0, 5 }, 12
    d.nest = { flying, washing }
    d.book["Moss Turtle"] = { found = true, claimed = true, mutations = { Normal = true } }
    d.receipts["purchase-1"] = true
    d.stats = { throws = 4, hatches = 2 }
    d.pity = { [1] = 3, [2] = 7 }
    d.gifts.rareEgg = true
    d.nextId = 5
    d.migratedFrom = 6

    local saved = SaveSchema.serialize(d)
    check(saved.nest[1].state == nil and saved.nest[2].hp == nil, "runtime egg fields not saved")
    local back = SaveSchema.load(throughJson(saved))
    assert(back, "load returned nil")
    check(#back.nest == 2, "both eggs still in the nest after rejoin")
    check(back.nest[1].species == "Clover Fawn" and back.nest[1].mutation == "Shiny", "egg contents kept")
    check(deepEqual(SaveSchema.serialize(back), saved), "load(serialize(d)) round trip is lossless")
    check(back.coins == 1234.5 and back.migratedFrom == 6 and back.receipts["purchase-1"], "scalars kept")
    check(back.pity[1] == 3 and back.pity[2] == 7 and back.gifts.rareEgg, "discovery meter and gift flag kept")
    check(back.nest[1].gift == true and back.nest[2].gift == nil, "gift egg keeps its flag")
end

-- 9. Session lock
do
    check(SaveSchema.lockState(nil, "a", 1000) == "free", "no record -> free")
    check(SaveSchema.lockState({ lock = { jobId = "a", t = 990 } }, "a", 1000) == "ours", "own lock")
    check(SaveSchema.lockState({ lock = { jobId = "b", t = 990 } }, "a", 1000) == "other", "other server's lock")
    check(SaveSchema.lockState({ lock = { jobId = "b", t = 600 } }, "a", 1000) == "free", "stale lock is free")
    check(SaveSchema.lockState({ lock = "x" }, "a", 1000) == "free", "junk lock is free")
end

print(string.format("PASS SaveSchema (%d checks)", checks))
return true
