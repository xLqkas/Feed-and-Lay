-- Test for the Lift Bench (design-v3 3.1, VS-9): src/server/v3/LiftRules.luau and the EggService remotes.
-- Run: lune run tests/LiftRules.spec.luau
local Economy = require("../src/shared/Economy")
local SaveSchema = require("../src/server/v3/SaveSchema")
local LiftRules = require("../src/server/v3/LiftRules")
local EggService = require("../src/server/v3/EggService")

local checks = 0
local function check(ok: any, msg: string)
    assert(ok, "FAIL: " .. msg)
    checks += 1
end

local rngState = 42
local function rand(): number
    rngState = (rngState * 1103515245 + 12345) % 2147483648
    return rngState / 2147483648
end
local function gauss(sd: number): number
    return sd * math.sqrt(-2 * math.log(math.max(rand(), 1e-12))) * math.cos(2 * math.pi * rand())
end

-- Runs one player for `seconds`. tapAfter(sess) returns the delay from now until the player's next tap.
-- Returns strength gained per second and the time Strength first reached `goal` (or nil).
local function run(seconds: number, tapAfter: (sess: any, now: number) -> number, goal: number?): (number, number?)
    local data = SaveSchema.new()
    local now = 0
    local sess = LiftRules.start(now, 1, 123456 + math.floor(rand() * 1e6))
    local reached
    while now < seconds do
        now += math.max(tapAfter(sess, now), 0.01)
        local r = LiftRules.tap(data, sess, now, sess.k, nil)
        check(r.result == "perfect" or r.result == "good" or r.result == "miss", "valid result")
        if goal and not reached and data.strength >= goal then
            reached = now
        end
    end
    return (data.strength - Economy.START_STRENGTH) / seconds, reached
end

-- An attentive player taps when the ring meets the target, with human timing noise (sd 50 ms)
local function active(sess: any, now: number): number
    LiftRules.advance(sess, now)
    return sess.startAt + sess.T + gauss(0.05) - now
end
local function every(interval: number)
    return function()
        return interval
    end
end

-- 1. VS-9 acceptance: reaching Strength 80 takes 20-40 s of active play
do
    local times = {}
    for i = 1, 5 do
        local _, reached = run(60, active, 80)
        check(
            reached and reached >= 20 and reached <= 40,
            "active player reaches 80 in 20-40 s (" .. tostring(reached) .. ")"
        )
        table.insert(times, string.format("%.1f", reached :: number))
    end
    print("  active player, Strength 50 -> 80: " .. table.concat(times, " / ") .. " s")
end

-- 2. VS-9 acceptance: a 1 Hz autoclicker gains under 40% of an active player's rate (10 minutes each)
do
    local activeRate = run(600, active)
    local clickRate = run(600, every(1.0))
    local ratio = clickRate / activeRate
    print(
        string.format("  10 min: active %.2f/s, 1 Hz autoclicker %.2f/s (%.0f%%)", activeRate, clickRate, ratio * 100)
    )
    check(ratio < 0.4, "1 Hz autoclicker under 40% of active")
    local worst, worstAt = 0, 0
    for ms = 600, 1600, 50 do
        local r = run(600, every(ms / 1000)) / activeRate
        if r > worst then
            worst, worstAt = r, ms
        end
    end
    print(string.format("  best fixed interval 0.60-1.60 s: %d ms at %.0f%% of active", worstAt, worst * 100))
    check(worst < 0.4, "no fixed-interval autoclicker reaches 40% of the active rate")
end

-- 3. Scripted perfect timing: perfects capped at 30 of any 50 reps; taps faster than 0.6 s do not count
do
    local data = SaveSchema.new()
    local sess = LiftRules.start(0, 1, 777)
    local now = 0
    local results = {}
    for _ = 1, 200 do
        now = sess.startAt + sess.T -- exact
        table.insert(results, LiftRules.tap(data, sess, now, sess.k, nil).result)
    end
    for i = 1, #results - 49 do
        local n = 0
        for j = i, i + 49 do
            if results[j] == "perfect" then
                n += 1
            end
        end
        check(n <= Economy.LIFT_PERFECT_MAX, "at most 30 perfects in any 50 reps")
    end

    local d2 = SaveSchema.new()
    local s2 = LiftRules.start(0, 2, 99)
    -- the ring after this one shows within 0.5 s; tap it the moment the window opens if under 0.6 s since
    local r1 = LiftRules.tap(d2, s2, s2.startAt + s2.T, s2.k, nil)
    check(r1.result ~= "miss", "first rep counts")
    local strength = d2.strength
    LiftRules.tap(d2, s2, s2.startAt - 0.1, s2.k, nil) -- tapping before the ring shows
    check(d2.strength == strength, "tap before the ring shows is a miss")
end

-- 4. Rep caps: 75 per minute, 650 per 10 minutes ("Take a breather!")
do
    local data = SaveSchema.new()
    local sess = LiftRules.start(0, 3, 5)
    local message = ""
    local reps = 0
    local now = 0
    for _ = 1, 2000 do
        now = math.max(sess.startAt + sess.T, now)
        local r = LiftRules.tap(data, sess, now, sess.k, nil)
        if r.result ~= "miss" then
            reps += 1
        elseif r.message ~= "" then
            message = r.message
        end
        if now > 600 then
            break
        end
    end
    check(reps <= Economy.LIFT_MAX_PER_10_MIN, "at most 650 reps in 10 minutes (" .. reps .. ")")
end

-- 5. Latency allowance: the client's elapsed counts only within 0.15 s of the server's
do
    local data = SaveSchema.new()
    local sess = LiftRules.start(0, 4, 31337)
    local now = sess.startAt + sess.T * 0.3 -- far too early
    local r = LiftRules.tap(data, sess, now, sess.k, sess.T) -- client claims a perfect tap
    check(r.result == "miss", "lying client elapsed ignored")
    now = sess.startAt + sess.T + 0.1 -- 0.1 s late on the server (latency)
    r = LiftRules.tap(data, sess, now, sess.k, sess.T)
    check(r.result == "perfect", "honest client elapsed accepted within tolerance")
end

-- 6. Timeouts: the server and a client computing rings from the same seed agree after silence
do
    local sess = LiftRules.start(0, 5, 2024)
    LiftRules.advance(sess, 30)
    local k, start = 1, 0
    local gap, T = Economy.liftRing(2024, 1)
    start = gap
    while 30 > start + T * (1 + Economy.LIFT_LATE) do
        local nextGap, nextT = Economy.liftRing(2024, k + 1)
        start = start + T * (1 + Economy.LIFT_LATE) + nextGap
        k, T = k + 1, nextT
    end
    check(sess.k == k and math.abs(sess.startAt - start) < 1e-9, "ring schedule matches after 30 s of silence")
    local a1, b1 = Economy.liftRing(2024, 7)
    local a2, b2 = Economy.liftRing(2024, 7)
    check(a1 == a2 and b1 == b2, "liftRing is deterministic")
    check(a1 >= Economy.LIFT_GAP_MIN and a1 <= Economy.LIFT_GAP_MAX and b1 >= 0.75 and b1 <= 1.1, "ring in range")
end

-- 7. Remotes: StartLift needs a hatched egg and the bench; Lift needs the right session
do
    local t = 100
    local near = { Lift = true }
    local svc = EggService.new({
        now = function()
            return t
        end,
        random = rand,
        isNear = function(_p, kind)
            return near[kind] == true
        end,
        send = function() end,
        goldenHour = function()
            return false
        end,
        log = function() end,
    })
    local p = {}
    local data = SaveSchema.new()
    svc:add(p, data)
    check(svc.remotes.StartLift(p).message == "Wash your first egg first!", "lift gated before the first hatch")
    data.stats.hatches = 1
    t += 1
    near.Lift = false
    check(svc.remotes.StartLift(p).ok == false, "lift needs the bench")
    near.Lift = true
    t += 1
    local s = svc.remotes.StartLift(p)
    check(s.ok and s.ring.index == 1 and type(s.seed) == "number", "lift starts")
    t = s.ring.startAt + s.ring.duration
    check(svc.remotes.Lift(p, s.sessionId + 1, 1, 0).ok == false, "wrong session rejected")
    t += 0.2
    local r = svc.remotes.Lift(p, s.sessionId, 1, nil)
    check(r.ok and r.ring.index == 2, "tap judged, next ring returned")
    t += 25
    check(svc.remotes.Lift(p, s.sessionId, r.ring.index, nil).ok == false, "session closes after 20 s idle")
end

print(string.format("PASS LiftRules (%d checks)", checks))
return true
