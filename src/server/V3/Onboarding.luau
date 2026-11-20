--!strict
-- Onboarding steps 1-15 (design-v3 section 5, VS-10). Pure: each step completes from saved state (plus two
-- live facts), so a step can never be missed and a returning player resumes where they were. The client
-- shows the banner, trail and HUD for data.tutorialStep (player attribute TutorialStep).
-- Step 16 ("You're a Sanctuary Keeper!") is the last saved value: it means onboarding is done.

local Economy = if game
    then require(game:GetService("ReplicatedStorage").Modules.Economy)
    else require("../../shared/Economy")

local Onboarding = {}
Onboarding.DONE = 16

export type Facts = { onLedge: boolean, lifting: boolean, revealing: boolean }

local function claimed(data: any, zone: number?): number
    local n = 0
    for species, entry in data.book do
        if entry.claimed and (not zone or Economy.CreatureByName[species].Zone == zone) then
            n += 1
        end
    end
    return n
end

local function found(data: any, zone: number): boolean
    for species, entry in data.book do
        if entry.found and Economy.CreatureByName[species].Zone == zone then
            return true
        end
    end
    return false
end

local function anyEgg(data: any, state: string): boolean
    for _, egg in data.nest do
        if egg.state == state then
            return true
        end
    end
    return false
end

-- Completion test for each step (design-v3 section 5 table, "Completes when")
local DONE: { (data: any, f: Facts) -> boolean } = {
    function(d, f) -- 1 Walk to the ledge
        return f.onLedge or d.stats.throws > 0
    end,
    function(d) -- 2 Hold to throw
        return d.stats.throws > 0
    end,
    function(d) -- 3 Watch Mama Hen eat: egg lands in the nest
        return anyEgg(d, "Nest") or anyEgg(d, "Washing") or d.stats.hatches > 0
    end,
    function(d) -- 4 Wash your muddy egg: wash started
        return anyEgg(d, "Washing") or d.stats.hatches > 0
    end,
    function(d) -- 5 Spray all the mud off
        return d.stats.hatches > 0
    end,
    function(_, f) -- 6 It's hatching: reveal ends
        return not f.revealing
    end,
    function(d) -- 7 Claim it in your Book
        return claimed(d) >= 1
    end,
    function(d) -- 8 Throw 2 more eggs
        return d.stats.throws >= 3
    end,
    function(d) -- 9 Wash your eggs: both hatched
        return d.stats.hatches >= 3
    end,
    function(d) -- 10 Buy a bigger nest
        return d.nestSlots >= 3
    end,
    function(d, f) -- 11 Train at the Lift Bench: lift started
        return f.lifting or d.strength > Economy.START_STRENGTH
    end,
    function(d) -- 12 Lift until Strength 80
        return d.strength >= Economy.Zones[2].StrengthGate
    end,
    function(d) -- 13 Throw into the Bog Marsh: a Marsh egg hatched
        return found(d, 2)
    end,
    function(d) -- 14 Claim your new creature (a Marsh one)
        return claimed(d, 2) >= 1
    end,
    function(d) -- 15 Buy Carrots
        return d.foodTier >= 2
    end,
}

-- Advances data.tutorialStep as far as the state allows. Returns true when it changed.
function Onboarding.advance(data: any, facts: Facts): boolean
    local before = data.tutorialStep
    if data.tutorialStep < 1 then
        data.tutorialStep = 1
    end
    while data.tutorialStep < Onboarding.DONE and DONE[data.tutorialStep](data, facts) do
        data.tutorialStep += 1
    end
    return data.tutorialStep ~= before
end

return Onboarding
