# Task for OpenCode: change the x2 bubble to a one-time on-screen tap, and apply review fixes

Owner: OpenCode, in the open Studio place "Feed an Lay". Builds on your auto-strength work (docs/tasks/opencode_auto_strength.md). Do NOT save, publish, commit or push. Do not touch SaveStore or the save mutex/pendingSaves logic.

## 1. The x2 mechanic was misunderstood: change it

What you built: an in-world bubble that gives x2 gain for N seconds.
What the user wants (they showed a screenshot of the reference): while the player is training, a round "x2" button (hand/tap icon with a big "x2" on it) pops up at a RANDOM POSITION ON THE SCREEN. Tapping it doubles ONE training gain, ONE time. It is not a timed boost. Then it disappears. If not tapped it disappears after a few seconds. Only one on screen at a time.

New design:
- Server decides WHEN a bonus is offered: while the player is in the zone, roll every `bonusRollSeconds` with chance `bonusChance` (Lucky Bubbles upgrade raises the chance). Server creates `{ id, expiresAt }` for that player and fires it to the OWNER only.
- Client decides WHERE on screen to show it (cosmetic only): random position inside the safe area, never overlapping the HUD buttons, currency stack, level bar or the Roblox top bar. Pop-in animation, pulse, pop effect when tapped. Tap target at least 64px on phone. Respect FLReduceMotion.
- Tap: client fires CollectBubble(id) (keep the existing numeric-id contract and validation). Server checks: matches this player's active bonus, not expired, player alive and still inside the training zone, rate limited. On success set `rt.x2Pending = true` and clear the bubble. The NEXT gain that is actually paid is multiplied by 2 once, then `x2Pending` is cleared (only the first paid step if the loop pays several). TrainingGain's `boosted` flag now means "this tick was doubled" so the client shows a big "+N x2!" pop on it.
- Do not spawn a new bonus while one is showing or while `x2Pending` is true. Clear `x2Pending` on leaving the zone and in clear().
- Optional: ignore a tap that arrives less than 0.3 s after the spawn (sub-human reaction time).
- An expired or unknown id is silently ignored. A second tap on the same id gives nothing.

Remove (no dead code left behind):
- boostUntil, boost duration, the "x2 active" countdown ring, and any multiplier that applies over time.
- The in-world bubble part/positions and the x/y/z values in BubbleSpawn; the distance-to-bubble check.
- The "Long Boost" upgrade (it no longer means anything). If a save field was added for it, keep reading it in SaveSchema for old saves but stop using it, and say so. Keep Training Power, Training Speed and Lucky Bubbles.

## 2. Review fixes

From the architect's read-only review of your CHANGES.md bundle (no High issues; the 4 earlier fixes are confirmed, except the x/y/z finite check, which goes away with this redesign).

Remove for the new design (exact list from the review):
- `boostUntil`, `boost(d)`, `Economy.boostSeconds`, `TRAIN_BOOST_SECONDS` / `_PER_LEVEL` / `_MAX_LEVEL`, `LongBoostCost`, the "LongBoost" branch in `trainingUpgradeCost`, its TRACKS / TRAINING_FIELDS entry.
- `longBoostLevel` in SaveSchema new/serialize/snapshot and the Main attributes `LongBoostLevel` and `TrainingBoostActive`. In sanitize, keep tolerating the old field if present (ignore it) so saves written by this build still load.
- `Spot`, `bubbleAt`, the `spot` parameter of tick, `Deps.zoneSpot`, `Deps.playerPosition` and their Main implementations, the x/y/z validation.
- `TRAIN_REACH` and the `distance` parameter of collect; the distance check in `_CollectBubble` (a screen button has no world distance and would always fail "Too far away!").
- The walk-into-bubble block in `EggService.update`.
- Client: world-space bubble projection in Loop.Lift (WorldToScreenPoint, Fx.burst at bubbleAt), the x2 countdown pill, the boostUntil handling (~line 289), the Menus LongBoost row, the boost-seconds toast.
- `V3.LiftRules` ModuleScript: no longer required anywhere but still holds the old lift award code. Delete it (and tell me which repo tests reference it).

Fix:
- MEDIUM: stale timers give a free burst on zone entry. `nextTickAt` / `nextRollAt` are only reset in the leave branch; `clear()` sets `rt.near = false` so that branch is skipped, and newRuntime sets them at join. A player who walks in after more than 8 s gets 4 ticks at once (and maybe an instant bonus roll). Fix: in tick, when near flips to true, set `rt.nextTickAt = now + interval(d)` and `rt.nextRollAt = now + bubbleRollSeconds(...)`.
- MEDIUM: flat caps (`TRAIN_MAX_TICK_GAIN = 5000`, `TRAIN_MAX_MINUTE_GAIN = 60000`) throttle real late-game players silently (Gold weights at the 0.4 s floor already exceed 60k/min) and are too loose to catch bugs early. Derive them from the player's own maximum rate, for example `tickCap = TRAIN_BASE_GAIN * strengthPerRep * 2 * 1.5` and `minuteCap = 1.5 * (60 / trainingInterval(level)) * TRAIN_BASE_GAIN * strengthPerRep * 2`. warn() once per player when a cap trips.
- LOW: `clear()` sends no `TrainingState(false)`, and the expired branch in collect sends no `BubbleExpired`. Send both so the HUD cannot stay stuck after respawn.
- LOW (note only): SaveSchema version stays 7, so if an OLD server build re-saves a record it drops the new level fields. Fine for a single-version rollout; mention it in your report.

## 3. Balance (keep the live values)
Live values are fine: start 50, first gate 80, 0.25 strength per 2 s, about 4 minutes to the first gate with no upgrades. Keep them as named constants marked TODO-BALANCE. Add: bonusRollSeconds, bonusChance, bonusLifetimeSeconds, with Lucky Bubbles levels. Report what a player gets per minute with average luck on taps.

## Test (Play Solo + Device Simulator phone)
1. Stand in zone: normal gain continues. A x2 button appears on screen at random spots, never over HUD elements.
2. Tap it: one gain of 2x tick amount, a "+N x2!" pop, button gone. Do not tap: it disappears after the lifetime and gives nothing.
3. Leave the zone while a button is showing: tapping it gives nothing (server rejects) and it disappears.
4. Fire CollectBubble with a wrong id, an old id, twice for the same id, and fast in a loop: no extra gain.
5. Lucky Bubbles upgrade measurably increases how often it appears.
6. Old save without the new fields loads. No new Output errors. Studio back in Edit mode.

## Report
Scripts and lines changed, what was removed, final constants, test results per item (mark anything not run "not verified"), and a screenshot of the x2 button on desktop and phone. Then update the review bundle (CHANGES.md) with the final code so the architect can re-check it.
