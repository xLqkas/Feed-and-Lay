-- Test for src/server/v3/Onboarding.luau (design-v3 section 5, VS-10). Run: lune run tests/Onboarding.spec.luau
local SaveSchema = require("../src/server/v3/SaveSchema")
local Onboarding = require("../src/server/v3/Onboarding")

local checks = 0
local function check(ok: any, msg: string)
    assert(ok, "FAIL: " .. msg)
    checks += 1
end

local d = SaveSchema.new()
local f = { onLedge = false, lifting = false, revealing = false }
local function step(): number
    Onboarding.advance(d, f)
    return d.tutorialStep
end

check(step() == 1, "fresh save starts at step 1")
f.onLedge = true
check(step() == 2, "1 -> 2 on the ledge")
d.stats.throws = 1
d.nest = { { state = "Flight" } }
check(step() == 3, "2 -> 3 after the first throw")
d.nest[1].state = "Nest"
check(step() == 4, "3 -> 4 when the egg lands")
d.nest[1].state = "Washing"
check(step() == 5, "4 -> 5 when the wash starts")
d.nest = {}
d.stats.hatches = 1
d.book["Moss Turtle"] = { found = true, claimed = false, mutations = {} }
f.revealing = true
check(step() == 6, "5 -> 6 when hatched, held while the reveal plays")
f.revealing = false
check(step() == 7, "6 -> 7 when the reveal ends")
d.book["Moss Turtle"].claimed = true
check(step() == 8, "7 -> 8 after the first claim")
d.stats.throws = 3
check(step() == 9, "8 -> 9 after 2 more throws")
d.stats.hatches = 3
check(step() == 10, "9 -> 10 when both hatched")
d.nestSlots = 3
check(step() == 11, "10 -> 11 after buying nest slot 3")
f.lifting = true
check(step() == 12, "11 -> 12 when lifting")
d.strength = 80
check(step() == 13, "12 -> 13 at Strength 80")
d.book["Bog Frog"] = { found = true, claimed = false, mutations = {} }
check(step() == 14, "13 -> 14 after a Marsh hatch")
d.book["Bog Frog"].claimed = true
check(step() == 15, "14 -> 15 after the Marsh claim")
d.foodTier = 2
check(step() == Onboarding.DONE, "15 -> 16 after buying Carrot")
check(not Onboarding.advance(d, f), "stays done")

-- Saved step survives a save round trip, and a returning player resumes there
local back = assert(SaveSchema.load(SaveSchema.serialize(d)))
check(back.tutorialStep == Onboarding.DONE, "step saved")
local mid = SaveSchema.new()
mid.tutorialStep = 9
mid.stats.throws, mid.stats.hatches = 3, 1
Onboarding.advance(mid, { onLedge = false, lifting = false, revealing = false })
check(mid.tutorialStep == 9, "returning player resumes at the saved step")

print(string.format("PASS Onboarding (%d checks)", checks))
return true
