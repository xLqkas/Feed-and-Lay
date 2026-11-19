# Audit: Feed and Lay (code name "Egg Sanctuary")

Date: 2026-11-19. Read-only audit. Nothing in the game, the repo or Studio was changed.
Sources: repo `main` at `5781a3d` (14 commits), the live Studio place "Feed an Lay" (placeId 113603218122384, Edit mode), read with the Studio MCP tools.
**Not done:** the game was not play-tested. Play mode was off limits, so everything below about how the game plays comes from reading code and looking at the place in edit mode (3 screenshots).

---

## 1. What the game is meant to be

**Concept.** It is a mash-up of "Throw Food for Animals", PowerWash Simulator and Grow a Garden. You throw food down a canyon. A creature eats it and lays a muddy egg. You power-wash the egg clean, it hatches into a pet, and the pet earns passive money. Strength decides how far you throw. Food tier decides your luck.

**Where the plan lives:**
- `Egg_Sanctuary_GDD.md`: "Master Game Design Document (GDD v2.1 — Food Luck & Dual Treadmill Edition)". It holds the core loop diagram (Train → Throw → Animal lays → "3-Layer Wash (Pressure Nozzle Peeling)" → Garden Hatch), 8 food tiers, 5 biomes with 3 creatures each, and monetization (Auto-Thrower R$799, Auto-Washer R$899, Lucky Chef R$499, +4 Incubators, Golden Feast Bait, Instant Hatch Potion). It sets a target of "250,000 – 400,000+ Concurrent Players".
- `Egg_Sanctuary_Clean_and_Hatch_GDD.html` / `.pdf`: the same GDD rendered by `build_gdd.py`. The `.md` still links to `C:\Users\USER\.gemini\antigravity\...` (another person's machine).
- `README.md`: the core loop as one line ("Train strength at the gym → Walk onto the marked Launch Station … → Place the clean egg in your open wooden garden yard … Upgrade food & repeat!"). Parts of it are out of date: it describes 4 dirt patches with 25% per brush and a treadmill gym.
- `3D_ARTIST_GUIDE.md`: the art bible (5 creatures, part naming for procedural animation, under 4k tris, PBR SurfaceAppearance).
- `audits/FILIP_2026-11-17_Audit.md`: the owner's earlier code audit (15 items).

**Intended core loop (as built):** curl dumbbells at the gym for Reach → stand on the yellow launch pad and hold-release to throw → the food lands at a distance that picks the biome → a mud egg flies back to your Egg Cleaner → walk back and power-wash 30 dirt chunks → press Hatch → the pet appears in your fenced yard and earns $/s → spend $ on food tiers, washer upgrades and garden slots.

---

## 2. What actually exists (systems and verdicts)

Repo code, synced into Studio by Rojo (see section 8):

| System | Where | Verdict |
|---|---|---|
| Player data load/save, autosave every 45 s, BindToClose | `src/server/MainGameServer.server.luau:41-432` | **Works, but fragile.** Raw DataStore (`EggSanctuary_SaveData_v6`). `UpdateAsync` ignores `oldData`, so there is no session lock. `CurrentEgg` is not saved, so leaving loses the egg. `UpgradeCleaner` saves on every purchase (`:838,864,890`), which will run into DataStore throttling. |
| Plot assignment (6 plots, kick 7th player) | server `:215-232` | **Works.** Server max-players is not set in the repo, so it could not be verified. |
| Gym: auto bicep curl | client `src/client/EggSanctuaryClient.client.luau:811-1341`, server `:437-491` | **Works, bad design.** Press E once and you earn +10 Reach every ~1.35 s with no further input. That is an AFK loop, despite the commit title "anti-autoclicker". The arms are animated by writing Motor6D `C0` on the client (`:1135-1188`), which does not replicate, so other players see you sit still. The same nearest-station search is copy-pasted twice (`:1256-1289`, `:1292-1328`). |
| Throw: launch zone, 6-segment meter, sweet spot | client `:184-531`, server `:496-583`, `GameConfig.ThrowRatio` | **Works, thin.** The server times the charge, and the meter logic is shared now. The "throw" is a neon ball tweened in a straight line (no arc), then a brown ball tweens back. No creature reacts: "CHOMP!" is a text notice plus `snap.wav`. |
| Biome / rarity / mutation roll | `src/shared/GameConfig.luau:16-162` | **Works.** Luck now shifts weights (the old "all Mythic" bug is fixed). There are only 5 creatures in total, one per zone. |
| 3D power-wash station | `src/client/EggRestoration3D.client.luau` | **Works in Studio, broken in the repo.** Repo lines 1056-1064 are a duplicated block left over from a bad edit: a syntax error, so the whole LocalScript would not run. The Studio copy (1079 lines) does not have it. When it works: the camera locks, there are 30 part-chunks with HP, and you hold to spray. A "front of egg" fallback (`:1000-1001`) cleans chunks you are not even aiming at, so aiming barely matters. |
| Old 2D wash modal | `StarterGui.EggSanctuaryHUD.MainFrame.WashModal` + client `:371-612` | **Dead.** No code ever sets `WashModal.Visible = true`. About 240 lines of client code plus a GUI tree do nothing. |
| Hatch → pet in yard | server `:645-697`, `spawnPetInGarden :115-212` | **Works, no payoff.** Instant. No hatch animation, no camera on the new pet, no rarity reveal. The pet is just added to the yard. |
| Pet "roaming" animation | `src/client/PetShowcaseAnimator.client.luau` | **Placeholder.** Each pet moves in a 1.8-stud circle around a fixed point and bobs. It is not roaming. Tail and ear rotations add up frame by frame. The art guide promises `Wing_*` and `Head_*` motion that the code does not have. |
| Food shop (8 tiers) | client `:725-808`, server `:789-812` | **Works, meaningless early.** Tier 2 costs 150 $, which takes about 50 s of starter income. Buying "equips" automatically; you cannot choose which food to use. |
| Washer upgrades (PSI, Width, Tier) | `EggRestoration3D :560-689`, server `:817-904` | **Works.** Only reachable from inside the wash screen. |
| Garden slots expand / sell pet | client `:617-723`, server `:702-784` | **Works, exploitable.** Selling pays `Income × 15` with no cooldown and no distance check. |
| Passive income tick (1 s) | server `:942-958` | **Works.** No "+$" feedback anywhere in the world. |
| Base sign "NAME'S BASE (+X $/s)" | server `:85-91` | **Works.** It is a small dark bar floating at the plot edge, easy to miss. |
| Day/night cycle | Studio-only `ServerScriptService.DayNightCycle` | **Works, hurts the game.** A 10-minute cycle with dark nights (ambient 30,34,48) in a kids' bright collect game, updated 20×/s on the server. |
| `Teams.Script` | Studio only | **Junk.** `print("Hello world!")` hidden under Teams. |
| Monetization (gamepasses, dev products) | — | **Missing.** No `MarketplaceService` use anywhere. |
| Rebirth, index, quests, leaderboards, trading, daily rewards, codes | — | **Missing.** |
| Tests | `tests/test_game_math.luau` | **Half-done.** Assert script for GameConfig math, not mapped in Rojo, no runner. |

---

## 3. UI

**How it is built:** a mix of two approaches with no framework.
- `StarterGui.EggSanctuaryHUD` is hand-built in Studio and exists only in the place file: TopBar with 4 badges, NavStack with SHOP/PETS/GYM, ThrowButton, ChargeMeterFrame with 6 segments, NoticeLabel, ShopModal, PetInventoryModal, and the dead WashModal. 134 descendants.
- Everything else is built in Luau with `Instance.new` and hard-coded pixels: WorkoutHud (client `:924-1002`), shop and pet cards (`:617-796`), the whole wash HUD and Washer Workshop (`EggRestoration3D :355-689`), pet name billboards (server `:174-209`) and floating "+10 REACH" text.

**What is concretely bad:**
1. **Not mobile-ready.** The GDD says "Mobile-First 75%", but everything is sized in pixel offsets with no `UIScale` or aspect constraints: ShopModal 440×320 px, wash progress bar 520 px, wash header 480 px, Washer Workshop 420×360 px. On a 375-px-wide phone these overflow the screen. Button hints say "[SPACE / WASD / E]" and "Hold Space".
2. **Two visual languages.** The Studio HUD uses FredokaOne with bright gradient pills. Every code-built panel uses Gotham on dark navy cards (`18,22,32`). Opening the shop or the wash screen feels like a different game.
3. **Emoji as icons.** "💩 THICK MUD", "💪 REACH", "🍎", "🔫". The GUI has no ImageLabels at all. The wash crosshair uses `rbxasset://textures/ui/GuiImagePlaceholder.png`, which is literally the placeholder image (`EggRestoration3D :370`).
4. **The NoticeLabel is the only feedback channel.** Every event overwrites one line of text, and long messages get cut off (for example "Monster laid a Muddy Egg! It landed in your Egg Cleaner! Walk to your base to scrub it clean!"). The edit-mode default text "Head to the Launch Runway…" disagrees with the code's text.
5. **Overlapping buttons.** In the wash HUD the Hatch button (380 px, bottom-center, `-82`) sits on top of the progress frame (520 px, bottom-center, `-86`).
6. **Numbers are not formatted.** "BIO: 1000000 $". The leaderstats leaderboard shows `PlotId` and `MaxSlots` as player stats.
7. **Shop and pets are bare lists.** No pet portraits or viewports, no rarity colors beyond a 1.5-px stroke, no "what's next" goal, no confirm on SELL (one tap destroys a pet).
8. **The GYM button works only within 22 studs of a curl station.** Anywhere else it just says "walk there". The Dumbbell Tool in `StarterPack` is a second, redundant way to do the same thing, and it clutters the hotbar.

---

## 4. Gameplay: the first 5 minutes as implemented

1. **0:00** You spawn in your fenced yard with 1 white-and-pink part-built Meadow Bunny, 50 $, Reach 150. The HUD says "Head to the Launch Runway". There is no arrow, beam or path to it. The pad is about 100 studs from plot 1, and farther from the other plots.
2. **0:30** You find the yellow pad. Hold and release. A red ball flies straight for about 1–2 s, landing at most 187 studs away. That is always Dewdrop Meadow, so the egg is always a Meadow Bunny. "CHOMP!" appears, the camera snaps back to your cleaner, and a notice tells you to walk home.
3. **1:00** While that egg sits unwashed you **cannot throw again** (server `:518`). So you walk back about 100 studs.
4. **1:30** Press E on the cleaner. The camera locks, and you hold to spray 30 chunks (40 HP each at 25 dmg/s), which takes about 50–70 s of holding one button. The turntable auto-spins, and chunks facing you clean even when you are not aiming.
5. **2:40** Hatch. The bunny appears in the yard. Nothing tells you its rarity or that your income went up, except the small sign.
6. **3:00–5:00** Repeat steps 2–5. Each cycle takes about 2 minutes and adds +2 $/s. You learn the gym by accident. Once you do, it is an AFK button: about 9 minutes of idle curling reaches the last zone (Reach 4000 × 1.25 = 5000), where a pet earns 3000 $/s against the Meadow's 2. After that there is nothing left to do.

**Boring:** the serial one-egg loop, long walks with nothing on the way, a 60-second hold-a-button wash, a passive AFK gym, and the same reward over and over.
**Confusing:** no guidance between stations, two gym entry points plus a tool, the dead wash modal, a canyon that does not match the config (Meadow floor spans Z 0–500, but the config switches to Marsh at 300; the folder is named "Luminescent Swamp" while the config says "Toxic Slime Marsh"; the Galaxy statue is a "Divine Kitsune" while the config's creature is "Galaxy Titan").
**Broken:** the repo copy of the wash station does not compile; leaving with an egg loses it; other players never see you curl.

---

## 5. Architecture and code health

- **Structure:** 3 god scripts. `EggSanctuaryClient` (1349 lines) holds the HUD, throw, wash v1, shop, pets and gym. `EggRestoration3D` (1088 lines) is the wash v2. `MainGameServer` (982 lines) holds everything server-side. `GameConfig` is the only shared module. There are no services, no state store and no UI components.
- **Networking:** 10 `RemoteFunction`s, created in code by the server, and no `RemoteEvent`s. The client polls `GetSanctuaryState`, and the server never pushes. Studio still has stale remotes `SelectFood` and `CollectCoins` with no handler. `CleanEgg` is invoked from inside a `RenderStepped` callback (`EggRestoration3D :1048`).
- **Anti-cheat holes:**
  - `CleanEgg` trusts a client-sent cleanliness (`server :618-622`). One call `CleanEgg:InvokeServer(1, 100)` cleans instantly.
  - `ManagePet "Sell"` pays `Income × 15` and the server never checks the pet was earned with effort. Combined with the hole above, an exploiter can farm Galaxy Titans (45,000 $ per sale) as fast as the throw cooldown allows.
  - `ThrowFood` without `StartCharge` accepts a client duration (`:543-545`), so a client can always send 1.6 s and hit the sweet spot.
- **Saving:** see section 2. There is no ProfileService, although the GDD lists "ProfileService" in the tech stack.
- **Sounds:** the server plays sounds parented to the player's HRP, but every template has `RollOffMaxDistance 10000`, so the whole server hears every chime and fanfare.
- **Worst code:**
  1. `EggRestoration3D.client.luau:1056-1064`, the duplicated tail block that breaks compilation in git.
  2. The client curl loop (`EggSanctuaryClient :1123-1238`): two near-identical 40-line phases that hand-write joint CFrames instead of playing one Animation.
  3. The dead 2D wash code (`:371-612`) still bound to buttons.
  4. Version banners ("v8.0 Fully Hardened & Audited Engine") that do not match reality.
- **Biggest risks:**
  - Running `rojo serve` from the repo today overwrites the working Studio wash script with the broken one.
  - The map, HUD, pet templates and sounds exist only in the place file, so there is no backup in git.
  - No session lock on saves.

---

## 6. Assets in use

| Asset | Where | State |
|---|---|---|
| Pets (5) | `ReplicatedStorage.PetTemplates.*` | **Placeholder.** Built from Studio primitive Parts and welds (Meadow Bunny about 23 parts, Ember Hound about 37). The whole place has **0 MeshParts and 0 SurfaceAppearances**, even though commit `0d04f62` claims "upgraded 3D models, PBR textures". |
| Showcase pets | `PlayerBase_2.PetsInGarden.ShowcasePet_1..4` (and other plots) | Decorative part models. They are wiped (`ClearAllChildren`, server `:306`) as soon as a player takes that plot, so empty plots look fuller than your own. |
| Map | `Workspace.EggSanctuaryMap` | **Greybox.** Flat block canyon walls, a red carpet strip, a blank lime-green arch, legacy "Studs" top surfaces, a big empty grass plain between plots. Canyon floors run to about Z 7500, mostly empty. |
| Stations | `PlayerBase_N.{BicepCurlStation, EggCleaner, ChefStall, BaseSign, GardenYard}` | Part-built. Readable, but generic. |
| Sounds (8) | `ReplicatedStorage.Sounds` | **Placeholder.** Roblox built-ins (`rbxasset://sounds/splat.wav`, `snap.wav`, `victory.wav`, …). No music, no ambience. |
| Animations | — | **None.** No `Animation` instances. All motion is CFrame code. |
| VFX | code-made ParticleEmitters (default texture), Beam, PointLights | Functional, default sparkle texture only. |
| Lighting | `Lighting.{SanctuaryAtmosphere, Bloom, ColorCorrection, SereneSanctuarySky}` | Purple-tinted sky reads as odd. The day/night script darkens it further. |
| UI art | — | None. Emoji and text only. |

---

## 7. Gap between the plan and what was built

| Plan (GDD / README / commits) | Built |
|---|---|
| 15 creatures (3 per biome), Alpha bosses, Godly 1-in-10k Galaxy Titan | 5 creatures, one per zone, no bosses |
| Distance 0 to 50,000+ studs | Hard cap at the 5000-stud zone, reached by about 9 min of AFK curling |
| Food perks: Giant Egg, guaranteed Uncommon/Rare floors, lures | Food changes rarity weights and mutation odds only |
| "3-Layer Wash (Pressure Nozzle Peeling)" | 1 layer of 30 chunks |
| "Garden Hatch" with incubators and growth time | Instant hatch, no incubators, no timers |
| Rebirth bonus, VIP multiplier | Not present |
| 6 monetization products | Not present (no MarketplaceService code) |
| ProfileService | Raw DataStore |
| Mobile-first 75% | Pixel-offset UI, keyboard hints |
| "PBR textures, upgraded 3D models" (commit `0d04f62`) | 0 meshes, 0 SurfaceAppearance |
| "anti-autoclicker protection" (commit `a242bd2`) | Training is now fully automatic |
| README: treadmill gym, 4 dirt patches at 25% each | Bicep curl, and a 3D wash that replaced the 2D one, which is left in as dead code |
| Owner's audit #5: put map, HUD, sounds and pets in the repo | Not done. Remotes are now created in code; everything else is still Studio-only |

Status of the owner's audit items: #1, #3, #4, #7, #8, #10, #11 are fixed. #2 is mostly fixed. #6, #9, #12, #13, #14, #15 are partly fixed. #5 is not done.

The pattern: each commit after the owner's audit added a big flashy subsystem (auto-gym, 3D wash, animator) with a hyped commit title. None of them worked on onboarding, the loop's pacing, the reward moments or art. One commit left the repo unbuildable.

---

## 8. Repo ↔ Studio sync

- **How code moves:** Rojo. `default.project.json` maps 6 files: `ServerScriptService.EggSanctuaryServer.MainGameServer`, 3 LocalScripts in `StarterPlayerScripts`, and `ReplicatedStorage.Modules.{GameConfig, SoundHelper}`. Studio has the Rojo 7.7.1 plugin. No `rojo` CLI was found on this machine's PATH (aftman, rokit and cargo bins are missing), so syncing has probably happened from the other developer's machine (commits by `xLqkas`, UTC+7). There is no Rojo mapping for the place content.
- **Scripts:** `MainGameServer` (982 lines), `EggSanctuaryClient` (1349), `PetShowcaseAnimator` (140), `GameConfig` (292) and `SoundHelper` (43) match the repo by line count and by spot greps of distinctive lines. **`EggRestoration3D` differs:** Studio has 1079 lines and is clean; the repo has 1088 lines and contains the 9-line broken duplicate. So Studio is ahead of git for that file.
- **Studio-only (not in git):** the whole map `Workspace.EggSanctuaryMap`, `StarterGui.EggSanctuaryHUD`, `ReplicatedStorage.PetTemplates`, `ReplicatedStorage.Sounds`, the stale remotes `SelectFood` and `CollectCoins`, `StarterPack.Dumbbell`, `ServerScriptService.DayNightCycle`, `Teams.Script`, and the Lighting setup.
- **Repo-only:** `tests/test_game_math.luau`, the docs, and `build_gdd.py`.

---

## 9. Top 10 problems, ranked by damage to fun and retention

1. **The core loop is slow, serial and has no hook.** You get one egg at a time, cannot throw while an egg waits, walk about 100 studs each way, and hold one button for about 60 s to wash. Each cycle takes about 2 minutes and pays +2 $/s, the same bunny every time. Nothing makes a player want "one more".
2. **Progression collapses and is shallow.** The gym is an AFK button that reaches the last zone in about 9 minutes. There are only 5 pets, food upgrades are cheap and invisible, and there is no rebirth, index, quests or collection goal. After about 15 minutes nothing is left.
3. **No onboarding or wayfinding.** One line of notice text, no arrows, beams or tutorial, and stations spread across an empty plain. New players will not find the loop.
4. **Reward moments have no juice.** No creature eats the food, rarity and mutation are never revealed, the hatch is instant and off-camera, there is no "+$" popup, and the sounds are placeholders. The two moments that should feel great (land and hatch) feel like nothing.
5. **Art is greybox and placeholder.** Primitive-part pets, a flat block canyon, a blank arch, a purple sky with dark nights, empty plots, no meshes, textures or animations. The thumbnail and first impression will not hold a click.
6. **The UI is not mobile-ready and is inconsistent.** Pixel sizes overflow phones, two clashing styles, emoji icons, a placeholder crosshair, overlapping buttons, unformatted numbers, and one tap to sell a pet with no confirm.
7. **Repo and Studio are out of sync, and the repo is broken.** `EggRestoration3D` does not compile in git, and most content lives only in the place file. One `rojo serve` breaks washing, the core step.
8. **Exploits break the economy.** Client-trusted cleanliness plus a 15× sell refund gives exploiters infinite money, and the client can always send a sweet-spot throw duration.
9. **No social or multiplayer reason to play together.** Six plots side by side, but no leaderboard worth reading, no trading, no visiting or gifting, and others cannot even see your workout. Server-wide sound bleed adds noise.
10. **Data and business gaps.** No session lock, the egg is lost on leave, extra saves on every upgrade, and no monetization at all, despite the GDD's revenue plan.

**Not checked:** live play behaviour (play mode not allowed), whether the game is published or what its Max Players setting is, the full Studio script text (compared by line count and greps, not a full diff), and pet templates other than their part lists. The screenshots briefly moved the Studio edit camera; nothing was edited or saved.
