--!strict
-- Left menu column and the two slice panels (design-v3 7.2 and 7.4, VS-10): Book (claim each new creature
-- once) and a minimal Upgrades panel (next Food, Weights, Nest slot, Nozzle). Buttons appear at their
-- onboarding step (Book 7, Upgrades 10). Upgrade signs carry a ProximityPrompt that opens Upgrades on their
-- row. The server decides every purchase and claim (Buy / ClaimBook).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Ctx = require(script.Parent.Ctx)
local Hud = require(script.Parent.Hud)
local Sfx = require(script.Parent.Sfx)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Logic = require(UI:WaitForChild("Logic"))
local Theme = require(UI:WaitForChild("Theme"))

local C = Theme.Colors
local Economy = Ctx.Economy
local player = Players.LocalPlayer
local screen = Hud.screen
local fmt = Logic.formatNumber

local Menus = {}
local panels = Kit.panels(screen)

-- Left column: pill buttons with a red badge and a bouncing pointer for the button the banner points at
local column = Kit.frame(screen.root, "MenuColumn")
column.AnchorPoint = Vector2.new(0, 0.5)
column.AutomaticSize = Enum.AutomaticSize.XY
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, Theme.Space.md)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = column

type MenuButton = { button: TextButton, badge: Frame, count: TextLabel, pointer: TextLabel }
local function menuButton(label: string, role: Theme.ButtonRole, order: number): MenuButton
    local button = Kit.button(column, label, role, UDim2.fromOffset(170, 60))
    button.LayoutOrder = order
    button.Visible = false
    local badge = Kit.frame(button, "Badge", C.danger)
    badge.AnchorPoint = Vector2.new(0.5, 0.5)
    badge.Position = UDim2.new(1, -4, 0, 4)
    badge.Size = UDim2.fromOffset(30, 30)
    badge.ZIndex = 5
    badge.Visible = false
    Kit.corner(badge, UDim.new(0.5, 0))
    Kit.stroke(badge, C.outline, 3, true)
    local count = Kit.text(badge, "", Theme.TextSize.small)
    count.Size = UDim2.fromScale(1, 1)
    count.ZIndex = 6
    local pointer = Kit.text(button, "<", Theme.TextSize.title, C.reward)
    pointer.Name = "Pointer"
    pointer.AnchorPoint = Vector2.new(0, 0.5)
    pointer.Size = UDim2.fromOffset(50, 50)
    pointer.Visible = false
    return { button = button, badge = badge, count = count, pointer = pointer }
end
local book = menuButton("Book", "info", 1)
local upgrades = menuButton("Upgrades", "primary", 2)

local function setBadge(b: MenuButton, n: number)
    b.badge.Visible = n > 0
    b.count.Text = tostring(n)
end

-- Pointer arrow bobs beside the button
RunService.RenderStepped:Connect(function()
    local x = 14 + math.abs(math.sin(os.clock() * 5)) * 16
    for _, b in { book, upgrades } do
        b.pointer.Position = UDim2.new(1, x, 0.5, 0)
    end
end)

Kit.onLayout(screen, function(info)
    column.Position = if info.compact then UDim2.new(0.02, 20, 0.3, 0) else UDim2.new(0.02, 20, 0.45, 0)
    for _, b in { book, upgrades } do
        b.button.Size = UDim2.fromOffset(if info.compact then 140 else 170, 60)
    end
end)

-- Panel rows: a row frame with a title, a detail line and an action button on the right
local function row(parent: Instance, order: number): (Frame, TextLabel, TextLabel)
    local f = Kit.frame(parent, "Row", C.neutralBase)
    f.LayoutOrder = order
    f.Size = UDim2.new(1, 0, 0, 92)
    Kit.corner(f, UDim.new(0, Theme.Radius.button))
    local title = Kit.text(f, "", Theme.TextSize.heading)
    title.AnchorPoint = Vector2.new(0, 0)
    title.Position = UDim2.fromOffset(Theme.Space.lg, Theme.Space.sm)
    title.Size = UDim2.new(1, -260, 0, 40)
    title.TextXAlignment = Enum.TextXAlignment.Left
    local detail = Kit.text(f, "", Theme.TextSize.body, C.muted, Theme.Fonts.body)
    detail.Position = UDim2.fromOffset(Theme.Space.lg, 50)
    detail.Size = UDim2.new(1, -260, 0, 30)
    detail.TextXAlignment = Enum.TextXAlignment.Left
    return f, title, detail
end

local function rowButton(f: Frame, label: string, role: Theme.ButtonRole): TextButton
    local b = Kit.button(f, label, role, UDim2.fromOffset(220, 64))
    b.AnchorPoint = Vector2.new(1, 0.5)
    b.Position = UDim2.new(1, -Theme.Space.md, 0.5, 0)
    return b
end

local function scrollBody(body: Frame): ScrollingFrame
    local scroll = Instance.new("ScrollingFrame")
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Size = UDim2.fromScale(1, 1)
    scroll.CanvasSize = UDim2.new()
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ScrollBarThickness = 8
    scroll.Parent = body
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, Theme.Space.md)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = scroll
    return scroll
end

-- Book: found creatures, CLAIM pays 30 x income once (server)
local _, bookBody = Kit.shell(screen, panels, "Book", "Book", C.info)
local bookList = scrollBody(bookBody)

local function unclaimed(): number
    local n = 0
    for _, claimed in Ctx.book do
        if not claimed then
            n += 1
        end
    end
    return n
end

local function refreshBook()
    for _, child in bookList:GetChildren() do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    for i, creature in Economy.Creatures do
        local claimed = Ctx.book[creature.Name]
        if claimed ~= nil or creature.Zone <= 2 then
            local f, title, detail = row(bookList, i)
            if claimed == nil then
                title.Text = "???"
                detail.Text = creature.Rarity .. ". Found in: " .. Economy.Zones[creature.Zone].Name
            else
                title.Text = creature.Name
                title.TextColor3 = Theme.Rarity[creature.Rarity] or C.paper
                detail.Text = creature.Rarity .. ", +" .. fmt(creature.Income) .. "/s"
                if claimed then
                    local done = Kit.text(f, "Claimed", Theme.TextSize.body, C.muted)
                    done.AnchorPoint = Vector2.new(1, 0.5)
                    done.Position = UDim2.new(1, -Theme.Space.lg, 0.5, 0)
                    done.Size = UDim2.fromOffset(200, 40)
                else
                    local b = rowButton(f, "CLAIM +" .. fmt(creature.BookClaim), "primary")
                    b.Activated:Connect(function()
                        local r = Ctx.invoke("ClaimBook", creature.Name)
                        if not r.ok then
                            Hud.toast(r.message, "error")
                            Sfx.play("bonk")
                            return
                        end
                        Ctx.book[creature.Name] = true
                        local from = b.AbsolutePosition + b.AbsoluteSize / 2
                        Kit.coinBurst(screen, Hud.coins, from, 12)
                        Sfx.play("chime")
                        Hud.toast("+" .. fmt(r.amount) .. " coins for " .. creature.Name .. "!", "gain")
                        Menus.refresh()
                    end)
                end
            end
        end
    end
end

-- Upgrades: one row per track with the next level; price button green when affordable, red when not
local _, upBody = Kit.shell(screen, panels, "Upgrades", "Upgrades", C.primary)
local upList = scrollBody(upBody)
type Track = { id: string, sign: string, level: () -> number, next: () -> (string?, string?) }
local TRACKS: { Track } = {
    {
        id = "Nest",
        sign = "Nest",
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
local priceButtons: { [string]: { button: TextButton, cost: number } } = {}
local rowFrames: { [string]: Frame } = {}

local function paintPrices()
    local coins = player:GetAttribute("Coins") or 0
    local affordable = 0
    for id, p in priceButtons do
        local ok = coins >= p.cost
        local face = p.button:FindFirstChild("Face") :: TextLabel
        face.BackgroundColor3 = if ok then C.primary else C.danger
        p.button.BackgroundColor3 = if ok then C.primaryBase else C.dangerBase
        if ok and id == "Nest" then
            affordable += 1
        end
    end
    -- the red dot marks the Nest slot while the banner asks for it (step 10)
    setBadge(upgrades, if (player:GetAttribute("TutorialStep") or 0) == 10 then affordable else 0)
end

local function refreshUpgrades(highlight: string?)
    for _, child in upList:GetChildren() do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    table.clear(priceButtons)
    for i, track in TRACKS do
        local f, title, detail = row(upList, i)
        rowFrames[track.id] = f
        local name, effect = track.next()
        if track.sign == highlight then
            Kit.stroke(f, C.reward, 4, true)
        end
        if not name then
            title.Text = track.id
            detail.Text = "Maxed!"
            continue
        end
        title.Text = name :: string
        detail.Text = effect :: string
        local cost = Economy.upgradeCost(track.id, track.level()) :: number
        local b = rowButton(f, fmt(cost), "primary")
        priceButtons[track.id] = { button = b, cost = cost }
        b.Activated:Connect(function()
            local r = Ctx.invoke("Buy", track.id)
            if not r.ok then
                Hud.shake(b)
                Sfx.play("bonk")
                Hud.toast(if r.need then "Need " .. fmt(math.ceil(r.need)) .. " more coins" else r.message, "error")
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
                Kit.pop(again, 0.95)
            end
        end)
    end
    paintPrices()
end

local function openUpgrades(highlight: string?)
    refreshUpgrades(highlight)
    Kit.showPanel(panels, "Upgrades")
end

-- Re-reads step-dependent visibility, badges and the open panel
function Menus.refresh()
    local step = player:GetAttribute("TutorialStep") or 0
    book.button.Visible = step >= 7
    upgrades.button.Visible = step >= 10
    setBadge(book, unclaimed())
    book.pointer.Visible = step == 7 or step == 14
    upgrades.pointer.Visible = step == 10 and (player:GetAttribute("Coins") or 0) >= Economy.NestSlotCost[3]
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
        refreshBook()
        Kit.showPanel(panels, "Book")
    end)
    upgrades.button.Activated:Connect(function()
        Sfx.play("tick")
        openUpgrades(nil)
    end)
    -- a new species becomes claimable once its reveal is over
    Ctx.on("hatched", function(r: any)
        if r.firstOfSpecies and Ctx.book[r.species] == nil then
            Ctx.at(r.revealAt + r.revealSeconds, function()
                Ctx.book[r.species] = false
                Kit.pop(book.button, 1.25)
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
