# Phase 0 — Read-Only System Survey

| Field | Detail |
|---|---|
| Date | 2026-11-20 |
| Repo HEAD | `5781a3d` — "feat: satisfying 3D egg restoration station, high-pressure power wash, pop-out physics, cleaner upgrades & canyon dumbbell milestone progression" |
| Scope read | `src/` (all 7 files), `default.project.json`, `Egg_Sanctuary_GDD.md`, `audits/`, `tests/` (plus `README.md` and `3D_ARTIST_GUIDE.md` for object names) |
| Code changed | None. This document is the only file written. |
| Tests run | None. `tests/test_game_math.luau` is a Studio-paste script; no place file exists in the repo. |
| Verification limit | No `.rbxl` in the repo. Map, HUD, sounds and pet models were inferred from string lookups only. An object missing from the tables below may still exist in the place. |

### Citation key

| Tag | File |
|---|---|
| `[S]` | `src/server/MainGameServer.server.luau` (982 lines) |
| `[C]` | `src/client/EggSanctuaryClient.client.luau` (1,349 lines) |
| `[R]` | `src/client/EggRestoration3D.client.luau` (1,088 lines) |
| `[A]` | `src/client/PetShowcaseAnimator.client.luau` (140 lines) |
| `[G]` | `src/shared/GameConfig.luau` (292 lines) |
| `[H]` | `src/shared/SoundHelper.luau` (43 lines) |
| `[T]` | `tests/test_game_math.luau` (61 lines) |
| `[P]` | `default.project.json` (38 lines) |
| `[GDD]` | `Egg_Sanctuary_GDD.md` (98 lines) |
| `[AU]` | `audits/FILIP_2026-11-17_Audit.md` (147 lines) |

---

## 0. Bottom line

1. **The core loop is currently unwinnable.** `[R]` does not compile (duplicated trailing block, `[R]:1055-1064`), and the older 2D wash UI in `[C]` can never be opened (`WashModal.Visible = true` appears nowhere). No code path can take an egg from 0% to 100%, so `HatchEgg` can never be reached in a normal session.
2. **Authority is mixed.** Throw timing, cooldowns, plot allocation, slot cap and hatch rolls are server-side and sound. Cleanliness and washer upgrade effects are client-reported; the server also accepts a client-chosen throw duration when `StartCharge` was never called.
3. **The repo still cannot produce a runnable place.** Remotes are now created in code (good), but the map, HUD, sounds, pet models and the Dumbbell tool exist only in someone's local `.rbxl` (`[P]` maps 6 scripts and nothing else).
4. **Six near-identical plot kits.** Only the Chef Stall is a clean hub candidate. The washer and the bicep-curl station pin the avatar in place, so sharing one instance would cause contention.

Loop as implemented:

```
gym (+10 Strength) -> ThrowRatio(hold) x Strength = distance -> zone
  -> RollRarity(food.Luck) x RollMutation(food.ShinyChance) -> CurrentEgg
  -> CleanEgg(client-reported %) -> HatchEgg -> GardenPets -> 1s income tick
  -> BioEssence -> FoodTier / MaxSlots / CleanerUpgrades -> back to gym
```

The chain breaks between `CurrentEgg` and `HatchEgg` (High #1, #2).

---

## 1. Systems map

### 1.1 Runtime topology

```
Server (authoritative)
  MainGameServer
    - creates 10 RemoteFunctions in ReplicatedStorage.Remotes   [S]:12-39
    - PlayerData / AssignedPlots / SpawnedPetModels             [S]:51-53
    - DataStore load/save/autosave/BindToClose                  [S]:254-432
    - gym, throw, clean, hatch, expand, sell, food, washer, state
    - 1 Hz income loop                                          [S]:942-958
    - builds/updates plot signs, ActiveEgg, pet models          [S]:76-212

Client A — EggSanctuaryClient        (HUD, throw, shop, pets, 2D wash [dead], gym)
Client B — EggRestoration3D          (3D wash stage, wand, upgrades modal)  [does not compile]
Client C — PetShowcaseAnimator       (60 FPS pet/ambient animation, all bases)

ReplicatedStorage
  Modules.GameConfig [shared rules]    Modules.SoundHelper [audio]
  Remotes [10 RFs]                     Sounds [7 names, place-only]
  PetTemplates [5 models, place-only]
```

### 1.2 System inventory

| # | System | Server | Client | Shared config | Authority / trigger |
|---|---|---|---|---|---|
| 1 | Save & session | `[S]:254-432` | — | — | Server. `GetAsync` on join, `UpdateAsync` on leave/every 45 s/cleaner purchase |
| 2 | Plot assignment & spawn | `[S]:215-369` | `[C]:113-137` | `MaxGardenPlots = 6` `[G]:165` | Server picks lowest free `PlayerBase_N`, kicks if none `[S]:226-230` |
| 3 | Gym / Strength | `[S]:437-491` | `[C]:1069-1253` | `TrainCooldown = 1.15` `[G]:172` | Server validates ≤20 studs from **any** plot's gym, then +10 |
| 4 | Throw charge | `[S]:496-508`, `[S]:513-583` | `[C]:236-341` | `ThrowRatio` `[G]:89-104` | Server times `os.clock()` delta from `StartCharge`; falls back to client value |
| 5 | Distance → zone | `[S]:549-550` | `[C]:336-339` (marker) | `Zones` `[G]:16-72`, `GetZoneByDistance` `[G]:154-162` | Server |
| 6 | Reward roll | `[S]:553-566` | display only | `RollRarity` `[G]:107-129`, `RollMutation` `[G]:139-151`, `Mutations` `[G]:132-137` | Server |
| 7 | Egg state | `[S]:557-566`, `[S]:604-640` | `[C]:430-531`, `[R]:1046-1049` | `TotalEggChunks = 30` `[G]:177` | `data.CurrentEgg`; cleanliness maxed from client input |
| 8 | 3D wash | — | `[R]:160-1088` | `EggCrusts` `[G]:179-235`, `CleanerUpgrades` `[G]:240-261` | **Broken** (`[R]:1055-1064`); otherwise client-driven |
| 9 | Legacy 2D wash | `[S]:604-640` | `[C]:374-403`, `[C]:536-612` | — | **Unreachable**: modal never shown |
| 10 | Hatch & garden pets | `[S]:645-697` | `[R]:856-862` | `DefaultMaxSlots = 4` `[G]:166` | Server checks 100%, proximity, `#GardenPets < MaxSlots` |
| 11 | Passive income | `[S]:942-958` | `[C]:139-156` | zone `BaseIncome` `[G]:25-69` | Server, 1 tick/s, additive |
| 12 | Garden slots | `[S]:702-736` | `[C]:629-655` | `MaxSlotsCap = 16`, cost `slots × 500` `[G]:167-170` | Server, +2 per purchase |
| 13 | Food shop | `[S]:789-812` | `[C]:728-808` | `Foods` `[G]:4-13` | Server upgrades exactly one tier at a time |
| 14 | Washer upgrades | `[S]:817-904` | `[R]:560-689` | `CleanerUpgrades` `[G]:240-261` | Server charges money; **effects are client-only** |
| 15 | HUD / leaderstats | `[S]:310-342` | `[C]:29-182` | — | Server writes 6 values; client binds `.Changed` + 2 s backup tick |
| 16 | Pet animation | spawn/attributes only `[S]:114-212` | `[A]:24-138` | — | Client, every frame, all bases |
| 17 | Audio | `[H]:13-41` | `[H]`, `[R]:80-84` | 7 sound names | Server plays parented to the player's HRP; no-op if folder/name missing |
| 18 | Prompts | `[S]:961-980` (gym text) | `[C]:88-111`, `[C]:1243-1253`, `[R]:1073-1083` | — | `ProximityPromptService.PromptTriggered`, string-matched |
| 19 | Tests | — | — | — | `[T]`: math only, Studio-only, not wired to Rojo or CI |
| 20 | Docs / build | — | — | — | `[GDD]`, PDF, HTML, `build_gdd.py` (hard-coded paths) |

### 1.3 State model

`PlayerData[userId]` (`[S]:234-252`):

| Field | Default | Persisted | Notes |
|---|---|---|---|
| `Strength` | 150 | yes | +10/rep, gates distance |
| `BioEssence` | 50 | yes | currency; income adds every second |
| `FoodTier` | 1 | yes | 1–8, shop only |
| `EggsCleaned` | 0 | yes | never shown in HUD |
| `MaxSlots` | 4 | yes | 4 → 16 in +2 steps |
| `GardenPets` | `{}` | yes | `{PetId, Name, Rarity, Mutation, Income, RelX, RelZ}` |
| `CurrentEgg` | `nil` | **no** | lost on leave; blocks throwing |
| `CleanerUpgrades` | `{PSILevel=1, WidthLevel=1, Tier=1}` | yes | effect not read by server |
| `LastThrowTime`, `LastTrainTime`, `ChargeStartTime` | 0/nil | no | anti-cheat only |
| `PlotId` | assigned | no | recomputed on join |
| `LoadFailed` | false | no | blocks writes after a failed load |

`leaderstats`: `Strength`, `BioEssence`, `FoodTier`, `EggsCleaned`, `PlotId`, `MaxSlots` (`[S]:310-342`).

### 1.4 Remote contract

All are `RemoteFunction`s created server-side; the client `WaitForChild`s them by name.

| Remote | Args | Returns | Server validation | Gap |
|---|---|---|---|---|
| `TrainStrength` | — | `Success, NewStrength, Gain` | HRP ≤20 studs from any plot's gym; 1.15 s cooldown | Any plot's gym counts; no "workout active" check |
| `StartCharge` | — | `Success` | In launch zone (X/Z only) | No cooldown; not required by `ThrowFood` |
| `ThrowFood` | `clientDuration` | `Success, Distance, Zone, Food, Rarity, Mutation, IsSweetSpot, Ratio, EggInfo, PlotId` | No existing egg, zone, 1.8 s cooldown | Uses `clientDuration` when no charge was started |
| `CleanEgg` | `chunkIndex, clientCleanliness` | `Success, Cleanliness, IsComplete, Egg` | ≤24 studs from own basin; clamps 0–100 | Accepts any upward jump; ignores `chunkIndex` |
| `HatchEgg` | — | `Success, Message, Pet, Income, TotalIncome, SlotsUsed, MaxSlots` | 100%, ≤24 studs, slots | Proximity to basin is the only pose check |
| `ExpandSanctuary` | — | `Success, NewMaxSlots, BioEssence, Message` | Cost, cap 16 | +2, not the GDD's +4 |
| `ManagePet` | `action, petId` | `Success, Refund, TotalIncome, Message` | Owns pet; `Sell`/`Release` only | Refund `max(10, income × 15)` |
| `UpgradeFood` | — | `Success, Food, NewEssence` | Next tier cost | — |
| `UpgradeCleaner` | `category` (`PSI`/`Width`/`Tier`) | `Success, Category, NewLevel/NewTier, Config, NewEssence, Message` | Cost, max level | Saves on every purchase |
| `GetSanctuaryState` | — | full state incl. `CurrentEgg`, `CleanerUpgrades`, `PlotId` | — | Returns pets table to the owner only |

### 1.5 Hidden place contract (not in the repo)

`[P]` maps only: `ServerScriptService.EggSanctuaryServer.MainGameServer`, three `StarterPlayerScripts`, and `ReplicatedStorage.Modules.{GameConfig, SoundHelper}`.

| Required instance | Consumed by | Failure mode if absent |
|---|---|---|
| `Workspace.EggSanctuaryMap.MultiplayerBases.PlayerBase_1..6` | `[S]:59-64`, `[C]:115-119`, `[A]:11-16` | `getPlayerPlot` returns nil → no sign, no egg visual, no pet spawn, no spawn relocation |
| Per-plot children (see §3) | `[S]`, `[C]`, `[R]`, `[A]` | Silent no-ops; `[R]` falls back to hard-coded `(-184, -77.6, -22)` |
| Launch pad inside `X -75..-35, Z -24..4` | `[G]:75-86`, `[C]:282`, `[S]:502` | No throw UI, throws refused |
| `Workspace.EggSanctuaryMap.DistanceCanyon.<zone>.*Statue*` | `[A]:119-137` | No statue hover (cosmetic only) |
| `PlayerGui.EggSanctuaryHUD` tree | `[C]:29-64` | `[C]` yields forever on `WaitForChild` → no HUD, no throw, no shop, no gym UI |
| `ReplicatedStorage.Sounds.{ThrowWhoosh, AnimalChomp, EggPop, WaterSpray, GymWorkout, PristineChime, HatchFanfare}` | `[H]` | All audio silently skipped |
| `ReplicatedStorage.PetTemplates.{Meadow Bunny, Slime Drake, Ember Hound, Coral Leviathan, Galaxy Titan}` | `[S]:131` | Placeholder 3×3 sphere per pet |
| Backpack/Character `Tool` named `Dumbbell` | `[C]:1291-1341` | One extra gym entry point missing (no error) |
| Server `MaxPlayers = 6` | `[S]:226-230` | Not enforced by code; 7th player is kicked at runtime instead |

HUD tree demanded by `[C]:29-64` (a missing child hangs the script):

```
EggSanctuaryHUD
└ MainFrame
  ├ TopBar.{StrengthBadge, EssenceBadge, FoodBadge, ZoneBadge}
  ├ NoticeLabel
  ├ NavStack.{ShopButton, PetsNavButton, GymNavButton}
  ├ ThrowButton
  ├ ChargeMeterFrame
  │ ├ SegmentsContainer.Segment_1..6.LitLayer
  │ └ ArrowTag.MultiplierLabel
  ├ WashModal            <- dead UI (High #2)
  │ ├ EggContainer.{UIStroke, DirtPatch_1..4}
  │ ├ ProgressBarBG.{Fill, PercentLabel}
  │ └ ScrubButton
  ├ PetInventoryModal.{PetListScroll, SummaryLabel, CloseButton}
  └ ShopModal.{FoodListScroll, CloseButton}
```

---

## 2. Improvements

### 2.0 Audit reconciliation (what changed since `[AU]`)

| `[AU]` item | Status now | Evidence |
|---|---|---|
| 1 — no pet limit / dead remotes | **Fixed** | cap `[S]:660-663`; `ExpandSanctuary` `[S]:702-736`; `ManagePet` `[S]:741-784` |
| 2 — join during load gets plot 1 | **Fixed** | early return includes `PlotId` `[S]:913-922`; client also reads leaderstats `[C]:122-130` |
| 3 — 7th player shares a plot | **Fixed in code**, place setting unverified | kick `[S]:226-230` |
| 4 — income half of display | **Fixed** | 1 s tick `[S]:942-958` |
| 5 — repo cannot run | **Partial** | remotes built in code `[S]:12-39`; map/HUD/sounds/templates still absent |
| 6 — save overwrite | **Partial** | `UpdateAsync` `[S]:379`, still no session lock; hatch not saved |
| 7 — throw rule duplicated | **Fixed** | `[G]:89-104` called from both sides `[C]:333`, `[S]:547` |
| 8 — high tiers always Mythic | **Fixed** | weight curve `[G]:107-129` |
| 9 — server sounds global | **Fixed** | no-parent server calls refused `[H]:18-21`; all callers pass HRP |
| 10 — server animates pets at 25 Hz | **Fixed** | client `[A]:24-138`; server only spawns `[S]:167-172` |
| 11 — setup blocks on first saves | **Fixed** | `task.spawn` `[S]:399-401` |
| 12 — no tests in repo | **Partial** | `[T]` exists; math only, not runnable outside Studio |
| 13 — `build_gdd.py` machine-bound | **Open** | three doc copies still drift |
| 14 — dead/duplicated code | **Partial** | mutations and launch box centralized; `resetWashModal` now dead; unused `plot` `[S]:568` |
| 15 — polling / soft-lock | **Mostly fixed** | `.Changed` bindings `[C]:159-174`; `pcall` + `isThrowing` reset `[C]:418-428`; `executeThrow` is local `[C]:234` |

### 2.1 High — fix before any gameplay work

**H1. `EggRestoration3D.client.luau` does not parse; the wash loop is dead.**
Evidence: the `RunService.RenderStepped` callback closes at `[R]:1055` (`end)`), then `[R]:1056-1064` repeats the tail of the spray loop (`local currentPct … end)`). The `end` at `[R]:1059` has no open block, and `[R]:1064` is a second unmatched `end)`. Luau rejects the file, so the whole script — stage builder, wand, HUD, prompt binding — never loads.
Impact: `CleanEgg` is called only here (live) and in the unreachable 2D modal. `ThrowFood` sets `CurrentEgg.Cleanliness = 0`, `HatchEgg` demands 100, so every session stops at a dirty egg. This is the single reason the game cannot be completed today.
Direction: delete the duplicated 9 lines; add a parse check (StyLua/Luau LSP or `rojo build`) before merge.

**H2. Two competing wash implementations; the 2D one is unreachable dead weight.**
Evidence: `[C]:50-55` requires `WashModal` to exist, `[C]:374-403` builds its reset state, `[C]:536-612` wires scrub/hatch — but no line ever sets `WashModal.Visible = true` (only `false` at `[C]:321`, `[C]:517`, `[C]:597`), and `resetWashModal()` is never called. The live path was replaced by `[R]`.
Impact: ~120 lines of misleading UI logic, a second cleanliness model (`+25%` per brush, ignoring `TotalEggChunks`), and a second hatch path with different feedback. Readers cannot tell which one is real; QA may test the wrong one.
Direction: delete the WashModal branch (and its HUD subtree) in Phase 3, or explicitly re-enable it as a fallback if the 3D stage is unavailable. Do not keep both.

**H3. `CleanEgg` trusts a client-supplied cleanliness value.**
Evidence: `[S]:618-625` takes `clientCleanliness`, clamps 0–100, and assigns it whenever it exceeds the stored value. `chunkIndex` is ignored. The only gate is distance ≤24 studs (`[S]:588-602`).
Impact: any executor can send `CleanEgg(_, 100)` once and skip the entire washer, all 30 chunks, and every PSI/Width/Tier purchase. It also makes the washer upgrade economy unverifiable.
Direction: server owns cleanliness. Either accept one chunk per call at a server rate derived from `CleanerUpgrades`, or have the client report aim only and let the server tick damage. Keep the client value as a hint, never as state.

**H4. The throw-power rule falls back to a client-chosen duration.**
Evidence: `[S]:538-545` — if `data.ChargeStartTime` is nil, `duration` is taken from `clientReportedDuration` and clamped to 0.05–3.0. Nothing forces `StartCharge` to be called first. `[AU]:25` claims a fake 1.6 s hold now yields ×0.5; the current code does the opposite.
Impact: `ThrowFood(1.6)` from a script gets the ×1.25 sweet spot on every throw, bypassing the skill mechanic that gates zone reach. This is the core reward loop.
Direction: no charge start ⇒ treat as a tap (`ThrowRatio(0.1)`) or reject with a message. Never read the client duration.

**H5. The repo still cannot build a playable place.**
Evidence: `[P]` maps 6 scripts. `[C]:29` waits indefinitely for `PlayerGui.EggSanctuaryHUD`; `[S]:8-10` requires `Modules`; the whole server depends on `Workspace.EggSanctuaryMap` and `ReplicatedStorage.PetTemplates`; `[H]` silently no-ops without `Sounds`.
Impact: `rojo build` produces a place with no map and no HUD; `[C]` hangs on its first `WaitForChild`, so there is no throw/shop/gym UI. The game exists only in one local file (`[AU]:61`); every review needs a fake harness (`[AU]:25`).
Direction: commit `map.rbxm`, `hud.rbxm`, `sounds.rbxm`, `pets.rbxm` and map them in `[P]`; or generate the HUD in code and fail loudly with a timeout instead of hanging. This is Phase 1 scope, not Phase 0.

**H6. Washer upgrades are charged but have no server effect.**
Evidence: `[S]:817-904` debits Bio-Essence and stores `PSILevel`/`WidthLevel`/`Tier`; the only consumers of `DamageRate`/`Radius` are `[R]:990-1002`, i.e. the client. The server never reads them to validate or compute anything.
Impact: PSI 5 costs 12,000 `$` and changes only local visuals/rate; combined with H3, a buyer cannot be distinguished from a cheater, and a cheater never needs to buy. Also blocks any future Auto-Washer gamepass.
Direction: move chunk damage/progress to the server (or at minimum rate-limit `CleanEgg` from the purchased PSI), and let the client render the result.

### 2.2 Medium — fix during Phase 1/2

**M1. GDD, README and code disagree on the core tables.**
- Zone cutoffs: `[GDD]:71-77` says 300 / 1,500 / 5,000 / 15,000; `[G]:16-72` uses 300 / 1,000 / 2,500 / 5,000. `[T]:7-13` encodes the code values, so tests cement the drift.
- Food names: `[GDD]:58-65` "Carrot Cupcake", "Rainbow Cotton Candy"; `[G]:6,10` "Carrot Cake", "Rainbow Candy". T7 shiny chance 22.5% vs 25%.
- Zone yields: GDD 1–5 / 15–60 / 200–800 / 2.5k–10k / 50k+; `[G]:25-69` uses 2 / 12 / 75 / 450 / 3,000 base (pre-multiplier), so displayed "base" differs by up to 6×.
- Incubators: `[GDD]:88` sells "+4 (4→8)"; code has `MaxSlots` 4→16 in +2 steps `[G]:166-170`, `[S]:717`.
- README says income every 2 s and a "procedural fallback" in SoundHelper; both are false (`[S]:944`, `[H]:13-41`).
Impact: balance conversations use three different truths; tests look green while asserting a design nobody signed off.
Direction: pick the code (it is the only executable truth), update `[GDD]`/README, then convert the GDD tables into a doc-generation step so they cannot drift again.

**M2. Late-game economy collapses to "always Mythic, always Rainbow".**
Computed from `[G]:107-151`:
- Luck 1: Common 49.5%, Rare 22.5%, Epic 16.2%, Legendary 9.0%, Mythic 2.7%.
- Luck 100: Common 11.2%, Rare 25.5%, Epic 36.7%, Legendary 20.4%, Mythic 6.1%.
- Mutations at tier 8 (35% roll): Rainbow 3.5% (×10), Golden 7% (×5), Shiny 20% (×2.5) ⇒ expected ×1.90 income.
- Zone 5 common = 3,000/s; zone 5 Mythic Rainbow = **450,000/s**; 16 slots ⇒ ~7.2M/s.
`[T]:52-55` only asserts "Mythic < 30%" and "Legendary > 15%", which passes at these numbers, so the test cannot catch inflation.
Impact: food tier 8 (1M `$`) and the whole slot ladder (6 steps, 2,000–7,000 `$` each, 27,000 `$` total to reach 16) become trivial; the GDD's "1-in-10,000 Godly" rarity does not exist in code at all.
Direction: decide the endgame curve first (target Mythic share per tier, mutation expected value, pet cap), then tighten `[T]` to those targets. Add a Godly tier or delete the claim from the GDD.

**M3. Wash duration is unreasonable at high zones with starter gear.**
Evidence: chunk HP 40 / 75 / 120 / 175 / 240 `[G]:186-230`; 30 chunks `[G]:177`; PSI 25→180 `[G]:242-246`. Single-target time = `30 × HP ÷ PSI`: zone 1 at PSI 1 ≈ 48 s; zone 5 at PSI 1 ≈ 288 s; zone 5 at PSI 5 ≈ 40 s. The radius check `[R]:997-1002` damages every chunk in range at once, so real times are shorter, but the spread between a new player and a maxed washer is extreme.
Impact: a player who reaches Galaxy before upgrading the washer faces minutes of holding a button — the exact "chore" the ASMR premise is meant to avoid.
Direction: normalize crust HP against the expected PSI for that zone, or scale damage by zone, and state the target seconds-per-egg per zone in the GDD.

**M4. `PetShowcaseAnimator` cost scales with every pet in every base, every frame.**
Evidence: `[A]:28-72` loops all 6 bases × all pets × `GetChildren()` per pet and writes `pet:PivotTo` plus per-part `CFrame` for tail/ear/crest. At 6 × 16 pets × ~40 parts this is thousands of part transforms per frame, per client, on top of `[A]:76-137` station/canyon work.
Impact: mobile frame time and battery; worst case is exactly the full server the game is designed for.
Direction: animate only the local player's plot, cache part lists once per pet (not per frame), and throttle sub-part motion to a lower rate than `PivotTo`.

**M5. `hasEggInCleaner` goes stale after the 3D hatch.**
Evidence: set true on throw `[C]:431`, read for notices `[C]:303-305`; the only reset is the dead 2D hatch path `[C]:595`. `[R]:856-862` hatches without telling `[C]`.
Impact: after a successful hatch, walking off the pad still says "Dirty Egg waiting at your Egg Cleaner"; the prompt handler `[C]:96-100` also refuses to warn correctly. Confusing but not blocking.
Direction: derive the flag from `GetSanctuaryState`/`CurrentEgg` instead of mirroring it, or expose a client-side event.

**M6. Space is bound twice with conflicting meanings.**
Evidence: `[C]:357-362` starts a throw on Space; `[R]:898-904` starts spraying on Space. While restoring, Space fires both. `startCharge` is not in the launch zone, so it shows "Walk forward to the Yellow Launch Pad" `[C]:237-240` on every spray press.
Impact: notice spam over the wash HUD; two input systems fighting for one key.
Direction: gate `startCharge` on mode (not in restoration / not in workout), or use a different spray key.

**M7. Restoration edge cases leave the player stuck or the camera wrong.**
Evidence: hatch errors are ignored `[R]:856-862` (no message, unlike `[C]`); `stopRestoration` sets `Camera.CameraType` then writes `Camera.CFrame` `[R]:845-851` (the write is ignored under `Custom`); death during a wash stops the render loop but leaves `RestorationGui`/wand until `stopRestoration` runs; `CleanEggRemote:InvokeServer` `[R]:1048` is not wrapped in `pcall`, so one server error aborts the frame loop.
Impact: soft-locks and silent failures around the most expensive interaction in the game.
Direction: wrap remote calls, restore camera state before type, and add a `CharacterRemoving`/`Humanoid.Died` cleanup that calls the same exit path.

**M8. Save coverage gaps.**
Evidence: `[S]:379-390` persists 7 fields — `CurrentEgg` is absent, so a dirty egg and its cleanliness vanish on rejoin; `HatchEgg` does not save (`[S]:684-696`), so up to 45 s of pet progress is at risk; `UpgradeCleaner` saves on each purchase (`[S]:838, 864, 890`), which can hit Roblox's ~1 write/6 s/key limit; no session lock, so the cross-server overwrite from `[AU]:69-73` remains possible.
Impact: "I lost my egg/pet after rejoining" reports; throttled writes logged as warnings.
Direction: add `CurrentEgg` to the payload (with a resume path), mark data dirty and let the autosave loop write once, and adopt ProfileStore-style session locking.

**M9. Launch-zone and proximity checks drift.**
Evidence: `IsInLaunchZone` tests only X/Z `[G]:82-86`, so a player standing on a roof above the pad can throw; server cleaner radius 24 `[S]:601`, client modal radius 20 `[C]:320`; server gym radius 20 `[S]:452`, client gym nav 22 `[C]:1284`; server gym accepts any plot's station `[S]:456-464`.
Impact: edge-case throws from above; prompts that look usable but are refused (or vice versa); cross-plot training.
Direction: include Y (or a downward raycast) in the launch test; export the three radii to `[G]` and consume them everywhere; restrict the gym to the player's own plot.

**M10. Tests cover only the math and cannot run in CI.**
Evidence: `[T]` asserts zones, `ThrowRatio`, launch box, and 10k-roll distributions. Nothing covers `CleanEgg`, `HatchEgg`, slot cap, save payload, or the client/server contract; it requires `game.ReplicatedStorage.Modules.GameConfig`, so it only runs when pasted into Studio. `[P]` does not map `tests/`.
Impact: the two regressions that matter most (H1 parse break, H3 trust) would both pass a green test suite.
Direction: add a headless runner (Lune/`luau` CLI with a `GameConfig` shim) and at least: parse-check every `src` file, `CleanEgg` rate limit, hatch cap, save round-trip.

**M11. Monetization from the GDD is entirely unimplemented.**
Evidence: `[GDD]:85-90` lists Auto-Thrower, Auto-Washer, Lucky Chef, +4 Incubators, Golden Feast, Instant Hatch. No `MarketplaceService`, gamepass or dev-product code exists anywhere in `src/`.
Impact: if Phase 1 assumes revenue hooks, they are greenfield, not "wire-up". The Auto-Washer in particular conflicts with H3/H6 (it must be server-side to be safe).
Direction: scope explicitly. Implement none until the washer authority model is settled.

**M12. World positions are hard-coded fallbacks in three files.**
Evidence: pet center `(-155, -77.9, -36)` `[S]:126`; player spawn `(-155, -73, -18)` `[S]:359`; cleaner `(-184, -77.6, -22)` `[C]:486` and `[R]:716`; launch marker `(-55, -76.8, z)` `[C]:339`; camera offsets `[C]:471`, `[R]:772`.
Impact: moving the map silently teleports eggs/pets/camera to empty space. `[AU]:14` flagged the same class of bug for the launch box.
Direction: put one `GameConfig.WorldAnchors` table (or read from map attributes) and delete the literals.

**M13. Pet template contract has a silent low-quality fallback.**
Evidence: `[S]:131-142` falls back to a 3×3 sphere when `PetTemplates` is missing or the name does not match. The five expected names are in `3D_ARTIST_GUIDE.md:121-127`.
Impact: a typo in a model name produces spheres instead of an error, so missing art ships unnoticed.
Direction: warn once per missing template and list expected names.

### 2.3 Low — cleanup, docs, polish

- **L1. Dead code.** `resetWashModal` `[C]:374-403`; unused `plot` `[S]:568`; unused `vol` parameter `[R]:80`; `getBases()` allocates a fresh child table every frame `[A]:28`; `Camera` captured once at load `[C]:10`.
- **L2. Audio silence is invisible.** `[H]:15-16` returns if the sound name is missing; `[H]:34` keeps a 20 s safety cap; `[R]:80` ignores its volume argument. Add a one-time warning per missing name.
- **L3. Docs/build drift.** `build_gdd.py` hard-codes `C:\Users\USER\...`; `[GDD]:9-11` links three copies (md/html/pdf). `[AU]:111-115` already recommended one source.
- **L4. README inaccuracies.** "every 2 seconds" (`README.md:31`), "treadmill" (`README.md:35`) vs `BicepCurlStation`, "procedural fallback" (`README.md:56`), repo tree omits `PetShowcaseAnimator` and `EggRestoration3D` (`README.md:51-56`).
- **L5. Naming drift.** Stat is `Strength` but UI says "REACH" and "+10 Reach" (`[S]:971`, `[C]:143`, `[C]:1210`); prompt text is server-set with a different verb. Pick one word.
- **L6. HUD contract is silent.** `[C]:29-64` uses untimed `WaitForChild`; a renamed label hangs the entire client with no error. Add timeouts and a clear warn.
- **L7. `EggsCleaned` is tracked, saved and never displayed** (`[S]:329-332`, `[S]:666-669`).
- **L8. Studio load-failure path silently never saves** (`[S]:267-274` sets `LoadFailed`, `[S]:374` blocks writes). Fine for a harness, confusing for a designer testing balance.
- **L9. Remote chatter.** Thirty `CleanEgg` invokes per egg (`[R]:1046-1049`), each triggering `updateSanctuaryWorldVisuals` (`[S]:627`) and a sign text rebuild. Batch progress or send at milestones.
- **L10. `RenderStepped` loop in `[A]` has no pause** when no plot is nearby; early-out on the local plot only (see M4).

### 2.4 Suggested order

1. H1 (delete 9 lines) → verify a full throw → clean → hatch cycle in Studio.
2. H2 (delete the dead wash UI) so there is one wash truth.
3. H3 + H4 + H6 together (server owns cleanliness, throw duration, washer effect). These are one design decision: what does the server trust?
4. H5 (assets into the repo) so anyone can reproduce 1–3.
5. M8, M7, M5, M9, M6 (save and state hygiene), then M1/M2/M3 (design numbers), then M4/M10 (perf and regression safety).

---

## 3. Plot objects

Destination legend:

- **keep** — stays per player, in `PlayerBase_1..6`.
- **hub** — recommend moving to a single shared world area (no hub exists today; that area would be new Phase 1 work). Chosen when six copies add nothing and no avatar is pinned to the object.
- **remove** — unused, dead, or promises a feature that does not exist.
- **unresolved** — outside the three-way choice until a design question is answered (§4).

Evidence basis: every row is a string lookup in `src/`. The place itself was not available.

### 3.1 Scripted plot objects

| ID | Object | Expected path | Driving script(s) | What it does today | Destination |
|---|---|---|---|---|---|
| PO-01 | `PlayerBase_N` (Model) | `EggSanctuaryMap.MultiplayerBases.PlayerBase_1..6` | `[S]:57-64, 219-232, 302-308, 352-363`; `[C]:113-120`; `[A]:11-16` | Per-player container; server assigns lowest free index, kicks at 6; client resolves from `leaderstats.PlotId` | **keep** |
| PO-02 | `BaseSign` (Part + `SurfaceGui` + `TextLabel`) | `PlayerBase_N.BaseSign` | `[S]:86-91` | Writes `"<DISPLAYNAME>'S BASE (+N $/s)"` on every income-relevant change | **keep** |
| PO-03 | `EggCleaner` (Model) | `PlayerBase_N.EggCleaner` | `[S]:94-111, 588-602, 627, 651-653`; `[C]:88-111, 313-325, 485-503`; `[R]:714-724, 1073-1083`; `[A]:76-92` | Washer station: proximity gate for clean/hatch, target for the returning egg, anchor for the 3D stage, prompt host | **keep** *(see Q2)* |
| PO-04 | `EggCleaner.WashBasin` | `PlayerBase_N.EggCleaner.WashBasin` | `[S]:592`; `[C]:91, 316, 486`; `[R]:715, 1076` | Position anchor for distance checks, egg return, camera and stage; host of the prompt | **keep** |
| PO-05 | `EggCleaner.ActiveEgg` (must be a `BasePart`) | `PlayerBase_N.EggCleaner.ActiveEgg` | `[S]:95-110`; `[A]:78-86` | Server sets transparency/colour (mud → neon gold); client bobs it | **keep** |
| PO-06 | `EggCleaner.WaterPool` | `PlayerBase_N.EggCleaner.WaterPool` | `[A]:88-91` | Client-only transparency pulse | **keep** |
| PO-07 | Basin `ProximityPrompt` | `PlayerBase_N.EggCleaner.WashBasin` child | `[C]:92-101` (text + notice); `[R]:1076-1083` (opens 3D wash) | Two listeners on the same prompt: one warns, one starts restoration | **keep** (one listener after H2) |
| PO-08 | `ChefStall` (Model) | `PlayerBase_N.ChefStall` | `[C]:103-110` | Host for the food-shop prompt; no server logic | **hub** |
| PO-09 | `ChefStall.Counter` (+ prompt) | `PlayerBase_N.ChefStall.Counter` | `[C]:104-110` | Opens `ShopModal` | **hub** |
| PO-10 | `ChefStall.LanternGlass` | `PlayerBase_N.ChefStall.LanternGlass` | `[A]:95-102` | Client sway animation | **hub** (child of stall) |
| PO-11 | `BicepCurlStation` (Model) | `PlayerBase_N.BicepCurlStation` | `[S]:450-464, 966-978`; `[C]:1245-1253, 1272-1285, 1308-1323` | Gym; server validates ≤20 studs and adds +10 Strength; client pins avatar, animates arms, invokes reps | **keep** |
| PO-12 | `BicepCurlStation.InteractPart` (+ prompt) | `PlayerBase_N.BicepCurlStation.InteractPart` | `[S]:451-452, 966-975`; `[C]:1273-1278` | Distance anchor and prompt host; server rewrites prompt text at boot | **keep** |
| PO-13 | `BicepCurlStation.CurlSeat` | `PlayerBase_N.BicepCurlStation.CurlSeat` | `[C]:1098-1105` | Client snaps the HRP onto the seat facing the pad | **keep** |
| PO-14 | `BicepCurlStation.ArmPad` | `PlayerBase_N.BicepCurlStation.ArmPad` | `[C]:1099-1105` | Look-at target for the seat snap | **keep** |
| PO-15 | `GymTreadmill` (legacy alias) | `PlayerBase_N.GymTreadmill` | `[S]:450, 458, 966` | Server-only fallback name; no client support (`[C]` searches only `BicepCurlStation`) | **remove** |
| PO-16 | `GardenYard` (Model) | `PlayerBase_N.GardenYard` | `[S]:124, 357` | Yard container; anchor for pet spawn and player spawn | **keep** |
| PO-17 | `GardenYard.YardFloor` | `PlayerBase_N.GardenYard.YardFloor` | `[S]:125-129` (pet centre +2.4 Y), `[S]:358-361` (player spawn +4 Y/+18 Z) | The only position source for pets; missing ⇒ hard-coded fallback | **keep** |
| PO-18 | `GardenYard.RewardChest` + `Lock` | `PlayerBase_N.GardenYard.RewardChest.Lock` | `[A]:104-116` | Client colour pulse only; no reward, no prompt, no server code | **remove** (or keep as silent decor — it currently implies an unopened chest) |
| PO-19 | `PetsInGarden` (Folder, runtime) | `PlayerBase_N.PetsInGarden` | `[S]:121-122, 172, 304-307`; `[A]:30-32` | Holds spawned pet models; cleared on setup; destroyed on leave | **keep** |
| PO-20 | Incubator | *(does not exist in code or the map string lookups)* | `[GDD]:88`; `3D_ARTIST_GUIDE.md:98` ("EggModel hovering over incubators") | No object, no timer, no capacity; `MaxSlots` is the only limit and hatching is instant | **unresolved** (§4) |

### 3.2 Art-only plot objects (no script references)

From `3D_ARTIST_GUIDE.md:37-62`. None of these appear in `src/`, so they are pure decor unless the place names them differently.

| Object | Script | Destination |
|---|---|---|
| Split-rail fence + open gate | none | keep (decor) |
| Cobblestone stepping path | none | keep (decor) |
| Flower beds | none | keep (decor) |
| 4 corner lantern posts + PointLights | none (only `ChefStall.LanternGlass` is animated) | keep (decor) |
| Golden reward chest | `[A]:104-116` (colour pulse) | remove (see PO-18) |

### 3.3 World objects the plot code depends on

| ID | Object | Path | Consumed by | Destination |
|---|---|---|---|---|
| PW-01 | Launch pad / runway | inside `[G]:75-86` box (X −75…−35, Z −24…4) | `[S]:502, 528`; `[C]:282, 336-339` | keep (world) |
| PW-02 | `EggSanctuaryMap` + `MultiplayerBases` | `Workspace` | `[S]:59`; `[C]:115`; `[A]:12-15` | keep (world) |
| PW-03 | `DistanceCanyon` zone folders + `*Statue*` models | `EggSanctuaryMap.DistanceCanyon` | `[A]:119-137` | keep (world, cosmetic) |
| PW-04 | `Workspace.Terrain` | `Workspace.Terrain` | `[R]:737-762` (beam/splash parent) | keep (required by 3D wash) |
| PW-05 | Runtime props (`LandingPreviewMarker`, `FlyingFood`, `ReturningEgg`, `EggRestorationStage`, `PowerWasherWand`, `HighPressureWaterJet`) | `Workspace` | `[C]:187-209, 439-448, 487-496`; `[R]:172-174, 732, 739-749` | keep (client-created; must be cleaned up on exit) |
| PW-06 | `ReplicatedStorage.PetTemplates` (5 models) | `ReplicatedStorage` | `[S]:131` | keep (must be committed) |
| PW-07 | `ReplicatedStorage.Sounds` (7 names) | `ReplicatedStorage` | `[H]:6-16` | keep (must be committed) |
| PW-08 | `PlayerGui.EggSanctuaryHUD` (full tree in §1.5) | `PlayerGui` | `[C]:29-64` | keep, minus the `WashModal` subtree (H2) |
| PW-09 | `Dumbbell` Tool | `StarterPack`/`Backpack` | `[C]:1291-1341` | keep (optional entry point; undocumented in README) |

### 3.4 Duplication and hub notes

- Six copies exist for `EggCleaner`, `BicepCurlStation`, `ChefStall`, `BaseSign`, `GardenYard`. Only `ChefStall` has no spatial exclusivity, which is why it is the sole **hub** recommendation.
- If the washer moves to a hub, `[R]:694-724` (avatar snap + stage built at the basin) and `[S]:588-602` (24-stud gate) must be redesigned for queueing; do not move it without that work.
- `BicepCurlStation` cannot be shared as-is: `[C]:1097-1106` teleports the HRP to `CurlSeat` and zeroes `WalkSpeed`, so two players would occupy the same seat.
- Removing `GymTreadmill` (PO-15) requires confirming no map still uses that name; the server currently accepts either.

---

## 4. Questions about the washer and incubator

These block the destination decisions for PO-03/PO-04/PO-20 and the authority fix in H3/H6.

**Washer**

1. **Is `EggCleaner` the washer, and is the GDD's "3-layer wash / pressure nozzle peeling" (`[GDD]:42`) the same thing as the 30-chunk crust, or three explicit stages (rinse → soap → polish) that the code should model?** Today the only model is `TotalEggChunks = 30` with per-zone HP.
2. **Per-plot or hub?** Each player currently gets a basin, and the 3D stage builds at that basin and pins the avatar (`[R]:699-724`). If it becomes a shared hub station, how many basins, and do players queue, share one egg visually, or get instanced stages?
3. **Who owns wash progress?** Options: (a) server ticks damage from PSI while the client reports "spraying" + aim; (b) client reports per-chunk completion, server validates rate; (c) keep client-authoritative and accept the exploit. This decides H3/H6 and the Auto-Washer gamepass.
4. **What do PSI / Width / Tier actually change?** Current code: PSI = damage rate, Width = radius, Tier = wand colour/material only. Should Tier also gate which crust types can be removed (e.g. obsidian needs Tier ≥ 2), and should Width affect the number of chunks hit, the beam width, or both?
5. **What is the target seconds-per-egg per zone?** With the current numbers, a zone-5 egg at PSI 1 is ~288 s of continuous single-target spray (`[G]:230, 242`). Is that intended difficulty, an oversight, or should crust HP scale with the player's washer level instead of the zone?
6. **Can a dirty egg be abandoned, shared, or resumed?** `CurrentEgg` is not saved (`[S]:379-390`), blocks throwing (`[S]:518-520`), and has no cancel. If a player leaves mid-wash, should the egg persist, be refunded, or be lost?
7. **Should washing be interruptible?** The only distance check lives in the dead 2D modal (auto-close at >20 studs, `[C]:314-325`); the 3D stage has no distance check and no death cleanup (`[R]:825-852`). What is the intended fail state — progress kept, egg dropped, or stage restart?

**Incubator**

8. **Is the incubator a separate object at all?** `[A]:75` calls `EggCleaner.ActiveEgg` an "Incubator Egg", the art guide says `EggModel` hovers "over incubators" (`3D_ARTIST_GUIDE.md:98`), and the code has no incubator instance. Is the garden yard itself the incubator, or is a new prop expected?
9. **Which capacity is authoritative: the GDD's "+4 incubators (4→8)" gamepass (`[GDD]:88`) or the code's `MaxSlots` 4→16 in +2 steps for Bio-Essence (`[G]:166-170`, `[S]:702-736`)?** Two systems for one cap will conflict; one should be deleted or renamed.
10. **Is hatching instant or timed?** Today `HatchEgg` inserts the pet immediately (`[S]:674-696`) and the pet earns from the next tick. If incubation is timed, who runs the timer (server), what does the player see (egg model in the yard?), and does a pet occupy a slot while incubating?
11. **Where do incubators live — inside the fenced yard, a row beside the washer, or the hub?** This decides whether PO-20 is `keep` (per plot) or `hub`.
12. **Does incubation replace the current "put the clean egg in the garden" action or add a step after it (clean → incubate → pet)?** The UI copy currently promises "PUT IN GARDEN TO GROW & HATCH" (`[C]:559`, `[R]:545`), which implies a growth phase the server does not simulate.
13. **Does the Auto-Washer Robot (R$899, `[GDD]:86`) bypass the 3D wash entirely?** If yes, it must be implemented server-side (after H3/H6), and it changes what "washing" means for paying players.
