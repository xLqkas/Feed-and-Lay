# Task for OpenCode: fix the egg growth review findings

Owner: OpenCode, in the open Studio place "Feed an Lay". Do NOT publish, commit or push. Save only when the user says so. Do not touch SaveStore or the save mutex/pendingSaves logic. Gemini is redesigning the plots right now (moving Washer, LiftBench, HatchPad, Nest as whole models; removing signs and the ODDS board; adding a shared Food Shop with Loop.FoodShop and changes to Goals, Loop.Trail and the Loop.Main hint lines). Do not touch those modules or Workspace plot parts. If a fix needs them, write it down.

The architect reviewed egg growth (read-only). Remotes, timer, secrecy, schema and instant-hatch removal passed. Fix these, in this order:

## HIGH
1. **Clean eggs can be washed again.** A clean egg is only `state = "Nest"` with all chunk hp at 0, and there's no server flag. `oldestInNest` (EggRules ~311-318), `startWash(wantId)` (~320-343) and the washer auto-load (~572) can reload it. `loadEgg` (~299) resets washStart, so `snapshot().clean` (EggService ~131) goes false, and PlaceEgg says "Wash it clean first!".
   Fix: set `egg.clean = true` where washing finishes (EggRules ~565). Skip clean eggs in `oldestInNest`, `startWash` and the auto-load. `GrowthRules.canPlace` (~76) and `snapshot().clean` read the flag.
2. **Clean status isn't saved.** `SaveSchema.serialize` (~419-427) and `sanitize` (~222-232) drop it, so after a rejoin a clean unplaced egg is dirty again. Fix: save `clean: boolean?` on the egg (default false, sanitize to a boolean), separate from hp.

## MEDIUM
3. **Storage cap ignores growing eggs.** `EggRules.canThrow` (~142) counts `#pets + #nest`. Add `+ #data.growth`, so storage can't go past Economy.STORAGE when growing eggs hatch into storage.
4. **A hatch that errors loses the egg.** `hatchGrowth` (~546) removes the growth record before `grantHatch` runs, and `grantHatch` can assert (~470). Remove the record only after `grantHatch` succeeds, or put it back on failure.
5. **Income multiplier minimum.** Economy ~569-572 clamps it to 0.90-1.35. The brief (and the user) said 1.0-1.35: a new light pet must never earn less than an old pet without weight. Set GROWTH_INCOME_MIN = 1.0 (TODO-BALANCE stays).

## LOW
6. `_EquipBest` (EggService ~354-355) ranks pets with `petIncome` and leaves out weight/rarity. Pass `Weight` and `Rarity` so Equip Best picks the real best set.
7. Menus ~449: the client sell confirm calls `petSellValue` without weight, so the confirm threshold is too low. Pass the pet's weight. (The server value is already right.)
8. SaveSchema `startedAt` is only clamped to [1, 1e12] (~275). On load, also cap it at `os.time()`, so a future value can't block a spot for years. Growth records with a duplicate eggId (~260-264) or a bad start time (~256) are dropped. Repair them instead (new id; start time = now) so a real egg isn't lost.
9. The dead `EggRules.hatch` (the old instant hatch): grep for callers. If none, delete it.

## Not a bug, leave as is
- `currentWeight` in GrowthState lets a client work out the final weight early. The species stays secret, and that's what matters. Keep it.
- No plot-proximity check on PlaceEgg/Hatch: that matches the user's "from everywhere" decision.

## Also check what you marked "not verified" last time
Tap/click/Space skip during the letter reveal, touch on the growth-spot prompt (Device Simulator phone), FLReduceMotion and sound on the growth/READY/reveal.

## Test (Play Solo + Device Simulator phone)
1. Wash an egg clean, then go back to the washer: it doesn't reload the clean egg, and it takes the next dirty one.
2. Clean egg, then leave and rejoin (API Services on, no no-save flag): it's still clean and can be placed.
3. Fill storage, grow 4 eggs, hatch all: storage never goes past the cap. Throwing is blocked when full, as before.
4. Force a grantHatch error (Studio only, temporary): the egg is still in its spot afterwards. Remove the forced error.
5. A light pet's income is >= the same species without weight. Equip Best puts the highest-weight pets on the plot.
6. Old save still loads. A save with startedAt in the future loads with the spot growing from now.
7. No new errors. Studio back in Edit mode (check the Studio state).

## Report
Per item: script, lines, change, test result (anything not run = "not verified"). Update the CHANGES.md bundle for a re-check.
