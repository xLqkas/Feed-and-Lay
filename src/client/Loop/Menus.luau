--!strict
-- Menu tiles and the two slice panels (ui-style-spec 2.2, 3.1-3.3; design-v3 7.4, VS-10): Book (claim each
-- new creature once) as a grid of rarity cards, and Upgrades (next Food, Weights, Nest slot, Nozzle) as
-- shop rows with live green / red prices. Tiles appear at their onboarding step (Book 7, Upgrades 10).
-- Upgrade signs carry a ProximityPrompt that opens Upgrades on their row. The server decides every
-- purchase and claim (Buy / ClaimBook).

local Players = game:GetService("Players")

local Ctx = require(script.Parent.Ctx)
local Hud = require(script.Parent.Hud)
local Pen = require(script.Parent.Pen)
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
local screen = Hud.screen
local fmt = Logic.formatNumber

local Menus = {}
local panels = Kit.panels(screen)

-- Tiles: Book in the left column, Upgrades in the right (spec 2.1), each with a dot and a pointer.
local book = Kit.menuTile(Hud.leftColumn, "Book", Kit.art("book"))
local upgrades = Kit.menuTile(Hud.rightColumn, "Upgrades", Kit.art("upgrade"))
local pointers = { Book = Kit.pointer(book.button), Upgrades = Kit.pointer(upgrades.button, true) }
local tiles = { Book = book, Upgrades = upgrades }
book.button.Visible = false
upgrades.button.Visible = false

Kit.onPanel(panels, function(open)
    Hud.setHidden("panel", open ~= nil)
    for name, tile in tiles do
        Kit.setTileOpen(tile, open == name)
    end
end)

-- Book: found creatures as rarity cards; CLAIM pays BookClaim once (server)
local _, bookBody = Kit.shell(screen, panels, "Book", "Book", Kit.art("book"))
local bookList = Kit.scroll(bookBody)
local bookGrid = Instance.new("UIGridLayout")
bookGrid.CellPadding = UDim2.fromOffset(18, 18)
bookGrid.SortOrder = Enum.SortOrder.LayoutOrder
bookGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
bookGrid.Parent = bookList

local function unclaimed(): number
    local n = 0
    for _, claimed in Ctx.book do
        if not claimed then
            n += 1
        end
    end
    return n
end

-- Puts a pet model in a card's viewport, framed by its bounding box
local function showModel(vp: ViewportFrame, species: string, rarity: string)
    local model = Pen.makePet(species, "Normal", rarity)
    local tag = model:FindFirstChild("Tag", true)
    if tag then
        tag:Destroy()
    end
    model:PivotTo(CFrame.Angles(0, math.rad(200), 0))
    model.Parent = vp
    local cf, size = model:GetBoundingBox()
    local camera = Instance.new("Camera")
    camera.FieldOfView = 30
    local dist = size.Magnitude * 1.9
    camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, size.Y * 0.25, -dist), cf.Position)
    camera.Parent = vp
    vp.CurrentCamera = camera
end

local bookSignature = ""
local function refreshBook(force: boolean?)
    local parts = {}
    for i, creature in Economy.Creatures do
        parts[i] = tostring(Ctx.book[creature.Name])
    end
    local signature = table.concat(parts, ",") .. tostring(screen.info.touchMin)
    if signature == bookSignature and not force then
        return -- coins tick every second; only rebuild when the book itself changed
    end
    bookSignature = signature
    for _, child in bookList:GetChildren() do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    local buttonH = math.max(56, screen.info.touchMin)
    bookGrid.CellSize = UDim2.fromOffset(150, 170 + 10 + buttonH)
    for i, creature in Economy.Creatures do
        local claimed = Ctx.book[creature.Name]
        if claimed ~= nil or creature.Zone <= 2 then
            local cell = Kit.frame(bookList, "Entry")
            cell.LayoutOrder = i
            local card = Kit.rarityCard(cell, creature.Rarity, claimed == nil)
            showModel(card.viewport, creature.Name, creature.Rarity)
            if claimed == nil then
                card.rarity.Text = Economy.Zones[creature.Zone].Name
                continue
            end
            card.title.Text = creature.Name
            card.income.Text = "+" .. fmt(creature.Income) .. "/s"
            card.check.Visible = claimed
            if claimed then
                local done = Kit.text(cell, "Claimed", T.label, C.panelText, nil, 0)
                done.Position = UDim2.fromOffset(0, 182)
                done.Size = UDim2.fromOffset(150, 34)
                continue
            end
            Kit.setDot(card.dot, "!")
            local b = Kit.button(cell, "CLAIM +" .. fmt(creature.BookClaim), "primary", UDim2.fromOffset(150, 56))
            b.Position = UDim2.fromOffset(0, 180)
            b.Activated:Connect(function()
                local r = Ctx.invoke("ClaimBook", creature.Name)
                if not r.ok then
                    Motion.shake(b)
                    Hud.toast(r.message, "error")
                    Sfx.play("bonk")
                    return
                end
                Ctx.book[creature.Name] = true
                local from = b.AbsolutePosition + b.AbsoluteSize / 2
                Kit.coinBurst(screen, Hud.coins, from, 16)
                Sfx.play("chime")
                Hud.toast("+" .. fmt(r.amount) .. " coins for " .. creature.Name .. "!", "gain")
                Menus.refresh()
            end)
        end
    end
end

-- Upgrades: one shop row per track with the next level; price green when affordable, red when not
local _, upBody = Kit.shell(screen, panels, "Upgrades", "Upgrades", Kit.art("upgrade"))
local upList = Kit.scroll(upBody)
local upLayout = Instance.new("UIListLayout")
upLayout.Padding = UDim.new(0, Theme.Space.md)
upLayout.SortOrder = Enum.SortOrder.LayoutOrder
upLayout.Parent = upList

type Track = {
    id: string,
    sign: string,
    icon: () -> string,
    level: () -> number,
    next: () -> (string?, string?),
}
local TRACKS: { Track } = {
    {
        id = "Nest",
        sign = "Nest",
        icon = function()
            return "egg"
        end,
        level = function()
            return player:GetAttribute("NestSlots") or Economy.START_NEST
        end,
        next = function()
            local slots = (player:GetAttribute("NestSlots") or Economy.START_NEST) + 1
            if slots > Economy.MAX_NEST then
                return nil, nil
            end
            return "Nest slot " .. slots, "Hold " .. slots .. " eggs at once"
        end,
    },
    {
        id = "Food",
        sign = "Food",
        icon = function()
            local icons = { "food1Apple", "food2Carrot", "food3Blueberry", "food4Pancake", "food5Strawberry" }
            return icons[Ctx.foodTier + 1] or "food6Cookie"
        end,
        level = function()
            return Ctx.foodTier
        end,
        next = function()
            local food = Economy.Foods[Ctx.foodTier + 1]
            if not food then
                return nil, nil
            end
            return food.Name, "Luck x" .. food.Luck .. ": rarer eggs (now " .. Economy.Foods[Ctx.foodTier].Name .. ")"
        end,
    },
    {
        id = "Nozzle",
        sign = "Nozzle",
        icon = function()
            return "lightning" -- shortcut: no nozzle icon (missing art)
        end,
        level = function()
            return Ctx.nozzleLevel
        end,
        next = function()
            local n = Economy.Nozzles[Ctx.nozzleLevel + 1]
            if not n then
                return nil, nil
            end
            return n.Name, "Washer power " .. n.DPS .. " (now " .. Economy.Nozzles[Ctx.nozzleLevel].DPS .. ")"
        end,
    },
    {
        id = "Dumbbell",
        sign = "Weights",
        icon = function()
            return "lightningBlue" -- shortcut: no dumbbell icon (missing art)
        end,
        level = function()
            return Ctx.dumbbellTier
        end,
        next = function()
            local bell = Economy.Dumbbells[Ctx.dumbbellTier + 1]
            if not bell then
                return nil, nil
            end
            return bell.Name, "+" .. fmt(bell.PerRep) .. " Strength per rep"
        end,
    },
}
type Price = { button: TextButton, cost: number, bar: Kit.Bar, ok: boolean? }
local prices: { [string]: Price } = {}
local rowFrames: { [string]: GuiObject } = {}

-- Row strip (spec 3.3): cardCream art, icon tile, name and effect in ink
local function row(order: number, iconName: string): (GuiObject, TextLabel, TextLabel)
    local f: GuiObject
    if Theme.UseArt then
        local art = Kit.image(upList, "cardCream", 116)
        art.SliceScale = 0.3
        f = art
    else
        local frame = Kit.frame(upList, "Row", C.rowBody)
        Kit.corner(frame, UDim.new(0, Theme.Radius.card))
        f = frame
    end
    f.Name = "Row"
    f.LayoutOrder = order
    f.Size = UDim2.new(1, 0, 0, 116)
    local tile = if Theme.UseArt then Kit.image(f, "iconTile", 88) else Kit.frame(f, "iconTile", C.panelRim)
    tile.AnchorPoint = Vector2.new(0, 0.5)
    tile.Position = UDim2.new(0, 14, 0.5, 0)
    tile.Size = UDim2.fromOffset(88, 88)
    local icon = Kit.image(tile, iconName)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.fromScale(0.5, 0.48)
    icon.Size = UDim2.fromOffset(66, 66)
    local title = Kit.text(f, "", T.heading, C.panelText, nil, 0)
    title.Position = UDim2.fromOffset(118, 18)
    title.Size = UDim2.new(1, -370, 0, 36)
    title.TextXAlignment = Enum.TextXAlignment.Left
    local detail = Kit.text(f, "", T.body, C.panelText, Theme.Fonts.body, 0)
    detail.TextTransparency = 0.3
    detail.Position = UDim2.fromOffset(118, 60)
    detail.Size = UDim2.new(1, -370, 0, 28)
    detail.TextXAlignment = Enum.TextXAlignment.Left
    return f, title, detail
end

local function priceButton(f: GuiObject, cost: number): (TextButton, Kit.Bar)
    local b, face = Kit.button(f, fmt(cost), "priceOk", UDim2.fromOffset(220, 76))
    b.AnchorPoint = Vector2.new(1, 0.5)
    b.Position = UDim2.new(1, -16, 0.5, -6)
    local coin = Kit.image(face, "coin")
    coin.AnchorPoint = Vector2.new(0, 0.5)
    coin.Position = UDim2.new(0, -4, 0.5, 0)
    coin.Size = UDim2.fromOffset(36, 36)
    coin.ZIndex = 3
    local pad = face:FindFirstChildOfClass("UIPadding") :: UIPadding
    pad.PaddingLeft = UDim.new(0, 48)
    local bar = Kit.progressBar(f, UDim2.fromOffset(220, 14), nil)
    bar.frame.AnchorPoint = Vector2.new(1, 1)
    bar.frame.Position = UDim2.new(1, -16, 1, -6)
    bar.label.Visible = false
    return b, bar
end

local function paintPrices()
    local coins = player:GetAttribute("Coins") or 0
    local affordable = 0
    for id, p in prices do
        local ok = coins >= p.cost
        if ok ~= p.ok then
            Kit.setRole(p.button, if ok then "priceOk" else "priceNo")
            if ok and p.ok == false then
                Motion.scaleTo(p.button, "priceAffordable") -- turned affordable: pop once
            end
            p.ok = ok
        end
        p.bar.frame.Visible = not ok
        if not ok then
            Kit.setProgress(p.bar, coins / p.cost)
        end
        if ok and id == "Nest" then
            affordable += 1
        end
    end
    -- the red dot marks the Nest slot while the objective asks for it (step 10)
    Kit.setDot(upgrades.dot, if (player:GetAttribute("TutorialStep") or 0) == 10 then affordable else nil)
end

local function refreshUpgrades(highlight: string?)
    for _, child in upList:GetChildren() do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    table.clear(prices)
    for i, track in TRACKS do
        local name, effect = track.next()
        local f, title, detail = row(i, track.icon())
        rowFrames[track.id] = f
        if track.sign == highlight then
            Kit.stroke(f, C.reward, 5, true)
        end
        if not name then
            title.Text = track.id
            detail.Text = "Maxed!"
            local check = Kit.image(f, "check")
            check.AnchorPoint = Vector2.new(1, 0.5)
            check.Position = UDim2.new(1, -130, 0.5, 0)
            check.Size = UDim2.fromOffset(52, 52)
            local owned = Kit.text(f, "Owned", T.label, C.money, nil, 2)
            owned.AnchorPoint = Vector2.new(1, 0.5)
            owned.Position = UDim2.new(1, -20, 0.5, 0)
            owned.Size = UDim2.fromOffset(100, 32)
            continue
        end
        title.Text = name :: string
        detail.Text = effect :: string
        local cost = Economy.upgradeCost(track.id, track.level()) :: number
        local b, bar = priceButton(f, cost)
        prices[track.id] = { button = b, cost = cost, bar = bar, ok = nil }
        b.Activated:Connect(function()
            local r = Ctx.invoke("Buy", track.id)
            if not r.ok then
                Motion.shake(b)
                Sfx.play("bonk")
                Hud.toast(
                    if r.need then "Not enough coins! Need " .. fmt(math.ceil(r.need)) .. " more" else r.message,
                    "error"
                )
                return
            end
            if track.id == "Food" then
                Ctx.foodTier = r.level
                Hud.refreshFood()
            elseif track.id == "Nozzle" then
                Ctx.nozzleLevel = r.level
            elseif track.id == "Dumbbell" then
                Ctx.dumbbellTier = r.level
            end
            Sfx.play("chime")
            Hud.toast("Bought " .. name .. "!", "gain")
            task.wait() -- let NestSlots replicate before the row rebuilds
            refreshUpgrades(highlight)
            local again = rowFrames[track.id]
            if again then
                Motion.pop(again, 1.05)
            end
        end)
    end
    paintPrices()
end

local function openUpgrades(highlight: string?)
    refreshUpgrades(highlight)
    Kit.showPanel(panels, "Upgrades")
end

-- Re-reads step-dependent visibility, dots, pointers and the open panel
local function showTile(tile: Kit.Tile, show: boolean)
    if show and not tile.button.Visible then
        tile.button.Visible = true
        Kit.revealTile(tile)
    elseif not show then
        tile.button.Visible = false
    end
end

function Menus.refresh()
    local step = player:GetAttribute("TutorialStep") or 0
    showTile(book, step >= 7)
    showTile(upgrades, step >= 10)
    local n = unclaimed()
    Kit.setDot(book.dot, if n > 0 then n else nil)
    pointers.Book.Visible = step == 7 or step == 14
    pointers.Upgrades.Visible = step == 10 and (player:GetAttribute("Coins") or 0) >= Economy.NestSlotCost[3]
    if panels.frames.Book.Visible then
        refreshBook()
    end
    paintPrices()
end

function Menus.init(state: any)
    for _, entry in state.book or {} do
        Ctx.book[entry.species] = entry.claimed
    end
    book.button.Activated:Connect(function()
        Sfx.play("tick")
        pointers.Book.Visible = false
        refreshBook()
        Kit.showPanel(panels, "Book")
    end)
    upgrades.button.Activated:Connect(function()
        Sfx.play("tick")
        pointers.Upgrades.Visible = false
        openUpgrades(nil)
    end)
    Kit.onLayout(screen, function()
        if panels.frames.Book.Visible then
            refreshBook(true)
        end
    end)
    -- a new species becomes claimable once its reveal is over
    Ctx.on("hatched", function(r: any)
        if r.firstOfSpecies and Ctx.book[r.species] == nil then
            Ctx.at(r.revealAt + r.revealSeconds, function()
                Ctx.book[r.species] = false
                Motion.pop(book.button, 1.25)
                Menus.refresh()
            end)
        end
    end)
    player:GetAttributeChangedSignal("TutorialStep"):Connect(Menus.refresh)
    player:GetAttributeChangedSignal("Coins"):Connect(Menus.refresh)
    player:GetAttributeChangedSignal("NestSlots"):Connect(function()
        if panels.frames.Upgrades.Visible then
            refreshUpgrades(nil)
        end
    end)

    -- Upgrade signs: a ProximityPrompt on each (E, tap or gamepad X) opens Upgrades on that row once the
    -- Upgrades button exists. Signs stand 2 studs from their station, so only the sign the onboarding trail
    -- leads to (steps 10 and 15) opens by itself; anything else would pop over the washer or the bench.
    local AUTO = { [10] = "Sign_Nest", [15] = "Sign_Food" }
    local prompts: { ProximityPrompt } = {}
    for _, sign in (Ctx.plot :: Model):GetChildren() do
        local tab = sign:GetAttribute("Tab")
        local board = sign:FindFirstChild("Board")
        if sign:IsA("Model") and typeof(tab) == "string" and board then
            local prompt = Instance.new("ProximityPrompt")
            prompt.ActionText = "Upgrades"
            prompt.ObjectText = tab
            prompt.MaxActivationDistance = 7
            prompt.RequiresLineOfSight = false
            prompt.Enabled = false
            prompt.Parent = board
            prompt.Triggered:Connect(function()
                Sfx.play("tick")
                openUpgrades(tab)
            end)
            table.insert(prompts, prompt)
        end
    end
    local opened: { [string]: boolean } = {}
    task.spawn(function()
        while true do
            task.wait(0.25)
            local step = player:GetAttribute("TutorialStep") or 0
            for _, prompt in prompts do
                prompt.Enabled = step >= 10
            end
            local auto = AUTO[step]
            if auto and not opened[auto] and Ctx.distanceTo(auto) <= 5 then
                opened[auto] = true
                Sfx.play("tick")
                openUpgrades(((Ctx.plot :: Model):FindFirstChild(auto) :: Instance):GetAttribute("Tab"))
            end
        end
    end)
    Menus.refresh()
end

return Menus
