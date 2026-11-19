--!strict
-- UI tokens named by role. Values follow docs/ai/ui-style-spec.md (the "Blend": LightDock base plus picks
-- from the other presets, sections 1.1, 6 and 7). Sizes are reference pixels at 1080p; Kit scales the screen.
--
-- Preset switch (compare looks): set the string attribute FLUiPreset on ReplicatedStorage in Studio before
-- pressing Play: "Blend" (default), "LightDock", "DarkTiles", "SlimPills" or "GlassPanels". A preset other
-- than Blend overlays its colours, button colours, rarity colours, panel radius / stroke and motion, and
-- draws panels and buttons in code instead of the SunGraphica art. Motion.luau reads the same setting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local hex = Color3.fromHex

local Theme = {}

local chosen = ReplicatedStorage:GetAttribute("FLUiPreset")
Theme.Preset = if typeof(chosen) == "string" and chosen ~= "" then chosen else "Blend"
Theme.UseArt = true -- SunGraphica panels, ribbons, buttons, bars (Gvesster icons are always shown)

Theme.Colors = {
    money = hex("2BD45B"), -- positive / affordable text, gain toasts
    moneyStroke = hex("1C8F3C"),
    primary = hex("2B8000"), -- main action button face (white text 5:1)
    primaryBase = hex("1C5700"),
    reward = hex("FFC800"), -- coins, gold; dark text only
    rewardBase = hex("C99700"),
    info = hex("1CB0F6"),
    infoBase = hex("1182B8"),
    danger = hex("FF4B4B"), -- errors, unaffordable, close, notification dot
    dangerBase = hex("C22E2E"),
    premium = hex("CE82FF"), -- Robux
    premiumBase = hex("9150BD"),
    neutral = hex("4A4160"),
    neutralBase = hex("2E2840"),
    disabled = hex("9A9A9A"),
    disabledBase = hex("6B6B6B"),
    panel = hex("2A2438"), -- dark HUD surfaces (timer strip, card chips), not panel bodies
    panelBody = hex("F2DCB8"), -- cream panel body when drawn in code (art fallback / other presets)
    rowBody = hex("FFF4E0"), -- row strip on the panel body when drawn in code
    panelRim = hex("C9A27A"), -- divider lines and scroll bar on cream
    panelText = hex("4A3424"), -- text on the panel body (ink on cream; white on dark presets)
    outline = hex("2A2B31"), -- panel rim and HUD text stroke (LightDock)
    track = hex("1A1624"), -- progress bar track when drawn in code
    shade = hex("0B0910"), -- menu backdrop
    paper = hex("FFFFFF"),
    muted = hex("B9B3C9"),
    ink = hex("4A3424"), -- body text on cream and on yellow fills
    announce = hex("FFC800"),
    newSticker = hex("FFF1D6"),
    newText = hex("FF8A00"),
    topbarButton = hex("1B1B22"),
}

-- Rarity word is always shown as text too, never colour alone. Secret also gets a rainbow gradient.
Theme.Rarity = {
    Common = hex("B8C0CC"),
    Uncommon = hex("5BD45B"),
    Rare = hex("3BA7FF"),
    Epic = hex("B65CFF"),
    Legendary = hex("FFC800"),
    Mythic = hex("FF4B6E"),
    Secret = hex("FFFFFF"),
}
Theme.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

export type ButtonRole =
    "primary"
    | "reward"
    | "info"
    | "danger"
    | "premium"
    | "neutral"
    | "disabled"
    | "priceOk"
    | "priceNo"
export type ButtonColors = { face: Color3, base: Color3, text: Color3 }

local C = Theme.Colors
local function buttons()
    return {
        primary = { face = C.primary, base = C.primaryBase, text = C.paper },
        reward = { face = C.reward, base = C.rewardBase, text = C.ink },
        info = { face = C.info, base = C.infoBase, text = C.paper },
        danger = { face = C.danger, base = C.dangerBase, text = C.paper },
        premium = { face = C.premium, base = C.premiumBase, text = C.paper },
        neutral = { face = C.neutral, base = C.neutralBase, text = C.paper },
        disabled = { face = C.disabled, base = C.disabledBase, text = hex("E6E6E6") },
        priceOk = { face = C.money, base = C.moneyStroke, text = C.paper },
        priceNo = { face = C.danger, base = C.dangerBase, text = C.paper },
    } :: { [ButtonRole]: ButtonColors }
end
Theme.Buttons = buttons()

-- Uploaded art per button role (ImageIds.Buttons); roles without art are drawn in code (spec 4.1).
Theme.ButtonArt = {
    primary = "buttonWideGreen",
    reward = "buttonWideYellow",
    info = "buttonWideBlue",
    danger = "buttonWideRed",
    priceOk = "buttonPriceGreen",
    priceNo = "buttonPriceRed",
} :: { [string]: string }

-- Title ribbon per panel (ImageIds.Headers); spec 3.1. Upgrades would be green (missing art).
Theme.Ribbons = {
    Book = "headerCyan",
    Upgrades = "headerMagenta",
    Shop = "headerPurple",
    Pets = "headerOrange",
    Daily = "headerYellow",
    Settings = "headerBrown",
    Confirm = "headerRed",
    Info = "headerBlue",
} :: { [string]: string }

Theme.Fonts = {
    title = Font.fromEnum(Enum.Font.FredokaOne), -- HUD, titles, numbers, buttons
    body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold), -- long text in panels
}

-- spec section 6 (1080 px reference)
Theme.TextSize = {
    hero = 80,
    display = 56,
    title = 44,
    banner = 40,
    number = 38,
    button = 32,
    heading = 28,
    label = 24,
    body = 20,
    small = 16,
}
Theme.Space = { xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32, xxxl = 48 }
Theme.Radius = { button = 16, panel = 26, card = 14 }
Theme.Stroke = { text = 3, banner = 4, panel = 4, card = 3 }
Theme.ButtonDepth = 6 -- base strip under code-drawn button faces

-- Gvesster icons and SunGraphica art by name (ImageIds.luau); Theme.Images kept for older callers.
local ImageIds = require(script.Parent.ImageIds)
Theme.Images = {
    coin = ImageIds.Currency.coin,
    close = ImageIds.Ui.close,
}

-- Overlay another captured preset (docs/ai/ui-presets) for comparison.
if Theme.Preset ~= "Blend" then
    local module = script.Parent.Presets:FindFirstChild(Theme.Preset)
    if module and module:IsA("ModuleScript") then
        local p = (require :: any)(module)
        Theme.UseArt = false
        local pc = p.Colors
        C.outline = pc.outline or C.outline
        C.panelBody = pc.panel or C.panelBody
        C.rowBody = pc.panelAlt or pc.row or pc.card or pc.panelPattern or C.rowBody
        local light = C.panelBody.R + C.panelBody.G + C.panelBody.B > 2
        C.panelText = if light then pc.ink or C.ink else C.paper
        C.panelRim = pc.divider or pc.panelOutline or C.panelRim
        C.danger = pc.danger or C.danger
        C.money = pc.money or pc.gain or C.money
        C.primary = pc.primary or C.primary
        for name, color in p.Rarity do
            if (Theme.Rarity :: any)[name] then
                (Theme.Rarity :: any)[name] = color
            end
        end
        Theme.Buttons = buttons()
        for role, b in p.Buttons do
            if (Theme.Buttons :: any)[role] then
                (Theme.Buttons :: any)[role] = { face = b.face, base = b.base, text = b.text }
            end
        end
        Theme.Radius.panel = p.Radius.panel or Theme.Radius.panel
        Theme.Radius.button = p.Radius.button or Theme.Radius.button
        Theme.Stroke.panel = p.Stroke.panel or Theme.Stroke.panel
        Theme.ButtonDepth = p.ButtonDepth
    else
        warn("[UI] unknown FLUiPreset " .. Theme.Preset .. ", using Blend")
        Theme.Preset = "Blend"
    end
end

return Theme
