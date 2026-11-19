--!strict
-- EggService (design-v3 VS-5): remote handlers for the egg pipeline, on top of EggRules.
-- Pure apart from the injected deps, so tests/EggService.spec.luau drives it with a fake clock.
-- Every RemoteFunction handler: player loaded, per-player cooldown, busy flag, type checks, pcall,
-- reply { ok, message, ... }.

local Economy = if game
    then require(game:GetService("ReplicatedStorage").Modules.Economy)
    else require("../../shared/Economy")
local EggRules = if game then require(script.Parent.EggRules) else require("./EggRules")

export type Deps = {
    now: () -> number, -- server time (workspace:GetServerTimeNow())
    random: () -> number, -- uniform [0, 1)
    isNear: (player: any, kind: string) -> boolean, -- alive and at their own station of that Kind
    send: (player: any, event: string, ...any) -> (), -- RemoteEvent to that player only
    goldenHour: () -> boolean,
    log: (msg: string) -> (),
}

-- Spam cooldowns per remote (seconds). Game rules (throw cooldown etc.) live in Economy.
local COOLDOWNS = {
    GetState = 0.5,
    StartCharge = 0.25,
    ReleaseThrow = 0.25,
    StartWash = 0.5,
    StopWash = 0.25,
}
local SPRAY_MIN_GAP = 0.05 -- drop SprayHits faster than 20 Hz outright; damage is capped by dt anyway

local EggService = {}
EggService.__index = EggService
EggService.COOLDOWNS = COOLDOWNS

function EggService.new(deps: Deps)
    local self = setmetatable({ deps = deps, players = {} :: { [any]: any } }, EggService)
    local remotes = {}
    for name in COOLDOWNS do
        remotes[name] = self:_wrap(name, (EggService :: any)["_" .. name])
    end
    self.remotes = remotes
    return self
end

function EggService:add(player: any, data: any)
    EggRules.prepare(data)
    self.players[player] = {
        data = data,
        rt = EggRules.newRuntime(self.deps.now()),
        last = {},
        busy = {},
        lastSpray = -math.huge,
    }
end

-- Removes the player and returns their data for the final save (eggs in flight are saved as in the nest)
function EggService:remove(player: any): any
    local s = self.players[player]
    self.players[player] = nil
    return s and s.data
end

function EggService:get(player: any): any
    return self.players[player]
end

function EggService:_wrap(name: string, fn: any)
    return function(player: any, ...: any)
        local s = self.players[player]
        if not s then
            return { ok = false, message = "Still loading, one moment!" }
        end
        if s.busy[name] then
            return { ok = false, message = "Busy, one moment!" }
        end
        local now = self.deps.now()
        if now - (s.last[name] or -math.huge) < COOLDOWNS[name] then
            return { ok = false, message = "Slow down!" }
        end
        s.last[name] = now
        s.busy[name] = true
        local ok, reply = pcall(fn, self, player, s, now, ...)
        s.busy[name] = false
        if not ok then
            self.deps.log("[EggService] " .. name .. " failed: " .. tostring(reply))
            return { ok = false, message = "Something went wrong. Try again!" }
        end
        return reply
    end
end

-- Client-safe view of the player's state. Nest eggs never include species or mutation.
function EggService:snapshot(s: any, now: number): { [string]: any }
    local d, rt = s.data, s.rt
    local nest = {}
    for _, egg in d.nest do
        table.insert(nest, {
            id = egg.id,
            zone = egg.zone,
            state = egg.state,
            sparkle = egg.sparkle,
            chunks = egg.chunks,
            arrivesAt = if egg.state == "Flight" then egg.arrivesAt else nil,
        })
    end
    local pets = {}
    for _, p in d.pets do
        local c = Economy.CreatureByName[p.species]
        table.insert(pets, {
            id = p.id,
            species = p.species,
            mutation = p.mutation,
            rarity = c.Rarity,
            pen = p.pen,
            income = Economy.petIncome({ Species = p.species, Mutation = p.mutation }),
        })
    end
    local washing
    for _, egg in d.nest do
        if egg.id == rt.washingId then
            washing = EggRules.washInfo(egg, d.nozzleLevel)
        end
    end
    return {
        ok = true,
        message = "",
        serverTime = now,
        coins = d.coins,
        strength = d.strength,
        incomePerSecond = EggRules.income(d),
        foodTier = d.foodTier,
        dumbbellTier = d.dumbbellTier,
        nozzleLevel = d.nozzleLevel,
        nestSlots = d.nestSlots,
        penSlots = d.penSlots,
        rebirths = d.rebirths,
        tutorialStep = d.tutorialStep,
        stats = table.clone(d.stats),
        settings = table.clone(d.settings),
        nest = nest,
        pets = pets,
        washing = washing,
        revealUntil = rt.revealUntil,
    }
end

function EggService:_GetState(_player: any, s: any, now: number)
    EggRules.advance(s.data, now)
    return self:snapshot(s, now)
end

function EggService:_StartCharge(player: any, s: any, now: number)
    if not self.deps.isNear(player, "Ledge") then
        return { ok = false, message = "Walk to your ledge to throw!" }
    end
    EggRules.advance(s.data, now)
    local ok, msg = EggRules.startCharge(s.data, s.rt, now)
    return { ok = ok, message = msg, startedAt = if ok then now else nil }
end

function EggService:_ReleaseThrow(player: any, s: any, now: number, clientElapsed: any)
    if clientElapsed ~= nil and (type(clientElapsed) ~= "number" or clientElapsed ~= clientElapsed) then
        s.rt.chargeStart = nil
        return { ok = false, message = "Bad request." }
    end
    if not self.deps.isNear(player, "Ledge") then
        s.rt.chargeStart = nil
        return { ok = false, message = "Walk to your ledge to throw!" }
    end
    EggRules.advance(s.data, now)
    return EggRules.release(
        s.data,
        s.rt,
        now,
        clientElapsed,
        self.deps.random(),
        self.deps.random(),
        self.deps.goldenHour()
    )
end

function EggService:_StartWash(player: any, s: any, now: number)
    if not self.deps.isNear(player, "Washer") then
        return { ok = false, message = "Step into your washer!" }
    end
    return EggRules.startWash(s.data, s.rt, now)
end

function EggService:_StopWash(_player: any, s: any, _now: number)
    EggRules.stopWash(s.data, s.rt)
    return { ok = true, message = "" }
end

-- SprayHits (UnreliableRemoteEvent): payload { eggId = number, aim = { x, y } } (see EggRules.spray). No reply.
function EggService:sprayHits(player: any, payload: any)
    local s = self.players[player]
    if not s or type(payload) ~= "table" or type(payload.eggId) ~= "number" then
        return
    end
    local now = self.deps.now()
    if now - s.lastSpray < SPRAY_MIN_GAP then
        return
    end
    s.lastSpray = now
    local ok, err = pcall(function()
        if not self.deps.isNear(player, "Washer") then
            return
        end
        local popped = EggRules.spray(s.data, s.rt, now, payload.eggId, payload.aim)
        for _, id in popped or {} do
            self.deps.send(player, "ChunkPopped", payload.eggId, id)
        end
    end)
    if not ok then
        self.deps.log("[EggService] SprayHits failed: " .. tostring(err))
    end
end

-- Call often (10 Hz). Lands eggs, finishes washes, pushes hatch results, loads the next egg, pays income.
function EggService:update()
    local now = self.deps.now()
    for player, s in self.players do
        local ok, err = pcall(function()
            local events = EggRules.update(s.data, s.rt, now)
            for _, ev in events do
                self.deps.send(player, ev[1], ev[2])
            end
        end)
        if not ok then
            self.deps.log("[EggService] update failed: " .. tostring(err))
        end
    end
end

return EggService
