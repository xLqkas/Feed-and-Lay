--!strict
-- ThrowCinematic: Implements the Throw Flight Cinematic (design-v3, throw_flight_cinematic.md)
-- Chunky Nest aesthetics: vertical charge meter beside character, dynamic chase camera,
-- live luck multiplier & zone counter banner, expanding ground pulse rings, and Big Egg Drop Fanfare (Option A).
-- Client presentation only. Toggled with ThrowCinematic.enabled.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Cam = require(script.Parent.Cam)
local Ctx = require(script.Parent.Ctx)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))

local Economy = Ctx.Economy
local player = Players.LocalPlayer

local ThrowCinematic = {}
ThrowCinematic.enabled = true

-- Active instances & state tracking
local activeMeterGui: BillboardGui? = nil
local activeBannerGui: ScreenGui? = nil
local activeFanfareGui: ScreenGui? = nil
local activeRunConn: RBXScriptConnection? = nil
local activeDiedConn: RBXScriptConnection? = nil
local meterNeedle: Frame? = nil
local meterReach: TextLabel? = nil
local meterPrompt: TextLabel? = nil
local meterSweet: Frame? = nil
local meterScale: UIScale? = nil

local bannerMult: TextLabel? = nil
local bannerZoneBadge: TextLabel? = nil
local bannerZoneScale: UIScale? = nil
local currentTrackedZone = 0

local function getPlayerGui(): PlayerGui?
    return player:FindFirstChildOfClass("PlayerGui")
end

--------------------------------------------------------------------------------
-- 1. VERTICAL CHARGE METER (Chunky Nest BillboardGui beside character)
--------------------------------------------------------------------------------

local function buildVerticalMeter(): BillboardGui
    local bg = Instance.new("BillboardGui")
    bg.Name = "FLThrowVerticalMeter"
    bg.Size = UDim2.fromOffset(80, 260)
    bg.StudsOffset = Vector3.new(3.2, 0.6, 0)
    bg.AlwaysOnTop = true
    bg.ClipsDescendants = false
    bg.ResetOnSpawn = false

    local scale = Instance.new("UIScale")
    scale.Scale = 0.7
    scale.Parent = bg
    meterScale = scale

    -- Outer Container
    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(1, 0, 1, 0)
    container.BackgroundColor3 = Color3.fromHex("1E293B")
    container.BorderSizePixel = 0
    container.Parent = bg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = container

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromHex("12202A")
    stroke.Thickness = 4
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = container

    -- Top Title Pill
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -12, 0, 22)
    title.Position = UDim2.new(0, 6, 0, 6)
    title.BackgroundColor3 = Color3.fromHex("12202A")
    title.TextColor3 = Color3.fromHex("FFC800")
    title.FontFace = Theme.Fonts.title
    title.TextSize = 12
    title.Text = "POWER"
    title.BorderSizePixel = 0
    title.Parent = container

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = title

    -- Inner Track
    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Size = UDim2.new(0, 32, 1, -66)
    track.Position = UDim2.new(0.5, 0, 0.5, 3)
    track.AnchorPoint = Vector2.new(0.5, 0.5)
    track.BackgroundColor3 = Color3.fromHex("0F172A")
    track.BorderSizePixel = 0
    track.ClipsDescendants = false
    track.Parent = container

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(0, 12)
    trackCorner.Parent = track

    local trackStroke = Instance.new("UIStroke")
    trackStroke.Color = Color3.fromHex("12202A")
    trackStroke.Thickness = 2
    trackStroke.Parent = track

    -- Gradient Fill
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.new(1, 1, 1)
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 12)
    fillCorner.Parent = fill

    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, Color3.fromHex("FF4B4B")), -- Red (top)
        ColorSequenceKeypoint.new(0.12, Color3.fromHex("FFD700")), -- Sweet Spot Gold
        ColorSequenceKeypoint.new(0.35, Color3.fromHex("FFC800")), -- Yellow
        ColorSequenceKeypoint.new(0.65, Color3.fromHex("2BD45B")), -- Green
        ColorSequenceKeypoint.new(1.0, Color3.fromHex("1CB0F6")), -- Cyan/Blue (bottom)
    })
    gradient.Parent = fill

    -- Sweet Spot Highlight Zone (SWEET_MIN = 0.85, SWEET_MAX = 0.95)
    local sweet = Instance.new("Frame")
    sweet.Name = "SweetSpot"
    sweet.Size = UDim2.new(1, 4, 0.10, 0)
    sweet.Position = UDim2.new(0.5, 0, 1 - Economy.SWEET_MAX, 0)
    sweet.AnchorPoint = Vector2.new(0.5, 0)
    sweet.BackgroundColor3 = Color3.fromHex("FFF275")
    sweet.BackgroundTransparency = 0.35
    sweet.BorderSizePixel = 0
    sweet.Parent = track
    meterSweet = sweet

    local sweetCorner = Instance.new("UICorner")
    sweetCorner.CornerRadius = UDim.new(0, 6)
    sweetCorner.Parent = sweet

    local sweetStroke = Instance.new("UIStroke")
    sweetStroke.Color = Color3.fromHex("FFD700")
    sweetStroke.Thickness = 2
    sweetStroke.Parent = sweet

    -- Needle Indicator
    local needle = Instance.new("Frame")
    needle.Name = "Needle"
    needle.Size = UDim2.new(1, 16, 0, 8)
    needle.Position = UDim2.new(0.5, 0, 1, 0)
    needle.AnchorPoint = Vector2.new(0.5, 0.5)
    needle.BackgroundColor3 = Color3.fromHex("FFFFFF")
    needle.BorderSizePixel = 0
    needle.ZIndex = 3
    needle.Parent = track
    meterNeedle = needle

    local needleCorner = Instance.new("UICorner")
    needleCorner.CornerRadius = UDim.new(0, 4)
    needleCorner.Parent = needle

    local needleStroke = Instance.new("UIStroke")
    needleStroke.Color = Color3.fromHex("12202A")
    needleStroke.Thickness = 2
    needleStroke.Parent = needle

    -- Floating Reach Pill (attached beside needle)
    local reach = Instance.new("TextLabel")
    reach.Name = "ReachPill"
    reach.Size = UDim2.fromOffset(50, 20)
    reach.Position = UDim2.new(0, -8, 0.5, 0)
    reach.AnchorPoint = Vector2.new(1, 0.5)
    reach.BackgroundColor3 = Color3.fromHex("12202A")
    reach.TextColor3 = Color3.fromHex("FFC800")
    reach.FontFace = Theme.Fonts.title
    reach.TextSize = 11
    reach.Text = "+0m"
    reach.BorderSizePixel = 0
    reach.Parent = needle
    meterReach = reach

    local reachCorner = Instance.new("UICorner")
    reachCorner.CornerRadius = UDim.new(0, 6)
    reachCorner.Parent = reach

    local reachStroke = Instance.new("UIStroke")
    reachStroke.Color = Color3.fromHex("FFC800")
    reachStroke.Thickness = 1.5
    reachStroke.Parent = reach

    -- Bottom Prompt Label
    local prompt = Instance.new("TextLabel")
    prompt.Name = "Prompt"
    prompt.Size = UDim2.new(1, -12, 0, 22)
    prompt.Position = UDim2.new(0, 6, 1, -28)
    prompt.BackgroundColor3 = Color3.fromHex("12202A")
    prompt.TextColor3 = Color3.fromHex("94A3B8")
    prompt.FontFace = Theme.Fonts.title
    prompt.TextSize = 10
    prompt.Text = "HOLD"
    prompt.BorderSizePixel = 0
    prompt.Parent = container
    meterPrompt = prompt

    local promptCorner = Instance.new("UICorner")
    promptCorner.CornerRadius = UDim.new(0, 8)
    promptCorner.Parent = prompt

    return bg
end

function ThrowCinematic.startCharge(strength: number)
    if not ThrowCinematic.enabled then
        return
    end

    local pGui = getPlayerGui()
    if not pGui then
        return
    end

    local root = Ctx.root()
    if not activeMeterGui or not activeMeterGui.Parent then
        activeMeterGui = buildVerticalMeter()
        activeMeterGui.Parent = pGui
    end

    local bg = activeMeterGui :: BillboardGui
    if root then
        bg.Adornee = root
    end
    bg.Enabled = true

    if meterScale then
        meterScale.Scale = 0.5
        local style = if Ctx.reducedMotion() then Enum.EasingStyle.Quad else Enum.EasingStyle.Back
        TweenService:Create(
            meterScale,
            TweenInfo.new(0.2, style, Enum.EasingDirection.Out),
            { Scale = 1.0 }
        ):Play()
    end

    if meterNeedle then
        meterNeedle.Position = UDim2.new(0.5, 0, 1, 0)
    end
    if meterReach then
        meterReach.Text = "+0m"
        meterReach.TextColor3 = Color3.fromHex("FFC800")
    end
    if meterPrompt then
        meterPrompt.Text = "HOLD"
        meterPrompt.TextColor3 = Color3.fromHex("94A3B8")
    end
end

function ThrowCinematic.updateCharge(needlePos: number, _elapsed: number)
    if not activeMeterGui or not meterNeedle or not activeMeterGui.Enabled then
        return
    end

    local clampedP = math.clamp(needlePos, 0, 1)
    meterNeedle.Position = UDim2.new(0.5, 0, 1 - clampedP, 0)

    local mult = Economy.throwMultiplier(clampedP)
    local reachDist = math.floor(Ctx.strength * mult)
    if meterReach then
        meterReach.Text = "+" .. reachDist .. "m"
    end

    local isSweet = clampedP >= Economy.SWEET_MIN and clampedP <= Economy.SWEET_MAX
    if meterPrompt then
        if isSweet then
            meterPrompt.Text = "RELEASE! 🔥"
            meterPrompt.TextColor3 = Color3.fromHex("FFD700")
            if meterReach then
                meterReach.TextColor3 = Color3.fromHex("2BD45B")
            end
        else
            meterPrompt.Text = "HOLD"
            meterPrompt.TextColor3 = Color3.fromHex("94A3B8")
            if meterReach then
                meterReach.TextColor3 = Color3.fromHex("FFC800")
            end
        end
    end
end

function ThrowCinematic.stopCharge()
    if activeMeterGui and meterScale and activeMeterGui.Enabled then
        local t = TweenService:Create(
            meterScale,
            TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Scale = 0.4 }
        )
        t:Play()
        task.delay(0.13, function()
            if activeMeterGui then
                activeMeterGui.Enabled = false
            end
        end)
    elseif activeMeterGui then
        activeMeterGui.Enabled = false
    end
end

--------------------------------------------------------------------------------
-- 2. LIVE FLIGHT BANNER (Multiplier counter & Zone badge)
--------------------------------------------------------------------------------

local function buildFlightBanner(): ScreenGui
    local pGui = getPlayerGui()
    local sg = Instance.new("ScreenGui")
    sg.Name = "FLThrowBannerGui"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 18

    local banner = Instance.new("Frame")
    banner.Name = "TopBanner"
    banner.Size = UDim2.fromOffset(360, 58)
    banner.Position = UDim2.new(0.5, 0, 0.05, 0)
    banner.AnchorPoint = Vector2.new(0.5, 0)
    banner.BackgroundColor3 = Color3.fromHex("1E293B")
    banner.BorderSizePixel = 0
    banner.Parent = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 18)
    corner.Parent = banner

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromHex("12202A")
    stroke.Thickness = 4
    stroke.Parent = banner

    -- Left Multiplier Box
    local multBox = Instance.new("Frame")
    multBox.Name = "MultBox"
    multBox.Size = UDim2.new(0.46, 0, 1, 0)
    multBox.BackgroundTransparency = 1
    multBox.Parent = banner

    local multTitle = Instance.new("TextLabel")
    multTitle.Name = "Title"
    multTitle.Size = UDim2.new(1, 0, 0, 16)
    multTitle.Position = UDim2.new(0, 0, 0, 6)
    multTitle.BackgroundTransparency = 1
    multTitle.TextColor3 = Color3.fromHex("94A3B8")
    multTitle.FontFace = Theme.Fonts.title
    multTitle.TextSize = 10
    multTitle.Text = "LUCK MULTIPLIER"
    multTitle.Parent = multBox

    local multVal = Instance.new("TextLabel")
    multVal.Name = "Value"
    multVal.Size = UDim2.new(1, 0, 0, 28)
    multVal.Position = UDim2.new(0, 0, 0, 22)
    multVal.BackgroundTransparency = 1
    multVal.TextColor3 = Color3.fromHex("FFC800")
    multVal.FontFace = Theme.Fonts.title
    multVal.TextSize = 22
    multVal.Text = "1.00x"
    multVal.Parent = multBox
    bannerMult = multVal

    -- Vertical Divider
    local div = Instance.new("Frame")
    div.Name = "Divider"
    div.Size = UDim2.new(0, 2, 0.65, 0)
    div.Position = UDim2.new(0.47, 0, 0.5, 0)
    div.AnchorPoint = Vector2.new(0.5, 0.5)
    div.BackgroundColor3 = Color3.fromHex("334155")
    div.BorderSizePixel = 0
    div.Parent = banner

    -- Right Zone Badge
    local zoneBox = Instance.new("Frame")
    zoneBox.Name = "ZoneBox"
    zoneBox.Size = UDim2.new(0.51, 0, 1, 0)
    zoneBox.Position = UDim2.new(0.49, 0, 0, 0)
    zoneBox.BackgroundTransparency = 1
    zoneBox.Parent = banner

    local badge = Instance.new("TextLabel")
    badge.Name = "Badge"
    badge.Size = UDim2.new(1, -16, 0, 36)
    badge.Position = UDim2.new(0.5, 0, 0.5, 0)
    badge.AnchorPoint = Vector2.new(0.5, 0.5)
    badge.BackgroundColor3 = Fx.FLOOR[1] or Color3.fromHex("2563EB")
    badge.TextColor3 = Color3.fromHex("FFFFFF")
    badge.FontFace = Theme.Fonts.title
    badge.TextSize = 13
    badge.Text = "Dewdrop Meadow"
    badge.BorderSizePixel = 0
    badge.Parent = zoneBox
    bannerZoneBadge = badge

    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0, 12)
    badgeCorner.Parent = badge

    local badgeStroke = Instance.new("UIStroke")
    badgeStroke.Color = Color3.fromHex("12202A")
    badgeStroke.Thickness = 2
    badgeStroke.Parent = badge

    local badgeScale = Instance.new("UIScale")
    badgeScale.Scale = 1.0
    badgeScale.Parent = badge
    bannerZoneScale = badgeScale

    if pGui then
        sg.Parent = pGui
    end
    return sg
end

local function updateZoneBadge(zone: any)
    if not bannerZoneBadge then
        return
    end
    bannerZoneBadge.Text = zone.Name
    bannerZoneBadge.BackgroundColor3 = Fx.FLOOR[zone.Id] or Color3.fromHex("2563EB")

    if bannerZoneScale and not Ctx.reducedMotion() then
        bannerZoneScale.Scale = 1.25
        TweenService:Create(
            bannerZoneScale,
            TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Scale = 1.0 }
        ):Play()
    end
    Sfx.play("tick", 1.2, 0.7)
end

-- Zone cutoff boundaries matching the 3D world gates:
-- Gate_1 at Z = 22 (Dewdrop Meadow), Gate_2 at Z = 1422 (Bog Marsh), Gate_3 at Z = 2822 (Ember Volcano),
-- Gate_4 at Z = 4222 (Coral Reef), Gate_5 at Z = 5622 (Starfield)
local function zoneForWorldZ(z: number): any
    if z >= 5622 then
        return Economy.Zones[5] or Economy.Zones[#Economy.Zones]
    elseif z >= 4222 then
        return Economy.Zones[4]
    elseif z >= 2822 then
        return Economy.Zones[3]
    elseif z >= 1422 then
        return Economy.Zones[2]
    else
        return Economy.Zones[1]
    end
end

--------------------------------------------------------------------------------
-- 3. LANDING PULSE RINGS & IMPACT FX
--------------------------------------------------------------------------------

local function spawnPulseRing(landing: Vector3, zoneId: number, foodColor: Color3)
    local ringColor = Fx.FLOOR[zoneId] or Color3.fromHex("FFD700")

    -- Ring 1: expanding ground shockwave
    local ring1 = Instance.new("Part")
    ring1.Name = "FLPulseRing1"
    ring1.Shape = Enum.PartType.Cylinder
    ring1.Size = Vector3.new(0.08, 2, 2)
    ring1.CFrame = CFrame.new(landing + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
    ring1.Color = ringColor
    ring1.Material = Enum.Material.Neon
    ring1.Transparency = 0.15
    ring1.Anchored = true
    ring1.CanCollide = false
    ring1.CanQuery = false
    ring1.CanTouch = false
    ring1.Parent = Fx.folder

    TweenService:Create(
        ring1,
        TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = Vector3.new(0.08, 18, 18), Transparency = 1.0 }
    ):Play()

    task.delay(0.8, function()
        ring1:Destroy()
    end)

    -- Ring 2: delayed secondary ripple
    task.delay(0.12, function()
        local ring2 = Instance.new("Part")
        ring2.Name = "FLPulseRing2"
        ring2.Shape = Enum.PartType.Cylinder
        ring2.Size = Vector3.new(0.08, 1.5, 1.5)
        ring2.CFrame = CFrame.new(landing + Vector3.new(0, 0.09, 0)) * CFrame.Angles(0, 0, math.rad(90))
        ring2.Color = Color3.fromHex("FFFFFF")
        ring2.Material = Enum.Material.Neon
        ring2.Transparency = 0.2
        ring2.Anchored = true
        ring2.CanCollide = false
        ring2.CanQuery = false
        ring2.CanTouch = false
        ring2.Parent = Fx.folder

        TweenService:Create(
            ring2,
            TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = Vector3.new(0.08, 14, 14), Transparency = 1.0 }
        ):Play()

        task.delay(0.7, function()
            ring2:Destroy()
        end)
    end)

    -- Particle bursts
    Fx.burst(landing + Vector3.new(0, 0.4, 0), foodColor, 22, 14, 0.5, 0.8)
    Fx.burst(landing + Vector3.new(0, 0.2, 0), Color3.fromRGB(220, 210, 190), 12, 8, 0.35, 0.6)
end

--------------------------------------------------------------------------------
-- 4. EGG DROP FANFARE (Option A)
--------------------------------------------------------------------------------

local function showEggFanfare(r: any, landing: Vector3)
    local pGui = getPlayerGui()
    if not pGui then
        return
    end

    local sg = Instance.new("ScreenGui")
    sg.Name = "FLFanfareGui"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 22
    activeFanfareGui = sg

    -- Screen Tint Flash
    local flash = Instance.new("Frame")
    flash.Name = "ScreenFlash"
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.BackgroundColor3 = Fx.FLOOR[r.zone] or Color3.fromHex("FFD700")
    flash.BackgroundTransparency = if Ctx.reducedMotion() then 0.8 else 0.55
    flash.BorderSizePixel = 0
    flash.Parent = sg

    TweenService:Create(
        flash,
        TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 1.0 }
    ):Play()

    -- Fanfare Announcement Card
    local banner = Instance.new("Frame")
    banner.Name = "FanfareCard"
    banner.Size = UDim2.fromOffset(400, 96)
    banner.Position = UDim2.new(0.5, 0, 0.24, 0)
    banner.AnchorPoint = Vector2.new(0.5, 0.5)
    banner.BackgroundColor3 = Color3.fromHex("1E293B")
    banner.BorderSizePixel = 0
    banner.Parent = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 20)
    corner.Parent = banner

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromHex("12202A")
    stroke.Thickness = 5
    stroke.Parent = banner

    local scale = Instance.new("UIScale")
    scale.Scale = 0.4
    scale.Parent = banner

    -- Main Title
    local titleText = "NICE CATCH! 🎯"
    if r.label == "SWEET!" then
        titleText = "SWEET SPOT! 🔥"
    elseif r.zone >= 4 then
        titleText = "LEGENDARY CATCH! ⭐"
    elseif r.zone >= 3 then
        titleText = "EPIC LAUNCH! ✨"
    elseif r.zone >= 2 then
        titleText = "GREAT THROW! 👍"
    end

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 42)
    title.Position = UDim2.new(0, 0, 0, 10)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromHex("FFC800")
    title.FontFace = Theme.Fonts.title
    title.TextSize = 28
    title.Text = titleText
    title.Parent = banner

    local titleStroke = Instance.new("UIStroke")
    titleStroke.Color = Color3.fromHex("12202A")
    titleStroke.Thickness = 3
    titleStroke.Parent = title

    -- Subtitle
    local sub = Instance.new("TextLabel")
    sub.Name = "Subtitle"
    sub.Size = UDim2.new(1, 0, 0, 24)
    sub.Position = UDim2.new(0, 0, 0, 52)
    sub.BackgroundTransparency = 1
    sub.TextColor3 = Color3.fromHex("FFFFFF")
    sub.FontFace = Theme.Fonts.body
    sub.TextSize = 15
    sub.Text = r.zoneName .. " • " .. string.format("%.2fx Luck", r.multiplier)
    sub.Parent = banner

    sg.Parent = pGui

    -- Bounce In
    local style = if Ctx.reducedMotion() then Enum.EasingStyle.Quad else Enum.EasingStyle.Back
    TweenService:Create(
        scale,
        TweenInfo.new(0.24, style, Enum.EasingDirection.Out),
        { Scale = 1.0 }
    ):Play()

    -- Fanfare Audio
    if r.zone >= 4 or r.label == "SWEET!" then
        Sfx.play("fanfare3", 1, 1.0)
    elseif r.zone >= 3 then
        Sfx.play("fanfare2", 1, 0.9)
    else
        Sfx.play("fanfare1", 1, 0.8)
    end

    -- World Sparkle Burst
    Fx.burst(landing + Vector3.new(0, 2, 0), Color3.fromHex("FFD700"), 24, 16, 0.5, 1.0)

    -- Hold until egg launches, then slide up and fade
    Ctx.at(r.eggLaunchAt, function()
        if activeFanfareGui == sg then
            TweenService:Create(
                banner,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { Position = UDim2.new(0.5, 0, 0.14, 0), BackgroundTransparency = 1.0 }
            ):Play()
            TweenService:Create(
                title,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { TextTransparency = 1.0 }
            ):Play()
            TweenService:Create(
                sub,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { TextTransparency = 1.0 }
            ):Play()
            task.delay(0.32, function()
                if activeFanfareGui == sg then
                    activeFanfareGui:Destroy()
                    activeFanfareGui = nil
                end
            end)
        end
    end)
end

--------------------------------------------------------------------------------
-- 5. COMPLETE THROW FLIGHT CINEMATIC PLAYBACK
--------------------------------------------------------------------------------

function ThrowCinematic.play(
    r: any,
    landing: Vector3,
    food: BasePart?,
    getEgg: () -> BasePart?,
    onComplete: (() -> ())?
)
    if not ThrowCinematic.enabled then
        return
    end

    local from = Ctx.launchOrigin()
    if landing then
        from = Vector3.new(landing.X, from.Y, from.Z)
    end
    local flat = (from - landing) * Vector3.new(1, 0, 1)
    local back = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
    local side = back:Cross(Vector3.yAxis).Unit

    currentTrackedZone = 1
    if activeBannerGui then
        activeBannerGui:Destroy()
    end
    activeBannerGui = buildFlightBanner()
    if bannerMult then
        bannerMult.Text = "1.00x"
    end
    if bannerZoneBadge then
        bannerZoneBadge.Text = Economy.Zones[1].Name
        bannerZoneBadge.BackgroundColor3 = Fx.FLOOR[1] or Color3.fromHex("2563EB")
    end

    local landed = false
    local henLayed = false
    local currentCF = Workspace.CurrentCamera.CFrame

    if not Ctx.reducedMotion() then
        Cam.fov(76, 0.3)
    end

    -- Fail-safe cleanup
    local function cleanup()
        if activeRunConn then
            activeRunConn:Disconnect()
            activeRunConn = nil
        end
        if activeDiedConn then
            activeDiedConn:Disconnect()
            activeDiedConn = nil
        end
        Cam.clear("throw_cinematic")
        Cam.fov(70, 0.25)
        if activeBannerGui then
            activeBannerGui:Destroy()
            activeBannerGui = nil
        end
        if activeFanfareGui then
            activeFanfareGui:Destroy()
            activeFanfareGui = nil
        end
        if onComplete then
            onComplete()
            onComplete = nil
        end
    end

    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        activeDiedConn = hum.Died:Connect(cleanup)
    end

    -- Camera shot registration (Priority 25 overrides default throw cam 20)
    Cam.set("throw_cinematic", 25, function(dt)
        local now = Ctx.now()
        local targetCF: CFrame? = nil

        if now < r.foodLandsAt and food and food.Parent then
            -- Phase 1: Flying fast behind food
            local p = food.Position
            targetCF = CFrame.lookAt(p + back * 16 + Vector3.new(0, 5, 0), p + back * -4 + Vector3.new(0, 0.5, 0))

            -- Live multiplier counting up & live zone tracking
            local flightDuration = math.max(r.foodLandsAt - r.releasedAt, 0.01)
            local alpha = math.clamp((now - r.releasedAt) / flightDuration, 0, 1)
            -- Ease-out curve so counter slows near destination
            local easeMult = 1.0 + (r.multiplier - 1.0) * (1 - (1 - alpha) ^ 2)
            if bannerMult then
                bannerMult.Text = string.format("%.2fx", easeMult)
            end

            local activeZone = zoneForWorldZ(p.Z)
            if activeZone.Id ~= currentTrackedZone then
                currentTrackedZone = activeZone.Id
                updateZoneBadge(activeZone)
            end

        elseif now < r.eggLaunchAt then
            -- Phase 2: Landing & Mama Hen
            if not landed then
                landed = true
                spawnPulseRing(landing, r.zone, if food then food.Color else Color3.fromHex("FF4B4B"))
                Sfx.play("thunk", 1, 1, landing)
                if r.label == "SWEET!" then
                    Sfx.play("ding", 1.2, 1, landing)
                end
                if bannerMult then
                    bannerMult.Text = string.format("%.2fx", r.multiplier)
                end
                updateZoneBadge(Economy.Zones[r.zone])
                Cam.fov(70, 0.4)
            end

            -- Egg drop fanfare trigger (~1.0s after landing)
            if not henLayed and now >= r.foodLandsAt + 0.95 then
                henLayed = true
                showEggFanfare(r, landing)
            end

            -- Cinematic 3/4 framing of the landing spot & Mama Hen
            targetCF = CFrame.lookAt(
                landing + back * 20 + side * 13 + Vector3.new(0, 9, 0),
                landing + Vector3.new(0, 3, 0)
            )

        elseif now < r.arrivesAt + 0.15 then
            -- Phase 3: Egg rocket return to nest
            local egg = getEgg()
            if egg and egg.Parent then
                local p = egg.Position
                targetCF = CFrame.lookAt(p - back * 18 + Vector3.new(0, 7, 0), p)
            else
                local root = Ctx.root()
                if root then
                    targetCF = CFrame.lookAt(root.Position - back * 16 + Vector3.new(0, 8, 0), root.Position)
                end
            end
        else
            -- Phase 4: Arrival & Return
            cleanup()
        end

        if targetCF then
            local speed = if now < r.foodLandsAt then (if Ctx.reducedMotion() then 10 else 16) else (if Ctx.reducedMotion() then 8 else 12)
            currentCF = Cam.smooth(currentCF, targetCF, dt, speed)
        end
        return currentCF
    end)
end

return ThrowCinematic
