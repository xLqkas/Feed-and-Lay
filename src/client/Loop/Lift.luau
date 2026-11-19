--!strict
-- Lift Bench (design-v3 3.1, VS-9): step onto the bench ring; a ring shrinks toward the target circle and the
-- player taps (PC: click or Space, phone: tap anywhere outside buttons, gamepad: A) when they meet. The server
-- owns the ring schedule (Economy.liftRing with the session seed) and judges every tap; this module only draws
-- rings, sends taps and shows the server's result. Leave by walking out, the X button, or 20 s without a tap.

local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Cam = require(script.Parent.Cam)
local Ctx = require(script.Parent.Ctx)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)
local Sfx = require(script.Parent.Sfx)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Logic = require(UI:WaitForChild("Logic"))
local Theme = require(UI:WaitForChild("Theme"))

local C = Theme.Colors
local Economy = Ctx.Economy
local ENTER = 2.6 -- the bench ring is 4 studs across
local LEAVE = 4.5
local TARGET = 150 -- target circle diameter, reference px
local ACTION = "FLLiftTap"
local RING_Y = 0.3 -- above the character in the side view

local Lift = {}
local active = false
local pending = false -- StartLift in flight
local waiting = false -- a tap in flight
local blocked = false -- after leaving with X or a refusal: until the player steps off the bench
local session: any = nil
local ring = { index = 0, startAt = 0, duration = 1 }
local lastTap = 0

-- HUD: target circle at screen centre, the shrinking ring, Strength bar, dumbbell name, result word, X
local hud = Kit.frame(Hud.screen.root, "LiftHud")
hud.Size = UDim2.fromScale(1, 1)
hud.Visible = false
local function circle(name: string, color: Color3, thickness: number): Frame
    local f = Kit.frame(hud, name, C.paper)
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.fromScale(0.5, RING_Y)
    f.Size = UDim2.fromOffset(TARGET, TARGET)
    f.BackgroundTransparency = 1
    Kit.corner(f, UDim.new(0.5, 0))
    local s = Kit.stroke(f, color, thickness, true)
    s.Name = "Line"
    return f
end
local target = circle("Target", C.paper, 10)
local outer = circle("Ring", C.reward, 8)
local word = Kit.text(hud, "", Theme.TextSize.display)
word.AnchorPoint = Vector2.new(0.5, 0.5)
word.Position = UDim2.fromScale(0.5, RING_Y)
word.Size = UDim2.fromOffset(420, 70)
local bar = Kit.progressBar(hud, UDim2.fromOffset(560, 40), C.reward)
bar.frame.AnchorPoint = Vector2.new(0.5, 0)
local bellLabel = Kit.text(hud, "", Theme.TextSize.body, C.muted)
bellLabel.AnchorPoint = Vector2.new(0.5, 0)
bellLabel.Size = UDim2.fromOffset(560, 28)
local hint = Kit.text(hud, "", Theme.TextSize.body)
hint.AnchorPoint = Vector2.new(0.5, 0)
hint.Size = UDim2.fromOffset(700, 28)
local close = Kit.iconButton(hud, Theme.Images.close, "X", "danger", 64)
close.AnchorPoint = Vector2.new(1, 0)

Kit.onLayout(Hud.screen, function(info)
    local y = if info.compact then 0.62 else 0.6
    bar.frame.Size = if info.compact then UDim2.new(0.8, 0, 0, 40) else UDim2.fromOffset(560, 40)
    bar.frame.Position = UDim2.fromScale(0.5, y)
    bellLabel.Position = UDim2.new(0.5, 0, y, 46)
    hint.Position = UDim2.new(0.5, 0, y, 78)
    close.Position = UDim2.fromScale(0.98, if info.compact then 0.2 else 0.05)
end)

-- Next zone gate above this Strength (bar goal), or nil past the last zone
local function nextGate(strength: number): any
    for _, zone in Economy.Zones do
        if zone.StrengthGate > strength then
            return zone
        end
    end
    return nil
end

local function refreshBar()
    local strength = Ctx.strength
    local zone = nextGate(strength)
    if zone then
        local prev = 0
        for _, z in Economy.Zones do
            if z.StrengthGate <= strength then
                prev = math.max(prev, z.StrengthGate)
            end
        end
        local from = math.max(prev, Economy.START_STRENGTH)
        Kit.setProgress(
            bar,
            (strength - from) / math.max(zone.StrengthGate - from, 1),
            "Strength "
                .. Logic.formatNumber(strength)
                .. " / "
                .. Logic.formatNumber(zone.StrengthGate)
                .. " ("
                .. zone.Name
                .. ")"
        )
    else
        Kit.setProgress(bar, 1, "Strength " .. Logic.formatNumber(strength))
    end
    local bell = Economy.Dumbbells[Ctx.dumbbellTier] or Economy.Dumbbells[1]
    bellLabel.Text = bell.Name .. ": +" .. Logic.formatNumber(bell.PerRep) .. " per rep"
end

local function showWord(text: string, color: Color3)
    word.Text = text
    word.TextColor3 = color
    word.TextTransparency = 0
    Kit.pop(word, 0.6)
    task.delay(0.45, function()
        if word.Text == text then
            Kit.tween(word, 0.2, { TextTransparency = 1 })
        end
    end)
end

local function stamp(zoneName: string)
    local s = Kit.text(Hud.screen.root, string.upper(zoneName) .. " UNLOCKED!", Theme.TextSize.display, C.reward)
    s.AnchorPoint = Vector2.new(0.5, 0.5)
    s.Size = UDim2.fromOffset(900, 80)
    s.Position = UDim2.fromScale(0.5, -0.2)
    s.ZIndex = 45
    Kit.tween(s, 0.4, { Position = UDim2.fromScale(0.5, 0.28) }, Enum.EasingStyle.Back)
    Sfx.play("fanfare2")
    task.delay(1.6, function()
        Kit.tween(s, 0.3, { TextTransparency = 1 })
        task.delay(0.35, function()
            s:Destroy()
        end)
    end)
end

local function stop(sendStop: boolean)
    if not active then
        return
    end
    active = false
    Ctx.lifting = false
    session = nil
    hud.Visible = false
    Cam.clear("lift")
    ContextActionService:UnbindAction(ACTION)
    if sendStop then
        task.spawn(Ctx.invoke, "StopLift")
    end
end

local function tap()
    if not active or waiting or not session then
        return
    end
    lastTap = os.clock()
    waiting = true
    local elapsed = Ctx.now() - ring.startAt
    local r = Ctx.invoke("Lift", session.sessionId, ring.index, elapsed)
    waiting = false
    if not active then
        return
    end
    if not r.ok then
        Hud.toast(r.message, "error")
        Sfx.play("bonk")
        stop(false)
        blocked = true
        return
    end
    ring = r.ring
    local before = Ctx.strength
    Ctx.strength = r.strength
    if r.result == "miss" then
        showWord("MISS", C.muted)
        Sfx.play("bonk", 0.8, 0.5)
        if r.message ~= "" then
            Hud.toast(r.message, "error")
        end
    else
        local perfect = r.result == "perfect"
        showWord(if perfect then "PERFECT!" else "GOOD", if perfect then C.reward else C.money)
        Sfx.play("ding", if perfect then 1.2 else 1, 0.6)
        local root = Ctx.root()
        if root then
            Fx.floatText(
                root.Position + Vector3.new(0, 3.5, 0),
                "+" .. Logic.formatNumber(r.gained),
                if perfect then C.reward else C.money
            )
        end
        Kit.pop(bar.frame, 1.06)
        for _, zone in Economy.Zones do
            if before < zone.StrengthGate and r.strength >= zone.StrengthGate then
                stamp(zone.Name)
            end
        end
    end
    refreshBar()
end

local function start()
    pending = true
    local r = Ctx.invoke("StartLift")
    pending = false
    if not r.ok then
        Hud.toast(r.message, "error")
        Sfx.play("bonk")
        blocked = true
        return
    end
    if Ctx.distanceTo("LiftBench") > LEAVE then
        task.spawn(Ctx.invoke, "StopLift")
        return
    end
    active = true
    Ctx.lifting = true
    session = r
    ring = r.ring
    Ctx.strength = r.strength
    lastTap = os.clock()
    refreshBar()
    hud.Visible = true
    local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local gamepad = UserInputService:GetLastInputType().Name:find("Gamepad") ~= nil
    hint.Text = if gamepad
        then "Press A when the rings meet"
        elseif touch then "Tap when the rings meet"
        else "Click or press Space when the rings meet"
    ContextActionService:BindActionAtPriority(ACTION, function(_, state)
        if state == Enum.UserInputState.Begin then
            task.spawn(tap)
        end
        return Enum.ContextActionResult.Sink -- Space and A do not jump while lifting
    end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
    -- side view of the bench, from the plot centre's side
    local current = Workspace.CurrentCamera.CFrame
    Cam.set("lift", 10, function(dt)
        local root = Ctx.root()
        if not root then
            return current
        end
        local at = root.Position + Vector3.new(0, 1, 0)
        local side = Ctx.plotRotation():VectorToWorldSpace(Vector3.new(1, 0, 0))
        current = Cam.smooth(current, CFrame.lookAt(at + side * 10 + Vector3.new(0, 2.5, 0), at), dt, 9)
        return current
    end)
end

function Lift.init()
    close.Activated:Connect(function()
        stop(true)
        blocked = true
    end)
    UserInputService.InputBegan:Connect(function(input, processed)
        local kind = input.UserInputType
        if
            active
            and not processed
            and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch)
        then
            task.spawn(tap)
        end
    end)
    RunService.RenderStepped:Connect(function()
        local d = Ctx.distanceTo("LiftBench")
        if d > LEAVE then
            blocked = false
            if active then
                stop(true)
            end
        end
        if not active and not pending and not blocked and d <= ENTER then
            task.spawn(start)
        end
        if not active or not session then
            return
        end
        if os.clock() - lastTap > Economy.LIFT_IDLE_CLOSE then
            stop(true)
            blocked = true
            Hud.toast("Lift closed. Step on again to lift!", "error")
            return
        end
        local e = Ctx.now() - ring.startAt
        local T = ring.duration
        if not waiting and e > T * (1 + Economy.LIFT_LATE) then
            -- timed out: the server moves on the same way (LiftRules.advance)
            local gap, nextT = Economy.liftRing(session.seed, ring.index + 1)
            ring = {
                index = ring.index + 1,
                startAt = ring.startAt + T * (1 + Economy.LIFT_LATE) + gap,
                duration = nextT,
            }
            showWord("MISS", C.muted)
            return
        end
        outer.Visible = e >= 0
        target.BackgroundTransparency = if e >= 0 then 1 else 0.85
        local scale = math.max(2 - e / T, 1 - Economy.LIFT_LATE)
        outer.Size = UDim2.fromOffset(TARGET * scale, TARGET * scale)
        local line = outer:FindFirstChild("Line") :: UIStroke
        line.Color = if math.abs(e - T) / T <= Economy.LIFT_GOOD then C.money else C.reward
    end)
end

return Lift
