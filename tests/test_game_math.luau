-- Unit Tests for Egg Sanctuary Game Math & Economy
local GameConfig = require(game:GetService("ReplicatedStorage").Modules.GameConfig)

print("--- Running Egg Sanctuary Math & Economy Tests ---")

-- 1. Zone Distance Boundaries
assert(GameConfig.GetZoneByDistance(0).Name == "Dewdrop Meadow", "Test 1 Failed: Dist 0 should be Dewdrop Meadow")
assert(GameConfig.GetZoneByDistance(150).Name == "Dewdrop Meadow", "Test 2 Failed: Dist 150 should be Dewdrop Meadow")
assert(GameConfig.GetZoneByDistance(300).Name == "Toxic Slime Marsh", "Test 3 Failed: Dist 300 should be Toxic Slime Marsh")
assert(GameConfig.GetZoneByDistance(999).Name == "Toxic Slime Marsh", "Test 4 Failed: Dist 999 should be Toxic Slime Marsh")
assert(GameConfig.GetZoneByDistance(1000).Name == "Cinder Volcano", "Test 5 Failed: Dist 1000 should be Cinder Volcano")
assert(GameConfig.GetZoneByDistance(2500).Name == "Sunken Coral Reef", "Test 6 Failed: Dist 2500 should be Sunken Coral Reef")
assert(GameConfig.GetZoneByDistance(5000).Name == "Celestial Galaxy", "Test 7 Failed: Dist 5000 should be Celestial Galaxy")
print("✓ Biome distance boundary tests passed!")

-- 2. Throw Multipliers & Sweet Spot
local rTap, isSweetTap = GameConfig.ThrowRatio(0.1)
assert(rTap == 0.50 and not isSweetTap, "Test 8 Failed: 0.1s should be 0.50 tap")

local rSpeed = GameConfig.ThrowRatio(0.6)
assert(rSpeed == 0.70, "Test 9 Failed: 0.6s should be 0.70 speed")

local rSweet, isSweet = GameConfig.ThrowRatio(1.6)
assert(rSweet == 1.25 and isSweet, "Test 10 Failed: 1.6s should be 1.25 sweet spot")

local rOver, isSweetOver = GameConfig.ThrowRatio(2.5)
assert(rOver == 0.90 and not isSweetOver, "Test 11 Failed: 2.5s should be 0.90 overcharge")
print("✓ Throw ratio and sweet spot tests passed!")

-- 3. Launch Zone Bounds
assert(GameConfig.IsInLaunchZone(Vector3.new(-55, -75, -14)) == true, "Test 12 Failed: Yellow Pad should be in Launch Zone")
assert(GameConfig.IsInLaunchZone(Vector3.new(0, 0, 0)) == false, "Test 13 Failed: Origin should NOT be in Launch Zone")
assert(GameConfig.IsInLaunchZone(Vector3.new(-155, -75, -36)) == false, "Test 14 Failed: Base 1 should NOT be in Launch Zone")
print("✓ Launch zone validation tests passed!")

-- 4. Rarity Distribution & Anti-Inflation Simulation (10,000 rolls per tier)
local countTier1 = { Common = 0, Rare = 0, Epic = 0, Legendary = 0, Mythic = 0 }
for i = 1, 10000 do
    local r = GameConfig.RollRarity(1.0)
    countTier1[r] = (countTier1[r] or 0) + 1
end

assert(countTier1.Common > countTier1.Rare, "Tier 1 Common must be most frequent")
assert(countTier1.Mythic < 500, "Tier 1 Mythic must be rare (< 5%)")

local countTier8 = { Common = 0, Rare = 0, Epic = 0, Legendary = 0, Mythic = 0 }
for i = 1, 10000 do
    local r = GameConfig.RollRarity(100.0)
    countTier8[r] = (countTier8[r] or 0) + 1
end

-- With Luck 100, Mythic should be rewarding (~10-20%) but NOT 100%!
assert(countTier8.Mythic > countTier1.Mythic, "Tier 8 must yield significantly more Mythics than Tier 1")
assert(countTier8.Mythic < 3000, "Tier 8 Mythic must NOT collapse economy (must be < 30%)")
assert(countTier8.Legendary > 1500, "Tier 8 Legendary should be frequent")

print(string.format("✓ Rarity curves verified! Tier 1 Mythic: %.1f%%, Tier 8 Mythic: %.1f%% (Balanced economy preserved!)",
    (countTier1.Mythic / 100), (countTier8.Mythic / 100)))

print("--- ALL 14 EGG SANCTUARY UNIT TESTS PASSED! ---")
return true
