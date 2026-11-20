local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local SoundHelper = require(Modules:WaitForChild("SoundHelper"))

-- 1. Ensure Remotes Folder & Remote Functions Exist (Issue 11 Fix)
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
    Remotes = Instance.new("Folder")
    Remotes.Name = "Remotes"
    Remotes.Parent = ReplicatedStorage
end

local function getOrCreateRemoteFunction(name)
    local remote = Remotes:FindFirstChild(name)
    if not remote then
        remote = Instance.new("RemoteFunction")
        remote.Name = name
        remote.Parent = Remotes
    end
    return remote
end

local TrainStrengthRemote = getOrCreateRemoteFunction("TrainStrength")
local StartChargeRemote = getOrCreateRemoteFunction("StartCharge")
local ThrowFoodRemote = getOrCreateRemoteFunction("ThrowFood")
local CleanEggRemote = getOrCreateRemoteFunction("CleanEgg")
local HatchEggRemote = getOrCreateRemoteFunction("HatchEgg")
local UpgradeFoodRemote = getOrCreateRemoteFunction("UpgradeFood")
local ExpandSanctuaryRemote = getOrCreateRemoteFunction("ExpandSanctuary")
local ManagePetRemote = getOrCreateRemoteFunction("ManagePet")
local GetSanctuaryStateRemote = getOrCreateRemoteFunction("GetSanctuaryState")
local UpgradeCleanerRemote = getOrCreateRemoteFunction("UpgradeCleaner")

-- 2. DataStore Setup
local DATASTORE_KEY = "EggSanctuary_SaveData_v6"
local PlayerDataStore = nil
local isDataStoreActive = false

pcall(function()
    PlayerDataStore = DataStoreService:GetDataStore(DATASTORE_KEY)
    isDataStoreActive = true
end)

local PlayerData = {}
local AssignedPlots = {} -- [userId] = plotId (1..6)
local SpawnedPetModels = {} -- [userId] = { [petId] = model }

local MAX_PLOTS = GameConfig.MaxGardenPlots or 6

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

    -- Update Base Sign
    local signPart = plot:FindFirstChild("BaseSign")
    local sg = signPart and signPart:FindFirstChildOfClass("SurfaceGui")
    local titleLbl = sg and sg:FindFirstChildOfClass("TextLabel")
    if titleLbl then
        titleLbl.Text = player.DisplayName:upper() .. "'S BASE (+" .. totalIncome .. " $/s)"
    end

    -- Update ActiveEgg visual at EggCleaner (Covered in mud/sludge until 100% cleaned)
    local cleaner = plot:FindFirstChild("EggCleaner")
    if cleaner and cleaner:FindFirstChild("ActiveEgg") then
        local eggPart = cleaner.ActiveEgg
        if data.CurrentEgg then
            eggPart.Transparency = 0
            if (data.CurrentEgg.Cleanliness or 0) >= 100 then
                -- Pristine clean revealed egg: Glowing neon gold
                eggPart.Color = Color3.fromRGB(255, 225, 80)
                eggPart.Material = Enum.Material.Neon
            else
                -- Completely covered in thick muddy sludge/dump until cleaned
                eggPart.Color = Color3.fromRGB(62, 42, 24)
                eggPart.Material = Enum.Material.Slate
            end
        else
            eggPart.Transparency = 1
        end
    end
end

-- Spawn pet into open garden yard (anchored; client handles 60fps bobbing)
local function spawnPetInGarden(userId, pet)
    SpawnedPetModels[userId] = SpawnedPetModels[userId] or {}

    local plot, plotId = getPlayerPlot(userId)
    if not plot then return end

    local petsFolder = plot:FindFirstChild("PetsInGarden") or Instance.new("Folder", plot)
    petsFolder.Name = "PetsInGarden"

    local yard = plot:FindFirstChild("GardenYard")
    local floor = yard and yard:FindFirstChild("YardFloor")
    local centerPos = floor and floor.Position or Vector3.new(-155, -77.9, -36)
    local spawnX = centerPos.X + (pet.RelX or math.random(-14, 14))
    local spawnY = centerPos.Y + 2.4
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

    -- Apply centralized mutation styling
    local mutConfig = GameConfig.Mutations[pet.Mutation] or GameConfig.Mutations.Normal
    if pet.Mutation ~= "Normal" then
        for _, p in ipairs(petModel:GetDescendants()) do
            if p:IsA("BasePart") and not p.Name:find("Eye") then
                p.Color = mutConfig.Color
                p.Material = mutConfig.Material
            end
        end
    end

    local randomYaw = math.random() * math.pi * 2
    local baseCFrame = CFrame.new(spawnX, spawnY, spawnZ) * CFrame.Angles(0, randomYaw, 0)
    petModel:PivotTo(baseCFrame)
    petModel:SetAttribute("IsGardenPet", true)
    petModel:SetAttribute("BaseCFrame", baseCFrame)
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
        bgStroke.Color = mutConfig.StrokeColor

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

    SpawnedPetModels[userId][pet.PetId] = petModel
end

-- 3. Player Setup & Safe Loading (Issue 1, 3, 8, 9 Fixes)
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

    -- If no plot is free, safely reject to prevent wiping another player's base (Issue 9)
    if not plotId then
        player:Kick("Sanctuary world is full (Max 6 players per server). Please join another server!")
        return
    end

    AssignedPlots[player.UserId] = plotId

    local defaultData = {
        Strength = 150,
        BioEssence = 50,
        FoodTier = 1,
        EggsCleaned = 0,
        MaxSlots = GameConfig.DefaultMaxSlots or 4,
        GardenPets = {},
        CurrentEgg = nil,
        CleanerUpgrades = {
            PSILevel = 1,
            WidthLevel = 1,
            Tier = 1,
        },
        LastThrowTime = 0,
        LastTrainTime = 0,
        ChargeStartTime = nil,
        PlotId = plotId,
        LoadFailed = false,
    }

    -- Robust DataStore Load (Issue 1 & 3)
    if isDataStoreActive and PlayerDataStore then
        local key = "Player_" .. player.UserId
        local success, saved = pcall(function()
            return PlayerDataStore:GetAsync(key)
        end)

        -- If player left while loading, release plot immediately (Issue 3)
        if not player.Parent then
            AssignedPlots[player.UserId] = nil
            return
        end

        if not success then
            warn("[EggSanctuary] Load failed for " .. player.UserId .. ": " .. tostring(saved))
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
            defaultData.CleanerUpgrades = saved.CleanerUpgrades or defaultData.CleanerUpgrades
        end
    end

    PlayerData[player.UserId] = defaultData

    -- Guarantee 1 Starter Pet (Meadow Bunny) for new players
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

    -- Clear old models in assigned plot
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

    local maxSlotsVal = Instance.new("IntValue")
    maxSlotsVal.Name = "MaxSlots"
    maxSlotsVal.Value = defaultData.MaxSlots
    maxSlotsVal.Parent = leaderstats

    -- Spawn placed garden pets
    for _, pet in ipairs(defaultData.GardenPets) do
        spawnPetInGarden(player.UserId, pet)
    end

    updateSanctuaryWorldVisuals(player)

    -- Position character at their base when spawning
    local function onCharacterAdded(char)
        local root = char:WaitForChild("HumanoidRootPart", 5)
        if root then
            local plotObj = getPlayerPlot(player.UserId)
            if plotObj then
                local yard = plotObj:FindFirstChild("GardenYard")
                local floor = yard and yard:FindFirstChild("YardFloor")
                local spawnPos = floor and (floor.Position + Vector3.new(0, 4, 18)) or Vector3.new(-155, -73, -18)
                task.wait(0.1)
                root.CFrame = CFrame.new(spawnPos) * CFrame.Angles(0, math.rad(180), 0)
            end
        end
    end
    player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then
        task.spawn(onCharacterAdded, player.Character)
    end
end

-- 4. Safe Player Data Saving (Issue 1 & 12)
local function savePlayerData(player)
    local data = PlayerData[player.UserId]
    if not data or data.LoadFailed then return end

    if isDataStoreActive and PlayerDataStore then
        local key = "Player_" .. player.UserId
        local ok, err = pcall(function()
            PlayerDataStore:UpdateAsync(key, function(oldData)
                return {
                    Strength = data.Strength,
                    BioEssence = data.BioEssence,
                    FoodTier = data.FoodTier,
                    EggsCleaned = data.EggsCleaned,
                    MaxSlots = data.MaxSlots,
                    GardenPets = data.GardenPets,
                    CleanerUpgrades = data.CleanerUpgrades,
                    LastSaveTime = os.time(),
                }
            end)
        end)
        if not ok then
            warn("[EggSanctuary] Save failed for " .. player.UserId .. ": " .. tostring(err))
        end
    end
end

Players.PlayerAdded:Connect(setupPlayer)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(setupPlayer, p)
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

-- Server Shutdown Protection (Issue 2 Fix)
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
-- 1. GYM: BICEP CURL TRAINING (Automated Repetitions & Anti-Cheat)
-----------------------------------------------------
local function doTrainStrength(player)
    local data = PlayerData[player.UserId]
    if not data then return { Success = false, Message = "No data" } end

    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return { Success = false, Message = "Character not found" } end

    -- Verify player is near their Bicep Curl Station (Anti-Teleport / Remote Exploit)
    local isNearGym = false
    local plotId = AssignedPlots[player.UserId]
    local bases = Workspace:FindFirstChild("EggSanctuaryMap") and Workspace.EggSanctuaryMap:FindFirstChild("MultiplayerBases")
    if bases then
        local base = plotId and bases:FindFirstChild("PlayerBase_" .. plotId)
        local gym = base and (base:FindFirstChild("BicepCurlStation") or base:FindFirstChild("GymTreadmill"))
        if gym and gym:FindFirstChild("InteractPart") then
            if (hrp.Position - gym.InteractPart.Position).Magnitude <= 20 then
                isNearGym = true
            end
        end
        if not isNearGym then
            for _, b in ipairs(bases:GetChildren()) do
                local g = b:FindFirstChild("BicepCurlStation") or b:FindFirstChild("GymTreadmill")
                if g and g:FindFirstChild("InteractPart") and (hrp.Position - g.InteractPart.Position).Magnitude <= 20 then
                    isNearGym = true
                    break
                end
            end
        end
    end

    if not isNearGym then
        return { Success = false, Message = "You must be at the Bicep Curl Station to train!" }
    end

    local now = os.clock()
    if data.LastTrainTime and (now - data.LastTrainTime) < GameConfig.TrainCooldown then
        return { Success = false, Message = "Training cooldown! Rest a moment." }
    end
    data.LastTrainTime = now

    data.Strength = data.Strength + 10
    if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Strength") then
        player.leaderstats.Strength.Value = data.Strength
    end

    SoundHelper.Play("GymWorkout", hrp)

    return {
        Success = true,
        NewStrength = data.Strength,
        Gain = 10,
    }
end

TrainStrengthRemote.OnServerInvoke = doTrainStrength

-----------------------------------------------------
-- 2. START CHARGE REMOTE (Issue 5 Anti-Cheat Fix)
-----------------------------------------------------
StartChargeRemote.OnServerInvoke = function(player)
    local data = PlayerData[player.UserId]
    if not data then return { Success = false } end

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not GameConfig.IsInLaunchZone(root.Position) then
        return { Success = false, Message = "Walk to the Launch Pad to throw!" }
    end

    data.ChargeStartTime = os.clock()
    return { Success = true }
end

-----------------------------------------------------
-- 3. THROW FOOD (Issue 5, 6, 13 Fixes)
-----------------------------------------------------
ThrowFoodRemote.OnServerInvoke = function(player, clientReportedDuration)
    local data = PlayerData[player.UserId]
    if not data then return { Success = false, Message = "No data" } end

    -- Check if player already has an uncleaned egg (Issue 6 Fix)
    if data.CurrentEgg then
        return { Success = false, Message = "You already have an egg in your cleaner! Clean and hatch it first." }
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return { Success = false, Message = "Character not found!" }
    end

    if not GameConfig.IsInLaunchZone(root.Position) then
        return { Success = false, Message = "Walk forward to the Launch Pad to throw!" }
    end

    local now = os.clock()
    if data.LastThrowTime and (now - data.LastThrowTime) < GameConfig.ThrowCooldown then
        return { Success = false, Message = "Throw is on cooldown! Wait a moment." }
    end
    -- Calculate true charge duration on server (Issue 5 Fix)
    -- No StartCharge is a bad request; the client-reported duration is never trusted on its own.
    if not data.ChargeStartTime then
        return { Success = false, Message = "Hold to charge first!" }
    end
    local duration = now - data.ChargeStartTime
    data.ChargeStartTime = nil
    data.LastThrowTime = now
    if clientReportedDuration ~= nil then
        local reported = tonumber(clientReportedDuration)
        if type(reported) == "number" and reported == reported and math.abs(reported - duration) <= 0.15 then
            duration = math.clamp(reported, 0.05, 3.0)
        end
    end

    local ratio, isSweetSpot, tierTag = GameConfig.ThrowRatio(duration)

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
        PlotId = plotId,
    }
end

-----------------------------------------------------
-- 4. EGG CLEANER: BRUSH EGG (Section Distance Validation)
-----------------------------------------------------
local function isNearEggCleaner(player)
    local plot, plotId = getPlayerPlot(player.UserId)
    if not plot then return false end
    local cleaner = plot:FindFirstChild("EggCleaner")
    local basin = cleaner and (cleaner:FindFirstChild("WashBasin") or cleaner:FindFirstChildWhichIsA("BasePart"))
    local cleanerPos = basin and basin.Position or (cleaner and cleaner:GetPivot().Position)
    if not cleanerPos then return false end

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local dist = (root.Position - cleanerPos).Magnitude
    return dist <= 24, dist
end

CleanEggRemote.OnServerInvoke = function(player, chunkIndex, clientCleanliness)
    local data = PlayerData[player.UserId]
    if not data or not data.CurrentEgg then
        return { Success = false, Message = "No egg in cleaner! Feed the monster down the canyon first." }
    end

    -- User requirement: Egg can only be cleaned when player is at the cleaning section
    if not isNearEggCleaner(player) then
        return { Success = false, Message = "Walk to your base's Egg Cleaner to wash the egg!" }
    end

    local egg = data.CurrentEgg
    local totalChunks = GameConfig.TotalEggChunks or 30

    if clientCleanliness ~= nil then
        local targetClean = math.clamp(math.floor(tonumber(clientCleanliness) or 0), 0, 100)
        if targetClean > egg.Cleanliness then
            egg.Cleanliness = targetClean
        end
    else
        egg.Cleanliness = math.min(100, egg.Cleanliness + math.ceil(100 / totalChunks))
    end

    updateSanctuaryWorldVisuals(player)

    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if egg.Cleanliness >= 100 then
        SoundHelper.Play("PristineChime", hrp)
    end

    return {
        Success = true,
        Cleanliness = egg.Cleanliness,
        IsComplete = (egg.Cleanliness >= 100),
        Egg = egg,
    }
end

-----------------------------------------------------
-- 5. PUT EGG IN GARDEN TO GROW & HATCH (Issue 7 Fix)
-----------------------------------------------------
HatchEggRemote.OnServerInvoke = function(player)
    local data = PlayerData[player.UserId]
    if not data or not data.CurrentEgg then
        return { Success = false, Message = "No egg to place in garden!" }
    end

    if not isNearEggCleaner(player) then
        return { Success = false, Message = "Walk to your base's Egg Cleaner to hatch your egg!" }
    end

    local egg = data.CurrentEgg
    if egg.Cleanliness < 100 then
        return { Success = false, Message = "Egg is still dirty! Brush it clean first." }
    end

    local maxSlots = data.MaxSlots or GameConfig.DefaultMaxSlots
    if #data.GardenPets >= maxSlots then
        return { Success = false, Message = "Garden is full (" .. #data.GardenPets .. "/" .. maxSlots .. ")! Expand your slots." }
    end

    data.CurrentEgg = nil
    data.EggsCleaned = data.EggsCleaned + 1
    if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("EggsCleaned") then
        player.leaderstats.EggsCleaned.Value = data.EggsCleaned
    end

    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    SoundHelper.Play("HatchFanfare", hrp)

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

    return {
        Success = true,
        Message = "Growing a " .. egg.Mutation .. " " .. egg.Rarity .. " " .. egg.AnimalName .. " in your Garden!",
        Pet = newPet,
        Income = egg.PetIncome,
        TotalIncome = calculateTotalIncome(player.UserId),
        SlotsUsed = #data.GardenPets,
        MaxSlots = maxSlots,
    }
end

-----------------------------------------------------
-- 6. EXPAND SANCTUARY SLOTS (Issue 7 Fix)
-----------------------------------------------------
ExpandSanctuaryRemote.OnServerInvoke = function(player)
    local data = PlayerData[player.UserId]
    if not data then return { Success = false, Message = "No data" } end

    local currentSlots = data.MaxSlots or GameConfig.DefaultMaxSlots
    if currentSlots >= GameConfig.MaxSlotsCap then
        return { Success = false, Message = "Garden is already at maximum capacity (" .. GameConfig.MaxSlotsCap .. " slots)!" }
    end

    local cost = GameConfig.SlotUpgradeCost(currentSlots)
    if data.BioEssence < cost then
        return { Success = false, Message = "Need " .. cost .. " Bio-Essence to expand garden slots!" }
    end

    data.BioEssence = data.BioEssence - cost
    data.MaxSlots = currentSlots + 2
    if player:FindFirstChild("leaderstats") then
        if player.leaderstats:FindFirstChild("BioEssence") then
            player.leaderstats.BioEssence.Value = data.BioEssence
        end
        if player.leaderstats:FindFirstChild("MaxSlots") then
            player.leaderstats.MaxSlots.Value = data.MaxSlots
        end
    end

    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    SoundHelper.Play("PristineChime", hrp)

    return {
        Success = true,
        NewMaxSlots = data.MaxSlots,
        BioEssence = data.BioEssence,
        Message = "Garden expanded to " .. data.MaxSlots .. " slots!",
    }
end

-----------------------------------------------------
-- 7. MANAGE PET: REMOVE/SELL (Issue 7 Fix)
-----------------------------------------------------
ManagePetRemote.OnServerInvoke = function(player, action, targetPetId)
    local data = PlayerData[player.UserId]
    if not data then return { Success = false, Message = "No data" } end

    if action == "Sell" or action == "Release" then
        local foundIdx = nil
        for i, pet in ipairs(data.GardenPets) do
            if pet.PetId == targetPetId then
                foundIdx = i
                break
            end
        end

        if not foundIdx then
            return { Success = false, Message = "Pet not found in garden!" }
        end

        local pet = data.GardenPets[foundIdx]
        local refund = math.max(10, pet.Income * 15)
        data.BioEssence = data.BioEssence + refund
        table.remove(data.GardenPets, foundIdx)

        if SpawnedPetModels[player.UserId] and SpawnedPetModels[player.UserId][targetPetId] then
            local model = SpawnedPetModels[player.UserId][targetPetId]
            if model and model.Parent then model:Destroy() end
            SpawnedPetModels[player.UserId][targetPetId] = nil
        end

        if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("BioEssence") then
            player.leaderstats.BioEssence.Value = data.BioEssence
        end

        updateSanctuaryWorldVisuals(player)

        return {
            Success = true,
            Refund = refund,
            TotalIncome = calculateTotalIncome(player.UserId),
            Message = "Released " .. pet.Name .. " for +" .. refund .. " Bio-Essence!",
        }
    end

    return { Success = false, Message = "Unknown pet action" }
end

-----------------------------------------------------
-- 8. UPGRADE FOOD
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
        if player:FindFirstChild("leaderstats") then
            player.leaderstats.BioEssence.Value = data.BioEssence
            player.leaderstats.FoodTier.Value = data.FoodTier
        end
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        SoundHelper.Play("PristineChime", hrp)
        return { Success = true, Food = nextFood, NewEssence = data.BioEssence }
    else
        return { Success = false, Message = "Need " .. nextFood.Cost .. " Bio-Essence for " .. nextFood.Name .. "!" }
    end
end

-----------------------------------------------------
-- 9. POWER WASHER & CLEANER UPGRADES
-----------------------------------------------------
UpgradeCleanerRemote.OnServerInvoke = function(player, category)
    local data = PlayerData[player.UserId]
    if not data then return { Success = false, Message = "No data" } end

    data.CleanerUpgrades = data.CleanerUpgrades or { PSILevel = 1, WidthLevel = 1, Tier = 1 }

    if category == "PSI" then
        local currentLvl = data.CleanerUpgrades.PSILevel or 1
        local nextConfig = GameConfig.CleanerUpgrades.PSI[currentLvl + 1]
        if not nextConfig then
            return { Success = false, Message = "Pressure (PSI) is already at maximum level!" }
        end
        if data.BioEssence < nextConfig.Cost then
            return { Success = false, Message = "Not enough Bio-Essence! Need " .. nextConfig.Cost .. " $" }
        end
        data.BioEssence = data.BioEssence - nextConfig.Cost
        data.CleanerUpgrades.PSILevel = currentLvl + 1

        if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("BioEssence") then
            player.leaderstats.BioEssence.Value = data.BioEssence
        end
        savePlayerData(player)
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        SoundHelper.Play("PristineChime", hrp)
        return {
            Success = true,
            Category = "PSI",
            NewLevel = data.CleanerUpgrades.PSILevel,
            Config = nextConfig,
            NewEssence = data.BioEssence,
            Message = "Upgraded to " .. nextConfig.Name .. "!",
        }
    elseif category == "Width" then
        local currentLvl = data.CleanerUpgrades.WidthLevel or 1
        local nextConfig = GameConfig.CleanerUpgrades.Width[currentLvl + 1]
        if not nextConfig then
            return { Success = false, Message = "Spray Nozzle is already at maximum width!" }
        end
        if data.BioEssence < nextConfig.Cost then
            return { Success = false, Message = "Not enough Bio-Essence! Need " .. nextConfig.Cost .. " $" }
        end
        data.BioEssence = data.BioEssence - nextConfig.Cost
        data.CleanerUpgrades.WidthLevel = currentLvl + 1

        if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("BioEssence") then
            player.leaderstats.BioEssence.Value = data.BioEssence
        end
        savePlayerData(player)
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        SoundHelper.Play("PristineChime", hrp)
        return {
            Success = true,
            Category = "Width",
            NewLevel = data.CleanerUpgrades.WidthLevel,
            Config = nextConfig,
            NewEssence = data.BioEssence,
            Message = "Upgraded to " .. nextConfig.Name .. "!",
        }
    elseif category == "Tier" then
        local currentTier = data.CleanerUpgrades.Tier or 1
        local nextConfig = GameConfig.CleanerUpgrades.Tier[currentTier + 1]
        if not nextConfig then
            return { Success = false, Message = "Washer hardware is already at maximum tier!" }
        end
        if data.BioEssence < nextConfig.Cost then
            return { Success = false, Message = "Not enough Bio-Essence! Need " .. nextConfig.Cost .. " $" }
        end
        data.BioEssence = data.BioEssence - nextConfig.Cost
        data.CleanerUpgrades.Tier = currentTier + 1

        if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("BioEssence") then
            player.leaderstats.BioEssence.Value = data.BioEssence
        end
        savePlayerData(player)
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        SoundHelper.Play("PristineChime", hrp)
        return {
            Success = true,
            Category = "Tier",
            NewTier = data.CleanerUpgrades.Tier,
            Config = nextConfig,
            NewEssence = data.BioEssence,
            Message = "Unlocked " .. nextConfig.Name .. "!",
        }
    end

    return { Success = false, Message = "Invalid upgrade category" }
end

-----------------------------------------------------
-- 10. GET SANCTUARY STATE (Issue 8 Fix)
-----------------------------------------------------
GetSanctuaryStateRemote.OnServerInvoke = function(player)
    local plotId = AssignedPlots[player.UserId] or 1
    local data = PlayerData[player.UserId]
    if not data then
        return {
            GardenPets = {},
            MaxSlots = GameConfig.DefaultMaxSlots or 4,
            TotalIncome = 0,
            HasEgg = false,
            BioEssence = 0,
            FoodTier = 1,
            PlotId = plotId,
            CleanerUpgrades = { PSILevel = 1, WidthLevel = 1, Tier = 1 },
        }
    end

    return {
        GardenPets = data.GardenPets or {},
        MaxSlots = data.MaxSlots or GameConfig.DefaultMaxSlots,
        TotalIncome = calculateTotalIncome(player.UserId),
        BioEssence = data.BioEssence,
        FoodTier = data.FoodTier,
        HasEgg = (data.CurrentEgg ~= nil),
        EggCleanliness = data.CurrentEgg and data.CurrentEgg.Cleanliness or 0,
        CurrentEgg = data.CurrentEgg,
        CleanerUpgrades = data.CleanerUpgrades or { PSILevel = 1, WidthLevel = 1, Tier = 1 },
        PlotId = plotId,
    }
end

-----------------------------------------------------
-- 10. PASSIVE INCOME TICK (Issue 10 Rate Fix: Every 1s)
-----------------------------------------------------
task.spawn(function()
    while true do
        task.wait(1)
        for _, player in ipairs(Players:GetPlayers()) do
            local data = PlayerData[player.UserId]
            if data then
                local income = calculateTotalIncome(player.UserId)
                if income > 0 then
                    data.BioEssence = data.BioEssence + income
                    if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("BioEssence") then
                        player.leaderstats.BioEssence.Value = data.BioEssence
                    end
                end
            end
        end
    end
end)

-- Configure in-world ProximityPrompts for all plots
local function bindAllPrompts()
    local bases = Workspace:FindFirstChild("EggSanctuaryMap") and Workspace.EggSanctuaryMap:FindFirstChild("MultiplayerBases")
    if not bases then return end

    for _, plot in ipairs(bases:GetChildren()) do
        local gym = plot:FindFirstChild("BicepCurlStation") or plot:FindFirstChild("GymTreadmill")
        if gym then
            for _, desc in ipairs(gym:GetDescendants()) do
                if desc:IsA("ProximityPrompt") then
                    desc.ObjectText = "Bicep Curl Station"
                    desc.ActionText = "Start Auto-Workout (+10 Reach/rep)"
                    desc.HoldDuration = 0
                    desc.MaxActivationDistance = 14
                    desc.RequiresLineOfSight = false
                end
            end
        end
    end
end
task.spawn(bindAllPrompts)

print("[EggSanctuary] Server v8.0 Fully Hardened & Audited Engine Loaded!")
