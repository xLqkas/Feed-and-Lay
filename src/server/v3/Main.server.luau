--!strict
-- v3 server entry: saves (VS-2) and the egg pipeline (VS-5). Replaces the old MainGameServer flow, which
-- default.project.json keeps in the repo but maps with Enabled = false. Rules live in the pure modules
-- next to this script; this file only wires Roblox to them. Remote list: docs/ai/server-v3-notes.md.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Economy = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Economy"))
local SaveSchema = require(script.Parent.SaveSchema)
local SaveStore = require(script.Parent.SaveStore)
local EggService = require(script.Parent.EggService)
local EggRules = require(script.Parent.EggRules)

local MAX_PLOTS = 6
local AUTOSAVE_INTERVAL = 60
local UPDATE_INTERVAL = 0.1
local SHUTDOWN_WAIT = 25
local STATION_MAX_DY = 8 -- vertical slack for station distance checks
local RADIUS = { Ledge = Economy.LEDGE_RADIUS, Washer = Economy.WASHER_RADIUS }

-- Remotes: a new folder so the old client scripts (still waiting on ReplicatedStorage.Remotes) cannot collide
local folder = Instance.new("Folder")
folder.Name = "RemotesV3"
local events: { [string]: RemoteEvent } = {}
for _, name in { "ChunkPopped", "WashDone", "HatchResult", "WashLoaded" } do
    local ev = Instance.new("RemoteEvent")
    ev.Name = name
    ev.Parent = folder
    events[name] = ev
end
local sprayHits = Instance.new("UnreliableRemoteEvent")
sprayHits.Name = "SprayHits"
sprayHits.Parent = folder

-- Plots and stations. A station is tagged FLStation with attribute Kind; its plot is the nearest ancestor
-- (or itself) with a number attribute PlotId, or a model named PlayerBase_<n>.
local plotOf: { [Player]: number } = {}

local function plotIdOf(inst: Instance): number?
    local node: Instance? = inst
    while node and node ~= game do
        local id = node:GetAttribute("PlotId")
        if type(id) == "number" then
            return id
        end
        local n = string.match(node.Name, "^PlayerBase_(%d+)$")
        if n then
            return tonumber(n)
        end
        node = node.Parent
    end
    return nil
end

local function stationPosition(plotId: number, kind: string): Vector3?
    for _, s in CollectionService:GetTagged("FLStation") do
        if s:GetAttribute("Kind") == kind and plotIdOf(s) == plotId then
            if s:IsA("BasePart") then
                return s.Position
            elseif s:IsA("Model") then
                return s:GetPivot().Position
            end
        end
    end
    return nil
end

local function isNear(player: Player, kind: string): boolean
    local plotId = plotOf[player]
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not plotId or not hum or hum.Health <= 0 or not root or not root:IsA("BasePart") then
        return false
    end
    local pos = stationPosition(plotId, kind)
    if not pos then
        return false
    end
    local d = root.Position - pos
    return Vector2.new(d.X, d.Z).Magnitude <= RADIUS[kind] and math.abs(d.Y) <= STATION_MAX_DY
end

local rng = Random.new()
local svc = EggService.new({
    now = function()
        return Workspace:GetServerTimeNow()
    end,
    random = function()
        return rng:NextNumber()
    end,
    isNear = isNear :: any,
    send = function(player, event, ...)
        events[event]:FireClient(player, ...)
    end,
    goldenHour = function()
        return false -- shortcut: Golden Hour is P-5; read ReplicatedStorage.GameClock there
    end,
    log = function(msg)
        warn(msg)
    end,
})

for name, handler in svc.remotes do
    local rf = Instance.new("RemoteFunction")
    rf.Name = name
    rf.OnServerInvoke = handler
    rf.Parent = folder
end
sprayHits.OnServerEvent:Connect(function(player, payload)
    svc:sprayHits(player, payload)
end)
folder.Parent = ReplicatedStorage

-- Saving
local canSave: { [Player]: boolean } = {}

local function save(player: Player, data: SaveSchema.Data, release: boolean)
    local ok, why = SaveStore.save(player.UserId, data, release)
    if ok then
        return
    end
    if release then
        warn(
            "[V3] FINAL SAVE FAILED for "
                .. player.UserId
                .. " ("
                .. tostring(why)
                .. "): progress since the last autosave is lost"
        )
    else
        warn("[V3] autosave failed for " .. player.UserId .. " (" .. tostring(why) .. "), kept in memory")
        if why == "lock lost" and player.Parent then
            canSave[player] = false
            player:Kick("Your save was opened on another server. Please rejoin.")
        end
    end
end

local function placeAtSpawn(player: Player, char: Model)
    local plotId = plotOf[player]
    local spawnPos = plotId and stationPosition(plotId, "Spawn")
    if not spawnPos then
        return
    end
    char:WaitForChild("HumanoidRootPart", 5)
    local ledge = stationPosition(plotId :: number, "Ledge")
    local at = spawnPos + Vector3.new(0, 4, 0)
    char:PivotTo(if ledge then CFrame.lookAt(at, Vector3.new(ledge.X, at.Y, ledge.Z)) else CFrame.new(at))
end

local function onPlayerAdded(player: Player)
    local used = {}
    for _, id in plotOf do
        used[id] = true
    end
    for i = 1, MAX_PLOTS do
        if not used[i] then
            plotOf[player] = i
            break
        end
    end
    if not plotOf[player] then
        player:Kick("This sanctuary is full (6 players). Please join another server!")
        return
    end
    player:SetAttribute("PlotId", plotOf[player])

    for _, plot in CollectionService:GetTagged("FLPlot") do
        if plot:GetAttribute("PlotId") == plotOf[player] then
            player.RespawnLocation = plot:FindFirstChild("Spawn") :: SpawnLocation?
        end
    end

    -- Studio playtests of the new-player flow: set ServerStorage attribute FLFreshSaveInStudio = true
    local fresh = RunService:IsStudio() and ServerStorage:GetAttribute("FLFreshSaveInStudio") == true
    local data, status
    if fresh then
        warn("[V3] FLFreshSaveInStudio: fresh unsaved profile")
        data, status = SaveSchema.new(), "fresh"
    else
        data, status = SaveStore.load(player.UserId, function()
            return player.Parent ~= nil
        end)
    end
    if not player.Parent then
        if data and not fresh then
            SaveStore.releaseLock(player.UserId)
        end
        plotOf[player] = nil
        return
    end
    if data then
        canSave[player] = not fresh
    elseif status == "failed" and RunService:IsStudio() then
        warn("[V3] DataStore unavailable in Studio: playing with a fresh save that will NOT be saved")
        data = SaveSchema.new()
        canSave[player] = false
    else
        plotOf[player] = nil
        local why = {
            locked = "Your save is still open on another server. Try again in a minute.",
            newer = "This server is out of date. Please join another server.",
        }
        player:Kick(why[status] or "Could not load your save. Please rejoin in a moment.")
        return
    end

    svc:add(player, data :: SaveSchema.Data)
    player.CharacterAdded:Connect(function(char)
        placeAtSpawn(player, char)
    end)
    if player.Character then
        task.spawn(placeAtSpawn, player, player.Character)
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
    task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
    local data = svc:remove(player)
    plotOf[player] = nil
    if data and canSave[player] then
        save(player, data, true)
    end
    canSave[player] = nil
end)

game:BindToClose(function()
    local pending = 0
    for _, player in Players:GetPlayers() do
        local data = svc:remove(player) -- PlayerRemoving then finds nothing to save twice
        if data and canSave[player] then
            pending += 1
            task.spawn(function()
                save(player, data, true)
                pending -= 1
            end)
        end
    end
    local deadline = os.clock() + SHUTDOWN_WAIT
    while pending > 0 and os.clock() < deadline do
        task.wait(0.2)
    end
end)

task.spawn(function()
    while true do
        task.wait(AUTOSAVE_INTERVAL)
        for player, s in svc.players do
            if canSave[player] then
                task.spawn(save, player, s.data, false)
            end
        end
    end
end)

-- Pipeline timers and income, plus attributes the HUD reads (they replicate without a remote)
task.spawn(function()
    while true do
        task.wait(UPDATE_INTERVAL)
        svc:update()
        for player, s in svc.players do
            local d = s.data
            player:SetAttribute("Coins", math.floor(d.coins))
            player:SetAttribute("Strength", d.strength)
            player:SetAttribute("IncomePerSecond", EggRules.income(d))
            player:SetAttribute("NestUsed", #d.nest)
            player:SetAttribute("NestSlots", d.nestSlots)
        end
    end
end)

print("[EggSanctuary] v3 server loaded")
