--!strict
-- Feed and Lay UI kit: Luau port of Bobux Gang src/client/ui.ts (see docs/ai/design-v3.md 7.1, 7.2 and 8).
-- Every screen is built with these helpers; colours and sizes come from Theme only.
-- Offsets are reference pixels at 1080p: Kit.screen puts one UIScale on a root frame sized to the screen.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Logic = require(script.Parent.Logic)
local Theme = require(script.Parent.Theme)

local C = Theme.Colors
local Kit = {}

export type Screen = {
    gui: ScreenGui,
    root: Frame,
    scale: UIScale,
    toasts: Frame,
    banner: TextLabel?,
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
}

export type Pill = { frame: Frame, icon: ImageLabel, value: TextLabel, rate: TextLabel, number: NumberValue }
export type Bar = { frame: Frame, fill: Frame, label: TextLabel }
export type Reply = { ok: boolean, message: string }

local function tween(
    target: Instance,
    seconds: number,
    goal: { [string]: any },
    style: Enum.EasingStyle?,
    direction: Enum.EasingDirection?
): Tween
    local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
    local t = TweenService:Create(target, info, goal)
    t:Play()
    return t
end
Kit.tween = tween

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
    s.Parent = object
    return s
end

local PILL = UDim.new(0.5, 0)
local BUTTON_RADIUS = UDim.new(0, Theme.Radius.button)

-- Scale 1 -> peak -> 1 with a springy settle (reward pop, counter bump, banner change).
function Kit.pop(object: GuiObject, peak: number?)
    local scale = object:FindFirstChild("PopScale") :: UIScale?
    if not scale then
        local s = Instance.new("UIScale")
        s.Name = "PopScale"
        s.Parent = object
        scale = s
    end
    assert(scale, "PopScale")
    scale.Scale = peak or 1.15
    tween(scale, Theme.Motion.pop, { Scale = 1 }, Enum.EasingStyle.Back)
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

-- Fredoka text with the dark "paper" stroke. Sized by the caller; TextScaled keeps long text inside its box.
function Kit.text(parent: Instance, value: string, textSize: number, color: Color3?, font: Font?): TextLabel
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
    stroke(t, C.outline, if textSize >= 28 then Theme.Stroke.text else 2)
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

    local toasts = Kit.frame(root, "Toasts")
    toasts.AnchorPoint = Vector2.new(0.5, 0)
    toasts.AutomaticSize = Enum.AutomaticSize.Y
    toasts.ZIndex = 70 -- above panels, so purchase errors stay readable
    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.Padding = UDim.new(0, Theme.Space.sm)
    list.Parent = toasts

    local screen: Screen = {
        gui = gui,
        root = root,
        scale = scale,
        toasts = toasts,
        banner = nil,
        info = Logic.layoutFor(1920, 1080),
        listeners = {},
        toastSerial = 0,
    }

    local function apply()
        local size = gui.AbsoluteSize
        if size.X <= 0 or size.Y <= 0 then
            return
        end
        local info = Logic.layoutFor(size.X, size.Y)
        screen.info = info
        scale.Scale = info.scale
        root.Size = UDim2.fromScale(1 / info.scale, 1 / info.scale)
        -- Phone banner sits higher than the spec's 0.12 so it clears the top-left Coins counter.
        local bannerY = if info.compact then 0.05 else 0.10
        if screen.banner then
            screen.banner.Position = UDim2.fromScale(0.5, bannerY)
        end
        toasts.Position = UDim2.fromScale(0.5, if info.compact then 0.20 else 0.15)
        toasts.Size = UDim2.fromOffset(info.toastWidth, 0)
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
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    apply()
    return screen
end

-- Calls back now and on every viewport change: use it to switch composition (info.compact = phone).
function Kit.onLayout(screen: Screen, callback: (Logic.LayoutInfo) -> ())
    table.insert(screen.listeners, callback)
    task.spawn(callback, screen.info)
end

-- 3D button: darker base strip, face on top. Press: face drops and the button shrinks; hover brightens.
function Kit.button(parent: Instance, label: string, role: Theme.ButtonRole, size: UDim2): (TextButton, TextLabel)
    local colors = Theme.Buttons[role]
    local depth = Theme.ButtonDepth
    local button = Instance.new("TextButton")
    button.Name = label
    button.Text = ""
    button.AutoButtonColor = false
    button.BorderSizePixel = 0
    button.BackgroundColor3 = colors.base
    button.Size = size
    corner(button, BUTTON_RADIUS)
    if size.Y.Scale == 0 then
        button:SetAttribute("FLBaseHeight", size.Y.Offset)
    end
    local selection = stroke(button, C.outline, 3, true)

    local face = Instance.new("TextLabel")
    face.Name = "Face"
    face.Size = UDim2.new(1, 0, 1, -depth)
    face.BorderSizePixel = 0
    face.BackgroundColor3 = colors.face
    face.Text = label
    face.FontFace = Theme.Fonts.title
    face.TextColor3 = colors.text
    face.TextScaled = true
    corner(face, BUTTON_RADIUS)
    local limit = Instance.new("UITextSizeConstraint")
    limit.MaxTextSize = Theme.TextSize.heading
    limit.Parent = face
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, Theme.Space.md)
    pad.PaddingRight = UDim.new(0, Theme.Space.md)
    pad.PaddingTop = UDim.new(0, Theme.Space.sm)
    pad.PaddingBottom = UDim.new(0, Theme.Space.sm)
    pad.Parent = face
    if colors.text == C.paper then
        stroke(face, C.outline, 2)
    end
    face.Parent = button

    local press = Instance.new("UIScale")
    press.Name = "PressScale"
    press.Parent = button
    local hovered = false
    local function release()
        tween(press, Theme.Motion.release, { Scale = 1 }, Enum.EasingStyle.Back)
        tween(face, Theme.Motion.release, { Position = UDim2.new() })
    end
    button.InputBegan:Connect(function(input)
        local kind = input.UserInputType
        if
            kind == Enum.UserInputType.MouseButton1
            or kind == Enum.UserInputType.Touch
            or input.KeyCode == Enum.KeyCode.ButtonA
        then
            tween(press, Theme.Motion.press, { Scale = 0.94 })
            tween(face, Theme.Motion.press, { Position = UDim2.fromOffset(0, depth) })
        end
    end)
    button.InputEnded:Connect(release)
    button.MouseEnter:Connect(function()
        hovered = true
        tween(face, Theme.Motion.hover, { BackgroundColor3 = colors.face:Lerp(C.paper, 0.12) })
    end)
    button.MouseLeave:Connect(function()
        if hovered then
            hovered = false
            tween(face, Theme.Motion.hover, { BackgroundColor3 = colors.face })
        end
        release()
    end)
    button.SelectionGained:Connect(function()
        selection.Color = C.paper
    end)
    button.SelectionLost:Connect(function()
        selection.Color = C.outline
    end)
    button.Parent = parent
    return button, face
end

-- Square icon button. With a placeholder image ("") the label text is shown instead.
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
    if image ~= "" then
        face.Text = ""
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.BackgroundTransparency = 1
        icon.Size = UDim2.fromScale(1, 1)
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Image = image
        icon.Parent = face
    end
    return button
end

local function icon(parent: Instance, image: string, fallback: Color3, side: number): ImageLabel
    local i = Instance.new("ImageLabel")
    i.Name = "Icon"
    i.Image = image
    i.ScaleType = Enum.ScaleType.Fit
    i.Size = UDim2.fromOffset(side, side)
    i.BorderSizePixel = 0
    i.BackgroundColor3 = fallback
    i.BackgroundTransparency = if image == "" then 0 else 1 -- coloured disc until art is uploaded
    corner(i, PILL)
    if image == "" then
        stroke(i, C.outline, 3, true)
    end
    i.Parent = parent
    return i
end

-- Objective banner (top-centre, no panel). Calling again changes the text with a pop.
function Kit.banner(screen: Screen, value: string): TextLabel
    local banner = screen.banner
    if not banner then
        local b = Kit.text(screen.root, value, Theme.TextSize.title)
        b.Name = "Banner"
        b.AnchorPoint = Vector2.new(0.5, 0.5)
        b.Size = UDim2.new(0.9, 0, 0, 56)
        screen.banner = b
        banner = b
    end
    assert(banner, "Banner")
    banner.Text = value
    banner.Position = UDim2.fromScale(0.5, if screen.info.compact then 0.05 else 0.10)
    Kit.pop(banner, 0.6)
    return banner
end

local TOAST_COLORS: { [string]: Color3 } = { gain = C.money, error = C.danger, announce = C.reward }

-- Toast under the banner: green gain, red error, gold announce. 3 s; oldest drops past 3 (PC) / 2 (phone).
function Kit.toast(screen: Screen, message: string, kind: "gain" | "error" | "announce")
    local color = TOAST_COLORS[kind]
    screen.toastSerial += 1
    local label = Instance.new("TextLabel")
    label.Name = "Toast"
    label.LayoutOrder = screen.toastSerial
    label.Size = UDim2.fromScale(1, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.BackgroundColor3 = C.panel
    label.Text = message
    label.TextWrapped = true
    label.FontFace = Theme.Fonts.title
    label.TextSize = Theme.TextSize.heading
    label.TextColor3 = color
    label.ZIndex = 70
    corner(label, BUTTON_RADIUS)
    stroke(label, color, Theme.Stroke.panel, true)
    stroke(label, C.outline, 2)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, Theme.Space.md)
    pad.PaddingBottom = UDim.new(0, Theme.Space.md)
    pad.PaddingLeft = UDim.new(0, Theme.Space.lg)
    pad.PaddingRight = UDim.new(0, Theme.Space.lg)
    pad.Parent = label
    label.Parent = screen.toasts
    Kit.pop(label, 0.6)

    local shown: { TextLabel } = {}
    for _, child in screen.toasts:GetChildren() do
        if child:IsA("TextLabel") then
            table.insert(shown, child)
        end
    end
    table.sort(shown, function(a, b)
        return a.LayoutOrder < b.LayoutOrder
    end)
    for i = 1, #shown - screen.info.toastMax do
        shown[i]:Destroy()
    end
    task.delay(3, function()
        if label.Parent then
            label:Destroy()
        end
    end)
end

-- Shows a server reply ({ok, message} handler shape from MAIN_PLAN) as a toast.
function Kit.toastReply(screen: Screen, reply: Reply)
    if reply.message ~= "" then
        Kit.toast(screen, reply.message, if reply.ok then "gain" else "error")
    end
end

-- Panel manager: one panel open at a time behind a 40% shade + blur 18 (fades with a serial guard).
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
    return { state = Logic.newPanelState(), frames = {}, shade = shade, blur = blur, serial = 0 }
end

local function setFocus(panels: Panels, visible: boolean)
    panels.serial += 1
    local version = panels.serial
    if visible then
        panels.shade.Visible = true
        panels.blur.Enabled = true
        tween(panels.shade, Theme.Motion.fade, { BackgroundTransparency = 0.4 })
        tween(panels.blur, Theme.Motion.fade, { Size = 18 })
    else
        tween(panels.shade, 0.15, { BackgroundTransparency = 1 })
        tween(panels.blur, 0.15, { Size = 0 })
        task.delay(0.16, function()
            if version == panels.serial then
                panels.shade.Visible = false
                panels.blur.Enabled = false
            end
        end)
    end
end

function Kit.showPanel(panels: Panels, name: string)
    local frame = panels.frames[name]
    assert(frame, "unknown panel " .. name)
    local previous = Logic.openPanel(panels.state, name)
    if previous then
        panels.frames[previous].Visible = false
    end
    if not frame.Visible then
        Kit.pop(frame, 0.9)
    end
    frame.Visible = true
    setFocus(panels, true)
end

function Kit.hidePanel(panels: Panels, name: string)
    if Logic.closePanel(panels.state, name) then
        panels.frames[name].Visible = false -- closing is instant (BG rule: keeps visibility checks simple)
        setFocus(panels, false)
    end
end

-- Panel shell: coloured title bar, red X top-right, body frame. Registered with the manager, hidden.
function Kit.shell(screen: Screen, panels: Panels, name: string, title: string, titleColor: Color3): (Frame, Frame)
    local panel = Kit.frame(screen.root, name, C.panel)
    panel:SetAttribute("FLPanel", true)
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Visible = false
    panel.ZIndex = 60
    corner(panel, UDim.new(0, Theme.Radius.panel))
    stroke(panel, C.outline, Theme.Stroke.panel, true)
    fit(panel, screen.info)

    local bar = Kit.frame(panel, "TitleBar", titleColor)
    bar.Size = UDim2.new(1, 0, 0, 80)
    corner(bar, UDim.new(0, Theme.Radius.panel))
    local heading = Kit.text(bar, title, Theme.TextSize.title)
    heading.Name = "Title"
    heading.AnchorPoint = Vector2.new(0, 0.5)
    heading.Position = UDim2.new(0, Theme.Space.xl, 0.5, 0)
    heading.Size = UDim2.new(1, -120, 0, 50)
    heading.TextXAlignment = Enum.TextXAlignment.Left

    local close = Kit.iconButton(bar, Theme.Images.close, "X", "danger", 56)
    close.Name = "Close"
    close.AnchorPoint = Vector2.new(1, 0.5)
    close.Position = UDim2.new(1, -Theme.Space.md, 0.5, 0)
    close.Activated:Connect(function()
        Kit.hidePanel(panels, name)
    end)

    local body = Kit.frame(panel, "Body")
    body.Position = UDim2.fromOffset(Theme.Space.xl, 80 + Theme.Space.lg)
    body.Size = UDim2.new(1, -2 * Theme.Space.xl, 1, -(80 + Theme.Space.lg + Theme.Space.xl))
    body.ClipsDescendants = true

    panels.frames[name] = panel
    return panel, body
end

-- Currency pill: icon overhanging left, rolling number, small "+X/s" line underneath.
function Kit.currencyPill(parent: Instance, image: string, color: Color3): Pill
    local frame = Kit.frame(parent, "CurrencyPill", C.panel)
    frame.Size = UDim2.fromOffset(240, 64)
    corner(frame, PILL)
    stroke(frame, C.outline, Theme.Stroke.panel, true)
    local i = icon(frame, image, color, 76)
    i.AnchorPoint = Vector2.new(0, 0.5)
    i.Position = UDim2.new(0, -20, 0.5, 0)
    local value = Kit.text(frame, "0", Theme.TextSize.title)
    value.Name = "Value"
    value.AnchorPoint = Vector2.new(0, 0.5)
    value.Position = UDim2.new(0, 64, 0.5, 0)
    value.Size = UDim2.new(1, -80, 0, 48)
    value.TextXAlignment = Enum.TextXAlignment.Left
    local rate = Kit.text(frame, "", Theme.TextSize.body, C.money)
    rate.Name = "Rate"
    rate.Position = UDim2.new(0, 64, 1, 2)
    rate.Size = UDim2.new(1, -64, 0, 24)
    rate.TextXAlignment = Enum.TextXAlignment.Left
    local number = Instance.new("NumberValue")
    number.Parent = frame
    number.Changed:Connect(function(v)
        value.Text = Logic.formatNumber(v)
    end)
    return { frame = frame, icon = i, value = value, rate = rate, number = number }
end

-- Rolls the number to the new value in 0.4 s (or snaps when animate is false).
function Kit.setPillValue(pill: Pill, amount: number, animate: boolean?)
    if animate == false then
        pill.number.Value = amount
        pill.value.Text = Logic.formatNumber(amount)
    else
        tween(pill.number, 0.4, { Value = amount })
    end
end

function Kit.setPillRate(pill: Pill, perSecond: number)
    pill.rate.Text = if perSecond > 0 then "+" .. Logic.formatNumber(perSecond) .. "/s" else ""
end

-- Coins curve from an absolute screen point to the pill (0.8 s, 0.03 s stagger); pill bumps on each arrival.
function Kit.coinBurst(screen: Screen, pill: Pill, from: Vector2, count: number?)
    local root = screen.root
    local function toRoot(p: Vector2): Vector2
        return (p - root.AbsolutePosition) / screen.scale.Scale
    end
    local start = toRoot(from)
    local finish = toRoot(pill.icon.AbsolutePosition + pill.icon.AbsoluteSize / 2)
    for n = 1, count or 14 do
        task.delay((n - 1) * 0.03, function()
            local coin = icon(root, pill.icon.Image, pill.icon.BackgroundColor3, 44)
            coin.Name = "BurstCoin"
            coin.AnchorPoint = Vector2.new(0.5, 0.5)
            coin.ZIndex = 80
            local spread = Vector2.new(math.random(-160, 160), math.random(-220, -80))
            local control = (start + finish) / 2 + spread
            local t = Instance.new("NumberValue")
            t.Changed:Connect(function(a)
                local p = start:Lerp(control, a):Lerp(control:Lerp(finish, a), a) -- quadratic bezier
                coin.Position = UDim2.fromOffset(p.X, p.Y)
            end)
            coin.Position = UDim2.fromOffset(start.X, start.Y)
            tween(t, 0.8, { Value = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
                coin:Destroy()
                t:Destroy()
                Kit.pop(pill.frame, 1.15)
            end)
        end)
    end
end

-- 16+ px rounded bar with a highlight strip; optional centred label ("320 / 800").
function Kit.progressBar(parent: Instance, size: UDim2, color: Color3): Bar
    local frame = Kit.frame(parent, "ProgressBar", C.track)
    frame.Size = size
    corner(frame, PILL)
    stroke(frame, C.outline, 3, true)
    local fill = Kit.frame(frame, "Fill", color)
    fill.Size = UDim2.fromScale(0, 1)
    corner(fill, PILL)
    local shine = Kit.frame(fill, "Highlight", C.paper)
    shine.BackgroundTransparency = 0.7
    shine.Position = UDim2.fromOffset(8, 3)
    shine.Size = UDim2.new(1, -16, 0.25, 0)
    corner(shine, PILL)
    local label = Kit.text(frame, "", Theme.TextSize.body)
    label.Name = "Label"
    label.Size = UDim2.fromScale(1, 1)
    return { frame = frame, fill = fill, label = label }
end

function Kit.setProgress(bar: Bar, fraction: number, text: string?)
    tween(bar.fill, 0.2, { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) })
    if text then
        bar.label.Text = text
    end
end

-- Rarity word in its colour (always the word, never colour alone); Secret gets a spinning rainbow.
function Kit.rarityLabel(parent: Instance, rarity: string, textSize: number?): TextLabel
    local color = (Theme.Rarity :: { [string]: Color3 })[rarity]
    assert(color, "unknown rarity " .. rarity)
    local label = Kit.text(parent, string.upper(rarity), textSize or Theme.TextSize.heading, color)
    label.Name = "Rarity"
    label.TextScaled = false
    label.TextSize = textSize or Theme.TextSize.heading
    label.AutomaticSize = Enum.AutomaticSize.X
    label.Size = UDim2.fromOffset(0, label.Size.Y.Offset)
    if rarity == "Secret" then
        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHex("FF4B4B")),
            ColorSequenceKeypoint.new(0.2, Color3.fromHex("FFC800")),
            ColorSequenceKeypoint.new(0.4, Color3.fromHex("5BD45B")),
            ColorSequenceKeypoint.new(0.6, Color3.fromHex("3BA7FF")),
            ColorSequenceKeypoint.new(0.8, Color3.fromHex("B65CFF")),
            ColorSequenceKeypoint.new(1, Color3.fromHex("FF4B6E")),
        })
        gradient.Parent = label
        TweenService:Create(gradient, TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {
            Rotation = 360,
        }):Play()
    end
    return label
end

-- "+X" that floats 60 px up and fades in 0.9 s, then removes itself.
function Kit.floatingNumber(parent: Instance, value: string, color: Color3, position: UDim2)
    local label = Kit.text(parent, value, Theme.TextSize.heading, color)
    label.Name = "FloatingNumber"
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Size = UDim2.fromOffset(200, 36)
    label.Position = position
    label.ZIndex = 75
    local s = label:FindFirstChildOfClass("UIStroke")
    tween(label, 0.9, { Position = position + UDim2.fromOffset(0, -60), TextTransparency = 1 })
    if s then
        tween(s, 0.9, { Transparency = 1 })
    end
    task.delay(0.95, function()
        label:Destroy()
    end)
end

return Kit
