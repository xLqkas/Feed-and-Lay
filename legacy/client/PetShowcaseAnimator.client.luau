--!strict
-- PetShowcaseAnimator: High-Fidelity 60FPS Living Animation Engine for Egg Sanctuary
-- Handles alive breathing, multi-tail wave sway, ear twitches, wing hovers, station ambient motion & canyon statues

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local function getBases()
    local map = Workspace:FindFirstChild("EggSanctuaryMap")
    local mp = map and map:FindFirstChild("MultiplayerBases")
    if mp then return mp:GetChildren() end
    return {}
end

local function getCanyon()
    local map = Workspace:FindFirstChild("EggSanctuaryMap")
    return map and map:FindFirstChild("DistanceCanyon")
end

local clock = 0
RunService.RenderStepped:Connect(function(dt)
    clock = clock + dt

    -- 1. ANIMATE GARDEN PETS IN ALL BASES (Smooth 60FPS Alive Motion)
    local bases = getBases()
    for _, base in ipairs(bases) do
        local petsFolder = base:FindFirstChild("PetsInGarden")
        if petsFolder then
            for _, pet in ipairs(petsFolder:GetChildren()) do
                if pet:IsA("Model") and pet:GetAttribute("IsGardenPet") then
                    local baseCF = pet:GetAttribute("BaseCFrame")
                    if baseCF then
                        local seed = (pet.Name:byte(5) or 1) * 0.85
                        
                        -- Alive breathing and gentle wandering
                        local bob = math.sin(clock * 2.4 + seed) * 0.35
                        local tilt = math.sin(clock * 1.6 + seed) * 0.08
                        local roamX = math.sin(clock * 0.65 + seed) * 1.8
                        local roamZ = math.cos(clock * 0.65 + seed) * 1.8
                        local heading = math.sin(clock * 0.85 + seed) * 0.35

                        -- Apply alive root CFrame
                        local currentCF = baseCF * CFrame.new(roamX, bob, roamZ) * CFrame.Angles(0, heading, tilt)
                        pet:PivotTo(currentCF)

                        -- Subtle sub-part wave animations for multi-tail beasts & ears
                        for _, child in ipairs(pet:GetChildren()) do
                            if child:IsA("BasePart") then
                                local cName = child.Name:lower()
                                -- Tail wave sway (sine wave propagation)
                                if cName:find("tail") then
                                    local tailIdx = tonumber(cName:match("[-]?%d+")) or 0
                                    local sway = math.sin(clock * 2.8 + tailIdx * 0.45) * math.rad(8)
                                    child.CFrame = child.CFrame * CFrame.Angles(0, sway * dt * 8, 0)
                                -- Ear twitch
                                elseif cName:find("ear") then
                                    local twitch = math.sin(clock * 3.5 + seed) > 0.85 and (math.sin(clock * 15) * math.rad(4)) or 0
                                    child.CFrame = child.CFrame * CFrame.Angles(twitch * dt * 10, 0, 0)
                                -- Spine Crest wave
                                elseif cName:find("spine") or cName:find("crest") then
                                    local wave = math.sin(clock * 3.0 + child.Position.Z * 0.5) * math.rad(5)
                                    child.CFrame = child.CFrame * CFrame.Angles(wave * dt * 6, 0, 0)
                                end
                            end
                        end
                    end
                end
            end
        end

        -- 2. STATION AMBIENT ANIMATIONS
        -- Egg Cleaner Incubator Egg & Water Ripple
        local cleaner = base:FindFirstChild("EggCleaner")
        if cleaner then
            local activeEgg = cleaner:FindFirstChild("ActiveEgg")
            if activeEgg and activeEgg:IsA("BasePart") and activeEgg.Transparency < 1 then
                if not activeEgg:GetAttribute("BaseEggY") then
                    activeEgg:SetAttribute("BaseEggY", activeEgg.Position.Y)
                end
                local eggY = activeEgg:GetAttribute("BaseEggY") or activeEgg.Position.Y
                local eggBob = math.sin(clock * 2.2) * 0.22
                activeEgg.CFrame = CFrame.new(activeEgg.Position.X, eggY + eggBob, activeEgg.Position.Z) * CFrame.Angles(0, clock * 0.9, math.sin(clock * 1.5) * 0.08)
            end

            local waterPool = cleaner:FindFirstChild("WaterPool")
            if waterPool and waterPool:IsA("BasePart") then
                waterPool.Transparency = 0.32 + math.sin(clock * 2.0) * 0.06
            end
        end

        -- Chef Stall Hanging Lantern Sway
        local chef = base:FindFirstChild("ChefStall")
        if chef then
            local lantern = chef:FindFirstChild("LanternGlass")
            if lantern and lantern:IsA("BasePart") then
                local sway = math.sin(clock * 1.6) * 0.06
                lantern.CFrame = CFrame.new(lantern.Position.X + sway * 0.1, lantern.Position.Y, lantern.Position.Z) * CFrame.Angles(0, 0, sway)
            end
        end

        -- Corner Lanterns & Reward Chest Gentle Shimmer
        local yard = base:FindFirstChild("GardenYard")
        if yard then
            local chest = yard:FindFirstChild("RewardChest")
            local lock = chest and chest:FindFirstChild("Lock")
            if lock and lock:IsA("BasePart") then
                lock.Color = Color3.fromRGB(
                    math.floor(255),
                    math.floor(210 + math.sin(clock * 3.0) * 25),
                    math.floor(70 + math.sin(clock * 3.0) * 30)
                )
            end
        end
    end

    -- 3. DISTANCE CANYON MONSTER STATUES HOVERING/BREATHING
    local canyon = getCanyon()
    if canyon then
        for _, zone in ipairs(canyon:GetChildren()) do
            for _, child in ipairs(zone:GetChildren()) do
                if child:IsA("Model") and child.Name:find("Statue") then
                    local primary = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
                    if primary then
                        if not primary:GetAttribute("BaseStatueY") then
                            primary:SetAttribute("BaseStatueY", primary.Position.Y)
                        end
                        local baseY = primary:GetAttribute("BaseStatueY")
                        local hover = math.sin(clock * 1.8 + primary.Position.Z * 0.01) * 0.28
                        child:PivotTo(CFrame.new(primary.Position.X, baseY + hover, primary.Position.Z) * (primary.CFrame - primary.Position))
                    end
                end
            end
        end
    end
end)

print("[EggSanctuary] PetShowcaseAnimator v8.0 High-Fidelity 60FPS Living Engine Loaded!")
