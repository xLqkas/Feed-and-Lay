# Client v3 notes (VS-6 throw, VS-7 wash, VS-8 hatch and pen, VS-9 lift, VS-10 onboarding)

Written 2026-11-19. Code: `src/client/Loop/` (Rojo: `StarterPlayer.StarterPlayerScripts.Loop`), UI kit in `src/client/UI/`. Server contract: `server-v3-notes.md`. The server decides every outcome; the client only shows replies and events.

## Module map

| Module | Does |
|---|---|
| `Main.client.luau` | Waits for `PlotId`, finds the `FLPlot`, calls `GetState` once, starts the modules, keeps the objective banner and trail target current (5 Hz) from the `TutorialStep` attribute (steps 1-15), then a contextual banner. Step 16 shows "You're a Sanctuary Keeper!" for 3 s, live only. |
| `Ctx.luau` | Shared state: remotes, own plot, client copy of nest eggs and pets, tiny event bus (`on`/`emit`), `invoke` (InvokeServer that never throws), `at(serverTime, fn)`, distance to a station. |
| `Cam.luau` | Camera owners by priority (throw 20, reveal 30, wash 10); none = default camera, placed back behind the character. Shake, FOV tween and punch (off in reduced motion). |
| `Fx.luau` | Client-only parts in `Workspace.FLClientFx`: eggs, bursts, floating world text, Bezier arcs, squash, landing point on the canyon floor. |
| `Sfx.luau` | Sound ids and play helpers (UI sounds in SoundService, 3D sounds at a point, 60-stud roll-off). |
| `Hud.luau` | Built only with the UI kit: Coins pill with `+X/s`, Food chip, Nest chip, banner slot, toasts, THROW button (touch), throw hint chip, power meter with zone bands and SWEET band, release label, Eat Card row, wash HUD (progress bar, aim hint, "Nozzle too weak" chip, X), CLEAN! pop, reveal cards. PC/phone composition via `Kit.onLayout`. |
| `Throw.luau` | Hold-and-release on the Ledge: mouse / Space (ContextActionService, sinks jump while on the Ledge), THROW button, gamepad R2. `StartCharge` on press, `ReleaseThrow(secondsHeld)` on release, 6 s auto-cancel. Food arc, Mama Hen, egg return, throw cam rule (throws 1-3, first throw into a zone, follow setting; sparkle eggs get the return leg) or Eat Card. |
| `Hen.luau` | Client-local Mama Hen at the landing point (zone tint + hat): run 0.5 s, 3 pecks 0.6 s (nom, crumbs, hearts), sit and cluck 0.2 s, egg leaves at `eggLaunchAt`. Eat Card: 2.2 s ViewportFrame, max 3. |
| `Nest.luau` | Egg return arc (1.5 s, apex +60, 2 spins, mud trail, gold trail on sparkle eggs) into the next free cup, landing squash / dust / thunk / shake, eggs in cups, padlocks and the "used/size" billboard. |
| `Wash.luau` | Ring auto-start (`StartWash`, retries after 2 s while eggs wait), egg hops to the turntable, chunk meshes on the server `normals`, camera on the turntable's +Z side, spray beam and mist, 10 Hz `SprayHits` with the aim point on the unit egg (ray against the egg ellipsoid; the server picks the chunks), camera 6 studs, chunks 0.8 studs (a pair reads as one blob), pop juice, progress, CLEAN!, `WashLoaded` next egg, leaves the view when the nest is empty, X or walking out sends `StopWash`. |
| `Hatch.luau` | `HatchResult`: queue shelf if an earlier reveal is running, then full reveal (hop 0.5 + wobble 2.5 with 3 cracks, 14-tick slot roll 2.0 s, shards + rarity burst + fanfare tier + FOV punch on Rare+, 1.5 s hold, camera on the pad) or compact (2.5 s, small card, no camera move). Then the pet jumps to its pen spot; storage / swap toasts. |
| `Lift.luau` | Lift Bench (VS-9): enter the bench ring (2.6 studs) -> `StartLift`; target circle + shrinking ring (drawn from `Economy.liftRing`, timeouts advanced locally like the server), tap = click / Space / touch / gamepad A (Space and A sunk so they do not jump), side camera, Strength bar to the next zone gate, +N float, zone-unlock stamp, X / walking out / 20 s idle -> `StopLift`. |
| `Menus.luau` | Left column Book (step 7) and Upgrades (step 10) with red badge and bobbing pointer; Book panel (found species, CLAIM -> `ClaimBook`, coin burst; Meadow/Marsh silhouettes "???"); Upgrades panel (next Nest slot, Food, Nozzle, Weights; price button green/red live with Coins, `Buy`, shake + "Need N more coins"). Upgrade signs carry a client ProximityPrompt (from step 10); only the trail's sign (Nest at step 10, Food at 15) opens by itself. |
| `Trail.luau` | Arrow trail: cyan neon chevrons every 1.6 studs on the floor (raycast) along a `PathfindingService` path (0.5 s refresh, straight-line fallback), pulse toward the target, fade near the camera, bobbing chevron 5 studs above the target, hidden within 4 studs and while washing or lifting. |
| `Pen.luau` | Placeholder pets (species colour, rarity size, mutation looks), wander in their spot, name + rarity billboard (40 studs), `+X` floater every second over the 12 nearest pen pets, staggered 0.08 s. |

UI kit changes: `Kit.corner` / `Kit.stroke` exported; debug attribute `FLDebugViewport` (see Screenshots).

## VS-9 / VS-10 and playtest fixes (2026-11-19, second client session)

**Onboarding (VS-10).** Banner and trail per step (`Main.client.luau`): 1 Walk to the ledge (Ledge), 2 Hold to throw, 3 Watch Mama Hen eat, 4 Wash your muddy egg (Washer), 5 Spray all the mud off, 6 It's hatching..., 7 New creature! Claim it in your Book (Book pointer), 8 Throw 2 more eggs (Ledge; "Wash your eggs!" when the nest is full), 9 Wash your eggs (Washer), 10 Buy a bigger nest! (Sign_Nest) or "Earn 100 coins: your pets are working!" below 100, 11 Throw farther: train at the Lift Bench! (LiftBench), 12 Lift until Strength 80!, 13 Throw into the Bog Marsh: release on SWEET! (Ledge; Washer when the nest is full), 14 Claim your new creature in your Book!, 15 Buy Carrots for better eggs! (Sign_Food). HUD reveal (`Hud.setStep`): Coins 7, Book 7, Nest chip 8, Upgrades 10, Strength chip 11, Food chip 15. The server completes steps from saved state (`Onboarding.luau`).

**Fixes from the first playtest.**
- Wash aim: see `server-v3-notes.md` (aim point instead of chunk ids, paired chunks on height bands).
- Hatch Pad: the 14-stud beam is a flat glow ring on the pedestal (all 6 plots, and the build script in `plot-v3-layout.md`). The reveal camera looks 1 stud above the egg and the full reveal card moved from y 0.30 to 0.24, so the egg and pet stay visible under the card (shot 03).
- Day cycle: `ServerScriptService.DayNightCycle` was kept and rewritten in place (same path, same mapping): 8 min day (clock 8:00 to 16:30), 2 min warm dusk (clock 17.4, tint 255/230/200), Ambient never below (120, 120, 130), 1 Hz updates. Old keyframes: git tag `backup/pre-v3` and `ServerStorage._Backup_PreV3`. Golden Hour gameplay is still P-5.
- Egg behind the character: the wash view hides the character locally (as before); the reveal and lift cameras put the character outside the line to the target (shots 03 and 06).
- Upgrade signs used to open the panel on approach; the Weights sign is 4.4 studs from the Lift Bench and the Washer sign 4.6 from the Washer, so the panel popped over those stations and its shade swallowed every lift click. Now ProximityPrompts, auto-open only for the trail's sign.
- Washer: a "Step into your washer!" refusal (server has not seen the player arrive yet) now retries quietly after 0.3 s instead of toasting.

**Studio caveat.** Several MCP calls timed out because Studio stopped rendering (viewport 1x1, then 0-15 fps while the window was not in front). Everything driven by `RenderStepped` (wash start, lift start, trail) stalls then; a test-environment artefact, not a game bug.

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

### Playtest fixes, VS-9, VS-10 (second session)

| Package | Test | Result |
|---|---|---|
| Fix 1 | Parked aim stalls; sweeping aim finishes in 4-8 s | **PASS** in lune (`tests/EggService.spec.luau` 5b: a fixed aim anywhere on a 7x19 grid pops at most 2/10 chunks in 30 s; honest sweep 5.8 / 6.0 / 7.1 s). Live: mouse parked on the egg centre for 20 s = 0%. A scripted tracker aiming at the real mud parts (10 Hz from the client VM, real server) washed the tutorial egg in 6.0 and 5.9 s and Meadow eggs in 6.5, 8.5 and about 8 s; once 20 s (the greedy tracker kept chasing pairs leaving view). A human mouse sweep could not be timed: MCP mouse moves are too coarse and laggy to follow a moving blob. |
| Fix 2 | Hatch Pad beam gone; egg framed during wobble and roll | **PASS** (shots 01, 03) |
| Fix 3 | Play is bright at all times | **PASS** (day and dusk seen in play; shot 07 is dusk, pink from the purple skybox plus warm haze, but readable) |
| Fix 4 | Egg not hidden behind the character in wash and hatch | **PASS** (shot 03; the wash view hides the character) |
| VS-9 | Strength 50 to 80 takes 20-40 s of active play | **PASS**: lune 27-31 s (5 runs, 50 ms timing jitter); live scripted tapper 1.24 Strength/s, about 24 s for 30 |
| VS-9 | A 1 Hz autoclicker gains under 40% of an active player | **PASS**: lune 4% (worst fixed interval in 0.6-1.6 s: 35% at 1.4 s); live, 18 real mouse clicks about 1 s apart through the input path: +5 in 20 s = 0.25/s, 20% of the live active rate |
| VS-10 | Fresh save: first reward under 60 s | **PASS**: rarity card about 30 s after the HUD was ready (wall clock including MCP latency); about 19 s composed from in-game segments |
| VS-10 | Marsh egg hatched under 3:30 | **NOT RUN** as one continuous run (MCP latency stretched the run to about 17 minutes). All 15 steps were completed in order in play mode; composed estimate about 2:10 below. |
| VS-10 | No HUD button visible before its step | **PASS** (shots 01, 04, 05, 08) |
| VS-10 | Onboarding progress saved, no repeat for a returning player | **PASS in lune only** (`tests/Onboarding.spec.luau`: save round trip, resume at a saved step). DataStore API access is off in this place, so a real rejoin was not tested. |
| All | 15 steps from a fresh save, no console errors | **PASS**: only the expected DataStore-off messages and the old `rbxassetid://203785492` warning |
| Input | Touch and gamepad | **NOT RUN** (see the review below) |

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

### Second session (fresh save, all fixes)

Client logger, seconds from the HUD being ready: step 2 at 7.7 (keyboard tool latency; a player walks the 6 studs in 0.4 s), release 9.6, egg in nest 13.6, wash loaded 13.7 (player already in the ring), spraying started 19.0 (tracker latency), WashDone 24.9 (5.9 s spraying), rarity word about 30, step 7 at 31.5.

- **First hatch from spawn, composed for a human:** 0.4 walk + 1.5 read + 1.2 hold + 4.0 flight + 0.6 hop + 5.9 wash + 5.1 to the rarity word = **about 18.7 s**; pet in the pen at about 22 s. Target 0:22 and first reward within 60 s: PASS (composed; measured wall clock with tool latency about 30 s).
- **Marsh egg, composed:** first hatch 22 s + claim 5 s + 2 throws and 2 washes with full reveals about 35 s + Nest slot 3 (coins were already over 100 after the claim) 5 s + walk and lift 50 to 80 about 25-30 s + SWEET throw 6 s + Marsh wash at Lv1 17.8 s (measured) + reveal 6.5 s = about 2:05-2:15. Each non-SWEET throw at step 13 lands in the Meadow and costs about 15 s more.

## Touch and gamepad review (code read, not run)

Studio MCP has no touch or gamepad input and no control over device emulation, so none of this was played.
- **Throw:** touch THROW button (shown only with touch and no keyboard), gamepad R2 through ContextActionService. Unchanged since VS-6.
- **Wash:** touch: `TouchStarted` (not game-processed) sets the aim, `TouchMoved` follows the finger, `ScreenPointToRay`. Gamepad: right stick moves a crosshair from the viewport centre, R2 sprays, `ViewportPointToRay`. Risk: a touch that starts on the dynamic thumbstick may also aim the spray.
- **Lift:** touch tap anywhere not game-processed; gamepad A and Space through ContextActionService with Sink (no jump). Risk: thumbstick touches may count as taps (a miss at worst).
- **Signs:** ProximityPrompt gives E, tap and gamepad X.
- **Panels (Book, Upgrades): gap.** Nothing sets `GuiService.SelectedObject` when a panel opens, and the HUD Book / Upgrades buttons have no gamepad binding, so a gamepad player reaches them only with the virtual cursor. Mouse and touch work through `Activated`.
- The phone layout of the new HUD (menu column, Lift HUD) was not screenshotted; `Kit.onLayout` sets compact positions.

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

## Screenshots

`docs/ai/shots/onboarding-v3/`: 01 spawn, step 1 banner and trail beacon (bright day, no beam); 02 throw cam on Mama Hen (step 3); 03 full reveal after the framing fix; 04 Book button with badge and pointer, Coins appear (step 7); 05 Book claim with coin burst, Nest chip appears (step 8); 06 Lift HUD (rings before they moved above the character); 07 SWEET throw into the Marsh (step 13, dusk); 08 Upgrades from the Food sign, prices green / red (step 15); 09 Carrot bought, step 16 banner.

`docs/ai/shots/loop-v3/`

01 PC HUD at spawn, 02 throw cam on Mama Hen, 03 power meter and release label, 04 wash view, 05 reveal mid-roll, 06 nest-full toast, 07 phone HUD (812 x 375, emulated), 08 final reveal card, 09 Eat Card (before the overlap fix).

Phone shots use the debug attribute: in play mode set `game.Players.LocalPlayer:SetAttribute("FLDebugViewport", Vector2.new(812, 375))`; the HUD lays out at that size, centred and clipped. The THROW button was forced visible for 07 (it only shows with touch).

## Known rough edges

- Washing with honest aim is harder than before: the live tracker needed 6-8.5 s per Meadow egg and once 20 s; a human sweep was not timed. If it feels fiddly, raise `Economy.AIM_RADIUS` (0.19) only together with the band spacing, or a parked aim reaches two bands.
- The dusk phase reads pink (purple skybox plus warm haze); bright enough, not pretty.
- At step 13 the SWEET segment of the meter is the Marsh band, but only a darker green with no label; the banner says "release on SWEET!" instead.
- Lift: rings time out into "MISS" every couple of seconds while idle (noisy); no curl animation (needs an uploaded Animation), no grunt sound. The zone-unlock stamp only shows for reps tapped through the HUD.
- Book and Upgrades panels are not gamepad-navigable (see the review). The Book lists only Meadow and Marsh entries plus found species.
- Arm-swing animation, food models, crack decals, egg meshes, shell shards and all pets are primitive placeholders.
- Full reveal timing is client-paced after `revealAt`, so it can drift a frame or two from `revealSeconds`.
- `src/client/UI/ImageIds.luau` (commit 0f52e9d, another session) is in the repo but not in Studio; not wired in on purpose.
- `tests/test_game_math.luau` is an old Studio-only script (indexes `game`), not a lune test.
