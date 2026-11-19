# Client v3 notes (VS-6 throw, VS-7 wash, VS-8 hatch and pen)

Written 2026-11-19. Code: `src/client/Loop/` (Rojo: `StarterPlayer.StarterPlayerScripts.Loop`), UI kit in `src/client/UI/`. Server contract: `server-v3-notes.md`. The server decides every outcome; the client only shows replies and events.

## Module map

| Module | Does |
|---|---|
| `Main.client.luau` | Waits for `PlotId`, finds the `FLPlot`, calls `GetState` once, starts the modules, keeps the objective banner current (5 Hz). |
| `Ctx.luau` | Shared state: remotes, own plot, client copy of nest eggs and pets, tiny event bus (`on`/`emit`), `invoke` (InvokeServer that never throws), `at(serverTime, fn)`, distance to a station. |
| `Cam.luau` | Camera owners by priority (throw 20, reveal 30, wash 10); none = default camera, placed back behind the character. Shake, FOV tween and punch (off in reduced motion). |
| `Fx.luau` | Client-only parts in `Workspace.FLClientFx`: eggs, bursts, floating world text, Bezier arcs, squash, landing point on the canyon floor. |
| `Sfx.luau` | Sound ids and play helpers (UI sounds in SoundService, 3D sounds at a point, 60-stud roll-off). |
| `Hud.luau` | Built only with the UI kit: Coins pill with `+X/s`, Food chip, Nest chip, banner slot, toasts, THROW button (touch), throw hint chip, power meter with zone bands and SWEET band, release label, Eat Card row, wash HUD (progress bar, aim hint, "Nozzle too weak" chip, X), CLEAN! pop, reveal cards. PC/phone composition via `Kit.onLayout`. |
| `Throw.luau` | Hold-and-release on the Ledge: mouse / Space (ContextActionService, sinks jump while on the Ledge), THROW button, gamepad R2. `StartCharge` on press, `ReleaseThrow(secondsHeld)` on release, 6 s auto-cancel. Food arc, Mama Hen, egg return, throw cam rule (throws 1-3, first throw into a zone, follow setting; sparkle eggs get the return leg) or Eat Card. |
| `Hen.luau` | Client-local Mama Hen at the landing point (zone tint + hat): run 0.5 s, 3 pecks 0.6 s (nom, crumbs, hearts), sit and cluck 0.2 s, egg leaves at `eggLaunchAt`. Eat Card: 2.2 s ViewportFrame, max 3. |
| `Nest.luau` | Egg return arc (1.5 s, apex +60, 2 spins, mud trail, gold trail on sparkle eggs) into the next free cup, landing squash / dust / thunk / shake, eggs in cups, padlocks and the "used/size" billboard. |
| `Wash.luau` | Ring auto-start (`StartWash`, retries after 2 s while eggs wait), egg hops to the turntable, chunk meshes on the server `normals`, camera on the turntable's +Z side, spray beam and mist, 10 Hz `SprayHits` with the chunks near the aim point that face the camera, pop juice, progress, CLEAN!, `WashLoaded` next egg, leaves the view when the nest is empty, X or walking out sends `StopWash`. |
| `Hatch.luau` | `HatchResult`: queue shelf if an earlier reveal is running, then full reveal (hop 0.5 + wobble 2.5 with 3 cracks, 14-tick slot roll 2.0 s, shards + rarity burst + fanfare tier + FOV punch on Rare+, 1.5 s hold, camera on the pad) or compact (2.5 s, small card, no camera move). Then the pet jumps to its pen spot; storage / swap toasts. |
| `Pen.luau` | Placeholder pets (species colour, rarity size, mutation looks), wander in their spot, name + rarity billboard (40 studs), `+X` floater every second over the 12 nearest pen pets, staggered 0.08 s. |

UI kit changes: `Kit.corner` / `Kit.stroke` exported; debug attribute `FLDebugViewport` (see Screenshots).

## How code reaches Studio

The repo is the source of truth. Rojo serve could not be used: the Rojo plugin needs a human click to connect, and Studio's `HttpService` from the MCP tools is blocked for localhost ("not in the Assistant HTTP allowlist"). So scripts were mirrored with the Studio MCP tools: whole files through `execute_luau` (setting `Source`), later changes through `multi_edit` with the same old/new strings as the repo edit (note: `multi_edit` with `replace_all` reported success but changed nothing once; use one edit per occurrence). Every mapped script was then checked by length + a 31-polynomial hash of the source (CR stripped) computed in lune for the repo and in Studio for the place: **30 / 30 identical** at the end of this session. Old scripts replaced by v3 (`MainGameServer`, `EggSanctuaryClient`, `EggRestoration3D`, `PetShowcaseAnimator`) are disabled, not deleted, in both the place and `default.project.json`; `StarterGui.EggSanctuaryHUD` is disabled in the place.

Studio-only switch: `ServerStorage` attribute `FLFreshSaveInStudio = true` gives an unsaved fresh profile in Studio (new-player tests without touching the real save). Not needed today: DataStore API access is off in this place, so `SaveStore.load` fails with 403 after its retries and `Main` falls back to an unsaved fresh profile with a warning, as designed.

## Acceptance tests

| Package | Test | Result |
|---|---|---|
| VS-6 | First throw to egg in nest in 4.0 s ± 0.2 | **PASS**: 3.97 s and 3.98 s (release to the egg settling in its cup, client clock) |
| VS-6 | Eat Card shows from throw 4 | **PASS**: throws 1-3 used the throw cam; throw 4 and 5 showed the Eat Card (screenshot 09 is from before it was moved above the SWEET label) |
| VS-7 | Meadow egg at Nozzle Lv1 washes in 5-9 s | **PASS**: 6.2 s and about 8 s first pop to done while aiming at the egg; tutorial egg (6 chunks) 5.1-5.7 s |
| VS-7 | `SprayHits` at 60 Hz washes no faster than 10 Hz | **PASS**: live server, 60 Hz on one chunk popped it after 1.00 s (10 HP at 10 DPS); lune `tests/EggService.spec.luau` also PASS |
| VS-7 | Spraying only the back stalls | **PASS**: live, 27 batches of back-facing chunks in 3 s, 0 pops; lune PASS |
| VS-8 | First hatch is Moss Turtle with "UNCOMMON" in green | **PASS** (twice, fresh profiles; screenshots 05, 08) |
| VS-8 | Floaters every 1 s over each pen pet | **PASS**: measured `+1` / `+3` at 0.75/0.82, 1.77/1.83, 2.77/2.83 s |
| All | Loop completed twice by a new player in play mode, no console errors | **PASS**: 3 play sessions, 4 to 5 hatches each; only warning is `rbxassetid://203785492 ... Asset type does not match` which appears before the v3 client loads and is not referenced by any client instance (pre-existing) |
| Input | Mouse | PASS (all runs) |
| Input | Touch THROW button, touch-drag spraying | **NOT RUN**: Studio MCP has no touch input; code path written, button shown only in the emulated phone screenshot |
| Input | Gamepad R2 throw, right-stick aim + R2 spray | **NOT RUN**: no gamepad input available through the MCP tools |

## Measured timings

All from client-side logs in play mode. MCP tool round trips add 2-5 s between my inputs, so wall-clock runs are slower than a human; the loop numbers below add the measured in-game segments to walking times (16 studs/s, plot walks of 6-10 studs).

| Segment | Measured |
|---|---|
| Hold for SWEET | 1.2 s |
| Release to egg in nest | 3.97-3.98 s |
| Walk Ledge to Washer ring | about 0.7 s (done while the egg flies) |
| Egg hop to turntable | 0.6 s |
| Wash tutorial egg (6 chunks) | 5.1-5.7 s |
| Wash Meadow egg (10 chunks, Lv1) | 6.2-8 s |
| Full reveal: hatch to rarity burst / to pet in pen | 5.13 s / 6.6 s + 0.6 s jump |
| Next egg loads after a full reveal | 6.57 s after the hatch (server waits for the reveal) |

- **First hatch (rarity shown):** about 0:18 to 0:20 from spawn (0.4 walk + about 1.5 reading the banner + 1.2 hold + 4.0 flight + 0.6 hop + 5.5 wash + 5.1 reveal); pet in the pen at about 0:22. Target about 0:22: **PASS (composed from measured segments, not one continuous human run)**.
- **Loop with 2 eggs (hatches 2-5, full reveals):** about 34-36 s (2 throws with the 1.5 s cooldown, about 7 s until the second egg lands, 2 washes, 2 full reveals that block washing). Measured wall clock including my tool latency: about 36 s from the first release to the second burst. Target 45 s or less: **PASS**. From hatch 6 on, compact reveals do not block washing, so a 2-egg loop drops to about 22 s.

## Sounds (all checked with `ContentProvider:PreloadAsync`: 15 / 15 Success, `IsLoaded` true)

| Name | Id | Length | Source |
|---|---|---|---|
| charge | `rbxassetid://123796710194563` | 0.59 s | Creator Store "Whoosh Swinging Sound", looped, pitch follows the needle |
| throw | `rbxassetid://138890894929151` | 0.84 s | "Whoosh2" |
| ding (SWEET) | `rbxassetid://4612374495` | 1.50 s | "bling_diamond_pickup_3" |
| nom | `rbxassetid://137096768206416` | 1.54 s | "eat_crunchybread" |
| cluck | `rbxassetid://77584650945481` | 0.95 s | "chicken cluck" |
| thunk | `rbxassetid://9119319842` | 0.60 s | ProSoundEffects "Soccer Ball Bounces Hits On Grass 4" |
| hiss (spray loop) | `rbxassetid://9126200774` | 8.13 s | ProSoundEffects "Water Spray ... Hose Water Dirt" |
| splat | `rbxassetid://12222152` | 0.22 s | Roblox "splat.wav" |
| chime (wash done) | `rbxassetid://4612374036` | 2.01 s | "bling_big_diamond_pickup" |
| crack | `rbxassetid://9113959343` | 1.02 s | ProSoundEffects "Crack Egg Crunchy 11" |
| tick | `rbxasset://sounds/clickfast.wav` | 0.29 s | built into the client |
| bonk | `rbxasset://sounds/button.wav` | 0.58 s | built into the client |
| fanfare1 (Common/Uncommon) | `rbxassetid://1844016113` | 4.53 s | APM "White Sands - Sting" |
| fanfare2 (Rare/Epic) | `rbxassetid://1839881844` | 5.42 s | APM "Spinning Around (b)" |
| fanfare3 (Legendary+) | `rbxassetid://1840076509` | 2.25 s | APM "Through the Roof (sting)" |

Not sourced yet: rising hum under the wobble, coin tick, music.

## Screenshots (`docs/ai/shots/loop-v3/`)

01 PC HUD at spawn, 02 throw cam on Mama Hen, 03 power meter and release label, 04 wash view, 05 reveal mid-roll, 06 nest-full toast, 07 phone HUD (812 x 375, emulated), 08 final reveal card, 09 Eat Card (before the overlap fix).

Phone shots use the debug attribute: in play mode set `game.Players.LocalPlayer:SetAttribute("FLDebugViewport", Vector2.new(812, 375))`; the HUD lays out at that size, centred and clipped. The THROW button was forced visible for 07 (it only shows with touch).

## Known rough edges

- **Studio play mode is half at night**: the old `DayNightCycle` runs (Golden Hour replaces it in P-5). Many play moments are dark.
- **Holding still on the egg's centre still washes it**: the turntable brings every chunk to the front within 9 s, so aim barely matters (egg 3 washed in about 8 s with the mouse parked). `design-v3.md` 4.9 claims a parked autoclicker "washes about one third and stalls"; it does not. Facing still blocks back-only spraying.
- Throw hint shows "Hold click or Space"; the arm-swing animation, food 3D models, crack decals, egg meshes, shell shards and all pets are primitive placeholders.
- The Hatch Pad's tall translucent beam (plot model) covers the reveal and the default camera view.
- The food "selector" only shows the food in use (server always throws the best owned food; buying is VS-10 / P-1).
- The coins counter shows from the start (progressive HUD reveal is VS-10).
- Full reveal timing is client-paced after `revealAt` (task waits), so it can drift by a frame or two from `revealSeconds`; the server only uses `revealUntil` to delay the next egg.
- The egg is hidden behind the character on some camera angles; the wash view hides the character locally.
- `tests/test_game_math.luau` is an old Studio-only script (indexes `game`), not a lune test.
- Touch and gamepad paths are untested (see above).
