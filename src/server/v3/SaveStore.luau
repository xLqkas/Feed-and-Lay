--!strict
-- Thin DataStore wrapper for SaveSchema (VS-2). The only v3 code that touches DataStores.
-- v7 store: read and write, with a session lock in the record. v6 and v5 stores: read only, once, to convert.
--
-- Failure behaviour:
-- * Load: lock write retried 3x with backoff; if another live server holds the lock it waits 5 s and retries
--   up to 6 times, then returns "locked". Any read failure returns "failed" (the caller kicks the player, or
--   in Studio plays without saving). It never falls back to a fresh save, so a hiccup cannot wipe pets.
-- * Save: UpdateAsync retried 4x (1, 2, 4 s backoff). On failure it returns false and the caller keeps the
--   data in memory and retries at the next autosave. If another server took the lock it refuses to write and
--   returns "lock lost" (that server has newer data); the caller then kicks the player.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local SaveSchema = require(script.Parent.SaveSchema)

local SaveStore = {}

SaveStore.V7_STORE = "EggSanctuary_SaveData_v7"
local LEGACY = {
    { name = "EggSanctuary_SaveData_v6", version = 6 },
    { name = "EggSanctuary_SaveData_v5", version = 5 },
}
local READ_ATTEMPTS = 3
local WRITE_ATTEMPTS = 4
local LOCK_ATTEMPTS = 6
local LOCK_RETRY_WAIT = 5

local jobId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)

local function keyFor(userId: number): string
    return "Player_" .. userId
end

local function getStore(name: string): DataStore?
    local ok, store = pcall(function()
        return DataStoreService:GetDataStore(name)
    end)
    return if ok then store else nil
end

local function retry(attempts: number, fn: () -> any): (boolean, any)
    local err
    for i = 1, attempts do
        local ok, res = pcall(fn)
        if ok then
            return true, res
        end
        err = res
        if i < attempts then
            task.wait(2 ^ (i - 1))
        end
    end
    return false, err
end

-- Best effort: drop our lock so the player can join another server at once
function SaveStore.releaseLock(userId: number)
    local store = getStore(SaveStore.V7_STORE)
    if not store then
        return
    end
    retry(READ_ATTEMPTS, function()
        return (store :: DataStore):UpdateAsync(keyFor(userId), function(old)
            if SaveSchema.lockState(old, jobId, os.time()) ~= "ours" then
                return nil
            end
            old.lock = nil
            return old
        end)
    end)
end

-- Returns data and "ok", or nil and "failed" | "locked" | "newer"
function SaveStore.load(userId: number, stillHere: () -> boolean): (SaveSchema.Data?, string)
    local store = getStore(SaveStore.V7_STORE)
    if not store then
        return nil, "failed"
    end
    local key = keyFor(userId)
    local record: any
    for attempt = 1, LOCK_ATTEMPTS do
        local blocked = false
        local ok, err = retry(READ_ATTEMPTS, function()
            return (store :: DataStore):UpdateAsync(key, function(old)
                blocked = SaveSchema.lockState(old, jobId, os.time()) == "other"
                if blocked then
                    return nil
                end
                local rec = if type(old) == "table" then old else {}
                rec.lock = { jobId = jobId, t = os.time() }
                record = rec
                return rec
            end)
        end)
        if not ok then
            warn("[SaveStore] v7 load failed for " .. userId .. ": " .. tostring(err))
            return nil, "failed"
        end
        if not blocked then
            break
        end
        if attempt == LOCK_ATTEMPTS or not stillHere() then
            return nil, "locked"
        end
        task.wait(LOCK_RETRY_WAIT)
    end

    local legacy, legacyVersion = nil, nil
    if not SaveSchema.isV3(record) then
        for _, src in LEGACY do
            local old = getStore(src.name)
            local ok, value = retry(READ_ATTEMPTS, function()
                return (assert(old, "no store") :: DataStore):GetAsync(key)
            end)
            if not ok then
                warn("[SaveStore] " .. src.name .. " read failed for " .. userId .. ": " .. tostring(value))
                SaveStore.releaseLock(userId)
                return nil, "failed"
            end
            if value ~= nil then
                legacy, legacyVersion = value, src.version
                break
            end
        end
    end

    local data, notes = SaveSchema.load(record, legacy, legacyVersion)
    for _, note in notes do
        warn("[SaveStore] " .. userId .. ": " .. note)
    end
    if not data then
        SaveStore.releaseLock(userId)
        return nil, "newer"
    end
    if legacyVersion then
        print("[SaveStore] converted v" .. legacyVersion .. " save for " .. userId .. " (" .. #data.pets .. " pets)")
    end
    return data, "ok"
end

-- Writes the data; release = true drops the lock (player leaving). Returns ok and a reason on failure.
function SaveStore.save(userId: number, data: SaveSchema.Data, release: boolean?): (boolean, string?)
    local store = getStore(SaveStore.V7_STORE)
    if not store then
        return false, "no DataStore"
    end
    local payload = SaveSchema.serialize(data) -- snapshot before yielding
    local lost = false
    local ok, err = retry(WRITE_ATTEMPTS, function()
        return (store :: DataStore):UpdateAsync(keyFor(userId), function(old)
            lost = SaveSchema.lockState(old, jobId, os.time()) == "other"
            if lost then
                return nil
            end
            local out = table.clone(payload)
            out.lock = if release then nil else { jobId = jobId, t = os.time() }
            return out
        end)
    end)
    if lost then
        return false, "lock lost"
    end
    if not ok then
        return false, tostring(err)
    end
    return true, nil
end

return SaveStore
