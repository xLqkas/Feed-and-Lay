# Revert check: live place vs v3

Date: 2026-11-20. Place "Feed an Lay" (placeId 113603218122384), Edit mode, read-only through Studio MCP (`execute_luau` reads, `screen_capture`). Nothing in Studio was edited, moved, enabled, disabled or saved. Repo compared at `v3` head `23af487` plus the uncommitted working tree.

## Verdict

**Mostly v3, and ahead of git, not reverted.** No script is back to its pre-v3 version and no old map piece, plot or HUD is back in place. What changed is a large **redesign added on top of v3** that is in no git revision and in none of the owner's Claude sessions: automatic strength training, an egg bag / inventory / hotbar in place of the nest rack, a "Chunky Nest" UI kit, a shared launch pad at the canyon in place of the per-plot Ledge, and a reworked save worker. Two parts of it do undo v3 features (the manual tap lift, and throwing from your own plot's Ledge). The old pre-v3 scripts have been **deleted** from the place, not just disabled. Copies are still in `_Backup_PreV3`.

How scripts were compared: length plus a 31-polynomial hash of each script's full source (CR stripped), worked out in Studio and in Python for `HEAD`, the working tree, `backup/pre-v3` and every past git revision of each file. For scripts that differ, function names and new comment lines were compared against `HEAD`. These are summaries, not full line diffs.

## Evidence of who and when

| Item | Value |
|---|---|
| `game.PlaceVersion` | **103** (last documented AI save: 77, so about 26 saves since) |
| Users in the Team Create session during the check | `xxfilippoxx33`, `xLqkas` |
| Per-version author and time | Not readable from the MCP tools (version history is only in the Creator Dashboard or Studio's Asset Manager) |
| New code's style | AI-written house style (`--!strict`, header comments). It names an "auto-strength brief", "the Director", `docs/ui_style_spec.md` (this repo has `docs/ai/ui-style-spec.md`) and "Chunky Nest". It also says `default.project.json` no longer maps `MainGameServer`, which is not true of this repo, so it was written from another clone or project file |
| Owner's own sessions | `EggHotbar` and `TrainingRules` appear in no Claude Code transcript (archived ones included), in no session note, and in no local repo under `Documents/GitHub` |
| Unexpected activity | About midway through this check, Studio switched to **Play mode** and back. This session did not start it; someone at this Studio (the owner or another session) did |

Conclusion: the redesign was most likely made by the teammate (`xLqkas`), probably with their own AI tooling, writing straight into the place. Confidence: medium. It is clearly not from the owner's Claude sessions, but the version authors could not be read.

## Differences

Classification key: TR = teammate revert, TA = teammate addition/change, AI = unfinished AI work, DOC = AI session change not yet in docs, ? = unknown.

### Scripts mapped in `default.project.json`

| Instance | v3 expects | Place has | Class | Sure |
|---|---|---|---|---|
| `ServerScriptService.EggSanctuaryServer.MainGameServer` | present, Disabled | **deleted** (copy only in `_Backup_PreV3`) | TA | high |
| `StarterPlayerScripts.EggSanctuaryClient` | present, Disabled | **deleted** (backup copy) | TA | high |
| `StarterPlayerScripts.PetShowcaseAnimator` | present, Disabled | **deleted** (backup copy) | TA | high |
| `StarterPlayerScripts.EggRestoration3D` | present, Disabled | **deleted** (backup copy is the pre-Phase-0 version that equals HEAD) | TA | high |
| `Loop.Pen` | HEAD 10154 chars | 8532, **= working tree** | AI | high |
| `Loop.Creatures` | not in HEAD (untracked) | 25963 = working tree + 2 lines (`light.Range = 6 + 2 * rank`, `light.Brightness = 1.5`) | AI | high |
| `Loop.Ctx` | HEAD 128 lines | 176; adds `launchPad`, `launchOrigin`, `onLaunchPad`, `distanceToLaunch`: the throw pad is now the canyon launch lane | TA | med-high |
| `Loop.Lift` | HEAD: tap lift, barbell press, streak (`23af487`) | 377 lines: **automatic training**; `tap`, `rep`, `start`, `stop`, `setStreak`, `showWord`, `circle` removed; `curl`, `showBubble` (x2 bubble) added; barbell model kept | TA (undoes the VS-9 tap lift) | high |
| `Loop.Nest` | nest rack cups | 101 lines (was 157): "egg bag replaces the nest rack"; `slotPoint`, `cupPosition`, `reserve` removed | TA | high |
| `Loop.Main` | HEAD | +`stripCoreTool`, `hookBackpack` (own hotbar, no Backpack, no Dumbbell tool) | TA | high |
| `Loop.Menus` | HEAD | +`Menus.show`, Shop shell at the "hub ChefStall", Inventory slot upgrade | TA | high |
| `Loop.Wash` | HEAD | +`Wash.washEgg`; walking into the washer opens the Inventory to pick an egg | TA | high |
| `Loop.Throw` | HEAD | small: full throw cutscene every throw, pad-edge tutorial nudge | TA | med |
| `Loop.Hud` | HEAD | small: Eggs chip opens the Inventory | TA | med |
| `Loop.Hatch`, `Loop.Teaser`, `Loop.Trail` | HEAD | same functions, different content (sizes 310 / 86 / 161 lines vs 297 / 85 / 157) | TA | med |
| `UI.Kit` | HEAD 42280 chars | 77759: whole "Chunky Nest component layer" (`K.window`, `K.robuxButton`, `K.productCard`, `K.gamepassCard`, `K.hotbarSlot`, `K.ModelIcon`, ...) | TA | high |
| `UI.Theme` | HEAD | 246 lines: Chunky Nest token set, old tokens kept as aliases | TA | high |
| `UI.Motion` | HEAD | Chunky Nest motion presets, `FLReduceMotion`, fadeOut fix | TA | high |
| `UI.Demo`, `UI.Logic` | HEAD | same functions, small content changes | TA | med |
| `V3.Main` (server) | HEAD 10360 chars | 19561: shared launch-lane throw pad, station cache, queued save worker (`runSaveWorker`, `enqueueSave`, `retryPendingSave`, session-release guards) | TA | high |
| `V3.EggService` | HEAD | `_StartLift`, `_StopLift`, `_Lift` removed; `_CollectBubble` added (auto-strength x2) | TA (undoes the tap lift) | high |
| `V3.EggRules` | HEAD | the bag can name which egg to wash | TA | high |
| `V3.SaveSchema` | HEAD | auto-strength fields (default 1), Long Boost retired | TA | high |
| `V3.SaveStore` | HEAD | changed content, same functions | TA | med |
| `Modules.Economy` | HEAD | +training interval, caps, x2 bonus chance/lifetime, training upgrade cost (`TODO-BALANCE`) | TA | high |
| `Modules.Goals` | HEAD | same functions, small content changes | TA | med |
| `DayNightCycle`, `V3.LiftRules`, `V3.Onboarding`, `Modules.GameConfig`, `Modules.SoundHelper`, `Loop.Cam`, `Loop.Fx`, `Loop.Hen`, `Loop.Sfx`, `UI.ImageIds`, `UI.Presets.{Types,DarkTiles,GlassPanels,LightDock,SlimPills}`, `Teams.Script` | HEAD | **identical to HEAD** | - | high |

None of the changed scripts matches any past git revision of its file (all revisions checked), and none matches `backup/pre-v3`.

Enabled state: `DayNightCycle`, `V3.Main`, `Loop.Main` are on, as expected. `Teams.Script` (junk `print`) is on, as before v3. No old script is enabled anywhere: the live ones are deleted and the 8 copies in `_Backup_PreV3` are all off.

### Scripts in the place that are not mapped or not in git

| Instance | What it is | Class | Sure |
|---|---|---|---|
| `V3.TrainingRules` (157 lines) | pure rules for automatic Strength training and x2 bubbles | TA | high |
| `UI.Icons` (115 lines) | icon table, asset ids filled in for coins, robux, egg, book, paw, shop, ... | TA | high |
| `UI.Presets.Chunky` (77 lines) | "Chunky Nest" preset data | TA | high |
| `Loop.EggBag` (180 lines) | egg bag panel | TA | high |
| `Loop.Inventory` (301 lines) | Eggs / Pets inventory panel | TA | high |
| `Loop.EggHotbar` (220 lines) | numbered egg hotbar, keys 1-8 load the washer | TA | high |

These sit inside Rojo-mapped folders (`V3`, `UI`, `Loop`). `V3` and `Loop` do **not** have `$ignoreUnknownInstances`, so a `rojo serve` from this repo would delete these 6 modules, and it would overwrite the 23 changed scripts.

### Map and instances (`plot-v3-layout.md`)

| Item | v3 expects | Place has | Class | Sure |
|---|---|---|---|---|
| `Workspace.PlotsV3` | 6 plots, attrs `MouthX/MouthZ/Radius` | 6 plots, attrs match, pivots match the table | - | high |
| Each plot | 59 parts, tag `FLPlot`, `PlotId`, `OwnerUserId=0`, `AccentColor` | all match on all 6 | - | high |
| Stations | 11 per plot, 66 `FLStation` tags | 66, correct `Kind`, `PlotId`, `Tab`, every one has a `PrimaryPart`; 8 slots, 16 spots, 8 queue points per plot | - | high |
| `Plot_N.Ledge` | Model named `Ledge` | **renamed `ViewingDeck`** on all 6 (still `Kind=Ledge`, same parts, pad at spec (0,0,12)) | TA | high |
| `Ledge.Pad.ThrowOrigin` | Attachment | **missing** on `Plot_4` (only plot checked) | TA | med |
| `Nest` rack and cups | present | present and unchanged in the world (the client no longer uses the cups) | - | high |
| `Workspace.EggSanctuaryMap.LaunchStation` | old runway, left in place | same parts plus **new `Pad`** (invisible, no collision, 20 x 0.4 x 30 at (-55, -77.65, -2)): the shared throw zone | TA | high |
| `Workspace.CanyonV3` | 2 landing floors + 2 gates, attrs | all match | - | high |
| `ReplicatedStorage.Models.MamaHen` / `MamaHenHats` | 15 parts, `Root`, `Tint_1..5`, `HatPoint`, 5 hats | all match (+ a `Note` attribute) | - | high |
| `ServerStorage._OldMap_PreV3` | the 18 moved items | all 18 still there; none back in Workspace (no `MultiplayerBases`, `Lamp_1/2`, `LanternPost_1/2`, moved arches/statues) | - | high |
| `ServerStorage._Backup_PreV3` | 3,678 descendants, 0 enabled scripts | 3,678, 0 enabled, `CreatedUtc` 2026-11-19T15:09:15Z | - | high |
| Rest of `EggSanctuaryMap` | as left | unchanged against the backup (18 "changed" hits were all duplicate-name parts such as `CarpetRail` and `RunwayEdgeLamp` matched to the wrong twin, not real moves) | - | med-high |
| Spawns | 6 plot spawns | exactly the 6 plot spawns | - | high |
| `StarterPack.Dumbbell` | in the pre-v3 inventory; design-v3 says to delete it | **removed** (the new code strips the core Backpack and the Dumbbell) | TA (matches design) | high |
| `ReplicatedStorage` attribute `FLUiPreset` | absent (default Blend) | **`Chunky`** | TA | high |
| `ServerStorage` attribute `FLDebugProfile` | not documented | JSON debug profile (tutorialStep 16, 3 pets, coins 120) | ? (likely TA debug) | low |
| `ServerStorage` attribute `FLFreshSaveInStudio` | documented switch | `false` | - | high |
| `ReplicatedStorage.Remotes` (10 old RemoteFunctions), `Sounds`, `PetTemplates` | pre-existing, still there | unchanged | - | high |
| `RemotesV3` | made by the server at runtime | absent in Edit (expected) | - | high |

### UI

| Item | v3 expects | Place has | Class | Sure |
|---|---|---|---|---|
| `StarterGui.EggSanctuaryHUD` | the only ScreenGui, **disabled** | the only one, `Enabled=false`, 134 descendants | - | high |
| `StarterPlayerScripts` | `Loop`, `UI` (+ disabled old scripts) | `Loop`, `UI` only (old scripts deleted, see above) | TA | high |
| `StarterCharacterScripts`, `ReplicatedFirst` | empty | empty | - | high |

### Lighting and settings

| Item | v3 expects | Place has | Class | Sure |
|---|---|---|---|---|
| Lighting (edit) | ClockTime 14, Brightness 2.5, Ambient (90,100,120), Outdoor (130,150,180) | same | - | high |
| Lighting children | Atmosphere, Bloom, ColorCorrection, Sky | same | - | high |
| `DayNightCycle` script | HEAD | identical, enabled | - | high |
| `Workspace.StreamingEnabled` | not documented | `true` | ? | low |
| WalkSpeed 16, Gravity 196.2 | defaults | same | - | high |

Screenshots: `docs/ai/shots/revert-check/01-map-from-above.jpg` (6 plots on the arc, launch runway, canyon) and `02-plot4-from-back-to-canyon.jpg` (Plot_4 up close, canyon gate behind it).

## What restoring v3 (git HEAD) would involve, item by item (not done)

First, decide whether the redesign is wanted. Most of it is new work, not a revert. Before restoring anything, ask the teammate for their branch or clone and get it into git (e.g. a `teammate/auto-strength` branch). Today the only copy of that work is the live place.

1. **Keep a copy of the redesign first.** Read out the 29 changed or new scripts (the 23 changed, the 6 new, plus `Creatures` and `Pen`) and commit them to a separate branch. Then nothing is lost whatever is decided.
2. **Unfinished AI work** (`Pen`, `Creatures`): the place already has it. Either commit the working tree (adding the 2 light lines from Studio to `Creatures.luau`) or revert the place's two modules to HEAD.
3. **23 changed scripts + 6 new modules**: to go back to HEAD, write the HEAD source into each changed script and delete the 6 new modules (or `rojo serve` from `v3`, which does both because `V3` and `Loop` lack `$ignoreUnknownInstances`, plus `UI.Icons` and `UI.Presets.Chunky` by hand: `UI` keeps unknown instances).
4. **Old scripts** (`MainGameServer`, `EggSanctuaryClient`, `PetShowcaseAnimator`, `EggRestoration3D`): optional. v3 only needs them present and disabled. Clone them from `_Backup_PreV3` (they are already off), or let `rojo serve` create them with `Disabled=true`.
5. **`Ledge` renamed `ViewingDeck`, `ThrowOrigin` missing**: rename back to `Ledge` on all 6 plots and re-add `Pad.ThrowOrigin` at spec (0,4.5,14.5). Or simply re-run the build script in `plot-v3-layout.md` (rebuilds `PlotsV3` only). HEAD client and server code look stations up by name, so this must match the code that is chosen.
6. **`LaunchStation.Pad`**: delete it (an invisible part, used only by the new code).
7. **`StarterPack.Dumbbell`**: leave it removed (design-v3 says to delete it).
8. **`FLUiPreset = Chunky`**: remove the attribute (HEAD has no `Chunky` preset and falls back to Blend). **`FLDebugProfile`**: ask the teammate; harmless to HEAD code, which does not read it.
9. Play-test, then save. Restoring writes a new cloud version; versions 78-103 stay in version history.

## What could not be checked

- Who made each save, and when: the MCP tools cannot read version history. Check Asset Manager > Places > View Version History for versions 78-103.
- Full line-by-line diffs of the 23 changed scripts: only function lists, new comments and sizes were compared.
- `ThrowOrigin` on plots other than `Plot_4`, and per-part positions inside plots (only counts, names, tags, attributes and pivots were checked).
- Place and universe settings (max players, game passes, API access); `StreamingEnabled` has no documented baseline.
- Runtime behaviour: no play mode was started by this check. One close-up screenshot request timed out.
