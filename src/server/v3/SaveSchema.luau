--!strict
-- Save schema v7 (design-v3 VS-2). Pure: no Roblox services, tested by tests/SaveSchema.spec.luau.
-- Reads a v7 record or converts an old v5/v6 record, and cleans every field on load.
-- The DataStore wrapper (SaveStore.luau) is the only code that touches DataStores.

local Economy = if game
    then require(game:GetService("ReplicatedStorage").Modules.Economy)
    else require("../../shared/Economy")

local SaveSchema = {}

SaveSchema.VERSION = 7
SaveSchema.LOCK_STALE_AFTER = 300 -- seconds; autosave refreshes the lock every 60 s
SaveSchema.TUTORIAL_STEPS = 16

export type Pet = { id: number, species: string, mutation: string, pen: boolean }
-- Saved egg. At runtime EggRules adds state, arrivesAt, hp, washStart, lastHit; those are never saved.
export type Egg = { id: number, zone: number, species: string, mutation: string, sparkle: boolean, chunks: number }
export type Data = {
    version: number,
    coins: number,
    strength: number,
    foodTier: number,
    dumbbellTier: number,
    nestSlots: number,
    penSlots: number,
    nozzleLevel: number,
    rebirths: number,
    tutorialStep: number,
    pets: { Pet },
    nest: { Egg },
    book: { [string]: { found: boolean, claimed: boolean, mutations: { [string]: boolean } } },
    daily: { streak: number, lastDay: number },
    settings: { music: boolean, sfx: boolean, followThrows: boolean, reducedMotion: boolean },
    receipts: { [string]: boolean },
    stats: { throws: number, hatches: number },
    nextId: number,
    migratedFrom: number?,
}

local MUTATIONS = { Normal = true, Shiny = true, Golden = true, Rainbow = true }

function SaveSchema.new(): Data
    return {
        version = SaveSchema.VERSION,
        coins = 0,
        strength = Economy.START_STRENGTH,
        foodTier = 1,
        dumbbellTier = 1,
        nestSlots = Economy.START_NEST,
        penSlots = Economy.START_PEN,
        nozzleLevel = 1,
        rebirths = 0,
        tutorialStep = 0,
        pets = {},
        nest = {},
        book = {},
        daily = { streak = 0, lastDay = 0 },
        settings = { music = true, sfx = true, followThrows = false, reducedMotion = false },
        receipts = {},
        stats = { throws = 0, hatches = 0 },
        nextId = 1,
    }
end

-- A finite number clamped to [lo, hi], floored when int; anything else gives the default
local function num(v: any, default: number, lo: number, hi: number, int: boolean?): number
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
        return default
    end
    v = math.clamp(v, lo, hi)
    return if int then math.floor(v) else v
end

local function bool(v: any, default: boolean): boolean
    return if type(v) == "boolean" then v else default
end

local function income(pet: Pet): number
    return Economy.petIncome({ Species = pet.species, Mutation = pet.mutation })
end

-- Pen holds the best pets up to penSlots; keeps every pet (storage may exceed its cap rather than lose one)
local function fitPen(data: Data)
    local inPen = {}
    for _, p in data.pets do
        if p.pen then
            table.insert(inPen, p)
        end
    end
    if #inPen <= data.penSlots then
        return
    end
    table.sort(inPen, function(a, b)
        return income(a) > income(b)
    end)
    for i = data.penSlots + 1, #inPen do
        inPen[i].pen = false
    end
end

local function cleanMutation(v: any, notes: { string }, where: string): string
    if type(v) == "string" and MUTATIONS[v] then
        return v
    end
    if v ~= nil then
        table.insert(notes, where .. ": unknown mutation " .. tostring(v) .. " -> Normal")
    end
    return "Normal"
end

-- Cleans a v7-shaped table. Never errors; every bad field falls back to its default.
function SaveSchema.sanitize(raw: any): (Data, { string })
    local notes = {}
    local d = SaveSchema.new()
    if type(raw) ~= "table" then
        table.insert(notes, "record is not a table: started fresh")
        return d, notes
    end

    d.coins = num(raw.coins, 0, 0, 1e300)
    d.strength = num(raw.strength, Economy.START_STRENGTH, Economy.START_STRENGTH, 1e300)
    d.foodTier = num(raw.foodTier, 1, 1, #Economy.Foods, true)
    d.dumbbellTier = num(raw.dumbbellTier, 1, 1, #Economy.Dumbbells, true)
    d.nestSlots = num(raw.nestSlots, Economy.START_NEST, Economy.START_NEST, Economy.MAX_NEST, true)
    d.penSlots = num(raw.penSlots, Economy.START_PEN, Economy.START_PEN, Economy.MAX_PEN, true)
    d.nozzleLevel = num(raw.nozzleLevel, 1, 1, #Economy.Nozzles, true)
    d.rebirths = num(raw.rebirths, 0, 0, Economy.MAX_REBIRTHS, true)
    d.tutorialStep = num(raw.tutorialStep, 0, 0, SaveSchema.TUTORIAL_STEPS, true)
    if raw.migratedFrom == 5 or raw.migratedFrom == 6 then
        d.migratedFrom = raw.migratedFrom
    end

    local usedIds: { [number]: boolean } = {}
    local maxId = 0
    local needIds = {}
    local function claimId(v: any): number?
        local id = num(v, 0, 0, 2 ^ 52, true)
        if id < 1 or id ~= v or usedIds[id] then
            return nil
        end
        usedIds[id] = true
        maxId = math.max(maxId, id)
        return id
    end

    if type(raw.pets) == "table" then
        for _, p in raw.pets do
            if type(p) ~= "table" or type(p.species) ~= "string" or not Economy.CreatureByName[p.species] then
                table.insert(notes, "dropped pet with unknown species " .. tostring(type(p) == "table" and p.species))
                continue
            end
            local pet: Pet = {
                id = claimId(p.id) or 0,
                species = p.species,
                mutation = cleanMutation(p.mutation, notes, "pet"),
                pen = bool(p.pen, false),
            }
            if pet.id == 0 then
                table.insert(needIds, pet)
            end
            table.insert(d.pets, pet)
        end
    end

    if type(raw.nest) == "table" then
        for _, e in raw.nest do
            local c = type(e) == "table" and type(e.species) == "string" and Economy.CreatureByName[e.species]
            if not c then
                table.insert(notes, "dropped egg with unknown species")
                continue
            end
            if #d.nest >= Economy.MAX_NEST then
                table.insert(notes, "dropped egg beyond the largest nest")
                break
            end
            local egg: Egg = {
                id = claimId(e.id) or 0,
                zone = c.Zone, -- species decides the zone; a mismatching saved zone is ignored
                species = c.Name,
                mutation = cleanMutation(e.mutation, notes, "egg"),
                sparkle = c.Slot == "C",
                chunks = if e.chunks == Economy.TUTORIAL_CHUNKS
                    then Economy.TUTORIAL_CHUNKS
                    else Economy.CHUNKS_PER_EGG,
            }
            if egg.id == 0 then
                table.insert(needIds, egg)
            end
            table.insert(d.nest, egg)
        end
    end

    d.nextId = math.max(num(raw.nextId, 1, 1, 2 ^ 52, true), maxId + 1)
    for _, item in needIds do
        item.id = d.nextId
        d.nextId += 1
    end
    table.sort(d.pets, function(a, b)
        return a.id < b.id
    end)
    table.sort(d.nest, function(a, b)
        return a.id < b.id
    end)
    fitPen(d)

    if type(raw.book) == "table" then
        for species, entry in raw.book do
            if type(species) == "string" and Economy.CreatureByName[species] and type(entry) == "table" then
                local muts = {}
                if type(entry.mutations) == "table" then
                    for m, v in entry.mutations do
                        if type(m) == "string" and MUTATIONS[m] and v == true then
                            muts[m] = true
                        end
                    end
                end
                d.book[species] =
                    { found = bool(entry.found, false), claimed = bool(entry.claimed, false), mutations = muts }
            end
        end
    end

    if type(raw.daily) == "table" then
        d.daily.streak = num(raw.daily.streak, 0, 0, 7, true)
        d.daily.lastDay = num(raw.daily.lastDay, 0, 0, 1e9, true)
    end
    if type(raw.settings) == "table" then
        for k, v in d.settings do
            d.settings[k] = bool(raw.settings[k], v)
        end
    end
    if type(raw.receipts) == "table" then
        for k, v in raw.receipts do
            if type(k) == "string" and v then
                d.receipts[k] = true
            end
        end
    end
    if type(raw.stats) == "table" then
        d.stats.throws = num(raw.stats.throws, 0, 0, 1e15, true)
        d.stats.hatches = num(raw.stats.hatches, 0, 0, 1e15, true)
    end
    return d, notes
end

-- True when the record holds v3 data (a lock-only record written on first join does not count)
function SaveSchema.isV3(record: any): boolean
    return type(record) == "table" and type(record.version) == "number"
end

-- Converts an old record (v5 or v6 store, same shape) per owner decision 2.
-- Old currency, Strength, FoodTier, MaxSlots and CleanerUpgrades are dropped; every pet is kept.
function SaveSchema.fromLegacy(old: any, fromVersion: number): (Data, { string })
    local d = SaveSchema.new()
    local notes = {}
    if type(old) ~= "table" then
        return d, notes -- never played the old game
    end
    d.migratedFrom = fromVersion
    if type(old.GardenPets) == "table" then
        for _, p in old.GardenPets do
            if type(p) ~= "table" then
                table.insert(notes, "dropped non-table GardenPets entry")
                continue
            end
            local species = p.Name
            if type(species) ~= "string" or not Economy.CreatureByName[species] then
                table.insert(notes, "unknown old pet " .. tostring(species) .. " -> Meadow Bunny")
                species = "Meadow Bunny"
            end
            table.insert(d.pets, {
                id = d.nextId,
                species = species,
                mutation = cleanMutation(p.Mutation, notes, "old pet"),
                pen = false,
            })
            d.nextId += 1
        end
    end
    -- Best income first into the pen, the rest to storage
    local order = table.clone(d.pets)
    table.sort(order, function(a, b)
        local ia, ib = income(a), income(b)
        return if ia == ib then a.id < b.id else ia > ib
    end)
    for i, p in order do
        p.pen = i <= d.penSlots
    end
    return d, notes
end

-- Load entry point. v7 is the v7 store record; legacy is the old record and its version, read only when
-- v7 holds no v3 data. Returns nil when the record was written by a newer schema (do not touch it).
function SaveSchema.load(v7: any, legacy: any?, legacyVersion: number?): (Data?, { string })
    if SaveSchema.isV3(v7) then
        if v7.version > SaveSchema.VERSION then
            return nil, { "record is version " .. tostring(v7.version) .. ", newer than this server" }
        end
        return SaveSchema.sanitize(v7)
    end
    if legacy ~= nil then
        return SaveSchema.fromLegacy(legacy, legacyVersion or 6)
    end
    return SaveSchema.new(), {}
end

-- Plain table to store. Eggs keep only saved fields, so flying or half-washed eggs come back in the nest.
function SaveSchema.serialize(d: Data): { [string]: any }
    local pets = {}
    for _, p in d.pets do
        table.insert(pets, { id = p.id, species = p.species, mutation = p.mutation, pen = p.pen })
    end
    local nest = {}
    for _, e in d.nest do
        table.insert(nest, {
            id = e.id,
            zone = e.zone,
            species = e.species,
            mutation = e.mutation,
            sparkle = e.sparkle,
            chunks = e.chunks,
        })
    end
    local book = {}
    for species, entry in d.book do
        book[species] = { found = entry.found, claimed = entry.claimed, mutations = table.clone(entry.mutations) }
    end
    return {
        version = SaveSchema.VERSION,
        coins = d.coins,
        strength = d.strength,
        foodTier = d.foodTier,
        dumbbellTier = d.dumbbellTier,
        nestSlots = d.nestSlots,
        penSlots = d.penSlots,
        nozzleLevel = d.nozzleLevel,
        rebirths = d.rebirths,
        tutorialStep = d.tutorialStep,
        pets = pets,
        nest = nest,
        book = book,
        daily = table.clone(d.daily),
        settings = table.clone(d.settings),
        receipts = table.clone(d.receipts),
        stats = table.clone(d.stats),
        nextId = d.nextId,
        migratedFrom = d.migratedFrom,
    }
end

-- Session lock on the stored record: "free", "ours" or "other" (another live server holds it)
function SaveSchema.lockState(record: any, jobId: string, now: number): string
    local lock = type(record) == "table" and record.lock
    if type(lock) ~= "table" or type(lock.t) ~= "number" or now - lock.t > SaveSchema.LOCK_STALE_AFTER then
        return "free"
    end
    return if lock.jobId == jobId then "ours" else "other"
end

return SaveSchema
