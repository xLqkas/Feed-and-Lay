--!strict
-- Washer (design-v3 3.5, VS-7): step into the ring to load the oldest egg; the camera sits on the turntable's
-- +Z side (the server's facing check assumes it). Hold and aim (mouse, touch, gamepad R2 + right stick) to spray.
-- Every 0.1 s the client sends the aim point on the unit egg (SprayHits); the server picks the blobs, owns HP and
-- answers with ChunkHit (a quarter of a blob knocked off) / ChunkPopped / WashDone / HatchResult / WashLoaded.
-- Each mud blob is drawn as BLOB_STAGES lumps; one flies off per ChunkHit. Progress comes from the server's HP.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Cam = require(script.Parent.Cam)
local Ctx = require(script.Parent.Ctx)
local Fx = require(script.Parent.Fx)
local Hatch = require(script.Parent.Hatch)
local Hud = require(script.Parent.Hud)
local Nest = require(script.Parent.Nest)
local Sfx = require(script.Parent.Sfx)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Theme = require(UI:WaitForChild("Theme"))

local Economy = Ctx.Economy
local RING_ENTER = 3.6 -- ring is 6.4 studs across
local RING_LEAVE = 6
local SPRAY_EVERY = 0.1
local CAMERA_DISTANCE = 6
local RADII = Fx.EGG_SIZE / 2
local LUMP_SIZE = Vector3.new(0.75, 0.75, 0.45) -- 4 lumps make one blob about the aim radius wide
-- lump offsets on the egg surface (studs, blob-local x/y); the big centre lump goes last
local LUMPS = { Vector2.new(-0.32, 0.22), Vector2.new(0.34, 0.18), Vector2.new(0.02, -0.34), Vector2.new(0, 0) }
local CURSOR_SPEED = 700 -- gamepad aim, px per second

local Wash = {}
type Chunk = { parts: { BasePart }, normal: Vector3, frac: number, alive: boolean }
local active = false
local pending = false
local blockedUntil = 0 -- after X / walking out: until the player leaves the ring; after a refusal: 2 s
local info: any = nil
local egg: BasePart? = nil
local chunks: { Chunk } = {}
local combo = 0
local comboLabelAt = 0
local hopUntil = 0
local lastSpray = os.clock()
local touchPos: Vector2? = nil
local cursor = Vector2.zero
local hiss: Sound? = nil
local sprayRemote = Ctx.remotes:WaitForChild("SprayHits") :: UnreliableRemoteEvent

-- Spray visuals: a water beam from beside the camera to the aim point, plus mist at the hit point
local nozzle = Fx.part("Nozzle", Vector3.one * 0.2, Color3.new(1, 1, 1))
nozzle.Transparency = 1
local hitPart = Fx.part("SprayHit", Vector3.one * 0.2, Color3.new(1, 1, 1))
hitPart.Transparency = 1
local a0 = Instance.new("Attachment")
a0.Parent = nozzle
local a1 = Instance.new("Attachment")
a1.Parent = hitPart
local beam = Instance.new("Beam")
beam.Attachment0, beam.Attachment1 = a0, a1
beam.Color = ColorSequence.new(Color3.fromRGB(140, 210, 255))
beam.Transparency = NumberSequence.new(0.2, 0.5)
beam.Width0, beam.Width1 = 0.15, 0.6
beam.LightEmission = 0.5
beam.FaceCamera = true
beam.Enabled = false
beam.Parent = nozzle
local mist = Instance.new("ParticleEmitter")
mist.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
mist.Rate = 0
mist.Speed = NumberRange.new(3, 6)
mist.SpreadAngle = Vector2.new(60, 60)
mist.Lifetime = NumberRange.new(0.2, 0.4)
mist.Size = NumberSequence.new(0.3, 0)
mist.Transparency = NumberSequence.new(0.3, 1)
mist.Parent = a1
local foam = Instance.new("ParticleEmitter") -- soap foam where the jet hits mud
foam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
foam.Rate = 0
foam.Speed = NumberRange.new(1, 3)
foam.SpreadAngle = Vector2.new(80, 80)
foam.Lifetime = NumberRange.new(0.4, 0.8)
foam.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.15),
    NumberSequenceKeypoint.new(0.3, 0.35),
    NumberSequenceKeypoint.new(1, 0),
})
foam.Transparency = NumberSequence.new(0.1, 0.6)
foam.Acceleration = Vector3.new(0, -4, 0)
foam.Parent = a1

local crosshair = Kit.frame(Hud.wash.frame, "Crosshair", Theme.Colors.paper)
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Size = UDim2.fromOffset(24, 24)
crosshair.Visible = false
Kit.corner(crosshair, UDim.new(0.5, 0))
Kit.stroke(crosshair, Theme.Colors.outline, 3, true)

local function center(): CFrame
    local turntable = Ctx.station("Washer"):FindFirstChild("Turntable") :: BasePart
    local point = turntable:FindFirstChild("EggPoint") :: Attachment
    return CFrame.new(point.WorldPosition + Vector3.new(0, 0.3, 0)) * Ctx.plotRotation()
end

local function angle(): number
    return math.rad((Ctx.now() - info.washStart) * info.degPerSec)
end

local function spun(): CFrame
    return center() * CFrame.Angles(0, angle(), 0)
end

-- Same rules as the server (EggRules.facing / projected): +Z part of the normal after the turntable turn, and
-- where the chunk shows in the wash view on the unit egg
local function facing(n: Vector3): number
    local a = angle()
    return -n.X * math.sin(a) + n.Z * math.cos(a)
end

local function projected(n: Vector3): Vector2
    local a = angle()
    return Vector2.new(n.X * math.cos(a) + n.Z * math.sin(a), n.Y)
end

local function chunkPose(frame: CFrame, c: Chunk): (Vector3, CFrame)
    local localPos = c.normal * RADII
    local pos = frame:PointToWorldSpace(localPos)
    local dir = frame:VectorToWorldSpace(c.normal)
    return pos, CFrame.lookAt(pos, pos + dir, frame.UpVector)
end

local function cameraShot(): CFrame
    local c = center()
    local dir = c:VectorToWorldSpace(Vector3.new(0, 0.45, 1).Unit)
    return CFrame.lookAt(c.Position + dir * CAMERA_DISTANCE, c.Position)
end

local function clearChunks()
    for _, c in chunks do
        for _, p in c.parts do
            p:Destroy()
        end
    end
    chunks = {}
end

local function setProgress()
    if info then
        local clean = 0
        for _, c in chunks do
            clean += 1 - c.frac
        end
        Hud.setWashProgress(clean / math.max(#chunks, 1), info.zoneName)
    end
end

local function toScreen(pos: Vector3): UDim2
    local camera = Workspace.CurrentCamera
    local screen = camera:WorldToViewportPoint(pos)
    local inset = game:GetService("GuiService"):GetGuiInset()
    return UDim2.fromScale(screen.X / camera.ViewportSize.X, (screen.Y - inset.Y) / camera.ViewportSize.Y)
end

-- Flings one lump off the egg with a splat, foam and a floating number
local function knock(c: Chunk, big: boolean)
    local part = table.remove(c.parts, 1)
    if not part or not info then
        return
    end
    local pos = part.Position
    local out = (pos - center().Position).Unit
    Fx.tween(part, 0.35, {
        Position = pos + out * 2.2 + Vector3.new(0, -1.2, 0),
        Size = Vector3.zero,
        Orientation = part.Orientation + Vector3.new(180, 90, 0),
    })
    task.delay(0.36, function()
        part:Destroy()
    end)
    Fx.burst(pos, Fx.MUD[info.zone], if big then 16 else 8, if big then 14 else 9, if big then 0.5 else 0.35)
    Fx.burst(pos, Color3.fromRGB(255, 255, 255), 6, 4, 0.3, 0.6) -- foam puff
    Sfx.play("splat", (if big then 0.9 else 1.15) + 0.05 * combo, if big then 0.9 else 0.55)
    local pct = math.floor(100 / (info.chunks * Economy.BLOB_STAGES) + 0.5)
    Kit.floatingNumber(Hud.screen.root, "+" .. pct .. "%", Theme.Colors.money, toScreen(pos))
end

local function showCombo(n: number)
    combo = n
    if n >= 3 and os.clock() - comboLabelAt > 0.35 then
        comboLabelAt = os.clock()
        local label = if n >= Economy.COMBO_MAX then "MAX COMBO!" else "COMBO x" .. n
        Kit.floatingNumber(Hud.screen.root, label, Theme.Colors.reward, UDim2.fromScale(0.5, 0.3))
    end
end

-- Puts a wash egg on the turntable: the nest egg hops over (0.6 s) and grows to wash size
local function load(newInfo: any)
    clearChunks()
    info = newInfo
    local mine = Ctx.findEgg(newInfo.eggId)
    if mine then
        mine.state = "Washing"
    end
    local part = Nest.take(newInfo.eggId) or Fx.egg(newInfo.zone, newInfo.sparkle, 0.42)
    part.Color = Fx.MUD[newInfo.zone]:Lerp(Fx.SHELL, 0.55)
    egg = part
    local target = center().Position
    hopUntil = os.clock() + 0.6
    Fx.tween(part, 0.6, { Size = Fx.EGG_SIZE })
    Fx.arc(part, part.Position, target, 3, 0.6, 0)
    combo = 0
    for i, n in newInfo.normals do
        local frac = newInfo.hp[i] / newInfo.chunkHP
        local parts = {}
        for k = #LUMPS - math.ceil(frac * Economy.BLOB_STAGES - 1e-6) + 1, #LUMPS do
            local p = Fx.part("Mud", LUMP_SIZE * (if k == #LUMPS then 1.35 else 1), Fx.MUD[newInfo.zone])
            p.Material = Enum.Material.Mud
            p.Transparency = 1 -- shown once the hop lands
            p:SetAttribute("Lump", k)
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.Sphere
            mesh.Parent = p
            table.insert(parts, p)
        end
        table.insert(chunks, { parts = parts, normal = Vector3.new(n[1], n[2], n[3]), frac = frac, alive = frac > 0 })
    end
    Hud.showWash(true, newInfo.zone)
    setProgress()
    Ctx.emit("nest")
end

local function stopVisuals()
    beam.Enabled = false
    if hiss then
        hiss:Destroy()
        hiss = nil
    end
    Cam.clear("wash")
    Hud.showWash(false)
    crosshair.Visible = false
    local char = Players.LocalPlayer.Character
    if char then
        for _, d in char:GetDescendants() do
            if d:IsA("BasePart") then
                d.LocalTransparencyModifier = 0
            end
        end
    end
end

-- Leave the wash view. sendStop = tell the server (walked out / X), the egg goes back to the nest.
local function stop(sendStop: boolean)
    if not active then
        return
    end
    active = false
    Ctx.washing = false
    blockedUntil = math.huge
    if sendStop then
        task.spawn(Ctx.invoke, "StopWash")
        if info then
            local mine = Ctx.findEgg(info.eggId)
            if mine then
                mine.state = "Nest"
            end
        end
        if egg then
            egg:Destroy()
        end
    end
    egg = nil
    info = nil
    clearChunks()
    stopVisuals()
    Nest.refresh()
    Ctx.emit("nest")
end

local function start()
    pending = true
    local r = Ctx.invoke("StartWash")
    pending = false
    if not r.ok then
        if r.message == "Step into your washer!" then
            blockedUntil = os.clock() + 0.3 -- the server has not seen us arrive yet: retry quietly
            return
        end
        blockedUntil = os.clock() + 2
        Hud.toast(r.message, "error")
        Sfx.play("bonk")
        return
    end
    if Ctx.distanceTo("Washer") > RING_LEAVE then
        task.spawn(Ctx.invoke, "StopWash")
        return
    end
    active = true
    blockedUntil = 0
    Ctx.washing = true
    Hud.setBanner(nil)
    hiss = Sfx.loop("hiss", 0)
    local current = Workspace.CurrentCamera.CFrame
    Cam.set("wash", 10, function(dt)
        current = Cam.smooth(current, cameraShot(), dt, 9)
        return current
    end)
    cursor = Workspace.CurrentCamera.ViewportSize / 2
    load(r)
end

-- Aim point in viewport pixels, or nil when the player is not spraying
local function aimPoint(): (Vector2?, boolean)
    if touchPos then
        return touchPos, true
    end
    if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2) then
        return cursor, false
    end
    if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        return UserInputService:GetMouseLocation(), false
    end
    return nil, false
end

-- Ray from the camera through the aim point against the egg ellipsoid: world hit point and the aim point on
-- the unit egg (egg-local hit divided by the radii, in the unspun turntable frame), or nil
local function hitEgg(ray: Ray): (Vector3?, Vector2?)
    local frame = center()
    local o = frame:PointToObjectSpace(ray.Origin) / RADII
    local d = (frame:VectorToObjectSpace(ray.Direction) / RADII).Unit
    local b = o:Dot(d)
    local disc = b * b - (o:Dot(o) - 1)
    if disc < 0 then
        return nil, nil
    end
    local u = o + d * (-b - math.sqrt(disc))
    return frame:PointToWorldSpace(u * RADII), Vector2.new(u.X, u.Y)
end

local function spray(dt: number)
    local camera = Workspace.CurrentCamera
    local point, isTouch = aimPoint()
    local gamepad = UserInputService:GetLastInputType().Name:find("Gamepad") ~= nil
    crosshair.Visible = gamepad
    if gamepad then
        local stick = Vector2.zero
        for _, s in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
            if s.KeyCode == Enum.KeyCode.Thumbstick2 then
                stick = Vector2.new(s.Position.X, -s.Position.Y)
            end
        end
        if stick.Magnitude > 0.15 then
            cursor += stick * CURSOR_SPEED * dt
            cursor = Vector2.new(
                math.clamp(cursor.X, 0, camera.ViewportSize.X),
                math.clamp(cursor.Y, 0, camera.ViewportSize.Y)
            )
        end
        local inset = game:GetService("GuiService"):GetGuiInset()
        crosshair.Position =
            UDim2.fromScale(cursor.X / camera.ViewportSize.X, (cursor.Y - inset.Y) / camera.ViewportSize.Y)
    end
    if not point or Ctx.revealing or os.clock() < hopUntil or not info then
        beam.Enabled = false
        if hiss then
            hiss.Volume = 0
        end
        return
    end
    local ray = if isTouch
        then camera:ScreenPointToRay(point.X, point.Y)
        else camera:ViewportPointToRay(point.X, point.Y)
    local hit, aim = hitEgg(ray)
    nozzle.Position = (camera.CFrame * CFrame.new(1.2, -1.1, -2)).Position
    hitPart.Position = hit or (ray.Origin + ray.Direction.Unit * 12)
    beam.Enabled = true
    mist.Rate = if hit then 40 else 0
    foam.Rate = 0
    if hiss then
        hiss.Volume = 0.35
    end
    if os.clock() - lastSpray < SPRAY_EVERY then
        return
    end
    lastSpray = os.clock()
    if not aim then
        return
    end
    -- feedback only (the server judges): foam and a higher hiss while the jet is on visible mud
    local onMud = false
    for _, c in chunks do
        local near = (projected(c.normal) - aim).Magnitude <= Economy.AIM_RADIUS
        if c.alive and near and facing(c.normal) >= info.facingMin then
            onMud = true
        end
    end
    foam.Rate = if onMud then 60 else 0
    if hiss then
        hiss.PlaybackSpeed = if onMud then 1.25 else 1
    end
    sprayRemote:FireServer({ eggId = info.eggId, aim = { aim.X, aim.Y } })
end

local function onHit(eggId: number, id: number, frac: number, newCombo: number?)
    if not info or eggId ~= info.eggId then
        return
    end
    local c = chunks[id]
    if not c or not c.alive then
        return
    end
    c.frac = frac
    showCombo(newCombo or 0)
    while #c.parts > math.ceil(frac * Economy.BLOB_STAGES - 1e-6) do
        knock(c, false)
    end
    setProgress()
end

local function onPopped(eggId: number, id: number, newCombo: number?)
    if not info or eggId ~= info.eggId then
        return
    end
    local c = chunks[id]
    if not c or not c.alive then
        return
    end
    c.alive = false
    c.frac = 0
    showCombo(newCombo or 0)
    while #c.parts > 0 do
        knock(c, #c.parts == 1)
    end
    setProgress()
end

local function onDone(eggId: number)
    if not info or eggId ~= info.eggId or not egg then
        return
    end
    local part = egg :: BasePart
    for _, c in chunks do
        c.frac = 0
    end
    setProgress()
    clearChunks()
    foam.Rate = 0
    -- squeaky clean: the shell turns glossy, a white shine sweeps over it, sparkles, squeak + chime
    part.Color = Fx.SHELL
    part.Material = Enum.Material.SmoothPlastic
    part.Reflectance = 0.5
    Fx.tween(part, 0.8, { Reflectance = 0.05 })
    local shine = Instance.new("Highlight")
    shine.FillColor = Color3.new(1, 1, 1)
    shine.OutlineColor = Color3.fromRGB(255, 240, 150)
    shine.FillTransparency = 0.15
    shine.OutlineTransparency = 0
    shine.DepthMode = Enum.HighlightDepthMode.Occluded
    shine.Parent = part
    Fx.tween(shine, 0.7, { FillTransparency = 1, OutlineTransparency = 1 })
    local sweep = Fx.part("Shine", Vector3.new(0.25, Fx.EGG_SIZE.Y * 1.1, Fx.EGG_SIZE.Z * 1.05), Color3.new(1, 1, 1))
    sweep.Material = Enum.Material.Neon
    sweep.Transparency = 0.35
    local base = part.CFrame * CFrame.Angles(0, 0, math.rad(-25))
    sweep.CFrame = base * CFrame.new(-Fx.EGG_SIZE.X * 0.7, 0, 0)
    Fx.tween(sweep, 0.45, { CFrame = base * CFrame.new(Fx.EGG_SIZE.X * 0.7, 0, 0), Transparency = 0.9 })
    task.delay(0.5, function()
        sweep:Destroy()
        shine:Destroy()
    end)
    local sparkles = Instance.new("Sparkles")
    sparkles.SparkleColor = Color3.fromRGB(255, 250, 200)
    sparkles.Parent = part
    task.delay(1.2, function()
        sparkles.Enabled = false
    end)
    Fx.tween(part, 0.15, { Size = Fx.EGG_SIZE * 1.15 })
    task.delay(0.15, function()
        Fx.tween(part, 0.25, { Size = Fx.EGG_SIZE }, Enum.EasingStyle.Back)
    end)
    Fx.burst(part.Position, Color3.fromRGB(220, 240, 255), 24, 12, 0.4, 0.7)
    Hud.popWord("SQUEAKY CLEAN!", Theme.Colors.reward)
    Sfx.play("squeak", 1.1, 0.8)
    Sfx.play("chime")
    Hatch.handOver(eggId, part)
    egg = nil
    info = nil
end

function Wash.init()
    Ctx.remotes:WaitForChild("ChunkHit").OnClientEvent:Connect(onHit)
    Ctx.remotes:WaitForChild("ChunkPopped").OnClientEvent:Connect(onPopped)
    Ctx.remotes:WaitForChild("WashDone").OnClientEvent:Connect(onDone)
    Ctx.remotes:WaitForChild("WashLoaded").OnClientEvent:Connect(function(newInfo: any)
        if active then
            load(newInfo)
        else
            task.spawn(Ctx.invoke, "StopWash")
        end
    end)
    -- Nothing left to wash: leave the wash view once the reveal is over (or 1 s after a compact one)
    Ctx.on("hatched", function(r: any)
        if Ctx.waitingEggs() > 0 then
            return
        end
        task.wait(if r.mode == "full" then r.revealAt - Ctx.now() + r.revealSeconds else 1)
        if active and not info and Ctx.waitingEggs() == 0 then
            stop(false)
        end
    end)
    Hud.wash.close.Activated:Connect(function()
        stop(true)
    end)

    UserInputService.TouchStarted:Connect(function(input, processed)
        if active and not processed then
            touchPos = Vector2.new(input.Position.X, input.Position.Y)
        end
    end)
    UserInputService.TouchMoved:Connect(function(input)
        if touchPos then
            touchPos = Vector2.new(input.Position.X, input.Position.Y)
        end
    end)
    UserInputService.TouchEnded:Connect(function()
        touchPos = nil
    end)

    RunService.RenderStepped:Connect(function(dt)
        local d = Ctx.distanceTo("Washer")
        if d > RING_LEAVE then
            blockedUntil = 0
        end
        local retry = os.clock() >= blockedUntil and (blockedUntil == 0 or Ctx.waitingEggs() > 0)
        if not active and not pending and retry and d <= RING_ENTER and not Ctx.revealing then
            task.spawn(start)
        elseif active and d > RING_LEAVE then
            stop(true)
        end
        if not active then
            return
        end
        local char = Players.LocalPlayer.Character
        if char then -- keep the character out of the wash view
            for _, part in char:GetDescendants() do
                if part:IsA("BasePart") then
                    part.LocalTransparencyModifier = 1
                end
            end
        end
        Hud.wash.frame.Visible = not Ctx.revealing
        if info and egg and os.clock() >= hopUntil then
            local frame = spun()
            egg.CFrame = frame
            for _, c in chunks do
                if c.alive then
                    local _, cf = chunkPose(frame, c)
                    for _, p in c.parts do
                        local o = LUMPS[p:GetAttribute("Lump") :: number]
                        p.CFrame = cf * CFrame.new(o.X, o.Y, 0)
                        p.Transparency = 0
                    end
                end
            end
        end
        spray(dt)
    end)
end

return Wash
