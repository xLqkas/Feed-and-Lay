# Code Audit — Egg Sanctuary (Feed-and-Lay)

**Date:** 2026-11-17 · **Commit:** `aaddef6` · **Scope:** whole repo (`src/`, `default.project.json`, `build_gdd.py`, docs)
**Tests in repo:** none · **Code changed by this audit:** none

---

## What this repo does

A Roblox game, synced into Studio with Rojo. Players train strength, throw food down a canyon, get an egg back, brush it clean, and put it in their yard, where the pet earns Bio-Essence (the game money) every few seconds. Money buys better food, which gives rarer pets.

**Load assumed:** one Roblox server holds up to 6 players (there are 6 plots), and many servers run at once when the game is public. Each player can click as fast as an autoclicker allows, and some players will cheat (an "exploiter" is a player who sends fake messages to the server).

---

## Must fix

### 1. A failed load wipes the player's save (`src/server/MainGameServer.server.luau:L259-275, L334-351`)
- **What this is:** On join the server reads the save with `GetAsync`. Every 45 s, on leave, and after each hatch, it writes with `SetAsync`.
- **Problem:** If `GetAsync` fails (Roblox DataStore outage or rate limit), the error is caught and the player silently gets starter data. The next save writes that starter data over the real save. Save errors are also swallowed (`pcall` with no check), so nobody sees it.
- **Fix:** Keep the `pcall` result. If the load failed, set `data.LoadFailed = true`, tell or kick the player, and make `savePlayerData` return early when that flag is set. Log `warn()` when a save fails.
- **If we skip it:** One bad DataStore minute = players lose all pets and money for good.

### 2. Nothing is saved when the server shuts down (whole server file; no `BindToClose`)
- **What this is:** Roblox closes servers on updates and when the last player leaves.
- **Problem:** There is no `game:BindToClose`. When a server closes, `PlayerRemoving` may not finish its save in time, so up to 45 s of progress is lost for everyone on that server.
- **Fix:** `game:BindToClose(function() for _, p in Players:GetPlayers() do savePlayerData(p) end end)` (about 5 lines).
- **If we skip it:** Every game update loses progress for every online player.

### 3. A player who leaves while loading locks a plot forever (`MainGameServer.server.luau:L232-332, L358-370`)
- **What this is:** `setupPlayer` takes a plot, then waits on `GetAsync`.
- **Problem:** If the player leaves during that wait, `PlayerRemoving` runs first and cleans up nothing (no data yet). Then `setupPlayer` wakes up, stores data, keeps the plot and spawns pets for a player who is gone. That plot is never freed and those pets roam until the server dies.
- **Fix:** Right after `GetAsync`: `if not player.Parent then AssignedPlots[player.UserId] = nil return end`.
- **If we skip it:** On a busy server, plots run out after a few quick join/leave cases, and new players land on someone else's plot (see #9).

### 4. Autoclicker gives unlimited strength (`MainGameServer.server.luau:L385-398`, client `L690-696`)
- **What this is:** `TrainStrength` adds +10 strength each call. The HUD "Gym" button calls it from anywhere.
- **Problem:** No cooldown, no cost, no check that the player is at the treadmill. An autoclicker at 10 clicks/s reaches the last zone (5000 studs) in under a minute.
- **Fix:** Store `data.LastTrainTime` and reject calls under ~0.5 s apart, same pattern as the throw cooldown on L445-449. Optionally drop the HUD button and keep only the treadmill prompt.
- **If we skip it:** The whole progression is skippable on day one.

### 5. The client picks its own throw power (`MainGameServer.server.luau:L428-465`)
- **What this is:** The server turns `chargeDuration` (how long the button was held) into a power multiplier. 1.45–1.90 s is the "sweet spot" (x1.25).
- **Problem:** The server trusts the number the client sends. An exploiter sends `1.6` every time and always gets the best throw.
- **Fix:** Add a `StartCharge` remote. The server stores `os.clock()` there and computes the duration itself on `ThrowFood`, ignoring the client value.
- **If we skip it:** Cheaters always get x1.25, so honest players fall behind.

### 6. Throwing again destroys the egg you have not cleaned (`MainGameServer.server.luau:L475-484`)
- **What this is:** Each throw sets `data.CurrentEgg`.
- **Problem:** Nothing checks if an egg is already waiting. A player who throws again (easy to do: the wash modal does not block the throw button) silently loses the old egg, even a Mythic Rainbow one.
- **Fix:** At the top of `ThrowFood`: `if data.CurrentEgg then return { Success = false, Message = "Clean your egg first!" } end`.
- **If we skip it:** Players lose their best rolls and file "my pet vanished" reports.

### 7. No pet limit; slot remotes have no handler (`MainGameServer.server.luau:L19-20, L535-573`)
- **What this is:** Saves store `MaxSlots = 4`, and the server fetches `ExpandSanctuary` and `ManagePet` remotes.
- **Problem:** `HatchEgg` never checks `MaxSlots`, and those two remotes have no `OnServerInvoke`. Pets and income grow without limit. The save list also grows without limit, toward the 4 MB DataStore value limit. A client calling those remotes waits forever.
- **Fix:** In `HatchEgg`: `if #data.GardenPets >= data.MaxSlots then return { Success = false, Message = "Garden full!" } end`. Then either build sell/expand, or delete the two unused remotes.
- **If we skip it:** No economy ceiling, and the server load in #16 grows with every hatch.

### 8. Joining while the save loads puts you on plot 1 (`MainGameServer.server.luau:L578-580`, client `L87-118`)
- **What this is:** The client asks `GetSanctuaryState` once on start to learn its plot.
- **Problem:** While `GetAsync` is still running, the server returns the early "no data" table, which has no `PlotId`. The client keeps the default plot 1. Players on plots 2–6 then get plot 1's wash basin and shop prompts, and their egg flies to plot 1.
- **Fix:** In the early return, add `PlotId = AssignedPlots[player.UserId]`. Better: the client reads `leaderstats.PlotId` with `WaitForChild` instead of calling the remote.
- **If we skip it:** Many players on a slow DataStore day see the wrong base.

### 9. A 7th player shares a plot and wipes the owner's pets (`MainGameServer.server.luau:L242-245, L289-295`)
- **What this is:** There are 6 plots. When all are taken, the code falls back to `UserId % 6 + 1`.
- **Problem:** That plot already has an owner. `setupPlayer` then calls `PetsInGarden:ClearAllChildren()`, which deletes the owner's pet models from the world. Both players' pets now spawn in one yard, and the sign shows only one name. Nothing in the repo sets the server size to 6.
- **Fix:** Set Max Players to 6 in the place settings, and in code kick the player if no plot is free (`player:Kick("Server full")`) instead of sharing.
- **If we skip it:** Any server with more than 6 players breaks two players' bases.

### 10. Income is half of what the game shows (`MainGameServer.server.luau:L596-610`)
- **What this is:** Signs, pet tags and the pet menu all say "+X $/s".
- **Problem:** The tick runs every 2 seconds and adds X once, so the real rate is X every 2 s, half of what is shown.
- **Fix:** Change `task.wait(2)` to `task.wait(1)`, or add `income * 2`. One line.
- **If we skip it:** Players see the money counter lag behind the promised rate; balance math in the GDD is off by 2x.

### 11. The repo alone cannot run the game (`default.project.json`)
- **What this is:** The Rojo project maps only the 4 script files.
- **Problem:** Both scripts `WaitForChild` on `ReplicatedStorage.Remotes`, `ReplicatedStorage.Sounds`, `PlayerGui.EggSanctuaryHUD`, and code expects `Workspace.EggSanctuaryMap` and `ReplicatedStorage.PetTemplates`. None of these are in the repo. A `rojo build` place hangs forever on `Remotes`. The game only works inside one person's local `.rbxl`.
- **Fix:** Create the remotes in code at the top of the server (a short loop over names), and export the HUD, map, sounds and pet templates as `.rbxm` files mapped in `default.project.json`.
- **If we skip it:** Losing that one `.rbxl` file loses the game; nobody else can clone and play.

---

## Should fix

### 12. Two servers can overwrite each other's save (`MainGameServer.server.luau:L334-351, L564`)
- **What this is:** Saves use plain `SetAsync`, and a hatch saves at once.
- **Problem:** A player who hops servers fast can be loaded on server B before server A's leave-save lands; A's late write then overwrites B's newer progress. Also, Roblox allows about one write per key every 6 s; hatching faster than that gets writes throttled, and errors are swallowed (#1).
- **Fix:** Use ProfileStore (a widely used open-source save module with session locking), or at least `UpdateAsync` plus a "dirty" flag saved by the autosave loop instead of saving on every hatch.
- **If we skip it:** Rare but real "I lost progress after switching servers" reports.

### 13. The throw-power rule is written twice and the two disagree (client `L276-296`, server `L451-465`)
- **What this is:** The client meter shows steps (x0.5, x0.7, x0.85, x1.0, x1.25, x0.9). The server computes the real power.
- **Problem:** The server uses a smooth line from 0.5 to 1.0, not steps. Holding 0.6 s, the meter and landing marker say x0.7, the server gives x0.65. At exactly 1.45 s the meter says x1.0, the server gives the x1.25 sweet spot.
- **Fix:** Put one `GameConfig.ThrowRatio(duration)` in the shared module and call it from both sides.
- **If we skip it:** The landing preview lies, and any tuning must be done in two places.

### 14. High food tiers make every pet Mythic (`src/shared/GameConfig.luau:L75-89`)
- **What this is:** `RollRarity` divides a random number by the food's `Luck`.
- **Problem:** With Luck 25 (tier 6), the roll is always under 0.04, so every pet is Legendary or Mythic. With Luck 100 (tier 8) every pet is Mythic. Rarity stops meaning anything late in the game.
- **Fix:** Use luck to shift the weights, not divide the roll; for example `roll = math.random() ^ (1 + math.log(luckMult))`, or a weight table per tier. Decide the target odds with design first.
- **If we skip it:** The end game has no surprise left; Mythic x15 income inflates the economy.

### 15. Server sounds play for every player in the server (`src/shared/SoundHelper.luau:L11`, server calls at L488, L519-521, L549)
- **What this is:** `SoundHelper.Play(name)` with no parent puts the sound in `SoundService`.
- **Problem:** Played from the server, that sound replicates to all clients. Every player hears every other player's spray, chime, whoosh and hatch fanfare. The throw whoosh also plays twice (client on charge, server on throw). The 3 s auto-destroy also cuts any sound longer than 3 s.
- **Fix:** On the server, always pass the player's `HumanoidRootPart` as the parent (positional sound), or fire the sound to that one client. Drop the `task.delay(3)` and keep only `Ended`.
- **If we skip it:** With 6 players the base is a constant noise wall.

### 16. Every pet is animated on the server 25 times a second (`MainGameServer.server.luau:L218-228`)
- **What this is:** Each pet gets its own loop calling `PivotTo` every 0.04 s.
- **Problem:** Server moves replicate to every client. 6 players × 30 pets = 180 models × 25 updates/s, each with several parts. With no pet cap (#7) this has no ceiling, and it eats server CPU and player bandwidth.
- **Fix:** Spawn pets on the server once (still anchored), and run the bob/roam animation in the client script for nearby pets.
- **If we skip it:** Lag and high ping on full servers, worse on mobile.

### 17. Risky game math has no test (`GameConfig.luau`, throw ratio)
- **What this is:** `RollRarity`, `RollMutation`, `GetZoneByDistance` and the throw ratio decide all rewards.
- **Problem:** A typo in a threshold (as #13 and #14 show) changes the whole economy and nothing catches it.
- **Fix:** One small test script (plain `assert`s, run in Studio's command bar or via `run-in-roblox`): fixed inputs for `GetZoneByDistance(0/300/4999/5000)`, `ThrowRatio(0.1/1.0/1.5/2.5)`, and roll 10,000 times per food tier to check the Mythic share stays in range.
- **If we skip it:** Balance bugs ship silently.

### 18. `build_gdd.py` only runs on another person's machine (`build_gdd.py:L6-8`)
- **What this is:** A script that writes the GDD HTML and prints it to PDF via Edge.
- **Problem:** Paths are hard-coded to `C:\Users\USER\.gemini\antigravity\...` (another tool's scratch folder). It fails here, and the generated HTML and PDF are committed next to a separate `Egg_Sanctuary_GDD.md`, so there are three copies of the design doc that can drift.
- **Fix:** Pick one source. Either keep the `.md` and delete the script, HTML and PDF, or keep the script with `OUTPUT_DIR = os.path.dirname(__file__)` and drop the `ARTIFACT_DIR` copy.
- **If we skip it:** Nobody can rebuild the PDF; docs drift apart.

### 19. Dead and duplicated code (several files)
- **What this is:** Code that is never used, or copies that must change together.
- **Problem / cases:**
  - Server `TweenService` (L4) is never used.
  - Server `cleanPrompt` and `chefPrompt` (L618-624) are found but never used.
  - Server `plot` in `ThrowFood` (L486) is unused; `PlotX` + `PLOT_X_OFFSETS` (L39-46, L500) are sent but the client never reads `res.PlotX`.
  - Client `PLOT_X_POSITIONS` / `myPlotX` (L65, L67, L92) only feed a fallback start position.
  - The launch-pad box (`Z -24..4, X -75..-35`) is copied in client L238 and server L440, and both comments say a different box ("|X| <= 90").
  - Mutation colors are written three times (server L144-165, server L189-197, client L571-579).
- **Fix:** Delete the unused lines. Move the launch box and a `Mutations = { Rainbow = {Color=...}, ... }` table into `GameConfig` and read them from both sides.
- **If we skip it:** Moving the launch pad in the map breaks the throw unless both files are edited the same way.

---

## Nice to have

### 20. Client polls the HUD and can get stuck after a server error (`src/client/EggSanctuaryClient.client.luau:L140-145, L354-465`)
- **What this is:** `updateUI` reruns every 0.5 s forever; `executeThrow` is a global function.
- **Problem:** Polling is wasted work when `leaderstats` values have a `.Changed` event. If the server throws an error inside `ThrowFood`, `InvokeServer` errors on the client and `isThrowing` stays `true`, so the player can never throw again until rejoin.
- **Fix:** Connect `updateUI` to each leaderstat's `.Changed`. Wrap the `InvokeServer` in `pcall` and reset `isThrowing` on failure. Make `executeThrow` a `local function` declared before `endCharge`.
- **If we skip it:** Small CPU waste, and a rare soft-lock.

Smaller items left out: 3 (raw big numbers not formatted, current egg not saved on leave, misleading "procedural fallback" in README for SoundHelper).

---

**Verdict:** Not ready for public players. Fix the save path first (#1, #2, #3, then #12), then the cheats (#4, #5) and the egg/plot bugs (#6, #8, #9).

**Lean:** -~45 lines of Luau possible (dead code + merged copies in #19), plus -1,393 lines if the GDD build script and its HTML output go (#18). -0 dependencies (there are none).

**Not checked:** The game was not run (no place file in the repo, see #11). The HUD, map, sounds and pet templates live only in a local `.rbxl` and were not seen. `3D_ARTIST_GUIDE.md`, `Egg_Sanctuary_GDD.md` and the PDF were skimmed, not reviewed. The untracked `AUDIT.md` in the repo root was left untouched.
