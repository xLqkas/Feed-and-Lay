# Task: Egg growth (phase0 decision 2): washed eggs grow on the plot, then hatch

Owner: OpenCode (it knows the pet, save and pen code from the last rounds). Start only after the user has saved the place with the Animals round in it. Gemini is building the ODDS board (Loop.OddsBoard, client only) at the same time: do not edit its module; it only reads Economy, so adding the growth section to Economy is fine. Do NOT publish, commit or push; save only when the user says so. Do not touch SaveStore or the save mutex/pendingSaves logic.

Balance: the user said use your proposed numbers now and balance later. Every number is a named constant marked TODO-BALANCE.

## What changes for the player
Today: wash an egg to 100% and it hatches straight away with a reveal.
New:
1. Wash an egg to 100%. It becomes a "clean egg" (no reveal yet).
2. The player places it on a free growth spot on their plot (tap the spot, or the clean egg goes to the next free spot automatically if the player walks to the plot; pick one and say which).
3. The egg grows: a timer above it ("2:14"), it slowly gets bigger and shows its weight in kg counting up.
4. When the timer ends, "READY!" with a bounce and glow. The player taps/walks to it and it hatches: the existing reveal, plus a letter-by-letter name reveal (blanks fill in one at a time, about 1.5 s, tick sound per letter, tap to skip).
5. The hatched pet's size and income scale with the final weight.

## Numbers (from the repo's src/shared/Economy.luau growth section; TODO-BALANCE)
- Grow time by rarity: Common 30 s, Uncommon 60 s, Rare 120 s, Epic 300 s, Legendary 900 s, Mythic 1800 s, Secret 3600 s (only for rarities the game actually has).
- Weight roll by rarity ranges (for example Common 0.8-1.6 kg ... Mythic 50-120 kg), `rollEggWeight`.
- Visual scale 0.75x-1.6x (`petVisualScale`), income bonus 1.0x-1.35x (`weightIncomeMultiplier`).
- Growth spots: start with 4 per plot (TODO-BALANCE). Later a gamepass adds 4 more (not in this task).
IMPORTANT: the live place Economy has changed since the export (training caps, SELL_SECONDS_OF_INCOME, etc.). Copy ONLY the growth section into the live Economy. Never paste the whole repo file over the live one.

## Server rules
- The server rolls the creature and the weight when the egg is placed (or keeps the existing roll timing if it already happens earlier; say which), stores them server-side, and owns the timer using os.time(). Growth continues while the player is offline.
- The client is told only: spot id, rarity (for the timer colour), start time, duration, current weight for display. The species stays secret until hatch.
- New remotes, same standard as the rest of V3 (types, NaN, ownership, rate limit through EggService._wrap, no Instances from the client): PlaceEgg(eggId, spotId), Hatch(spotId). Hatch only succeeds when os.time() >= start + duration. Hatching twice, hatching someone else's spot, placing on an occupied spot or a spot that does not exist: rejected.
- Pets get a `weight` field. Pet income uses weightIncomeMultiplier on the server (EggRules income and the Sell value). Pets without weight (old saves) = multiplier 1.0, scale 1.0.
- Save: add growing eggs `{ spotId, eggId/zone, species, rarity, weight, startedAt, duration }` and pet `weight` to SaveSchema with safe defaults and clamps in sanitize. Old saves load with no growing eggs and pets unchanged. A failed load must never overwrite.
- Remove the instant hatch path at 100% wash so there is only one way to hatch. Keep the hatch reveal code and reuse it.
- Respect the pet capacity rules already in the game (plot slots / storage from the Animals panel): a hatched pet goes to the plot if there is room, otherwise to storage.

## Client
- Growth spots on the plot (use existing nest/egg spot parts if they exist; otherwise add simple pads in the plot and say where). Each shows: the egg model scaled by progress, a BillboardGui timer + kg, rarity-coloured ring, "READY!" state.
- Inventory: clean eggs show "Ready to place"; the wash-to-hatch wording ("PUT IN GARDEN TO GROW & HATCH") must now be true.
- Chunky Nest style, Theme/Kit read-only unless OpenCode is idle; respect FLReduceMotion.

## Test (Play Solo + Device Simulator phone)
1. Wash an egg: no instant hatch; it becomes a clean egg.
2. Place it: timer and kg show, egg grows; leave and rejoin (API Services on, no Studio no-save flag): timer continued, still growing.
3. Timer ends: READY; hatch gives the reveal with letter-by-letter name; pet size and income match the weight; Book/Index updates.
4. Try hatching early, hatching twice, placing on a full or invalid spot, firing the remotes with bad ids and fast loops: rejected, no dupes.
5. Old save (no growth data, pets without weight) loads fine.
6. Full plot: hatched pet goes to storage.
7. No new errors. Studio back in Edit mode.

## Report
Scripts and lines changed, save fields added, final constants, where the creature/weight roll happens, screenshots (growing egg, READY, reveal) on desktop and phone, test results (anything not run = "not verified"), and a CHANGES.md bundle with the final code for the architect review.
