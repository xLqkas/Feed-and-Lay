--!strict
-- UI tokens named by role (design-v3 section 7.1, styles/09-playful-bold friendly variant).
-- Sizes are reference pixels at 1080p; Kit scales the whole screen with one UIScale.

local hex = Color3.fromHex

local Theme = {}

Theme.Colors = {
    money = hex("2BD45B"), -- positive / affordable text
    moneyStroke = hex("1C8F3C"),
    primary = hex("2B8000"), -- main action button face (white text 5:1)
    primaryBase = hex("1C5700"),
    reward = hex("FFC800"), -- coins, gold; dark text only
    rewardBase = hex("C99700"),
    info = hex("1CB0F6"),
    infoBase = hex("1182B8"),
    danger = hex("FF4B4B"), -- errors, unaffordable, close
    dangerBase = hex("C22E2E"),
    premium = hex("CE82FF"), -- Robux
    premiumBase = hex("9150BD"),
    neutral = hex("4A4160"),
    neutralBase = hex("2E2840"),
    panel = hex("2A2438"),
    outline = hex("14111C"), -- panel outline and text stroke
    track = hex("1A1624"), -- progress bar track
    shade = hex("0B0910"), -- menu backdrop
    paper = hex("FFFFFF"),
    muted = hex("B9B3C9"),
    ink = hex("3C3C3C"), -- text on yellow / bright fills
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

export type ButtonRole = "primary" | "reward" | "info" | "danger" | "premium" | "neutral"
export type ButtonColors = { face: Color3, base: Color3, text: Color3 }

local C = Theme.Colors
Theme.Buttons = {
    primary = { face = C.primary, base = C.primaryBase, text = C.paper },
    reward = { face = C.reward, base = C.rewardBase, text = C.ink },
    info = { face = C.info, base = C.infoBase, text = C.paper },
    danger = { face = C.danger, base = C.dangerBase, text = C.paper },
    premium = { face = C.premium, base = C.premiumBase, text = C.paper },
    neutral = { face = C.neutral, base = C.neutralBase, text = C.paper },
} :: { [ButtonRole]: ButtonColors }

Theme.Fonts = {
    title = Font.fromEnum(Enum.Font.FredokaOne), -- titles, numbers, banner, buttons
    body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
}

Theme.TextSize = { display = 56, title = 40, heading = 28, body = 20, small = 16 }
Theme.Space = { xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32, xxxl = 48 }
Theme.Radius = { button = 16, panel = 24 }
Theme.Stroke = { text = 3, panel = 4 }
Theme.ButtonDepth = 6 -- 3D base strip under every button face
Theme.Motion = { press = 0.06, release = 0.12, hover = 0.2, pop = 0.25, fade = 0.2 }

-- shortcut: placeholder image ids; "" makes the kit draw a coloured fallback. Upload from assets
-- (Gvesster pack, used unmodified) and paste rbxassetid:// ids here:
--   coin  = Currency\Coin\256px\Golden Coin 1st 256px.png
--   close = UI\Close Button\256px\Close Button 1st 256px.png
Theme.Images = {
    coin = "",
    close = "",
}

return Theme
