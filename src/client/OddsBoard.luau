--!strict
-- OddsBoard (design-v3, phase0_decisions Step 1, gemini_odds_board.md):
-- Renders live drop odds on the local player's plot ViewingDeck.OddsBoard SurfaceGui.
-- Client-only presentation. Displays equipped food + luck multiplier, reachable zones,
-- the next locked zone ("Need X strength"), and the best creature found (or "???").
-- The odds are computed directly from Economy.eggOdds (the shared server roll function).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Ctx = require(script.Parent.Ctx)
local Fx = require(script.Parent.Fx)
local UI = script.Parent.Parent:WaitForChild("UI")
local Logic = require(UI:WaitForChild("Logic"))
local Theme = require(UI:WaitForChild("Theme"))

local Economy = Ctx.Economy
local player = Ctx.player

local OddsBoard = {}
local initialized = false
local currentBoardPart: BasePart? = nil
local activeSurfaceGui: SurfaceGui? = nil
local rootFrame: Frame? = nil
local headerFoodLabel: TextLabel? = nil
local headerStrengthLabel: TextLabel? = nil
local zoneRowsContainer: Frame? = nil

local refreshPending = false

local function isCreatureFound(species: string): boolean
    if Ctx.book and Ctx.book[species] ~= nil then
        return true
    end
    for _, pet in Ctx.pets do
        if pet.species == species then
            return true
        end
    end
    return false
end

local function getPlot(): Model?
    if Ctx.plot then
        return Ctx.plot
    end
    local plotId = player:GetAttribute("PlotId")
    if plotId then
        for _, p in CollectionService:GetTagged("FLPlot") do
            if p:GetAttribute("PlotId") == plotId and p:IsA("Model") then
                Ctx.plot = p
                return p
            end
        end
    end
    return nil
end

local function buildGenericBoard(sg: SurfaceGui)
    sg:ClearAllChildren()
    sg.Face = Enum.NormalId.Back
    sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    sg.CanvasSize = Vector2.new(900, 600)
    sg.LightInfluence = 0.05
    sg.AlwaysOnTop = false

    local root = Instance.new("Frame")
    root.Name = "GenericRoot"
    root.Size = UDim2.new(1, 0, 1, 0)
    root.BackgroundColor3 = Color3.fromHex("1A2234")
    root.BorderSizePixel = 0
    root.Parent = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 24)
    corner.Parent = root

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromHex("12202A")
    stroke.Thickness = 6
    stroke.Parent = root

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -40, 0, 80)
    title.Position = UDim2.new(0, 20, 0.35, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromHex("FFC800")
    title.FontFace = Theme.Fonts.title
    title.TextSize = 44
    title.Text = "DROP ODDS"
    title.Parent = root

    local titleStroke = Instance.new("UIStroke")
    titleStroke.Color = Color3.fromHex("12202A")
    titleStroke.Thickness = 4
    titleStroke.Parent = title

    local sub = Instance.new("TextLabel")
    sub.Name = "Subtitle"
    sub.Size = UDim2.new(1, -40, 0, 40)
    sub.Position = UDim2.new(0, 20, 0.52, 0)
    sub.BackgroundTransparency = 1
    sub.TextColor3 = Color3.fromHex("94A3B8")
    sub.FontFace = Theme.Fonts.body
    sub.TextSize = 22
    sub.Text = "VISIT YOUR PLOT'S VIEWING DECK FOR LIVE ODDS"
    sub.Parent = root
end

local function setupPlayerSurfaceGui(sg: SurfaceGui)
    sg:ClearAllChildren()
    sg.Face = Enum.NormalId.Back
    sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    sg.CanvasSize = Vector2.new(900, 600)
    sg.LightInfluence = 0.05
    sg.AlwaysOnTop = false

    local root = Instance.new("Frame")
    root.Name = "OddsBoardRoot"
    root.Size = UDim2.new(1, 0, 1, 0)
    root.BackgroundColor3 = Color3.fromHex("161F2E")
    root.BorderSizePixel = 0
    root.Parent = sg
    rootFrame = root

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 24)
    corner.Parent = root

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromHex("12202A")
    stroke.Thickness = 6
    stroke.Parent = root

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 14)
    padding.PaddingBottom = UDim.new(0, 14)
    padding.PaddingLeft = UDim.new(0, 16)
    padding.PaddingRight = UDim.new(0, 16)
    padding.Parent = root

    -- Header Bar (Height = 72px)
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 72)
    header.BackgroundColor3 = Color3.fromHex("101724")
    header.BorderSizePixel = 0
    header.Parent = root

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 14)
    headerCorner.Parent = header

    local headerStroke = Instance.new("UIStroke")
    headerStroke.Color = Color3.fromHex("12202A")
    headerStroke.Thickness = 3
    headerStroke.Parent = header

    -- Title Section
    local titleBox = Instance.new("Frame")
    titleBox.Name = "TitleBox"
    titleBox.Size = UDim2.new(0, 240, 1, 0)
    titleBox.Position = UDim2.new(0, 16, 0, 0)
    titleBox.BackgroundTransparency = 1
    titleBox.Parent = header

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 36)
    title.Position = UDim2.new(0, 0, 0, 6)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromHex("FFC800")
    title.FontFace = Theme.Fonts.title
    title.TextSize = 28
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "DROP ODDS"
    title.Parent = titleBox

    local titleStroke = Instance.new("UIStroke")
    titleStroke.Color = Color3.fromHex("12202A")
    titleStroke.Thickness = 3
    titleStroke.Parent = title

    local subTitle = Instance.new("TextLabel")
    subTitle.Name = "SubTitle"
    subTitle.Size = UDim2.new(1, 0, 0, 20)
    subTitle.Position = UDim2.new(0, 0, 0, 42)
    subTitle.BackgroundTransparency = 1
    subTitle.TextColor3 = Color3.fromHex("94A3B8")
    subTitle.FontFace = Theme.Fonts.body
    subTitle.TextSize = 12
    subTitle.TextXAlignment = Enum.TextXAlignment.Left
    subTitle.Text = "BASE ODDS • Food Luck Applied"
    subTitle.Parent = titleBox

    -- Equipped Food Pill
    local foodPill = Instance.new("Frame")
    foodPill.Name = "FoodPill"
    foodPill.Size = UDim2.new(0, 360, 0, 48)
    foodPill.Position = UDim2.new(0.5, 0, 0.5, 0)
    foodPill.AnchorPoint = Vector2.new(0.5, 0.5)
    foodPill.BackgroundColor3 = Color3.fromHex("1E2B3E")
    foodPill.BorderSizePixel = 0
    foodPill.Parent = header

    local foodCorner = Instance.new("UICorner")
    foodCorner.CornerRadius = UDim.new(0, 12)
    foodCorner.Parent = foodPill

    local foodStroke = Instance.new("UIStroke")
    foodStroke.Color = Color3.fromHex("12202A")
    foodStroke.Thickness = 2
    foodStroke.Parent = foodPill

    local foodLabel = Instance.new("TextLabel")
    foodLabel.Name = "FoodLabel"
    foodLabel.Size = UDim2.new(1, 0, 1, 0)
    foodLabel.BackgroundTransparency = 1
    foodLabel.TextColor3 = Color3.fromHex("2BD45B")
    foodLabel.FontFace = Theme.Fonts.title
    foodLabel.TextSize = 16
    foodLabel.Text = "Apple (Tier 1) • 1x Luck"
    foodLabel.Parent = foodPill
    headerFoodLabel = foodLabel

    -- Strength Badge (Right)
    local strengthPill = Instance.new("Frame")
    strengthPill.Name = "StrengthPill"
    strengthPill.Size = UDim2.new(0, 200, 0, 48)
    strengthPill.Position = UDim2.new(1, -16, 0.5, 0)
    strengthPill.AnchorPoint = Vector2.new(1, 0.5)
    strengthPill.BackgroundColor3 = Color3.fromHex("1E2B3E")
    strengthPill.BorderSizePixel = 0
    strengthPill.Parent = header

    local strCorner = Instance.new("UICorner")
    strCorner.CornerRadius = UDim.new(0, 12)
    strCorner.Parent = strengthPill

    local strStroke = Instance.new("UIStroke")
    strStroke.Color = Color3.fromHex("12202A")
    strStroke.Thickness = 2
    strStroke.Parent = strengthPill

    local strLabel = Instance.new("TextLabel")
    strLabel.Name = "StrengthLabel"
    strLabel.Size = UDim2.new(1, 0, 1, 0)
    strLabel.BackgroundTransparency = 1
    strLabel.TextColor3 = Color3.fromHex("FFC800")
    strLabel.FontFace = Theme.Fonts.title
    strLabel.TextSize = 16
    strLabel.Text = "💪 50 Strength"
    strLabel.Parent = strengthPill
    headerStrengthLabel = strLabel

    -- Zone Rows Container
    local rowsContainer = Instance.new("Frame")
    rowsContainer.Name = "RowsContainer"
    rowsContainer.Size = UDim2.new(1, 0, 1, -84)
    rowsContainer.Position = UDim2.new(0, 0, 0, 82)
    rowsContainer.BackgroundTransparency = 1
    rowsContainer.Parent = root
    zoneRowsContainer = rowsContainer

    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.Padding = UDim.new(0, 8)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = rowsContainer
end

local function refresh()
    if not rootFrame or not zoneRowsContainer then
        return
    end

    local food = Economy.Foods[Ctx.foodTier] or Economy.Foods[1]
    local foodLuck = food.Luck
    local strength = Ctx.strength

    if headerFoodLabel then
        headerFoodLabel.Text = string.format("🍏 %s (Tier %d) • %dx Luck", food.Name, food.Tier, foodLuck)
    end
    if headerStrengthLabel then
        headerStrengthLabel.Text = string.format("💪 %s Strength", Logic.formatNumber(strength))
    end

    -- Clear previous rows
    for _, child in zoneRowsContainer:GetChildren() do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    -- Determine how many zones to display: reachable zones + 1 next locked zone
    local maxZone = Economy.zoneForStrength(strength)
    local maxReachableId = maxZone.Id
    local nextLockedId = math.min(maxReachableId + 1, 5)
    local displayCount = if maxReachableId >= 5 then 5 else nextLockedId

    local totalHeight = zoneRowsContainer.AbsoluteSize.Y
    if totalHeight <= 0 then
        totalHeight = 490
    end
    local rowHeight = math.floor((totalHeight - (displayCount - 1) * 8) / displayCount)

    for zoneId = 1, displayCount do
        local z = Economy.Zones[zoneId]
        local isUnlocked = zoneId <= maxReachableId

        local row = Instance.new("Frame")
        row.Name = "ZoneRow_" .. zoneId
        row.Size = UDim2.new(1, 0, 0, rowHeight)
        row.BackgroundColor3 = if isUnlocked then Color3.fromHex("1E293B") else Color3.fromHex("131C28")
        row.BorderSizePixel = 0
        row.LayoutOrder = zoneId
        row.Parent = zoneRowsContainer

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 12)
        rowCorner.Parent = row

        local rowStroke = Instance.new("UIStroke")
        rowStroke.Color = Color3.fromHex("12202A")
        rowStroke.Thickness = 2.5
        rowStroke.Parent = row

        -- Left Section: Zone badge + Best creature / Lock note
        local leftBox = Instance.new("Frame")
        leftBox.Name = "LeftBox"
        leftBox.Size = UDim2.new(0, 270, 1, 0)
        leftBox.Position = UDim2.new(0, 12, 0, 0)
        leftBox.BackgroundTransparency = 1
        leftBox.Parent = row

        local zoneBadge = Instance.new("TextLabel")
        zoneBadge.Name = "ZoneBadge"
        zoneBadge.Size = UDim2.new(1, 0, 0, math.clamp(rowHeight * 0.44, 26, 40))
        zoneBadge.Position = UDim2.new(0, 0, 0, math.clamp(rowHeight * 0.08, 4, 10))
        zoneBadge.BackgroundColor3 = if isUnlocked
            then (Fx.FLOOR[zoneId] or Color3.fromHex("2563EB"))
            else Color3.fromHex("2A3342")
        zoneBadge.TextColor3 = Color3.fromHex("FFFFFF")
        zoneBadge.FontFace = Theme.Fonts.title
        zoneBadge.TextSize = if displayCount <= 3 then 16 else 14
        zoneBadge.Text = z.Name
        zoneBadge.BorderSizePixel = 0
        zoneBadge.Parent = leftBox

        local badgeCorner = Instance.new("UICorner")
        badgeCorner.CornerRadius = UDim.new(0, 8)
        badgeCorner.Parent = zoneBadge

        local badgeStroke = Instance.new("UIStroke")
        badgeStroke.Color = Color3.fromHex("12202A")
        badgeStroke.Thickness = 2
        badgeStroke.Parent = zoneBadge

        local statusLabel = Instance.new("TextLabel")
        statusLabel.Name = "StatusLabel"
        statusLabel.Size = UDim2.new(1, 0, 0, math.clamp(rowHeight * 0.36, 20, 32))
        statusLabel.Position = UDim2.new(0, 0, 1, -math.clamp(rowHeight * 0.42, 22, 34))
        statusLabel.BackgroundTransparency = 1
        statusLabel.FontFace = Theme.Fonts.body
        statusLabel.TextSize = if displayCount <= 3 then 13 else 11
        statusLabel.TextXAlignment = Enum.TextXAlignment.Left
        statusLabel.Parent = leftBox

        if isUnlocked then
            local bestCreature = Economy.Creatures[(zoneId - 1) * 3 + 3]
            local found = isCreatureFound(bestCreature.Name)
            local bestName = if found then ("★ " .. bestCreature.Name) else "★ ???"
            local rarityColor = (Theme.Rarity :: any)[bestCreature.Rarity] or Color3.fromHex("FFC800")
            statusLabel.Text = bestName .. " [" .. bestCreature.Rarity .. "]"
            statusLabel.TextColor3 = if found then rarityColor else Color3.fromHex("94A3B8")
        else
            statusLabel.Text = "🔒 Need " .. Logic.formatNumber(z.StrengthGate) .. " Strength"
            statusLabel.TextColor3 = Color3.fromHex("F59E0B")
        end

        -- Right Section: Odds breakdown pills
        local rightBox = Instance.new("Frame")
        rightBox.Name = "RightBox"
        rightBox.Size = UDim2.new(1, -300, 1, 0)
        rightBox.Position = UDim2.new(0, 290, 0, 0)
        rightBox.BackgroundTransparency = 1
        rightBox.Parent = row

        if isUnlocked then
            local oddsLayout = Instance.new("UIListLayout")
            oddsLayout.FillDirection = Enum.FillDirection.Horizontal
            oddsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
            oddsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            oddsLayout.Padding = UDim.new(0, 10)
            oddsLayout.Parent = rightBox

            -- Roll probabilities using the shared server formula
            -- NOTE: When Golden Hour ships on the server (replacing hard-coded false in Main), read the replicated server attribute here, never a client guess.
            local odds = Economy.eggOdds(zoneId, foodLuck, false)
            for i = 1, 3 do
                local creature = Economy.Creatures[(zoneId - 1) * 3 + i]
                local p = odds[i]
                local rColor = (Theme.Rarity :: any)[creature.Rarity] or Color3.fromHex("FFFFFF")

                local pctText = if p >= 0.01
                    then string.format("%.1f%%", p * 100)
                    else string.format("%.2f%%", p * 100)
                local oneInN = if p <= 0.20 and p > 0 then string.format(" (1 in %d)", math.round(1 / p)) else ""

                local pill = Instance.new("Frame")
                pill.Name = "Pill_" .. i
                pill.Size = UDim2.new(0.31, 0, 0, math.clamp(rowHeight * 0.65, 34, 52))
                pill.BackgroundColor3 = Color3.fromHex("121A28")
                pill.BorderSizePixel = 0
                pill.LayoutOrder = i
                pill.Parent = rightBox

                local pillCorner = Instance.new("UICorner")
                pillCorner.CornerRadius = UDim.new(0, 10)
                pillCorner.Parent = pill

                local pillStroke = Instance.new("UIStroke")
                pillStroke.Color = rColor
                pillStroke.Thickness = 2
                pillStroke.Parent = pill

                local pillLabel = Instance.new("TextLabel")
                pillLabel.Name = "Label"
                pillLabel.Size = UDim2.new(1, -8, 1, 0)
                pillLabel.Position = UDim2.new(0, 4, 0, 0)
                pillLabel.BackgroundTransparency = 1
                pillLabel.TextColor3 = rColor
                pillLabel.FontFace = Theme.Fonts.title
                pillLabel.TextSize = if displayCount <= 3 then 14 else 12
                pillLabel.Text = creature.Rarity .. "\n" .. pctText .. oneInN
                pillLabel.Parent = pill
            end
        else
            -- Locked state representation
            local lockPill = Instance.new("Frame")
            lockPill.Name = "LockedPill"
            lockPill.Size = UDim2.new(0.96, 0, 0, math.clamp(rowHeight * 0.65, 34, 52))
            lockPill.Position = UDim2.new(0.02, 0, 0.5, 0)
            lockPill.AnchorPoint = Vector2.new(0, 0.5)
            lockPill.BackgroundColor3 = Color3.fromHex("0E1520")
            lockPill.BorderSizePixel = 0
            lockPill.Parent = rightBox

            local lockCorner = Instance.new("UICorner")
            lockCorner.CornerRadius = UDim.new(0, 10)
            lockCorner.Parent = lockPill

            local lockStroke = Instance.new("UIStroke")
            lockStroke.Color = Color3.fromHex("232E40")
            lockStroke.Thickness = 1.5
            lockStroke.Parent = lockPill

            local lockLabel = Instance.new("TextLabel")
            lockLabel.Name = "Label"
            lockLabel.Size = UDim2.new(1, 0, 1, 0)
            lockLabel.BackgroundTransparency = 1
            lockLabel.TextColor3 = Color3.fromHex("64748B")
            lockLabel.FontFace = Theme.Fonts.title
            lockLabel.TextSize = 13
            lockLabel.Text = "LOCKED ZONE • GAIN STRENGTH TO UNLOCK AND VIEW DROP ODDS"
            lockLabel.Parent = lockPill
        end
    end
end

local function requestRefresh()
    if refreshPending then
        return
    end
    refreshPending = true
    task.delay(0.2, function()
        refreshPending = false
        refresh()
    end)
end

function OddsBoard.init()
    if initialized then
        return
    end
    initialized = true

    -- Initialize Runway Lanes client module (phase0 Step 2)
    task.spawn(function()
        local ok, err = pcall(function()
            require(script.Parent.Lanes).init()
        end)
        if not ok then
            warn("[OddsBoard] Failed to initialize Lanes:", err)
        end
    end)

    -- Ensure plot is resolved
    task.spawn(function()
        local plot = getPlot()
        local waited = 0
        while not plot and waited < 10 do
            waited += task.wait(0.2)
            plot = getPlot()
        end
        if not plot then
            warn("[OddsBoard] Player plot not found!")
            return
        end

        local deck = plot:WaitForChild("ViewingDeck", 5) :: Model?
        local boardPart = deck and deck:WaitForChild("OddsBoard", 5) :: BasePart?
        if not boardPart then
            warn("[OddsBoard] ViewingDeck.OddsBoard part not found on plot!")
            return
        end

        currentBoardPart = boardPart
        local sg = boardPart:FindFirstChildOfClass("SurfaceGui")
        if not sg then
            sg = Instance.new("SurfaceGui")
            sg.Name = "SurfaceGui"
            sg.Parent = boardPart
        end
        activeSurfaceGui = sg

        setupPlayerSurfaceGui(sg)
        refresh()

        -- Update any other plot boards with the generic placeholder
        local plotsFolder = Workspace:FindFirstChild("PlotsV3")
        if plotsFolder then
            for _, otherPlot in plotsFolder:GetChildren() do
                if otherPlot ~= plot and otherPlot:IsA("Model") then
                    local otherDeck = otherPlot:FindFirstChild("ViewingDeck")
                    local otherBoard = otherDeck and otherDeck:FindFirstChild("OddsBoard")
                    local otherSg = otherBoard and otherBoard:FindFirstChildOfClass("SurfaceGui")
                    if otherSg then
                        buildGenericBoard(otherSg)
                    end
                end
            end
        end

        -- Live event hooks for updates
        player:GetAttributeChangedSignal("Strength"):Connect(requestRefresh)
        player:GetAttributeChangedSignal("FoodTier"):Connect(requestRefresh)
        Ctx.on("hatched", requestRefresh)
        Ctx.on("book", requestRefresh)
        Ctx.on("bag", requestRefresh)
    end)
end

return OddsBoard
