--!strict
-- Throwing (design-v3 3.2, 3.3, 3.4; VS-6): hold to charge on the Ledge, release to throw. Mouse / Space,
-- touch THROW button, gamepad R2. The server picks the result (ReleaseThrow); this module only shows it:
-- meter, release label, food arc, Mama Hen, egg return, throw cam or Eat Card.

local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Cam = require(script.Parent.Cam)
local Ctx = require(script.Parent.Ctx)
local Fx = require(script.Parent.Fx)
local Hen = require(script.Parent.Hen)
local Hud = require(script.Parent.Hud)
local Nest = require(script.Parent.Nest)
local Sfx = require(script.Parent.Sfx)

local Economy = Ctx.Economy
local LEDGE_RANGE = 5.5 -- a little inside the server's 6 studs
local ACTION = "FLThrow"

local Throw = {}
Throw.onLedge = false
local charging = false
local holdStart = 0
local token = 0
local chargeReply: any = nil
local chargeSound: Sound? = nil
local seenZones: { [number]: boolean } = {}

local FOOD_COLORS = {
    Color3.fromRGB(230, 50, 50), -- Apple
    Color3.fromRGB(255, 140, 30), -- Carrot
    Color3.fromRGB(70, 90, 220), -- Blueberries
    Color3.fromRGB(220, 170, 90), -- Pancakes
    Color3.fromRGB(240, 60, 90), -- Strawberry
    Color3.fromRGB(255, 210, 90), -- Star Cookie
}

-- Same ping-pong as the server (EggRules.needle)
local function needle(elapsed: number): number
    local x = (elapsed / Economy.NEEDLE_HALF_CYCLE) % 2
    return if x <= 1 then x else 2 - x
end

local function stopCharge()
    charging = false
    if chargeSound then
        chargeSound:Destroy()
        chargeSound = nil
    end
    Cam.fov(70, 0.2)
    local press = Hud.throwButton:FindFirstChild("MotionScale") :: UIScale?
    if press then
        press.Scale = 1
    end
end

local function fail(message: string)
    token += 1
    stopCharge()
    Hud.meter.Visible = false
    if message ~= "" then
        Hud.toast(message, "error")
    end
    Sfx.play("bonk")
    Hud.shake(if Hud.throwButton.Visible then Hud.throwButton else Hud.hint)
    if string.find(message, "Nest full", 1, true) then
        Hud.pulseNest()
    end
end

local function begin()
    if charging or not Throw.onLedge then
        return
    end
    token += 1
    local my = token
    charging = true
    holdStart = os.clock()
    chargeReply = nil
    Hud.buildMeter(Ctx.strength)
    Hud.setNeedle(0)
    Hud.meter.Visible = true
    chargeSound = Sfx.loop("charge", 0.5)
    Cam.fov(66, 0.4)
    local press = Hud.throwButton:FindFirstChild("MotionScale") :: UIScale?
    if press then
        press.Scale = 0.92
    end
    task.spawn(function()
        local r = Ctx.invoke("StartCharge")
        if my ~= token then
            return
        end
        chargeReply = r
        if not r.ok then
            fail(r.message)
        end
    end)
end

-- Throw cam: follow the food, hold a 3/4 view of the hen, ride back with the egg (eggOnly: return leg only)
local function throwCam(r: any, landing: Vector3, food: BasePart?, getEgg: () -> BasePart?, eggOnly: boolean)
    local origin = (Ctx.station("Ledge"):FindFirstChild("Pad") :: BasePart).Position
    local flat = (origin - landing) * Vector3.new(1, 0, 1)
    local back = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
    local side = back:Cross(Vector3.yAxis).Unit
    local current = Workspace.CurrentCamera.CFrame
    Cam.set("throw", 20, function(dt)
        local now = Ctx.now()
        local target: CFrame? = nil
        if not eggOnly and now < r.foodLandsAt and food and food.Parent then
            local p = food.Position
            target = CFrame.lookAt(p + back * 24 + Vector3.new(0, 10, 0), p)
        elseif not eggOnly and now < r.eggLaunchAt then
            target =
                CFrame.lookAt(landing + back * 22 + side * 14 + Vector3.new(0, 12, 0), landing + Vector3.new(0, 4, 0))
        else
            local egg = getEgg()
            if now > r.arrivesAt + 0.2 then
                Cam.clear("throw")
            elseif egg and egg.Parent then
                local p = egg.Position
                target = CFrame.lookAt(p - back * 20 + Vector3.new(0, 9, 0), p)
            end
        end
        if target then
            current = Cam.smooth(current, target, dt, 14)
        end
        return current
    end)
end

local function launch(r: any)
    Hud.releaseLabel(r.label, r.label == "SWEET!")
    Sfx.play("throw")
    if r.label == "SWEET!" then
        Sfx.play("ding")
    end
    task.delay(0.6, function()
        if not charging then
            Hud.meter.Visible = false
        end
    end)

    table.insert(
        Ctx.nest,
        { id = r.eggId, zone = r.zone, sparkle = r.sparkle, state = "Flight", arrivesAt = r.arrivesAt }
    )
    Ctx.stats.throws = r.throwNumber
    Ctx.emit("nest")

    local originAttachment = (Ctx.station("Ledge"):FindFirstChild("Pad") :: BasePart):FindFirstChild(
            "ThrowOrigin"
        ) :: Attachment
    local from = originAttachment.WorldPosition
    local landing = Fx.landingPoint(r.zone, r.landingDistance)
    local food =
        Fx.part("Food", Vector3.new(1.6, 1.6, 1.6), FOOD_COLORS[Ctx.foodTier] or FOOD_COLORS[1], Enum.PartType.Ball)
    food.CFrame = CFrame.new(from)
    local a0 = Instance.new("Attachment")
    a0.Position = Vector3.new(0, 0.5, 0)
    a0.Parent = food
    local a1 = Instance.new("Attachment")
    a1.Position = Vector3.new(0, -0.5, 0)
    a1.Parent = food
    local trail = Instance.new("Trail")
    trail.Attachment0, trail.Attachment1 = a0, a1
    trail.Color = ColorSequence.new(food.Color)
    trail.Lifetime = 0.3
    trail.Transparency = NumberSequence.new(0.3, 1)
    trail.Parent = food
    local apex = math.clamp(40 + 0.05 * (landing - from).Magnitude, 40, 160)
    Fx.arc(food, from, landing, apex, math.max(0.2, r.foodLandsAt - Ctx.now()), 1, function()
        trail.Enabled = false
        food.CFrame = CFrame.new(landing + Vector3.new(0, 0.8, 0))
    end)

    local eggFrom = Hen.play(r, landing, food)
    local eggPart: BasePart? = nil
    Nest.incoming(r.eggId, r.zone, r.sparkle, eggFrom, r.eggLaunchAt, r.arrivesAt, function(part)
        eggPart = part
    end)

    local newZone = not seenZones[r.zone]
    seenZones[r.zone] = true
    local follow = r.throwNumber <= 3 or newZone or Ctx.settings.followThrows
    if follow then
        throwCam(r, landing, food, function()
            return eggPart
        end, false)
    else
        Hen.card(r)
        if r.sparkle then
            Ctx.at(r.eggLaunchAt, function()
                throwCam(r, landing, nil, function()
                    return eggPart
                end, true)
            end)
        end
    end
end

local function release()
    if not charging then
        return
    end
    local my = token
    local elapsed = os.clock() - holdStart
    stopCharge()
    task.spawn(function()
        local waited = 0
        while chargeReply == nil and my == token and waited < 5 do
            waited += task.wait()
        end
        if my ~= token or not chargeReply or not chargeReply.ok then
            return
        end
        local r = Ctx.invoke("ReleaseThrow", elapsed)
        if not r.ok then
            fail(r.message)
            return
        end
        launch(r)
    end)
end

local function cancel()
    if charging then
        token += 1
        stopCharge()
        Hud.meter.Visible = false
    end
end

local function onAction(_: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
    if state == Enum.UserInputState.Begin then
        begin()
    elseif state == Enum.UserInputState.End then
        release()
    elseif state == Enum.UserInputState.Cancel then
        cancel()
    end
    return Enum.ContextActionResult.Sink
end

function Throw.init(zonesOwned: { [number]: boolean })
    seenZones = zonesOwned
    Hud.throwButton.InputBegan:Connect(function(input)
        if
            input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        then
            begin()
        end
    end)
    Hud.throwButton.InputEnded:Connect(function(input)
        if
            input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        then
            release()
        end
    end)

    local lastGamepad = false
    RunService.Heartbeat:Connect(function()
        local on = Ctx.distanceTo("Ledge") <= LEDGE_RANGE and not Ctx.washing
        local gamepad = UserInputService:GetLastInputType().Name:find("Gamepad") ~= nil
        if on ~= Throw.onLedge or gamepad ~= lastGamepad then
            Throw.onLedge = on
            lastGamepad = gamepad
            if on then
                ContextActionService:BindActionAtPriority(
                    ACTION,
                    onAction,
                    false,
                    Enum.ContextActionPriority.High.Value,
                    Enum.UserInputType.MouseButton1,
                    Enum.KeyCode.Space,
                    Enum.KeyCode.ButtonR2
                )
            else
                ContextActionService:UnbindAction(ACTION)
                cancel()
            end
            Hud.showThrowControls(on)
        end
        if charging then
            local elapsed = os.clock() - holdStart
            local p = needle(elapsed)
            Hud.setNeedle(p)
            if chargeSound then
                chargeSound.PlaybackSpeed = 0.8 + 0.6 * p
            end
            if elapsed > Economy.MAX_HOLD then
                fail("Held too long! Try again.")
            end
        end
    end)
end

return Throw
