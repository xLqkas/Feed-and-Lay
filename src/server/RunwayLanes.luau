--!strict
-- RunwayLanes: Server module for Runway Lane management (phase0 Step 2)
-- Pure, unwired module: ready for OpenCode to integrate into Main after egg growth.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RunwayLanes = {}

-- Store auto-throw lane holds: [laneId] = player
local autoThrowHolders: { [number]: Player } = {}

-- Cache of lane pads by laneId
local lanePads: { [number]: BasePart } = {}

local function findLanesFolder(): Folder?
    local map = Workspace:FindFirstChild("EggSanctuaryMap")
    local ls = map and map:FindFirstChild("LaunchStation")
    local rf = ls and ls:FindFirstChild("RunwayLanes")
    return if rf and rf:IsA("Folder") then rf else nil
end

local function refreshCache()
    local folder = findLanesFolder()
    if not folder then return end
    for _, child in folder:GetChildren() do
        if child:IsA("BasePart") and CollectionService:HasTag(child, "FLLane") then
            local id = child:GetAttribute("LaneId")
            if type(id) == "number" then
                lanePads[id] = child
            end
        end
    end
end

-- Get lane assigned to player (PlotId -> LaneId)
function RunwayLanes.laneFor(player: Player): number?
    local plotId = player:GetAttribute("PlotId")
    if type(plotId) == "number" and plotId >= 1 and plotId <= 6 then
        return plotId
    end
    return nil
end

-- Get lane start pad part for a laneId
function RunwayLanes.padFor(laneId: number): BasePart?
    if not lanePads[laneId] or not lanePads[laneId].Parent then
        refreshCache()
    end
    return lanePads[laneId]
end

-- Check if a character position / root part is within the lane box
-- Replaces shared onPad check with per-lane bounding box (+0.5 stud margin)
function RunwayLanes.isInLane(root: BasePart, laneId: number): boolean
    local pad = RunwayLanes.padFor(laneId)
    if not pad then
        return false
    end
    local p = pad.CFrame:PointToObjectSpace(root.Position)
    return math.abs(p.X) <= pad.Size.X / 2 + 0.5
        and math.abs(p.Z) <= pad.Size.Z / 2 + 0.5
        and p.Y >= -0.2
        and p.Y <= 6
end

-- Teleport CFrame facing down the runway (+Z) for a lane
function RunwayLanes.teleportCFrame(laneId: number): CFrame?
    local pad = RunwayLanes.padFor(laneId)
    if not pad then
        return nil
    end
    -- Stand on pad, facing forward (+Z down the canyon)
    local pos = pad.Position + Vector3.new(0, 3, 0)
    return CFrame.lookAt(pos, pos + Vector3.new(0, 0, 10))
end

-- Auto-throw reservation: holds the lane while active
function RunwayLanes.claimAutoThrow(player: Player, laneId: number): boolean
    local current = autoThrowHolders[laneId]
    if current and current ~= player and current.Parent then
        return false -- already held by another player
    end
    autoThrowHolders[laneId] = player
    return true
end

function RunwayLanes.releaseAutoThrow(player: Player, laneId: number)
    if autoThrowHolders[laneId] == player then
        autoThrowHolders[laneId] = nil
    end
end

function RunwayLanes.autoThrowHolder(laneId: number): Player?
    local holder = autoThrowHolders[laneId]
    if holder and not holder.Parent then
        autoThrowHolders[laneId] = nil
        return nil
    end
    return holder
end

-- Clean up on player disconnect
Players.PlayerRemoving:Connect(function(player)
    for laneId, holder in autoThrowHolders do
        if holder == player then
            autoThrowHolders[laneId] = nil
        end
    end
end)

return RunwayLanes
