--!strict
-- Glowing arrow trail (design-v3 section 5): chevrons on the ground from the character to the current
-- objective, path from PathfindingService every 0.5 s (straight line if it fails), a bobbing chevron above
-- the target, hidden within 4 studs of it. Chevrons near the camera fade so they never hide the character.

local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Ctx = require(script.Parent.Ctx)
local Fx = require(script.Parent.Fx)

local Trail = {}
local SPACING = 1.6
local MAX_CHEVRONS = 40
local HIDE_WITHIN = 4
local CYAN = Color3.fromRGB(80, 230, 255)

local target: string? = nil -- station name in the player's plot
local points: { Vector3 } = {}
local chevrons: { Model } = {}
local beacon: Model? = nil

-- A chevron: two thin neon bars in a V pointing along -Z of its CFrame
local function chevron(scale: number): Model
    local m = Instance.new("Model")
    m.Name = "TrailChevron"
    for _, side in { -1, 1 } do
        local bar = Fx.part("Bar", Vector3.new(0.35, 0.12, 1.3) * scale, CYAN)
        bar.Material = Enum.Material.Neon
        bar.CastShadow = false
        bar:SetAttribute("Offset", side)
        bar.Parent = m
    end
    m.Parent = Fx.folder
    return m
end

local function place(m: Model, cf: CFrame, scale: number, transparency: number)
    for _, bar in m:GetChildren() do
        local p = bar :: BasePart
        local side = p:GetAttribute("Offset") :: number
        p.CFrame = cf * CFrame.new(side * 0.42 * scale, 0, 0) * CFrame.Angles(0, math.rad(35 * side), 0) -- tips meet at the front
        p.Transparency = transparency
    end
end

local function goal(): Vector3?
    local plot = Ctx.plot
    local station = target and plot and plot:FindFirstChild(target)
    if not station or not station:IsA("Model") then
        return nil
    end
    return station:GetPivot().Position
end

local function floorAt(p: Vector3): Vector3
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { Fx.folder, Ctx.player.Character :: Instance }
    local hit = Workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
    return if hit then hit.Position + Vector3.new(0, 0.12, 0) else p
end

local function recompute()
    local root = Ctx.root()
    local to = goal()
    if not root or not to then
        points = {}
        return
    end
    local from = root.Position - Vector3.new(0, 2.8, 0)
    local waypoints = { from, to }
    local path = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentCanJump = true })
    local ok = pcall(path.ComputeAsync, path, from, to)
    if ok and path.Status == Enum.PathStatus.Success then
        waypoints = {}
        for _, w in path:GetWaypoints() do
            table.insert(waypoints, w.Position)
        end
    end
    -- resample the polyline every SPACING studs
    local out = {}
    local carry = 0
    for i = 1, #waypoints - 1 do
        local a, b = waypoints[i], waypoints[i + 1]
        local seg = (b - a) * Vector3.new(1, 0, 1)
        local len = seg.Magnitude
        local d = carry
        while d < len and #out < MAX_CHEVRONS do
            table.insert(out, floorAt(a + (b - a) * (d / len)))
            d += SPACING
        end
        carry = d - len
    end
    points = out
end

-- Point the trail at a station in the player's plot (nil hides it)
function Trail.set(stationName: string?)
    if stationName == target then
        return
    end
    target = stationName
    task.spawn(recompute)
end

function Trail.init()
    beacon = chevron(1.8)
    task.spawn(function()
        while true do
            task.wait(0.5)
            recompute()
        end
    end)
    RunService.RenderStepped:Connect(function()
        local root = Ctx.root()
        local to = goal()
        local show = root ~= nil and to ~= nil and not Ctx.washing and not Ctx.lifting
        local near = show
            and (((root :: BasePart).Position - (to :: Vector3)) * Vector3.new(1, 0, 1)).Magnitude <= HIDE_WITHIN
        local count = if show and not near then #points else 0
        local camPos = Workspace.CurrentCamera.CFrame.Position
        local t = os.clock()
        for i = 1, math.max(count, #chevrons) do
            if i > count then
                if chevrons[i] then
                    place(chevrons[i], CFrame.new(0, -500, 0), 1, 1)
                end
            else
                chevrons[i] = chevrons[i] or chevron(1)
                local p = points[i]
                local nextP = points[i + 1] or (to :: Vector3)
                local dir = (nextP - p) * Vector3.new(1, 0, 1)
                if dir.Magnitude < 0.01 then
                    dir = Vector3.new(0, 0, -1)
                end
                local at = p
                local wave = 0.5 + 0.5 * math.sin(i * 0.9 - t * 8) -- pulse runs toward the target
                local fade = math.clamp(((at - camPos).Magnitude - 4) / 6, 0, 1)
                place(chevrons[i], CFrame.lookAt(at, at + dir), 1, 1 - fade * (0.35 + 0.5 * wave))
            end
        end
        if beacon then
            if show and to then
                local top = (to :: Vector3) + Vector3.new(0, 5 + math.sin(t * 3) * 0.5, 0)
                -- point down: lay the V in a vertical plane facing the camera
                local face = CFrame.lookAt(top, top + Vector3.new(0, -1, 0), (camPos - top) * Vector3.new(1, 0, 1))
                place(beacon, face, 1.8, 0.1)
            else
                place(beacon, CFrame.new(0, -500, 0), 1.8, 1)
            end
        end
    end)
end

return Trail
