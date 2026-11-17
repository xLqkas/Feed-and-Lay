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

-- Centralized Launch Zone Bounding Box
GameConfig.LaunchZone = {
    MinZ = -24,
    MaxZ = 4,
    MinX = -75,
    MaxX = -35,
}

function GameConfig.IsInLaunchZone(pos)
    if not pos then return false end
    return (pos.Z >= GameConfig.LaunchZone.MinZ and pos.Z <= GameConfig.LaunchZone.MaxZ
        and pos.X >= GameConfig.LaunchZone.MinX and pos.X <= GameConfig.LaunchZone.MaxX)
end

-- Centralized Throw Power Multiplier (100% agreement between Client & Server)
function GameConfig.ThrowRatio(duration)
    duration = math.clamp(tonumber(duration) or 0.1, 0.05, 3.0)
    if duration <= 0.25 then
        return 0.50, false, "<| x0.5 TAP", 1
    elseif duration <= 0.65 then
        return 0.70, false, "<| x0.7 SPEED", 2
    elseif duration <= 1.05 then
        return 0.85, false, "<| x0.85 SPEED", 3
    elseif duration < 1.45 then
        return 1.00, false, "<| x1.0 FULL", 4
    elseif duration <= 1.90 then
        return 1.25, true, "<| x1.25 SWEET SPOT! 🔥", 5
    else
        return 0.90, false, "<| x0.9 OVERCHARGE", 6
    end
end

-- Balanced Rarity weights shifted smoothly by Luck (never collapses into 100% Mythic)
function GameConfig.RollRarity(luckMult)
    luckMult = math.max(1.0, tonumber(luckMult) or 1.0)
    local wCommon = 550
    local wRare = 250 * math.min(luckMult, 5)
    local wEpic = 120 * math.sqrt(luckMult) * 1.5
    local wLegendary = 50 * math.sqrt(luckMult) * 2.0
    local wMythic = 10 * math.sqrt(luckMult) * 3.0

    local totalWeight = wCommon + wRare + wEpic + wLegendary + wMythic
    local roll = math.random() * totalWeight

    if roll <= wMythic then
        return "Mythic", 15.0
    elseif roll <= (wMythic + wLegendary) then
        return "Legendary", 6.0
    elseif roll <= (wMythic + wLegendary + wEpic) then
        return "Epic", 3.0
    elseif roll <= (wMythic + wLegendary + wEpic + wRare) then
        return "Rare", 1.8
    else
        return "Common", 1.0
    end
end

-- Centralized Mutation definitions and Roll
GameConfig.Mutations = {
    Normal = { Name = "Normal", Multiplier = 1.0, Color = Color3.fromRGB(245, 245, 250), StrokeColor = Color3.fromRGB(80, 180, 120), Material = Enum.Material.SmoothPlastic },
    Shiny = { Name = "Shiny", Multiplier = 2.5, Color = Color3.fromRGB(150, 235, 255), StrokeColor = Color3.fromRGB(120, 220, 255), Material = Enum.Material.Ice },
    Golden = { Name = "Golden", Multiplier = 5.0, Color = Color3.fromRGB(255, 215, 0), StrokeColor = Color3.fromRGB(255, 215, 0), Material = Enum.Material.Glass },
    Rainbow = { Name = "Rainbow", Multiplier = 10.0, Color = Color3.fromRGB(255, 90, 240), StrokeColor = Color3.fromRGB(255, 90, 240), Material = Enum.Material.Neon },
}

function GameConfig.RollMutation(shinyChance)
    shinyChance = shinyChance or 0.001
    local roll = math.random()
    if roll < (shinyChance * 0.1) then
        return "Rainbow", GameConfig.Mutations.Rainbow.Multiplier
    elseif roll < (shinyChance * 0.3) then
        return "Golden", GameConfig.Mutations.Golden.Multiplier
    elseif roll < shinyChance then
        return "Shiny", GameConfig.Mutations.Shiny.Multiplier
    else
        return "Normal", GameConfig.Mutations.Normal.Multiplier
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

-- Progression & Economy Constants
GameConfig.MaxGardenPlots = 6
GameConfig.DefaultMaxSlots = 4
GameConfig.MaxSlotsCap = 16
GameConfig.SlotUpgradeCost = function(currentSlots)
    return (currentSlots or 4) * 500
end
GameConfig.ThrowCooldown = 1.8
GameConfig.TrainCooldown = 1.15

return GameConfig
