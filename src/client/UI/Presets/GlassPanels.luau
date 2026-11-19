--!strict
-- UI style preset "GlassPanels": see-through dark panels over a blurred world, a saturated title bar per menu
-- matching its HUD button, wide pills with an overhanging icon, cash bursts that fly to the counter.
-- Source: docs/ai/ui-presets/scare-streamer.md (from the earlier study, no frame-by-frame capture). Data only.

local Types = require(script.Parent.Types)

local hex = Color3.fromHex
local S = Enum.EasingStyle
local D = Enum.EasingDirection

local preset: Types.Preset = {
    Colors = {
        panel = hex("2D2D33"), -- body, drawn at about 0.3 transparency so the blurred world shows (estimate)
        card = hex("737273"), -- item cards inside panels, also see-through (sampled)
        outline = hex("13131A"), -- panel outline and text stroke (sampled)
        paper = hex("FFFFFF"),
        money = hex("3BE33B"), -- cash number and gain toasts (estimate)
        primary = hex("15BC20"), -- buy-with-cash button base (sampled)
        premium = hex("B31FBC"), -- Robux button (sampled)
        danger = hex("E81E1E"), -- close button, unaffordable price (estimate)
        dangerOutline = hex("7C0000"), -- (sampled)
        threat = hex("D32E45"), -- red news toast (sampled)
        stat = hex("5FD4FF"), -- multiplier text "x2" (sampled)
        dot = hex("FF3030"), -- notification dot (estimate)
        tutorialRing = hex("E8762A"), -- glowing ring round a newly shown HUD button (estimate)
        timerStrip = hex("000000"), -- gradient strip behind the day/night timer (estimate)
    },
    Rarity = {
        Common = hex("A6A6A8"), -- sampled
        Uncommon = hex("65BA0E"), -- sampled
        Rare = hex("1EE0FF"), -- sampled
        Epic = hex("B54CFF"), -- estimate
        Legendary = hex("FFC21A"), -- estimate
        Insane = hex("FF5A1F"), -- estimate
        Secret = hex("FFFFFF"), -- rainbow gradient
    },
    RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Insane", "Secret" },
    Buttons = {
        primary = { face = hex("10EA4A"), base = hex("15BC20"), text = hex("FFFFFF"), stroke = hex("13131A") },
        premium = { face = hex("D23CDB"), base = hex("B31FBC"), text = hex("FFFFFF"), stroke = hex("13131A") },
        danger = { face = hex("FF3B3B"), base = hex("E81E1E"), text = hex("FFFFFF"), stroke = hex("7C0000") },
        collection = { face = hex("3EC8F0"), base = hex("2AA6D0"), text = hex("FFFFFF"), stroke = hex("13131A") },
    },
    Gradients = {
        titleBarCostumes = { stops = { hex("E677FF"), hex("C967FF") }, rotation = 90 }, -- sampled
        buttonPrimary = { stops = { hex("10EA4A"), hex("15BC20") }, rotation = 90 }, -- sampled
        timerStrip = { stops = { hex("000000"), hex("000000") }, rotation = 0 }, -- transparency 1 -> 0.45
    },
    Fonts = {
        title = Font.fromEnum(Enum.Font.FredokaOne),
        body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic),
    },
    TextSize = {
        title = 54, -- panel title (0.050)
        banner = 50, -- objective line (0.047)
        pillLabel = 38, -- (0.035)
        toast = 36, -- top news line (0.033)
        stat = 36, -- cash (0.033)
        price = 34, -- italic price on buttons (0.031)
        heading = 32, -- card names
        body = 20,
        small = 18, -- rarity word under names
    },
    Space = { xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32 },
    Radius = { panel = 12, card = 8, button = 6, close = 4, pill = 10 },
    Stroke = { text = 4, panel = 6, button = 3 },
    ButtonDepth = 4, -- slight bottom bevel on pills
    Layout = {
        pillWidth = 0.2, -- H
        pillHeight = 0.073, -- H
        pillIconOverhang = 0.02, -- icon pokes out past the left end
        leftColumnTop = 0.42,
        rightTileSize = 0.117,
        rightColumnTop = 0.41,
        bannerY = 0.14,
        toastY = 0.053,
        cashBottom = 0.876,
        hotbarSlot = 0.093,
        panelWidthW = 0.88,
        panelHeight = 0.69,
        titleBar = 0.085,
        closeSize = 0.067,
        blurSize = 18, -- estimate
    },
    Motion = { -- all estimated from 1-2 s apart screenshots in the earlier study
        cashFly = { -- icons spray from the claim button and fly to the cash counter
            Time = 0.7,
            EasingStyle = S.Quad,
            EasingDirection = D.In,
            Delay = 0,
            From = { Scale = 1 },
            To = { Scale = 0.6 },
            Stagger = 0.015, -- about 20 icons within ~0.3 s
            Estimate = true,
        },
        counterRoll = {
            Time = 1.0,
            EasingStyle = S.Quad,
            EasingDirection = D.Out,
            Delay = 0.3,
            From = {},
            To = {},
            Estimate = true,
        },
        floatNumber = { -- "-1" damage and "+$510" income numbers float up and fade
            Time = 0.6,
            EasingStyle = S.Quad,
            EasingDirection = D.Out,
            Delay = 0,
            From = { OffsetY = 0, Transparency = 0 },
            To = { OffsetY = -0.05, Transparency = 1 },
            Estimate = true,
        },
        revealRoll = { -- name and model cycle like a slot machine, slowing down, then land
            Time = 2.5,
            EasingStyle = S.Quad,
            EasingDirection = D.Out,
            Delay = 0,
            From = {},
            To = {},
            Estimate = true,
        },
        revealLand = {
            Time = 0.3,
            EasingStyle = S.Back,
            EasingDirection = D.Out,
            Delay = 0,
            From = { Scale = 1.3 },
            To = { Scale = 1 },
            Estimate = true,
        },
        newButtonPulse = { -- outline ring pulses round a just-unlocked HUD button
            Time = 0.6,
            EasingStyle = S.Sine,
            EasingDirection = D.InOut,
            Delay = 0,
            From = { Scale = 1, Transparency = 0 },
            To = { Scale = 1.12, Transparency = 0.4 },
            Loop = true,
            Estimate = true,
        },
        pointerBob = { -- pointing hand under the new button
            Time = 0.5,
            EasingStyle = S.Sine,
            EasingDirection = D.InOut,
            Delay = 0,
            From = { OffsetY = 0 },
            To = { OffsetY = -0.012 },
            Loop = true,
            Estimate = true,
        },
        nightFlash = { -- full-screen white flash with a big moon and a 3 s count
            Time = 0.5,
            EasingStyle = S.Quad,
            EasingDirection = D.Out,
            Delay = 0,
            From = { Transparency = 0 },
            To = { Transparency = 1 },
            Estimate = true,
        },
        timerUrgent = { -- under 10 s the timer text turns red
            Time = 0.2,
            EasingStyle = S.Linear,
            EasingDirection = D.In,
            Delay = 0,
            From = {},
            To = {},
            Estimate = true,
        },
    },
}

return preset
