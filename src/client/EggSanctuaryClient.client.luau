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
local ThrowFoodRemote = Remotes:WaitForChild("ThrowFood")
local CleanEggRemote = Remotes:WaitForChild("CleanEgg")
local HatchEggRemote = Remotes:WaitForChild("HatchEgg")
local UpgradeFoodRemote = Remotes:WaitForChild("UpgradeFood")
local GetSanctuaryStateRemote = Remotes:WaitForChild("GetSanctuaryState")
local StartChargeRemote = Remotes:WaitForChild("StartCharge")

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
local myPlotX = -150

local PLOT_X_POSITIONS = {-150, -90, -30, 30, 90, 150}

local isAtLaunchZone = false
local isCharging = false
local isThrowing = false
local chargeStartTime = 0
local landingPreviewPart = nil
local hasEggInCleaner = false

local function showNotice(text, color)
    NoticeLabel.Text = text
    NoticeLabel.TextColor3 = color or Color3.fromRGB(255, 255, 120)
    NoticeLabel.Visible = true

    NoticeLabel.Size = UDim2.new(0, 460, 0, 36)
    TweenService:Create(NoticeLabel, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 440, 0, 32)
    }):Play()
end

local function resolvePlot()
    local state = GetSanctuaryStateRemote:InvokeServer()
    if state and state.PlotId then
        myPlotId = state.PlotId
        hasEggInCleaner = state.HasEgg
        myPlotX = PLOT_X_POSITIONS[myPlotId] or -150
    end

    local bases = Workspace:FindFirstChild("EggSanctuaryMap") and Workspace.EggSanctuaryMap:FindFirstChild("MultiplayerBases")
    if bases then
        myPlotModel = bases:FindFirstChild("PlayerBase_" .. myPlotId)
        if myPlotModel then
            local cleaner = myPlotModel:FindFirstChild("EggCleaner")
            local basin = cleaner and cleaner:FindFirstChild("WashBasin")
            local prompt = basin and basin:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                prompt.Triggered:Connect(function()
                    WashModal.Visible = true
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
    end
end
task.spawn(resolvePlot)

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

task.spawn(function()
    while true do
        updateUI()
        task.wait(0.5)
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
local function setMeterSegments(activeCount, text, arrowYNorm)
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
        -- Move ArrowTag vertically alongside the active segment
        local yPos = UDim2.new(1, 10, 1, - (activeCount - 0.5) * 41)
        ArrowTag.Position = yPos
    else
        ArrowTag.Visible = false
    end
end

local function startCharge()
    if not isAtLaunchZone then
        showNotice("👉 Walk forward to the Yellow Launch Pad to throw!", Color3.fromRGB(255, 200, 100))
        return
    end
    if isThrowing or isCharging then return end

    isCharging = true
    chargeStartTime = os.clock()
    StartChargeRemote:FireServer()

    ThrowBtn.Text = "CHARGING...\nRELEASE TO THROW!"
    ThrowBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 20)
    SoundHelper.Play("ThrowWhoosh")
end

local function endCharge()
    if not isCharging then return end
    isCharging = false
    removeLandingMarker()

    setMeterSegments(0)
    ThrowBtn.Text = "HOLD TO CHARGE\nRELEASE TO THROW"
    ThrowBtn.BackgroundColor3 = Color3.fromRGB(240, 90, 40)

    if not isAtLaunchZone then
        showNotice("Left Launch Zone - Throw Cancelled!", Color3.fromRGB(255, 120, 100))
        return
    end

    executeThrow()
end

-- RenderStepped Location & Segment Charge Tracker
RunService.RenderStepped:Connect(function()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if root then
        local pos = root.Position
        -- Generous launch zone: Z between -5 and 30, and |X| <= 90
        local inZone = (pos.Z >= -24 and pos.Z <= 4 and pos.X >= -75 and pos.X <= -35)

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

    -- Update 6 Segments if charging
    if isCharging then
        local elapsed = os.clock() - chargeStartTime
        local leaderstats = player:FindFirstChild("leaderstats")
        local strength = leaderstats and leaderstats:FindFirstChild("Strength") and leaderstats.Strength.Value or 150
        local projectedDist = math.floor(strength * 0.5)

        if elapsed <= 0.25 then
            setMeterSegments(1, "<| x0.5 TAP")
            projectedDist = math.floor(strength * 0.50)
        elseif elapsed <= 0.65 then
            setMeterSegments(2, "<| x0.7 SPEED")
            projectedDist = math.floor(strength * 0.70)
        elseif elapsed <= 1.05 then
            setMeterSegments(3, "<| x0.85 SPEED")
            projectedDist = math.floor(strength * 0.85)
        elseif elapsed <= 1.45 then
            setMeterSegments(4, "<| x1.0 FULL")
            projectedDist = math.floor(strength * 1.0)
        elseif elapsed <= 1.90 then
            -- GOLDEN SWEET SPOT (Segment 5)
            setMeterSegments(5, "<| x1.25 SWEET SPOT! 🔥")
            projectedDist = math.floor(strength * 1.25)
        else
            -- OVERCHARGE (Segment 6)
            setMeterSegments(6, "<| x0.9 OVERCHARGE")
            projectedDist = math.floor(strength * 0.90)
        end

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
-- RESET WASH MODAL
-----------------------------------------------------
local function resetWashModal()
    EggContainer.BackgroundColor3 = Color3.fromRGB(115, 85, 55)
    for i = 1, 4 do
        local patch = EggContainer:FindFirstChild("DirtPatch_" .. i)
        if patch then
            patch.Visible = true
            patch.TextTransparency = 0
            patch.BackgroundTransparency = 0
        end
    end
    ProgressBarFill.Size = UDim2.new(0, 0, 1, 0)
    if PercentLabel then PercentLabel.Text = "CLEANLINESS: 0%" end
    ScrubBtn.Text = "🧽 BRUSH DIRT OFF (+25%)"
    ScrubBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 90)
end

-----------------------------------------------------
-- EXECUTE THROW
-----------------------------------------------------
function executeThrow()
    if isThrowing then return end
    isThrowing = true
    ThrowBtn.Text = "LAUNCHING..."
    ThrowBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local startPos = root and (root.Position + Vector3.new(0, 3, 3)) or Vector3.new(myPlotX, 5, 20)

    local res = ThrowFoodRemote:InvokeServer()
    if res and res.Success then
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

            -- 2. Monster lays egg: Golden Egg swoops back to player's EggCleaner
            local cleaner = myPlotModel and myPlotModel:FindFirstChild("EggCleaner")
            local cleanerPos = cleaner and (cleaner:FindFirstChild("WashBasin") and cleaner.WashBasin.Position or (cleaner:IsA("Model") and cleaner:GetPivot().Position)) or Vector3.new(-184, -77.6, -22)
            local returningEgg = Instance.new("Part")
            returningEgg.Name = "ReturningEgg"
            returningEgg.Size = Vector3.new(3, 4, 3)
            returningEgg.Shape = Enum.PartType.Ball
            returningEgg.Color = Color3.fromRGB(255, 215, 80)
            returningEgg.Material = Enum.Material.Neon
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

                resetWashModal()
                WashModal.Visible = true
                showNotice("🫧 Dirty Egg Delivered to Egg Cleaner! Brush it clean!", Color3.fromRGB(255, 230, 100))

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

        EggContainer.BackgroundColor3 = Color3.fromRGB(
            math.floor(115 + (240 - 115) * progress),
            math.floor(85 + (240 - 85) * progress),
            math.floor(55 + (250 - 55) * progress)
        )

        if res.IsComplete then
            ScrubBtn.Text = "🌱 PUT IN GARDEN TO GROW & HATCH! 🌱"
            ScrubBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
            showNotice("EGG IS PRISTINE! Tap to put in your Garden Yard!", Color3.fromRGB(255, 235, 90))
        else
            showNotice("Brushing dirt off... " .. res.Cleanliness .. "% Clean", Color3.fromRGB(90, 220, 255))
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
-- PET SANCTUARY INVENTORY MODAL
-----------------------------------------------------
local function refreshPetModal()
    for _, child in ipairs(PetListScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local state = GetSanctuaryStateRemote:InvokeServer()
    if not state then return end

    local petCount = #(state.GardenPets or {})
    PetSummaryLabel.Text = "Pets in Garden: " .. petCount .. " • Total: +" .. state.TotalIncome .. " Bio-Essence/sec"

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

        local cStroke = Instance.new("UIStroke", card)
        cStroke.Thickness = 1.5
        if pet.Mutation == "Rainbow" then
            cStroke.Color = Color3.fromRGB(255, 90, 240)
        elseif pet.Mutation == "Golden" then
            cStroke.Color = Color3.fromRGB(255, 215, 0)
        elseif pet.Mutation == "Shiny" then
            cStroke.Color = Color3.fromRGB(120, 220, 255)
        else
            cStroke.Color = Color3.fromRGB(80, 100, 140)
        end

        local info = Instance.new("TextLabel", card)
        info.Size = UDim2.new(1, -20, 1, 0)
        info.Position = UDim2.new(0, 12, 0, 0)
        info.BackgroundTransparency = 1
        info.Font = Enum.Font.GothamBlack
        info.TextSize = 12
        info.TextColor3 = Color3.fromRGB(255, 255, 255)
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.Text = "🐾 " .. pet.Mutation .. " " .. pet.Name .. " (" .. pet.Rarity .. ")\nIncome: +" .. pet.Income .. " $/sec"
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

GymNavBtn.MouseButton1Click:Connect(function()
    local res = TrainStrengthRemote:InvokeServer()
    if res and res.Success then
        showNotice("WORKOUT! +10 Reach (" .. res.NewStrength .. " Studs)", Color3.fromRGB(255, 140, 80))
        updateUI()
    elseif res and res.Message then
        showNotice(res.Message, Color3.fromRGB(255, 200, 100))
    end
end)

print("[EggSanctuary] Client v7.0 Segmented Throw UI & Fenced Garden Engine Loaded!")
