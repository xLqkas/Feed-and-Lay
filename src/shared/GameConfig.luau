local GameConfig = {}

-- Food Tiers (Strength = Distance, Food = Luck)
GameConfig.Foods = {
    [1] = { Tier = 1, Name = "Red Apple", Cost = 0, Luck = 1.0, ShinyChance = 0.001, Color = Color3.fromRGB(230, 40, 40) },
    [2] = { Tier = 2, Name = "Carrot Cake", Cost = 150, Luck = 1.5, ShinyChance = 0.005, Color = Color3.fromRGB(240, 140, 30) },
    [3] = { Tier = 3, Name = "Honey Glazed Ribs", Cost = 600, Luck = 2.5, ShinyChance = 0.015, Color = Color3.fromRGB(160, 80, 30) },
    [4] = { Tier = 4, Name = "Golden Star-Berry", Cost = 2500, Luck = 5.0, ShinyChance = 0.035, Color = Color3.fromRGB(255, 215, 0) },
    [5] = { Tier = 5, Name = "Flame-Grilled Steak", Cost = 10000, Luck = 10.0, ShinyChance = 0.075, Color = Color3.fromRGB(255, 60, 20) },
    [6] = { Tier = 6, Name = "Rainbow Candy", Cost = 50000, Luck = 25.0, ShinyChance = 0.150, Color = Color3.fromRGB(220, 80, 240) },
    [7] = { Tier = 7, Name = "Abyssal Caviar", Cost = 250000, Luck = 50.0, ShinyChance = 0.250, Color = Color3.fromRGB(40, 160, 255) },
    [8] = { Tier = 8, Name = "Cosmic Ambrosia", Cost = 1000000, Luck = 100.0, ShinyChance = 0.350, Color = Color3.fromRGB(180, 100, 255) },
}

-- Biome Zones along the throw canyon
GameConfig.Zones = {
    [1] = {
        Id = 1,
        Name = "Dewdrop Meadow",
        MinDist = 0,
        MaxDist = 300,
        AnimalName = "Meadow Bunny",
        AnimalColor = Color3.fromRGB(140, 210, 120),
        EggName = "Muddy Meadow Egg",
        BaseIncome = 2,
        GroundColor = Color3.fromRGB(105, 175, 80),
    },
    [2] = {
        Id = 2,
        Name = "Toxic Slime Marsh",
        MinDist = 300,
        MaxDist = 1000,
        AnimalName = "Slime Drake",
        AnimalColor = Color3.fromRGB(90, 220, 140),
        EggName = "Toxic Slime Egg",
        BaseIncome = 12,
        GroundColor = Color3.fromRGB(60, 120, 70),
    },
    [3] = {
        Id = 3,
        Name = "Cinder Volcano",
        MinDist = 1000,
        MaxDist = 2500,
        AnimalName = "Ember Hound",
        AnimalColor = Color3.fromRGB(255, 80, 40),
        EggName = "Obsidian Magma Egg",
        BaseIncome = 75,
        GroundColor = Color3.fromRGB(70, 35, 30),
    },
    [4] = {
        Id = 4,
        Name = "Sunken Coral Reef",
        MinDist = 2500,
        MaxDist = 5000,
        AnimalName = "Coral Leviathan",
        AnimalColor = Color3.fromRGB(50, 180, 240),
        EggName = "Barnacle Pearl Egg",
        BaseIncome = 450,
        GroundColor = Color3.fromRGB(40, 90, 130),
    },
    [5] = {
        Id = 5,
        Name = "Celestial Galaxy",
        MinDist = 5000,
        MaxDist = 999999,
        AnimalName = "Galaxy Titan",
        AnimalColor = Color3.fromRGB(160, 90, 255),
        EggName = "Starlight Crystal Egg",
        BaseIncome = 3000,
        GroundColor = Color3.fromRGB(30, 20, 50),
    },
}

-- Rarity weights based on Luck
function GameConfig.RollRarity(luckMult)
    luckMult = luckMult or 1.0
    local roll = math.random() / luckMult
    if roll < 0.01 then
        return "Mythic", 15
    elseif roll < 0.06 then
        return "Legendary", 6
    elseif roll < 0.20 then
        return "Epic", 3
    elseif roll < 0.50 then
        return "Rare", 1.8
    else
        return "Common", 1.0
    end
end

-- Roll Mutation based on Food ShinyChance
function GameConfig.RollMutation(shinyChance)
    shinyChance = shinyChance or 0.001
    local roll = math.random()
    if roll < (shinyChance * 0.1) then
        return "Rainbow", 10.0
    elseif roll < (shinyChance * 0.3) then
        return "Golden", 5.0
    elseif roll < shinyChance then
        return "Shiny", 2.5
    else
        return "Normal", 1.0
    end
end

-- Get Zone by Distance
function GameConfig.GetZoneByDistance(dist)
    for i = #GameConfig.Zones, 1, -1 do
        local z = GameConfig.Zones[i]
        if dist >= z.MinDist then
            return z
        end
    end
    return GameConfig.Zones[1]
end

return GameConfig
