# Code Audit — Egg Sanctuary (Feed-and-Lay)

**Date:** 2026-11-17 (third pass) · **Branch:** `fix/anti-cheat` (on top of `main`, which has the merged PR #1) · **Scope:** whole repo (`src/`, `default.project.json`, `build_gdd.py`, docs)
**Tests in repo:** none · **Code changed by this audit:** none

---

## What this repo does

A Roblox game, synced into Studio with Rojo. Players train strength, throw food down a canyon, get an egg back, brush it clean, and put it in their yard, where the pet earns Bio-Essence (the game money). Money buys better food, which gives rarer pets.

**Load assumed:** one Roblox server holds up to 6 players (there are 6 plots), and many servers run at once when the game is public. Some players use autoclickers, and some cheat (an "exploiter" is a player who sends fake messages to the server).

## Fixed since the first audit

| Fix | Where | How it was checked |
|---|---|---|
| Failed load no longer wipes the save; save errors are logged | `MainGameServer.server.luau:L277-291, L361-381` | Studio harness (see below) |
| Server saves everyone on shutdown (`BindToClose`) | `L402-407` | Studio harness |
| Leaving during load frees the plot | `L277-281` | Studio harness |
| Gym training has a 0.5 s server cooldown | `L32, L426-430`; client shows the message `L691-698` | Studio harness |
| Server times the throw charge itself (new `StartCharge` event, created in code) | server `L24-30, L472-477, L506-508`; client `StartChargeRemote:FireServer()` in `startCharge` | Studio harness |
| A throw is refused while an egg waits in the cleaner | `L483-485` | Studio harness |

**How it was tested:** the real server script and `GameConfig` were run inside Roblox Studio's Luau engine with fake Players, Remotes and DataStore (no place file exists in the repo, see #5). 18 checks passed: cooldown rejects an instant second click and allows ~2 trains/s under a 100 clicks/s autoclicker; a client claiming a 1.6 s hold without a real hold gets x0.5; a real 1.6 s hold gets the sweet spot even if the client sends 0.01; a second throw is refused and the original egg hatches unchanged; failed load kicks and never writes; leave-during-load keeps no data and frees the plot; shutdown saves. The client script was only parse-checked.

**New risks from these fixes:** none found. Two limits worth knowing:
- The server measures the charge between two network messages, so ping jitter moves the result by a few hundredths of a second. The sweet spot is 0.45 s wide, so this is fine.
- 0.5 s cooldown caps an autoclicker at human speed (2 trains/s), not below it. Reaching the last zone still takes about 3 minutes of clicking. Whether that is too fast is a design call, not a bug.

---

## Must fix

### 1. No pet limit; two remotes have no handler (`src/server/MainGameServer.server.luau:L20-21, L592-630`)
- **What this is:** Saves store `MaxSlots = 4`, and the server fetches `ExpandSanctuary` and `ManagePet` remotes.
- **Problem:** `HatchEgg` never checks `MaxSlots`, and those two remotes have no `OnServerInvoke`. Pets and income grow without limit, and the save grows toward the 4 MB DataStore limit. A client calling those remotes waits forever.
- **Fix:** In `HatchEgg`: `if #data.GardenPets >= data.MaxSlots then return { Success = false, Message = "Garden full!" } end`. Then build sell/expand, or delete the two remotes.
- **If we skip it:** No economy ceiling, and the server load in #10 grows with every hatch.

### 2. Joining while the save loads puts you on plot 1 (`MainGameServer.server.luau:L637`, client `L88-119`)
- **What this is:** The client asks `GetSanctuaryState` once on start to learn its plot.
- **Problem:** While `GetAsync` is still running, the server returns the early "no data" table, which has no `PlotId`. The client keeps plot 1. Players on plots 2–6 get plot 1's wash basin and shop prompts, and their egg flies to plot 1.
- **Fix:** Add `PlotId = AssignedPlots[player.UserId]` to that early return. Better: the client waits for `leaderstats.PlotId` with `WaitForChild` instead of calling the remote.
- **If we skip it:** On a slow DataStore day many players see the wrong base.

### 3. A 7th player shares a plot and wipes the owner's pets (`MainGameServer.server.luau:L253-256, L316-322`)
- **What this is:** There are 6 plots. When all are taken, the code falls back to `UserId % 6 + 1`.
- **Problem:** That plot already has an owner. `setupPlayer` then calls `PetsInGarden:ClearAllChildren()`, which deletes the owner's pet models. Both players' pets spawn in one yard. Nothing in the repo sets the server size to 6.
- **Fix:** Set Max Players to 6 in the place settings, and in code kick when no plot is free (`player:Kick("Server full")`) instead of sharing.
- **If we skip it:** Any server with more than 6 players breaks two bases.

### 4. Income is half of what the game shows (`MainGameServer.server.luau:L653-667`)
- **What this is:** Signs, pet tags and the pet menu all say "+X $/s".
- **Problem:** The tick runs every 2 seconds and adds X once, so the real rate is half of what is shown.
- **Fix:** `task.wait(2)` → `task.wait(1)` on `L655`, or add `income * 2`. One line.
- **If we skip it:** The money counter lags the promised rate; GDD balance math is off by 2x.

### 5. The repo alone cannot run the game (`default.project.json`)
- **What this is:** The Rojo project maps only the 4 script files.
- **Problem:** Both scripts `WaitForChild` on `ReplicatedStorage.Remotes`, `ReplicatedStorage.Sounds` and `PlayerGui.EggSanctuaryHUD`, and code expects `Workspace.EggSanctuaryMap` and `ReplicatedStorage.PetTemplates`. None of these are in the repo. A `rojo build` place hangs forever on `Remotes`. The game only works inside one person's local `.rbxl`.
- **Fix:** Create all remotes in code at the top of the server (the same pattern now used for `StartCharge`, `L24-30`, as a loop over names), and export the HUD, map, sounds and pet templates as `.rbxm` files mapped in `default.project.json`.
- **If we skip it:** Losing that one `.rbxl` loses the game, and reviewers can only test PRs with fake harnesses like the one used for this pass.

---

## Should fix

### 6. Two servers can overwrite each other's save (`MainGameServer.server.luau:L361-381, L621`)
- **What this is:** Saves use plain `SetAsync`, and a hatch saves at once.
- **Problem:** A player who hops servers fast can load on server B before server A's leave-save lands; A's late write then overwrites B's newer progress. Roblox also allows about one write per key every 6 s, so fast hatching gets throttled (now logged as a warning).
- **Fix:** Use ProfileStore (a widely used open-source save module with session locking), or at least `UpdateAsync` plus a "dirty" flag saved by the autosave loop instead of saving on every hatch.
- **If we skip it:** Rare but real "I lost progress after switching servers" reports.

### 7. The throw-power rule is written twice and the two disagree (client `L277-297`, server `L507-522`)
- **What this is:** The client meter shows steps (x0.5, x0.7, x0.85, x1.0, x1.25, x0.9). The server computes the real power.
- **Problem:** The server uses a smooth line from 0.5 to 1.0, not steps. At 0.6 s the meter and landing marker say x0.7, the server gives x0.65. At exactly 1.45 s the meter says x1.0, the server gives the sweet spot. Now that the server owns the timing, this mismatch is the only thing that makes the meter lie.
- **Fix:** One `GameConfig.ThrowRatio(duration)` in the shared module, called from both sides.
- **If we skip it:** The landing preview lies, and tuning must be done in two places.

### 8. High food tiers make every pet Mythic (`src/shared/GameConfig.luau:L75-89`)
- **What this is:** `RollRarity` divides a random number by the food's `Luck`.
- **Problem:** With Luck 25 (tier 6) the roll is always under 0.04, so every pet is Legendary or Mythic. With Luck 100 (tier 8) every pet is Mythic.
- **Fix:** Let luck shift the weights instead of dividing the roll, for example `roll = math.random() ^ (1 + math.log(luckMult))`, or a weight table per tier. Set the target odds with design first.
- **If we skip it:** The late game has no surprise, and Mythic x15 income inflates the economy.

### 9. Server sounds play for every player in the server (`src/shared/SoundHelper.luau:L11`, server `L545, L576-578, L606`)
- **What this is:** `SoundHelper.Play(name)` with no parent puts the sound in `SoundService`.
- **Problem:** Played from the server, that sound reaches every client. Everyone hears everyone's spray, chime, whoosh and fanfare. The throw whoosh also plays twice (client on charge, server on throw). The 3 s auto-destroy cuts any sound longer than 3 s.
- **Fix:** On the server, always pass the player's `HumanoidRootPart` as the parent, or fire the sound to that one client. Drop the `task.delay(3)` and keep only `Ended`.
- **If we skip it:** With 6 players the base is constant noise.

### 10. Every pet is animated on the server 25 times a second (`MainGameServer.server.luau:L229-239`)
- **What this is:** Each pet gets its own loop calling `PivotTo` every 0.04 s.
- **Problem:** Server moves are sent to every client. 6 players × 30 pets = 180 models × 25 updates/s. With no pet cap (#1) this has no ceiling.
- **Fix:** Spawn pets on the server once, and run the bob/roam animation in the client script.
- **If we skip it:** Lag and high ping on full servers, worse on mobile.

### 11. Server setup blocks on the first players' saves (`MainGameServer.server.luau:L384-386`)
- **What this is:** At start, the server runs `setupPlayer` for players already in the game, one by one, before it connects `PlayerRemoving`, `BindToClose` and all remote handlers below.
- **Problem:** `setupPlayer` waits on `GetAsync`. In Studio Play (player is often there before the script runs) or after a slow DataStore, everything below that loop waits. A player who leaves in that window is never cleaned up or saved, and a shutdown in that window skips the `BindToClose` save.
- **Fix:** `task.spawn(setupPlayer, p)` instead of `setupPlayer(p)` on `L385`. One line.
- **If we skip it:** Rare lost cleanup and saves at server start; confusing Studio tests.

### 12. Risky game logic has no test in the repo (`GameConfig.luau`, throw ratio, save path)
- **What this is:** Rarity, zones and throw power decide all rewards; the save and anti-cheat guards decide whether progress survives.
- **Problem:** This pass tested them with a harness pasted into Studio, but nothing in the repo runs it, so the next change can break them silently.
- **Fix:** After #5 (remotes in code), add one `tests/` script with plain `assert`s that a teammate can run in Studio: fixed inputs for `GetZoneByDistance(0/300/4999/5000)`, `ThrowRatio(0.1/1.0/1.5/2.5)` (after #7), and 10,000 rolls per food tier to check the Mythic share stays in range.
- **If we skip it:** Balance and save bugs ship silently.

### 13. `build_gdd.py` only runs on another person's machine (`build_gdd.py:L6-8`)
- **What this is:** A script that writes the GDD HTML and prints it to PDF via Edge.
- **Problem:** Paths are hard-coded to `C:\Users\USER\.gemini\antigravity\...`. It fails here, and the generated HTML and PDF sit next to a separate `Egg_Sanctuary_GDD.md`: three copies of the design doc that can drift.
- **Fix:** Pick one source. Keep the `.md` and delete the script, HTML and PDF; or keep the script with `OUTPUT_DIR = os.path.dirname(__file__)` and drop the `ARTIFACT_DIR` copy.
- **If we skip it:** Nobody can rebuild the PDF; docs drift.

### 14. Dead and duplicated code (several files)
- **What this is:** Code never used, or copies that must change together.
- **Cases:**
  - Server `TweenService` (`L4`) is never used.
  - Server `cleanPrompt` / `chefPrompt` (`L675-681`) are found but never used.
  - Server `plot` in `ThrowFood` (`L543`) is unused; `PlotX` + `PLOT_X_OFFSETS` (`L50-57, L557`) are sent but the client never reads `res.PlotX`.
  - Client `PLOT_X_POSITIONS` / `myPlotX` (`L66, L68, L93`) only feed a fallback start position.
  - The launch-pad box (`Z -24..4, X -75..-35`) is copied in client `L239` and server `L495`, and both comments describe a different box ("|X| <= 90").
  - Mutation colors are written three times (server `L155-176`, server `L200-208`, client `L572-580`).
- **Fix:** Delete the unused lines. Move the launch box and a `Mutations = { Rainbow = { Color = ... }, ... }` table into `GameConfig` and read them from both sides.
- **If we skip it:** Moving the launch pad in the map breaks the throw unless both files change the same way.

---

## Nice to have

### 15. Client polls the HUD and can get stuck after a server error (`src/client/EggSanctuaryClient.client.luau:L141-146, L355-466`)
- **What this is:** `updateUI` reruns every 0.5 s forever; `executeThrow` is a global function.
- **Problem:** Polling is wasted when `leaderstats` values have a `.Changed` event. If the server errors inside `ThrowFood`, `InvokeServer` errors on the client and `isThrowing` stays `true`: the player can't throw again until rejoin.
- **Fix:** Connect `updateUI` to each leaderstat's `.Changed`. Wrap `InvokeServer` in `pcall` and reset `isThrowing` on failure. Make `executeThrow` a `local function` declared before `endCharge`.
- **If we skip it:** Small CPU waste, and a rare soft-lock.

Smaller items left out: 3 (big numbers not formatted, the current egg is not saved on leave, README says SoundHelper has a "procedural fallback" that does not exist).

---

**Verdict:** Saves are handled (PR #1, merged) and the main cheats are handled once the anti-cheat PR merges. Still not ready for public players: fix the plot bugs (#2, #3) and the pet cap (#1) next, then the one-liners #4 and #11.

**Lean:** -~45 lines of Luau possible (dead code + merged copies in #14), plus -1,393 lines if the GDD build script and its HTML output go (#13). -0 dependencies (there are none).

**Not checked:** The game was not played (no place file in the repo, see #5); the server was tested only with fakes for Roblox services, and the client script only parse-checked. The HUD, map, sounds and pet templates live only in a local `.rbxl` and were not seen. `3D_ARTIST_GUIDE.md`, `Egg_Sanctuary_GDD.md` and the PDF were skimmed, not reviewed.
