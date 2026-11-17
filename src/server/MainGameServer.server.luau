local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local SoundHelper = require(Modules:WaitForChild("SoundHelper"))

-- Remotes
local TrainStrengthRemote = Remotes:WaitForChild("TrainStrength")
local ThrowFoodRemote = Remotes:WaitForChild("ThrowFood")
local CleanEggRemote = Remotes:WaitForChild("CleanEgg")
local HatchEggRemote = Remotes:WaitForChild("HatchEgg")
local UpgradeFoodRemote = Remotes:WaitForChild("UpgradeFood")
local ExpandSanctuaryRemote = Remotes:WaitForChild("ExpandSanctuary")
local ManagePetRemote = Remotes:WaitForChild("ManagePet")
local GetSanctuaryStateRemote = Remotes:WaitForChild("GetSanctuaryState")

-- Created in code because the Remotes folder only lives in the local place file.
local StartChargeRemote = Remotes:FindFirstChild("StartCharge")
if not StartChargeRemote then
    StartChargeRemote = Instance.new("RemoteEvent")
    StartChargeRemote.Name = "StartCharge"
    StartChargeRemote.Parent = Remotes
end

local TRAIN_COOLDOWN = 0.5

-- DataStore Setup
local DATASTORE_KEY = "EggSanctuary_SaveData_v5"
local PlayerDataStore = nil
local isDataStoreActive = false

pcall(function()
    PlayerDataStore = DataStoreService:GetDataStore(DATASTORE_KEY)
    isDataStoreActive = true
end)

local PlayerData = {}
local AssignedPlots = {} -- [userId] = 1 or 2
local SpawnedPetModels = {} -- [userId] = { [petId] = model }

local MAX_PLOTS = 6

local PLOT_X_OFFSETS = {
	[1] = -150,
	[2] = -90,
	[3] = -30,
	[4] = 30,
	[5] = 90,
	[6] = 150,
}

local function getPlayerPlot(userId)
    local plotId = AssignedPlots[userId] or 1
    local bases = Workspace:FindFirstChild("EggSanctuaryMap") and Workspace.EggSanctuaryMap:FindFirstChild("MultiplayerBases")
    if bases then
        return bases:FindFirstChild("PlayerBase_" .. plotId), plotId
    end
    return nil, plotId
end

local function calculateTotalIncome(userId)
    local data = PlayerData[userId]
    if not data then return 0 end
    local total = 0
    for _, pet in ipairs(data.GardenPets or {}) do
        total = total + (pet.Income or 0)
    end
    return total
end

local function updateSanctuaryWorldVisuals(player)
    local data = PlayerData[player.UserId]
    if not data then return end

    local plot, plotId = getPlayerPlot(player.UserId)
    if not plot then return end

    local totalIncome = calculateTotalIncome(player.UserId)

    -- Update Base Sign (Matching Image 3: "chinorey502's Base $2.3T/s")
    local signPart = plot:FindFirstChild("BaseSign")
    local sg = signPart and signPart:FindFirstChildOfClass("SurfaceGui")
    local titleLbl = sg and sg:FindFirstChildOfClass("TextLabel")
    if titleLbl then
        titleLbl.Text = player.DisplayName:upper() .. "'S BASE (+" .. totalIncome .. " $/s)"
    end

    -- Update ActiveEgg visual at EggCleaner
    local cleaner = plot:FindFirstChild("EggCleaner")
    if cleaner and cleaner:FindFirstChild("ActiveEgg") then
        local eggPart = cleaner.ActiveEgg
        if data.CurrentEgg then
            eggPart.Transparency = 0
            local progress = (data.CurrentEgg.Cleanliness or 0) / 100
            eggPart.Color = Color3.fromRGB(
                math.floor(115 + (245 - 115) * progress),
                math.floor(85 + (245 - 85) * progress),
                math.floor(55 + (255 - 55) * progress)
            )
            eggPart.Material = (data.CurrentEgg.Cleanliness >= 100) and Enum.Material.Neon or Enum.Material.Slate
        else
            eggPart.Transparency = 1
        end
    end
end

-- Spawn pet roaming freely inside the open fenced yard (NO NESTS!)
local function spawnPetInGarden(userId, pet)
    SpawnedPetModels[userId] = SpawnedPetModels[userId] or {}

    local plot, plotId = getPlayerPlot(userId)
    if not plot then return end

    local petsFolder = plot:FindFirstChild("PetsInGarden") or Instance.new("Folder", plot)
    petsFolder.Name = "PetsInGarden"

    local yard = plot:FindFirstChild("GardenYard")
    local floor = yard and yard:FindFirstChild("YardFloor")
    local centerPos = floor and floor.Position or Vector3.new(-100, 2.1, -10)
    local spawnX = centerPos.X + (pet.RelX or math.random(-14, 14))
    local spawnZ = centerPos.Z + (pet.RelZ or math.random(-14, 14))

    local template = ReplicatedStorage:FindFirstChild("PetTemplates") and (ReplicatedStorage.PetTemplates:FindFirstChild(pet.Name) or ReplicatedStorage.PetTemplates:FindFirstChild("Meadow Bunny"))
    local petModel
    if template then
        petModel = template:Clone()
    else
        petModel = Instance.new("Model")
        local b = Instance.new("Part", petModel)
        b.Name = "Body"
        b.Shape = Enum.PartType.Ball
        b.Size = Vector3.new(3, 3, 3)
        petModel.PrimaryPart = b
    end
    petModel.Name = "Pet_" .. tostring(pet.PetId)

    local primary = petModel.PrimaryPart or petModel:FindFirstChild("Body") or petModel:FindFirstChild("Chest") or petModel:FindFirstChildWhichIsA("BasePart")
    petModel.PrimaryPart = primary

    for _, p in ipairs(petModel:GetDescendants()) do
        if p:IsA("BasePart") then
            p.Anchored = true
            p.CanCollide = false
            p.CastShadow = true
        end
    end

    if pet.Mutation == "Rainbow" then
        for _, p in ipairs(petModel:GetDescendants()) do
            if p:IsA("BasePart") and not p.Name:find("Eye") then
                p.Color = Color3.fromRGB(255, 90, 240)
                p.Material = Enum.Material.Neon
            end
        end
    elseif pet.Mutation == "Golden" then
        for _, p in ipairs(petModel:GetDescendants()) do
            if p:IsA("BasePart") and not p.Name:find("Eye") then
                p.Color = Color3.fromRGB(255, 215, 0)
                p.Material = Enum.Material.Glass
            end
        end
    elseif pet.Mutation == "Shiny" then
        for _, p in ipairs(petModel:GetDescendants()) do
            if p:IsA("BasePart") and not p.Name:find("Eye") then
                p.Color = Color3.fromRGB(150, 235, 255)
                p.Material = Enum.Material.Ice
            end
        end
    end

    local randomYaw = math.random() * math.pi * 2
    local spawnY = centerPos.Y + 2.5
    local baseCFrame = CFrame.new(spawnX, spawnY, spawnZ) * CFrame.Angles(0, randomYaw, 0)
    petModel:PivotTo(baseCFrame)
    petModel.Parent = petsFolder

    if primary then
        local bb = Instance.new("BillboardGui", primary)
        bb.Name = "PetTag"
        bb.Size = UDim2.new(0, 160, 0, 42)
        bb.StudsOffset = Vector3.new(0, 3.4, 0)
        bb.AlwaysOnTop = false
        bb.MaxDistance = 55

        local bg = Instance.new("Frame", bb)
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(18, 24, 38)
        bg.BackgroundTransparency = 0.2
        local bgCorner = Instance.new("UICorner", bg)
        bgCorner.CornerRadius = UDim.new(0, 8)
        local bgStroke = Instance.new("UIStroke", bg)
        bgStroke.Thickness = 1.5
        if pet.Mutation == "Golden" then
            bgStroke.Color = Color3.fromRGB(255, 215, 0)
        elseif pet.Mutation == "Rainbow" then
            bgStroke.Color = Color3.fromRGB(255, 90, 240)
        elseif pet.Mutation == "Shiny" then
            bgStroke.Color = Color3.fromRGB(120, 220, 255)
        else
            bgStroke.Color = Color3.fromRGB(80, 180, 120)
        end

        local titleLbl = Instance.new("TextLabel", bg)
        titleLbl.Size = UDim2.new(1, 0, 0.52, 0)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBlack
        titleLbl.TextSize = 12
        titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        local prefix = (pet.Mutation ~= "Normal") and (pet.Mutation .. " ") or ""
        titleLbl.Text = prefix .. pet.Name .. " (" .. (pet.Rarity or "Common") .. ")"

        local subLbl = Instance.new("TextLabel", bg)
        subLbl.Size = UDim2.new(1, 0, 0.48, 0)
        subLbl.Position = UDim2.new(0, 0, 0.52, 0)
        subLbl.BackgroundTransparency = 1
        subLbl.Font = Enum.Font.GothamBold
        subLbl.TextSize = 11
        subLbl.TextColor3 = (pet.Mutation == "Golden") and Color3.fromRGB(255, 225, 60) or Color3.fromRGB(130, 255, 160)
        subLbl.Text = "+" .. pet.Income .. " $/sec"
    end

    task.spawn(function()
        local t = math.random() * 10
        while petModel and petModel.Parent do
            t = t + 0.08
            local bob = math.sin(t) * 0.35
            local roamX = math.sin(t * 0.25) * 1.2
            local roamZ = math.cos(t * 0.25) * 1.2
            petModel:PivotTo(baseCFrame * CFrame.new(roamX, bob, roamZ) * CFrame.Angles(0, math.sin(t * 0.4) * 0.25, 0))
            task.wait(0.04)
        end
    end)

    SpawnedPetModels[userId][pet.PetId] = petModel
end
local function setupPlayer(player)
    local used = {}
    for _, pid in pairs(AssignedPlots) do used[pid] = true end
    local plotId = nil
    for i = 1, MAX_PLOTS do
        if not used[i] then
            plotId = i
            break
        end
    end
    if not plotId then
        plotId = (player.UserId % MAX_PLOTS) + 1
    end
    AssignedPlots[player.UserId] = plotId

    local defaultData = {
        Strength = 150,
        BioEssence = 50,
        FoodTier = 1,
        EggsCleaned = 0,
        MaxSlots = 4,
        GardenPets = {}, -- list of pets placed in the garden
        CurrentEgg = nil,
        LastThrowTime = 0,
        PlotId = plotId,
    }

    -- Robust DataStore Load
    if isDataStoreActive and PlayerDataStore then
        local key = "Player_" .. player.UserId
        local success, saved = pcall(function()
            return PlayerDataStore:GetAsync(key)
        end)

        -- Player left while we were loading: free the plot and stop.
        if not player.Parent then
            AssignedPlots[player.UserId] = nil
            return
        end

        if not success then
            warn("[EggSanctuary] Load failed for " .. player.UserId .. ": " .. tostring(saved))
            -- Never save over the real data with starter data.
            defaultData.LoadFailed = true
            if not RunService:IsStudio() then
                AssignedPlots[player.UserId] = nil
                player:Kick("Could not load your save. Please rejoin in a moment.")
                return
            end
        elseif saved and type(saved) == "table" then
            defaultData.Strength = saved.Strength or defaultData.Strength
            defaultData.BioEssence = saved.BioEssence or defaultData.BioEssence
            defaultData.FoodTier = saved.FoodTier or defaultData.FoodTier
            defaultData.EggsCleaned = saved.EggsCleaned or defaultData.EggsCleaned
            defaultData.MaxSlots = saved.MaxSlots or defaultData.MaxSlots
            defaultData.GardenPets = saved.GardenPets or defaultData.GardenPets
        end
    end

    PlayerData[player.UserId] = defaultData

    if #defaultData.GardenPets == 0 then
        table.insert(defaultData.GardenPets, {
            PetId = "starter_bunny_" .. player.UserId,
            Name = "Meadow Bunny",
            Rarity = "Common",
            Mutation = "Normal",
            Income = 3,
            RelX = 0,
            RelZ = 0,
        })
    end

    local plotObj = getPlayerPlot(player.UserId)
    if plotObj then
        local pFolder = plotObj:FindFirstChild("PetsInGarden")
        if pFolder then
            pFolder:ClearAllChildren()
        end
    end

    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local strengthVal = Instance.new("NumberValue")
    strengthVal.Name = "Strength"
    strengthVal.Value = defaultData.Strength
    strengthVal.Parent = leaderstats

    local essenceVal = Instance.new("NumberValue")
    essenceVal.Name = "BioEssence"
    essenceVal.Value = defaultData.BioEssence
    essenceVal.Parent = leaderstats

    local foodTierVal = Instance.new("IntValue")
    foodTierVal.Name = "FoodTier"
    foodTierVal.Value = defaultData.FoodTier
    foodTierVal.Parent = leaderstats

    local eggsVal = Instance.new("IntValue")
    eggsVal.Name = "EggsCleaned"
    eggsVal.Value = defaultData.EggsCleaned
    eggsVal.Parent = leaderstats

    local plotVal = Instance.new("IntValue")
    plotVal.Name = "PlotId"
    plotVal.Value = plotId
    plotVal.Parent = leaderstats

    -- Spawn placed garden pets
    for _, pet in ipairs(defaultData.GardenPets) do
        spawnPetInGarden(player.UserId, pet)
    end

    updateSanctuaryWorldVisuals(player)
end

local function savePlayerData(player)
    local data = PlayerData[player.UserId]
    if not data or data.LoadFailed then return end

    if isDataStoreActive and PlayerDataStore then
        local key = "Player_" .. player.UserId
        local ok, err = pcall(function()
            PlayerDataStore:SetAsync(key, {
                Strength = data.Strength,
                BioEssence = data.BioEssence,
                FoodTier = data.FoodTier,
                EggsCleaned = data.EggsCleaned,
                MaxSlots = data.MaxSlots,
                GardenPets = data.GardenPets,
            })
        end)
        if not ok then
            warn("[EggSanctuary] Save failed for " .. player.UserId .. ": " .. tostring(err))
        end
    end
end

Players.PlayerAdded:Connect(setupPlayer)
for _, p in ipairs(Players:GetPlayers()) do
    setupPlayer(p)
end

Players.PlayerRemoving:Connect(function(player)
    savePlayerData(player)

    if SpawnedPetModels[player.UserId] then
        for _, model in pairs(SpawnedPetModels[player.UserId]) do
            if model and model.Parent then model:Destroy() end
        end
        SpawnedPetModels[player.UserId] = nil
    end

    AssignedPlots[player.UserId] = nil
    PlayerData[player.UserId] = nil
end)

-- Save everyone when Roblox shuts the server down (updates, last player leaving).
game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        savePlayerData(player)
    end
end)

-- Autosave loop every 45s
task.spawn(function()
    while true do
        task.wait(45)
        for _, player in ipairs(Players:GetPlayers()) do
            savePlayerData(player)
        end
    end
end)

-----------------------------------------------------
-- 1. GYM: TRAIN STRENGTH
-----------------------------------------------------
TrainStrengthRemote.OnServerInvoke = function(player)
    local data = PlayerData[player.UserId]
    if not data then return { Success = false } end

    local now = os.clock()
    if data.LastTrainTime and (now - data.LastTrainTime) < TRAIN_COOLDOWN then
        return { Success = false, Message = "Catch your breath!" }
    end
    data.LastTrainTime = now

    data.Strength = data.Strength + 10
    player.leaderstats.Strength.Value = data.Strength

    SoundHelper.Play("GymWorkout", player.Character and player.Character:FindFirstChild("HumanoidRootPart"))
    return {
        Success = true,
        NewStrength = data.Strength,
        Gain = 10,
    }
end

-----------------------------------------------------
-- 2. KITCHEN: UPGRADE FOOD
-----------------------------------------------------
UpgradeFoodRemote.OnServerInvoke = function(player)
    local data = PlayerData[player.UserId]
    if not data then return { Success = false, Message = "No data" } end

    local nextTier = data.FoodTier + 1
    local nextFood = GameConfig.Foods[nextTier]
    if not nextFood then
        return { Success = false, Message = "Already at Max Food Tier!" }
    end

    if data.BioEssence >= nextFood.Cost then
        data.BioEssence = data.BioEssence - nextFood.Cost
        data.FoodTier = nextTier
        player.leaderstats.BioEssence.Value = data.BioEssence
        player.leaderstats.FoodTier.Value = data.FoodTier
        SoundHelper.Play("PristineChime", player.Character and player.Character:FindFirstChild("HumanoidRootPart"))
        return { Success = true, Food = nextFood, NewEssence = data.BioEssence }
    else
        return { Success = false, Message = "Need " .. nextFood.Cost .. " Bio-Essence for " .. nextFood.Name .. "!" }
    end
end

-----------------------------------------------------
-- 3. THROW FOOD: GENEROUS LAUNCH ZONE VALIDATION
-----------------------------------------------------
-- The server times the charge itself, so a client cannot claim a perfect hold.
StartChargeRemote.OnServerEvent:Connect(function(player)
    local data = PlayerData[player.UserId]
    if data then
        data.ChargeStart = os.clock()
    end
end)

ThrowFoodRemote.OnServerInvoke = function(player)
    local data = PlayerData[player.UserId]
    if not data then return { Success = false, Message = "No data" } end

    if data.CurrentEgg then
        return { Success = false, Message = "Clean the egg in your Egg Cleaner first!" }
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return { Success = false, Message = "Character not found!" }
    end

    -- Generous Launch Zone check: anywhere along front launch zone (Z between -5 and 30, and |X| <= 90)
    local pos = root.Position
    local inLaunchZone = (pos.Z >= -24 and pos.Z <= 4 and pos.X >= -75 and pos.X <= -35)
    if not inLaunchZone then
        return { Success = false, Message = "Walk forward to the Launch Pad to throw!" }
    end

    local now = os.clock()
    if data.LastThrowTime and (now - data.LastThrowTime) < 1.8 then
        return { Success = false, Message = "Throw is on cooldown! Wait a moment." }
    end
    data.LastThrowTime = now

    -- No StartCharge seen: count it as a tap.
    local duration = math.clamp(data.ChargeStart and (now - data.ChargeStart) or 0.1, 0.05, 3.0)
    data.ChargeStart = nil
    local ratio = 0.50
    local isSweetSpot = false

    if duration <= 0.25 then
        ratio = 0.50
    elseif duration < 1.45 then
        local t = (duration - 0.25) / (1.45 - 0.25)
        ratio = 0.50 + (t * 0.50)
    elseif duration <= 1.90 then
        ratio = 1.25
        isSweetSpot = true
    else
        ratio = 0.90
    end

    local totalDist = math.floor(data.Strength * ratio)
    local zone = GameConfig.GetZoneByDistance(totalDist)
    local food = GameConfig.Foods[data.FoodTier] or GameConfig.Foods[1]

    local rarity, rarityMult = GameConfig.RollRarity(food.Luck)
    local mutation, mutationMult = GameConfig.RollMutation(food.ShinyChance)
    local petIncome = math.floor(zone.BaseIncome * rarityMult * mutationMult)

    data.CurrentEgg = {
        ZoneName = zone.Name,
        EggName = zone.EggName,
        AnimalName = zone.AnimalName,
        Rarity = rarity,
        Mutation = mutation,
        Cleanliness = 0,
        MaxClean = 100,
        PetIncome = petIncome,
    }

    local plot, plotId = getPlayerPlot(player.UserId)
    updateSanctuaryWorldVisuals(player)
    SoundHelper.Play("ThrowWhoosh")

    return {
        Success = true,
        Distance = totalDist,
        Zone = zone,
        Food = food,
        Rarity = rarity,
        Mutation = mutation,
        IsSweetSpot = isSweetSpot,
        Ratio = ratio,
        EggInfo = data.CurrentEgg,
        PlotX = PLOT_X_OFFSETS[plotId] or pos.X
    }
end

-----------------------------------------------------
-- 4. EGG CLEANER: BRUSH EGG OURSELVES
-----------------------------------------------------
CleanEggRemote.OnServerInvoke = function(player)
    local data = PlayerData[player.UserId]
    if not data or not data.CurrentEgg then
        return { Success = false, Message = "No egg in cleaner! Feed the monster down the tunnel first." }
    end

    local egg = data.CurrentEgg
    egg.Cleanliness = math.min(100, egg.Cleanliness + 25)

    updateSanctuaryWorldVisuals(player)

    if egg.Cleanliness >= 100 then
        SoundHelper.Play("PristineChime")
    else
        SoundHelper.Play("WaterSpray")
    end

    return {
        Success = true,
        Cleanliness = egg.Cleanliness,
        IsComplete = (egg.Cleanliness >= 100),
        Egg = egg,
    }
end

-----------------------------------------------------
-- 5. PUT EGG IN GARDEN TO GROW & HATCH (NO NESTS!)
-----------------------------------------------------
HatchEggRemote.OnServerInvoke = function(player)
    local data = PlayerData[player.UserId]
    if not data or not data.CurrentEgg then
        return { Success = false, Message = "No egg to place in garden!" }
    end

    local egg = data.CurrentEgg
    if egg.Cleanliness < 100 then
        return { Success = false, Message = "Egg is still dirty! Brush it clean first." }
    end

    data.CurrentEgg = nil
    data.EggsCleaned = data.EggsCleaned + 1
    player.leaderstats.EggsCleaned.Value = data.EggsCleaned
    SoundHelper.Play("HatchFanfare")

    local newPet = {
        PetId = HttpService:GenerateGUID(false),
        Name = egg.AnimalName,
        Rarity = egg.Rarity,
        Mutation = egg.Mutation,
        Income = egg.PetIncome,
        RelX = math.random(-15, 15),
        RelZ = math.random(-15, 15),
    }

    table.insert(data.GardenPets, newPet)
    spawnPetInGarden(player.UserId, newPet)
    updateSanctuaryWorldVisuals(player)
    savePlayerData(player) -- Save immediately on placement!

    return {
        Success = true,
        Message = "Growing a " .. egg.Mutation .. " " .. egg.Rarity .. " " .. egg.AnimalName .. " in your Garden!",
        Pet = newPet,
        Income = egg.PetIncome,
        TotalIncome = calculateTotalIncome(player.UserId)
    }
end

-----------------------------------------------------
-- 6. GET SANCTUARY STATE & SAVE QUERY
-----------------------------------------------------
GetSanctuaryStateRemote.OnServerInvoke = function(player)
    local data = PlayerData[player.UserId]
    if not data then return { GardenPets = {}, MaxSlots = 4, TotalIncome = 0, HasEgg = false } end
    return {
        GardenPets = data.GardenPets or {},
        MaxSlots = data.MaxSlots or 4,
        TotalIncome = calculateTotalIncome(player.UserId),
        BioEssence = data.BioEssence,
        FoodTier = data.FoodTier,
        HasEgg = (data.CurrentEgg ~= nil),
        EggCleanliness = data.CurrentEgg and data.CurrentEgg.Cleanliness or 0,
        PlotId = AssignedPlots[player.UserId] or 1
    }
end

-----------------------------------------------------
-- 7. PASSIVE INCOME TICK (ALL PETS IN GARDEN EARN!)
-----------------------------------------------------
task.spawn(function()
    while true do
        task.wait(2)
        for _, player in ipairs(Players:GetPlayers()) do
            local data = PlayerData[player.UserId]
            if data then
                local income = calculateTotalIncome(player.UserId)
                if income > 0 then
                    data.BioEssence = data.BioEssence + income
                    player.leaderstats.BioEssence.Value = data.BioEssence
                end
            end
        end
    end
end)

-- Bind in-world ProximityPrompts for all plots
local function bindAllPrompts()
    local bases = Workspace:FindFirstChild("EggSanctuaryMap") and Workspace.EggSanctuaryMap:FindFirstChild("MultiplayerBases")
    if not bases then return end

    for _, plot in ipairs(bases:GetChildren()) do
        local cleaner = plot:FindFirstChild("EggCleaner")
        local basin = cleaner and cleaner:FindFirstChild("WashBasin")
        local cleanPrompt = basin and basin:FindFirstChildOfClass("ProximityPrompt")

        local chef = plot:FindFirstChild("ChefStall")
        local counter = chef and chef:FindFirstChild("Counter")
        local chefPrompt = counter and counter:FindFirstChildOfClass("ProximityPrompt")

        local gym = plot:FindFirstChild("GymTreadmill")
        local belt = gym and gym:FindFirstChild("Belt")
        local gymPrompt = belt and belt:FindFirstChildOfClass("ProximityPrompt")
        if gymPrompt then
            gymPrompt.Triggered:Connect(function(player)
                TrainStrengthRemote.OnServerInvoke(player)
            end)
        end
    end
end
task.spawn(bindAllPrompts)

print("[EggSanctuary] Server v7.0 Full DataStore Save & Open Fenced Garden Engine Loaded!")
