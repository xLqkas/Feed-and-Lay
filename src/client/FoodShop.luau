--!strict
-- FoodShop: Client module for the central Food Shop window (phase0 Step 2, docs/tasks/gemini_plot_redesign.md)
-- Chunky Nest aesthetics, built with Kit & Theme components.
-- Horizontal scroll of food cards, buying calls Ctx.invoke("Buy", "Food").

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Ctx = require(script.Parent.Ctx)
local Sfx = require(script.Parent.Sfx)
local UI = script.Parent.Parent:WaitForChild("UI")
local Icons = require(UI:WaitForChild("Icons"))
local Kit = require(UI:WaitForChild("Kit"))
local Logic = require(UI:WaitForChild("Logic"))
local Theme = require(UI:WaitForChild("Theme"))

local Economy = Ctx.Economy
local player = Players.LocalPlayer

local FoodShop = {}

local screen: any = nil
local panels: any = nil
local shellFrame: Frame? = nil
local bodyFrame: Frame? = nil
local cardsScroll: ScrollingFrame? = nil
local cardInstances: { [number]: { card: Frame, btn: TextButton, btnLbl: TextLabel } } = {}
local isOpen = false
local initialized = false

local FOOD_ICONS: { [number]: string } = {
    [1] = "🍏",
    [2] = "🥕",
    [3] = "🫐",
    [4] = "🥞",
    [5] = "🍓",
    [6] = "⭐",
}

local FOOD_IMAGE_ASSETS: { [number]: string } = {
    [2] = Icons.Assets.foodCarrot or "",
    [3] = Icons.Assets.foodBlueberry or "",
    [4] = Icons.Assets.foodPancake or "",
    [5] = Icons.Assets.foodCookie or "",
}

local function formatNumber(n: number): string
    if n >= 1e9 then
        return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then
        return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then
        return string.format("%.1fK", n / 1e3)
    else
        return tostring(math.floor(n))
    end
end

local function currentFoodTier(): number
    local tier = player:GetAttribute("FoodTier")
    if type(tier) == "number" then
        return tier
    end
    return Ctx.foodTier or 1
end

local function playerCoins(): number
    return (player:GetAttribute("Coins") :: number?) or Ctx.coins or 0
end

--------------------------------------------------------------------------------
-- Build & Layout
--------------------------------------------------------------------------------

local function refreshCards()
    if not isOpen or not cardsScroll then
        return
    end

    local cTier = currentFoodTier()
    local coins = playerCoins()
    local foods = Economy.Foods

    for i = 1, #foods do
        local food = foods[i]
        local cost = Economy.upgradeCost("Food", i - 1) or 0
        local cardData = cardInstances[i]
        if not cardData then
            continue
        end

        local btn = cardData.btn
        local btnLbl = cardData.btnLbl
        local card = cardData.card
        local stroke = card:FindFirstChildOfClass("UIStroke")

        if i == cTier then
            -- EQUIPPED
            Kit.setRole(btn, "dim")
            btnLbl.Text = "EQUIPPED"
            btn.Active = false
            if stroke then
                stroke.Color = Theme.Colors.reward or Color3.fromHex("FFC800")
                stroke.Thickness = 4
            end
        elseif i < cTier then
            -- OWNED
            Kit.setRole(btn, "dim")
            btnLbl.Text = "OWNED"
            btn.Active = false
            if stroke then
                stroke.Color = Theme.Colors.outline or Color3.fromHex("334155")
                stroke.Thickness = 3
            end
        elseif i == cTier + 1 then
            -- NEXT TIER TO BUY
            local affordable = coins >= cost
            if affordable then
                Kit.setRole(btn, "confirm")
                btnLbl.Text = "🪙 " .. formatNumber(cost)
                btn.Active = true
            else
                Kit.setRole(btn, "destructive")
                btnLbl.Text = "🪙 " .. formatNumber(cost)
                btn.Active = true
            end
            if stroke then
                stroke.Color = if affordable then (Theme.Colors.reward or Color3.fromHex("FFC800")) else (Theme.Colors.danger or Color3.fromHex("EF4444"))
                stroke.Thickness = 3
            end
        else
            -- LOCKED
            Kit.setRole(btn, "dim")
            btnLbl.Text = "Locked"
            btn.Active = false
            if stroke then
                stroke.Color = Theme.Colors.outline or Color3.fromHex("334155")
                stroke.Thickness = 2
            end
        end
    end
end

local function onCardClicked(tier: number)
    local cTier = currentFoodTier()
    if tier ~= cTier + 1 then
        return
    end

    local cost = Economy.upgradeCost("Food", cTier) or 0
    local coins = playerCoins()

    if coins < cost then
        Sfx.play("bad")
        local cardData = cardInstances[tier]
        if cardData then
            Kit.shake(cardData.btn)
        end
        return
    end

    Sfx.play("coin")
    -- Call server Buy remote
    local reply = Ctx.invoke("Buy", "Food", "foodTier")
    if reply and reply.ok then
        Sfx.play("chime")
        refreshCards()
    else
        Sfx.play("bad")
    end
end

local function buildWindow()
    if screen then
        return
    end
    local pGui = player:WaitForChild("PlayerGui")
    local existing = pGui:FindFirstChild("FLFoodShopScreen")
    if existing then
        existing:Destroy()
    end
    screen = Kit.screen("FLFoodShopScreen", 15)
    panels = Kit.panels(screen)

    local shell, body = Kit.shell(screen, panels, "FoodShop", "Food Shop", nil)
    shellFrame = shell
    bodyFrame = body

    Kit.onLayout(screen, function(info)
        local w = if info.compact then math.min(info.refWidth - 20, 480) else 680
        local h = if info.compact then math.min(info.refHeight - 30, 420) else 440
        shell.Size = UDim2.fromOffset(w, h)
        Kit.fitPanel(shell, info)
    end)

    -- Horizontal Scroll of Food Cards
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "CardsScroll"
    scroll.Size = UDim2.new(1, -20, 1, -20)
    scroll.Position = UDim2.new(0, 10, 0, 10)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.ScrollBarImageColor3 = Theme.Colors.reward or Color3.fromHex("FFC800")
    scroll.ScrollingDirection = Enum.ScrollingDirection.X
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.X
    scroll.CanvasSize = UDim2.new(0, 0, 1, 0)
    scroll.Parent = body
    cardsScroll = scroll

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 14)
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Parent = scroll

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = scroll

    local foods = Economy.Foods

    for i = 1, #foods do
        local food = foods[i]

        local card = Instance.new("Frame")
        card.Name = "Card_" .. i
        card.Size = UDim2.new(0, 150, 1, -16)
        card.BackgroundColor3 = Theme.Colors.panel or Color3.fromHex("1E293B")
        card.BorderSizePixel = 0
        card.LayoutOrder = i
        card.Parent = scroll

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 16)
        cardCorner.Parent = card

        local cardStroke = Instance.new("UIStroke")
        cardStroke.Color = Theme.Colors.outline or Color3.fromHex("334155")
        cardStroke.Thickness = 3
        cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        cardStroke.Parent = card

        -- Title: Food Name
        local nameLbl = Instance.new("TextLabel")
        nameLbl.Name = "FoodName"
        nameLbl.Size = UDim2.new(1, -12, 0, 28)
        nameLbl.Position = UDim2.new(0, 6, 0, 10)
        nameLbl.BackgroundTransparency = 1
        nameLbl.TextColor3 = Theme.Colors.paper or Color3.fromHex("F8FAFC")
        nameLbl.FontFace = Theme.Fonts.title
        nameLbl.TextSize = 18
        nameLbl.Text = food.Name
        nameLbl.Parent = card

        -- Icon Display (Large Emoji or Icon)
        local iconLbl = Instance.new("TextLabel")
        iconLbl.Name = "FoodIcon"
        iconLbl.Size = UDim2.new(1, -20, 0, 80)
        iconLbl.Position = UDim2.new(0, 10, 0, 42)
        iconLbl.BackgroundTransparency = 1
        iconLbl.TextSize = 54
        iconLbl.Text = FOOD_ICONS[i] or "🍎"
        iconLbl.Parent = card

        -- Subtitle: Tier & Luck Multiplier
        local mult = food.LuckMultiplier or food.Luck or 1
        local luckLbl = Instance.new("TextLabel")
        luckLbl.Name = "LuckMultiplier"
        luckLbl.Size = UDim2.new(1, -12, 0, 22)
        luckLbl.Position = UDim2.new(0, 6, 0, 130)
        luckLbl.BackgroundColor3 = Theme.Colors.panel or Color3.fromHex("0F172A")
        luckLbl.TextColor3 = Theme.Colors.reward or Color3.fromHex("FFC800")
        luckLbl.FontFace = Theme.Fonts.title
        luckLbl.TextSize = 13
        luckLbl.Text = string.format("Tier %d • %sx Luck", i, tostring(mult))
        luckLbl.Parent = card

        local luckCorner = Instance.new("UICorner")
        luckCorner.CornerRadius = UDim.new(0, 8)
        luckCorner.Parent = luckLbl

        -- Bottom Action Button
        local btn, btnLbl = Kit.button(card, "...", "confirm", UDim2.new(1, -16, 0, 40))
        btn.Position = UDim2.new(0.5, 0, 1, -14)
        btn.AnchorPoint = Vector2.new(0.5, 1)

        btn.MouseButton1Click:Connect(function()
            onCardClicked(i)
        end)

        cardInstances[i] = {
            card = card,
            btn = btn,
            btnLbl = btnLbl,
        }
    end

    -- Listen to close panel
    Kit.onPanel(panels, function(openName)
        isOpen = (openName == "FoodShop")
        if isOpen then
            refreshCards()
        end
    end)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function FoodShop.open()
    if not panels then
        buildWindow()
    end
    Kit.showPanel(panels, "FoodShop")
    isOpen = true
    refreshCards()
    Sfx.play("open")
end

function FoodShop.close()
    if panels and isOpen then
        Kit.hidePanel(panels, "FoodShop")
        isOpen = false
        Sfx.play("close")
    end
end

function FoodShop.toggle()
    if isOpen then
        FoodShop.close()
    else
        FoodShop.open()
    end
end

function FoodShop.init()
    if initialized then
        return
    end
    initialized = true

    buildWindow()

    -- Connect ProximityPrompt on Workspace.Hub.FoodShop
    task.spawn(function()
        local waited = 0
        local prompt: ProximityPrompt? = nil
        while not prompt and waited < 10 do
            local hub = Workspace:FindFirstChild("Hub")
            local shop = hub and hub:FindFirstChild("FoodShop")
            local counter = shop and shop:FindFirstChild("Counter")
            prompt = counter and counter:FindFirstChildOfClass("ProximityPrompt")
            if not prompt then
                waited += task.wait(0.3)
            end
        end

        if prompt then
            prompt.Triggered:Connect(function(plr)
                if plr == player then
                    FoodShop.open()
                end
            end)
        end
    end)

    -- Live updates
    player:GetAttributeChangedSignal("Coins"):Connect(refreshCards)
    player:GetAttributeChangedSignal("FoodTier"):Connect(refreshCards)
    Ctx.on("food", refreshCards)
    Ctx.on("coins", refreshCards)

    -- Escape key closes window
    UserInputService.InputBegan:Connect(function(input, processed)
        if input.KeyCode == Enum.KeyCode.Escape and isOpen then
            FoodShop.close()
        end
    end)
end

return FoodShop
