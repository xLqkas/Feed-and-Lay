--!strict
-- UI style preset "SlimPills": slim flat pills on the left, small icon tiles on the right, dark stud-textured
-- panels with patterned title bars, side drawers instead of modals, instant close.
-- Source: docs/ai/ui-presets/steal-an-egg.md. Data only.

local Types = require(script.Parent.Types)

local hex = Color3.fromHex
local S = Enum.EasingStyle
local D = Enum.EasingDirection

local preset: Types.Preset = {
    Colors = {
        panel = hex("333342"), -- panel body with a faint stud texture (sampled)
        panelOutline = hex("1A1A22"), -- (estimate)
        row = hex("35445C"), -- settings rows (sampled)
        drawer = hex("323241"), -- side drawer body (sampled)
        drawerHeader = hex("E8C9A0"), -- beige drawer title strip (estimate)
        outline = hex("000000"), -- text stroke
        paper = hex("FFFFFF"),
        sectionTitle = hex("FFD800"), -- "-- FEATURED --" section titles (estimate)
        money = hex("3BFF2E"), -- cash number, italic (estimate)
        primary = hex("49FE01"), -- buy buttons (sampled)
        premiumGift = hex("E21FE0"), -- gift square beside each Robux button (estimate)
        danger = hex("D81111"), -- close button, price plates you cannot afford (sampled)
        dangerOutline = hex("4F0707"), -- (sampled)
        errorText = hex("FF4040"), -- "Not enough money" (sampled)
        strike = hex("FF2929"), -- struck-through old price (sampled)
        sliderFill = hex("FFEA7E"), -- (sampled)
        toggleOn = hex("92FF00"), -- (sampled)
        dot = hex("FF0000"), -- notification dot (sampled)
        tabSelected = hex("1E90FF"), -- (estimate)
        tabIdle = hex("8A6E1E"), -- dull gold (estimate)
        disabled = hex("ABABAB"), -- grey CLAIM (sampled)
        bannerBand = hex("000000"), -- title band behind the top text, at 0.6 transparency (estimate)
        timerStrip = hex("000000"), -- bottom-right timer strip, gradient to transparent (estimate)
        hoverDarken = hex("B3B3B3"), -- multiply on hover: pill reads about 70 % as bright (sampled)
    },
    Rarity = {
        Common = hex("8C8C8C"), -- estimate
        Uncommon = hex("5DEB68"), -- sampled
        Rare = hex("1F5BFF"), -- estimate
        Epic = hex("D81FD8"), -- estimate (magenta)
        Legendary = hex("FFD000"), -- estimate
        Divine = hex("FFFFFF"), -- shown as a rainbow gradient on the text
    },
    RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Divine" },
    Buttons = {
        primary = { face = hex("81FD01"), base = hex("49FE01"), text = hex("FFFFFF"), stroke = hex("000000") },
        shop = { face = hex("83FF01"), base = hex("4BFF0C"), text = hex("FFFFFF"), stroke = hex("0B4800") },
        collection = { face = hex("0CE9FB"), base = hex("08C9FF"), text = hex("FFFFFF"), stroke = hex("1A0048") },
        danger = { face = hex("E91212"), base = hex("D81111"), text = hex("FFFFFF"), stroke = hex("4F0707") },
        disabled = { face = hex("C4C4C4"), base = hex("ABABAB"), text = hex("FFFFFF"), stroke = hex("000000") },
    },
    Gradients = {
        pillShop = { stops = { hex("83FF01"), hex("4BFF0C") }, rotation = 90 }, -- sampled
        pillCollection = { stops = { hex("0CE9FB"), hex("08C9FF") }, rotation = 90 }, -- sampled
        buttonPrimary = { stops = { hex("81FD01"), hex("49FE01") }, rotation = 90 }, -- sampled
        titleBarShop = { stops = { hex("7DF057"), hex("5ED93A") }, rotation = 90 }, -- top sampled
        titleBarCollection = { stops = { hex("5FE6FF"), hex("2FC4F0") }, rotation = 90 }, -- estimate
        titleBarSettings = { stops = { hex("F2F4F8"), hex("A9B0BC") }, rotation = 90 }, -- estimate
        timerStrip = { stops = { hex("000000"), hex("000000") }, rotation = 0 }, -- with transparency 1 -> 0.5
    },
    Fonts = {
        title = Font.fromEnum(Enum.Font.FredokaOne),
        body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic),
    },
    TextSize = {
        title = 43, -- panel title (0.040)
        banner = 43, -- top title band (0.040)
        stat = 38, -- italic currency number (0.035)
        pillLabel = 32, -- (0.030)
        price = 30, -- buy button price (0.028)
        heading = 30, -- section titles (0.028)
        toast = 43, -- "Not enough money" (0.040)
        body = 20,
        small = 16,
    },
    Space = { xs = 4, sm = 8, md = 12, lg = 14, xl = 24, xxl = 32 },
    Radius = { pill = 4, tile = 4, panel = 12, button = 6, close = 3 },
    Stroke = { text = 4, outline = 3, panel = 4 },
    ButtonDepth = 0,
    Layout = {
        pillWidth = 0.161, -- H
        pillHeight = 0.061, -- H
        pillGap = 0.013,
        leftColumnTop = 0.41,
        rightTileSize = 0.061,
        rightTileGap = 0.027,
        rightColumnTop = 0.39,
        bannerY = 0.12,
        statsBottom = 0.97,
        hotbarSlot = 0.1,
        panelWidthW = 0.64,
        panelHeight = 0.46,
        titleBar = 0.065,
        closeSize = 0.053,
        drawerWidth = 0.3, -- H, replaces the right tile column
        dotSize = 0.029,
        errorToastY = 0.83, -- toast centre, just above the hotbar
        blurSize = 18, -- estimate
    },
    Motion = {
        panelOpen = { -- no scale: drops in from slightly below; blur fades in alongside
            Time = 0.15,
            EasingStyle = S.Quad,
            EasingDirection = D.Out,
            Delay = 0,
            From = { OffsetY = 0.016 },
            To = { OffsetY = 0 },
            Estimate = false,
        },
        blurIn = {
            Time = 0.14,
            EasingStyle = S.Quad,
            EasingDirection = D.Out,
            Delay = 0,
            From = { Transparency = 1 },
            To = { Transparency = 0 },
            Estimate = true,
        },
        panelClose = { -- instant
            Time = 0,
            EasingStyle = S.Linear,
            EasingDirection = D.In,
            Delay = 0,
            From = { Transparency = 0 },
            To = { Transparency = 1 },
            Estimate = false,
        },
        priceRoll = { -- prices count up to their value when the shop opens
            Time = 0.25,
            EasingStyle = S.Quad,
            EasingDirection = D.Out,
            Delay = 0.1,
            From = {},
            To = {},
            Estimate = true,
        },
        drawerOpen = {
            Time = 0.3,
            EasingStyle = S.Back,
            EasingDirection = D.Out,
            Delay = 0,
            From = { OffsetX = 0.08 },
            To = { OffsetX = 0 },
            Overshoot = 0.5, -- peaked about 0.05 H past rest on an 0.08+ H travel
            Estimate = false,
        },
        pillHover = { -- colour only: multiply face by hoverDarken, no scale
            Time = 0.05,
            EasingStyle = S.Linear,
            EasingDirection = D.In,
            Delay = 0,
            From = {},
            To = {},
            Estimate = false,
        },
        buttonPress = {
            Time = 0.05,
            EasingStyle = S.Quad,
            EasingDirection = D.Out,
            Delay = 0,
            From = { Scale = 1 },
            To = { Scale = 0.9 },
            Estimate = false,
        },
        buttonRelease = {
            Time = 0.08,
            EasingStyle = S.Quad,
            EasingDirection = D.Out,
            Delay = 0,
            From = { Scale = 0.9 },
            To = { Scale = 1 },
            Estimate = false,
        },
        errorToastIn = {
            Time = 0.3,
            EasingStyle = S.Back,
            EasingDirection = D.Out,
            Delay = 0,
            From = { Scale = 0.83 },
            To = { Scale = 1 },
            Overshoot = 0.02,
            Estimate = false,
        },
        errorToastOut = { -- after a 2.0 s hold
            Time = 0.08,
            EasingStyle = S.Linear,
            EasingDirection = D.In,
            Delay = 2.0,
            From = { Transparency = 0 },
            To = { Transparency = 1 },
            Estimate = false,
        },
    },
}

return preset
