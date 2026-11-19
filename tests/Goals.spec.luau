-- Tests for src/shared/Goals.luau (post-tutorial goal line and next-creature card).
-- Run: lune run tests/Goals.spec.luau
local Economy = require("../src/shared/Economy")
local Goals = require("../src/shared/Goals")

local checks = 0
local function check(ok: any, msg: string)
    assert(ok, "FAIL: " .. msg)
    checks += 1
end
local function fmt(n: number): string
    return tostring(n)
end
local function state(over: { [string]: any }): Goals.State
    local s: any = {
        coins = 0,
        strength = 50,
        foodTier = 1,
        nozzleLevel = 1,
        dumbbellTier = 1,
        nestSlots = 3,
        found = { ["Moss Turtle"] = true, ["Meadow Bunny"] = true },
        unclaimed = 0,
        pity = {},
        nestFull = false,
        waitingEggs = 0,
    }
    for k, v in over do
        s[k] = v
    end
    return s
end

-- Never a tutorial line
local tutorial = {
    "Walk to the ledge!",
    "Hold to throw food to Mama Hen!",
    "Wash your muddy egg!",
    "Watch Mama Hen eat!",
    "Throw again, or wash your eggs!",
}
local function notTutorial(g: Goals.Goal)
    for _, line in tutorial do
        check(g.text ~= line, "no tutorial line: " .. g.text)
    end
end

-- 1. Claims first, then a blocked nest, then an affordable upgrade (cheapest first)
local g = Goals.next(state({ unclaimed = 1, coins = 1e9 }), fmt)
check(g.text:find("Book"), "unclaimed entry first")
g = Goals.next(state({ nestFull = true, waitingEggs = 2, coins = 1e9 }), fmt)
check(g.trail == "Washer", "full nest sends to the washer")
g = Goals.next(state({ coins = 600 }), fmt)
check(g.text == "Buy Carrot for 500!" and g.trail == "Sign_Food", "cheapest affordable upgrade: " .. g.text)
notTutorial(g)

-- 2. Nearly affordable: a count goal with a bar
g = Goals.next(state({ coins = 300 }), fmt)
check(g.current == 300 and g.target == 500, "almost-there bar toward the cheapest upgrade")

-- 3. Next creature: Clover Fawn in the Meadow with its discovery meter
local t = Goals.nextCreature(state({ pity = { [1] = 3 } })) :: Goals.Target
check(t.creature.Name == "Clover Fawn" and not t.locked, "next creature is the missing Meadow one")
check(t.current == 3 and t.target == Economy.DISCOVERY_PITY.Rare, "bar is the discovery meter")
g = Goals.next(state({ coins = 10 }), fmt)
check(g.trail == "Ledge" and g.text:find("RARE"), "goal: throw into the Meadow for the rare ???")
notTutorial(g)

-- 4. Meadow complete: Bog Frog behind the Marsh gate, Strength bar and the Lift Bench
local all = { ["Moss Turtle"] = true, ["Meadow Bunny"] = true, ["Clover Fawn"] = true }
t = Goals.nextCreature(state({ found = all })) :: Goals.Target
check(t.creature.Name == "Bog Frog" and t.locked and t.target == 80, "Bog Frog locked behind Strength 80")
g = Goals.next(state({ found = all, coins = 10 }), fmt)
check(g.trail == "LiftBench" and g.current == 50 and g.target == 80, "lift goal with Strength bar")

-- 5. A far gate (Volcano at Strength 800 with Twig Weights) points at saving instead of 750 reps
local marsh = table.clone(all)
for _, name in { "Bog Frog", "Slime Drake", "Lily Croc" } do
    marsh[name] = true
end
g = Goals.next(state({ found = marsh, strength = 90, coins = 10, foodTier = 6, nozzleLevel = 5, nestSlots = 8 }), fmt)
check(g.text:find("Save up") and g.target == 50e3, "far gate: save up for Stone Weights (" .. g.text .. ")")

-- 6. Everything found: no card
local every = {}
for _, c in Economy.Creatures do
    every[c.Name] = true
end
check(Goals.nextCreature(state({ found = every })) == nil, "all found: no next creature")

print(string.format("PASS Goals (%d checks)", checks))
return true
