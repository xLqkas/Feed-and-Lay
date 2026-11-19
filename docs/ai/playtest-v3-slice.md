# v3 slice playtest (VS-11)

Written 2026-11-19 by the independent tester. Branch `v3`, place "Feed an Lay" (placeId 113603218122384), place version 75 at the start. Studio and repo scripts were identical before testing (37 / 37 mapped scripts, length + 31-polynomial hash). Shots: `docs/ai/shots/playtest-v3/`.

Phase 1 (this section down to the bug list) was written before any fix. Phase 2 is at the end.

## How it was played

- One fresh Studio play session, about 25 minutes of game time, PC window 794 x 576 (screenshots are 993 x 720). DataStore API access is off in this place, so every play session is a fresh, unsaved profile.
- Input went through the Studio MCP tools: walking with `character_navigation`, throws with real Space key holds, clicks with real mouse clicks on the HUD. Washing was first tried with real mouse sweeps; after that a scripted aim tracker (client side, aims at the visible mud and sends `SprayHits` at about 3-10 Hz) washed the eggs, as the earlier sessions did. Lifting 50 to 80 used a scripted tapper that taps at the ring's perfect moment (a best case, not a human).
- MCP round trips add 2-10 s to every action, so wall-clock times below are slow; "composed" times add up the measured in-game segments for a human.
- Phone checks used the debug attribute `FLDebugViewport = (667, 375)` (HUD laid out at phone size, centred and clipped in the PC window). Touch and gamepad cannot be sent through the MCP tools; those paths are code-reviewed only.

Test-tool artefacts found and ruled out (not game bugs):
- The Studio MCP resets the camera to `Scriptable` after any `execute_luau` call during which the game changed the camera type (console: "The execute_luau changed camera type. Resetting ..."). A 21 s scripted lift call left the camera frozen (shot 14). Long scripts must run in `task.spawn`.
- Tool mouse coordinates are GUI pixels (viewport minus the 58 px top inset), not screenshot pixels; my first sweeps missed the egg because of that.
- Throws fired straight at the remotes (cheat tests) are unknown to the client's egg list, so the wash view left after each hatch while those eggs waited. Real throws keep the client list right.

## First 10 minutes as a new player

Timeline from the client logger (t = 0 about 5 s after spawn; wall clock with tool latency):

| Milestone | Wall clock | In-game segment measured | Composed for a human |
|---|---|---|---|
| Step 2 (on the ledge) | 27.5 s | | 1 s walk |
| First throw released | 36.8 s | hold 1.0 s | 0:03 |
| First egg in nest | 40.8 s | release to nest 4.0 s | 0:07 |
| Wash loaded | 53.3 s | | 0:09 |
| First hatch (Moss Turtle, UNCOMMON in green) | 178.7 s | wash 6.7 s (tracker; 2 min lost to my mis-scaled mouse) | 0:16, rarity word about 0:21 |
| Book claim (+100) | about 215 s | | 0:30 |
| Throws 2 and 3, 4th rejected "Nest full!" | 233.6 / 236.0 s | | |
| Hatches 2 and 3 | 258.2 / 273.2 s | washes 6.6 and 7.7 s, next egg loads 6.2 s after a full reveal | about 0:55 |
| First purchase (Nest slot 3, 100) | about 299 s | | about 1:05 |
| First lift | 309.6 s | | |
| Marsh unlocked (Strength 80) | 369.5 s | 50 to 81 in 21.1 s (perfect bot: 12 perfect, 1 good) | about 1:45 |
| SWEET throw into the Marsh | about 500 s | hold 1.2 s | |
| Marsh egg hatched (Bog Frog) | 536.8 s | wash 19.0 s at Nozzle Lv1 | about 2:15 |
| Carrot bought, step 16 | 577.9 s | | about 2:35 |

Moments I did not know what to do, or that looked broken or ugly:

1. Spawn: the camera faces a brown cliff wall; the Ledge is about 18 studs away (spec: 6). The trail and banner make the way clear. (shot 01)
2. On the Ledge nothing shows where the food goes: no canyon, no Mama Hen, no target in view before the first throw. The ODDS board shows only the word "ODDS", and the FOOD sign sits in front of it so it reads "FOODDS". (shot 02)
3. Arriving at the washer the first message is a red "Slow down!" toast with a bonk. (shot 04)
4. Washing: my honest raster sweep over the egg (about 7 s, mouse held) popped 1 of 6 chunks (17 %). The mud is two or three small blobs on a big egg that keeps turning; a sweep crosses a blob in about 0.1 s and a chunk needs about 1 s of spray. The game only works if you chase one blob at a time. A 10-year-old will scrub and stall. (shots 05, 06)
5. After a Marsh egg is already in the nest, the banner still says "Throw into the Bog Marsh: release on SWEET!" (shot 16), so the obvious move is to throw more Meadow eggs.
6. After the tutorial the banner repeats tutorial lines ("Walk to the ledge!", "Hold to throw food to Mama Hen!", "Wash your muddy egg!") and there is no next goal. (shots 20, 23)
7. Coins pile up fast: 25K by about minute 20 with Nest 4, Pressure Wand and Blueberries the only near targets.
8. With 6+ pets the pen name tags overlap each other and slide under the HUD numbers. (shot 22)
9. The compact reveal's final card shows for about 0.7 s; twice I could not catch it in a screenshot.
10. The camera that comes back after a lift or a respawn is placed behind the character's facing and can land inside the washer pedestal. (shot 29)

Strongest moments: Mama Hen running to the food and pecking (shot 03), the egg arcing back into the nest, and the full reveal with the rarity word (shot 07). The Book and Upgrades panels look like a real Roblox game now (shots 09, 12, 18).

Console over the whole session: no errors and no warnings from game code, including during every cheat attempt. Only the known DataStore-off messages, the old `rbxassetid://203785492` warning, a plugin's asset requires and the MCP camera notices.

## Main plan targets

| Target | Result | Evidence |
|---|---|---|
| First reward within 60 s; no tutorial screens | **PASS (composed), at risk** | About 0:21 to the rarity word for a player who washes by chasing the mud (6.7 s wash). No tutorial screens, banner only. A player who scrubs randomly washes about 1 chunk per 7 s (bug M3), which would push the first reward toward 60 s. |
| One full loop in 45 s or less early on | **PASS** | 2-egg batch: release 233.6 s to second hatch 273.2 s = 39.6 s wall clock including tool walks; washes 6.6 / 7.7 s; next egg loads 6.2 s after a full reveal. |
| Every reward has a visible build-up (3-5 s) and a reveal | **PASS for full reveals, PARTIAL for compact** | Full reveal 5.1 s hop, wobble, 3 cracks, slot roll, rarity word, fanfare (shot 07). Compact reveal 2.4 s total but the result is readable for only about 0.7 s. Book claims and purchases are instant (coin burst / toast), which is fine for them. |
| Everything readable and tappable on a phone | **FAIL** | At 667 x 375 the throw meter covers the Nest and Strength rows (shot 27, bug M2); the objective banner sits on the lift ring (shot 28); Book card labels about 8 pt (shot 24). Book, Upgrades and wash HUD fit (shots 24-26). |
| The server decides every payout | **PASS** | Cheat section: every bad input rejected, no extra coins, Strength or eggs. |

## Slice acceptance tests (design-v3 section 11)

| Package | Test | Result | Evidence |
|---|---|---|---|
| VS-1 | Test prints PASS; odds to 0.1 %; `throwMultiplier(0.9) == 1.25` | **PASS** | `lune run tests/Economy.spec.luau`: PASS (500345 checks) |
| VS-2 | Sanitize/transform test incl. v6 conversion | **PASS** | `tests/SaveSchema.spec.luau`: PASS (156 checks) |
| VS-2 | Leave with 2 eggs in the nest, rejoin: eggs still there | **PASS in lune only; live NOT RUN** | Round-trip test 8 in `SaveSchema.spec.luau`. Live rejoin impossible: DataStore API access is off, every play is a fresh unsaved profile (`[V3] DataStore unavailable in Studio`). Turning it on would make Studio write to the real universe's v7 store; that is the owner's call (question Q1). |
| VS-3 | Walk Ledge -> Washer -> Hatch Pad -> Ledge in under 3 s | **NOT RUN as timed**; distances fine | Ledge to Washer about 14 studs (0.9 s at 16 studs/s), Washer to Hatch Pad 8 studs, Hatch Pad to Ledge about 22 studs: about 2.8 s by distance. Not walked with a stopwatch (MCP navigation is not human speed). |
| VS-4 | Phone and PC screenshots, nothing overflows; toast shows server message | **FAIL (phone)** | PC: nothing overflows. Phone 667 x 375: meter over stats (shot 27). Server messages shown as toasts: "Nest full! Wash an egg first.", "Walk to your ledge to throw!", "Need ... more coins" (shots 10, 19). |
| VS-5 | 3 throws accepted, 4th rejected "Nest full"; release without StartCharge rejected; no species before hatch | **PASS** | Live with Nest 3: third throw ok, 4th "Nest full! Wash an egg first."; ReleaseThrow without charge "Hold to charge first!"; replies carry zone, label, timings only. lune `EggService.spec.luau` PASS. |
| VS-6 | First throw to egg in nest in 4.0 s ± 0.2 | **PASS** | Release 36.8 s, NestUsed=1 / step 3 at 36.8, egg landed step 4 at 40.8 s: 4.0 s. |
| VS-6 | Eat Card from throw 4 | **NOT RUN this session** | Throws 4+ were scripted or rejected; earlier session PASS. |
| VS-7 | Meadow egg at Lv1 in 5-9 s | **PASS (scripted aim)**, FAIL for a random human sweep | Tracker: 6.6, 7.7, 5.9, 9.1 s; tutorial egg 6.7 s. Random raster sweep: 1 / 6 chunks in 7 s. |
| VS-7 | 60 Hz SprayHits no faster than 10 Hz | **PASS (lune)** | `EggService.spec.luau` PASS; server drops batches under 0.05 s. |
| VS-7 | Spraying only the back stalls | **PASS** | Parked aims (0,0), (0,0.4), (0.3,-0.3), 8 s each at 10 Hz: 0 of 10 chunks. |
| VS-8 | First hatch Moss Turtle, "UNCOMMON" in green | **PASS** | shot 07 |
| VS-8 | Floaters every 1 s over pen pets | **NOT RUN this session (timing)** | Floaters seen; not timed. Earlier session PASS. |
| VS-9 | Strength 80 in 20-40 s of active play | **PASS** | Perfect-timing bot 21.1 s (human will be slower, inside the window); lune 26.6-30.7 s. |
| VS-9 | 1 Hz autoclicker under 40 % | **PASS (lune)** | 4 %; worst fixed interval 35 %. Idle on the bench 21 s: session closed, Strength unchanged. |
| VS-10 | First reward under 60 s | **PASS (composed)** | see targets |
| VS-10 | Marsh egg hatched under 3:30 | **PASS (composed about 2:15)** | Segments above; wall clock 9 min with tool latency and the camera artefact. |
| VS-10 | No HUD button before its step | **PASS** | Book at 7 (shot 08), Nest chip at 8, Upgrades at 10, Strength at 11, Food at 15 (shots 08-19). |
| VS-10 | Onboarding saved, no repeat for a returning player | **PASS in lune only** | `Onboarding.spec.luau` PASS; live rejoin NOT RUN (Q1). |
| VS-11 | 3 fresh sessions on PC and phone emulation | **PARTIAL** | 1 full fresh session (steps 1-16 plus 20 minutes of break tests); phone via debug viewport; earlier sessions supplied 5 more fresh runs. |

Counts over the rows above: 14 PASS (6 of them lune-only or composed), 2 FAIL, 3 NOT RUN, 2 PARTIAL.

## Builders' unverified items

| Item | Result |
|---|---|
| Run into the Marsh | **PASS**: lift 50 -> 81, SWEET throw landed in the Marsh (shots 15, 16), Marsh wash 19.0 s with the "Nozzle too weak! Upgrade: 1.5K" chip (shot 17), Bog Frog, Book claim +750 (shot 18), Carrot bought, step 16. |
| Real rejoin | **NOT RUN** (DataStore API off; Q1). lune round trip PASS. |
| Last three restyle fixes (full-screen shade and flash, pet tag hidden under reveal text, narrower phone lift bar) | Shade covers the screen behind Book / Upgrades (shots 09, 12); flash not caught in a still; pet tag hidden during the reveal (shot 07, no tag over the pad); phone lift bar narrower than the ring row (shot 28). **PASS** as far as stills show. |
| Every UI screen at phone and PC size | HUD, Book, Upgrades, wash, lift, throw meter at both; full reveal at PC only; compact card not caught. Results in the targets table. |
| Touch and gamepad | **NOT RUN** (no MCP input). Code review below. |

### Touch and gamepad review (code read)

- THROW button: `InputBegan` / `InputEnded` on the button. If the finger slides off the button before lifting, `InputEnded` may not reach it; the 6 s "Held too long!" auto-cancel recovers. Not verified.
- Wash on touch: `TouchEnded` clears the aim for any finger, so lifting the thumbstick thumb stops spraying with the other finger. Minor.
- Lift on touch: taps that are not game-processed count; thumbstick touches are processed, so they do not. Fine.
- Upgrade sign prompts: shown on phone as a tap button next to the sign, also while washing and lifting (bug M1).
- Gamepad: throw (R2), wash (right stick + R2), lift (A) are bound. The Book and Upgrades tiles have no gamepad binding and nothing sets `GuiService.SelectedObject` when a panel opens, so a gamepad-only player cannot claim in the Book (step 7) or buy in Upgrades (steps 10 and 15) without Roblox's virtual cursor. Bug M4.

## Cheat tests (client `execute_luau` against the live server)

| Attempt | Server reply / effect |
|---|---|
| `ReleaseThrow("abc")`, `(0/0)`, `({1})` | "Bad request." |
| `ReleaseThrow(math.huge)`, `(-5)` away from the ledge | "Walk to your ledge to throw!" |
| On the ledge: charge 0.3 s, claim 1.2 s held | ok but label x0.31: the server used its own clock |
| Two `StartCharge` in a row | second "Slow down!" |
| `ReleaseThrow(1e9)` after a real charge | ok, server time used (x0.34) |
| Release again without a charge | "Hold to charge first!" |
| 4th throw with Nest 3/3 | "Nest full! Wash an egg first." |
| `StartCharge` / `StartWash` standing on another player's (plot 2) ledge | "Walk to your ledge to throw!" / "Step into your washer!" (no remote takes a player or plot id) |
| `Buy(nil / {} / "Coins" / "__index" / 1e9 / "food" / "Pen")` | "Bad request." |
| `ClaimBook` again, nil, unfound species, table, "__index", NaN | "Already claimed!" / "Find it first!" |
| Triple click on CLAIM and on a price button | paid once; "Slow down!" and "Need 11.7K more" for the extra clicks |
| `Lift(1e9, NaN, NaN)`, `Lift("x","y","z")` | "Step onto your Lift Bench!" |
| `GetState` 30 times in a burst | 3 ok, 27 "Slow down!" |
| `SprayHits` with "x", NaN egg id, aim 1e9, aim "x", NaN aim, huge egg id | ignored, no error logged |
| Parked spray aim 24 s | 0 chunks |
| Idle on the Lift Bench 21 s | session closed, Strength 83 -> 83 |
| Coins / Strength over the cheat block | 4154 -> 4738 over about 20 s (income 30/s only); Strength unchanged |

Nothing paid out and nothing errored on the server.

## Break tests

| Attempt | Result |
|---|---|
| Spam Book / CLAIM / price buttons | one claim, one purchase; extra clicks toast "Slow down!" (minor polish) |
| Click the Book tile during a full reveal | nothing (tiles slide off in station mode) |
| Press E in the washer during a wash / reveal | **Upgrades opens over the wash** (shot 21). Bug M1. |
| Walk out mid-wash at 60 %, come back | egg back in the nest, camera back; on return the wash resumes at 60 % (shot 30) |
| Fill the nest (3/3) | 4th throw refused with toast and nest pulse |
| Fill the pen (6), hatch a 7th | 7th went to storage (`placement.where = "storage"`); pets list shows 6 pen + 1 storage |
| Reset while charging a throw | respawn clean, no stuck meter, eggs kept |
| Reset mid-wash | respawn clean, egg back in the nest, camera Custom |
| Two players | **NOT RUN**: the MCP tools start a single client only |

## Fun, honestly

- **Strongest moment:** the first throw. Mama Hen running to the apple, pecking, the egg flying back into your nest is charming and new. The full reveal (wobble, cracks, slot roll, the rarity word in colour) is the second best and reads like the reference games.
- **Where it drags:** washing. It is the longest part of every loop and the least fun: two or three small blobs on a big turning egg, a scrub does almost nothing, and the Marsh egg takes 19 s at Lv1. Lifting is a bare timing ring with no animation or sound of effort. After the tutorial there is no goal on screen and the banner keeps repeating tutorial lines.
- **Against the references** (`game-study-scare-your-favorite-streamer.md`, `ui-study-popular-games.md`): the UI now looks the part; the loop has a payoff at each end (hen, reveal) but a slow middle, the pets are coloured blobs, and there is nothing to chase on screen (no "???" next creature, no next-zone teaser, no rare sparkle moment in the first 10 minutes).
- **What would keep a 10-year-old five more minutes:** a visible next target (the next creature as a "???" card with a progress bar to it), messy, satisfying mud (big blobs that splat off in chunks with foam, so random scrubbing works and good aim is faster), and a rare sparkly egg early on that forces a big reveal.

Verdict: the slice works end to end with no blocker and a solid server; it is promising but not yet catchy. Go for the core, with the wash feel and the post-tutorial goal fixed before extras.

## Ranked bug list (before fixes)

No blockers found.

**Major**

- **M1. Upgrade sign prompts stay active during wash, lift and reveal.** E (PC), X (gamepad) or the on-screen prompt button (phone) opens Upgrades over the wash view or the reveal; the Washer sign is 4.6 studs from the washer and the Weights sign 4.4 from the bench, inside the prompt's 7-stud range. Seen live (shot 21). `src/client/Loop/Menus.luau` prompt loop.
- **M2. Phone layout: the throw meter covers the Nest and Strength rows** (shot 27). `Hud.luau` compact layout: meter 80 % wide over the stats column.
- **M3. Washing by scrubbing barely works** (1 of 6 chunks in 7 s with a mouse held down and swept over the egg). Needs a design decision on aim radius / chunk size / blob size; the anti-park rule must stay (Q2).
- **M4. Gamepad cannot open the Book or press panel buttons**, so a gamepad-only player stalls at step 7. Needs a button mapping decision and real gamepad testing (Q3).

**Minor**

- m1. Red "Slow down!" toast when stepping into the washer (client retries `StartWash` 0.3 s after "Step into your washer!", the server cooldown is 0.5 s) and on double-clicks in panels.
- m2. Step 13 banner keeps saying "Throw into the Bog Marsh" while a Marsh egg already waits in the nest.
- m3. After step 16 the banner repeats tutorial lines; no "Next:" goal (P-7 in the plan).
- m4. Compact reveal result readable for about 0.7 s.
- m5. Pen name tags overlap each other and the HUD with 6+ pets.
- m6. Camera after lift close / respawn placed by the character's facing; can start inside the washer pedestal.
- m7. Phone: objective banner over the top of the lift ring.
- m8. Nothing to aim at from the Ledge before the first throw; ODDS board empty; FOOD sign in front of it reads "FOODDS".
- m9. Spawn about 18 studs from the Ledge (spec 6).
- m10. Book silhouettes are all the bunny shape; Book card labels about 8 pt on phone.
- m11. Touch: lifting any finger ends spraying; THROW button release when the finger slides off is unverified.
- m12. Economy feels loose in the slice (25K coins by minute 20 with few sinks). Not a bug; worth a look with P-1.

## Questions for the owner

- **Q1.** May a tester turn on "Enable Studio Access to API Services" for this place to test a real rejoin? Studio would then read and write the real `EggSanctuary_SaveData_v7` store for the tester's own account.
- **Q2.** Wash feel (M3): should scrubbing work? Options: bigger aim radius with fewer, wider height bands; bigger mud blobs; or damage from any hit on a facing chunk with the anti-park rule kept by requiring the aim to move. Each changes the tuned 5-9 s wash time and the lune anti-park test.
- **Q3.** Gamepad (M4): which buttons open Book and Upgrades (for example ButtonY and ButtonX; X is taken by the sign prompts), and should panels select their first button? It cannot be tested through the MCP tools.

## Phase 2: fixes and re-test

| Bug | Fix | Re-test in play mode (fresh profile) |
|---|---|---|
| M1 sign prompts during wash, lift, reveal | `src/client/Loop/Menus.luau`: prompts (and the step 10 / 15 auto-open) are off while `Ctx.washing`, `Ctx.lifting` or `Ctx.revealing`. | **PASS**: in the washer all 5 sign prompts `Enabled = false`, E during the wash opens nothing (shot 31); 1.5 s into both full reveals the Weights prompt is off; walking out turns it back on; on the Lift Bench it is off again. |
| M2 phone meter over the stats | `src/client/Loop/Hud.luau`: the meter is 50 % wide on phone too (was 80 %). | **PASS** at 667 x 375 with every stat row and the THROW button forced visible: meter x 231-564 px, stats end at 218, THROW button x 637-708 above the meter (shot 32). PC unchanged (50 % before and after). |
| M3 scrubbing does not wash | Not changed: tuning the aim radius, bands or blob size changes the tested 5-9 s wash and the anti-park rule. | Handed back as Q2. |
| M4 gamepad cannot use the Book / Upgrades panels | Not changed: needs a button mapping decision, and gamepad input cannot be sent through the Studio MCP, so a fix could not be verified. | Handed back as Q3. |

No lune test was added: both fixes are one-line UI conditions on Roblox instances, not pure logic. Checks after the fixes: all lune tests PASS (Economy, EggService, LiftRules, Onboarding, SaveSchema, test_ui_logic); `stylua --check` and `selene` clean on the v3 paths (`src/client/Loop`, `src/client/UI`, `src/server/v3`, `src/shared/Economy.luau`, `tests/*.spec.luau`; the disabled pre-v3 scripts were never formatted); `rojo build` OK; Studio and repo identical, 37 / 37 scripts by length + hash.

Also seen in the re-test run: steps 8 and 9 completed by themselves once the Book claim was made late (state-based onboarding works), and the place's window size changed between runs, which moved click targets (test artefact; clicks now go to the buttons' measured positions).

Still open: minors m1-m12, M3 (Q2), M4 (Q3), and the live rejoin (Q1).
