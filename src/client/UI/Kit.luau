--!strict
-- Feed and Lay UI kit (docs/ai/ui-style-spec.md). Every screen is built with these helpers; colours and sizes
-- come from Theme, art from ImageIds, and every animation from Motion (no tween values here).
-- Offsets are reference pixels at 1080p: Kit.screen puts one UIScale on a root frame sized to the screen.
-- Gvesster icons (all Kit icons) are never tinted; SunGraphica art (panels, ribbons, buttons, bars) may be.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local ImageIds = require(script.Parent.ImageIds)
local Logic = require(script.Parent.Logic)
local Motion = require(script.Parent.Motion)
local Theme = require(script.Parent.Theme)

local C = Theme.Colors
local T = Theme.TextSize
local Kit = {}

export type Screen = {
    gui: ScreenGui,
    root: Frame,
    scale: UIScale,
    toasts: Frame, -- gain / error lane, bottom centre
    announce: Frame, -- announce lane, top centre
    banner: TextLabel?,
    goal: Frame?,
    info: Logic.LayoutInfo,
    listeners: { (Logic.LayoutInfo) -> () },
    toastSerial: number,
}

export type Panels = {
    state: Logic.PanelState,
    frames: { [string]: Frame },
    shade: Frame,
    blur: BlurEffect,
    serial: number,
    listeners: { (string?) -> () },
}

export type Pill = { frame: Frame, icon: ImageLabel, value: TextLabel, rate: TextLabel, number: NumberValue }
export type Bar = { frame: GuiObject, fill: GuiObject, label: TextLabel }
export type Reply = { ok: boolean, message: string }
export type Tile = { button: TextButton, art: ImageLabel, icon: ImageLabel, label: TextLabel, dot: Frame }
export type Card = {
    frame: Frame,
    viewport: ViewportFrame,
    rarity: TextLabel,
    title: TextLabel,
    income: TextLabel,
    count: TextLabel,
    check: ImageLabel,
    dot: Frame,
}

-- Every uploaded image by name (ImageIds groups flattened), and source heights for SliceScale.
local ART: { [string]: string } = {}
for group, entries in ImageIds :: any do
    if group ~= "SliceCenter" then
        for name, id in entries do
            ART[name] = id
        end
    end
end
local SOURCE_HEIGHT: { [string]: number } = {
    panelTall = 896,
    panelWide = 780,
    panelSmall = 406,
    cardCream = 352,
    slotDark = 159,
    cardBrown = 227,
    buttonPriceGreen = 95,
    buttonPriceRed = 95,
    buttonSquareBlue = 159,
    tabSelected = 171,
    tabDeselected = 171,
    iconTile = 113,
    barTrack = 43,
    barFill = 21,
}

function Kit.art(name: string): string
    local id = ART[name]
    assert(id, "unknown image " .. name)
    return id
end

local function corner(object: GuiObject, radius: UDim)
    local c = Instance.new("UICorner")
    c.CornerRadius = radius
    c.Parent = object
end

local function stroke(object: GuiObject, color: Color3, thickness: number, border: boolean?): UIStroke
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness
    s.ApplyStrokeMode = if border then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual
    s.LineJoinMode = Enum.LineJoinMode.Round
    s.Parent = object
    return s
end

Kit.corner = corner
Kit.stroke = stroke

local PILL = UDim.new(0.5, 0)

function Kit.pop(object: GuiObject, peak: number?)
    Motion.pop(object, peak)
end

function Kit.shake(object: GuiObject)
    Motion.shake(object)
end

function Kit.frame(parent: Instance, name: string, color: Color3?): Frame
    local f = Instance.new("Frame")
    f.Name = name
    f.BorderSizePixel = 0
    f.BackgroundTransparency = if color then 0 else 1
    f.BackgroundColor3 = color or C.panel
    f.Parent = parent
    return f
end

-- Image by name (ImageIds). Sliced art gets SliceCenter and a SliceScale for `height` (reference px).
function Kit.image(parent: Instance, name: string, height: number?): ImageLabel
    local i = Instance.new("ImageLabel")
    i.Name = name
    i.BackgroundTransparency = 1
    i.Image = Kit.art(name)
    local center = (ImageIds.SliceCenter :: any)[name]
    if center then
        i.ScaleType = Enum.ScaleType.Slice
        i.SliceCenter = center
        local source = SOURCE_HEIGHT[name] or 170
        i.SliceScale = if height then math.clamp(height / source, 0.1, 1) else 0.5
    else
        i.ScaleType = Enum.ScaleType.Fit
    end
    i.Parent = parent
    return i
end

-- Fredoka text. HUD text gets the dark stroke (C6); pass strokeSize 0 for text on cream panels.
function Kit.text(
    parent: Instance,
    value: string,
    textSize: number,
    color: Color3?,
    font: Font?,
    strokeSize: number?
): TextLabel
    local t = Instance.new("TextLabel")
    t.Name = "Text"
    t.BackgroundTransparency = 1
    t.Text = value
    t.FontFace = font or Theme.Fonts.title
    t.TextColor3 = color or C.paper
    t.TextScaled = true
    t.Size = UDim2.new(1, 0, 0, math.ceil(textSize * 1.25))
    local limit = Instance.new("UITextSizeConstraint")
    limit.MaxTextSize = textSize
    limit.Parent = t
    local thickness = strokeSize or (if textSize >= 40 then Theme.Stroke.banner elseif textSize >= 24 then 3 else 2)
    if thickness > 0 then
        stroke(t, C.outline, thickness)
    end
    t.Parent = parent
    return t
end

-- Applies the screen's layout to one kit object (buttons keep 56 real px on phones; panels resize).
local function fit(object: Instance, info: Logic.LayoutInfo)
    if not object:IsA("GuiObject") then
        return
    end
    local base = object:GetAttribute("FLBaseHeight")
    if typeof(base) == "number" then
        object.Size = UDim2.new(object.Size.X, UDim.new(0, math.max(base, info.touchMin)))
    end
    if object:GetAttribute("FLPanel") then
        object.Size = UDim2.fromOffset(info.panelWidth, info.panelHeight)
    end
end

local function lane(root: Frame, name: string, bottom: boolean): Frame
    local f = Kit.frame(root, name)
    f.AnchorPoint = Vector2.new(0.5, if bottom then 1 else 0)
    f.AutomaticSize = Enum.AutomaticSize.Y
    f.ZIndex = 70 -- above panels, so purchase errors stay readable
    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.VerticalAlignment = if bottom then Enum.VerticalAlignment.Bottom else Enum.VerticalAlignment.Top
    list.Padding = UDim.new(0, Theme.Space.xs)
    list.Parent = f
    return f
end

-- Creates a ScreenGui in PlayerGui with a scaled root. Re-lays out whenever the real viewport changes.
function Kit.screen(name: string, displayOrder: number?): Screen
    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
    gui.DisplayOrder = displayOrder or 10

    local root = Kit.frame(gui, "Root")
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    root.Size = UDim2.fromScale(1, 1)
    local scale = Instance.new("UIScale")
    scale.Parent = root

    local screen: Screen = {
        gui = gui,
        root = root,
        scale = scale,
        toasts = lane(root, "Toasts", true),
        announce = lane(root, "Announce", false),
        banner = nil,
        goal = nil,
        info = Logic.layoutFor(1920, 1080),
        listeners = {},
        toastSerial = 0,
    }

    local function apply()
        -- Debug: player attribute FLDebugViewport (Vector2) lays the screen out at that size, centred and
        -- clipped, so phone screenshots can be taken in a PC window (docs/ai/client-v3-notes.md).
        local debugSize = Players.LocalPlayer:GetAttribute("FLDebugViewport")
        local emulated = typeof(debugSize) == "Vector2"
        local size = if emulated then debugSize else gui.AbsoluteSize
        if size.X <= 0 or size.Y <= 0 then
            return
        end
        local info = Logic.layoutFor(size.X, size.Y)
        screen.info = info
        scale.Scale = info.scale
        root.Size = if emulated
            then UDim2.fromOffset(size.X / info.scale, size.Y / info.scale)
            else UDim2.fromScale(1 / info.scale, 1 / info.scale)
        root.ClipsDescendants = emulated
        -- spec 2.1: objective (0.5, 0.10) PC / 0.12 phone, announce 0.17, gain lane 0.80 PC / 0.70 phone
        local bannerY = if info.compact then 0.12 else 0.10
        if screen.banner then
            screen.banner.Position = UDim2.fromScale(0.5, bannerY)
        end
        if screen.goal then
            screen.goal.Position = UDim2.new(0.5, 0, bannerY, 34)
        end
        screen.announce.Position = UDim2.new(0.5, 0, if info.compact then 0.12 else 0.10, 70)
        screen.announce.Size = UDim2.fromOffset(info.toastWidth, 0)
        screen.toasts.Position = UDim2.fromScale(0.5, if info.compact then 0.70 else 0.80)
        screen.toasts.Size = UDim2.fromOffset(info.toastWidth, 0)
        for _, d in root:GetDescendants() do
            fit(d, info)
        end
        for _, callback in screen.listeners do
            task.spawn(callback, info)
        end
    end

    root.DescendantAdded:Connect(function(d)
        fit(d, screen.info)
    end)
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
    Players.LocalPlayer:GetAttributeChangedSignal("FLDebugViewport"):Connect(apply)
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    apply()
    return screen
end

-- Calls back now and on every viewport change: use it to switch composition (info.compact = phone).
function Kit.onLayout(screen: Screen, callback: (Logic.LayoutInfo) -> ())
    table.insert(screen.listeners, callback)
    task.spawn(callback, screen.info)
end

-- Press / hover / release motion for any button (spec 4.1). `face` drops 4 px while pressed.
local function pressable(button: GuiButton, face: GuiObject?)
    local s = Motion.scale(button)
    local hovered, down = false, false
    local function rest()
        down = false
        Motion.play(s, "buttonRelease", { Scale = if hovered then 1.04 else 1 })
        if face then
            Motion.play(face, "buttonRelease", { Position = UDim2.new() })
        end
    end
    button.InputBegan:Connect(function(input)
        local kind = input.UserInputType
        if button:GetAttribute("FLRole") == "disabled" then
            return
        end
        if
            kind == Enum.UserInputType.MouseButton1
            or kind == Enum.UserInputType.Touch
            or input.KeyCode == Enum.KeyCode.ButtonA
        then
            down = true
            Motion.play(s, "buttonPress", { Scale = Motion.get("buttonPress").To.Scale or 0.94 })
            if face then
                Motion.play(face, "buttonPress", { Position = UDim2.fromOffset(0, 4) })
            end
        end
    end)
    button.InputEnded:Connect(function()
        if down then
            rest()
        end
    end)
    button.MouseEnter:Connect(function()
        if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
            return
        end
        hovered = true
        if not down then
            Motion.play(s, "buttonHover", { Scale = Motion.get("buttonHover").To.Scale or 1.04 })
        end
    end)
    button.MouseLeave:Connect(function()
        hovered = false
        rest()
    end)
end
Kit.pressable = pressable

-- Paints a button for a role: SunGraphica art where it exists, else code-drawn face on a darker base.
function Kit.setRole(button: TextButton, role: Theme.ButtonRole)
    local colors = Theme.Buttons[role]
    local artName = if Theme.UseArt then Theme.ButtonArt[role] else nil
    local art = button:FindFirstChild("Art") :: ImageLabel
    local face = button:FindFirstChild("Face") :: TextLabel
    local depth = if artName then 0 else Theme.ButtonDepth
    button:SetAttribute("FLRole", role)
    art.Visible = artName ~= nil
    if artName then
        art.Image = Kit.art(artName)
        art.SliceCenter = (ImageIds.SliceCenter :: any)[artName]
        local h = button:GetAttribute("FLBaseHeight")
        art.SliceScale = math.clamp((if typeof(h) == "number" then h else 64) / (SOURCE_HEIGHT[artName] or 170), 0.1, 1)
    end
    button.BackgroundTransparency = if artName then 1 else 0
    button.BackgroundColor3 = colors.base
    face.BackgroundTransparency = if artName then 1 else 0
    face.BackgroundColor3 = colors.face
    face.Size = UDim2.new(1, 0, 1, if artName then -6 else -depth)
    face.TextColor3 = colors.text
    local s = face:FindFirstChild("TextStroke") :: UIStroke
    s.Enabled = colors.text ~= C.ink
    s.Color = colors.base:Lerp(Color3.new(), 0.45)
    button.AutoButtonColor = false
end

-- 3D button: art (or code-drawn base + face), white Fredoka label with a dark stroke, press motion.
function Kit.button(parent: Instance, label: string, role: Theme.ButtonRole, size: UDim2): (TextButton, TextLabel)
    local button = Instance.new("TextButton")
    button.Name = label
    button.Text = ""
    button.BorderSizePixel = 0
    button.Size = size
    corner(button, UDim.new(0, Theme.Radius.button))
    if size.Y.Scale == 0 then
        button:SetAttribute("FLBaseHeight", size.Y.Offset)
    end
    local art = Instance.new("ImageLabel")
    art.Name = "Art"
    art.BackgroundTransparency = 1
    art.Size = UDim2.fromScale(1, 1)
    art.ScaleType = Enum.ScaleType.Slice
    art.Parent = button

    local face = Instance.new("TextLabel")
    face.Name = "Face"
    face.BorderSizePixel = 0
    face.Text = label
    face.FontFace = Theme.Fonts.title
    face.TextScaled = true
    face.ZIndex = 2
    corner(face, UDim.new(0, Theme.Radius.button))
    local limit = Instance.new("UITextSizeConstraint")
    limit.MaxTextSize = T.button
    limit.Parent = face
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, Theme.Space.lg)
    pad.PaddingRight = UDim.new(0, Theme.Space.lg)
    pad.PaddingTop = UDim.new(0, Theme.Space.sm)
    pad.PaddingBottom = UDim.new(0, Theme.Space.sm)
    pad.Parent = face
    local s = stroke(face, C.outline, 3)
    s.Name = "TextStroke"
    face.Parent = button
    Kit.setRole(button, role)

    local selection = stroke(button, C.outline, 0, true)
    button.SelectionGained:Connect(function()
        selection.Thickness = 3
        selection.Color = C.paper
    end)
    button.SelectionLost:Connect(function()
        selection.Thickness = 0
    end)
    pressable(button, face)
    button.Parent = parent
    return button, face
end

-- Square icon button on square art (buttonSquare*): icon 70 %, label used only when there is no icon.
local SQUARE_ART: { [string]: string } = {
    primary = "buttonSquareGreen",
    danger = "buttonSquareRed",
    reward = "buttonSquareYellow",
    info = "buttonSquareBlue",
}
function Kit.iconButton(
    parent: Instance,
    image: string,
    label: string,
    role: Theme.ButtonRole,
    side: number
): TextButton
    local button, face = Kit.button(parent, label, role, UDim2.fromOffset(side, side))
    button:SetAttribute("ActionLabel", label)
    local ratio = Instance.new("UIAspectRatioConstraint")
    ratio.DominantAxis = Enum.DominantAxis.Height -- stays square when the touch minimum grows the height
    ratio.Parent = button
    local square = SQUARE_ART[role]
    if Theme.UseArt and square then
        local art = button:FindFirstChild("Art") :: ImageLabel
        art.Visible = true
        art.Image = Kit.art(square)
        art.SliceCenter = (ImageIds.SliceCenter :: any)[square]
        art.SliceScale = side / 163
        button.BackgroundTransparency = 1
        face.BackgroundTransparency = 1
    end
    if image ~= "" then
        face.Text = ""
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.BackgroundTransparency = 1
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position = UDim2.fromScale(0.5, 0.5)
        icon.Size = UDim2.fromScale(0.7, 0.7)
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Image = image
        icon.ZIndex = 3
        icon.Parent = face
    end
    return button
end

-- Close button: the Gvesster close icon itself (a red square with an X), press motion, 56 px min touch.
function Kit.closeButton(parent: Instance, side: number): ImageButton
    local b = Instance.new("ImageButton")
    b.Name = "Close"
    b.BackgroundTransparency = 1
    b.Image = Theme.Images.close
    b.ScaleType = Enum.ScaleType.Fit
    b.Size = UDim2.fromOffset(side, side)
    b.ZIndex = 8
    b:SetAttribute("FLBaseHeight", side)
    local ratio = Instance.new("UIAspectRatioConstraint")
    ratio.DominantAxis = Enum.DominantAxis.Height
    ratio.Parent = b
    pressable(b, nil)
    b.Parent = parent
    return b
end

-- Notification dot (spec 4.7): red circle, white rim, count or "!", pulses while shown.
function Kit.dot(parent: Instance): Frame
    local d = Kit.frame(parent, "Dot", C.danger)
    d.AnchorPoint = Vector2.new(0.5, 0.5)
    d.Position = UDim2.fromScale(1, 0)
    d.Size = UDim2.fromOffset(34, 34)
    d.ZIndex = 9
    d.Visible = false
    corner(d, PILL)
    stroke(d, C.paper, 3, true)
    local t = Kit.text(d, "", 22, C.paper, nil, 2)
    t.Name = "Count"
    t.Size = UDim2.fromScale(1, 1)
    t.ZIndex = 10
    return d
end

local pulses: { [Frame]: () -> () } = {}
-- n > 0 shows the count, "!" shows the exclamation, nil / 0 hides it.
function Kit.setDot(dot: Frame, n: number | string | nil)
    local show = n ~= nil and n ~= 0
    local count = dot:FindFirstChild("Count") :: TextLabel
    count.Text = if show then tostring(n) else ""
    if show and not dot.Visible then
        dot.Visible = true
        Motion.scaleTo(dot, "newButton")
        local stop = pulses[dot]
        if stop then
            stop()
        end
        task.delay(0.35, function()
            if dot.Visible then
                pulses[dot] = Motion.pulse(dot)
            end
        end)
    elseif not show and dot.Visible then
        dot.Visible = false
        local stop = pulses[dot]
        if stop then
            stop()
            pulses[dot] = nil
        end
    end
end

-- HUD menu tile (spec 2.2): blue square art, icon overhanging the top, label on the bottom edge, dot.
function Kit.menuTile(parent: Instance, label: string, image: string): Tile
    local button = Instance.new("TextButton")
    button.Name = label
    button.Text = ""
    button.AutoButtonColor = false
    button.BackgroundColor3 = C.info
    button.BackgroundTransparency = if Theme.UseArt then 1 else 0
    button.Size = UDim2.fromOffset(104, 104)
    corner(button, UDim.new(0, 20))
    if not Theme.UseArt then
        stroke(button, C.outline, 4, true)
    end
    local art = Kit.image(button, "buttonSquareBlue", 104)
    art.Name = "Art"
    art.Size = UDim2.fromScale(1, 1)
    art.Visible = Theme.UseArt
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.BackgroundTransparency = 1
    icon.Image = image
    icon.ScaleType = Enum.ScaleType.Fit
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.new(0.5, 0, 0.5, -20) -- overhangs the top edge by ~10 px (spec 2.2)
    icon.Size = UDim2.fromOffset(92, 92)
    icon.ZIndex = 2
    icon.Parent = button
    local text = Kit.text(button, label, 26, C.paper, nil, 3)
    text.Name = "Label"
    text.AnchorPoint = Vector2.new(0.5, 0.5)
    text.Position = UDim2.fromScale(0.5, 1)
    text.Size = UDim2.fromOffset(124, 32)
    text.ZIndex = 3
    local dot = Kit.dot(button)
    pressable(button, nil)
    button.Parent = parent
    return { button = button, art = art, icon = icon, label = text, dot = dot }
end

-- Open state while its panel is shown: darker body, icon 1.08.
function Kit.setTileOpen(tile: Tile, open: boolean)
    tile.art.ImageColor3 = if open then Color3.fromHex("B4B4B4") else Color3.new(1, 1, 1)
    Motion.play(Motion.scale(tile.icon), "tabSwitch", { Scale = if open then 1.08 else 1 })
end

-- Shows a tile that just unlocked: scale 0 -> 1.15 -> 1 (spec 5 "New HUD button").
function Kit.revealTile(tile: Tile)
    Motion.scaleTo(tile.button, "newButton")
end

-- Tutorial pointer (spec 4.6): cursor image at the target's lower-right, bobbing toward it.
-- `fromLeft` puts it at the lower-left, turned to point up-right (tiles on the right screen edge).
function Kit.pointer(target: GuiObject, fromLeft: boolean?): ImageLabel
    local p = Instance.new("ImageLabel")
    p.Name = "Pointer"
    p.BackgroundTransparency = 1
    p.Image = Kit.art("cursor")
    p.ScaleType = Enum.ScaleType.Fit
    p.Size = UDim2.fromOffset(72, 72)
    p.AnchorPoint = Vector2.new(if fromLeft then 1 else 0, 0)
    p.Position = if fromLeft then UDim2.new(0, 12, 1, -12) else UDim2.new(1, -12, 1, -12)
    p.Rotation = if fromLeft then 90 else 0
    p.ZIndex = 12
    p.Visible = false
    p.Parent = target
    Motion.bob(p, "arrowBob", Vector2.new(if fromLeft then 0.7 else -0.7, -0.7))
    return p
end

-- Objective line (spec 2.4): old line fades up, new line pops in. nil hides it.
function Kit.banner(screen: Screen, value: string): TextLabel
    local banner = screen.banner
    local y = if screen.info.compact then 0.12 else 0.10
    if not banner then
        local b = Kit.text(screen.root, value, T.banner, C.paper, nil, Theme.Stroke.banner)
        b.Name = "Banner"
        b.AnchorPoint = Vector2.new(0.5, 0.5)
        b.Size = UDim2.new(0.7, 0, 0, 52)
        b.ZIndex = 20
        local limit = b:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint
        limit.MinTextSize = 28
        screen.banner = b
        banner = b
    elseif banner.Text ~= value and banner.Visible and not Motion.reduced() then
        local ghost = banner:Clone()
        ghost.Name = "BannerOut"
        ghost.Parent = screen.root
        Motion.play(ghost, "objectiveOut", { Position = ghost.Position + UDim2.fromOffset(0, -10) })
        Motion.fadeOut(ghost, "objectiveOut", true)
    end
    assert(banner, "Banner")
    banner.Text = value
    banner.Position = UDim2.fromScale(0.5, y)
    Motion.scaleTo(banner, "objectiveIn")
    return banner
end

-- Count goal under the objective ("52 / 80"): mini bar 220 x 14 (spec 2.4). nil target hides it.
function Kit.bannerGoal(screen: Screen, current: number?, target: number?)
    local goal = screen.goal
    if not goal then
        local g = Kit.frame(screen.root, "Goal")
        g.AnchorPoint = Vector2.new(0.5, 0)
        g.Size = UDim2.fromOffset(330, 28)
        g.ZIndex = 20
        local bar = Kit.progressBar(g, UDim2.fromOffset(220, 18), nil)
        bar.frame.Name = "Bar"
        bar.label.Visible = false
        local text = Kit.text(g, "", 22, C.paper, nil, 2)
        text.Name = "Count"
        text.AnchorPoint = Vector2.new(0, 0.5)
        text.Position = UDim2.new(0, 230, 0.5, 0)
        text.Size = UDim2.fromOffset(100, 26)
        text.TextXAlignment = Enum.TextXAlignment.Left
        screen.goal = g
        goal = g
    end
    assert(goal, "Goal")
    goal.Position = UDim2.new(0.5, 0, if screen.info.compact then 0.12 else 0.10, 34)
    goal.Visible = current ~= nil and target ~= nil
    if current and target then
        local bar = goal:FindFirstChild("Bar") :: GuiObject
        local fill = bar:FindFirstChild("Fill", true) :: GuiObject -- inside "Inner" when drawn with art
        Motion.play(fill, "fill", { Size = UDim2.fromScale(math.clamp(current / target, 0, 1), 1) })
        local count = goal:FindFirstChild("Count") :: TextLabel
        count.Text = Logic.formatNumber(math.min(current, target)) .. " / " .. Logic.formatNumber(target)
    end
end

-- Toasts (spec 4.8): gain / error text above the hotbar, announce text under the objective. No background.
local TOAST_COLORS: { [string]: Color3 } = { gain = C.money, error = C.danger, announce = C.announce }
function Kit.toast(screen: Screen, message: string, kind: "gain" | "error" | "announce")
    local target = if kind == "announce" then screen.announce else screen.toasts
    screen.toastSerial += 1
    local size = if kind == "announce" then T.heading else T.button
    local label = Kit.text(target, message, size, TOAST_COLORS[kind], nil, 3)
    label.Name = "Toast"
    label.LayoutOrder = screen.toastSerial
    label.TextScaled = false
    label.TextSize = size
    label.TextWrapped = true
    label.Size = UDim2.fromScale(1, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.ZIndex = 70
    Motion.scaleTo(label, "toastIn")

    local shown: { TextLabel } = {}
    for _, child in target:GetChildren() do
        if child:IsA("TextLabel") then
            table.insert(shown, child)
        end
    end
    table.sort(shown, function(a, b)
        return a.LayoutOrder < b.LayoutOrder
    end)
    for i = 1, #shown - 2 do -- max 2 lines per lane; the new one pushes the old one up
        shown[i]:Destroy()
    end
    local hold = if kind == "announce" then 4 else 2 -- spec 4.8; the toastOut preset may carry part of it
    task.delay(math.max(0, hold - Motion.get("toastOut").Delay), function()
        if label.Parent then
            Motion.fadeOut(label, "toastOut", true)
        end
    end)
end

-- Shows a server reply ({ok, message} handler shape from MAIN_PLAN) as a toast.
function Kit.toastReply(screen: Screen, reply: Reply)
    if reply.message ~= "" then
        Kit.toast(screen, reply.message, if reply.ok then "gain" else "error")
    end
end

-- Panel manager: one panel open at a time behind a shade + blur 18 (spec 3.1, motion spec 5).
function Kit.panels(screen: Screen): Panels
    local shade = Kit.frame(screen.root, "MenuShade", C.shade)
    shade.Size = UDim2.fromScale(1, 1)
    shade.BackgroundTransparency = 1
    shade.Visible = false
    shade.Active = true -- swallows clicks to the HUD below
    shade.ZIndex = 50
    local blur = Lighting:FindFirstChild("FLMenuBlur") :: BlurEffect?
    if not blur then
        local b = Instance.new("BlurEffect")
        b.Name = "FLMenuBlur"
        b.Size = 0
        b.Enabled = false
        b.Parent = Lighting
        blur = b
    end
    assert(blur, "FLMenuBlur")
    return { state = Logic.newPanelState(), frames = {}, shade = shade, blur = blur, serial = 0, listeners = {} }
end

-- Called with the open panel's name, or nil when none is open (HUD columns slide away, tiles darken).
function Kit.onPanel(panels: Panels, callback: (string?) -> ())
    table.insert(panels.listeners, callback)
end

local function notify(panels: Panels)
    for _, cb in panels.listeners do
        task.spawn(cb, panels.state.open)
    end
end

local function setFocus(panels: Panels, visible: boolean)
    panels.serial += 1
    local version = panels.serial
    if visible then
        panels.shade.Visible = true
        panels.blur.Enabled = true
        Motion.play(panels.shade, "shadeIn", { BackgroundTransparency = 0.6 })
        Motion.play(panels.blur, "shadeIn", { Size = 18 })
    else
        Motion.play(panels.shade, "shadeOut", { BackgroundTransparency = 1 })
        Motion.play(panels.blur, "shadeOut", { Size = 0 })
        task.delay(Motion.get("shadeOut").Time + 0.01, function()
            if version == panels.serial then
                panels.shade.Visible = false
                panels.blur.Enabled = false
            end
        end)
    end
end

local function closeFrame(frame: Frame)
    local t = Motion.scaleTo(frame, "panelClose")
    if t then
        t.Completed:Connect(function(state)
            if state == Enum.PlaybackState.Completed then
                frame.Visible = false
            end
        end)
    else
        frame.Visible = false
    end
end

function Kit.showPanel(panels: Panels, name: string)
    local frame = panels.frames[name]
    assert(frame, "unknown panel " .. name)
    local previous = Logic.openPanel(panels.state, name)
    if previous then
        panels.frames[previous].Visible = false
    end
    if not frame.Visible or previous then
        frame.Visible = true
        Motion.scaleTo(frame, "panelOpen")
    end
    frame.Visible = true
    setFocus(panels, true)
    notify(panels)
end

function Kit.hidePanel(panels: Panels, name: string)
    if Logic.closePanel(panels.state, name) then
        closeFrame(panels.frames[name])
        setFocus(panels, false)
        notify(panels)
    end
end

-- Panel shell (spec 3.1): cream body with a dark rim, ribbon title on the top edge with the menu icon
-- overhanging its left end, close button overhanging the top-right corner. Returns (panel, body).
function Kit.shell(screen: Screen, panels: Panels, name: string, title: string, icon: string?): (Frame, Frame)
    local panel = Kit.frame(screen.root, name)
    panel:SetAttribute("FLPanel", true)
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.new(0.5, 0, 0.5, 24)
    panel.Visible = false
    panel.ZIndex = 60
    fit(panel, screen.info)

    local rim = Kit.frame(panel, "Rim", C.outline)
    rim.AnchorPoint = Vector2.new(0.5, 0.5)
    rim.Position = UDim2.fromScale(0.5, 0.5)
    rim.Size = UDim2.new(1, 8, 1, 8)
    rim.ZIndex = 60
    corner(rim, UDim.new(0, Theme.Radius.panel + 2))
    local bodyArt: GuiObject
    if Theme.UseArt then
        local art = Kit.image(panel, "panelWide")
        art.SliceScale = 0.45
        bodyArt = art
    else
        local f = Kit.frame(panel, "panelWide", C.panelBody)
        corner(f, UDim.new(0, Theme.Radius.panel))
        bodyArt = f
    end
    bodyArt.Name = "BodyArt"
    bodyArt.Size = UDim2.fromScale(1, 1)
    bodyArt.ZIndex = 61

    -- Ribbon: 60 % of the body width (max 520), 0.35 of it above the top edge
    local ribbonW = 520
    local ribbonH = math.floor(ribbonW * 181 / 524)
    local ribbon: GuiObject
    if Theme.UseArt then
        local r = Kit.image(panel, Theme.Ribbons[name] or "headerBlue")
        r.ScaleType = Enum.ScaleType.Fit
        ribbon = r
    else
        local f = Kit.frame(panel, "Ribbon", Theme.Buttons.info.face)
        corner(f, UDim.new(0, Theme.Radius.button))
        stroke(f, C.outline, 4, true)
        ribbon = f
    end
    ribbon.Name = "Ribbon"
    ribbon.AnchorPoint = Vector2.new(0.5, 0)
    ribbon.Position = UDim2.new(0.5, 0, 0, -math.floor(ribbonH * 0.35))
    ribbon.Size = UDim2.fromOffset(ribbonW, if Theme.UseArt then ribbonH else 80)
    ribbon.ZIndex = 64
    local heading = Kit.text(ribbon, title, T.title, C.paper, nil, Theme.Stroke.banner)
    heading.Name = "Title"
    heading.AnchorPoint = Vector2.new(0.5, 0.5)
    heading.Position = UDim2.fromScale(0.5, if Theme.UseArt then 0.47 else 0.5)
    heading.Size = UDim2.new(0.7, 0, 0, 56)
    heading.ZIndex = 65

    if icon then
        local i = Instance.new("ImageLabel")
        i.Name = "MenuIcon"
        i.BackgroundTransparency = 1
        i.Image = icon
        i.ScaleType = Enum.ScaleType.Fit
        i.AnchorPoint = Vector2.new(0.5, 0.5)
        i.Position = UDim2.new(0, 40, 0.5, -4)
        i.Size = UDim2.fromOffset(110, 110)
        i.Rotation = -8
        i.ZIndex = 66
        i.Parent = ribbon
    end

    local close = Kit.closeButton(panel, 72)
    close.AnchorPoint = Vector2.new(0.5, 0.5)
    close.Position = UDim2.new(1, -12, 0, 12)
    close.ZIndex = 67
    close.Activated:Connect(function()
        Kit.hidePanel(panels, name)
    end)

    local top = math.floor(ribbonH * 0.65) + Theme.Space.md
    local body = Kit.frame(panel, "Body")
    body.Position = UDim2.fromOffset(Theme.Space.xl, top)
    body.Size = UDim2.new(1, -2 * Theme.Space.xl, 1, -(top + Theme.Space.xl))
    body.ClipsDescendants = true
    body.ZIndex = 62

    panels.frames[name] = panel
    return panel, body
end

-- Scrolling content area on the cream body (spec 3.1: 8 px bar in panelRim, vertical only).
function Kit.scroll(parent: Instance): ScrollingFrame
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Scroll"
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Size = UDim2.fromScale(1, 1)
    scroll.CanvasSize = UDim2.new()
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    scroll.ScrollBarThickness = 8
    scroll.ScrollBarImageColor3 = C.panelRim
    scroll.ScrollBarImageTransparency = 0
    scroll.ZIndex = 62
    scroll.Parent = parent
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 14) -- room for card dots and press scale
    pad.PaddingLeft = UDim.new(0, 6)
    pad.PaddingRight = UDim.new(0, 14)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = scroll
    return scroll
end

-- Currency row without a pill (spec 2.3): icon 52, white stroked number 38 with a soft shadow, rate line.
function Kit.currencyPill(parent: Instance, image: string, _color: Color3?): Pill
    local frame = Kit.frame(parent, "CurrencyRow")
    frame.Size = UDim2.fromOffset(260, 52)
    local i = Instance.new("ImageLabel")
    i.Name = "Icon"
    i.BackgroundTransparency = 1
    i.Image = image
    i.ScaleType = Enum.ScaleType.Fit
    i.Size = UDim2.fromOffset(52, 52)
    i.Parent = frame
    local shadow = Kit.text(frame, "0", T.number, C.outline, nil, 0)
    shadow.Name = "Shadow"
    shadow.TextTransparency = 0.5
    local value = Kit.text(frame, "0", T.number, C.paper, nil, 3)
    value.Name = "Value"
    for _, t in { shadow, value } do
        t.AnchorPoint = Vector2.new(0, 0.5)
        t.Size = UDim2.new(1, -60, 0, 46)
        t.TextXAlignment = Enum.TextXAlignment.Left
    end
    value.Position = UDim2.new(0, 60, 0.5, 0)
    shadow.Position = UDim2.new(0, 60, 0.5, 3)
    value:GetPropertyChangedSignal("Text"):Connect(function()
        shadow.Text = value.Text
    end)
    local rate = Kit.text(frame, "", T.body, C.money, nil, 2)
    rate.Name = "Rate"
    rate.Position = UDim2.new(0, 60, 1, -4)
    rate.Size = UDim2.new(1, -60, 0, 24)
    rate.TextXAlignment = Enum.TextXAlignment.Left
    local number = Instance.new("NumberValue")
    number.Parent = frame
    number.Changed:Connect(function(v)
        value.Text = Logic.formatNumber(v)
    end)
    return { frame = frame, icon = i, value = value, rate = rate, number = number }
end

-- Rolls the number to the new value and pops the icon (or snaps when animate is false).
function Kit.setPillValue(pill: Pill, amount: number, animate: boolean?)
    if animate == false then
        pill.number.Value = amount
        pill.value.Text = Logic.formatNumber(amount)
        return
    end
    if amount == pill.number.Value then
        return
    end
    local big = math.abs(amount - pill.number.Value) > math.max(10, pill.number.Value * 0.05)
    Motion.roll(pill.number, amount, if big then "counterRoll" else "numberRoll")
    if big then
        Motion.pop(pill.icon, 1.15)
    end
end

function Kit.setPillRate(pill: Pill, perSecond: number)
    pill.rate.Text = if perSecond > 0 then "+" .. Logic.formatNumber(perSecond) .. "/s" else ""
end

-- Coins fly from an absolute screen point to the pill icon; the icon pops on each arrival.
function Kit.coinBurst(screen: Screen, pill: Pill, from: Vector2, count: number?)
    local root = screen.root
    local function toRoot(p: Vector2): Vector2
        return (p - root.AbsolutePosition) / screen.scale.Scale
    end
    local finish = toRoot(pill.icon.AbsolutePosition + pill.icon.AbsoluteSize / 2)
    Motion.fly(root, pill.icon.Image, toRoot(from), finish, count or 14, function()
        Motion.pop(pill.icon, 1.15)
    end)
end

-- Progress bar (spec 4.3): barTrack art with the barFill art inside (4 px padding), centred label.
-- `color` tints the fill (SunGraphica art may be tinted); nil keeps the green art.
function Kit.progressBar(parent: Instance, size: UDim2, color: Color3?): Bar
    local frame: GuiObject
    local fill: GuiObject
    if Theme.UseArt then
        local track = Kit.image(parent, "barTrack", if size.Y.Scale == 0 then size.Y.Offset else 40)
        track.Name = "ProgressBar"
        frame = track
        local inner = Kit.frame(track, "Inner")
        inner.Position = UDim2.fromOffset(4, 4)
        inner.Size = UDim2.new(1, -8, 1, -8)
        inner.ClipsDescendants = true
        local f = Kit.image(inner, "barFill", if size.Y.Scale == 0 then size.Y.Offset - 8 else 32)
        f.Name = "Fill"
        if color then
            f.ImageColor3 = color
        end
        fill = f
    else
        local track = Kit.frame(parent, "ProgressBar", C.track)
        corner(track, PILL)
        stroke(track, C.outline, 3, true)
        frame = track
        local f = Kit.frame(track, "Fill", color or C.money)
        corner(f, PILL)
        fill = f
    end
    frame.Size = size
    fill.Size = UDim2.fromScale(0, 1)
    local label = Kit.text(frame, "", 22, C.paper, nil, 2)
    label.Name = "Label"
    label.Size = UDim2.fromScale(1, 1)
    label.ZIndex = 4
    return { frame = frame, fill = fill, label = label }
end

function Kit.setProgress(bar: Bar, fraction: number, text: string?)
    Motion.play(bar.fill, "fill", { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) })
    if text then
        bar.label.Text = text
    end
end

local RAINBOW = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromHex("FF4B4B")),
    ColorSequenceKeypoint.new(0.2, Color3.fromHex("FFC800")),
    ColorSequenceKeypoint.new(0.4, Color3.fromHex("5BD45B")),
    ColorSequenceKeypoint.new(0.6, Color3.fromHex("3BA7FF")),
    ColorSequenceKeypoint.new(0.8, Color3.fromHex("B65CFF")),
    ColorSequenceKeypoint.new(1, Color3.fromHex("FF4B6E")),
})
Kit.RAINBOW = RAINBOW

-- Rarity word in its colour (always the word, never colour alone); Secret gets a spinning rainbow.
function Kit.rarityLabel(parent: Instance, rarity: string, textSize: number?): TextLabel
    local color = (Theme.Rarity :: { [string]: Color3 })[rarity]
    assert(color, "unknown rarity " .. rarity)
    local size = textSize or T.heading
    local label = Kit.text(parent, string.upper(rarity), size, color)
    label.Name = "Rarity"
    label.TextScaled = false
    label.TextSize = size
    label.AutomaticSize = Enum.AutomaticSize.X
    label.Size = UDim2.fromOffset(0, label.Size.Y.Offset)
    if rarity == "Secret" then
        local gradient = Instance.new("UIGradient")
        gradient.Color = RAINBOW
        gradient.Parent = label
        Motion.spin(gradient, 3)
    end
    return label
end

-- Rarity card (spec 3.2): whole card in the rarity colour, lighter top, dark rim, model viewport,
-- rarity word, income chip, count, equipped check, dot. `hidden` = undiscovered silhouette with "???".
function Kit.rarityCard(parent: Instance, rarity: string, hidden: boolean?): Card
    local color = (Theme.Rarity :: { [string]: Color3 })[rarity] or C.disabled
    local frame = Kit.frame(parent, "Card", if hidden then Color3.fromHex("6B6B6B") else color)
    frame.Size = UDim2.fromOffset(150, 170)
    corner(frame, UDim.new(0, Theme.Radius.card))
    stroke(frame, C.outline, Theme.Stroke.card, true)
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = if rarity == "Secret" and not hidden
        then RAINBOW
        else ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.8, 0.8, 0.8))
    gradient.Parent = frame
    if rarity == "Secret" and not hidden then
        Motion.spin(gradient, 4)
    end
    local vp = Instance.new("ViewportFrame")
    vp.Name = "Model"
    vp.BackgroundTransparency = 1
    vp.AnchorPoint = Vector2.new(0.5, 0)
    vp.Position = UDim2.new(0.5, 0, 0, 10)
    vp.Size = UDim2.fromOffset(110, 100)
    vp.Ambient = if hidden then Color3.new() else Color3.fromRGB(200, 200, 200)
    vp.LightColor = if hidden then Color3.new() else Color3.new(1, 1, 1)
    vp.ImageColor3 = if hidden then Color3.new() else Color3.new(1, 1, 1)
    vp.Parent = frame
    local title = Kit.text(frame, if hidden then "???" else "", 22, C.paper, nil, 2)
    title.Name = "Title"
    title.AnchorPoint = Vector2.new(0.5, 1)
    title.Position = UDim2.new(0.5, 0, 1, -26)
    title.Size = UDim2.new(1, -10, 0, 26)
    local word = Kit.text(frame, string.upper(rarity), 18, C.paper, nil, 2)
    word.Name = "Rarity"
    word.AnchorPoint = Vector2.new(0.5, 1)
    word.Position = UDim2.new(0.5, 0, 1, -6)
    word.Size = UDim2.new(1, -10, 0, 22)
    local chip = Kit.frame(frame, "Income", Color3.new())
    chip.BackgroundTransparency = 0.5
    chip.Position = UDim2.fromOffset(6, 6)
    chip.AutomaticSize = Enum.AutomaticSize.X
    chip.Size = UDim2.fromOffset(0, 24)
    chip.Visible = false
    corner(chip, PILL)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 6)
    pad.PaddingRight = UDim.new(0, 6)
    pad.Parent = chip
    local income = Kit.text(chip, "", 18, C.money, nil, 2)
    income.TextScaled = false
    income.TextSize = 18
    income.AutomaticSize = Enum.AutomaticSize.X
    income.Size = UDim2.fromOffset(0, 24)
    income:GetPropertyChangedSignal("Text"):Connect(function()
        chip.Visible = income.Text ~= ""
    end)
    local count = Kit.text(frame, "", 20, C.paper, nil, 2)
    count.Name = "Count"
    count.AnchorPoint = Vector2.new(1, 1)
    count.Position = UDim2.new(1, -6, 1, -26)
    count.Size = UDim2.fromOffset(40, 24)
    count.TextXAlignment = Enum.TextXAlignment.Right
    local check = Kit.image(frame, "check")
    check.AnchorPoint = Vector2.new(0.5, 0.5)
    check.Position = UDim2.new(1, -6, 0, 6) -- top-right: the income chip owns the top-left
    check.Size = UDim2.fromOffset(36, 36)
    check.ZIndex = 8
    check.Visible = false
    local dot = Kit.dot(frame)
    return {
        frame = frame,
        viewport = vp,
        rarity = word,
        title = title,
        income = income,
        count = count,
        check = check,
        dot = dot,
    }
end

-- "+X" that floats up and fades (GlassPanels floatNumber), then removes itself.
function Kit.floatingNumber(parent: Instance, value: string, color: Color3, position: UDim2)
    local label = Kit.text(parent, value, T.button, color, nil, 3)
    label.Name = "FloatingNumber"
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Size = UDim2.fromOffset(220, 40)
    label.Position = position
    label.ZIndex = 75
    Motion.scaleTo(label, "toastIn")
    Motion.float(label)
end

return Kit
