--!strict
-----------------------------------------------------
-- EGG SANCTUARY: 3D EGG RESTORATION & POWER WASH SYSTEM
-- High-Satisfaction 3D Surface Cleaning, Pop-Out Physics & Progression
-----------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local SoundHelper = require(Modules:WaitForChild("SoundHelper"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CleanEggRemote = Remotes:WaitForChild("CleanEgg")
local HatchEggRemote = Remotes:WaitForChild("HatchEgg")
local UpgradeCleanerRemote = Remotes:WaitForChild("UpgradeCleaner")
local GetSanctuaryStateRemote = Remotes:WaitForChild("GetSanctuaryState")

-----------------------------------------------------
-- STATE VARIABLES
-----------------------------------------------------
local isRestoring = false
local isSpraying = false
local currentEggData = nil
local currentCrustConfig = nil
local cleanerUpgrades = { PSILevel = 1, WidthLevel = 1, Tier = 1 }

local cleanedChunksCount = 0
local totalChunks = GameConfig.TotalEggChunks or 30
local dirtChunks = {} -- list of chunk records

-- 3D Models in World
local stageFolder = nil
local turntableRoot = nil
local eggCore = nil
local wandModel = nil
local nozzleAttachment = nil
local waterBeam = nil
local splashEmitter = nil
local impactLight = nil
local targetAttachment = nil

-- Rotation Controls
local turntableYaw = 0
local turntablePitch = 0
local isDragging = false
local dragStartPos = Vector2.zero
local dragStartYaw = 0
local dragStartPitch = 0

-- Original Camera & Character State
local savedCamCFrame = nil
local savedCamType = nil
local originalWalkSpeed = 16
local originalJumpPower = 50

-- UI Elements
local RestorationGui = nil
local ProgressFill = nil
local PercentLabel = nil
local ChunksRemainingLabel = nil
local StatusPill = nil
local SprayPromptBtn = nil
local ActionBtn = nil
local UpgradesModal = nil

-----------------------------------------------------
-- AUDIO HELPER
-----------------------------------------------------
local function playSfx(name, vol)
    pcall(function()
        SoundHelper.Play(name)
    end)
end

-----------------------------------------------------
-- 3D WAND VIEWMODEL BUILDER
-----------------------------------------------------
local function buildWasherWand(tier)
    tier = tier or 1
    local tierCfg = GameConfig.CleanerUpgrades.Tier[tier] or GameConfig.CleanerUpgrades.Tier[1]

    local wand = Instance.new("Model")
    wand.Name = "PowerWasherWand"

    -- Main wand shaft
    local shaft = Instance.new("Part")
    shaft.Name = "Shaft"
    shaft.Shape = Enum.PartType.Cylinder
    shaft.Size = Vector3.new(2.4, 0.22, 0.22)
    shaft.Material = tierCfg.Material or Enum.Material.SmoothPlastic
    shaft.Color = tierCfg.Color or Color3.fromRGB(50, 160, 220)
    shaft.Anchored = true
    shaft.CanCollide = false
    shaft.CastShadow = false
    shaft.Parent = wand

    -- Handle grip
    local grip = Instance.new("Part")
    grip.Name = "Grip"
    grip.Size = Vector3.new(0.35, 0.85, 0.35)
    grip.Material = Enum.Material.Rubber
    grip.Color = Color3.fromRGB(30, 30, 35)
    grip.Anchored = true
    grip.CanCollide = false
    grip.CastShadow = false
    grip.Parent = wand

    -- Pressure Nozzle Tip
    local nozzle = Instance.new("Part")
    nozzle.Name = "Nozzle"
    nozzle.Shape = Enum.PartType.Cylinder
    nozzle.Size = Vector3.new(0.5, 0.18, 0.18)
    nozzle.Material = Enum.Material.Metal
    nozzle.Color = (tier >= 2) and Color3.fromRGB(225, 185, 50) or Color3.fromRGB(180, 180, 190)
    nozzle.Anchored = true
    nozzle.CanCollide = false
    nozzle.CastShadow = false
    nozzle.Parent = wand

    local nozzleAtt = Instance.new("Attachment")
    nozzleAtt.Name = "NozzleTip"
    nozzleAtt.Position = Vector3.new(0.25, 0, 0)
    nozzleAtt.Parent = nozzle

    -- Mist emitter at nozzle
    local mist = Instance.new("ParticleEmitter")
    mist.Name = "NozzleMist"
    mist.Rate = 0
    mist.Speed = NumberRange.new(8, 14)
    mist.Lifetime = NumberRange.new(0.12, 0.22)
    mist.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 0.8)
    })
    mist.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 1)
    })
    mist.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
    mist.Parent = nozzleAtt

    wand.PrimaryPart = shaft
    return wand, nozzleAtt, mist
end

-----------------------------------------------------
-- 3D DIRT CRUST & EGG CORE BUILDER
-----------------------------------------------------
local function build3DEggAndCrust(eggData, centerPos)
    local zoneId = 1
    for i, z in ipairs(GameConfig.Zones) do
        if z.Name == eggData.ZoneName or z.AnimalName == eggData.AnimalName then
            zoneId = i
            break
        end
    end

    local crustCfg = GameConfig.EggCrusts[zoneId] or GameConfig.EggCrusts[1]
    currentCrustConfig = crustCfg

    local folder = Instance.new("Folder")
    folder.Name = "EggRestorationStage"
    folder.Parent = Workspace

    -- 1. Turntable Pedestal
    local turntable = Instance.new("Part")
    turntable.Name = "Turntable"
    turntable.Shape = Enum.PartType.Cylinder
    turntable.Size = Vector3.new(0.4, 5.4, 5.4)
    turntable.CFrame = CFrame.new(centerPos) * CFrame.Angles(0, 0, math.rad(90))
    turntable.Material = Enum.Material.Marble
    turntable.Color = Color3.fromRGB(240, 240, 245)
    turntable.Anchored = true
    turntable.CanCollide = false
    turntable.Parent = folder

    local brassRing = Instance.new("Part")
    brassRing.Name = "BrassRing"
    brassRing.Shape = Enum.PartType.Cylinder
    brassRing.Size = Vector3.new(0.44, 5.6, 5.6)
    brassRing.CFrame = turntable.CFrame
    brassRing.Material = Enum.Material.Metal
    brassRing.Color = Color3.fromRGB(220, 180, 50)
    brassRing.Anchored = true
    brassRing.CanCollide = false
    brassRing.Parent = folder

    -- 2. Central Invisible Root for 360 Rotation
    local root = Instance.new("Part")
    root.Name = "TurntableRoot"
    root.Size = Vector3.new(1, 1, 1)
    root.Transparency = 1
    root.CanCollide = false
    root.Anchored = true
    root.CFrame = CFrame.new(centerPos + Vector3.new(0, 2.5, 0))
    root.Parent = folder

    -- 3. Pristine 3D Egg Core
    local eggModel = Instance.new("Model")
    eggModel.Name = "EggCore"

    local corePart = Instance.new("Part")
    corePart.Name = "CoreShell"
    corePart.Size = Vector3.new(3.2, 4.4, 3.2)
    corePart.Shape = Enum.PartType.Ball
    corePart.Material = crustCfg.EggCoreMaterial or Enum.Material.SmoothPlastic
    corePart.Color = crustCfg.EggCoreColor or Color3.fromRGB(160, 235, 170)
    corePart.Anchored = true
    corePart.CanCollide = false
    corePart.CFrame = root.CFrame
    corePart.Parent = eggModel

    -- Apply Mutation visual if applicable
    local mutConfig = GameConfig.Mutations[eggData.Mutation] or GameConfig.Mutations.Normal
    if eggData.Mutation ~= "Normal" then
        corePart.Color = mutConfig.Color
        corePart.Material = mutConfig.Material
    end

    -- Inner Egg Light
    local eggLight = Instance.new("PointLight")
    eggLight.Name = "CoreGlow"
    eggLight.Range = 14
    eggLight.Brightness = 2.2
    eggLight.Color = corePart.Color
    eggLight.Parent = corePart

    eggModel.PrimaryPart = corePart
    eggModel.Parent = folder

    -- 4. 30 Spatial 3D Dirt Crust Segments (Pop-Out Physics Ready)
    dirtChunks = {}
    cleanedChunksCount = 0

    -- Pre-calculate initial cleaned chunks if egg was partially washed
    local initialCleanPct = eggData.Cleanliness or 0
    local chunksToSkip = math.floor((initialCleanPct / 100) * totalChunks)

    -- Spherical coordinate rings for spatial coverage
    local chunkIndex = 0
    local function addChunk(yawDeg, pitchDeg, radius, size, isCap)
        chunkIndex += 1
        local isAlreadyClean = (chunkIndex <= chunksToSkip)

        local radYaw = math.rad(yawDeg)
        local radPitch = math.rad(pitchDeg)

        local x = math.cos(radPitch) * math.sin(radYaw) * radius
        local y = math.sin(radPitch) * (radius * 1.25)
        local z = math.cos(radPitch) * math.cos(radYaw) * radius
        local offsetPos = Vector3.new(x, y, z)

        local chunk = Instance.new("Part")
        chunk.Name = "DirtChunk_" .. chunkIndex
        chunk.Size = size or Vector3.new(1.7, 1.5, 1.3)
        chunk.Material = (math.random() > 0.4) and crustCfg.ChunkMaterial or crustCfg.DetailMaterial
        chunk.Color = crustCfg.ChunkColor
        chunk.Anchored = true
        chunk.CanCollide = false
        chunk.CastShadow = true

        -- Random jagged rock tilt
        local randRot = CFrame.Angles(
            math.rad(math.random(-18, 18)),
            math.rad(math.random(-18, 18)),
            math.rad(math.random(-18, 18))
        )
        chunk.CFrame = root.CFrame * CFrame.new(offsetPos) * randRot

        -- Debris Emitter for 3D Pop-Out
        local att = Instance.new("Attachment", chunk)
        local debrisEmitter = Instance.new("ParticleEmitter")
        debrisEmitter.Name = "DebrisBurst"
        debrisEmitter.Rate = 0
        debrisEmitter.Speed = NumberRange.new(6, 15)
        debrisEmitter.SpreadAngle = Vector2.new(60, 60)
        debrisEmitter.Lifetime = NumberRange.new(0.4, 0.8)
        debrisEmitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(1, 0.1)
        })
        debrisEmitter.Color = ColorSequence.new(crustCfg.ParticleColor)
        debrisEmitter.Parent = att

        if isAlreadyClean then
            chunk.Transparency = 1
            chunk.Parent = nil
            chunk:Destroy()
            table.insert(dirtChunks, {
                Index = chunkIndex,
                Part = nil,
                IsCleaned = true,
                HP = 0,
                MaxHP = crustCfg.ChunkHP,
            })
            cleanedChunksCount += 1
        else
            chunk.Parent = folder
            table.insert(dirtChunks, {
                Index = chunkIndex,
                Part = chunk,
                IsCleaned = false,
                HP = crustCfg.ChunkHP,
                MaxHP = crustCfg.ChunkHP,
                OffsetPos = offsetPos,
                BaseRot = randRot,
                DebrisEmitter = debrisEmitter,
            })
        end
    end

    -- Ring 1: Top Cap (1 chunk)
    addChunk(0, 78, 1.7, Vector3.new(1.9, 1.2, 1.9), true)

    -- Ring 2: Upper Ring (6 chunks)
    for i = 1, 6 do
        addChunk((i - 1) * 60 + math.random(-8, 8), 45, 1.8, Vector3.new(1.8, 1.5, 1.4))
    end

    -- Ring 3: Upper-Mid Ring (8 chunks)
    for i = 1, 8 do
        addChunk((i - 1) * 45 + math.random(-6, 6), 15, 1.95, Vector3.new(1.9, 1.6, 1.5))
    end

    -- Ring 4: Lower-Mid Ring (8 chunks)
    for i = 1, 8 do
        addChunk((i - 1) * 45 + 22.5 + math.random(-6, 6), -18, 1.95, Vector3.new(1.9, 1.6, 1.5))
    end

    -- Ring 5: Lower Ring (6 chunks)
    for i = 1, 6 do
        addChunk((i - 1) * 60 + 30 + math.random(-8, 8), -48, 1.8, Vector3.new(1.8, 1.5, 1.4))
    end

    -- Ring 6: Bottom Cap (1 chunk)
    addChunk(0, -78, 1.65, Vector3.new(1.8, 1.1, 1.8), true)

    return folder, root, eggModel
end

-----------------------------------------------------
-- RESTORATION HUD BUILDER
-----------------------------------------------------
local function createRestorationHUD()
    if RestorationGui then RestorationGui:Destroy() end

    RestorationGui = Instance.new("ScreenGui")
    RestorationGui.Name = "EggRestorationHUD"
    RestorationGui.ResetOnSpawn = false
    RestorationGui.DisplayOrder = 100
    RestorationGui.Parent = PlayerGui

    -- Center Crosshair / Aim Reticle
    local crosshair = Instance.new("ImageLabel")
    crosshair.Name = "Crosshair"
    crosshair.Size = UDim2.new(0, 36, 0, 36)
    crosshair.Position = UDim2.new(0.5, -18, 0.5, -18)
    crosshair.BackgroundTransparency = 1
    crosshair.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    crosshair.ImageColor3 = Color3.fromRGB(120, 220, 255)
    crosshair.ImageTransparency = 0.3
    crosshair.Parent = RestorationGui

    local chCenter = Instance.new("Frame", crosshair)
    chCenter.Size = UDim2.new(0, 6, 0, 6)
    chCenter.Position = UDim2.new(0.5, -3, 0.5, -3)
    chCenter.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    local chCorner = Instance.new("UICorner", chCenter)
    chCorner.CornerRadius = UDim.new(1, 0)

    -- Top Header Card
    local headerFrame = Instance.new("Frame")
    headerFrame.Name = "HeaderFrame"
    headerFrame.Size = UDim2.new(0, 480, 0, 52)
    headerFrame.Position = UDim2.new(0.5, -240, 0, 16)
    headerFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
    headerFrame.BackgroundTransparency = 0.15
    headerFrame.BorderSizePixel = 0
    headerFrame.Parent = RestorationGui

    local hCorner = Instance.new("UICorner", headerFrame)
    hCorner.CornerRadius = UDim.new(0, 12)
    local hStroke = Instance.new("UIStroke", headerFrame)
    hStroke.Color = Color3.fromRGB(80, 180, 255)
    hStroke.Thickness = 1.8

    local titleLbl = Instance.new("TextLabel", headerFrame)
    titleLbl.Name = "Title"
    titleLbl.Size = UDim2.new(1, 0, 0.52, 0)
    titleLbl.Position = UDim2.new(0, 0, 0, 4)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.TextSize = 16
    titleLbl.TextColor3 = Color3.fromRGB(255, 225, 90)
    titleLbl.Text = "✨ 3D EGG RESTORATION STATION ✨"

    local subTitleLbl = Instance.new("TextLabel", headerFrame)
    subTitleLbl.Name = "Subtitle"
    subTitleLbl.Size = UDim2.new(1, 0, 0.44, 0)
    subTitleLbl.Position = UDim2.new(0, 0, 0.52, 0)
    subTitleLbl.BackgroundTransparency = 1
    subTitleLbl.Font = Enum.Font.GothamMedium
    subTitleLbl.TextSize = 12
    subTitleLbl.TextColor3 = Color3.fromRGB(200, 225, 245)
    subTitleLbl.Text = "Restoring: " .. (currentEggData and currentEggData.EggName or "Muddy Egg")

    -- Top-Right Cleaner Info & Upgrade Button
    local washerCard = Instance.new("Frame")
    washerCard.Name = "WasherCard"
    washerCard.Size = UDim2.new(0, 240, 0, 78)
    washerCard.Position = UDim2.new(1, -255, 0, 16)
    washerCard.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
    washerCard.BackgroundTransparency = 0.15
    washerCard.BorderSizePixel = 0
    washerCard.Parent = RestorationGui

    local wCorner = Instance.new("UICorner", washerCard)
    wCorner.CornerRadius = UDim.new(0, 10)
    local wStroke = Instance.new("UIStroke", washerCard)
    wStroke.Color = Color3.fromRGB(50, 140, 220)
    wStroke.Thickness = 1.5

    StatusPill = Instance.new("TextLabel", washerCard)
    StatusPill.Size = UDim2.new(1, -16, 0, 36)
    StatusPill.Position = UDim2.new(0, 8, 0, 6)
    StatusPill.BackgroundTransparency = 1
    StatusPill.Font = Enum.Font.GothamBold
    StatusPill.TextSize = 12
    StatusPill.TextColor3 = Color3.fromRGB(180, 230, 255)
    StatusPill.TextXAlignment = Enum.TextXAlignment.Left
    StatusPill.Text = "🔫 Power Washer (Tier 1)\nPressure: 100 PSI  •  Nozzle: Std"

    local upgradeBtn = Instance.new("TextButton", washerCard)
    upgradeBtn.Name = "UpgradeBtn"
    upgradeBtn.Size = UDim2.new(1, -16, 0, 26)
    upgradeBtn.Position = UDim2.new(0, 8, 0, 44)
    upgradeBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 90)
    upgradeBtn.Font = Enum.Font.GothamBlack
    upgradeBtn.TextSize = 11
    upgradeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    upgradeBtn.Text = "⚙️ UPGRADE CLEANER"
    local ubCorner = Instance.new("UICorner", upgradeBtn)
    ubCorner.CornerRadius = UDim.new(0, 6)

    -- Bottom Progress Bar Frame
    local progressFrame = Instance.new("Frame")
    progressFrame.Name = "ProgressFrame"
    progressFrame.Size = UDim2.new(0, 520, 0, 68)
    progressFrame.Position = UDim2.new(0.5, -260, 1, -86)
    progressFrame.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
    progressFrame.BackgroundTransparency = 0.15
    progressFrame.BorderSizePixel = 0
    progressFrame.Parent = RestorationGui

    local pfCorner = Instance.new("UICorner", progressFrame)
    pfCorner.CornerRadius = UDim.new(0, 14)
    local pfStroke = Instance.new("UIStroke", progressFrame)
    pfStroke.Color = Color3.fromRGB(70, 160, 240)
    pfStroke.Thickness = 2

    PercentLabel = Instance.new("TextLabel", progressFrame)
    PercentLabel.Size = UDim2.new(0.6, 0, 0, 24)
    PercentLabel.Position = UDim2.new(0, 16, 0, 8)
    PercentLabel.BackgroundTransparency = 1
    PercentLabel.Font = Enum.Font.GothamBlack
    PercentLabel.TextSize = 15
    PercentLabel.TextColor3 = Color3.fromRGB(120, 235, 255)
    PercentLabel.TextXAlignment = Enum.TextXAlignment.Left
    PercentLabel.Text = "CLEANLINESS: 0%"

    ChunksRemainingLabel = Instance.new("TextLabel", progressFrame)
    ChunksRemainingLabel.Size = UDim2.new(0.4, -24, 0, 24)
    ChunksRemainingLabel.Position = UDim2.new(0.6, 0, 0, 8)
    ChunksRemainingLabel.BackgroundTransparency = 1
    ChunksRemainingLabel.Font = Enum.Font.GothamBold
    ChunksRemainingLabel.TextSize = 12
    ChunksRemainingLabel.TextColor3 = Color3.fromRGB(255, 215, 120)
    ChunksRemainingLabel.TextXAlignment = Enum.TextXAlignment.Right
    ChunksRemainingLabel.Text = "0 / 30 Chunks Removed"

    local barBg = Instance.new("Frame", progressFrame)
    barBg.Size = UDim2.new(1, -32, 0, 14)
    barBg.Position = UDim2.new(0, 16, 0, 36)
    barBg.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
    local bbgCorner = Instance.new("UICorner", barBg)
    bbgCorner.CornerRadius = UDim.new(0, 6)

    ProgressFill = Instance.new("Frame", barBg)
    ProgressFill.Size = UDim2.new(0, 0, 1, 0)
    ProgressFill.BackgroundColor3 = Color3.fromRGB(50, 200, 255)
    local pfFillCorner = Instance.new("UICorner", ProgressFill)
    pfFillCorner.CornerRadius = UDim.new(0, 6)

    -- Bottom-Left Exit Button
    local exitBtn = Instance.new("TextButton")
    exitBtn.Name = "ExitBtn"
    exitBtn.Size = UDim2.new(0, 130, 0, 42)
    exitBtn.Position = UDim2.new(0, 24, 1, -66)
    exitBtn.BackgroundColor3 = Color3.fromRGB(190, 50, 50)
    exitBtn.Font = Enum.Font.GothamBlack
    exitBtn.TextSize = 13
    exitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    exitBtn.Text = "✖ EXIT / PAUSE"
    local ebCorner = Instance.new("UICorner", exitBtn)
    ebCorner.CornerRadius = UDim.new(0, 10)
    exitBtn.Parent = RestorationGui

    -- Mobile Big Spray Button (Bottom-Right)
    SprayPromptBtn = Instance.new("TextButton")
    SprayPromptBtn.Name = "SprayPromptBtn"
    SprayPromptBtn.Size = UDim2.new(0, 140, 0, 56)
    SprayPromptBtn.Position = UDim2.new(1, -165, 1, -80)
    SprayPromptBtn.BackgroundColor3 = Color3.fromRGB(40, 150, 240)
    SprayPromptBtn.Font = Enum.Font.GothamBlack
    SprayPromptBtn.TextSize = 14
    SprayPromptBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    SprayPromptBtn.Text = "💦 HOLD TO\nPOWER WASH"
    local spCorner = Instance.new("UICorner", SprayPromptBtn)
    spCorner.CornerRadius = UDim.new(0, 14)
    local spStroke = Instance.new("UIStroke", SprayPromptBtn)
    spStroke.Color = Color3.fromRGB(180, 240, 255)
    spStroke.Thickness = 2
    SprayPromptBtn.Parent = RestorationGui

    -- Final Hatch Action Button (Hidden until 100%)
    ActionBtn = Instance.new("TextButton")
    ActionBtn.Name = "HatchActionBtn"
    ActionBtn.Size = UDim2.new(0, 380, 0, 56)
    ActionBtn.Position = UDim2.new(0.5, -190, 1, -82)
    ActionBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 100)
    ActionBtn.Font = Enum.Font.GothamBlack
    ActionBtn.TextSize = 16
    ActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ActionBtn.Text = "🌱 HATCH PET INTO GARDEN YARD! 🌱"
    ActionBtn.Visible = false
    local abCorner = Instance.new("UICorner", ActionBtn)
    abCorner.CornerRadius = UDim.new(0, 14)
    local abStroke = Instance.new("UIStroke", ActionBtn)
    abStroke.Color = Color3.fromRGB(255, 235, 90)
    abStroke.Thickness = 2.5
    ActionBtn.Parent = RestorationGui

    return RestorationGui, upgradeBtn, exitBtn, SprayPromptBtn, ActionBtn
end

-----------------------------------------------------
-- WASHER UPGRADES MODAL BUILDER
-----------------------------------------------------
local function openUpgradesModal()
    if UpgradesModal and UpgradesModal.Parent then
        UpgradesModal.Visible = true
        return
    end

    UpgradesModal = Instance.new("Frame")
    UpgradesModal.Name = "CleanerUpgradesModal"
    UpgradesModal.Size = UDim2.new(0, 420, 0, 360)
    UpgradesModal.Position = UDim2.new(0.5, -210, 0.5, -180)
    UpgradesModal.BackgroundColor3 = Color3.fromRGB(20, 25, 36)
    UpgradesModal.BorderSizePixel = 0
    UpgradesModal.ZIndex = 50
    UpgradesModal.Parent = RestorationGui

    local umCorner = Instance.new("UICorner", UpgradesModal)
    umCorner.CornerRadius = UDim.new(0, 14)
    local umStroke = Instance.new("UIStroke", UpgradesModal)
    umStroke.Color = Color3.fromRGB(60, 180, 255)
    umStroke.Thickness = 2

    local title = Instance.new("TextLabel", UpgradesModal)
    title.Size = UDim2.new(1, -60, 0, 36)
    title.Position = UDim2.new(0, 16, 0, 10)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(255, 220, 70)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "⚙️ POWER WASHER WORKSHOP"

    local closeBtn = Instance.new("TextButton", UpgradesModal)
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -42, 0, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 14
    local cbCorner = Instance.new("UICorner", closeBtn)
    cbCorner.CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function()
        UpgradesModal.Visible = false
    end)

    local function refreshUpgradeCards()
        for _, c in ipairs(UpgradesModal:GetChildren()) do
            if c:IsA("Frame") and c.Name:find("Card") then c:Destroy() end
        end

        local categories = {
            { Key = "PSI", Title = "⚡ Pressure (PSI)", Sub = "Removes tough dirt faster", Level = cleanerUpgrades.PSILevel or 1, List = GameConfig.CleanerUpgrades.PSI },
            { Key = "Width", Title = "🌊 Spray Nozzle Width", Sub = "Wider hit area covers more chunks", Level = cleanerUpgrades.WidthLevel or 1, List = GameConfig.CleanerUpgrades.Width },
            { Key = "Tier", Title = "🔫 Washer Hardware Tier", Sub = "Advanced wand design & high-velocity stream", Level = cleanerUpgrades.Tier or 1, List = GameConfig.CleanerUpgrades.Tier },
        }

        for idx, cat in ipairs(categories) do
            local card = Instance.new("Frame", UpgradesModal)
            card.Name = cat.Key .. "Card"
            card.Size = UDim2.new(1, -32, 0, 80)
            card.Position = UDim2.new(0, 16, 0, 52 + (idx - 1) * 92)
            card.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
            local ccCorner = Instance.new("UICorner", card)
            ccCorner.CornerRadius = UDim.new(0, 8)

            local cName = Instance.new("TextLabel", card)
            cName.Size = UDim2.new(0.65, 0, 0, 24)
            cName.Position = UDim2.new(0, 10, 0, 8)
            cName.BackgroundTransparency = 1
            cName.Font = Enum.Font.GothamBlack
            cName.TextSize = 13
            cName.TextColor3 = Color3.fromRGB(255, 255, 255)
            cName.TextXAlignment = Enum.TextXAlignment.Left
            cName.Text = cat.Title .. " (Lvl " .. cat.Level .. ")"

            local cSub = Instance.new("TextLabel", card)
            cSub.Size = UDim2.new(0.65, 0, 0, 36)
            cSub.Position = UDim2.new(0, 10, 0, 32)
            cSub.BackgroundTransparency = 1
            cSub.Font = Enum.Font.GothamMedium
            cSub.TextSize = 11
            cSub.TextColor3 = Color3.fromRGB(170, 190, 215)
            cSub.TextXAlignment = Enum.TextXAlignment.Left
            cSub.Text = cat.Sub

            local upgBtn = Instance.new("TextButton", card)
            upgBtn.Size = UDim2.new(0, 110, 0, 42)
            upgBtn.Position = UDim2.new(1, -120, 0.5, -21)
            local ubCorner = Instance.new("UICorner", upgBtn)
            ubCorner.CornerRadius = UDim.new(0, 6)
            upgBtn.Font = Enum.Font.GothamBold
            upgBtn.TextSize = 11

            local nextItem = cat.List[cat.Level + 1]
            if nextItem then
                upgBtn.Text = "UPGRADE\n(" .. nextItem.Cost .. " $)"
                upgBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 90)
                upgBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                upgBtn.MouseButton1Click:Connect(function()
                    local res = UpgradeCleanerRemote:InvokeServer(cat.Key)
                    if res and res.Success then
                        cleanerUpgrades[cat.Key .. (cat.Key == "Tier" and "" or "Level")] = res.NewLevel or res.NewTier
                        playSfx("PristineChime")
                        refreshUpgradeCards()
                        -- Refresh wand if tier upgraded
                        if cat.Key == "Tier" and wandModel then
                            wandModel:Destroy()
                            wandModel, nozzleAttachment = buildWasherWand(res.NewTier)
                            wandModel.Parent = Workspace
                        end
                        -- Update status card
                        local pLvl = cleanerUpgrades.PSILevel or 1
                        local pCfg = GameConfig.CleanerUpgrades.PSI[pLvl]
                        local wLvl = cleanerUpgrades.WidthLevel or 1
                        local wCfg = GameConfig.CleanerUpgrades.Width[wLvl]
                        local tLvl = cleanerUpgrades.Tier or 1
                        local tCfg = GameConfig.CleanerUpgrades.Tier[tLvl]
                        StatusPill.Text = "🔫 " .. tCfg.Name .. "\nPressure: " .. pCfg.Name .. "  •  " .. wCfg.Name
                    end
                end)
            else
                upgBtn.Text = "MAX LEVEL"
                upgBtn.BackgroundColor3 = Color3.fromRGB(50, 60, 75)
                upgBtn.TextColor3 = Color3.fromRGB(150, 165, 185)
            end
        end
    end

    refreshUpgradeCards()
end

-----------------------------------------------------
-- 3D RESTORATION EXPERIENCE CONTROLLER
-----------------------------------------------------
local function startRestoration(eggData, cleanerModel)
    if isRestoring then return end
    isRestoring = true
    currentEggData = eggData

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChild("Humanoid")
    if humanoid then
        originalWalkSpeed = humanoid.WalkSpeed
        originalJumpPower = humanoid.JumpPower
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
    end

    -- Save Camera
    savedCamCFrame = Camera.CFrame
    savedCamType = Camera.CameraType
    Camera.CameraType = Enum.CameraType.Scriptable

    -- Determine Station Center Position
    local basin = cleanerModel and (cleanerModel:FindFirstChild("WashBasin") or cleanerModel:FindFirstChildWhichIsA("BasePart"))
    local centerPos = basin and basin.Position or (hrp and hrp.Position + Vector3.new(0, 0, -8)) or Vector3.new(-184, -77.6, -22)

    -- Position Character standing beside basin
    if hrp then
        hrp.CFrame = CFrame.new(centerPos + Vector3.new(0, 2, 7.5), centerPos + Vector3.new(0, 2, 0))
    end

    -- Build 3D Stage (Egg & Dirt Crust)
    stageFolder, turntableRoot, eggCore = build3DEggAndCrust(eggData, centerPos)

    -- Build 3D Wand Viewmodel
    local state = GetSanctuaryStateRemote:InvokeServer()
    if state and state.CleanerUpgrades then
        cleanerUpgrades = state.CleanerUpgrades
    end
    wandModel, nozzleAttachment = buildWasherWand(cleanerUpgrades.Tier or 1)
    wandModel.Parent = Workspace

    -- Water Stream Target Attachment & Splash Emitter
    targetAttachment = Instance.new("Attachment")
    targetAttachment.Name = "SprayTargetAtt"
    targetAttachment.Parent = Workspace.Terrain

    waterBeam = Instance.new("Beam")
    waterBeam.Name = "HighPressureWaterJet"
    waterBeam.Attachment0 = nozzleAttachment
    waterBeam.Attachment1 = targetAttachment
    waterBeam.Width0 = 0.35
    waterBeam.Width1 = (GameConfig.CleanerUpgrades.Width[cleanerUpgrades.WidthLevel or 1].Radius or 1.6) * 0.35
    waterBeam.Color = ColorSequence.new(Color3.fromRGB(190, 245, 255), Color3.fromRGB(240, 255, 255))
    waterBeam.Transparency = NumberSequence.new(0.2)
    waterBeam.Segments = 10
    waterBeam.Enabled = false
    waterBeam.Parent = Workspace

    splashEmitter = Instance.new("ParticleEmitter")
    splashEmitter.Name = "WaterSplashFoam"
    splashEmitter.Rate = 0
    splashEmitter.Speed = NumberRange.new(8, 16)
    splashEmitter.SpreadAngle = Vector2.new(65, 65)
    splashEmitter.Lifetime = NumberRange.new(0.2, 0.45)
    splashEmitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 1.2)
    })
    splashEmitter.Color = ColorSequence.new(Color3.fromRGB(220, 250, 255))
    splashEmitter.Parent = targetAttachment

    impactLight = Instance.new("PointLight")
    impactLight.Name = "WaterImpactGlow"
    impactLight.Range = 10
    impactLight.Brightness = 0
    impactLight.Color = Color3.fromRGB(120, 220, 255)
    impactLight.Parent = targetAttachment

    -- Camera Focus on Egg
    local camPos = centerPos + Vector3.new(0, 4.2, 8.8)
    local camLook = centerPos + Vector3.new(0, 2.5, 0)
    TweenService:Create(Camera, TweenInfo.new(0.85, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
        CFrame = CFrame.lookAt(camPos, camLook)
    }):Play()

    -- Build HUD
    local hud, upgradeBtn, exitBtn, sprayBtn, hatchBtn = createRestorationHUD()

    local function updateHUDProgress()
        local pct = math.clamp(math.floor((cleanedChunksCount / totalChunks) * 100), 0, 100)
        ProgressFill.Size = UDim2.new(pct / 100, 0, 1, 0)
        PercentLabel.Text = "CLEANLINESS: " .. pct .. "%"
        ChunksRemainingLabel.Text = cleanedChunksCount .. " / " .. totalChunks .. " Chunks Removed"

        if pct >= 100 then
            -- 100% CLEAN GLORIOUS REVEAL!
            isSpraying = false
            waterBeam.Enabled = false
            splashEmitter.Rate = 0
            impactLight.Brightness = 0
            SprayPromptBtn.Visible = false
            ActionBtn.Visible = true

            playSfx("PristineChime")
            playSfx("HatchFanfare")

            -- Victory Sparkles Burst
            local sparkAtt = Instance.new("Attachment", eggCore.PrimaryPart)
            local stars = Instance.new("ParticleEmitter")
            stars.Rate = 0
            stars.Speed = NumberRange.new(8, 22)
            stars.SpreadAngle = Vector2.new(180, 180)
            stars.Lifetime = NumberRange.new(0.8, 1.6)
            stars.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.8),
                NumberSequenceKeypoint.new(1, 0.2)
            })
            stars.Color = ColorSequence.new(Color3.fromRGB(255, 235, 90), Color3.fromRGB(255, 255, 255))
            stars.Parent = sparkAtt
            stars:Emit(35)

            -- Float and spin egg
            TweenService:Create(turntableRoot, TweenInfo.new(1.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                CFrame = turntableRoot.CFrame + Vector3.new(0, 1.2, 0)
            }):Play()
        end
    end
    updateHUDProgress()

    -- Wire Buttons
    upgradeBtn.MouseButton1Click:Connect(openUpgradesModal)

    local function stopRestoration()
        if not isRestoring then return end
        isRestoring = false
        isSpraying = false

        if waterBeam then waterBeam.Enabled = false end
        if splashEmitter then splashEmitter.Rate = 0 end
        if impactLight then impactLight.Brightness = 0 end

        if RestorationGui then RestorationGui:Destroy() RestorationGui = nil end
        if stageFolder then stageFolder:Destroy() stageFolder = nil end
        if wandModel then wandModel:Destroy() wandModel = nil end
        if targetAttachment then targetAttachment:Destroy() targetAttachment = nil end
        if waterBeam then waterBeam:Destroy() waterBeam = nil end

        if humanoid then
            humanoid.WalkSpeed = originalWalkSpeed
            humanoid.JumpPower = originalJumpPower
        end

        Camera.CameraType = savedCamType or Enum.CameraType.Custom
        if char and char:FindFirstChild("Humanoid") then
            Camera.CameraSubject = char.Humanoid
        end
        if savedCamCFrame then
            Camera.CFrame = savedCamCFrame
        end
    end

    exitBtn.MouseButton1Click:Connect(stopRestoration)

    hatchBtn.MouseButton1Click:Connect(function()
        local res = HatchEggRemote:InvokeServer()
        stopRestoration()
        if res and res.Success then
            playSfx("HatchFanfare")
        end
    end)

    -- Mobile & Input Spraying Controls
    local function startSpray()
        if isRestoring and cleanedChunksCount < totalChunks then
            isSpraying = true
            if waterBeam then waterBeam.Enabled = true end
            if splashEmitter then splashEmitter.Rate = 35 end
            if impactLight then impactLight.Brightness = 3.5 end
            playSfx("WaterSpray")
        end
    end

    local function stopSpray()
        isSpraying = false
        if waterBeam then waterBeam.Enabled = false end
        if splashEmitter then splashEmitter.Rate = 0 end
        if impactLight then impactLight.Brightness = 0 end
    end

    sprayBtn.MouseButton1Down:Connect(startSpray)
    sprayBtn.MouseButton1Up:Connect(stopSpray)
    sprayBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            startSpray()
        end
    end)
    sprayBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            stopSpray()
        end
    end)

    -- PC Mouse & Keyboard Connections
    local inputBeganConn
    local inputEndedConn
    inputBeganConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if not isRestoring then return end
        if input.KeyCode == Enum.KeyCode.Space then
            startSpray()
            return
        end
        if gpe then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            startSpray()
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragStartPos = input.Position
            dragStartYaw = turntableYaw
            dragStartPitch = turntablePitch
        end
    end)

    inputEndedConn = UserInputService.InputEnded:Connect(function(input)
        if not isRestoring then return end
        if input.KeyCode == Enum.KeyCode.Space or input.UserInputType == Enum.UserInputType.MouseButton1 then
            stopSpray()
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)

    -- RenderStepped 60 FPS Loop for Wand Aiming, Turntable Spin & Pop-Out Physics
    local renderConn
    renderConn = RunService.RenderStepped:Connect(function(dt)
        if not isRestoring or not stageFolder or not turntableRoot then
            if renderConn then renderConn:Disconnect() end
            if inputBeganConn then inputBeganConn:Disconnect() end
            if inputEndedConn then inputEndedConn:Disconnect() end
            return
        end

        -- Keep Camera firmly locked on 3D Egg Wash Stage
        local camPos = centerPos + Vector3.new(0, 4.2, 8.8)
        local camLook = centerPos + Vector3.new(0, 2.5, 0)
        Camera.CameraType = Enum.CameraType.Scriptable
        Camera.CFrame = CFrame.lookAt(camPos, camLook)

        -- 1. Handle Turntable Rotation (Auto spin or Drag)
        if isDragging then
            local currentPos = UserInputService:GetMouseLocation()
            local delta = currentPos - dragStartPos
            turntableYaw = dragStartYaw - (delta.X * 0.008)
            turntablePitch = math.clamp(dragStartPitch - (delta.Y * 0.006), math.rad(-30), math.rad(30))
        else
            turntableYaw = (turntableYaw + math.rad(18) * dt) % (math.pi * 2)
        end

        local baseCF = CFrame.new(centerPos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(turntablePitch, turntableYaw, 0)
        turntableRoot.CFrame = baseCF

        if eggCore and eggCore.PrimaryPart then
            eggCore:PivotTo(baseCF)
        end

        -- 2. Position remaining dirt chunks relative to turntable
        for _, rec in ipairs(dirtChunks) do
            if not rec.IsCleaned and rec.Part and rec.Part.Parent then
                rec.Part.CFrame = baseCF * CFrame.new(rec.OffsetPos) * rec.BaseRot
            end
        end

        -- 3. Raycast Aiming & Wand Positioning
        local mousePos = UserInputService:GetMouseLocation()
        local unitRay = Camera:ViewportPointToRay(mousePos.X, mousePos.Y)
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Include
        rayParams.FilterDescendantsInstances = { stageFolder }

        local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 40, rayParams)
        local frontEggPos = centerPos + Vector3.new(0, 2.5, 1.8)
        local hitPos = (result and result.Position) or frontEggPos

        -- Position Wand in bottom-right corner of viewport
        if wandModel and wandModel.PrimaryPart then
            local wandCF = Camera.CFrame * CFrame.new(1.7, -1.15, -3.2)
            local aimDir = (hitPos - wandCF.Position).Unit
            wandModel:PivotTo(CFrame.lookAt(wandCF.Position, wandCF.Position + aimDir) * CFrame.Angles(0, math.rad(90), 0))
        end

        -- Position Water Target
        if targetAttachment then
            targetAttachment.WorldPosition = hitPos
        end

        -- 4. Dynamic Water Spray Damage & Pop-Out Trigger
        if isSpraying and cleanedChunksCount < totalChunks then
            local pLvl = cleanerUpgrades.PSILevel or 1
            local wLvl = cleanerUpgrades.WidthLevel or 1
            local psiPower = GameConfig.CleanerUpgrades.PSI[pLvl].DamageRate or 25
            local sprayRadius = GameConfig.CleanerUpgrades.Width[wLvl].Radius or 1.6

            local damageThisFrame = psiPower * dt

            for _, rec in ipairs(dirtChunks) do
                if not rec.IsCleaned and rec.Part and rec.Part.Parent then
                    local dist = (rec.Part.Position - hitPos).Magnitude
                    local distFront = (rec.Part.Position - frontEggPos).Magnitude
                    if dist <= sprayRadius or distFront <= (sprayRadius + 0.4) then
                        rec.HP = rec.HP - damageThisFrame

                        -- Visual wet darkening & particle puffs
                        rec.Part.Color = currentCrustConfig.ChunkColor:Lerp(Color3.fromRGB(15, 12, 10), 0.35)
                        if math.random() > 0.65 and rec.DebrisEmitter then
                            rec.DebrisEmitter:Emit(1)
                        end

                        -- CHUNK DESTROYED: 3D POP-OUT EFFECT!
                        if rec.HP <= 0 then
                            rec.IsCleaned = true
                            cleanedChunksCount += 1

                            local chunkPart = rec.Part
                            rec.Part = nil -- Release tracking

                            -- Pop-Out Physics Animation
                            task.spawn(function()
                                playSfx("EggPop")
                                if rec.DebrisEmitter then
                                    rec.DebrisEmitter:Emit(12)
                                end

                                -- Radial outward launch vector
                                local popDir = (chunkPart.Position - (centerPos + Vector3.new(0, 2.5, 0))).Unit
                                local popTarget = chunkPart.Position + (popDir * 4.2) + Vector3.new(0, 1.4, 0)
                                local randSpin = CFrame.Angles(math.rad(math.random(-90, 90)), math.rad(math.random(-90, 90)), 0)

                                local popTween = TweenService:Create(chunkPart, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                                    CFrame = CFrame.new(popTarget) * randSpin
                                })
                                popTween:Play()
                                popTween.Completed:Wait()

                                -- Drop into wash basin and dissolve
                                local dropTween = TweenService:Create(chunkPart, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                                    CFrame = CFrame.new(centerPos + Vector3.new(popDir.X * 1.5, -0.4, popDir.Z * 1.5)),
                                    Transparency = 1
                                })
                                dropTween:Play()
                                dropTween.Completed:Wait()
                                chunkPart:Destroy()
                            end)

                            -- Notify Server
                            local currentPct = math.floor((cleanedChunksCount / totalChunks) * 100)
                            CleanEggRemote:InvokeServer(rec.Index, currentPct)
                            updateHUDProgress()
                        end
                    end
                end
            end
        end
    end)
                            local currentPct = math.floor((cleanedChunksCount / totalChunks) * 100)
                            CleanEggRemote:InvokeServer(rec.Index, currentPct)
                            updateHUDProgress()
                        end
                    end
                end
            end
        end
    end)
end

-----------------------------------------------------
-- BIND IN-WORLD PROXIMITY PROMPT AT EGG CLEANER
-----------------------------------------------------
local function setupCleanerStationPrompt()
    local ProximityPromptService = game:GetService("ProximityPromptService")

    ProximityPromptService.PromptTriggered:Connect(function(prompt, inputPlayer)
        if inputPlayer ~= player then return end

        if prompt.ObjectText == "Egg Cleaner" or (prompt.Parent and prompt.Parent.Name == "WashBasin" and prompt.Parent.Parent and prompt.Parent.Parent.Name == "EggCleaner") then
            local state = GetSanctuaryStateRemote:InvokeServer()
            if state and state.HasEgg and state.CurrentEgg then
                local cleanerModel = prompt.Parent.Parent
                startRestoration(state.CurrentEgg, cleanerModel)
            end
        end
    end)
end

task.spawn(setupCleanerStationPrompt)

print("[EggSanctuary] 3D Egg Restoration & Pop-Out Physics Engine Loaded!")
