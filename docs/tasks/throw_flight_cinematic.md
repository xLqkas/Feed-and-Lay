# Task: make the throw feel like a big moment (charge, chase camera, live luck counter, landing, reveal)

Owner: Gemini (Studio access), CLIENT PRESENTATION ONLY, while OpenCode works on training. If OpenCode is idle it can take this instead. Do NOT save, publish, commit or push.

## Do not touch (OpenCode is editing these right now)
EggService, EggRules, Main, SaveSchema, SaveStore, TrainingRules, Economy, Loop.Lift, Loop.Menus, UI.Motion, Loop.Hud layout. No server code at all in this task. If you find you cannot build something without a server change, STOP and write down exactly what the server would need to send; do not change it.

## Reference
The user showed a short of a food-throwing Roblox simulator and wants our throw to play like it. Use the mechanics, not that game's look, names or text: keep Feed and Lay's own Chunky Nest style (docs/ui_style_spec.md), our zones and creature names, our own callout words.

What happens in the reference, in order:
1. **Charge:** a tall vertical power meter next to the character (green at the bottom to red at the top) with a "tap to throw" prompt; a small "+N" ticks up beside it while charging.
2. **Release and chase:** the camera leaves the player and follows the thrown food from behind, flying fast down one long straight runway lane, with the creatures standing along both sides.
3. **Live counter during flight:** a banner at the top shows a big multiplier that counts up as the food travels (for example 27.17x, 55.00x) and the name of the zone it is passing; the zone name changes as it crosses each zone.
4. **Landing:** the food slows and stops, a big ring pulses on the landing spot, a creature catches it.
5. **Rarity callout:** big shaking text graded by rarity ("Super lucky!", "Insane luck!", "Impossible!!!", "Godly luck!!!" in the reference) with the odds as "1 in N", screen tint in the rarity colour, light pillar/particles (clover-style luck particles).
6. **Egg/creature reveal:** a gift/egg pops, then the creature's name is revealed letter by letter, hangman-style (blanks fill in one at a time), then the full name.
7. Camera eases back to the player.

## How to map it onto our game (read these first)
Read in full: Loop.Throw, Loop.Cam, Loop.Fx, Loop.Hatch, Loop.Ctx, Loop.Sfx, UI.Kit, UI.Theme, and (read-only) EggRules.release / the ReleaseThrow handler in EggService and the egg "Flight" state, to learn what the client already receives after a throw.
- Our meter already has power bands and a sweet spot (README: 6-segment meter). Restyle it as the tall vertical meter with the Chunky Nest look; keep its bands and timings exactly as they are (server rules depend on them).
- The flight must show the outcome the SERVER already decided (landing distance, zone, egg rarity, creature). The client only animates toward it. Use whatever ReleaseThrow already returns or the existing flight/egg events. Never decide or reveal anything the server has not sent.
- Live counter: count from 1.00x up to the luck value for the landing zone/food tier, and switch the zone banner as the camera passes each zone's distance (Economy.Zones has the cutoffs; read-only). Ease out so the number slows near the end.
- Rarity callout tiers: map our rarities (Common, Rare, Epic, Legendary, Mythic, and any in Economy) to 4-5 callout words of our own and the rarity colours from the spec. Odds text "1 in N" only if the client already has the odds; otherwise leave it out and say so.
- Name reveal: letter-by-letter fill of the creature name, about 1.5 s total, with a tick sound per letter; skip straight to the full name on tap.
- Put the new code in a new module (for example Loop.ThrowCinematic) with a minimal hook in Loop.Throw, so it can be turned off with one flag. Respect FLReduceMotion (shorter camera move, no shake).
- Performance: one camera tween/RenderStepped connection at a time, cleaned up after; no new parts left behind; works on phone at 60 fps target.

## Test (Play Solo + Device Simulator phone)
1. Charge, release: camera follows the food to the landing spot and back; counter and zone banner match where it actually lands (compare with the egg's zone in the inventory).
2. Throw a weak tap and a sweet-spot throw: different distances, counter stops at different values.
3. Rarity callout and name reveal match the creature the server gave (check the Book/inventory afterwards).
4. Die or leave during the flight: camera returns to the player, no stuck camera or UI.
5. Throw several times in a row: no leftover connections or parts (watch the Output and the Workspace).
6. No new errors. Studio back in Edit mode.

## Report
New/changed scripts and lines, what the client receives from the server and what you used, anything that needs a server change (written down, not done), screenshots or a short capture of charge, flight, landing and reveal on desktop and phone, test results (mark anything not run "not verified").
