# Task for Gemini: simpler plots, one central Food Shop, closed-in map

Owner: Gemini, in the open Studio place "Feed an Lay". Do this BEFORE gemini_runway_lanes.md. Do NOT save, publish, commit or push. Do NOT run `rojo serve` (the repo is stale and would overwrite live code).

## Do not touch (OpenCode owns these; it is fixing egg growth review findings)
EggService, EggRules, Main (server), SaveSchema, SaveStore, TrainingRules, Economy, Loop.Growth, Loop.Hatch, Loop.Pen, Loop.Inventory, Loop.Menus, Loop.Hud, UI.Kit, UI.Theme, UI.Icons. You may READ them. If something you remove is used by one of these, keep it (hide or move it) and write it down for OpenCode. Never break their code.

## What the user wants (screenshots of a reference game; copy the idea, not its look or names)
Each plot is simple: **a fenced pen with only the pets in it, and in front of the pen the Washer and the Strength Training**. Nothing else on the plot. Food is bought at **one shared Food Shop** for the whole server, placed away from the throwing pad. The map is **closed in**: today the plot edge drops into open sky and players can fall off.

## 1. Clean up every plot (Plot_1..Plot_6, identical)
Before deleting anything, grep all scripts for its name and list what uses it.
- **Remove:** Sign_Food, Sign_Nest, Sign_Pen, Sign_Weights, Sign_Nozzle, the whole ViewingDeck (with OddsBoard), Hub (if nothing uses it).
- **Remove the ODDS board feature:** delete Loop.OddsBoard (StarterPlayerScripts) and its one-line hook in the client bootstrap. The user doesn't want it.
- **Keep, but move:** Washer and LiftBench (strength training) go side by side directly in front of the pen entrance. Move each model as a whole (PivotTo). Don't rename it, don't change its children, its tags (FLStation, Kind attribute) or its Zone part. The server finds stations by tag and pivot position, so moving them is safe.
- **HatchPad** (OpenCode's Loop.Growth builds the egg growth spots from it, Loop.Hatch uses Pedestal/QueueShelf): move it as a whole next to the Washer, in front of the pen, so washed eggs go straight onto growth spots. Don't change its children.
- **Nest** (egg slots): check Loop.Nest and the rest before touching it. If it's still used, keep it but make it compact and tidy beside the washer. Write down what it's for.
- **Keep as is:** Pen (fences, PenFloor and its attachments), Floor, Rim, Edge parts, Spawn, BaseSign (owner name / FREE PLOT).
- **Pen:** keep it simple, just fences and pets. Make sure it's big enough for the current max pen slots (read PenSlots / Economy, read only). Pets must not clip out.

## 2. Guide arrow targets
Goals (ReplicatedStorage.Modules.Goals ~45-51, ~104) and Loop.Main (~206, ~226) point the arrow trail at "Sign_Food", "Sign_Nest", "Sign_Nozzle", "Sign_Weights". Loop.Menus ~891 uses "Sign_Nest"/"Sign_Food" too (read only for you). After removal:
- Food goals point at the new Food Shop.
- Weights goals point at the LiftBench, nozzle goals at the Washer.
- Nest (inventory slot) goals: point at the Upgrades button or no trail.
Loop.Trail only aims at a station inside the player's plot. Extend it to also accept a world target (the shared Food Shop) without breaking the plot stations. You may edit Goals, Loop.Main (only those hint lines) and Loop.Trail. List the Menus ~891 change for OpenCode.

## 3. One shared Food Shop
- A stall/shop building in the shared area (the hub between the plots and the canyon), clearly away from the launch pad but easy to find. Chunky blocky style that fits the map, with a big "FOOD SHOP" sign. Put it in `Workspace.Hub.FoodShop` (or say where). Keep it out of every plot model.
- ProximityPrompt "Open Food Shop" (or walking into a trigger zone) opens the Food Shop window, client side.
- **Food Shop window**, new module Loop.FoodShop, Chunky Nest style (docs/ui_style_spec.md), built with Kit components, reading Kit and Theme only:
  - Header "Food Shop" and the red X. Centred, fully on screen on phone and PC (same rules as the other windows).
  - A horizontal scroll of cards, one per Economy.Foods tier: food name, a ViewportFrame render (or the food icon when there's no model), "Tier N", luck multiplier ("Luck x8").
  - Card button: current tier = grey "EQUIPPED". Lower tiers = "OWNED". Next tier = yellow price button when affordable, red price button when not. Tiers after the next one = locked ("Buy Tier N first").
  - Buying calls the existing remote `Ctx.invoke("Buy", "Food")` (same as the Upgrades panel today). Don't add or change server code. Update live on coins/food change.
  - Opening it closes other windows (use Kit.showPanel / the shared panel list so only one window is open at a time). Escape and X close it.
- Food stays in the Upgrades panel for now (Menus is OpenCode's). Write down "remove Food track from Upgrades" for OpenCode.
- Write down whether the server Buy checks distance (read Main/EggService). Don't change it. If it doesn't, players could still buy food from anywhere through the Upgrades panel, which is OK for now.

## 4. Close in the map
- No open edges anywhere a player can walk: surround the play area (plots, hub, shop, launch area) with walls or cliffs like the reference (tall blocky dirt walls with grass on top), or invisible walls behind a visible border where a wall would block the view of the canyon.
- The canyon/runway stays open along the throw path (the food has to fly), but players must not be able to walk or jump off. Use invisible walls (CanCollide true, Transparency 1, CanQuery false) where needed.
- Add a safety net: anything that falls below the map respawns at its plot (a kill/teleport part, or check the FallenPartsDestroyHeight setup). Say which.
- Remove the "FREE PLOT" sky gap look: the ground under and around plots should continue to the walls.

## Test (Play Solo + Device Simulator phone)
1. Each plot shows only the pen, the Washer, the Strength Training (and the HatchPad/Nest if kept). No signs, no ODDS board, no OddsBoard warnings in Output.
2. Wash an egg, train strength, throw: all still work at their new spots (no "walk closer" errors).
3. Walk to the Food Shop: prompt opens the window. Buy the next food: coins drop, the card turns EQUIPPED, the next one unlocks. Can't-afford shows red. Phone layout fits.
4. Goal arrow for food leads to the shop, weights to the bench.
5. Try to walk/jump off every edge of the map: impossible. Fall through on purpose (Studio): you respawn.
6. 2 players (local server test if you can): both use the same shop, each buys for themselves. Otherwise "not verified".
7. No new errors. Studio back in Edit mode (check the Studio state, don't assume).

## Report
For each removed part: what used it and what you did. New/moved parts with paths. New modules and the hook line. Trail/Goals changes with lines. Everything written down for OpenCode (Menus ~891, Food track removal, anything kept because OpenCode's code uses it). Screenshots: a plot from above, the Food Shop building, the Food Shop window on PC and phone, a map edge. Test results; anything not run = "not verified". "Verified" means you ran it and say what you saw.
