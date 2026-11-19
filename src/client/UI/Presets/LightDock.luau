--!strict
-- UI style preset "LightDock": white patterned panels with a thick dark outline, the title sitting on the
-- panel edge, close button overhanging the corner, one bottom-centre menu button that opens a dock of big
-- icons, a quest card at top centre. Source: docs/ai/ui-presets/pet-sim-99.md. Data only.

local Types = require(script.Parent.Types)

local hex = Color3.fromHex
local S = Enum.EasingStyle
local D = Enum.EasingDirection

local preset: Types.Preset = {
    Colors = {
        panel = hex("FFFFFF"), -- panel and quest card body (sampled)
        panelPattern = hex("EEF1F5"), -- faint pictogram pattern on the body (estimate)
        outline = hex("2A2B31"), -- panel, card, button outline and text stroke (sampled)
        ink = hex("2A2B31"), -- body text on white (sampled)
        paper = hex("FFFFFF"),
        sectionTitle = hex("1297FC"), -- blue section heading inside panels (sampled)
        questTitle = hex("70EDFC"), -- cyan stroked quest title (sampled)
        count = hex("1FB6F5"), -- "1/4" counts beside headings (estimate)
        progressFill = hex("38C8F0"), -- (estimate)
        progressTrack = hex("7F7F7F"), -- (sampled)
        primary = hex("68F10A"), -- green buttons (sampled)
        primaryOutline = hex("2B5207"), -- (sampled)
        accent = hex("FF0E48"), -- pink-red secondary buttons (sampled)
        danger = hex("FF114E"), -- close button (sampled)
        dangerOutline = hex("A1113E"), -- (sampled)
        dot = hex("FF1B62"), -- count badge and "!" badge (sampled)
        diamond = hex("6FE8FF"), -- premium currency number (estimate)
        coinText = hex("FFFFFF"),
        tierPip = hex("FFC21A"), -- small gold tier pips on items (estimate)
        dockGlow = hex("FFE45C"), -- glow behind the open dock icon (estimate)
        cardTint = hex("E8FFFF"), -- bottom of achievement card gradient (sampled)
        emptySlot = hex("8A8A8A"), -- dashed outline of empty pet slots (estimate)
        gain = hex("2BD45B"), -- "You have earned ..." toast (estimate)
    },
    Rarity = { -- estimates; tiers show as tile colour and pips rather than a whole card fill
        Basic = hex("B8C0CC"),
        Rare = hex("3BA7FF"),
        Epic = hex("B65CFF"),
        Legendary = hex("FFB21A"),
        Mythical = hex("FF4B6E"),
        Exclusive = hex("FFFFFF"), -- rainbow gradient
    },
    RarityOrder = { "Basic", "Rare", "Epic", "Legendary", "Mythical", "Exclusive" },
    Buttons = {
        primary = { face = hex("8CF816"), base = hex("68F10A"), text = hex("FFFFFF"), stroke = hex("2A2B31") },
        accent = { face = hex("FF1F6B"), base = hex("FF0E48"), text = hex("FFFFFF"), stroke = hex("2A2B31") },
        close = { face = hex("FF1F6A"), base = hex("FF114E"), text = hex("FFFFFF"), stroke = hex("A1113E") },
        neutral = { face = hex("F4F5F7"), base = hex("C9CDD3"), text = hex("2A2B31"), stroke = hex("2A2B31") },
    },
    Gradients = {
        buttonPrimary = { stops = { hex("8CF816"), hex("68F10A") }, rotation = 90 }, -- sampled
        buttonAccent = { stops = { hex("FF1F6B"), hex("FF0E48") }, rotation = 90 }, -- sampled
        achievementCard = { stops = { hex("FFFFFF"), hex("E8FFFF") }, rotation = 90 }, -- sampled
        offerCardWarm = { stops = { hex("FFE7A8"), hex("FF9A3C") }, rotation = 90 }, -- estimate
    },
    Fonts = {
        title = Font.fromEnum(Enum.Font.FredokaOne),
        body = Font.fromEnum(Enum.Font.FredokaOne),
    },
    TextSize = {
        bigButton = 65, -- "Ok!" (0.060)
        title = 59, -- panel title on the edge (0.055)
        heading = 43, -- settings labels, "Pick your pet!" is larger (0.040)
        stat = 38, -- currency numbers (0.035)
        card = 32, -- achievement card titles (0.030)
        quest = 27, -- quest card title and goal (0.025)
        body = 22,
        small = 16, -- "88/180" under bars
    },
    Space = { xs = 4, sm = 8, md = 14, lg = 20, xl = 28, xxl = 40 },
    Radius = { panel = 26, card = 14, button = 14, close = 14, pill = 999 },
    Stroke = { panel = 7, card = 6, text = 4, button = 4 },
    ButtonDepth = 6, -- darker bottom bevel under green buttons
    Layout = {
        menuButton = 0.13, -- H, single bottom-centre button
        dockIcon = 0.12, -- H, no backing tile
        dockGap = 0.01,
        dockY = 0.87, -- H, centre of dock row
        questCardWidth = 0.373, -- H
        questCardHeight = 0.16, -- H
        questCardY = 0.03,
        currencyIcon = 0.06,
        currencyTop = 0.6,
        panelWidthW = 0.9,
        panelHeight = 0.62,
        closeSize = 0.093, -- overhangs the top-right corner by ~1/3
        titleIcon = 0.1, -- overhangs the top-left corner
        badge = 0.04,
        blurSize = 18, -- estimate
    },
    Motion = {
        panelOpen = { -- appears almost at once, sliding up a little; content pops in a frame later
            Time = 0.08,
            EasingStyle = S.Quad,
            EasingDirection = D.Out,
            Delay = 0,
            From = { OffsetY = 0.02 },
            To = { OffsetY = 0 },
            Estimate = true,
        },
        panelClose = {
            Time = 0,
            EasingStyle = S.Linear,
            EasingDirection = D.In,
            Delay = 0,
            From = { Transparency = 0 },
            To = { Transparency = 1 },
            Estimate = false,
        },
        dockFanOut = { -- icons start bunched at the menu button and spread to their slots
            Time = 0.16,
            EasingStyle = S.Back,
            EasingDirection = D.Out,
            Delay = 0,
            From = { Scale = 0.85, OffsetX = 0 },
            To = { Scale = 1 }, -- OffsetX to each icon's slot
            Stagger = 0, -- all icons moved together in the captured frames
            Estimate = true,
        },
        questCardHide = { -- hidden while any panel is open, back instantly on close
            Time = 0,
            EasingStyle = S.Linear,
            EasingDirection = D.In,
            Delay = 0,
            From = { Transparency = 0 },
            To = { Transparency = 1 },
            Estimate = false,
        },
        gainBillboardBump = { -- the "+coins" number over the player drops and floats back on each gain
            Time = 0.3,
            EasingStyle = S.Quad,
            EasingDirection = D.Out,
            Delay = 0,
            From = { OffsetY = 0.02 },
            To = { OffsetY = 0 },
            Estimate = false,
        },
        pickupArc = { -- white arcs sweep round the player on pickup
            Time = 0.4,
            EasingStyle = S.Quad,
            EasingDirection = D.Out,
            Delay = 0,
            From = { Transparency = 0, Scale = 0.8 },
            To = { Transparency = 1, Scale = 1.2 },
            Estimate = true,
        },
        shortcutWobble = { -- promo/shop shortcut icon rocks side to side, forever
            Time = 0.5,
            EasingStyle = S.Sine,
            EasingDirection = D.InOut,
            Delay = 0,
            From = { Rotation = -8 },
            To = { Rotation = 8 },
            Loop = true,
            Estimate = true,
        },
        gainToast = {
            Time = 0.2,
            EasingStyle = S.Back,
            EasingDirection = D.Out,
            Delay = 0,
            From = { Scale = 0.8, Transparency = 1 },
            To = { Scale = 1, Transparency = 0 },
            Estimate = true,
        },
        counterRoll = { -- left currency counter lags the billboard and rolls up
            Time = 0.4,
            EasingStyle = S.Quad,
            EasingDirection = D.Out,
            Delay = 0.1,
            From = {},
            To = {},
            Estimate = true,
        },
    },
}

return preset
