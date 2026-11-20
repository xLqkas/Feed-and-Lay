--!strict
-- v3 server entry: saves (VS-2) and the egg pipeline (VS-5). Replaces the old MainGameServer flow, which
-- is moved to legacy/ and no longer mapped by default.project.json. Rules live in the pure modules
-- next to this script; this file only wires Roblox to them. Remote list: docs/ai/server-v3-notes.md.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
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
local RADIUS = { Ledge = Economy.LEDGE_RADIUS, Washer = Economy.WASHER_RADIUS, Lift = Economy.LIFT_RADIUS }

-- Remotes: a new folder so the old client scripts (still waiting on ReplicatedStorage.Remotes) cannot collide
local folder = Instance.new("Folder")
folder.Name = "RemotesV3"
local events: { [string]: RemoteEvent } = {}
for _, name in { "ChunkPopped", "ChunkHit", "WashDone", "HatchResult", "WashLoaded", "WashStopped" } do
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

local stationCache: { [number]: { [string]: Instance } } = {}
local cachedAs: { [Instance]: { plotId: number, kind: string } } = {}

local function forgetStation(s: Instance)
    local ref = cachedAs[s]
    if ref and stationCache[ref.plotId] and stationCache[ref.plotId][ref.kind] == s then
        stationCache[ref.plotId][ref.kind] = nil
    end
    cachedAs[s] = nil
end

local function cacheStation(s: Instance)
    local kind = s:GetAttribute("Kind")
    local plotId = plotIdOf(s)
    if type(kind) ~= "string" or not plotId then
        return
    end
    local old = cachedAs[s]
    if old and stationCache[old.plotId] and stationCache[old.plotId][old.kind] == s then
        stationCache[old.plotId][old.kind] = nil
    end
    local byKind = stationCache[plotId]
    if not byKind then
        byKind = {}
        stationCache[plotId] = byKind
    end
    byKind[kind] = s
    cachedAs[s] = { plotId = plotId, kind = kind }
end

for _, s in CollectionService:GetTagged("FLStation") do
    cacheStation(s)
end
CollectionService:GetInstanceAddedSignal("FLStation"):Connect(cacheStation)
CollectionService:GetInstanceRemovedSignal("FLStation"):Connect(forgetStation)

local function stationOf(plotId: number, kind: string): Instance?
    local byKind = stationCache[plotId]
    return if byKind then byKind[kind] else nil
end

local function stationPosition(plotId: number, kind: string): Vector3?
    local s = stationOf(plotId, kind)
    if s and s:IsA("BasePart") then
        return s.Position
    elseif s and s:IsA("Model") then
        return s:GetPivot().Position
    end
    return nil
end

-- The throw pad is the launch lane in the canyon, shared by every player; no plot involves it.
local function launchPad(): BasePart?
    local map = Workspace:FindFirstChild("EggSanctuaryMap")
    local ls = map and map:FindFirstChild("LaunchStation")
    local p = ls and ls:FindFirstChild("Pad")
    return if p and p:IsA("BasePart") then p else nil
end

local function onPad(root: BasePart): boolean
    local pad = launchPad()
    if not pad then
        return false
    end
    local p = pad.CFrame:PointToObjectSpace(root.Position)
    return math.abs(p.X) <= pad.Size.X / 2 + 0.5
        and math.abs(p.Z) <= pad.Size.Z / 2 + 0.5
        and p.Y >= 0
        and p.Y <= 6
end

local function isNear(player: Player, kind: string): boolean
    local plotId = plotOf[player]
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not plotId or not hum or hum.Health <= 0 or not root or not root:IsA("BasePart") then
        return false
    end
    if kind == "Ledge" then
        return onPad(root)
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
local saving: { [number]: boolean } = {}
local released: { [number]: boolean } = {}
local jobs: { [number]: any } = {}
local pendingSaves: { [number]: any } = {}
local saveSeq: { [number]: number } = {}
local loadedSeq: { [number]: number } = {}

local function nextSeq(userId: number): number
    local n = math.max((loadedSeq[userId] or 0) + 1, (saveSeq[userId] or 0) + 1, DateTime.now().UnixTimestampMillis)
    saveSeq[userId] = n
    return n
end

local function sessionStillHere(userId: number): boolean
    for _, p in Players:GetPlayers() do
        if p.UserId == userId then
            return true
        end
    end
    return false
end

local function clearSessionState(userId: number)
    released[userId] = nil
    saveSeq[userId] = nil
    loadedSeq[userId] = nil
    saving[userId] = nil
    jobs[userId] = nil
end

local function runSaveWorker(userId: number)
    if saving[userId] then
        return
    end
    saving[userId] = true
    task.spawn(function()
        while true do
            local job = jobs[userId]
            if not job then
                break
            end
            if not job.release and released[userId] then
                -- stale autosave queued just before the player left
                if jobs[userId] == job then
                    jobs[userId] = nil
                end
            else
                local ok, why
                local called, err = pcall(function()
                    ok, why = SaveStore.save(userId, job.data, job.release, job.seq)
                end)
                if not called then
                    ok, why = false, tostring(err)
                end
                if jobs[userId] == job then
                    jobs[userId] = nil
                end
                if ok then
                    pendingSaves[userId] = nil
                elseif job.release then
                    if why == "lock lost" or why == "newer save already written" then
                        pendingSaves[userId] = nil
                        warn("[V3] FINAL SAVE TERMINAL for " .. userId .. " (" .. tostring(why) .. "): dropped pending save")
                    else
                        pendingSaves[userId] = job
                        warn("[V3] FINAL SAVE FAILED for " .. userId .. " (" .. tostring(why) .. "): queued for retry")
                    end
                else
                    warn("[V3] autosave failed for " .. userId .. " (" .. tostring(why) .. "), kept in memory")
                    if why == "lock lost" and job.player.Parent then
                        canSave[job.player] = false
                        job.player:Kick("Your save was opened on another server. Please rejoin.")
                    end
                end
            end
        end
        saving[userId] = false
        if released[userId] and not pendingSaves[userId] and not sessionStillHere(userId) then
            clearSessionState(userId)
        elseif jobs[userId] then
            runSaveWorker(userId)
        end
    end)
end

local function enqueueSave(player: Player, data: SaveSchema.Data, release: boolean)
    local userId = player.UserId
    if release then
        released[userId] = true
    elseif released[userId] then
        return -- never write autosave data after this session was released
    end
    local old = jobs[userId]
    if old and old.release and not release then
        return -- an autosave must not replace a queued final save
    end
    jobs[userId] = { player = player, data = data, release = release, seq = nextSeq(userId) }
    runSaveWorker(userId)
end

local function retryPendingSave(userId: number)
    local job = pendingSaves[userId]
    if not job or saving[userId] or jobs[userId] then
        return
    end
    released[userId] = true
    job.seq = nextSeq(userId)
    jobs[userId] = job
    runSaveWorker(userId)
end

local function placeAtSpawn(player: Player, char: Model)
    local plotId = plotOf[player]
    local spawnPos = plotId and stationPosition(plotId, "Spawn")
    if not spawnPos then
        return
    end
    char:WaitForChild("HumanoidRootPart", 5)
    local pad = launchPad()
    local ledge = if pad then pad.Position else nil
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

    -- If this user left with a failed final save, flush it before loading. Never reuse in-session data.
    local userId = player.UserId
    if pendingSaves[userId] then
        retryPendingSave(userId)
    end
    local deadline = os.clock() + 10
    while (saving[userId] or jobs[userId] or pendingSaves[userId]) and os.clock() < deadline do
        task.wait(0.2)
    end
    if saving[userId] or jobs[userId] or pendingSaves[userId] then
        player:Kick("Your save is still finishing. Please rejoin in a moment.")
        return
    end
    released[userId] = false -- a new session may write autosaves again

    -- Studio playtests of the new-player flow: set ServerStorage attribute FLFreshSaveInStudio = true
    local fresh = RunService:IsStudio() and ServerStorage:GetAttribute("FLFreshSaveInStudio") == true
    local data, status, storedSeq
    if fresh then
        warn("[V3] FLFreshSaveInStudio: fresh unsaved profile")
        data, status = SaveSchema.new(), "fresh"
        loadedSeq[userId] = 0
    else
        data, status, storedSeq = SaveStore.load(player.UserId, function()
            return player.Parent ~= nil
        end)
        loadedSeq[userId] = storedSeq or 0
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
        warn("[V3] DataStore unavailable in Studio: fresh save will NOT persist. Fix: Game Settings > Security > Enable Studio Access to API Services, then stop and Play again.")
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
    -- Studio-only test hook: ServerStorage attribute FLDebugProfile (JSON) is merged into an unsaved profile at
    -- load, so play-mode tests can start a fresh player further along. Never read in a live server.
    local debugProfile = ServerStorage:GetAttribute("FLDebugProfile")
    if RunService:IsStudio() and not canSave[player] and type(debugProfile) == "string" then
        local decoded
        local ok = pcall(function()
            decoded = HttpService:JSONDecode(debugProfile)
        end)
        if ok and type(decoded) == "table" then
            local raw = SaveSchema.serialize(data)
            for k, v in decoded do
                raw[k] = v
            end
            data = SaveSchema.sanitize(raw)
            warn("[V3] FLDebugProfile applied (Studio test profile)")
        else
            warn("[V3] FLDebugProfile ignored (invalid JSON)")
        end
    end

    svc:add(player, data :: SaveSchema.Data)
    player.CharacterAdded:Connect(function(char)
        placeAtSpawn(player, char)
    end)
    player.CharacterRemoving:Connect(function()
        local s = svc:get(player)
        if s and s.rt.inWasher then
            EggRules.stopWash(s.data, s.rt)
            events.WashStopped:FireClient(player)
        end
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
        enqueueSave(player, data, true)
    end
    canSave[player] = nil
end)

game:BindToClose(function()
    for _, player in Players:GetPlayers() do
        local ok, err = pcall(function()
            local data = svc:remove(player) -- PlayerRemoving then finds nothing to save twice
            if data and canSave[player] then
                enqueueSave(player, data, true)
            end
        end)
        if not ok then
            warn("[V3] BindToClose save enqueue failed for " .. player.UserId .. ": " .. tostring(err))
        end
    end
    for userId in pendingSaves do
        local ok, err = pcall(retryPendingSave, userId)
        if not ok then
            warn("[V3] BindToClose pending retry failed for " .. userId .. ": " .. tostring(err))
        end
    end
    local deadline = os.clock() + SHUTDOWN_WAIT
    while os.clock() < deadline do
        local busy, waiting = 0, 0
        for _, active in saving do
            if active then
                busy += 1
            end
        end
        for userId in pendingSaves do
            waiting += 1
            local ok, err = pcall(retryPendingSave, userId)
            if not ok then
                warn("[V3] BindToClose pending retry failed for " .. userId .. ": " .. tostring(err))
            end
        end
        if busy == 0 and waiting == 0 then
            break
        end
        task.wait(0.2)
    end
end)

task.spawn(function()
    while true do
        task.wait(AUTOSAVE_INTERVAL)
        for player, s in svc.players do
            local ok, err = pcall(function()
                if canSave[player] and not released[player.UserId] then
                    enqueueSave(player, s.data, false)
                end
            end)
            if not ok then
                warn("[V3] autosave enqueue failed for " .. player.UserId .. ": " .. tostring(err))
            end
        end
        for userId in pendingSaves do
            local ok, err = pcall(retryPendingSave, userId)
            if not ok then
                warn("[V3] pending retry failed for " .. userId .. ": " .. tostring(err))
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
            player:SetAttribute("TutorialStep", d.tutorialStep)
            player:SetAttribute("FoodTier", d.foodTier)
            player:SetAttribute("NozzleLevel", d.nozzleLevel)
            player:SetAttribute("DumbbellTier", d.dumbbellTier)
        end
    end
end)

print("[EggSanctuary] v3 server loaded")
