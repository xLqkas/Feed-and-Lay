--!strict
-- The one place UI motion is defined (docs/ai/ui-style-spec.md section 5 and table 1.1). Every named tween
-- comes from a captured preset (src/client/UI/Presets) or, where no preset covers it, from spec section 5.
-- Feature code asks for a motion by name; it never builds its own TweenInfo.
-- FLUiPreset (see Theme.luau) swaps in that preset's tween wherever it has one of the same name.
-- Reduced motion (GuiService.ReducedMotionEnabled): scale / slide motions become a 0.15 s fade-free snap
-- and loops (pulse, bob, wobble) do not start.

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Presets = script.Parent.Presets
local DarkTiles = require(Presets.DarkTiles)
local GlassPanels = require(Presets.GlassPanels)
local LightDock = require(Presets.LightDock)
local SlimPills = require(Presets.SlimPills)

local S = Enum.EasingStyle
local D = Enum.EasingDirection

export type Spec = {
    Time: number,
    EasingStyle: Enum.EasingStyle,
    EasingDirection: Enum.EasingDirection,
    Delay: number,
    From: { [string]: number },
    To: { [string]: number },
    Stagger: number?,
    Loop: boolean?,
}

local function spec(time: number, style: Enum.EasingStyle, dir: Enum.EasingDirection, from: any?, to: any?): Spec
    return { Time = time, EasingStyle = style, EasingDirection = dir, Delay = 0, From = from or {}, To = to or {} }
end

local function looped(s: Spec): Spec
    local c = table.clone(s)
    c.Loop = true
    return c
end

local Motion = {}

-- Named presets. Source in the comment; spec = ui-style-spec.md section 5.
Motion.Presets = {
    panelOpen = DarkTiles.Motion.panelOpen, -- Scale 0.6 -> 1, Back Out 0.3 s
    panelClose = DarkTiles.Motion.panelClose, -- Scale 1 -> 0.75, Quad In 0.15 s
    shadeIn = spec(0.15, S.Quad, D.Out), -- spec: shade + blur with the panel
    shadeOut = spec(0.15, S.Quad, D.In),
    hudHide = DarkTiles.Motion.hudTilesHide, -- menu columns slide off while a panel is open
    hudShow = DarkTiles.Motion.hudTilesShow,
    stationHide = spec(0.2, S.Quad, D.In), -- spec: menu columns hide in station mode
    stationShow = spec(0.2, S.Quad, D.Out),
    buttonHover = spec(0.12, S.Quad, D.Out, { Scale = 1 }, { Scale = 1.04 }), -- spec 4.1
    buttonPress = spec(0.06, S.Quad, D.Out, { Scale = 1 }, { Scale = 0.94 }), -- spec 4.1 (stronger than DarkTiles)
    buttonRelease = DarkTiles.Motion.buttonRelease, -- Back Out 0.15 s
    tileShine = DarkTiles.Motion.tileHoverShine,
    pop = spec(0.25, S.Back, D.Out), -- reward pop / counter bump: scale peak -> 1
    newButton = spec(0.35, S.Back, D.Out, { Scale = 0 }, { Scale = 1 }), -- spec: new HUD button
    numberRoll = DarkTiles.Motion.numberRoll, -- small ticks (income)
    counterRoll = LightDock.Motion.counterRoll, -- bigger gains, Quad Out 0.4 s
    coinFly = GlassPanels.Motion.cashFly, -- Quad In 0.7 s, stagger 0.015, shrink to 0.6
    coinSpawn = spec(0.15, S.Quad, D.Out, { Scale = 0 }, { Scale = 1 }),
    toastIn = SlimPills.Motion.errorToastIn, -- Scale 0.83 -> 1, Back Out 0.3 s
    toastOut = SlimPills.Motion.errorToastOut, -- fade 0.08 s after a 2.0 s hold
    floatNumber = GlassPanels.Motion.floatNumber, -- up 0.05 H and fade, 0.6 s
    dotPulse = looped(spec(0.6, S.Sine, D.InOut, { Scale = 1 }, { Scale = 1.15 })), -- spec 4.7: 1.2 s cycle
    arrowBob = looped(spec(0.3, S.Sine, D.InOut, { OffsetY = 0 }, { OffsetY = 8 })), -- spec 4.6: 8 px, 0.6 s
    idleBob = looped(spec(0.5, S.Sine, D.InOut, { OffsetY = 0 }, { OffsetY = -6 })), -- spec: 1.0 s cycle
    wobble = LightDock.Motion.shortcutWobble, -- +-8 deg, Sine InOut, loop
    shake = spec(0.25, S.Linear, D.InOut), -- spec: +-6 px x3
    objectiveOut = spec(0.15, S.Quad, D.In, { OffsetY = 0 }, { OffsetY = -10 }),
    objectiveIn = spec(0.25, S.Back, D.Out, { Scale = 0.8 }, { Scale = 1 }),
    priceAffordable = spec(0.25, S.Back, D.Out, { Scale = 1.1 }, { Scale = 1 }),
    revealFlashIn = spec(0.12, S.Quad, D.Out, { Transparency = 1 }, { Transparency = 0 }),
    revealFlashOut = DarkTiles.Motion.revealFlash, -- 0.35 s
    revealLand = GlassPanels.Motion.revealLand, -- Scale 1.3 -> 1, Back Out 0.3 s
    revealSticker = DarkTiles.Motion.revealSticker, -- NEW! sticker, 0.2 s after land
    timerUrgent = spec(0.3, S.Quad, D.Out, { Scale = 1.08 }, { Scale = 1 }),
    tabSwitch = spec(0.12, S.Quad, D.Out),
    fade = spec(0.15, S.Linear, D.InOut), -- reduced-motion replacement
    wordOut = spec(0.25, S.Linear, D.InOut), -- big centre words fade
    stampIn = spec(0.4, S.Back, D.Out), -- zone unlocked stamp drops in
    fill = spec(0.2, S.Quad, D.Out), -- progress bar fill
} :: { [string]: Spec }

-- Other preset: same-named tweens replace the blend's (panel open/close, button press/release, toasts...).
if Theme.Preset ~= "Blend" then
    local module = Presets:FindFirstChild(Theme.Preset)
    if module and module:IsA("ModuleScript") then
        local p = (require :: any)(module)
        local alias = { errorToastIn = "toastIn", errorToastOut = "toastOut", gainToast = "toastIn" }
        for name, t in p.Motion do
            local key = alias[name] or name
            if Motion.Presets[key] then
                Motion.Presets[key] = t
            end
        end
    end
end

function Motion.reduced(): boolean
    return GuiService.ReducedMotionEnabled
end

function Motion.get(name: string): Spec
    local s = Motion.Presets[name]
    assert(s, "unknown motion " .. name)
    return s
end

function Motion.info(name: string, delay: number?): TweenInfo
    local s = Motion.get(name)
    local loop = s.Loop == true
    return TweenInfo.new(s.Time, s.EasingStyle, s.EasingDirection, if loop then -1 else 0, loop, delay or s.Delay)
end

-- Plays the named timing on any properties. Returns the tween (already playing).
function Motion.play(target: Instance, name: string, goal: { [string]: any }, delay: number?): Tween
    local t = TweenService:Create(target, Motion.info(name, delay), goal)
    t:Play()
    return t
end

-- One UIScale per object for motion (named MotionScale, so layout code can own other UIScales).
function Motion.scale(object: GuiObject): UIScale
    local s = object:FindFirstChild("MotionScale") :: UIScale?
    if s then
        return s
    end
    local n = Instance.new("UIScale")
    n.Name = "MotionScale"
    n.Parent = object
    return n
end

-- Scale peak -> 1 with a springy settle (reward pop, counter bump, arrival).
function Motion.pop(object: GuiObject, peak: number?, name: string?)
    local s = Motion.scale(object)
    if Motion.reduced() then
        s.Scale = 1
        return
    end
    s.Scale = peak or 1.15
    Motion.play(s, name or "pop", { Scale = 1 })
end

-- Scale From -> To of a named preset (panel open / close, new button, reveal land, sticker).
function Motion.scaleTo(object: GuiObject, name: string, delay: number?): Tween?
    local m = Motion.get(name)
    local s = Motion.scale(object)
    if Motion.reduced() then
        s.Scale = m.To.Scale or 1
        return nil
    end
    s.Scale = m.From.Scale or s.Scale
    return Motion.play(s, name, { Scale = m.To.Scale or 1 }, delay)
end

-- Looping motion (pulse, bob, wobble). Stops itself when the object leaves the game. Returns a stop function.
function Motion.loop(target: Instance, name: string, goal: { [string]: any }): () -> ()
    if Motion.reduced() then
        return function() end
    end
    local t = Motion.play(target, name, goal)
    local conn = target.AncestryChanged:Connect(function()
        if not target:IsDescendantOf(game) then
            t:Cancel()
        end
    end)
    return function()
        conn:Disconnect()
        t:Cancel()
    end
end

-- Pulsing notification dot: 1.0 -> 1.15 -> 1.0 every 1.2 s.
function Motion.pulse(object: GuiObject): () -> ()
    local s = Motion.scale(object)
    s.Scale = 1
    local stop = Motion.loop(s, "dotPulse", { Scale = Motion.get("dotPulse").To.Scale })
    return function()
        stop()
        s.Scale = 1
    end
end

-- Bobs a GuiObject by `pixels` (reference px) along `axis` from its current position.
function Motion.bob(object: GuiObject, name: string, axis: Vector2?): () -> ()
    local base = object.Position
    local d = Motion.get(name).To.OffsetY or 8
    local dir = axis or Vector2.new(0, 1)
    return Motion.loop(object, name, { Position = base + UDim2.fromOffset(dir.X * d, dir.Y * d) })
end

-- Cannot-afford shake: +-6 px x3 in 0.25 s around the object's resting position.
function Motion.shake(object: GuiObject)
    local base = object:GetAttribute("FLShakeBase") :: UDim2?
    if not base then
        object:SetAttribute("FLShakeBase", object.Position)
        base = object.Position
    end
    local b = base :: UDim2
    local total = Motion.get("shake").Time
    local steps = { 6, -6, 6, -6, 6, 0 }
    for i, dx in steps do
        task.delay((i - 1) * total / #steps, function()
            object.Position = b + UDim2.fromOffset(dx, 0)
        end)
    end
end

-- Number roll: tweens a NumberValue to `amount` ("counterRoll" for big gains, "numberRoll" for ticks).
function Motion.roll(number: NumberValue, amount: number, name: string?): Tween?
    if Motion.reduced() then
        number.Value = amount
        return nil
    end
    return Motion.play(number, name or "counterRoll", { Value = amount })
end

-- Fades a text label (and its strokes) out, then destroys it.
function Motion.fadeOut(label: TextLabel | TextButton, name: string?, destroy: boolean?)
    local n = name or "wordOut"
    Motion.play(label, n, { TextTransparency = 1 })
    for _, s in label:GetChildren() do
        if s:IsA("UIStroke") then
            Motion.play(s, n, { Transparency = 1 })
        end
    end
    if destroy then
        local m = Motion.get(n)
        task.delay(m.Delay + m.Time + 0.05, function()
            label:Destroy()
        end)
    end
end

-- Floating "+N": rises by the preset's OffsetY (fraction of 1080 px) and fades, then removes itself.
function Motion.float(label: TextLabel)
    local m = Motion.get("floatNumber")
    local rise = (m.To.OffsetY or -0.05) * 1080
    Motion.play(label, "floatNumber", { Position = label.Position + UDim2.fromOffset(0, rise) })
    Motion.fadeOut(label, "floatNumber", true)
end

-- Currency fly-to-counter: `count` images spawn at `from`, arc to `to` (root-space reference px), staggered,
-- shrinking to the preset's end scale; onArrive runs per image (counter pop, tick sound).
function Motion.fly(root: GuiObject, image: string, from: Vector2, to: Vector2, count: number, onArrive: (() -> ())?)
    local m = Motion.get("coinFly")
    local stagger = m.Stagger or 0.015
    for n = 1, count do
        task.delay((n - 1) * stagger + math.random() * 0.15, function()
            local coin = Instance.new("ImageLabel")
            coin.Name = "FlyCoin"
            coin.BackgroundTransparency = 1
            coin.Image = image
            coin.AnchorPoint = Vector2.new(0.5, 0.5)
            coin.Size = UDim2.fromOffset(52, 52)
            coin.ZIndex = 80
            coin.Position = UDim2.fromOffset(from.X, from.Y)
            coin.Parent = root
            local spread = Vector2.new(math.random(-180, 180), math.random(-220, -60))
            local control = (from + to) / 2 + spread
            Motion.scaleTo(coin, "coinSpawn")
            local t = Instance.new("NumberValue")
            local conn = t.Changed:Connect(function(a)
                local p = from:Lerp(control, a):Lerp(control:Lerp(to, a), a) -- quadratic bezier
                coin.Position = UDim2.fromOffset(p.X, p.Y)
            end)
            Motion.play(Motion.scale(coin), "coinFly", { Scale = m.To.Scale or 0.6 }, 0.15)
            Motion.play(t, "coinFly", { Value = 1 }).Completed:Connect(function()
                conn:Disconnect()
                coin:Destroy()
                t:Destroy()
                if onArrive then
                    onArrive()
                end
            end)
        end)
    end
end

-- Scrolls a UIGradient offset (rainbow Secret frames) forever.
function Motion.spin(gradient: UIGradient, seconds: number)
    if Motion.reduced() then
        return
    end
    local conn: RBXScriptConnection
    conn = RunService.RenderStepped:Connect(function()
        if not gradient.Parent then
            conn:Disconnect()
            return
        end
        gradient.Rotation = (os.clock() / seconds * 360) % 360
    end)
end

return Motion
