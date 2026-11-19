--!strict
-- Kit showcase for screenshots (VS-4 accept: phone 375 x 667 and PC 1920 x 1080, nothing overflows).
-- Not auto-run. In Play mode, from a LocalScript or the client command bar:
--   require(game.Players.LocalPlayer.PlayerScripts.UI.Demo).mount(false)  -- HUD, toasts, components
--   require(game.Players.LocalPlayer.PlayerScripts.UI.Demo).mount(true)   -- same with the panel open
-- Destroy the returned screen.gui to remove it.

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local C = Theme.Colors
local Demo = {}

local function row(parent: Instance, name: string, y: number): Frame
    local frame = Kit.frame(parent, name)
    frame.AnchorPoint = Vector2.new(0.5, 0)
    frame.Position = UDim2.fromScale(0.5, y)
    frame.Size = UDim2.fromScale(0.92, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Horizontal
    list.Wraps = true
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.VerticalAlignment = Enum.VerticalAlignment.Center
    list.Padding = UDim.new(0, Theme.Space.lg)
    list.Parent = frame
    return frame
end

function Demo.mount(openPanel: boolean?): Kit.Screen
    local screen = Kit.screen("FLKitDemo", 20)
    local panels = Kit.panels(screen)
    Kit.banner(screen, "Throw food from the ledge!")

    -- Coins counter: PC bottom-left, phone top-left (design-v3 7.2).
    local coins = Kit.currencyPill(screen.root, Theme.Images.coin, C.reward)
    Kit.setPillValue(coins, 0, false)
    Kit.setPillRate(coins, 125)
    Kit.onLayout(screen, function(info)
        coins.frame.AnchorPoint = if info.compact then Vector2.new(0, 0) else Vector2.new(0, 1)
        coins.frame.Position = if info.compact then UDim2.new(0.02, 20, 0.10, 0) else UDim2.new(0.02, 20, 0.95, -24)
    end)
    Kit.setPillValue(coins, 1234567)

    -- Buttons, one per role, plus an icon button.
    local buttons = row(screen.root, "Buttons", 0.36)
    local open = Kit.button(buttons, "Upgrades", "primary", UDim2.fromOffset(180, 64))
    local claim = Kit.button(buttons, "Claim", "reward", UDim2.fromOffset(160, 64))
    Kit.button(buttons, "Info", "info", UDim2.fromOffset(140, 64))
    Kit.button(buttons, "Shop", "premium", UDim2.fromOffset(140, 64))
    Kit.button(buttons, "Sell", "danger", UDim2.fromOffset(140, 64))
    Kit.iconButton(buttons, Theme.Images.coin, "$", "neutral", 64)

    -- Progress bar and rarity words.
    local bars = row(screen.root, "Bars", 0.58)
    local bar = Kit.progressBar(bars, UDim2.new(0.9, 0, 0, 32), C.money)
    Kit.setProgress(bar, 320 / 800, "320 / 800")
    local rarities = row(screen.root, "Rarities", 0.66)
    for _, rarity in Theme.RarityOrder do
        Kit.rarityLabel(rarities, rarity)
    end

    -- Panel shell (Upgrades, green title) with a price button and a progress bar inside.
    local _, body = Kit.shell(screen, panels, "Upgrades", "Upgrades", C.primary)
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, Theme.Space.lg)
    list.Parent = body
    Kit.text(body, "Carrot: Luck x4", Theme.TextSize.heading)
    local price = Kit.progressBar(body, UDim2.new(1, 0, 0, 24), C.reward)
    Kit.setProgress(price, 0.75, "900 / 1.2K")
    local buy = Kit.button(body, "Buy 1.2K", "danger", UDim2.fromOffset(220, 64))

    open.Activated:Connect(function()
        Kit.showPanel(panels, "Upgrades")
    end)
    buy.Activated:Connect(function()
        Kit.toastReply(screen, { ok = false, message = "Need 300 more coins" })
    end)
    claim.Activated:Connect(function()
        Kit.coinBurst(screen, coins, claim.AbsolutePosition + claim.AbsoluteSize / 2)
        Kit.setPillValue(coins, coins.number.Value + 500)
        Kit.toastReply(screen, { ok = true, message = "+500 coins" })
    end)

    -- Toasts in all three kinds, shaped like server replies.
    Kit.toastReply(screen, { ok = true, message = "+120 coins" })
    Kit.toastReply(screen, { ok = false, message = "Nest full" })
    Kit.toast(screen, "Mia hatched a MYTHIC Pearl Whale!", "announce")

    -- Income floaters over the coins counter while the demo is mounted; one coin burst after mount.
    task.spawn(function()
        while screen.gui.Parent do
            Kit.floatingNumber(coins.frame, "+125", C.money, UDim2.new(0.5, 0, 0, -20))
            task.wait(1)
        end
    end)
    task.delay(0.5, function()
        Kit.coinBurst(screen, coins, claim.AbsolutePosition + claim.AbsoluteSize / 2)
    end)

    if openPanel then
        Kit.showPanel(panels, "Upgrades")
    end
    return screen
end

return Demo
