# Task for OpenCode: fix the broken core loop + rebuild the plot as one big fenced base

Owner: OpenCode, in the open Studio place "Feed an Lay" (Team Create: edits save automatically, so test carefully and never leave half-done edits). Do NOT publish, commit or push. Don't touch SaveStore or the save mutex/pendingSaves logic. Gemini is polishing the canyon/runway and walls (gemini_throw_map_polish.md): don't touch Workspace.CanyonV3, EggSanctuaryMap, SanctuaryEnclosure, Hub/FoodShop, or Gemini's modules (Loop.Lanes, Loop.FoodShop, Loop.Throw, Loop.ThrowCinematic, Loop.Trail). The plots (Workspace.PlotsV3) are now YOURS for Part B; Gemini's item 9 moves to you.

## Part A: bugs the user hit in Play (fix in this order; find the root cause first, with script and line, before changing anything)
1. **Coins don't go up** although the HUD says "84/s". Check the server income tick (pets on the plot × petIncome incl. weight) actually adds to coins, that the HUD rate and the real tick use the same function, and that nothing errors in the loop (check the server Output in Play, not only the client). Likely suspects: the growth/weight changes, the four scripts the bad edit helper corrupted, the pen=true/storage split (only pen pets earn).
2. **Index CLAIM does nothing.** Grep shows the client Menus only has CLAIM text (~275). Find the click handler, the remote it calls, the server handler, and why no coins arrive. Claim must pay once, and the tile must turn CLAIMED.
3. **Egg washing doesn't work.** Reproduce: pick an egg, go to the Washer, wash. Find what fails (the Washer was moved by Gemini: check the FLStation tag/Kind/Zone and the isNear radius against its new position; check your clean-egg changes in startWash/oldestInNest; check client Loop.Wash finds the Turntable).
4. **Washing auto-hatches.** The user still sees an instant hatch after washing. There must be only ONE way to hatch: a clean egg is placed by the player, then grows, then hatches. Find the remaining path (your report said "Washer path retains its old swap behaviour"; check Wash/Hatch client and EggRules/EggService server) and remove it.
5. **New rule from the user:** a dirty egg cannot be placed. Only clean eggs can go on the growth spot (server check already exists in GrowthRules.canPlace: verify it, and grey out the place button/prompt for dirty eggs with "Wash it first!").
6. **My Animals UI is cut off.** The panel content runs off the screen (rows, buttons or EQUIP BEST). Make the whole panel fit inside the safe area on desktop 1920×1080, phone landscape and portrait, and tablet: scale down with UIScale/UISizeConstraint, scroll the list, keep EQUIP BEST visible.

## Part B: plot = one big fenced base (user's reference screenshot)
The user wants each plot to look like this: **one wide, big fence around the whole base**, and inside it, **the pets roaming, a spot for the big egg to grow and hatch, the strength training, and the washing machine**. No separate small pen box in a corner.
- Replace the small Pen box with one large fence around (almost) the whole plot (blocky studded fence: posts + rails, two colours, Material Plastic so the stud material shows). Keep the Pen model name, the PenFloor and its pet attachments working (Loop.Pen places pets from them: move/extend them so pets spread over the big area).
- Inside the fence: the growth spot(s) as one clearly visible **big egg pedestal** area (Loop.Growth builds pads from HatchPad: keep that contract, make the pads/egg read big), the Washer and the LiftBench, each scaled up so they read from far away. The entrance gap faces the plot entrance/spawn.
- Move stations as whole models (PivotTo). Keep names, FLStation tags, Kind attributes and Zone parts. Check that isNear radii still work at the new spots.
- Floor: two-tone green checker like the reference, Plastic. Same layout on all 6 plots.
- Remove anything left over that isn't one of: fence, pets area, egg spot, washer, strength training, spawn, owner sign.

## Test (Play Solo + Device Simulator phone; real clicks)
1. Coins rise at the HUD rate (check coins after 10 s vs rate × 10).
2. Index: CLAIM pays once, turns CLAIMED, coins go up. Second claim impossible.
3. Throw → get an egg → wash at the moved Washer to 100% → **no hatch**, egg is clean → place it on the egg spot (a dirty egg is refused) → grows → READY → hatch with the reveal → pet appears inside the big fence and earns.
4. My Animals fully visible on desktop and phone, EQUIP BEST reachable.
5. Strength training works at its new spot.
6. No new errors in server or client Output. Studio back in Edit mode.

## Report
Per bug: root cause (script, line), fix, test result. Part B: new plot layout with paths, what moved. You can't view screenshots, so capture them anyway (plot from above, My Animals on phone) and I'll check them. Anything not run = "not verified". Update CHANGES.md.
