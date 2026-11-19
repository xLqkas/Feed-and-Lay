--!strict
-- HUD for the core loop (docs/ai/ui-style-spec.md section 2, design-v3 7.2 / 7.3), built only with the UI kit:
-- menu columns (Menus fills them), currency stack (Coins, Nest, Strength, Food selector), objective line and
-- goal bar, THROW button (touch), power meter, Eat Card row, wash HUD, reveal text, big words.
-- Positions are 1080p reference pixels; Kit scales the root. Phone = Kit layout "compact".

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Ctx = require(script.Parent.Ctx)
local Sfx = require(script.Parent.Sfx)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Logic = require(UI:WaitForChild("Logic"))
local Motion = require(UI:WaitForChild("Motion"))
local Theme = require(UI:WaitForChild("Theme"))

local C = Theme.Colors
local T = Theme.TextSize
local Economy = Ctx.Economy
local player = Players.LocalPlayer
local FOOD_ICONS = { "food1Apple", "food2Carrot", "food3Blueberry", "food4Pancake", "food5Strawberry", "food6Cookie" }

local Hud = {}
local screen = Kit.screen("FLHud", 10)
Hud.screen = screen

-- Objective line (spec 2.4). nil hides it (the wash bar takes its place); hidden while a panel is open.
local bannerText: string? = nil
local hiddenPanel = false
function Hud.setBanner(text: string?)
    if text == bannerText then
        return
    end
    bannerText = text
    if text then
        Kit.banner(screen, text).Visible = not hiddenPanel
    elseif screen.banner then
        screen.banner.Visible = false
    end
    if not text then
        Kit.bannerGoal(screen, nil, nil)
    end
end

-- Count goal under the objective ("52 / 80"); nil hides it.
function Hud.setGoal(current: number?, target: number?)
    if bannerText and not hiddenPanel then
        Kit.bannerGoal(screen, current, target)
    end
end

function Hud.toast(message: string, kind: "gain" | "error" | "announce")
    Kit.toast(screen, message, kind)
end

-- Cannot-afford / nest-full shake (Motion "shake")
function Hud.shake(object: GuiObject)
    Motion.shake(object)
end

-- Menu columns (spec 2.1): left Book, right Upgrades. Menus adds the tiles.
local function column(name: string, right: boolean): Frame
    local f = Kit.frame(screen.root, name)
    f.AnchorPoint = Vector2.new(if right then 1 else 0, 0.5)
    f.AutomaticSize = Enum.AutomaticSize.XY
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 30) -- 14 gap + room for the overhanging label
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.HorizontalAlignment = if right then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
    list.Parent = f
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 12) -- icons overhang the top tile
    pad.Parent = f
    return f
end
Hud.leftColumn = column("LeftColumn", false)
Hud.rightColumn = column("RightColumn", true)

-- Columns slide off their edge while a panel is open or a station HUD is up (C10).
local hidden: { [string]: boolean } = {}
local columnY = 0.40
local function placeColumns(animate: boolean)
    local off = false
    for _, v in hidden do
        off = off or v
    end
    local slide = 0.15 * 1080
    local name = if off then (if hidden.panel then "hudHide" else "stationHide") else "hudShow"
    for _, pair in { { Hud.leftColumn, -1, 24 }, { Hud.rightColumn, 1, -24 } } do
        local f, dir, x = pair[1] :: Frame, pair[2] :: number, pair[3] :: number
        local edge = if dir > 0 then 1 else 0
        local goal = UDim2.new(edge, x + (if off then dir * slide else 0), columnY, 0)
        if animate then
            Motion.play(f, name, { Position = goal })
        else
            f.Position = goal
        end
    end
end
function Hud.setHidden(reason: string, on: boolean)
    if (hidden[reason] or false) ~= on then
        hidden[reason] = on
        placeColumns(true)
    end
    if reason == "panel" then
        hiddenPanel = on
        if screen.banner then
            screen.banner.Visible = bannerText ~= nil and not on
        end
        if screen.goal and on then
            screen.goal.Visible = false
        end
        -- gain / error lane drops to the screen bottom so it does not cover the panel's rows
        screen.toasts.Position = if on
            then UDim2.new(0.5, 0, 1, -8)
            else UDim2.fromScale(0.5, if screen.info.compact then 0.70 else 0.80)
    end
end

-- Currency stack (spec 2.3): Coins, Nest, Strength, Food. Left edge under the menu column.
local stats = Kit.frame(screen.root, "Stats")
stats.AutomaticSize = Enum.AutomaticSize.XY
local statsList = Instance.new("UIListLayout")
statsList.Padding = UDim.new(0, 10)
statsList.SortOrder = Enum.SortOrder.LayoutOrder
statsList.Parent = stats

local coins = Kit.currencyPill(stats, Kit.art("coin"))
coins.frame.LayoutOrder = 1
coins.frame.Size = UDim2.fromOffset(260, 74) -- room for the +X/s line
coins.icon.Position = UDim2.fromOffset(0, 0)
coins.value.Position = UDim2.fromOffset(60, 26)
local coinShadow = coins.frame:FindFirstChild("Shadow") :: TextLabel
coinShadow.Position = UDim2.fromOffset(60, 29)
coins.rate.Position = UDim2.fromOffset(60, 48)
Hud.coins = coins
local nest = Kit.currencyPill(stats, Kit.art("egg"))
nest.frame.LayoutOrder = 2
Hud.nestChip = nest.frame
-- shortcut: Strength uses the blue lightning icon until a dumbbell icon exists (missing art, spec 8)
local strength = Kit.currencyPill(stats, Kit.art("lightningBlue"))
strength.frame.LayoutOrder = 3
local food = Kit.currencyPill(stats, Kit.art("food1Apple"))
food.frame.LayoutOrder = 4

-- Food selector: shows the food in use; tap tells what it does. The server always throws the best owned
-- food and buying food is the Upgrades panel, so there is nothing to pick yet (design-v3 P-1).
local foodTap = Instance.new("TextButton")
foodTap.Name = "Tap"
foodTap.BackgroundTransparency = 1
foodTap.Text = ""
foodTap.Size = UDim2.fromScale(1, 1)
foodTap.Parent = food.frame
Kit.pressable(foodTap, nil)
foodTap.Activated:Connect(function()
    local f = Economy.Foods[Ctx.foodTier]
    Sfx.play("tick")
    Motion.pop(food.icon, 1.2)
    Hud.toast(f.Name .. ": Luck x" .. f.Luck .. ". Your best food is always thrown.", "gain")
end)

function Hud.refreshFood()
    food.value.Text = Economy.Foods[Ctx.foodTier].Name
    food.icon.Image = Kit.art(FOOD_ICONS[Ctx.foodTier] or FOOD_ICONS[1])
end

-- Progressive HUD (design-v3 section 5): Coins 7, Nest 8, Strength 11, Food 15. New rows pop in.
local shownStep = -1
function Hud.setStep(step: number)
    for _, pair in { { coins.frame, 7 }, { nest.frame, 8 }, { strength.frame, 11 }, { food.frame, 15 } } do
        local f, at = pair[1] :: Frame, pair[2] :: number
        local show = step >= at
        if show and not f.Visible and shownStep >= 0 then
            Motion.scaleTo(f, "newButton")
        end
        f.Visible = show
    end
    shownStep = step
end
Hud.setStep(0)

local function refreshStrength()
    local s = player:GetAttribute("Strength") or Economy.START_STRENGTH
    if strength.number.Value == 0 then
        Kit.setPillValue(strength, s, false)
    else
        Kit.setPillValue(strength, s)
    end
end
player:GetAttributeChangedSignal("Strength"):Connect(refreshStrength)
refreshStrength()

local function refreshNest()
    local used = player:GetAttribute("NestUsed") or 0
    local slots = player:GetAttribute("NestSlots") or Economy.START_NEST
    nest.value.Text = "Nest " .. used .. "/" .. slots
    nest.value.TextColor3 = if used >= slots then C.danger else C.paper
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
    Motion.shake(nest.frame)
    for i = 0, 1 do
        task.delay(i * 0.2, function()
            Motion.pop(nest.icon, 1.2)
        end)
    end
end

-- THROW button (touch only, bottom-right above the jump button) and the key hint (PC / gamepad)
local throwButton = Kit.iconButton(screen.root, Kit.art("food1Apple"), "THROW", "reward", 130)
throwButton.AnchorPoint = Vector2.new(1, 1)
throwButton.Visible = false
local throwLabel = Kit.text(throwButton, "THROW", T.button, C.paper, nil, 3)
throwLabel.AnchorPoint = Vector2.new(0.5, 0.5)
throwLabel.Position = UDim2.fromScale(0.5, 1)
throwLabel.Size = UDim2.fromOffset(160, 40)
throwLabel.ZIndex = 5
Hud.throwButton = throwButton

local hint = Kit.frame(screen.root, "ThrowHint")
hint.AnchorPoint = Vector2.new(1, 1)
hint.Size = UDim2.fromOffset(420, 48)
hint.Visible = false
local hintIcon = Kit.image(hint, "info")
hintIcon.AnchorPoint = Vector2.new(1, 0.5)
hintIcon.Position = UDim2.fromScale(1, 0.5)
hintIcon.Size = UDim2.fromOffset(44, 44)
local hintLabel = Kit.text(hint, "", T.heading, C.paper, nil, 3)
hintLabel.AnchorPoint = Vector2.new(1, 0.5)
hintLabel.Position = UDim2.new(1, -52, 0.5, 0)
hintLabel.Size = UDim2.new(1, -52, 0, 36)
hintLabel.TextXAlignment = Enum.TextXAlignment.Right
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
meter.Size = UDim2.new(0.5, 0, 0, 52)
meter.Visible = false
meter.ClipsDescendants = false
Kit.corner(meter, UDim.new(0, 16))
Kit.stroke(meter, C.outline, 5, true)
local bands = Kit.frame(meter, "Bands")
bands.Size = UDim2.fromScale(1, 1)
bands.ClipsDescendants = true
Kit.corner(bands, UDim.new(0, 16))
local sweet = Kit.frame(meter, "Sweet")
sweet.Position = UDim2.fromScale(Economy.SWEET_MIN, 0)
sweet.Size = UDim2.fromScale(Economy.SWEET_MAX - Economy.SWEET_MIN, 1)
Kit.stroke(sweet, C.money, 5, true)
local sweetLabel = Kit.text(sweet, "SWEET", T.label, C.money, nil, 3)
sweetLabel.AnchorPoint = Vector2.new(0.5, 1)
sweetLabel.Position = UDim2.new(0.5, 0, 0, -4)
sweetLabel.Size = UDim2.fromOffset(110, 30)
local needle = Kit.frame(meter, "Needle", C.paper)
needle.AnchorPoint = Vector2.new(0.5, 0.5)
needle.Size = UDim2.new(0, 12, 1, 28)
needle.Position = UDim2.fromScale(0, 0.5)
Kit.corner(needle, UDim.new(0.5, 0))
Kit.stroke(needle, C.outline, 3, true)
local releaseLabel = Kit.text(meter, "", T.display, C.paper, nil, 4)
releaseLabel.Name = "ReleaseLabel"
releaseLabel.AnchorPoint = Vector2.new(0.5, 1)
releaseLabel.Size = UDim2.fromOffset(420, 70)
releaseLabel.Visible = false
Hud.meter = meter

-- Rebuilds the bands: each needle position coloured by the zone a throw there reaches with this Strength
function Hud.buildMeter(power: number)
    bands:ClearAllChildren()
    Kit.corner(bands, UDim.new(0, 16))
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
        local shine = Instance.new("UIGradient")
        shine.Rotation = 90
        shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.78, 0.78, 0.78))
        shine.Parent = seg
        if (stop - runStart) / steps >= 0.18 then
            local name = Kit.text(seg, Economy.Zones[runZone].Name, T.body, C.paper, nil, 2)
            name.Size = UDim2.fromScale(1, 0.6)
            name.AnchorPoint = Vector2.new(0.5, 0.5)
            name.Position = UDim2.fromScale(0.5, 0.5)
        end
    end
    for i = 0, steps - 1 do
        local p = (i + 0.5) / steps
        local zone = Economy.zoneForDistance(power * Economy.throwMultiplier(p)).Id
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

-- Release label pops for 0.6 s; SWEET is gold with an 8-star burst
function Hud.releaseLabel(text: string, isSweet: boolean)
    releaseLabel.Text = text
    releaseLabel.TextColor3 = if isSweet then C.reward else C.paper
    releaseLabel.TextTransparency = 0
    releaseLabel.Position = UDim2.new(0.5, 0, 0, -36)
    releaseLabel.Visible = true
    Motion.pop(releaseLabel, 0.6)
    if isSweet then
        for i = 1, 8 do
            local star = Kit.image(meter, "starGolden")
            star.AnchorPoint = Vector2.new(0.5, 0.5)
            star.Size = UDim2.fromOffset(44, 44)
            star.Position = UDim2.new(0.5, 0, 0, -70)
            local a = (i / 8) * math.pi * 2
            Motion.play(star, "floatNumber", {
                Position = UDim2.new(0.5, math.cos(a) * 170, 0, -70 + math.sin(a) * 80),
                ImageTransparency = 1,
            })
            task.delay(Motion.get("floatNumber").Time + 0.05, function()
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

-- Wash HUD: progress bar (replaces the objective), aim hint, nozzle warning, close button
local wash = Kit.frame(screen.root, "WashHud")
wash.Size = UDim2.fromScale(1, 1)
wash.Visible = false
local washBar = Kit.progressBar(wash, UDim2.fromOffset(640, 44), nil)
washBar.frame.AnchorPoint = Vector2.new(0.5, 0.5)
local washHint = Kit.text(wash, "", T.heading, C.paper, nil, 3)
washHint.Name = "AimHint"
washHint.AnchorPoint = Vector2.new(0.5, 0)
washHint.Size = UDim2.fromOffset(700, 36)
local nozzleChip = Kit.frame(wash, "NozzleChip")
nozzleChip.AnchorPoint = Vector2.new(0.5, 0)
nozzleChip.Size = UDim2.fromOffset(620, 52)
local nozzleIcon = Kit.image(nozzleChip, "upgrade")
nozzleIcon.Size = UDim2.fromOffset(52, 52)
local nozzleLabel = Kit.text(nozzleChip, "", T.heading, C.danger, nil, 3)
nozzleLabel.AnchorPoint = Vector2.new(0, 0.5)
nozzleLabel.Position = UDim2.new(0, 60, 0.5, 0)
nozzleLabel.Size = UDim2.new(1, -60, 0, 36)
nozzleLabel.TextXAlignment = Enum.TextXAlignment.Left
local close = Kit.closeButton(wash, 72)
close.AnchorPoint = Vector2.new(1, 0)
Hud.wash = { frame = wash, bar = washBar, close = close, nozzle = nozzleChip }

function Hud.showWash(visible: boolean, zoneId: number?)
    wash.Visible = visible
    if not visible then
        return
    end
    local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    washHint.Text = if touch then "Touch and drag on the mud" else "Hold click and aim at the mud"
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
    local word = Kit.text(screen.root, text, T.hero, color, nil, 5)
    word.AnchorPoint = Vector2.new(0.5, 0.5)
    word.Position = UDim2.fromScale(0.5, 0.4)
    word.Size = UDim2.fromOffset(700, 100)
    Motion.scaleTo(word, "revealLand")
    task.delay(0.7, function()
        Motion.fadeOut(word, "wordOut", true)
    end)
end

-- Reveal (spec 4.9): white flash, then a text stack: mutation, name (hero), rarity, +X/s; NEW! sticker on a
-- first catch. Full = top centre over the pad camera; compact = smaller, no flash.
export type Card = { frame: Frame, rarity: TextLabel, name: TextLabel, mutation: TextLabel, income: TextLabel }
function Hud.card(compact: boolean): Card
    if not compact and not Motion.reduced() then
        local flash = Kit.frame(screen.root, "RevealFlash", C.paper)
        flash.Position = UDim2.fromOffset(0, -200) -- also covers the top bar inset above the safe area
        flash.Size = UDim2.new(1, 0, 1, 400)
        flash.BackgroundTransparency = 1
        flash.ZIndex = 45
        Motion.play(flash, "revealFlashIn", { BackgroundTransparency = 0.15 }).Completed:Connect(function()
            Motion.play(flash, "revealFlashOut", { BackgroundTransparency = 1 })
            task.delay(Motion.get("revealFlashOut").Time + 0.05, function()
                flash:Destroy()
            end)
        end)
    end
    local f = Kit.frame(screen.root, "RevealCard")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Size = if compact then UDim2.fromOffset(600, 170) else UDim2.fromOffset(1000, 300)
    f.Position = if compact then UDim2.fromScale(0.5, 0.22) else UDim2.fromScale(0.5, 0.25)
    f.ZIndex = 40
    local list = Instance.new("UIListLayout")
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.VerticalAlignment = Enum.VerticalAlignment.Center
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, -6)
    list.Parent = f
    local s = if compact then 0.6 else 1
    local function line(order: number, size: number, color: Color3?, strokeSize: number): TextLabel
        local t = Kit.text(f, "", math.floor(size * s), color, nil, strokeSize)
        t.LayoutOrder = order
        t.Size = UDim2.new(1, 0, 0, math.ceil(size * s * 1.15))
        t.ZIndex = 41
        return t
    end
    local card = {
        frame = f,
        mutation = line(1, 32, C.reward, 3),
        name = line(2, T.hero, C.paper, 5),
        rarity = line(3, 40, C.paper, 4),
        income = line(4, 32, C.money, 3),
    }
    Motion.scaleTo(f, "objectiveIn")
    return card
end

-- Land: final text with the reveal-land pop; NEW! sticker beside the name on a first catch.
function Hud.revealLand(card: Card, isNew: boolean)
    Motion.scaleTo(card.name, "revealLand")
    Motion.scaleTo(card.rarity, "revealLand", 0.05)
    if not isNew then
        return
    end
    -- own layer, so the card's list layout does not place the sticker
    local layer = Kit.frame(screen.root, "StickerLayer")
    layer.AnchorPoint = card.frame.AnchorPoint
    layer.Position = card.frame.Position
    layer.Size = card.frame.Size
    layer.ZIndex = 44
    card.frame.Destroying:Connect(function()
        layer:Destroy()
    end)
    local sticker = Kit.frame(layer, "NewSticker", C.newSticker)
    sticker.AnchorPoint = Vector2.new(0, 0.5)
    sticker.Position = UDim2.new(0.5, 230, 0.5, -40)
    sticker.Size = UDim2.fromOffset(120, 56)
    sticker.ZIndex = 44
    Kit.corner(sticker, UDim.new(0, 14))
    Kit.stroke(sticker, C.outline, 3, true)
    local t = Kit.text(sticker, "NEW!", 28, C.newText, nil, 0)
    t.Size = UDim2.fromScale(1, 1)
    t.ZIndex = 45
    local m = Motion.get("revealSticker")
    sticker.Rotation = m.From.Rotation or -30
    Motion.scaleTo(sticker, "revealSticker")
    Motion.play(sticker, "revealSticker", { Rotation = -12 })
end

-- Layout: PC vs phone composition (spec 2.1)
Kit.onLayout(screen, function(info)
    local compact = info.compact
    columnY = if compact then 0.33 else 0.40
    placeColumns(false)
    stats.Position = UDim2.new(0, 20, if compact then 0.47 else 0.62, 0)
    throwButton.Position = UDim2.new(1, -40, 1, -300)
    meter.Size = if compact then UDim2.new(0.8, 0, 0, 52) else UDim2.new(0.5, 0, 0, 52)
    meter.Position = if compact then UDim2.fromScale(0.5, 0.72) else UDim2.fromScale(0.5, 0.86)
    hint.Position = UDim2.new(1, -24, 0.97, 0)
    eatRow.Position = if compact then UDim2.new(0.5, 0, 0.72, -110) else UDim2.new(0.5, 0, 0.86, -110)
    washBar.frame.Size = if compact then UDim2.new(0.6, 0, 0, 44) else UDim2.fromOffset(640, 44)
    washBar.frame.Position = UDim2.fromScale(0.5, if compact then 0.12 else 0.10)
    washHint.Position = UDim2.new(0.5, 0, if compact then 0.12 else 0.10, 34)
    nozzleChip.Position = UDim2.new(0.5, 0, if compact then 0.12 else 0.10, 80)
    close.Position = UDim2.new(1, -24, if compact then 0.22 else 0.05, 0)
end)

-- Station HUDs hide the menu columns (C10): throwing, washing, lifting, revealing.
local stationOn = false
RunService.Heartbeat:Connect(function()
    local on = meter.Visible or Ctx.washing or Ctx.lifting or Ctx.revealing
    if on ~= stationOn then
        stationOn = on
        Hud.setHidden("station", on)
    end
end)

return Hud
