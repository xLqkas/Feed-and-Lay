# Task for Gemini: your plot/lanes work is only half in the place, and the game client is broken

Owner: Gemini, in the open Studio place "Feed an Lay", **in Edit mode only**. Anything you create while Play Solo is running is thrown away when Play stops. That's the likely cause. Do NOT save, publish, commit or push. Do NOT run rojo serve.

## What the live place has right now (checked read-only, Edit mode)
Landed: the signs, ViewingDecks and Hub parts are gone from all plots. Washer, LiftBench, HatchPad and Nest are still there. Loop.OddsBoard is deleted. Goals line 47 and Loop.Main line 226 point at "FoodShop". Loop.Throw line 18 requires Loop.Lanes.

**Missing** (does not exist in Studio):
- Loop.Lanes, Loop.FoodShop (StarterPlayerScripts.Loop)
- ServerScriptService.EggSanctuaryServer.V3.RunwayLanes
- Workspace.Hub / FoodShop building and its ProximityPrompt
- The RunwayLanes folder with Lane_1..Lane_6, dividers, strips, YOUR LANE label
- The cliff walls, invisible barriers and the Y = -120 safety net
- Workspace only has PlotsV3, CanyonV3, EggSanctuaryMap, Baseplate, Terrain, Camera

**Broken:**
1. Loop.Throw line 18 `require(script.Parent.Lanes)` fails, and Loop.Main requires Throw at line 45, so **the whole client loop stops on join**. OpenCode couldn't test any UI because of this.
2. Loop.Main line 87 still runs `require(script.Parent.OddsBoard).init()`, but the module is deleted, so it errors on join. Delete that line.
3. Loop.Trail.set still only aims at stations inside the player's plot. Check that "FoodShop" (outside the plot) actually works. If it doesn't, add the world-target support from the brief.

## Do
1. Delete Main line 87 first, and re-create Loop.Lanes, so the client loads again. Your repo copies are in `src/client/Lanes.luau`, `src/client/FoodShop.luau`, `src/server/RunwayLanes.luau`. Paste them into Studio as ModuleScripts with the right names and parents, and check that they match what Throw/ThrowCinematic call.
2. Hook Loop.FoodShop in (one line, as before).
3. Rebuild the world parts from gemini_plot_redesign.md and gemini_runway_lanes.md in Edit mode: Hub/FoodShop building with prompt, cliff walls, invisible barriers, safety net, RunwayLanes lanes. Also check that Washer/LiftBench/HatchPad/Nest really sit in front of the pen (the parts exist, but check the positions).
4. Don't touch OpenCode's modules (EggService, EggRules, GrowthRules, Main server, SaveSchema, SaveStore, Economy, Loop.Growth, Loop.Hatch, Loop.Pen, Loop.Inventory, Loop.Menus, Loop.Hud).

## Proof required this time
- After you're done and Studio is in **Edit** mode: a list from the Explorer (or search_game_tree) showing each new module and part path exists.
- Play Solo: the client loads with no require errors in Output (paste the Output). Throw works. The Food Shop opens and buys. You can't walk off the map.
- Stop Play, then confirm everything still exists in Edit mode.
- Screenshots: plot from above, Food Shop building + window, lanes, a wall edge. Anything not run = "not verified".
