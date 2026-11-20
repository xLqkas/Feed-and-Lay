# Task for OpenCode: automatic strength training with x2 bubbles, plus a strength upgrade system

Owner: OpenCode, in the open Studio place "Feed an Lay" (V3). This touches SERVER code (training, save fields) and UI. Do NOT save the place, publish, commit or push; the user saves. Read every script you edit in full first. Context: docs/phase0_decisions.md, docs/ui_style_spec.md, docs/ARCHITECTURE.md.

## What the user wants
The current strength training (bicep-curl lift with taps/holds, V3 Lift / LiftRules / EggService lift remotes) is not fun. Replace it with an AUTOMATIC system like the training pads in food-throwing simulator games:
1. The player walks into the training zone (the radius around the plot's dumbbell/lift station). While inside, strength increases automatically on a timer. No tapping, no holding, no button.
2. Now and then a "x2" bubble pops up inside the zone. If the player collects it (walk into it or tap it), strength gain is doubled for a short time. It is a small surprise reward, not a requirement.
3. A strength upgrade system the player buys with in-game currency.

## Design (follow unless a real problem appears; if you deviate, say why)
Zone: reuse the existing station check (V3.Main isNear / the "FLStation" cache) for the lift station. Leaving the radius, dying or leaving stops training. Keep the dumbbell model and make the character play the curl animation automatically while training (cosmetic only, client side).

Tick (server-owned): every `trainInterval` seconds, for each player inside the zone, add `gain = baseGain * powerMult * bubbleMult` to strength. Client sends NOTHING to earn strength. Server tells the client the result (existing state/event path) so the HUD shows a floating "+N" and a progress feel.

Bubble (server-owned):
- Per player, while training, roll for a bubble every `bubbleRollSeconds`; chance `bubbleChance` (both upgradable). At most ONE active bubble per player, lifetime `bubbleLife` seconds, random spot inside the zone radius.
- Collect: either the player's root comes within a few studs (server checks distance), or the client fires a remote with the bubble id (server validates: bubble exists, belongs to this player, not expired, player within reach, rate limited). No Instances or positions from the client.
- Effect: bubbleMult = 2 for `bubbleBoostSeconds`. Collecting another while boosted refreshes the timer, never stacks above x2.
- Bubble is visible only to its owner (client-side visual driven by a server event) so other players cannot take it.

Upgrades (a new section in the existing Upgrades panel, built with Kit components, Chunky Nest style). Costs paid with the existing currency; server validates cost and owned level; level caps; saved. Suggested set:
| Upgrade | Effect | Notes |
|---|---|---|
| Training Power | raises powerMult per level | main upgrade |
| Training Speed | lowers trainInterval per level, with a hard floor (for example 0.4s) | |
| Lucky Bubbles | raises bubbleChance | capped |
| Long Boost | raises bubbleBoostSeconds | capped |
Read Economy and the existing `dumbbellTier` upgrade first. Do NOT create a second competing system: map "Training Power" onto the existing dumbbell tier if that fits, or replace it cleanly, and report what you did. Cost curve and gain numbers go in GameConfig/Economy as named constants marked `TODO-BALANCE` (do not bury numbers in code). Proposed placeholder: start strength 150, first zone cutoffs 300/1000/2500/5000 stay as they are; tune so the first zone cutoff takes roughly 3-5 minutes of standing in the zone with no upgrades, and say what your numbers give.

## Server rules (security, same standard as the rest of V3)
- All gains, bubble spawns, bubble collection and upgrade purchases are decided on the server. Validate argument types (reject non-numbers, NaN, huge values, wrong types), check the player is alive and inside the zone, and rate limit every remote through the existing EggService._wrap pattern.
- Cap per-tick gain and per-player gain per minute so a bug or exploit cannot give unlimited strength.
- Remove the old manual lift remotes only if nothing else uses them; otherwise leave them unused and tell the user. Do not leave dead server paths that still award strength.
- Saving: add the new upgrade levels to SaveSchema with safe defaults and clamps in sanitize. An OLD save with none of these fields must load fine and a failed load must still never overwrite data. Do NOT touch SaveStore or the save mutex/pendingSaves logic.
- Do not touch the egg, wash, throw or hatch code.

## Client/UI
- HUD: floating "+N" on each tick (merge/throttle so it does not spam), clear "x2" indicator with a countdown ring while boosted, bubble with a pop-in animation and a pop effect when collected. Use Kit/Theme tokens and the motion values in the spec; respect the FLReduceMotion attribute.
- Upgrades panel: four rows with level, cost, a green buy button, disabled state when it cannot be afforded or is maxed.
- Remove the old lift HUD and the Studio-only FLDebugLiftTap hook once it is unused.
- Works on phone: nothing needed to tap to earn strength; bubble tap target at least 48px.

## Test (Play Solo, plus the Device Simulator for phone)
1. Join, walk into the zone: strength rises on its own at the expected rate. Walk out: it stops. Die in the zone: it stops, respawn, walk in: it resumes.
2. A bubble appears; collecting it doubles gain for the boost time; an uncollected bubble disappears; only one at a time.
3. Buy each upgrade: cost deducted, effect measurable, cap enforced, cannot buy without enough currency.
4. Leave and rejoin with API Services on and no Studio no-save flag: upgrade levels and strength persist. Also load an old-format save (no new fields): loads fine.
5. Try the abuse cases from the Output/command bar if you can: fire the bubble remote with bad ids, from outside the zone, and fast: all rejected, no gain.
6. No new errors in Output. Studio back in Edit mode.

## Report (only what you ran; say "not verified" for the rest)
- Scripts changed, lines, what changed; what you removed.
- The final constants and the time-to-first-zone they give.
- How Training Power relates to the old dumbbellTier.
- Test results per item above; screenshots of the HUD and the Upgrades panel.
- Anything you were unsure about.

After you finish, the architect will review the server and save changes, so keep them small and clearly commented.
