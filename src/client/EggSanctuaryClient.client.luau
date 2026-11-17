local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local SoundHelper = require(Modules:WaitForChild("SoundHelper"))

-- Remotes
local TrainStrengthRemote = Remotes:WaitForChild("TrainStrength")
local StartChargeRemote = Remotes:WaitForChild("StartCharge")
local ThrowFoodRemote = Remotes:WaitForChild("ThrowFood")
local CleanEggRemote = Remotes:WaitForChild("CleanEgg")
local HatchEggRemote = Remotes:WaitForChild("HatchEgg")
local UpgradeFoodRemote = Remotes:WaitForChild("UpgradeFood")
local ExpandSanctuaryRemote = Remotes:WaitForChild("ExpandSanctuary")
local ManagePetRemote = Remotes:WaitForChild("ManagePet")
local GetSanctuaryStateRemote = Remotes:WaitForChild("GetSanctuaryState")

-- GUI References
local hudGui = PlayerGui:WaitForChild("EggSanctuaryHUD")
local HUD = hudGui:WaitForChild("MainFrame")
local TopBar = HUD:WaitForChild("TopBar")
local StrengthBadge = TopBar:WaitForChild("StrengthBadge")
local EssenceBadge = TopBar:WaitForChild("EssenceBadge")
local FoodBadge = TopBar:WaitForChild("FoodBadge")
local ZoneBadge = TopBar:WaitForChild("ZoneBadge")

local NoticeLabel = HUD:WaitForChild("NoticeLabel")

local NavStack = HUD:WaitForChild("NavStack")
local ShopBtn = NavStack:WaitForChild("ShopButton")
local PetsNavBtn = NavStack:WaitForChild("PetsNavButton")
local GymNavBtn = NavStack:WaitForChild("GymNavButton")

local ThrowBtn = HUD:WaitForChild("ThrowButton")
local MeterFrame = HUD:WaitForChild("ChargeMeterFrame")
local SegmentsContainer = MeterFrame:WaitForChild("SegmentsContainer")
local ArrowTag = MeterFrame:WaitForChild("ArrowTag")
local MultiplierLabel = ArrowTag:WaitForChild("MultiplierLabel")

local WashModal = HUD:WaitForChild("WashModal")
local EggContainer = WashModal:WaitForChild("EggContainer")
local ProgressBarBG = WashModal:WaitForChild("ProgressBarBG")
local ProgressBarFill = ProgressBarBG:WaitForChild("Fill")
local PercentLabel = ProgressBarBG:FindFirstChild("PercentLabel")
local ScrubBtn = WashModal:WaitForChild("ScrubButton")

local PetModal = HUD:WaitForChild("PetInventoryModal")
local PetListScroll = PetModal:WaitForChild("PetListScroll")
local PetSummaryLabel = PetModal:WaitForChild("SummaryLabel")
local ClosePetBtn = PetModal:WaitForChild("CloseButton")

local ShopModal = HUD:WaitForChild("ShopModal")
local FoodListScroll = ShopModal:WaitForChild("FoodListScroll")
local CloseShopBtn = ShopModal:WaitForChild("CloseButton")

local myPlotId = 1
local myPlotModel = nil

local isAtLaunchZone = false
local isCharging = false
local isThrowing = false
local chargeStartTime = 0
local landingPreviewPart = nil
local hasEggInCleaner = false
local lastClientGymClick = 0

local function showNotice(text, color)
    NoticeLabel.Text = text
    NoticeLabel.TextColor3 = color or Color3.fromRGB(255, 255, 120)
    NoticeLabel.Visible = true

    NoticeLabel.Size = UDim2.new(0, 460, 0, 36)
    TweenService:Create(NoticeLabel, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 440, 0, 32)
    }):Play()
end

local function bindPlotPrompts()
    if not myPlotModel then return end
    local cleaner = myPlotModel:FindFirstChild("EggCleaner")
    local basin = cleaner and cleaner:FindFirstChild("WashBasin")
    local prompt = basin and basin:FindFirstChildOfClass("ProximityPrompt")
    if prompt then
        prompt.ActionText = "Inspect & Power Wash Egg"
        prompt.ObjectText = "Egg Cleaner"
        prompt.Triggered:Connect(function()
            if not hasEggInCleaner then
                showNotice("No egg in cleaner! Walk to the Launch Pad to throw food and attract a creature!", Color3.fromRGB(255, 200, 100))
            end
        end)
    end

    local chef = myPlotModel:FindFirstChild("ChefStall")
    local counter = chef and chef:FindFirstChild("Counter")
    local chefPrompt = counter and counter:FindFirstChildOfClass("ProximityPrompt")
    if chefPrompt then
        chefPrompt.Triggered:Connect(function()
            ShopModal.Visible = true
        end)
    end
end

local function resolvePlot(plotId)
    myPlotId = plotId or myPlotId
    local bases = Workspace:FindFirstChild("EggSanctuaryMap") and Workspace.EggSanctuaryMap:FindFirstChild("MultiplayerBases")
    if bases then
        myPlotModel = bases:FindFirstChild("PlayerBase_" .. myPlotId)
        bindPlotPrompts()
    end
end

task.spawn(function()
    local leaderstats = player:WaitForChild("leaderstats", 15)
    if leaderstats then
        local plotVal = leaderstats:WaitForChild("PlotId", 15)
        if plotVal then
            resolvePlot(plotVal.Value)
            plotVal.Changed:Connect(resolvePlot)
        end
    end

    local state = GetSanctuaryStateRemote:InvokeServer()
    if state and state.PlotId then
        resolvePlot(state.PlotId)
        hasEggInCleaner = state.HasEgg
    end
end)

local function updateUI()
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local strength = leaderstats:FindFirstChild("Strength") and leaderstats.Strength.Value or 150
        StrengthBadge.Text = "💪 REACH: " .. strength .. " Studs"

        if leaderstats:FindFirstChild("BioEssence") then
            EssenceBadge.Text = "💵 BIO: " .. leaderstats.BioEssence.Value .. " $"
        end
        if leaderstats:FindFirstChild("FoodTier") then
            local food = GameConfig.Foods[leaderstats.FoodTier.Value] or GameConfig.Foods[1]
            FoodBadge.Text = "🍎 " .. food.Name .. " (" .. food.Luck .. "x)"
        end

        local currentZone = GameConfig.GetZoneByDistance(strength)
        ZoneBadge.Text = "📍 " .. (currentZone and currentZone.Name or "Meadow")
    end
end

-- Event-driven UI updates (Issue 20 Fix)
task.spawn(function()
    local leaderstats = player:WaitForChild("leaderstats", 15)
    if leaderstats then
        for _, child in ipairs(leaderstats:GetChildren()) do
            if child:IsA("ValueBase") then
                child.Changed:Connect(updateUI)
            end
        end
        leaderstats.ChildAdded:Connect(function(child)
            if child:IsA("ValueBase") then
                child.Changed:Connect(updateUI)
            end
        end)
    end
    updateUI()
end)

-- Gentle 2s backup UI ticker
task.spawn(function()
    while true do
        task.wait(2)
        updateUI()
    end
end)

-----------------------------------------------------
-- 3D TRAJECTORY PREVIEW
-----------------------------------------------------
local function getLandingMarker()
    if not landingPreviewPart or not landingPreviewPart.Parent then
        landingPreviewPart = Instance.new("Part")
        landingPreviewPart.Name = "LandingPreviewMarker"
        landingPreviewPart.Size = Vector3.new(14, 0.4, 14)
        landingPreviewPart.Shape = Enum.PartType.Cylinder
        landingPreviewPart.CFrame = CFrame.Angles(0, 0, math.rad(90))
        landingPreviewPart.Color = Color3.fromRGB(255, 220, 60)
        landingPreviewPart.Material = Enum.Material.Neon
        landingPreviewPart.Transparency = 0.4
        landingPreviewPart.Anchored = true
        landingPreviewPart.CanCollide = false
        landingPreviewPart.Parent = Workspace
    end
    return landingPreviewPart
end

local function removeLandingMarker()
    if landingPreviewPart and landingPreviewPart.Parent then
        landingPreviewPart:Destroy()
        landingPreviewPart = nil
    end
end

-----------------------------------------------------
-- SEGMENTED POWER METER CONTROLLER (IMAGE 1 STYLE)
-----------------------------------------------------
local function setMeterSegments(activeCount, text)
    for i = 1, 6 do
        local seg = SegmentsContainer:FindFirstChild("Segment_" .. i)
        local lit = seg and seg:FindFirstChild("LitLayer")
        if lit then
            lit.BackgroundTransparency = (i <= activeCount) and 0 or 1
        end
    end

    if activeCount > 0 then
        ArrowTag.Visible = true
        MultiplierLabel.Text = text or "<| x1.0 POWER"
        local yPos = UDim2.new(1, 10, 1, - (activeCount - 0.5) * 41)
        ArrowTag.Position = yPos
    else
        ArrowTag.Visible = false
    end
end

-- Forward declaration of local executeThrow (Issue 20 Fix)
local executeThrow = nil

local function startCharge()
    if not isAtLaunchZone then
        showNotice("👉 Walk forward to the Yellow Launch Pad to throw!", Color3.fromRGB(255, 200, 100))
        return
    end
    if isThrowing or isCharging then return end

    isCharging = true
    chargeStartTime = os.clock()

    -- Notify server to record charge start time (Issue 5 Anti-Cheat Fix)
    pcall(function()
        StartChargeRemote:InvokeServer()
    end)

    ThrowBtn.Text = "CHARGING...\nRELEASE TO THROW!"
    ThrowBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 20)
    SoundHelper.Play("ThrowWhoosh")
end

local function endCharge()
    if not isCharging then return end
    isCharging = false
    local duration = os.clock() - chargeStartTime
    removeLandingMarker()

    setMeterSegments(0)
    ThrowBtn.Text = "HOLD TO CHARGE\nRELEASE TO THROW"
    ThrowBtn.BackgroundColor3 = Color3.fromRGB(240, 90, 40)

    if not isAtLaunchZone then
        showNotice("Left Launch Zone - Throw Cancelled!", Color3.fromRGB(255, 120, 100))
        return
    end

    if executeThrow then
        executeThrow(duration)
    end
end

-- RenderStepped Location & Segment Charge Tracker (Using GameConfig.ThrowRatio!)
RunService.RenderStepped:Connect(function()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if root then
        local inZone = GameConfig.IsInLaunchZone(root.Position)

        if inZone then
            if not isAtLaunchZone then
                isAtLaunchZone = true
                ThrowBtn.Visible = true
                MeterFrame.Visible = true
                showNotice("⚡ ON LAUNCH PAD: Hold Space or Button to Throw Food!", Color3.fromRGB(255, 220, 80))
            end
        else
            if isAtLaunchZone then
                isAtLaunchZone = false
                ThrowBtn.Visible = false
                MeterFrame.Visible = false

                if isCharging then
                    isCharging = false
                    removeLandingMarker()
                    setMeterSegments(0)
                    showNotice("Left Launch Zone - Throw Cancelled!", Color3.fromRGB(255, 120, 100))
                else
                    if hasEggInCleaner then
                        showNotice("🫧 Dirty Egg waiting at your Egg Cleaner! Go brush it!", Color3.fromRGB(140, 220, 255))
                    else
                        showNotice("👉 Walk forward to the Launch Pad to throw food!", Color3.fromRGB(200, 220, 255))
                    end
                end
            end
        end
    end

    -- Check if player is near their Egg Cleaner station; close wash modal if walked away
    if WashModal.Visible and myPlotModel and root then
        local cleaner = myPlotModel:FindFirstChild("EggCleaner")
        local basin = cleaner and (cleaner:FindFirstChild("WashBasin") or cleaner:FindFirstChildWhichIsA("BasePart"))
        local cleanerPos = basin and basin.Position or (cleaner and cleaner:GetPivot().Position)
        if cleanerPos then
            local dist = (root.Position - cleanerPos).Magnitude
            if dist > 20 then
                WashModal.Visible = false
                showNotice("Walked away from Egg Cleaner - Washing Paused!", Color3.fromRGB(255, 120, 100))
            end
        end
    end

    -- Update 6 Segments via centralized GameConfig (Issue 13 Fix)
    if isCharging then
        local elapsed = os.clock() - chargeStartTime
        local leaderstats = player:FindFirstChild("leaderstats")
        local strength = leaderstats and leaderstats:FindFirstChild("Strength") and leaderstats.Strength.Value or 150

        local ratio, isSweetSpot, tierTag, segmentIndex = GameConfig.ThrowRatio(elapsed)
        setMeterSegments(segmentIndex, tierTag)

        local projectedDist = math.floor(strength * ratio)
        local marker = getLandingMarker()
        local targetZ = -10 + projectedDist
        marker.CFrame = CFrame.new(-55, -76.8, targetZ) * CFrame.Angles(0, 0, math.rad(90))
    end
end)

-- Button Touch / Mouse Inputs
ThrowBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        startCharge()
    end
end)

ThrowBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        endCharge()
    end
end)

-- Spacebar & Gamepad
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonA then
        startCharge()
    end
end)

UserInputService.InputEnded:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonA then
        endCharge()
    end
end)

-----------------------------------------------------
-- RESET WASH MODAL (Completely Covered in Mud/Sludge until cleaned)
-----------------------------------------------------
local function resetWashModal()
    EggContainer.BackgroundColor3 = Color3.fromRGB(65, 42, 24) -- Dark muddy sludge color
    local eggStroke = EggContainer:FindFirstChildOfClass("UIStroke")
    if eggStroke then
        eggStroke.Color = Color3.fromRGB(80, 55, 30)
    end

    for i = 1, 4 do
        local patch = EggContainer:FindFirstChild("DirtPatch_" .. i)
        if patch then
            patch.Visible = true
            patch.TextTransparency = 0
            patch.BackgroundTransparency = 0
            patch.BackgroundColor3 = Color3.fromRGB(55, 35, 18)
            patch.Text = "💩 THICK MUD"
            patch.TextSize = 11
            patch.TextColor3 = Color3.fromRGB(200, 160, 100)
            patch.Size = UDim2.new(0.48, 0, 0.48, 0)
            if i == 1 then patch.Position = UDim2.new(0.01, 0, 0.01, 0)
            elseif i == 2 then patch.Position = UDim2.new(0.51, 0, 0.01, 0)
            elseif i == 3 then patch.Position = UDim2.new(0.01, 0, 0.51, 0)
            elseif i == 4 then patch.Position = UDim2.new(0.51, 0, 0.51, 0)
            end
        end
    end
    ProgressBarFill.Size = UDim2.new(0, 0, 1, 0)
    if PercentLabel then PercentLabel.Text = "CLEANLINESS: 0% (COVERED IN MUD)" end
    ScrubBtn.Text = "🧽 BRUSH SLUDGE OFF (+25%)"
    ScrubBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 90)
end

-----------------------------------------------------
-- EXECUTE THROW (With safe pcall to avoid soft-lock)
-----------------------------------------------------
executeThrow = function(chargeDuration)
    if isThrowing then return end
    isThrowing = true
    ThrowBtn.Text = "LAUNCHING..."
    ThrowBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local startPos = root and (root.Position + Vector3.new(0, 3, 3)) or Vector3.new(-55, -74, -12)

    local ok, res = pcall(function()
        return ThrowFoodRemote:InvokeServer(chargeDuration)
    end)

    if not ok or not res then
        showNotice("Throw communication error. Try again!", Color3.fromRGB(255, 90, 90))
        isThrowing = false
        ThrowBtn.Text = "HOLD TO CHARGE\nRELEASE TO THROW"
        ThrowBtn.BackgroundColor3 = Color3.fromRGB(240, 90, 40)
        return
    end

    if res.Success then
        hasEggInCleaner = true
        local feedback = res.IsSweetSpot and "🔥 SWEET SPOT LAUNCH! " or "LAUNCHED! "
        showNotice(feedback .. res.Distance .. " Studs reach! (" .. res.Zone.Name .. ")", res.IsSweetSpot and Color3.fromRGB(255, 220, 60) or Color3.fromRGB(140, 240, 255))

        local targetZ = -10 + res.Distance
        local targetPos = Vector3.new(-55, -73, targetZ)

        -- 1. Flying Food Projectile down red carpet
        local foodProjectile = Instance.new("Part")
        foodProjectile.Name = "FlyingFood"
        foodProjectile.Size = Vector3.new(3, 3, 3)
        foodProjectile.Shape = Enum.PartType.Ball
        foodProjectile.Color = res.Food.Color or Color3.fromRGB(255, 60, 60)
        foodProjectile.Material = Enum.Material.Neon
        foodProjectile.Anchored = true
        foodProjectile.CanCollide = false
        foodProjectile.CFrame = CFrame.new(startPos)
        foodProjectile.Parent = Workspace

        local trail = Instance.new("Trail", foodProjectile)
        local a0 = Instance.new("Attachment", foodProjectile)
        a0.Position = Vector3.new(0, 1.2, 0)
        local a1 = Instance.new("Attachment", foodProjectile)
        a1.Position = Vector3.new(0, -1.2, 0)
        trail.Attachment0 = a0
        trail.Attachment1 = a1
        trail.Color = ColorSequence.new(foodProjectile.Color, Color3.fromRGB(255, 255, 255))
        trail.Lifetime = 0.65

        local oldCamType = Camera.CameraType
        Camera.CameraType = Enum.CameraType.Scriptable

        local flightDuration = math.clamp(res.Distance / 1000 + 0.8, 1.0, 3.2)
        local tweenInfo = TweenInfo.new(flightDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(foodProjectile, tweenInfo, { CFrame = CFrame.new(targetPos) })
        tween:Play()

        local conn
        conn = RunService.RenderStepped:Connect(function()
            if foodProjectile and foodProjectile.Parent then
                Camera.CFrame = CFrame.new(foodProjectile.Position + Vector3.new(0, 8, -18), foodProjectile.Position + Vector3.new(0, 2, 20))
            else
                if conn then conn:Disconnect() end
            end
        end)

        tween.Completed:Connect(function()
            if conn then conn:Disconnect() end
            foodProjectile:Destroy()
            SoundHelper.Play("AnimalChomp")

            showNotice("CHOMP! " .. res.Zone.AnimalName .. " ate the food and laid an egg!", Color3.fromRGB(130, 255, 170))

            -- 2. Monster lays egg: Muddy sludge-covered egg clump swoops back to player's EggCleaner
            local cleaner = myPlotModel and myPlotModel:FindFirstChild("EggCleaner")
            local cleanerPos = cleaner and (cleaner:FindFirstChild("WashBasin") and cleaner.WashBasin.Position or (cleaner:IsA("Model") and cleaner:GetPivot().Position)) or Vector3.new(-184, -77.6, -22)
            local returningEgg = Instance.new("Part")
            returningEgg.Name = "ReturningEgg"
            returningEgg.Size = Vector3.new(3.5, 4.5, 3.5)
            returningEgg.Shape = Enum.PartType.Ball
            returningEgg.Color = Color3.fromRGB(65, 42, 24) -- Dark mud brown; completely covers true egg identity!
            returningEgg.Material = Enum.Material.Slate
            returningEgg.Anchored = true
            returningEgg.CanCollide = false
            returningEgg.CFrame = CFrame.new(targetPos)
            returningEgg.Parent = Workspace

            local returnTween = TweenService:Create(returningEgg, TweenInfo.new(1.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                CFrame = CFrame.new(cleanerPos)
            })
            returnTween:Play()

            Camera.CFrame = CFrame.new(cleanerPos + Vector3.new(0, 6, -14), cleanerPos)

            returnTween.Completed:Connect(function()
                returningEgg:Destroy()
                SoundHelper.Play("EggPop")

                task.wait(0.4)
                Camera.CameraType = oldCamType
                if character and character:FindFirstChild("Humanoid") then
                    Camera.CameraSubject = character.Humanoid
                end

                -- User requirement: Egg can only be cleaned in the cleaned section (NOT far away)
                -- Keep wash modal closed while at Launch Pad!
                WashModal.Visible = false
                showNotice("🫧 Monster laid a Muddy Egg! It landed in your Egg Cleaner! Walk to your base to scrub it clean!", Color3.fromRGB(255, 220, 80))

                isThrowing = false
                ThrowBtn.Text = "HOLD TO CHARGE\nRELEASE TO THROW"
                ThrowBtn.BackgroundColor3 = Color3.fromRGB(240, 90, 40)
            end)
        end)
    else
        showNotice(res.Message or "Throw failed!", Color3.fromRGB(255, 90, 90))
        isThrowing = false
        ThrowBtn.Text = "HOLD TO CHARGE\nRELEASE TO THROW"
        ThrowBtn.BackgroundColor3 = Color3.fromRGB(240, 90, 40)
    end
end

-----------------------------------------------------
-- TACTILE WASHING INTERACTION ("BRUSH IT OURSELVES")
-----------------------------------------------------
local function handleScrubStep()
    local res = CleanEggRemote:InvokeServer()
    if res and res.Success then
        local progress = res.Cleanliness / 100
        ProgressBarFill.Size = UDim2.new(progress, 0, 1, 0)
        if PercentLabel then
            PercentLabel.Text = "CLEANLINESS: " .. res.Cleanliness .. "%"
        end

        -- Smoothly dissolve thick mud and reveal clean shell
        EggContainer.BackgroundColor3 = Color3.fromRGB(
            math.floor(65 + (255 - 65) * progress),
            math.floor(42 + (225 - 42) * progress),
            math.floor(24 + (80 - 24) * progress)
        )

        if res.IsComplete then
            local eggStroke = EggContainer:FindFirstChildOfClass("UIStroke")
            if eggStroke then
                eggStroke.Color = Color3.fromRGB(255, 235, 90)
                eggStroke.Thickness = 2.5
            end
            EggContainer.BackgroundColor3 = Color3.fromRGB(255, 225, 80)
            ScrubBtn.Text = "🌱 PUT IN GARDEN TO GROW & HATCH! 🌱"
            ScrubBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
            showNotice("✨ EGG IS 100% PRISTINE & CLEAN! Tap to put in your Garden Yard!", Color3.fromRGB(255, 235, 90))
        else
            showNotice("Brushing mud & sludge off... " .. res.Cleanliness .. "% Clean", Color3.fromRGB(90, 220, 255))
        end
    else
        if res and res.Message then
            showNotice(res.Message, Color3.fromRGB(255, 100, 100))
        end
    end
end

for i = 1, 4 do
    local patch = EggContainer:FindFirstChild("DirtPatch_" .. i)
    if patch then
        local function scrubPatch()
            if patch.Visible then
                patch.Visible = false
                SoundHelper.Play("WaterSpray")
                handleScrubStep()
            end
        end
        patch.MouseButton1Click:Connect(scrubPatch)
        patch.MouseEnter:Connect(function()
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                scrubPatch()
            end
        end)
    end
end

ScrubBtn.MouseButton1Click:Connect(function()
    if ScrubBtn.Text:find("GARDEN") then
        local hatchRes = HatchEggRemote:InvokeServer()
        if hatchRes and hatchRes.Success then
            hasEggInCleaner = false
            showNotice("PLANTED! " .. hatchRes.Message .. " (+" .. hatchRes.Income .. " $/s in your Garden!)", Color3.fromRGB(120, 255, 150))
            WashModal.Visible = false
            updateUI()
        else
            showNotice(hatchRes.Message or "Hatching error", Color3.fromRGB(255, 80, 80))
        end
    else
        for i = 1, 4 do
            local patch = EggContainer:FindFirstChild("DirtPatch_" .. i)
            if patch and patch.Visible then
                patch.Visible = false
                break
            end
        end
        handleScrubStep()
    end
end)

-----------------------------------------------------
-- PET SANCTUARY INVENTORY MODAL (With Expand Slots Support)
-----------------------------------------------------
local function refreshPetModal()
    for _, child in ipairs(PetListScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local state = GetSanctuaryStateRemote:InvokeServer()
    if not state then return end

    local petCount = #(state.GardenPets or {})
    local maxSlots = state.MaxSlots or GameConfig.DefaultMaxSlots
    PetSummaryLabel.Text = "Pets: " .. petCount .. "/" .. maxSlots .. " • Total: +" .. state.TotalIncome .. " Bio-Essence/sec"

    -- Expand Slots Button
    if maxSlots < GameConfig.MaxSlotsCap then
        local cost = GameConfig.SlotUpgradeCost(maxSlots)
        local expandCard = Instance.new("Frame", PetListScroll)
        expandCard.Size = UDim2.new(1, -6, 0, 44)
        expandCard.BackgroundColor3 = Color3.fromRGB(35, 45, 65)
        local ecCorner = Instance.new("UICorner", expandCard)
        ecCorner.CornerRadius = UDim.new(0, 8)

        local expandBtn = Instance.new("TextButton", expandCard)
        expandBtn.Size = UDim2.new(1, 0, 1, 0)
        expandBtn.BackgroundTransparency = 1
        expandBtn.Font = Enum.Font.GothamBlack
        expandBtn.TextSize = 12
        expandBtn.TextColor3 = Color3.fromRGB(255, 220, 80)
        expandBtn.Text = "➕ EXPAND GARDEN SLOTS (+2) • Cost: " .. cost .. " $"
        expandBtn.MouseButton1Click:Connect(function()
            local res = ExpandSanctuaryRemote:InvokeServer()
            if res and res.Success then
                showNotice(res.Message, Color3.fromRGB(120, 255, 150))
                refreshPetModal()
                updateUI()
            else
                showNotice(res and res.Message or "Cannot expand slots", Color3.fromRGB(255, 90, 90))
            end
        end)
    end

    if petCount == 0 then
        local emptyLbl = Instance.new("TextLabel", PetListScroll)
        emptyLbl.Size = UDim2.new(1, 0, 0, 60)
        emptyLbl.BackgroundTransparency = 1
        emptyLbl.Font = Enum.Font.GothamMedium
        emptyLbl.TextSize = 13
        emptyLbl.TextColor3 = Color3.fromRGB(170, 180, 200)
        emptyLbl.Text = "No pets yet! Walk to the Launch Pad to throw food and grow eggs in your Garden!"
        return
    end

    for _, pet in ipairs(state.GardenPets) do
        local card = Instance.new("Frame", PetListScroll)
        card.Size = UDim2.new(1, -6, 0, 52)
        card.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
        local cCorner = Instance.new("UICorner", card)
        cCorner.CornerRadius = UDim.new(0, 8)

        local mutConfig = GameConfig.Mutations[pet.Mutation] or GameConfig.Mutations.Normal
        local cStroke = Instance.new("UIStroke", card)
        cStroke.Thickness = 1.5
        cStroke.Color = mutConfig.StrokeColor

        local info = Instance.new("TextLabel", card)
        info.Size = UDim2.new(1, -90, 1, 0)
        info.Position = UDim2.new(0, 12, 0, 0)
        info.BackgroundTransparency = 1
        info.Font = Enum.Font.GothamBlack
        info.TextSize = 12
        info.TextColor3 = Color3.fromRGB(255, 255, 255)
        info.TextXAlignment = Enum.TextXAlignment.Left
        local prefix = (pet.Mutation ~= "Normal") and (pet.Mutation .. " ") or ""
        info.Text = "🐾 " .. prefix .. pet.Name .. " (" .. (pet.Rarity or "Common") .. ")\nIncome: +" .. pet.Income .. " $/sec"

        -- Release button
        local releaseBtn = Instance.new("TextButton", card)
        releaseBtn.Size = UDim2.new(0, 70, 0, 30)
        releaseBtn.Position = UDim2.new(1, -78, 0.5, -15)
        releaseBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        local rCorner = Instance.new("UICorner", releaseBtn)
        rCorner.CornerRadius = UDim.new(0, 6)
        releaseBtn.Font = Enum.Font.GothamBold
        releaseBtn.TextSize = 11
        releaseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        releaseBtn.Text = "SELL"
        releaseBtn.MouseButton1Click:Connect(function()
            local res = ManagePetRemote:InvokeServer("Sell", pet.PetId)
            if res and res.Success then
                showNotice(res.Message, Color3.fromRGB(255, 220, 80))
                refreshPetModal()
                updateUI()
            end
        end)
    end
end

PetsNavBtn.MouseButton1Click:Connect(function()
    PetModal.Visible = not PetModal.Visible
    if PetModal.Visible then
        ShopModal.Visible = false
        refreshPetModal()
    end
end)

ClosePetBtn.MouseButton1Click:Connect(function()
    PetModal.Visible = false
end)

-----------------------------------------------------
-- CHEF SHOP MODAL
-----------------------------------------------------
local function refreshShopModal()
    for _, child in ipairs(FoodListScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local leaderstats = player:FindFirstChild("leaderstats")
    local currentTier = leaderstats and leaderstats:FindFirstChild("FoodTier") and leaderstats.FoodTier.Value or 1
    local currentBio = leaderstats and leaderstats:FindFirstChild("BioEssence") and leaderstats.BioEssence.Value or 0

    for i = 1, #GameConfig.Foods do
        local food = GameConfig.Foods[i]
        local card = Instance.new("Frame", FoodListScroll)
        card.Size = UDim2.new(1, -6, 0, 52)
        card.BackgroundColor3 = (i == currentTier) and Color3.fromRGB(30, 45, 60) or Color3.fromRGB(22, 28, 42)

        local cCorner = Instance.new("UICorner", card)
        cCorner.CornerRadius = UDim.new(0, 8)

        local cStroke = Instance.new("UIStroke", card)
        cStroke.Thickness = 1.5
        cStroke.Color = (i == currentTier) and Color3.fromRGB(120, 240, 160) or Color3.fromRGB(50, 70, 100)

        local info = Instance.new("TextLabel", card)
        info.Size = UDim2.new(0.65, 0, 1, 0)
        info.Position = UDim2.new(0, 12, 0, 0)
        info.BackgroundTransparency = 1
        info.Font = Enum.Font.GothamBlack
        info.TextSize = 12
        info.TextColor3 = Color3.fromRGB(255, 255, 255)
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.Text = "Tier " .. food.Tier .. ": " .. food.Name .. " (" .. food.Luck .. "x Luck)"

        local actionBtn = Instance.new("TextButton", card)
        actionBtn.Size = UDim2.new(0, 105, 0, 34)
        actionBtn.Position = UDim2.new(1, -115, 0.5, -17)
        local aCorner = Instance.new("UICorner", actionBtn)
        aCorner.CornerRadius = UDim.new(0, 6)
        actionBtn.Font = Enum.Font.GothamBold
        actionBtn.TextSize = 11

        if i == currentTier then
            actionBtn.Text = "EQUIPPED"
            actionBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 80)
            actionBtn.TextColor3 = Color3.fromRGB(200, 255, 200)
        elseif i < currentTier then
            actionBtn.Text = "UNLOCKED"
            actionBtn.BackgroundColor3 = Color3.fromRGB(50, 60, 80)
            actionBtn.TextColor3 = Color3.fromRGB(180, 190, 210)
        elseif i == currentTier + 1 then
            actionBtn.Text = "BUY (" .. food.Cost .. " $)"
            actionBtn.BackgroundColor3 = (currentBio >= food.Cost) and Color3.fromRGB(40, 160, 90) or Color3.fromRGB(120, 60, 60)
            actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            actionBtn.MouseButton1Click:Connect(function()
                local res = UpgradeFoodRemote:InvokeServer()
                if res and res.Success then
                    showNotice("UNLOCKED: " .. res.Food.Name .. "! (" .. res.Food.Luck .. "x Luck)", Color3.fromRGB(120, 255, 150))
                    updateUI()
                    refreshShopModal()
                else
                    showNotice(res.Message or "Cannot buy", Color3.fromRGB(255, 90, 90))
                end
            end)
        else
            actionBtn.Text = "LOCKED (" .. food.Cost .. " $)"
            actionBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
            actionBtn.TextColor3 = Color3.fromRGB(120, 130, 150)
        end
    end
end

ShopBtn.MouseButton1Click:Connect(function()
    ShopModal.Visible = not ShopModal.Visible
    if ShopModal.Visible then
        PetModal.Visible = false
        refreshShopModal()
    end
end)

CloseShopBtn.MouseButton1Click:Connect(function()
    ShopModal.Visible = false
end)

-----------------------------------------------------
-- AUTOMATED BICEP CURL WORKOUT SYSTEM
-----------------------------------------------------
-- Floating Billboard for +10 REACH popups
local function spawnFloatingText(text, color)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local bill = Instance.new("BillboardGui")
    bill.Size = UDim2.new(0, 240, 0, 50)
    bill.StudsOffset = Vector3.new(0, 3.2, 0)
    bill.AlwaysOnTop = true
    bill.Adornee = hrp
    bill.Parent = hrp

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextSize = 22
    lbl.TextColor3 = color or Color3.fromRGB(255, 180, 50)
    lbl.TextStrokeColor3 = Color3.fromRGB(20, 20, 25)
    lbl.TextStrokeTransparency = 0.2
    lbl.Parent = bill

    task.spawn(function()
        local twPos = TweenService:Create(bill, TweenInfo.new(0.85, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            StudsOffset = Vector3.new(0, 5.8, 0)
        })
        local twFade = TweenService:Create(lbl, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            TextTransparency = 1,
            TextStrokeTransparency = 1
        })
        twPos:Play()
        twFade:Play()
        task.wait(0.9)
        bill:Destroy()
    end)
end

-- Create cosmetic hand dumbbells during auto-workout
local function createWorkoutDumbbells(char)
    local rHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
    local lHand = char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm")
    if not (rHand and lHand) then return nil end

    local container = Instance.new("Model")
    container.Name = "WorkoutDumbbells"

    local function makeDumbbell(handPart)
        local dumbbell = Instance.new("Model")
        dumbbell.Name = "HandDumbbell"

        local handle = Instance.new("Part")
        handle.Name = "Handle"
        handle.Shape = Enum.PartType.Cylinder
        handle.Size = Vector3.new(0.85, 0.16, 0.16)
        handle.Material = Enum.Material.Metal
        handle.Color = Color3.fromRGB(210, 210, 220)
        handle.CanCollide = false
        handle.Massless = true
        handle.CastShadow = false
        handle.CFrame = handPart.CFrame * CFrame.Angles(0, 0, math.rad(90))
        handle.Parent = dumbbell

        for _, offset in ipairs({ -0.38, 0.38 }) do
            local plate = Instance.new("Part")
            plate.Name = "Plate"
            plate.Shape = Enum.PartType.Cylinder
            plate.Size = Vector3.new(0.2, 0.6, 0.6)
            plate.Material = Enum.Material.SmoothPlastic
            plate.Color = Color3.fromRGB(35, 35, 40)
            plate.CanCollide = false
            plate.Massless = true
            plate.CastShadow = false
            plate.CFrame = handle.CFrame * CFrame.new(offset, 0, 0)
            plate.Parent = dumbbell

            local w = Instance.new("WeldConstraint")
            w.Part0 = handle
            w.Part1 = plate
            w.Parent = handle
        end

        local weld = Instance.new("WeldConstraint")
        weld.Part0 = handPart
        weld.Part1 = handle
        weld.Parent = handle

        dumbbell.Parent = container
    end

    makeDumbbell(rHand)
    makeDumbbell(lHand)

    container.Parent = char
    return container
end

-- Helper to find avatar arm joints (compatible with R15 AnimationConstraints/Motor6D and R6)
local function getArmJoint(char, partName, jointName)
    local part = char:FindFirstChild(partName)
    if part then
        local j = part:FindFirstChild(jointName)
        if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then return j end
    end
    for _, d in ipairs(char:GetDescendants()) do
        if d.Name == jointName and (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) then return d end
    end
    return nil
end

-- Workout HUD Card
local WorkoutHud = Instance.new("Frame")
WorkoutHud.Name = "WorkoutHud"
WorkoutHud.Size = UDim2.new(0, 360, 0, 115)
WorkoutHud.Position = UDim2.new(0.5, -180, 0.82, -125)
WorkoutHud.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
WorkoutHud.BackgroundTransparency = 0.1
WorkoutHud.BorderSizePixel = 0
WorkoutHud.Visible = false
WorkoutHud.Parent = HUD

local whCorner = Instance.new("UICorner")
whCorner.CornerRadius = UDim.new(0, 14)
whCorner.Parent = WorkoutHud

local whStroke = Instance.new("UIStroke")
whStroke.Color = Color3.fromRGB(255, 140, 40)
whStroke.Thickness = 2.5
whStroke.Parent = WorkoutHud

local WhTitle = Instance.new("TextLabel")
WhTitle.Name = "Title"
WhTitle.Size = UDim2.new(1, 0, 0, 26)
WhTitle.Position = UDim2.new(0, 0, 0, 6)
WhTitle.BackgroundTransparency = 1
WhTitle.Text = "💪 BICEP CURL (AUTO-WORKOUT)"
WhTitle.Font = Enum.Font.GothamBold
WhTitle.TextSize = 16
WhTitle.TextColor3 = Color3.fromRGB(255, 190, 60)
WhTitle.Parent = WorkoutHud

local WhStatus = Instance.new("TextLabel")
WhStatus.Name = "Status"
WhStatus.Size = UDim2.new(1, 0, 0, 20)
WhStatus.Position = UDim2.new(0, 0, 0, 30)
WhStatus.BackgroundTransparency = 1
WhStatus.Text = "Reps: 0  •  Reach Gained: +0 Studs"
WhStatus.Font = Enum.Font.GothamMedium
WhStatus.TextSize = 13
WhStatus.TextColor3 = Color3.fromRGB(220, 230, 245)
WhStatus.Parent = WorkoutHud

local WhProgressBg = Instance.new("Frame")
WhProgressBg.Name = "ProgressBg"
WhProgressBg.Size = UDim2.new(1, -28, 0, 8)
WhProgressBg.Position = UDim2.new(0, 14, 0, 54)
WhProgressBg.BackgroundColor3 = Color3.fromRGB(38, 42, 54)
WhProgressBg.BorderSizePixel = 0
WhProgressBg.Parent = WorkoutHud

local whpCorner = Instance.new("UICorner")
whpCorner.CornerRadius = UDim.new(0, 4)
whpCorner.Parent = WhProgressBg

local WhProgressFill = Instance.new("Frame")
WhProgressFill.Name = "Fill"
WhProgressFill.Size = UDim2.new(0, 0, 1, 0)
WhProgressFill.BackgroundColor3 = Color3.fromRGB(255, 140, 40)
WhProgressFill.BorderSizePixel = 0
WhProgressFill.Parent = WhProgressBg

local whfCorner = Instance.new("UICorner")
whfCorner.CornerRadius = UDim.new(0, 4)
whfCorner.Parent = WhProgressFill

local WhExitBtn = Instance.new("TextButton")
WhExitBtn.Name = "ExitBtn"
WhExitBtn.Size = UDim2.new(1, -28, 0, 34)
WhExitBtn.Position = UDim2.new(0, 14, 0, 68)
WhExitBtn.BackgroundColor3 = Color3.fromRGB(215, 55, 45)
WhExitBtn.Text = "STOP WORKOUT [SPACE / WASD / E]"
WhExitBtn.Font = Enum.Font.GothamBold
WhExitBtn.TextSize = 13
WhExitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
WhExitBtn.Parent = WorkoutHud

local wheCorner = Instance.new("UICorner")
wheCorner.CornerRadius = UDim.new(0, 8)
wheCorner.Parent = WhExitBtn

local isWorkingOut = false
local currentWorkoutThread = nil
local workoutDumbbells = nil
local workoutReps = 0
local activePrompt = nil

local function stopAutoWorkout()
    if not isWorkingOut then return end
    isWorkingOut = false

    local char = player.Character
    if char then
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
        end
    end

    if workoutDumbbells then
        workoutDumbbells:Destroy()
        workoutDumbbells = nil
    end

    WorkoutHud.Visible = false

    if activePrompt then
        activePrompt.ActionText = "Start Auto-Workout (+10 Reach/rep)"
    end

    if workoutReps > 0 then
        showNotice("💪 Great set! Completed " .. workoutReps .. " reps (+" .. (workoutReps * 10) .. " Reach)!", Color3.fromRGB(100, 255, 140))
    else
        showNotice("Workout stopped.", Color3.fromRGB(200, 200, 200))
    end
    updateUI()
end

WhExitBtn.MouseButton1Click:Connect(stopAutoWorkout)

UserInputService.InputBegan:Connect(function(input, gpe)
    if not isWorkingOut then return end
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Space
       or input.KeyCode == Enum.KeyCode.W
       or input.KeyCode == Enum.KeyCode.A
       or input.KeyCode == Enum.KeyCode.S
       or input.KeyCode == Enum.KeyCode.D
       or input.KeyCode == Enum.KeyCode.E then
        stopAutoWorkout()
    end
end)

UserInputService.JumpRequest:Connect(function()
    if isWorkingOut then
        stopAutoWorkout()
    end
end)

player.CharacterRemoving:Connect(function()
    if isWorkingOut then
        stopAutoWorkout()
    end
end)

local function startAutoWorkout(station, prompt)
    if isWorkingOut then
        stopAutoWorkout()
        return
    end

    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not (humanoid and hrp) then return end

    -- Locate joints
    local re = getArmJoint(char, "RightLowerArm", "RightElbow")
    local rs = getArmJoint(char, "RightUpperArm", "RightShoulder")
    local le = getArmJoint(char, "LeftLowerArm", "LeftElbow")
    local ls = getArmJoint(char, "LeftUpperArm", "LeftShoulder")
    local r6R = getArmJoint(char, "Torso", "Right Shoulder")
    local r6L = getArmJoint(char, "Torso", "Left Shoulder")

    local origRE = re and (re:IsA("AnimationConstraint") and re.Attachment0.CFrame or re.C0)
    local origRS = rs and (rs:IsA("AnimationConstraint") and rs.Attachment0.CFrame or rs.C0)
    local origLE = le and (le:IsA("AnimationConstraint") and le.Attachment0.CFrame or le.C0)
    local origLS = ls and (ls:IsA("AnimationConstraint") and ls.Attachment0.CFrame or ls.C0)
    local origR6R = r6R and r6R.C0
    local origR6L = r6L and r6L.C0

    -- Position on curl seat facing arm pad
    if station then
        local seat = station:FindFirstChild("CurlSeat")
        local armPad = station:FindFirstChild("ArmPad")
        if seat and armPad then
            local look = (armPad.Position - seat.Position) * Vector3.new(1, 0, 1)
            if look.Magnitude > 0 then
                hrp.CFrame = CFrame.new(seat.Position + Vector3.new(0, 1.5, 0), seat.Position + Vector3.new(0, 1.5, 0) + look.Unit)
            end
        end
    end

    humanoid.WalkSpeed = 0
    workoutDumbbells = createWorkoutDumbbells(char)
    workoutReps = 0
    activePrompt = prompt
    if activePrompt then
        activePrompt.ActionText = "Stop Workout"
    end

    WorkoutHud.Visible = true
    WhStatus.Text = "Reps: 0  •  Reach Gained: +0 Studs"
    WhProgressFill.Size = UDim2.new(0, 0, 1, 0)
    isWorkingOut = true

    showNotice("💪 Auto-Workout Started! Curling dumbbells...", Color3.fromRGB(255, 170, 50))

    currentWorkoutThread = task.spawn(function()
        while isWorkingOut do
            -- Phase 1: Curl Up (0.55s)
            local t0 = os.clock()
            while isWorkingOut and (os.clock() - t0) < 0.55 do
                local p = math.clamp((os.clock() - t0) / 0.55, 0, 1)
                local eased = math.sin(p * (math.pi / 2))
                WhProgressFill.Size = UDim2.new(eased * 0.7, 0, 1, 0)

                local curlAngle = math.rad(115 * eased)
                local shoulderAngle = math.rad(25 * eased)

                if re then
                    if re:IsA("AnimationConstraint") then
                        re.Attachment0.CFrame = origRE * CFrame.Angles(curlAngle, 0, 0)
                        rs.Attachment0.CFrame = origRS * CFrame.Angles(shoulderAngle, 0, 0)
                        le.Attachment0.CFrame = origLE * CFrame.Angles(curlAngle, 0, 0)
                        ls.Attachment0.CFrame = origLS * CFrame.Angles(shoulderAngle, 0, 0)
                    else
                        re.C0 = origRE * CFrame.Angles(curlAngle, 0, 0)
                        rs.C0 = origRS * CFrame.Angles(shoulderAngle, 0, 0)
                        le.C0 = origLE * CFrame.Angles(curlAngle, 0, 0)
                        ls.C0 = origLS * CFrame.Angles(shoulderAngle, 0, 0)
                    end
                elseif r6R and r6L then
                    r6R.C0 = origR6R * CFrame.Angles(curlAngle, 0, 0)
                    r6L.C0 = origR6L * CFrame.Angles(curlAngle, 0, 0)
                end

                task.wait(0.03)
            end

            if not isWorkingOut then break end

            -- Phase 2: Peak squeeze (0.15s)
            WhProgressFill.Size = UDim2.new(0.8, 0, 1, 0)
            task.wait(0.15)

            if not isWorkingOut then break end

            -- Phase 3: Lower Down (0.60s)
            local t1 = os.clock()
            while isWorkingOut and (os.clock() - t1) < 0.60 do
                local p = math.clamp((os.clock() - t1) / 0.60, 0, 1)
                local eased = 1 - math.sin(p * (math.pi / 2))
                WhProgressFill.Size = UDim2.new(0.8 + (1 - eased) * 0.2, 0, 1, 0)

                local curlAngle = math.rad(115 * eased)
                local shoulderAngle = math.rad(25 * eased)

                if re then
                    if re:IsA("AnimationConstraint") then
                        re.Attachment0.CFrame = origRE * CFrame.Angles(curlAngle, 0, 0)
                        rs.Attachment0.CFrame = origRS * CFrame.Angles(shoulderAngle, 0, 0)
                        le.Attachment0.CFrame = origLE * CFrame.Angles(curlAngle, 0, 0)
                        ls.Attachment0.CFrame = origLS * CFrame.Angles(shoulderAngle, 0, 0)
                    else
                        re.C0 = origRE * CFrame.Angles(curlAngle, 0, 0)
                        rs.C0 = origRS * CFrame.Angles(shoulderAngle, 0, 0)
                        le.C0 = origLE * CFrame.Angles(curlAngle, 0, 0)
                        ls.C0 = origLS * CFrame.Angles(shoulderAngle, 0, 0)
                    end
                elseif r6R and r6L then
                    r6R.C0 = origR6R * CFrame.Angles(curlAngle, 0, 0)
                    r6L.C0 = origR6L * CFrame.Angles(curlAngle, 0, 0)
                end

                task.wait(0.03)
            end

            if not isWorkingOut then break end

            -- REPETITION COMPLETE!
            workoutReps += 1
            WhProgressFill.Size = UDim2.new(1, 0, 1, 0)

            -- Award Strength via Server
            local res = TrainStrengthRemote:InvokeServer()
            if res and res.Success then
                local newStr = res.NewStrength or 160
                local milestone = GameConfig.GetNextZoneMilestone(newStr)
                local milestoneText = ""
                if not milestone.IsMax and milestone.NextZone then
                    milestoneText = "  •  " .. milestone.RepsNeeded .. " reps to " .. milestone.NextZone.Name .. "!"
                else
                    milestoneText = "  •  MAX ZONE UNLOCKED!"
                end
                spawnFloatingText("💪 +10 REACH! (Rep " .. workoutReps .. ")", Color3.fromRGB(255, 175, 40))
                WhStatus.Text = "Reps: " .. workoutReps .. "  •  Reach: " .. newStr .. " Studs" .. milestoneText
                updateUI()
            else
                showNotice(res and res.Message or "Pacing rest...", Color3.fromRGB(255, 140, 100))
            end

            task.wait(0.05)
            WhProgressFill.Size = UDim2.new(0, 0, 1, 0)
        end

        -- Clean joint reset on finish
        if re then
            if re:IsA("AnimationConstraint") then
                re.Attachment0.CFrame = origRE
                rs.Attachment0.CFrame = origRS
                le.Attachment0.CFrame = origLE
                ls.Attachment0.CFrame = origLS
            else
                re.C0 = origRE
                rs.C0 = origRS
                le.C0 = origLE
                ls.C0 = origLS
            end
        elseif r6R and r6L then
            r6R.C0 = origR6R
            r6L.C0 = origR6L
        end
    end)
end

-- Connect in-world ProximityPrompts for Bicep Curl Station
local ProximityPromptService = game:GetService("ProximityPromptService")
ProximityPromptService.PromptTriggered:Connect(function(prompt, inputPlayer)
    if inputPlayer ~= player then return end
    if prompt.ObjectText == "Bicep Curl Station" or (prompt.Parent and prompt.Parent.Parent and prompt.Parent.Parent.Name == "BicepCurlStation") then
        if isWorkingOut then
            stopAutoWorkout()
        else
            local station = prompt.Parent and prompt.Parent.Parent
            startAutoWorkout(station, prompt)
        end
    end
end)

-- Gym Navigation Button on HUD
GymNavBtn.MouseButton1Click:Connect(function()
    if isWorkingOut then
        stopAutoWorkout()
        return
    end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local bases = Workspace:FindFirstChild("EggSanctuaryMap") and Workspace.EggSanctuaryMap:FindFirstChild("MultiplayerBases")
    local nearestStation = nil
    local nearestPrompt = nil
    local nearestDist = 9999
    if bases then
        for _, b in ipairs(bases:GetChildren()) do
            local s = b:FindFirstChild("BicepCurlStation")
            if s and s:FindFirstChild("InteractPart") then
                local dist = (hrp.Position - s.InteractPart.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearestStation = s
                    nearestPrompt = s.InteractPart:FindFirstChildOfClass("ProximityPrompt")
                end
            end
        end
    end

    if nearestStation and nearestDist <= 22 then
        startAutoWorkout(nearestStation, nearestPrompt)
    else
        showNotice("Walk over to the Bicep Curl Station in your plot to auto-train!", Color3.fromRGB(255, 180, 100))
    end
end)

-- Connect Dumbbell Tool in backpack and character
local function setupDumbbell(t)
    if t:IsA("Tool") and t.Name == "Dumbbell" then
        t.Activated:Connect(function()
            if isWorkingOut then
                stopAutoWorkout()
                return
            end

            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            local bases = Workspace:FindFirstChild("EggSanctuaryMap") and Workspace.EggSanctuaryMap:FindFirstChild("MultiplayerBases")
            local nearestStation = nil
            local nearestPrompt = nil
            local nearestDist = 9999
            if bases then
                for _, b in ipairs(bases:GetChildren()) do
                    local s = b:FindFirstChild("BicepCurlStation")
                    if s and s:FindFirstChild("InteractPart") then
                        local dist = (hrp.Position - s.InteractPart.Position).Magnitude
                        if dist < nearestDist then
                            nearestDist = dist
                            nearestStation = s
                            nearestPrompt = s.InteractPart:FindFirstChildOfClass("ProximityPrompt")
                        end
                    end
                end
            end

            if nearestStation and nearestDist <= 22 then
                startAutoWorkout(nearestStation, nearestPrompt)
            else
                showNotice("Go to the Bicep Curl Station to start your automated workout!", Color3.fromRGB(255, 180, 100))
            end
        end)
    end
end

player.Backpack.ChildAdded:Connect(setupDumbbell)
for _, t in ipairs(player.Backpack:GetChildren()) do setupDumbbell(t) end

player.CharacterAdded:Connect(function(char)
    char.ChildAdded:Connect(setupDumbbell)
    for _, t in ipairs(char:GetChildren()) do setupDumbbell(t) end
end)
if player.Character then
    player.Character.ChildAdded:Connect(setupDumbbell)
    for _, t in ipairs(player.Character:GetChildren()) do setupDumbbell(t) end
end

-----------------------------------------------------
-- CLIENT-SIDE PET ANIMATION (Handled by PetShowcaseAnimator)
-----------------------------------------------------
-- Living breathing, roaming, multi-tail wave sway & ambient station motion
-- are powered at 60 FPS by PetShowcaseAnimator!

print("[EggSanctuary] Client v8.0 Fully Hardened & Audited Engine Loaded!")
