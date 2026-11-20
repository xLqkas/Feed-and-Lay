--!strict
-- The player's next goal after the tutorial (catchiness pass, design-v3 P-7) and the "next creature" target for
-- the HUD card. Pure: the caller passes a snapshot of client state. Tested by tests/Goals.spec.luau.

local Economy = if game then require(game:GetService("ReplicatedStorage").Modules.Economy) else require("./Economy")

local Goals = {}

export type State = {
    coins: number,
    strength: number,
    foodTier: number,
    nozzleLevel: number,
    dumbbellTier: number,
    nestSlots: number,
    found: { [string]: boolean },
    unclaimed: number,
    pity: { [number]: number },
    nestFull: boolean,
    waitingEggs: number,
}

export type Goal = { text: string, trail: string?, current: number?, target: number? }

export type Target = {
    creature: Economy.Creature,
    zone: Economy.Zone,
    locked: boolean, -- the zone is not reachable yet: the bar is Strength toward its gate
    current: number,
    target: number,
    caption: string,
}

type Upgrade = { track: string, name: string, cost: number, sign: string }

-- Next level of each upgrade track the player can still buy
function Goals.upgrades(s: State): { Upgrade }
    local list = {}
    local function add(track: string, current: number, name: string?, sign: string)
        local cost = Economy.upgradeCost(track, current)
        if cost and name then
            table.insert(list, { track = track, name = name, cost = cost, sign = sign })
        end
    end
    add("Nest", s.nestSlots, "Inventory slot " .. (s.nestSlots + 1), "Sign_Nest")
    local food = Economy.Foods[s.foodTier + 1]
    add("Food", s.foodTier, food and food.Name, "Sign_Food")
    local nozzle = Economy.Nozzles[s.nozzleLevel + 1]
    add("Nozzle", s.nozzleLevel, nozzle and nozzle.Name, "Sign_Nozzle")
    local bell = Economy.Dumbbells[s.dumbbellTier + 1]
    add("Dumbbell", s.dumbbellTier, bell and bell.Name, "Sign_Weights")
    table.sort(list, function(a, b)
        return a.cost < b.cost
    end)
    return list
end

-- The first creature in Book order the player has not found, with progress toward it, or nil when all are found
function Goals.nextCreature(s: State): Target?
    local reach = Economy.zoneForStrength(s.strength).Id
    for _, c in Economy.Creatures do
        if not s.found[c.Name] then
            local zone = Economy.Zones[c.Zone]
            if c.Zone > reach then
                return {
                    creature = c,
                    zone = zone,
                    locked = true,
                    current = s.strength,
                    target = zone.StrengthGate,
                    caption = "Strength " .. zone.StrengthGate .. " to reach " .. zone.Name,
                }
            end
            local missing = Economy.missingCreature(c.Zone, s.found) :: Economy.Creature
            local need = Economy.DISCOVERY_PITY[missing.Rarity]
            return {
                creature = missing,
                zone = zone,
                locked = false,
                current = math.min(s.pity[c.Zone] or 0, need),
                target = need,
                caption = "Hatch eggs from " .. zone.Name .. " to find it",
            }
        end
    end
    return nil
end

-- Repetitions of the current dumbbell needed to reach a Strength (perfect taps give 2 reps)
local function repsTo(s: State, strength: number): number
    return math.max(0, strength - s.strength) / Economy.strengthPerRep(s.dumbbellTier, 0)
end

-- The one goal the objective line shows after the tutorial. `fmt` formats coin amounts (1.2K).
function Goals.next(s: State, fmt: (number) -> string): Goal
    if s.unclaimed > 0 then
        return { text = "Claim your new creature in your Book!" }
    elseif s.waitingEggs > 0 then
        return { text = if s.nestFull then "Inventory full: wash an egg to throw again!" else "Wash an egg from your Inventory!", trail = "Washer" }
    end
    local ups = Goals.upgrades(s)
    for _, u in ups do
        if s.coins >= u.cost then
            return { text = "Buy " .. u.name .. " for " .. fmt(u.cost) .. "!", trail = u.sign }
        end
    end
    local cheapest = ups[1]
    if cheapest and s.coins >= cheapest.cost * 0.5 then
        return { text = "Almost there: " .. cheapest.name .. "!", current = s.coins, target = cheapest.cost }
    end
    local t = Goals.nextCreature(s)
    if t and t.locked and repsTo(s, t.target) <= 300 then
        return {
            text = "Lift to Strength " .. t.target .. " to reach " .. t.zone.Name .. "!",
            trail = "LiftBench",
            current = s.strength,
            target = t.target,
        }
    elseif t and not t.locked then
        return {
            text = "Find the " .. string.upper(t.creature.Rarity) .. " ??? in " .. t.zone.Name .. "!",
            trail = "Ledge",
        }
    elseif cheapest then
        return { text = "Save up for " .. cheapest.name .. "!", current = s.coins, target = cheapest.cost }
    end
    return { text = "Keep hatching! Every pet earns coins." }
end

return Goals
