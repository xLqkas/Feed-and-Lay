--!strict
-- Unit Tests for Egg Sanctuary V3: SaveSchema (v5, v6, v7, corrupted) & EggRules pure functions
-- Run in Studio Command Bar / Edit session or test harness.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Economy = require(ReplicatedStorage.Modules.Economy)
local SaveSchema = require(ServerScriptService.EggSanctuaryServer.V3.SaveSchema)
local EggRules = require(ServerScriptService.EggSanctuaryServer.V3.EggRules)

print("--- Running Egg Sanctuary V3 SaveSchema & EggRules Tests ---")

-- ====================================================================
-- PART 1: SaveSchema.load with v7, legacy v6, legacy v5, and corrupted data
-- ====================================================================

-- Test 1: Clean v7 record load
local v7Record = {
    version = 7,
    coins = 1500,
    strength = 350,
    foodTier = 2,
    dumbbellTier = 1,
    nestSlots = 2,
    penSlots = 3,
    nozzleLevel = 2,
    rebirths = 0,
    tutorialStep = 5,
    pets = {
        { id = 1, species = "Meadow Bunny", mutation = "Normal", pen = true },
        { id = 2, species = "Slime Drake", mutation = "Shiny", pen = true }
    },
    nest = {},
    book = {},
    daily = { streak = 1, lastDay = 1 },
    settings = { music = true, sfx = true, followThrows = false, reducedMotion = false },
    receipts = {},
    stats = { throws = 10, hatches = 5 },
    pity = {},
    gifts = { rareEgg = false },
    nextId = 3,
}

local loadedV7, notesV7 = SaveSchema.load(v7Record, nil, nil)
assert(loadedV7 ~= nil, "Test 1 Failed: v7 record should load")
assert(loadedV7.version == 7, "Test 1 Failed: version should be 7")
assert(loadedV7.coins == 1500, "Test 1 Failed: coins should be 1500")
assert(loadedV7.strength == 350, "Test 1 Failed: strength should be 350")
assert(#loadedV7.pets == 2, "Test 1 Failed: pets count should be 2")
assert(loadedV7.pets[1].species == "Meadow Bunny", "Test 1 Failed: pet 1 species match")
print("✓ Test 1: Clean v7 record load passed!")

-- Test 2: Legacy v6 record conversion
local legacyV6 = {
    Strength = 250,
    BioEssence = 300,
    FoodTier = 2,
    EggsCleaned = 12,
    MaxSlots = 4,
    GardenPets = {
        { PetId = "p1", Name = "Meadow Bunny", Rarity = "Common", Mutation = "Normal", Income = 3 },
        { PetId = "p2", Name = "Ember Hound", Rarity = "Rare", Mutation = "Golden", Income = 75 }
    }
}

local loadedV6, notesV6 = SaveSchema.load(nil, legacyV6, 6)
assert(loadedV6 ~= nil, "Test 2 Failed: v6 legacy record should load")
assert(loadedV6.migratedFrom == 6, "Test 2 Failed: migratedFrom should be 6")
assert(#loadedV6.pets == 2, "Test 2 Failed: both pets should be converted")
assert(loadedV6.coins == 0, "Test 2 Failed: legacy currency should be dropped per design")
assert(loadedV6.strength == Economy.START_STRENGTH, "Test 2 Failed: strength reset to START_STRENGTH")
assert(loadedV6.pets[1].pen == true, "Test 2 Failed: highest earner fitted into pen")
print("✓ Test 2: Legacy v6 record migration passed!")

-- Test 3: Legacy v5 record conversion with unknown creature
local legacyV5 = {
    Strength = 100,
    BioEssence = 50,
    GardenPets = {
        { PetId = "p_old", Name = "Ancient NonExistent Monster", Mutation = "Rainbow" }
    }
}

local loadedV5, notesV5 = SaveSchema.load(nil, legacyV5, 5)
assert(loadedV5 ~= nil, "Test 3 Failed: v5 legacy record should load")
assert(loadedV5.migratedFrom == 5, "Test 3 Failed: migratedFrom should be 5")
assert(#loadedV5.pets == 1, "Test 3 Failed: 1 pet converted")
assert(loadedV5.pets[1].species == "Meadow Bunny", "Test 3 Failed: unknown creature falls back to Meadow Bunny")
assert(loadedV5.pets[1].mutation == "Rainbow", "Test 3 Failed: mutation preserved")
print("✓ Test 3: Legacy v5 record migration with fallback passed!")

-- Test 4: Future version rejection (cannot load future version data)
local futureRecord = { version = 99, coins = 500000 }
local loadedFuture, notesFuture = SaveSchema.load(futureRecord, nil, nil)
assert(loadedFuture == nil, "Test 4 Failed: future version must return nil to prevent save corruption")
assert(#notesFuture > 0, "Test 4 Failed: should return notes explaining rejection")
print("✓ Test 4: Future version rejection passed!")

-- Test 5: Corrupted record sanitization (bad types, NaN, negative strength, unnested tables)
local corruptedRecord = {
    version = 7,
    coins = "not_a_number",
    strength = -500,
    foodTier = 9999,
    dumbbellTier = -2,
    nestSlots = "huge",
    penSlots = 9999,
    pets = "invalid_pets_format",
    settings = { music = "loud", sfx = false },
    daily = "corrupted",
}

local loadedCorrupt, notesCorrupt = SaveSchema.load(corruptedRecord, nil, nil)
assert(loadedCorrupt ~= nil, "Test 5 Failed: sanitizer must recover valid table")
assert(loadedCorrupt.coins == 0, "Test 5 Failed: invalid coins sanitized to 0")
assert(loadedCorrupt.strength == Economy.START_STRENGTH, "Test 5 Failed: negative strength clamped to START_STRENGTH")
assert(loadedCorrupt.foodTier == #Economy.Foods, "Test 5 Failed: out-of-range food tier clamped to max")
assert(loadedCorrupt.dumbbellTier == 1, "Test 5 Failed: invalid dumbbell tier clamped to 1")
assert(type(loadedCorrupt.pets) == "table" and #loadedCorrupt.pets == 0, "Test 5 Failed: non-table pets sanitized to empty table")
assert(loadedCorrupt.settings.music == true, "Test 5 Failed: invalid setting type sanitized to default")
assert(loadedCorrupt.settings.sfx == false, "Test 5 Failed: valid bool preserved")
print("✓ Test 5: Corrupted record sanitization passed!")

-- ====================================================================
-- PART 2: EggRules Pure Functions
-- ====================================================================

-- Test 6: EggRules.needle meter range & sweet spot
local nStart = EggRules.needle(0)
local nSweet = EggRules.needle(1.5)
local nLong = EggRules.needle(3.0)
assert(nStart >= 0 and nStart <= 1, "Test 6 Failed: needle(0) must be in [0, 1]")
assert(nSweet >= 0 and nSweet <= 1, "Test 6 Failed: needle(1.5) must be in [0, 1]")
assert(nLong >= 0 and nLong <= 1, "Test 6 Failed: needle(3.0) must be in [0, 1]")
print("✓ Test 6: EggRules.needle meter passed!")

-- Test 7: EggRules.throwLabel format
local label1 = EggRules.throwLabel(0.1, 0.5)
local labelSweet = EggRules.throwLabel(0.85, 1.25)
assert(type(label1) == "string" and #label1 > 0, "Test 7 Failed: throwLabel must return string")
assert(type(labelSweet) == "string" and #labelSweet > 0, "Test 7 Failed: throwLabel must return string")
print("✓ Test 7: EggRules.throwLabel passed!")

-- Test 8: EggRules.income calculation for placed pen pets
local testData = SaveSchema.new()
table.insert(testData.pets, { id = 1, species = "Meadow Bunny", mutation = "Normal", pen = true })
table.insert(testData.pets, { id = 2, species = "Coral Leviathan", mutation = "Golden", pen = true })
table.insert(testData.pets, { id = 3, species = "Slime Drake", mutation = "Normal", pen = false }) -- not in pen!
local totalIncome = EggRules.income(testData)
local expectedBunny = Economy.petIncome({ Species = "Meadow Bunny", Mutation = "Normal" })
local expectedLeviathan = Economy.petIncome({ Species = "Coral Leviathan", Mutation = "Golden" })
assert(totalIncome == (expectedBunny + expectedLeviathan), "Test 8 Failed: income must match sum of pen pets only")
print("✓ Test 8: EggRules.income calculation passed!")

-- Test 9: EggRules.canThrow & startCharge state gating
local rt = EggRules.newRuntime(100)
local canThrowOk, reason = EggRules.canThrow(testData, rt, 100)
assert(canThrowOk == true, "Test 9 Failed: initial state should be able to throw")

local startOk = EggRules.startCharge(testData, rt, 100)
assert(startOk == true, "Test 9 Failed: startCharge should succeed")
assert(rt.chargeStart == 100, "Test 9 Failed: rt.chargeStart should be set")

local rel = EggRules.release(testData, rt, 101.5, 1.5, 0.5, 0.5, false)
assert(rel.ok == true, "Test 9 Failed: release throw should succeed")
assert(rt.lastThrowAt == 101.5, "Test 9 Failed: lastThrowAt should be updated")

local canThrowCooldown = EggRules.canThrow(testData, rt, 102.0)
assert(canThrowCooldown == false, "Test 9 Failed: cannot throw during cooldown")
print("✓ Test 9: EggRules.canThrow and charge state gating passed!")

-- Test 10: EggRules chunk normal, turntable projected coordinates, and facing dot
local normal1 = EggRules.chunkNormal(1, 30)
assert(#normal1 == 3, "Test 10 Failed: chunkNormal must return 3D unit normal")
local normLen = math.sqrt(normal1[1]^2 + normal1[2]^2 + normal1[3]^2)
assert(math.abs(normLen - 1.0) < 0.01, "Test 10 Failed: chunkNormal must be approximately unit length")

local px, py = EggRules.projected(normal1, 0)
assert(type(px) == "number" and type(py) == "number", "Test 10 Failed: projected coordinates must be numbers")

local facing0 = EggRules.facing(normal1, 0)
assert(type(facing0) == "number", "Test 10 Failed: facing dot product must be number")
print("✓ Test 10: EggRules geometry and projection passed!")

-- ====================================================================
-- PART 3: Egg Growth & Weight Balancing (Phase 0 Decision 2)
-- ====================================================================

-- Test 11: Economy EggGrowthTimes & GameConfig parity
assert(Economy.growthDuration("Common") == 30, "Test 11 Failed: Common growth should be 30s")
assert(Economy.growthDuration("Rare") == 120, "Test 11 Failed: Rare growth should be 120s (2m)")
assert(Economy.growthDuration("Mythic") == 1800, "Test 11 Failed: Mythic growth should be 1800s (30m)")
print("✓ Test 11: Growth durations verified!")

-- Test 12: Weight rolls within bounds
local weightCommonMin = Economy.rollEggWeight("Common", 0.0)
local weightCommonMax = Economy.rollEggWeight("Common", 1.0)
assert(weightCommonMin >= 0.8 and weightCommonMin <= 1.6, "Test 12 Failed: Common weight out of bounds")
assert(weightCommonMax >= 0.8 and weightCommonMax <= 1.6, "Test 12 Failed: Common weight out of bounds")

local weightMythic = Economy.rollEggWeight("Mythic", 0.5)
assert(weightMythic >= 50.0 and weightMythic <= 120.0, "Test 12 Failed: Mythic weight out of bounds")
print("✓ Test 12: Egg weight bounds verified!")

-- Test 13: Weight-to-scale and income multipliers
local scaleNorm = Economy.petVisualScale(1.0, "Common")
local scaleHeavy = Economy.petVisualScale(1.6, "Common")
assert(scaleNorm >= 0.75 and scaleNorm <= 1.60, "Test 13 Failed: normal pet scale in bounds")
assert(scaleHeavy > scaleNorm, "Test 13 Failed: heavier egg must produce visibly larger pet")

local incNorm = Economy.weightIncomeMultiplier(1.0, "Common")
local incHeavy = Economy.weightIncomeMultiplier(1.6, "Common")
assert(incNorm == 1.0, "Test 13 Failed: base weight gives 1.0 income multiplier")
assert(incHeavy > 1.0 and incHeavy <= 1.35, "Test 13 Failed: heavy egg gives subtle income bonus")
print("✓ Test 13: Weight scale and income multiplier verified!")

print("--- ALL 13 V3 SAVESCHEMA, EGGRULES & BALANCING UNIT TESTS PASSED! ---")
return true
