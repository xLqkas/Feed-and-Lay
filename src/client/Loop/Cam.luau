--!strict
-- Camera owners: throw cam, wash view and hatch reveal each register a function; the highest priority wins.
-- With no owner the default follow camera comes back. Also camera shake and FOV punches (off in reduced motion).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Ctx = require(script.Parent.Ctx)

export type Shot = (dt: number) -> CFrame

local Cam = {}
local owners: { [string]: { priority: number, shot: Shot } } = {}
local controlling = false
local shakeUntil, shakeAmp = 0, 0
local BASE_FOV = 70

function Cam.set(name: string, priority: number, shot: Shot)
    owners[name] = { priority = priority, shot = shot }
end

function Cam.clear(name: string)
    owners[name] = nil
end

function Cam.active(name: string): boolean
    return owners[name] ~= nil
end

-- Exponential smoothing toward a target camera frame (Quint-out feel without tweens)
function Cam.smooth(current: CFrame, target: CFrame, dt: number, speed: number?): CFrame
    return current:Lerp(target, 1 - math.exp(-(speed or 8) * dt))
end

function Cam.shake(seconds: number, amplitude: number)
    if Ctx.reducedMotion() then
        return
    end
    shakeUntil = os.clock() + seconds
    shakeAmp = amplitude
end

function Cam.fov(target: number, seconds: number)
    if Ctx.reducedMotion() and target ~= BASE_FOV then
        return
    end
    local camera = Workspace.CurrentCamera
    TweenService:Create(camera, TweenInfo.new(seconds, Enum.EasingStyle.Quad), { FieldOfView = target }):Play()
end

-- FOV punch 70 -> to -> 70 (rare reveals)
function Cam.punch(to: number)
    Cam.fov(to, 0.12)
    task.delay(0.15, function()
        Cam.fov(BASE_FOV, 0.4)
    end)
end

RunService:BindToRenderStep("FLCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
    local camera = Workspace.CurrentCamera
    local best
    for _, o in owners do
        if not best or o.priority > best.priority then
            best = o
        end
    end
    if best then
        controlling = true
        camera.CameraType = Enum.CameraType.Scriptable
        local ok, cf = pcall(best.shot, dt)
        if ok then
            camera.CFrame = cf
        end
    elseif controlling then
        controlling = false
        camera.CameraType = Enum.CameraType.Custom
        local root = Ctx.root()
        if root then -- come back behind the character, not at the last scripted angle
            local back = root.CFrame.LookVector * Vector3.new(1, 0, 1)
            camera.CFrame = CFrame.lookAt(root.Position - back.Unit * 14 + Vector3.new(0, 7, 0), root.Position)
        end
    end
    if os.clock() < shakeUntil then
        local a = shakeAmp
        camera.CFrame *= CFrame.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
    end
end)

return Cam
