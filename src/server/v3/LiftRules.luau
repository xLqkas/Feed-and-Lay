--!strict
-- Lift Bench rules (design-v3 3.1, VS-9). Pure: the caller passes the clock (server time) and the seed.
-- The server owns the ring schedule and judges every tap by time, so a fixed-interval autoclicker lands in
-- the hit window only by chance. Tested by tests/LiftRules.spec.luau.

local Economy = if game
    then require(game:GetService("ReplicatedStorage").Modules.Economy)
    else require("../../shared/Economy")

local LiftRules = {}

export type Session = {
    id: number,
    seed: number,
    k: number, -- current ring index
    startAt: number, -- current ring shows (starts shrinking) at this time
    T: number, -- current ring shrink time
    lastTap: number,
    lastRepAt: number,
    reps: { number }, -- times of accepted reps in the last 10 minutes
    perfects: { boolean }, -- last accepted reps, newest last (perfect = true)
}

local function ring(sess: Session, k: number, after: number)
    local gap, T = Economy.liftRing(sess.seed, k)
    sess.k, sess.startAt, sess.T = k, after + gap, T
end

function LiftRules.start(now: number, id: number, seed: number): Session
    local sess: Session = {
        id = id,
        seed = seed,
        k = 0,
        startAt = 0,
        T = 1,
        lastTap = now,
        lastRepAt = -math.huge,
        reps = {},
        perfects = {},
    }
    ring(sess, 1, now)
    return sess
end

function LiftRules.ringInfo(sess: Session): { [string]: number }
    return { index = sess.k, startAt = sess.startAt, duration = sess.T }
end

-- Rings nobody tapped time out at 1 + LIFT_LATE of their shrink time; the next one follows after its gap
function LiftRules.advance(sess: Session, now: number)
    while now > sess.startAt + sess.T * (1 + Economy.LIFT_LATE) do
        ring(sess, sess.k + 1, sess.startAt + sess.T * (1 + Economy.LIFT_LATE))
    end
end

-- One tap. clientElapsed is the client's time since the ring showed; it is used only when it is within the
-- latency tolerance of the server's own value. Returns the reply fields (result, gained, message, ring).
function LiftRules.tap(data: any, sess: Session, now: number, ringIndex: any, clientElapsed: any): { [string]: any }
    LiftRules.advance(sess, now)
    sess.lastTap = now
    local elapsed = now - sess.startAt
    if
        ringIndex == sess.k
        and type(clientElapsed) == "number"
        and math.abs(clientElapsed - elapsed) <= Economy.ELAPSED_TOLERANCE
    then
        elapsed = clientElapsed
    end
    local result = if elapsed < 0 then "miss" else Economy.liftJudge(elapsed, sess.T)

    local message = ""
    if result ~= "miss" then
        while sess.reps[1] and now - sess.reps[1] > 600 do
            table.remove(sess.reps, 1)
        end
        local lastMinute = 0
        for _, t in sess.reps do
            if now - t <= 60 then
                lastMinute += 1
            end
        end
        if now - sess.lastRepAt < Economy.LIFT_MIN_REP_GAP then
            result = "miss"
        elseif lastMinute >= Economy.LIFT_MAX_PER_MINUTE or #sess.reps >= Economy.LIFT_MAX_PER_10_MIN then
            result, message = "miss", "Take a breather!"
        end
    end
    if result == "perfect" then
        local count = 0
        for _, p in sess.perfects do
            if p then
                count += 1
            end
        end
        if count >= Economy.LIFT_PERFECT_MAX then
            result = "good" -- scripted perfects stop paying double
        end
    end

    local gained = 0
    if result ~= "miss" then
        gained = (if result == "perfect" then 2 else 1) * Economy.strengthPerRep(data.dumbbellTier, data.rebirths)
        data.strength += gained
        sess.lastRepAt = now
        table.insert(sess.reps, now)
        table.insert(sess.perfects, result == "perfect")
        if #sess.perfects >= Economy.LIFT_PERFECT_WINDOW then
            table.remove(sess.perfects, 1) -- keep 49 so the next rep makes a window of 50
        end
    end
    ring(sess, sess.k + 1, now)
    return { result = result, gained = gained, message = message, strength = data.strength }
end

return LiftRules
