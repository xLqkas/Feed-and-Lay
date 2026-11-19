--!strict
-- HUD for the core loop (design-v3 7.2 and 7.3), built only with the UI kit: Coins with +X/s, Food chip,
-- Nest chip, objective banner slot, THROW button (touch), power meter, Eat Card row, wash HUD, reveal cards.
-- Positions are 1080p reference pixels; Kit scales the root. Phone = Kit layout "compact".

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Ctx = require(script.Parent.Ctx)
local Sfx = require(script.Parent.Sfx)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Theme = require(UI:WaitForChild("Theme"))
local Logic = require(UI:WaitForChild("Logic"))

local C = Theme.Colors
local Economy = Ctx.Economy
local player = Players.LocalPlayer

local Hud = {}
local screen = Kit.screen("FLHud", 10)
Hud.screen = screen

-- Banner slot: one line, top-centre. nil hides it (the wash bar takes its place).
local bannerText: string? = nil
function Hud.setBanner(text: string?)
    if text == bannerText then
        return
    end
    bannerText = text
    if text then
        Kit.banner(screen, text).Visible = true
    elseif screen.banner then
        screen.banner.Visible = false
    end
end

function Hud.toast(message: string, kind: "gain" | "error" | "announce")
    Kit.toast(screen, message, kind)
end

-- Shake a GUI object sideways (cannot afford / nest full): +-6 px x3 in 0.25 s
function Hud.shake(object: GuiObject)
    local base = object:GetAttribute("FLShakeBase") :: UDim2?
    if not base then
        object:SetAttribute("FLShakeBase", object.Position)
        base = object.Position
    end
    local b = base :: UDim2
    for i, dx in { 6, -6, 6, -6, 6, 0 } do
        task.delay((i - 1) * 0.042, function()
            object.Position = b + UDim2.fromOffset(dx, 0)
        end)
    end
end

-- Small rounded chip: placeholder icon disc + text (icons: docs/ai/image-upload-list.md)
local function chip(parent: Instance, name: string, iconColor: Color3, width: number): (Frame, TextLabel)
    local f = Kit.frame(parent, name, C.panel)
    f.Size = UDim2.fromOffset(width, 56)
    Kit.corner(f, UDim.new(0.5, 0))
    Kit.stroke(f, C.outline, Theme.Stroke.panel, true)
    local icon = Kit.frame(f, "Icon", iconColor)
    icon.Size = UDim2.fromOffset(44, 44)
    icon.AnchorPoint = Vector2.new(0, 0.5)
    icon.Position = UDim2.new(0, 6, 0.5, 0)
    Kit.corner(icon, UDim.new(0.5, 0))
    Kit.stroke(icon, C.outline, 3, true)
    local label = Kit.text(f, "", Theme.TextSize.body)
    label.AnchorPoint = Vector2.new(0, 0.5)
    label.Position = UDim2.new(0, 58, 0.5, 0)
    label.Size = UDim2.new(1, -68, 0, 30)
    label.TextXAlignment = Enum.TextXAlignment.Left
    return f, label
end

-- Stats block: Coins pill, then Food and Nest chips (PC bottom-left in a row, phone top-left in a column)
local stats = Kit.frame(screen.root, "Stats")
stats.AutomaticSize = Enum.AutomaticSize.XY
local statsList = Instance.new("UIListLayout")
statsList.Padding = UDim.new(0, Theme.Space.lg)
statsList.VerticalAlignment = Enum.VerticalAlignment.Bottom
statsList.SortOrder = Enum.SortOrder.LayoutOrder
statsList.Parent = stats

local coins = Kit.currencyPill(stats, Theme.Images.coin, C.reward)
coins.frame.LayoutOrder = 1
Hud.coins = coins
local foodChip, foodLabel = chip(stats, "FoodChip", Color3.fromRGB(230, 60, 60), 210)
foodChip.LayoutOrder = 2
local nestChip, nestLabel = chip(stats, "NestChip", Color3.fromRGB(255, 240, 210), 190)
nestChip.LayoutOrder = 3
Hud.nestChip = nestChip
-- shortcut: Strength icon is a plain disc until the dumbbell icon exists (design-v3 7.5 item 6)
local strengthChip, strengthLabel = chip(stats, "StrengthChip", Color3.fromRGB(255, 140, 64), 230)
strengthChip.LayoutOrder = 4

-- Progressive HUD (design-v3 section 5): each element appears at the onboarding step where it becomes useful.
-- Coins 7, Nest 8, Strength 11, Food 15 (the food chip only matters once there is a second food).
function Hud.setStep(step: number)
    coins.frame.Visible = step >= 7
    nestChip.Visible = step >= 8
    strengthChip.Visible = step >= 11
    foodChip.Visible = step >= 15
end
Hud.setStep(0)

local function refreshStrength()
    strengthLabel.Text = "Strength " .. Logic.formatNumber(player:GetAttribute("Strength") or Economy.START_STRENGTH)
end
player:GetAttributeChangedSignal("Strength"):Connect(refreshStrength)
refreshStrength()

local foodButton = Instance.new("TextButton")
foodButton.Name = "Tap"
foodButton.BackgroundTransparency = 1
foodButton.Text = ""
foodButton.Size = UDim2.fromScale(1, 1)
foodButton.Parent = foodChip
-- shortcut: food "selector" only shows the food in use; the server always throws the best owned food and
-- buying food is the Upgrades panel (VS-10 / P-1), so there is nothing to pick yet.
foodButton.Activated:Connect(function()
    local food = Economy.Foods[Ctx.foodTier]
    Sfx.play("tick")
    Hud.toast(food.Name .. ": Luck x" .. food.Luck .. ". Your best food is always thrown.", "gain")
end)

function Hud.refreshFood()
    foodLabel.Text = Economy.Foods[Ctx.foodTier].Name
end

local function refreshNest()
    local used = player:GetAttribute("NestUsed") or 0
    local slots = player:GetAttribute("NestSlots") or Economy.START_NEST
    nestLabel.Text = "Nest " .. used .. "/" .. slots
    nestLabel.TextColor3 = if used >= slots then C.danger else C.paper
end
player:GetAttributeChangedSignal("NestUsed"):Connect(refreshNest)
player:GetAttributeChangedSignal("NestSlots"):Connect(refreshNest)

local function refreshCoins()
    Kit.setPillValue(coins, player:GetAttribute("Coins") or 0)
end
player:GetAttributeChangedSignal("Coins"):Connect(refreshCoins)
player:GetAttributeChangedSignal("IncomePerSecond"):Connect(function()
    Kit.setPillRate(coins, player:GetAttribute("IncomePerSecond") or 0)
end)
Kit.setPillValue(coins, player:GetAttribute("Coins") or 0, false)
Kit.setPillRate(coins, player:GetAttribute("IncomePerSecond") or 0)
refreshNest()
Hud.refreshFood()

function Hud.pulseNest()
    Hud.shake(nestChip)
    for i = 0, 1 do
        task.delay(i * 0.2, function()
            Kit.pop(nestChip, 1.12)
        end)
    end
end

-- THROW button (touch only, bottom-right above the jump button) and the key hint chip (PC / gamepad)
local throwButton, throwFace = Kit.button(screen.root, "THROW", "reward", UDim2.fromOffset(130, 130))
throwButton.AnchorPoint = Vector2.new(1, 1)
throwButton.Visible = false
for _, c in { throwButton, throwFace } do
    local corner = c:FindFirstChildOfClass("UICorner")
    if corner then
        corner.CornerRadius = UDim.new(0.5, 0)
    end
end
Hud.throwButton = throwButton

local hint, hintLabel = chip(screen.root, "ThrowHint", C.info, 340)
hint.AnchorPoint = Vector2.new(1, 1)
hint.Visible = false
Hud.hint = hint

function Hud.showThrowControls(onLedge: boolean)
    local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    throwButton.Visible = onLedge and touch
    local gamepad = UserInputService:GetLastInputType().Name:find("Gamepad") ~= nil
    hintLabel.Text = if gamepad then "Hold R2 to throw" else "Hold click or Space to throw"
    hint.Visible = onLedge and not touch
end

-- Power meter: zone bands for the current Strength, a green SWEET band, the needle
local meter = Kit.frame(screen.root, "Meter", C.track)
meter.AnchorPoint = Vector2.new(0.5, 1)
meter.Size = UDim2.new(0.5, 0, 0, 48)
meter.Visible = false
meter.ClipsDescendants = false
Kit.corner(meter, UDim.new(0, 12))
Kit.stroke(meter, C.outline, Theme.Stroke.panel, true)
local bands = Kit.frame(meter, "Bands")
bands.Size = UDim2.fromScale(1, 1)
bands.ClipsDescendants = true
Kit.corner(bands, UDim.new(0, 12))
local sweet = Kit.frame(meter, "Sweet")
sweet.Position = UDim2.fromScale(Economy.SWEET_MIN, 0)
sweet.Size = UDim2.fromScale(Economy.SWEET_MAX - Economy.SWEET_MIN, 1)
Kit.stroke(sweet, C.money, 4, true)
local sweetLabel = Kit.text(sweet, "SWEET", Theme.TextSize.small, C.money)
sweetLabel.AnchorPoint = Vector2.new(0.5, 1)
sweetLabel.Position = UDim2.new(0.5, 0, 0, -2)
sweetLabel.Size = UDim2.fromOffset(90, 22)
local needle = Kit.frame(meter, "Needle", C.paper)
needle.AnchorPoint = Vector2.new(0.5, 0.5)
needle.Size = UDim2.new(0, 10, 1, 24)
needle.Position = UDim2.fromScale(0, 0.5)
Kit.corner(needle, UDim.new(0.5, 0))
Kit.stroke(needle, C.outline, 3, true)
local releaseLabel = Kit.text(meter, "", Theme.TextSize.display)
releaseLabel.Name = "ReleaseLabel"
releaseLabel.AnchorPoint = Vector2.new(0.5, 1)
releaseLabel.Size = UDim2.fromOffset(420, 70)
releaseLabel.Visible = false
Hud.meter = meter

-- Rebuilds the bands: each needle position coloured by the zone a throw there reaches with this Strength
function Hud.buildMeter(strength: number)
    bands:ClearAllChildren()
    Kit.corner(bands, UDim.new(0, 12))
    local steps = 50
    local runStart, runZone = 0, nil
    local zoneColors = {
        Color3.fromRGB(150, 205, 110),
        Color3.fromRGB(96, 160, 90),
        Color3.fromRGB(200, 90, 60),
        Color3.fromRGB(70, 160, 190),
        Color3.fromRGB(130, 100, 220),
    }
    local function flush(stop: number)
        if not runZone then
            return
        end
        local seg = Kit.frame(bands, "Band", zoneColors[runZone])
        seg.Position = UDim2.fromScale(runStart / steps, 0)
        seg.Size = UDim2.fromScale((stop - runStart) / steps, 1)
        seg.BackgroundTransparency = 0.15
        if (stop - runStart) / steps >= 0.18 then
            local name = Kit.text(seg, Economy.Zones[runZone].Name, Theme.TextSize.small)
            name.Size = UDim2.fromScale(1, 0.6)
            name.AnchorPoint = Vector2.new(0.5, 0.5)
            name.Position = UDim2.fromScale(0.5, 0.5)
        end
    end
    for i = 0, steps - 1 do
        local p = (i + 0.5) / steps
        local zone = Economy.zoneForDistance(strength * Economy.throwMultiplier(p)).Id
        if zone ~= runZone then
            flush(i)
            runStart, runZone = i, zone
        end
    end
    flush(steps)
end

function Hud.setNeedle(p: number)
    needle.Position = UDim2.fromScale(p, 0.5)
end

-- Release label pops (0.6 -> 1, Back) for 0.6 s; SWEET is gold with an 8-star burst
function Hud.releaseLabel(text: string, isSweet: boolean)
    releaseLabel.Text = text
    releaseLabel.TextColor3 = if isSweet then C.reward else C.paper
    releaseLabel.Position = UDim2.new(0.5, 0, 0, -30)
    releaseLabel.Visible = true
    Kit.pop(releaseLabel, 0.6)
    if isSweet then
        for i = 1, 8 do
            local star = Kit.text(meter, "*", Theme.TextSize.title, C.reward)
            star.AnchorPoint = Vector2.new(0.5, 0.5)
            star.Size = UDim2.fromOffset(40, 40)
            star.Position = UDim2.new(0.5, 0, 0, -60)
            local a = (i / 8) * math.pi * 2
            Kit.tween(
                star,
                0.5,
                { Position = UDim2.new(0.5, math.cos(a) * 160, 0, -60 + math.sin(a) * 70), TextTransparency = 1 }
            )
            task.delay(0.55, function()
                star:Destroy()
            end)
        end
    end
    task.delay(0.6, function()
        if releaseLabel.Text == text then
            releaseLabel.Visible = false
        end
    end)
end

-- Eat Cards row (bottom-centre above the meter); Hen.luau fills it
local eatRow = Kit.frame(screen.root, "EatCards")
eatRow.AnchorPoint = Vector2.new(0.5, 1)
eatRow.AutomaticSize = Enum.AutomaticSize.XY
local eatList = Instance.new("UIListLayout")
eatList.FillDirection = Enum.FillDirection.Horizontal
eatList.Padding = UDim.new(0, Theme.Space.md)
eatList.Parent = eatRow
Hud.eatRow = eatRow

-- Wash HUD: progress bar (replaces the banner), aim hint, nozzle chip, X button
local wash = Kit.frame(screen.root, "WashHud")
wash.Size = UDim2.fromScale(1, 1)
wash.Visible = false
local washBar = Kit.progressBar(wash, UDim2.fromOffset(640, 44), C.info)
washBar.frame.AnchorPoint = Vector2.new(0.5, 0.5)
local washHint, washHintLabel = chip(wash, "AimHint", C.info, 380)
washHint.AnchorPoint = Vector2.new(0.5, 0)
local nozzleChip, nozzleLabel = chip(wash, "NozzleChip", C.danger, 460)
nozzleChip.AnchorPoint = Vector2.new(0.5, 0)
local close = Kit.iconButton(wash, Theme.Images.close, "X", "danger", 64)
close.AnchorPoint = Vector2.new(1, 0)
Hud.wash = { frame = wash, bar = washBar, close = close, nozzle = nozzleChip }

function Hud.showWash(visible: boolean, zoneId: number?)
    wash.Visible = visible
    if not visible then
        return
    end
    local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    washHintLabel.Text = if touch then "Touch and drag on the mud" else "Hold click and aim at the mud"
    local zone = zoneId or 1
    local weak = Ctx.nozzleLevel < zone and Economy.Nozzles[Ctx.nozzleLevel + 1] ~= nil
    nozzleChip.Visible = weak
    if weak then
        local price = Economy.Nozzles[Ctx.nozzleLevel + 1].Cost
        nozzleLabel.Text = "Nozzle too weak! Upgrade: " .. Logic.formatNumber(price)
        nozzleLabel.TextColor3 = if (player:GetAttribute("Coins") or 0) >= price then C.money else C.danger
    end
end

function Hud.setWashProgress(fraction: number, zoneName: string)
    Kit.setProgress(washBar, fraction, math.floor(fraction * 100 + 0.5) .. "%  " .. zoneName)
end

-- Big centred word that pops and fades ("CLEAN!")
function Hud.popWord(text: string, color: Color3)
    local word = Kit.text(screen.root, text, Theme.TextSize.display, color)
    word.AnchorPoint = Vector2.new(0.5, 0.5)
    word.Position = UDim2.fromScale(0.5, 0.4)
    word.Size = UDim2.fromOffset(600, 80)
    Kit.pop(word, 0.4)
    task.delay(0.7, function()
        Kit.tween(word, 0.25, { TextTransparency = 1 })
        task.delay(0.3, function()
            word:Destroy()
        end)
    end)
end

-- Reveal card: rarity word, creature name, mutation word, +X/s. Full = centre, compact = small top-centre.
export type Card = { frame: Frame, rarity: TextLabel, name: TextLabel, mutation: TextLabel, income: TextLabel }
function Hud.card(compact: boolean): Card
    local f = Kit.frame(screen.root, "RevealCard", C.panel)
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Size = if compact then UDim2.fromOffset(380, 150) else UDim2.fromOffset(560, 260)
    f.Position = if compact then UDim2.fromScale(0.5, 0.22) else UDim2.fromScale(0.5, 0.24)
    f.ZIndex = 40
    Kit.corner(f, UDim.new(0, Theme.Radius.panel))
    local edge = Kit.stroke(f, C.outline, 6, true)
    edge.Name = "Edge"
    local list = Instance.new("UIListLayout")
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.VerticalAlignment = Enum.VerticalAlignment.Center
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = f
    local s = if compact then 0.6 else 1
    local function line(order: number, size: number, color: Color3?): TextLabel
        local t = Kit.text(f, "", math.floor(size * s), color)
        t.LayoutOrder = order
        t.Size = UDim2.new(1, -24, 0, math.ceil(size * s * 1.2))
        t.ZIndex = 41
        return t
    end
    local card = {
        frame = f,
        rarity = line(1, Theme.TextSize.display),
        name = line(2, Theme.TextSize.title),
        mutation = line(3, Theme.TextSize.heading, C.info),
        income = line(4, Theme.TextSize.heading, C.money),
    }
    Kit.pop(f, 0.7)
    return card
end

-- Layout: PC vs phone composition (design-v3 7.2)
Kit.onLayout(screen, function(info)
    local compact = info.compact
    statsList.FillDirection = if compact then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
    stats.AnchorPoint = if compact then Vector2.new(0, 0) else Vector2.new(0, 1)
    stats.Position = if compact then UDim2.new(0.02, 20, 0.10, 0) else UDim2.new(0.02, 20, 0.95, -24)
    throwButton.Position = UDim2.new(1, -40, 1, -300)
    meter.Size = if compact then UDim2.new(0.8, 0, 0, 48) else UDim2.new(0.5, 0, 0, 48)
    meter.Position = if compact then UDim2.fromScale(0.5, 0.72) else UDim2.fromScale(0.5, 0.8)
    hint.Position = UDim2.new(0.98, 0, 0.95, -24)
    eatRow.Position = if compact then UDim2.new(0.5, 0, 0.72, -190) else UDim2.new(0.5, 0, 0.8, -190)
    washBar.frame.Size = if compact then UDim2.new(0.8, 0, 0, 44) else UDim2.fromOffset(640, 44)
    washBar.frame.Position = UDim2.fromScale(0.5, if compact then 0.05 else 0.10)
    washHint.Position = UDim2.new(0.5, 0, if compact then 0.05 else 0.10, 40)
    nozzleChip.Position = UDim2.new(0.5, 0, if compact then 0.05 else 0.10, 106)
    close.Position = UDim2.fromScale(0.98, if compact then 0.2 else 0.05)
end)

return Hud
