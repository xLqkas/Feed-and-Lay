--!strict
-- UI style preset "DarkTiles": dark panels with gradient title bars, big labelled square HUD tiles,
-- menus slide off-screen while a panel is open. Source: docs/ai/ui-presets/throw-food.md. Data only.

local Types = require(script.Parent.Types)

local hex = Color3.fromHex
local S = Enum.EasingStyle
local D = Enum.EasingDirection

local preset: Types.Preset = {
    Colors = {
        panel = hex("242222"), -- panel body (sampled)
        panelAlt = hex("1E2130"), -- section pill, inset rows (estimate)
        divider = hex("313B54"), -- thin lines beside section labels (sampled)
        outline = hex("000000"), -- panel and button outline, text stroke (sampled)
        tile = hex("29282D"), -- HUD tile face (sampled)
        tileRim = hex("888A8F"), -- 2 px inner rim of HUD tiles (sampled)
        paper = hex("FFFFFF"),
        titleText = hex("FFF8E0"), -- cream-white panel titles (estimate)
        labelHover = hex("FFD24A"), -- HUD tile label colour on hover (estimate)
        money = hex("D4FF3A"), -- cash number (estimate)
        stat = hex("2EB8FF"), -- second stat number (estimate)
        primary = hex("29DE00"), -- buy button base (sampled)
        reward = hex("F18F0C"), -- big orange action button base (sampled)
        info = hex("0098FE"), -- slider fill (sampled)
        toggleOn = hex("79FF12"), -- (sampled)
        danger = hex("DB1225"), -- close button base, unaffordable price (sampled)
        locked = hex("474953"), -- LOCKED button (sampled)
        oddsChip = hex("271C34"), -- dark chip inside pet tiles (sampled)
        shade = hex("000000"),
        throwDim = hex("000000"), -- screen dim while the thrown item flies
    },
    -- Index tiles are filled with these (base colour; a 20 % lighter top highlight is the gradient).
    Rarity = {
        Common = hex("C9C9D1"), -- sampled highlight E5E5EA
        Uncommon = hex("6EDB3A"), -- sampled highlight B0FA89
        Rare = hex("3D8BFF"), -- sampled highlight 94CDFF
        Epic = hex("B04CF0"), -- sampled highlight DEA0FE
        Legendary = hex("FFC21A"), -- estimate
        Mythic = hex("FF3B3B"), -- estimate
    },
    RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" },
    Buttons = {
        primary = { face = hex("B7FF59"), base = hex("29DE00"), text = hex("FFFFFF"), stroke = hex("000000") },
        reward = { face = hex("FCB51D"), base = hex("F18F0C"), text = hex("FFFFFF"), stroke = hex("000000") },
        info = { face = hex("4FB8FF"), base = hex("0098FE"), text = hex("FFFFFF"), stroke = hex("000000") },
        danger = { face = hex("FF6E71"), base = hex("DB1225"), text = hex("FFFFFF"), stroke = hex("000000") },
        disabled = { face = hex("5A5C66"), base = hex("474953"), text = hex("B9BBC2"), stroke = hex("000000") },
    },
    Gradients = {
        titleBarShop = { stops = { hex("FF9100"), hex("FFD220"), hex("FF9100") }, rotation = 0 }, -- sampled
        titleBarCollection = { stops = { hex("F446E5"), hex("A03EC6") }, rotation = 90 }, -- sampled
        titleBarSettings = { stops = { hex("E8EAEE"), hex("9097A3") }, rotation = 90 }, -- estimate
        buttonPrimary = { stops = { hex("B7FF59"), hex("29DE00") }, rotation = 90 }, -- sampled
        buttonReward = { stops = { hex("FCB51D"), hex("F18F0C") }, rotation = 90 }, -- sampled
        buttonClose = { stops = { hex("FF6E71"), hex("DB1225") }, rotation = 90 }, -- sampled
        newPill = { stops = { hex("FF4FD8"), hex("FFD84F"), hex("4FFFB0"), hex("4FA8FF") }, rotation = 0 }, -- estimate
    },
    Fonts = {
        title = Font.fromEnum(Enum.Font.FredokaOne),
        body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
    },
    -- 1080 px reference; fraction of screen height in brackets.
    TextSize = {
        hero = 86, -- reveal name (0.080)
        bigButton = 63, -- EQUIP-BEST style button (0.059)
        banner = 43, -- objective line (0.040)
        title = 40, -- panel title (0.037)
        price = 38, -- buy button price (0.035)
        tileLabel = 36, -- HUD tile label (0.033)
        stat = 32, -- HUD stat numbers (0.030)
        heading = 28, -- card names (0.026)
        body = 20,
        small = 17, -- rarity word on tiles (0.016)
    },
    Space = { xs = 4, sm = 8, md = 12, lg = 16, xl = 28, xxl = 40 },
    Radius = { tile = 20, panel = 14, button = 12, close = 9, pill = 999 },
    Stroke = { text = 4, panel = 4, button = 4, tileRim = 3 },
    ButtonDepth = 0, -- no separate base strip: depth comes from the vertical gradient
    Layout = {
        tileSize = 0.13, -- H, square HUD tile
        tileGap = 0.027, -- H
        tileIconOverhang = 0.0, -- icon sits inside the tile
        leftColumnTop = 0.38, -- H
        rightColumnCentre = 0.52, -- H
        statsBottom = 0.96, -- H, bottom-left stat rows
        statIcon = 0.04, -- H
        bannerY = 0.15, -- H
        panelWidthW = 0.62, -- fraction of screen width
        panelHeight = 0.57, -- H
        titleBar = 0.067, -- H
        closeSize = 0.056, -- H
        drawerWidthW = 0.35,
        drawerHeight = 0.77,
        meterHeight = 0.55, -- vertical throw meter
        hotbarSlot = 0.08,
        blurSize = 18, -- BlurEffect.Size behind centred panels (estimate)
    },
    Motion = {
        panelOpen = {
            Time = 0.3,
            EasingStyle = S.Back,
            EasingDirection = D.Out,
            Delay = 0,
            From = { Scale = 0.6 },
            To = { Scale = 1 },
            Overshoot = 0.03, -- peak 1.03 at ~0.26 s; Roblox Back gives ~0.1, so tune or use two tweens
            Estimate = false,
        },
        panelClose = {
            Time = 0.15,
            EasingStyle = S.Quad,
            EasingDirection = D.In,
            Delay = 0,
            From = { Scale = 1 },
            To = { Scale = 0.75 }, -- then Visible = false
            Estimate = false,
        },
        hudTilesHide = { -- both columns slide off their edge when any panel opens
            Time = 0.15,
            EasingStyle = S.Quad,
            EasingDirection = D.In,
            Delay = 0,
            From = { OffsetX = 0 },
            To = { OffsetX = -0.15 }, -- right column uses +0.15
            Estimate = false,
        },
        hudTilesShow = {
            Time = 0.3,
            EasingStyle = S.Back,
            EasingDirection = D.Out,
            Delay = 0.05,
            From = { OffsetX = -0.15 },
            To = { OffsetX = 0 },
            Overshoot = 0.2, -- of the travel distance
            Estimate = false,
        },
        drawerOpen = { -- side panel, scaled from its right-centre anchor
            Time = 0.3,
            EasingStyle = S.Back,
            EasingDirection = D.Out,
            Delay = 0,
            From = { Scale = 0.85 },
            To = { Scale = 1 },
            Overshoot = 0.024,
            Estimate = false,
        },
        buttonHover = {
            Time = 0.1,
            EasingStyle = S.Quad,
            EasingDirection = D.Out,
            Delay = 0,
            From = { Scale = 1 },
            To = { Scale = 1.05 },
            Estimate = true,
        },
        buttonPress = {
            Time = 0.1,
            EasingStyle = S.Quad,
            EasingDirection = D.Out,
            Delay = 0,
            From = { Scale = 1.05 },
            To = { Scale = 0.98 },
            Estimate = false,
        },
        buttonRelease = {
            Time = 0.15,
            EasingStyle = S.Back,
            EasingDirection = D.Out,
            Delay = 0,
            From = { Scale = 0.98 },
            To = { Scale = 1 },
            Overshoot = 0.013,
            Estimate = false,
        },
        tileHoverShine = { -- white diagonal streak (UIGradient offset) sweeps across the tile once
            Time = 0.25,
            EasingStyle = S.Linear,
            EasingDirection = D.In,
            Delay = 0,
            From = { OffsetX = -0.13 },
            To = { OffsetX = 0.13 },
            Estimate = true,
        },
        numberRoll = { -- counter counts up one unit at a time, about 55 ms per unit, per income tick
            Time = 0.27,
            EasingStyle = S.Linear,
            EasingDirection = D.In,
            Delay = 0,
            From = {},
            To = {},
            Estimate = false,
        },
        floorArrowScroll = { -- floor chevrons move toward the goal by one arrow gap per cycle
            Time = 0.85,
            EasingStyle = S.Linear,
            EasingDirection = D.In,
            Delay = 0,
            From = { OffsetY = 0 },
            To = { OffsetY = 1 }, -- 1 = one arrow spacing (world units, not screen)
            Loop = true,
            Estimate = false,
        },
        throwDim = {
            Time = 0.2,
            EasingStyle = S.Quad,
            EasingDirection = D.Out,
            Delay = 0,
            From = { Transparency = 1 },
            To = { Transparency = 0.3 },
            Estimate = true,
        },
        revealFlash = {
            Time = 0.35,
            EasingStyle = S.Quad,
            EasingDirection = D.Out,
            Delay = 0,
            From = { Transparency = 0 },
            To = { Transparency = 1 },
            Estimate = true,
        },
        revealSticker = { -- tilted NEW! sticker beside the name
            Time = 0.3,
            EasingStyle = S.Back,
            EasingDirection = D.Out,
            Delay = 0.2,
            From = { Scale = 0, Rotation = -30 },
            To = { Scale = 1, Rotation = -15 },
            Estimate = true,
        },
    },
}

return preset
