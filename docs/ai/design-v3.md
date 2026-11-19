# Feed and Lay: design spec v3

Written 2026-11-19 by the game designer for the build agents. It implements Phase 1 to 6 of `MAIN_PLAN.md` and stays inside its decisions (plain Luau, keep the concept, server decides every payout). Sources: `audit-feed-and-lay.md`, `game-study-scare-your-favorite-streamer.md`, `assets-inventory.md`, `reference-bobux-gang.md`, `Egg_Sanctuary_GDD.md`.

Rules for this document:
- Every number here goes into one shared module, `src/shared/Economy.luau` (tables) plus pure functions with an assert test. Nothing is hard-coded in UI or server scripts.
- "Server validates" lists are the minimum. Every RemoteFunction also follows the plan's handler shape: whitelist, per-player cooldown, busy flag, type and range checks, `pcall`, reply `{ok, message}`.
- "Phone" means the compact layout: `compact = viewport.X < 700 or viewport.Y < 500` (the BG `layout()` rule). Everything else is "PC". Console uses the PC layout with gamepad bindings listed where they differ.
- Where a mechanic is borrowed from the study game, only the mechanic is taken. No names, characters or art from it.

---

## 0. What we keep, what we cut

**Keep from the GDD and the current build:** strength = distance, food = luck (the "dual treadmill"); 5 canyon zones with 3 creatures each; mutations Shiny / Golden / Rainbow; the 3D power-wash station (rebuilt, server-owned); the 5 existing pet templates (`Meadow Bunny`, `Slime Drake`, `Ember Hound`, `Coral Leviathan`, `Galaxy Titan`) as 5 of the 15 creatures; a lucky-food pass.

**Cut:**
| Cut | Why |
|---|---|
| Auto-Thrower and Auto-Washer passes | They sell skipping the game and let idle players progress content. Replaced by Fast Wash (x2 spray power). |
| Golden Feast Bait (paid guaranteed mutation), Instant Hatch Potion | Paid outcome on a random roll; hatch is 5 s anyway. |
| 3-layer wash, incubators, growth timers | Lengthen the loop we are trying to shorten. |
| Alpha bosses, 50,000-stud distances, the CCU target | Scope. |
| Separate Hatch button, old 2D WashModal, Dumbbell tool, GYM nav button | Replaced by automatic flow and stations. Delete their code. |
| Pet selling for profit, merging, trading, food selector | Exploit risk, scam risk for kids, and menus nobody needs. Release (small refund, with confirm) stays. |
| Washer "Tier" cosmetic wand, separate PSI and Width tracks | Merged into one Nozzle level. |
| Offline earnings | Idle must not skip content. |
| Dark nights | Kids' bright game. Night becomes a warm "Golden Hour" event. |

---

## 1. Pitch

Throw food down a giant canyon to hungry Mama Hens, catch the muddy eggs they lay, blast them clean and hatch a creature that earns coins for you forever. The farther you throw and the better the food, the rarer the egg.

**The one feeling:** "What's inside this egg?" Every throw ends in a reveal you watched coming.

Core vocabulary used everywhere in UI text: **Coins**, **Strength**, **Food**, **Nest**, **Washer**, **Pen**, **Book**, **Mama Hen**, **Golden Hour**.

---

## 2. The core loop

### 2.1 Shape

```
THROW (hold-release, 1.5 s)  ->  MAMA HEN EATS + LAYS (3 s, watched)  ->  EGG FLIES INTO YOUR NEST (1.5 s)
      ^                                                                             |
      |                                                                             v
SPEND COINS  <-  PET EARNS +X/s IN PEN  <-  HATCH ROLL + REVEAL (5 s)  <-  WASH (4-8 s active spray)
```

How each audit problem is solved:

| Audit problem | Fix |
|---|---|
| One egg at a time; cannot throw while an egg waits | A **Nest** holds 2 eggs at start, up to 8. You can throw while eggs are in flight or waiting, as long as nest slots (counting eggs in flight) are free. |
| Long walks (about 100 studs each way) | Every plot is rebuilt on the canyon rim. Ledge, Nest, Washer, Hatch Pad, Lift Bench and Pen all sit within a 14-stud radius of the plot centre. No walk is longer than 1 s. |
| 60 s hold-to-wash, aiming barely matters | 10 mud chunks, server-owned HP, chunks only take damage when they face the camera. 4-8 s at the matching nozzle level. Next egg auto-loads. |
| AFK training | **Lift** is a timing ring: one tap per rep, a miss gives nothing, and the ring speed varies. Strength only comes from reps. |
| No payoff on throw | A Mama Hen visibly runs to the food, pecks it, lays, and the egg arcs back into your nest. Sparkly eggs hint at rarity. |
| No payoff on hatch | Wobble and cracks for 3 s, a 2 s slot-machine roll, rarity word in its colour, camera on the pet, then it hops into your pen and shows `+X/s` every second. |

### 2.2 Brand-new player, first 3 minutes (second by second)

Assumes default walk speed 16 and a player who follows the banner. "Banner" is the objective banner (section 5). Times are cumulative.

| Time | What happens | Player sees / hears |
|---|---|---|
| 0:00 | Spawn on own plot centre, facing the Ledge (6 studs away). Coins 0, Strength 50, food Apple, Nest 2 slots, Pen 6 slots, no pets. | Banner "Walk to the ledge!". Glowing arrow trail from feet to the Ledge. No other HUD. Soft ambient music starts. |
| 0:02 | Player steps on the Ledge pad. | Pad ring glows. Phone: big THROW button fades in bottom-right. PC: chip "Hold click to throw". Banner "Hold to throw food to Mama Hen!". Odds board on the ledge railing shows Meadow odds. |
| 0:04 | Hold. Power needle sweeps up and down the meter; the meter shows the Meadow band in green. | Rising whoosh while charging. |
| 0:05.5 | Release (any position works; tutorial throw 1 always lands in Meadow). | Arm swing, apple leaves the hand. **Throw cam** (first 3 throws): camera follows the apple 1.2 s down the canyon. |
| 0:07 | Apple lands. Mama Hen (Meadow tint) runs 0.5 s, pecks 3 times in 1.0 s, sits and lays (0.4 s). | Crumb particles, "nom" x3, heart pop, cluck. |
| 0:09 | Egg launches back in a high arc, 1.5 s, camera rides back with it. | Mud trail, whistle. |
| 0:10.5 | Egg lands in Nest slot 1. | Squash and stretch, dust puff, thunk, 0.15 s camera shake. Banner "Wash your muddy egg!". Arrow trail to Washer ring (5 studs). |
| 0:12 | Player steps into the Washer ring. Wash starts automatically (no button). | Camera eases to the wash view in 0.4 s. Progress bar replaces the banner. Hint chip "Hold and aim at the mud" (PC) / "Touch and drag on the mud" (phone). |
| 0:12-0:17 | Tutorial egg: 6 chunks, about 4.5 s of spraying. | Each chunk pops with a splat, "+17%" floats, pitch rises per chunk. |
| 0:17 | Egg clean. | Shine sweep, sparkle burst, "CLEAN!" pop, chime. Egg hops to the Hatch Pad (0.5 s). |
| 0:17.5-0:20.5 | Wobble with 3 crack stages. | Camera on the Hatch Pad. Crack sound per stage, rising hum. |
| 0:20.5-0:22.5 | Slot roll over the egg (Meadow Bunny / Moss Turtle / Clover Fawn names and silhouettes cycle, slowing down). | Tick per name change. |
| 0:22.5 | **First reward (target: within 60 s): Moss Turtle, UNCOMMON** (the first egg is always a Moss Turtle; the Book says so). | Shell bursts, rarity word "UNCOMMON" in green, name, "+3/s". Fanfare. Camera holds 1.5 s on the pet. |
| 0:24 | Turtle hops into the Pen. Income starts. | `+3` floats over it every second. **Coins counter appears** bottom-left (phone: top-left) and rolls up. |
| 0:25 | **Book button appears** with red dot and bouncing pointer hand. | Banner "New creature! Claim it in your Book". Arrow trail hides (UI target, not world). |
| 0:30 | Player opens the Book, taps CLAIM on Moss Turtle. | 100 Coins: 12 coin icons fly to the counter in 0.8 s, counter rolls, coin jingle. |
| 0:33 | Book closes. | Banner "Throw 2 more eggs!". Trail to Ledge. **Nest chip** appears next to Coins: "Nest 0/2". |
| 0:35-0:42 | Two throws, 1.5 s cooldown between. Throw 2 still uses throw cam; throw 3 uses the compact Eat Card. | Nest chip counts eggs in flight as used ("Nest 2/2"). Trying a 3rd throw: red shake on the THROW button, toast "Nest full! Wash an egg first." |
| 0:46 | Both eggs in the nest. | Banner "Wash your eggs!". Trail to Washer. |
| 0:47-1:02 | Wash egg 2 (Meadow egg, 10 chunks, about 7 s), egg 3 auto-loads 0.6 s later, wash it. Egg 2 hatches on the Hatch Pad while egg 3 is washed. | Hatches 2 to 5 still play the full reveal (camera cuts to the pad, spraying pauses for the reveal). |
| 1:05 | Three pets: about 5/s. Coins about 150 (100 claim + income; Meadow Bunny discovery claim adds 100 more if found). | Banner "Buy a bigger nest!" once Coins >= 100. **Upgrades button appears** with red dot. Trail to the Nest sign. |
| 1:10 | Player buys Nest slot 3 (100). | Purchase juice (section 8). Nest grows a 3rd cup in the world. |
| 1:15-1:45 | Loop: 3 throws (6 s) + wash 3 (about 21 s) + walk (2 s) = about 30 s. | Hatches 4-6. |
| 1:50 | Banner "Throw farther: train at the Lift Bench!". **Strength chip** appears. Trail to Lift Bench (6 studs). |
| 1:52-2:17 | Lift: 30 reps at about 1.2 Strength/s with the Twig weights takes about 25 s. Goal shown on the ring: "Strength 50 / 80". | Each good rep: "+1" (perfect "+2") pops, grunt, bar fill. At 80: "MARSH UNLOCKED!" stamp, fanfare. |
| 2:20 | Banner "Throw into the Bog Marsh!". Trail to Ledge. The meter now shows a Marsh band at the sweet spot only. | |
| 2:25 | Sweet-spot throw lands in the Marsh (distance 100). | Throw cam forced (first throw into a new zone always uses it). Marsh Mama Hen (green tint) eats. |
| 2:30-2:45 | Wash a Marsh egg with nozzle Lv1: about 21 s (deliberately slow). | Wash HUD shows "Nozzle too weak for Marsh mud! Upgrade: 1.5K" chip. |
| 2:50 | Hatch: Bog Frog (Uncommon, +25/s) or better. | Full reveal. Book dot: new entry (claim 750). |
| 3:00 | Income about 35/s, Coins about 900 after claim. | Banner "Buy Carrots for better eggs!". Trail to the Food Stall sign. |

Loop length early: 1 throw-to-reveal is about 22 s for the first egg; a 3-egg batch takes about 30 s. Both are under the 45 s target.

### 2.3 Player at 30 minutes (second by second)

State assumed: in the Reef, Nest 6, Pen 12, Nozzle Lv4, food Pancakes, about 450K/s, Golden Hour in 4 minutes. One batch:

| Time | What happens |
|---|---|
| 0:00 | Player is on the Ledge. Banner shows the long goal: "Next: Gold Weights (200M) to reach the Starfield". |
| 0:00-0:10 | 6 throws, 1.5 s cooldown, each about 0.4-1.0 s charge. Each throw shows the compact **Eat Card** (2.2 s, bottom-centre) instead of throw cam. One egg comes back with a gold sparkle trail (rare-slot hint), and that throw forces throw cam for its egg return only (1.5 s). |
| 0:10 | Step back 4 studs into the Washer ring. |
| 0:10-0:45 | 6 Reef eggs at about 4.3 s each plus 0.6 s load = about 30 s. Common and Uncommon hatches use the **compact reveal** on the Hatch Pad (2.5 s, small card top-centre, no camera move). The sparkly egg is Legendary: full reveal, spraying pauses 5 s, server announcement "Filip hatched a LEGENDARY Coral Leviathan!". |
| 0:45 | Pen is full: the new pet is better than the worst, so it swaps in automatically. Toast "Coral Leviathan joined your pen. Bubble Seal moved to storage." |
| 0:45-0:55 | Walk to the Upgrades sign or open the Upgrades panel: buy Pen slot 12 (green price), check Gold Weights (red price, progress bar 62%). |
| 0:55 | Back to the Ledge. Next batch. |

Batch: about 55 s for 6 eggs (about 9 s per egg). Every 3-5 minutes there is a purchase; about every 8 minutes a 60 s Lift session to reach the next zone; every 10 minutes a 2-minute Golden Hour (section 6.2) that pulls everyone to throw at once.

---

## 3. Stations

### 3.0 Plot layout (all stations)

Six plots in a semicircle around the canyon mouth, each plot a 60 x 60 stud square whose front edge is the canyon rim. Positions relative to plot centre (X right, Z toward the canyon):

| Station | Offset (studs) | Footprint |
|---|---|---|
| Spawn point | (0, 0, -6) facing +Z | |
| Ledge pad | (0, 0, +12) | 8 x 6 pad, glowing ring, railing with Odds Board |
| Nest rack | (+8, 0, +8) | 8 cups in a curved rack; locked cups show a padlock |
| Washer ring | (+12, 0, +2) | 6-stud circle; turntable pedestal at its centre |
| Hatch Pad | (+12, 0, -6) | 4-stud pedestal with light beam |
| Lift Bench | (-10, 0, +6) | bench + weights rack |
| Food Stall sign, Upgrades signs | one sign per station, 2 studs beside it | SurfaceGui, opens the matching Upgrades tab |
| Pen | back half, (-20..+20, 0, -10..-28) | fenced, 16 pet spots in a grid of 4 x 4 |
| Base sign | (0, 12, -30) | big BillboardGui "FILIP'S SANCTUARY +1.2K/s", visible 300 studs |

All interactive stations are tagged with CollectionService tag `FLStation` and attribute `Kind` (`Ledge`, `Nest`, `Washer`, `HatchPad`, `Lift`, `Pen`, `Sign`), so code never searches by name. The map agent rebuilds the canyon so each zone band has a flat landing floor (section 3.4).

### 3.1 Lift Bench (training)

**Input.** Step into the bench ring (4 studs): the camera eases to a side view (0.4 s) and the Lift HUD opens. A target circle sits at screen centre; an outer ring shrinks toward it. Tap (phone: anywhere on screen except UI buttons; PC: click or Space; gamepad: A) when the ring overlaps the target.

| Hit window | Result |
|---|---|
| Ring within 6% of the target radius | PERFECT: 2 reps |
| within 18% | GOOD: 1 rep |
| outside, or no tap before the ring passes 30% inside | MISS: 0 reps, ring resets |

- Ring shrink time per rep: random 0.75-1.1 s (server-chosen seed per session, so a fixed-interval autoclicker hits about 25%).
- Strength per rep = dumbbell value x (1 + Rebirths). Twig 1, Stone 10, Iron 100, Gold 1000.
- Leave by walking out (movement input) or the X button. 20 s without a tap closes the Lift HUD.
- Average active rate (measured target): about 1.2 rep-units per second.

**Sees/hears.** Character plays a real `Animation` (curl loop, uploaded asset, replicates to all players; replaces the Motor6D code). Floating "+10" (perfect "+20", gold), grunt sound, bar "Strength 320 / 800 (next zone)". Miss: grey "MISS", soft thud, no shake. Reaching a zone threshold: stamp "VOLCANO UNLOCKED!" and fanfare.

**Server validates** (`Lift:InvokeServer(sessionId, result)` where result is `"perfect" | "good" | "miss"`):
- Player is within 8 studs of their own bench and has an open lift session (`StartLift` creates it and returns the seed).
- At least 0.6 s since the last accepted rep; at most 75 reps per minute; a rolling 10-minute cap of 650 reps (above that, reps give 0 with toast "Take a breather!").
- `perfect` is accepted at most 60% of reps in any 50-rep window; above that the server downgrades to `good` (stops scripted perfects).
- Strength is written server-side; client shows the server's number.

### 3.2 Ledge (throwing)

**Input.** On the Ledge pad, hold (PC: left mouse or Space; phone: THROW button; gamepad: R2) to charge, release to throw. The power needle ping-pongs 0 -> 1 -> 0 with a 1.4 s half-cycle. Release position `p` sets the multiplier:

| p | Multiplier | Label |
|---|---|---|
| 0.00-0.82 | 0.05 + 1.0 x p | "x0.4" etc. (shows the zone it lands in) |
| 0.82-0.96 | **1.25** | "SWEET!" (green band) |
| 0.96-1.00 | 1.00 | "Too much!" |

Distance = Strength x multiplier x (pass/boost bonuses: none in v3). The meter is a horizontal bar whose background is split into coloured zone bands for the player's current Strength, so the player can aim at a lower zone (to fill the Book) by releasing early.

- Throw cooldown 1.5 s (server).
- Blocked when nest slots used (in nest + in flight) = nest size: THROW button shakes red, toast "Nest full! Wash an egg first."
- Maximum hold 6 s, then auto-cancel.

**Sees/hears.** Arm-swing animation, food model (the current food's icon as a 3D billboard sprite until meshes exist) flies in a parabola, apex 40 + 0.05 x landing distance in studs, capped at 160 studs, 1.2 s. Whoosh. Release label pops near the meter for 0.6 s.

**Throw cam rule.** Camera follows the food and the egg (section 3.4) when any of these is true: it is one of the first 3 throws ever; it is the first throw into a newly unlocked zone; the egg is a sparkle egg (rare slot, return leg only); setting "Follow every throw" is on. Otherwise the **Eat Card** shows (section 3.3).

**Server validates.** `StartCharge` stores `os.clock()`; `ReleaseThrow(clientElapsed)`:
- Player on own Ledge pad (server-side `GameConfig.IsInLaunchZone` replaced by a per-plot box), alive, not washing or lifting.
- A charge exists (no release without start). Elapsed = server elapsed, but the client's value is accepted if within +-0.15 s of it (latency allowance); otherwise the server's value is used.
- Cooldown, nest capacity, busy flag.
- Server computes `p`, distance, zone, creature, mutation and sparkle, creates the egg record (`state = "Flight"`, `arrivesAt = now + 4.0`), returns `{ok, zone, landingDistance, sparkle, eggId, flightTimes}`. The species and mutation are **not** sent to the client until hatch.

### 3.3 Mama Hen (the creature that eats)

One Mama Hen rig (big round hen, about 10 studs tall), tinted per zone with a zone hat: Meadow (cream + flower crown), Marsh (green + lily pad), Volcano (charcoal + ember comb), Reef (teal + shell), Starfield (violet + star). She is **client-local**: each client spawns its own Mama at its own landing point from `ReplicatedStorage.Models.MamaHen`, so six players never fight over one NPC. Other players see only the food arc and the egg arc (cheap parts), and nothing beyond 300 studs.

Timeline after the food lands (4.0 s total from release to egg in nest):

| t from release | Beat |
|---|---|
| 0.0-1.2 | Food flight |
| 1.2-1.7 | Mama runs from 12 studs away to the food (or pops out of a bush if the camera is not following) |
| 1.7-2.7 | Pecks 3 times; crumbs; "nom" x3; hearts |
| 2.7-3.1 | Sits, squash, egg pops out with a cluck |
| 2.5-4.0 | Egg flight home (overlaps: launched at 2.5 so the total stays 4.0 s; tune visually) |

**Eat Card** (when throw cam is off): a 220 x 160 px (phone 160 x 120) ViewportFrame card that slides up bottom-centre, showing the Mama eating with the zone floor colour behind her, the zone name, and the egg leaving. 2.2 s on screen, slides down. Up to 3 cards stack side by side; more are skipped (eggs still arrive).

**Server validates:** nothing new; the server's egg record and `arrivesAt` are the truth. The client animation is cosmetic.

### 3.4 Egg flight and the Nest

- Distance is a game number, not studs. Landing point on the canyon floor: `Z = zone.floorStartZ + (dist - zone.min) / (zone.max - zone.min) x zone.floorLength`, clamped to the zone floor. Each zone floor is 1,400 studs long on the existing canyon (Starfield clamps at its end).
- Egg return: Bezier arc from the landing point to the player's next free nest cup, 1.5 s, apex 60 studs above the rim, egg spins 2 turns. Mud trail particles (zone colour). Sparkle eggs add a gold sparkle trail and a twinkle sound.
- Landing: squash (Y 0.7, 0.08 s) then stretch back with Back easing (0.25 s), dust puff, thunk, camera shake 0.15 s amplitude 0.3 studs (only if the egg is the player's own and the camera is within 40 studs).
- Nest cups: 2 at start, up to 8 (section 4). Eggs in the nest show zone crust colour and, for sparkle eggs, a slow glint every 2 s. BillboardGui over the nest: "2/3".
- Eggs in the nest are **saved** (fixes "leaving loses the egg"). Eggs still in flight on leave are saved as in the nest.

**Server validates:** egg moves `Flight -> Nest` only when `os.clock() >= arrivesAt`. Wash requests for an egg in `Flight` are rejected ("Egg still flying!").

### 3.5 Washer

**Entering.** Step into the Washer ring with at least one egg in `Nest` state. The oldest egg hops onto the turntable (0.6 s), camera eases to a fixed wash view 0.4 s. Leaving: movement input, X button, or the nest is empty 1 s after the last egg finishes.

**The egg.** 10 mud chunks (tutorial egg: 6) placed evenly over the egg. The turntable spins 40 degrees per second, server-timed (`angle = (now - washStart) x 40`). Each chunk has `HP = zone chunk HP` (table 4.6).

**Input.** PC: hold left mouse, aim with the mouse. Phone: touch and hold on the egg; the spray follows the finger. Gamepad: right stick aims, R2 sprays. Client raycasts the spray each 0.1 s and collects chunk ids within the nozzle radius around the hit point.

**Timings.** At the matching nozzle level a Meadow egg takes about 7 s, a Starfield egg about 4 s (table 4.6). Under-levelled nozzles are slow on purpose and show a chip "Nozzle too weak! Upgrade: 60K" (price coloured by affordability) in the wash HUD.

**Sees/hears.** Water jet Beam plus spray particles, constant hiss (pitch up while hitting mud). Each chunk: HP drains as the chunk shrinks (scale 1 -> 0.6), then pops: mud splat particles in zone colour, splat sound with pitch rising 4% per chunk popped, "+10%" floats from the chunk toward the progress bar. Progress bar top-centre (replaces the banner) with percentage and the egg's zone name. At 100%: section 8 "wash done".

**Server validates** (`SprayHits` is an `UnreliableRemoteEvent`, client to server, max 10 Hz, payload `{eggId, chunkIds}`):
- Egg belongs to the player and is `Washing`; player within 10 studs of their Washer.
- Number of chunk ids at most the nozzle's `maxChunksPerHit` (table 4.6); ids valid and alive.
- Facing: the server computes each chunk's world normal from the turntable angle; chunks with `dot(normal, washCameraDirection) < 0.2` are ignored. (Fixes the "front of egg" fallback; aim matters.)
- Damage per chunk = nozzle DPS x dt, with dt = time since last accepted batch, capped at 0.15 s. So sending faster gives nothing.
- Minimum wash time per egg 1.5 s from wash start, whatever the DPS.
- Server fires `ChunkPopped(eggId, chunkId)` and `WashDone(eggId)` (RemoteEvent to that player only). Client never sends a percentage. Wash progress is not saved; an egg left half-washed keeps its chunk HP only for the session.

### 3.6 Hatch Pad

Starts automatically when an egg finishes washing. One egg at a time; queue up to the nest size (queued eggs sit on a small shelf next to the pad).

| Mode | When | Sequence |
|---|---|---|
| **Full reveal** | Hatches 1-5 ever, any Rare or better, any mutation, any first-time species | 3.0 s wobble (cracks at 1.0, 2.0, 3.0 s) -> 2.0 s slot roll -> burst -> 1.5 s hold on the pet. Camera cuts to the pad; washing pauses (input ignored, turntable stops). |
| **Compact reveal** | Everything else | 1.5 s crack -> 1.0 s roll on a small card top-centre -> pet hops to the pen. No camera move, washing continues. |

Slot roll: card above the egg cycles the zone's 3 creature names and silhouettes (and for mutations a final "...SHINY!" tick), 14 changes, interval easing from 0.06 s to 0.3 s, lands on the result. Result card: rarity word in rarity colour (table 4.4), creature name, mutation word if any, "+X/s" in green.

After the reveal the pet jumps (0.6 s arc) to its pen spot. If the pen is full, the pet takes the spot of the lowest-income pen pet when it is better, and that pet goes to storage; otherwise the new pet goes to storage. Toast says which.

**Server validates:** the server picked species and mutation at throw time; `HatchResult` is pushed by the server when wash is done. No client remote starts a hatch.

### 3.7 Pen (pet earning)

- Pen holds 6 pets at start, up to 16 (+4 with the Big Pen pass). Only pen pets earn. Storage holds 60 pets.
- Income per second = sum over pen pets of `species income x mutation multiplier`, then x (1 + 0.5 x Rebirths) x (2 if x2 Coins pass) x (1.1 if VIP) x (1 + 0.1 x friends in server, max 0.3) x (1 + 0.05 x completed Book pages).
- Server ticks once per second and adds coins. Client shows, above each pen pet, `+X` in green Fredoka One that floats up 3 studs and fades over 0.9 s, once per second, staggered by pet index x 0.08 s so they ripple. Only the 12 pets nearest the camera show floaters (performance).
- Pets wander inside their 6 x 6 stud spot (random target every 3-6 s, walk speed 4, idle bob). This replaces the 1.8-stud circle in `PetShowcaseAnimator`.
- BillboardGui over each pet: name + rarity word in colour; visible within 40 studs.

**Release** (from the Pets panel): pays 20 x the pet's base income, requires a confirm dialog ("Release Bog Frog for 500 coins? This cannot be undone." with red "Release" and neutral "Keep"). Server: pet owned, not the last pet, 0.5 s cooldown, busy flag.

**Equip Best** button in the Pets panel: server sorts all pets by income and fills the pen.

### 3.8 Selling and merging

Selling for profit and merging are cut (section 0). Release is the only way to remove a pet.

---

## 4. Economy and progression

All numbers live in `src/shared/Economy.luau`. Number formatting everywhere: 1,234 -> "1.23K", then M, B, T, 3 significant digits.

### 4.1 Zones and Strength

Distance = Strength x throw multiplier (max 1.25).

| # | Zone | Distance band | Strength to reach with a SWEET throw | Chunk HP | Mama tint |
|---|---|---|---|---|---|
| 1 | Dewdrop Meadow | 0-100 | start (50) | 10 | cream |
| 2 | Bog Marsh | 100-1,000 | 80 | 30 | green |
| 3 | Ember Volcano | 1,000-10,000 | 800 | 100 | charcoal |
| 4 | Coral Reef | 10,000-100,000 | 8,000 | 300 | teal |
| 5 | Starfield | 100,000+ | 80,000 | 1,000 | violet |

(Rename note: config names "Toxic Slime Marsh", "Cinder Volcano", "Sunken Coral Reef", "Celestial Galaxy" become the names above; the map folders must be renamed to match, fixing the audit's name mismatch.)

### 4.2 Dumbbells (Strength per good rep)

| Tier | Name | Strength per rep | Cost | Lift time to the next gate with this tier |
|---|---|---|---|---|
| 1 | Twig Weights | 1 | free | 50 -> 80: about 25 s |
| 2 | Stone Weights | 10 | 50K | 80 -> 800: about 60 s |
| 3 | Iron Weights | 100 | 3M | 800 -> 8,000: about 60 s |
| 4 | Gold Weights | 1,000 | 200M | 8,000 -> 80,000: about 60 s |

With the previous tier each gate takes about 10 minutes of lifting: possible (effort can replace coins) but slow.

### 4.3 Food (luck)

| Tier | Food | Luck L | Cost | Icon (Gvesster, unmodified) |
|---|---|---|---|---|
| 1 | Apple | 1 | free | `Nature\Apple\256px\Apple 1st 256px.png` |
| 2 | Carrot | 2 | 500 | `Food\Carrot\256w\Carrot 1st 256px.png` |
| 3 | Blueberries | 4 | 15K | `Food\Blueberry\...` (1st, 256) |
| 4 | Pancakes | 8 | 1M | `Food\Pancake\...` (1st, 256) |
| 5 | Strawberry | 16 | 60M | `Nature\Strawberry\...` (1st, 256) |
| 6 | Star Cookie | 32 | 3B | `Food\Cookie\256px\Cookie 1st 256px.png` |

The best owned food is always used. Lucky Food pass doubles L.

### 4.4 The 15 creatures

Each zone has 3 creature slots A, B, C. Rarity colours: Common `#B8C0CC`, Uncommon `#5BD45B`, Rare `#3BA7FF`, Epic `#B65CFF`, Legendary `#FFC800`, Mythic `#FF4B6E`, Secret = animated rainbow `UIGradient`. The rarity word is always shown as a word too (never colour alone).

| Zone | Slot | Creature | Rarity | Income/s | Book claim (30 x income, min 100) | Model |
|---|---|---|---|---|---|---|
| Meadow | A | Meadow Bunny | Common | 1 | 100 | existing template |
| Meadow | B | Moss Turtle | Uncommon | 3 | 100 | new |
| Meadow | C | Clover Fawn | Rare | 10 | 300 | new |
| Marsh | A | Bog Frog | Uncommon | 25 | 750 | new |
| Marsh | B | Slime Drake | Rare | 60 | 1.8K | existing template |
| Marsh | C | Lily Croc | Epic | 200 | 6K | new |
| Volcano | A | Ember Hound | Rare | 600 | 18K | existing template |
| Volcano | B | Magma Newt | Epic | 1.5K | 45K | new |
| Volcano | C | Ash Phoenix | Legendary | 5K | 150K | new |
| Reef | A | Bubble Seal | Epic | 15K | 450K | new |
| Reef | B | Coral Leviathan | Legendary | 40K | 1.2M | existing template |
| Reef | C | Pearl Whale | Mythic | 120K | 3.6M | new |
| Starfield | A | Comet Fox | Legendary | 400K | 12M | new |
| Starfield | B | Nebula Kirin | Mythic | 1.2M | 36M | new |
| Starfield | C | Galaxy Titan | Secret | 5M | 150M | existing template |

### 4.5 Odds (published in game; section 9)

Weights: A = 80, B = 18 x sqrt(L), C = c x L x G, where c = 2 (Starfield: 0.2) and G = 2 during Golden Hour, else 1. Odds = weight / sum. The first egg ever is always Moss Turtle (stated in the Book and on the Odds Board while the tutorial runs).

Zones 1-4, percentages A / B / C:

| Food (L) | Normal | Golden Hour |
|---|---|---|
| Apple (1) | 80.0 / 18.0 / 2.0 | 78.4 / 17.6 / 3.9 |
| Carrot (2) | 73.1 / 23.3 / 3.7 | 70.5 / 22.4 / 7.1 |
| Blueberries (4) | 64.5 / 29.0 / 6.5 | 60.6 / 27.3 / 12.1 |
| Pancakes (8) | 54.5 / 34.7 / 10.9 | 49.1 / 31.3 / 19.6 |
| Strawberry (16) | 43.5 / 39.1 / 17.4 | 37.0 / 33.3 / 29.6 |
| Star Cookie (32) | 32.5 / 41.4 / 26.0 | 25.8 / 32.9 / 41.3 |

Starfield (Galaxy Titan is slot C):

| Food (L) | Normal | Golden Hour |
|---|---|---|
| Apple (1) | 81.5 / 18.3 / 0.2 | 81.3 / 18.3 / 0.4 |
| Carrot (2) | 75.6 / 24.0 / 0.4 | 75.3 / 24.0 / 0.8 |
| Blueberries (4) | 68.5 / 30.8 / 0.7 | 68.0 / 30.6 / 1.4 |
| Pancakes (8) | 60.4 / 38.4 / 1.2 | 59.7 / 38.0 / 2.4 |
| Strawberry (16) | 51.5 / 46.4 / 2.1 | 50.5 / 45.5 / 4.0 |
| Star Cookie (32) | 42.5 / 54.1 / 3.4 | 41.1 / 52.3 / 6.6 |

**Sparkle hint:** every slot-C egg is a sparkle egg. Slots A and B never sparkle.

**Mutations** (rolled separately, independent of food): Shiny x2 income 2%, Golden x5 0.5%, Rainbow x10 0.1% (Normal otherwise). Golden Hour triples all three. Shiny: light-blue tint + sparkles; Golden: gold `Color` + metal material; Rainbow: hue cycles on the client.

The odds functions are pure (`Economy.eggOdds(zone, L, goldenHour) -> {A, B, C}`, `Economy.rollEgg(zone, L, goldenHour, rng)`), and the assert test checks that the table above matches the function to 0.1%.

### 4.6 Washer nozzle, Nest, Pen

Nozzle (one track):

| Lv | Name | DPS | Radius (studs) | Max chunks per hit | Cost |
|---|---|---|---|---|---|
| 1 | Garden Hose | 10 | 1.5 | 2 | free |
| 2 | Pressure Wand | 30 | 2.0 | 3 | 1.5K |
| 3 | Turbo Jet | 100 | 2.5 | 4 | 60K |
| 4 | Hydro Cannon | 300 | 3.0 | 5 | 4M |
| 5 | Star Blaster | 1,000 | 3.5 | 6 | 300M |

Expected wash time per egg (10 chunks, average chunks hit per spray 1.4 / 1.7 / 2.0 / 2.3 / 2.6 by level; floor 1.5 s):

| Zone \ Nozzle | Lv1 | Lv2 | Lv3 | Lv4 | Lv5 |
|---|---|---|---|---|---|
| Meadow | **7.1 s** | 2.0 | 1.5 | 1.5 | 1.5 |
| Marsh | 21 | **5.9 s** | 1.5 | 1.5 | 1.5 |
| Volcano | 71 | 20 | **5.0 s** | 1.5 | 1.5 |
| Reef | 214 | 59 | 15 | **4.3 s** | 1.5 |
| Starfield | 714 | 196 | 50 | 15 | **3.8 s** |

Nest slots (start 2): 3rd 100, 4th 1K, 5th 20K, 6th 500K, 7th 20M, 8th 1B.

Pen slots (start 6): 7th 300, 8th 2K, 9th 10K, 10th 50K, 11th 250K, 12th 1.5M, 13th 10M, 14th 80M, 15th 600M, 16th 5B.

### 4.7 Income per second (expected full pen)

From a simulation of 15 eggs with the pen keeping the best ones (mutations included):

| Stage | Food | Pen | Expected income/s |
|---|---|---|---|
| Meadow | Apple | 6 | 16 |
| Marsh | Carrot | 8 | 440 |
| Volcano | Blueberries | 10 | 15K |
| Reef | Pancakes | 12 | 510K |
| Starfield | Strawberry | 14 | 13M |

### 4.8 Rebirth

- Available once the player has reached the Starfield. Cost 10B x 4^Rebirths. Maximum 10 rebirths in v3.
- Resets: Coins, Strength (to 50), dumbbell, food, Nest slots.
- Keeps: all pets (pen and storage), Pen slots, Nozzle, Book, passes, daily streak.
- Gives per rebirth: +50% coins (additive), Strength per rep x (1 + Rebirths), a rebirth star on the base sign.
- Panel: Upgrades > Rebirth tab, with the exact reset/keep list and a confirm dialog.
- After a rebirth the player re-lifts (about 4 minutes total, faster each time) and re-buys cheap upgrades with the income their pets still make; the next rebirth costs 4x as much, so the long tail stretches (about 35 minutes for the 2nd, more after).

### 4.9 Pacing check

Expected timeline for an active player following the banner. "Gap" = time since the previous unlock.

| Time | Unlock | Cost | Gap |
|---|---|---|---|
| 0:22 | First hatch (Moss Turtle) | - | 0:22 |
| 0:30 | First Book claim (+100) | - | 0:08 |
| 1:10 | Nest slot 3 | 100 | 0:40 |
| 2:17 | Bog Marsh (Strength 80) | lifting | 1:07 |
| 3:30 | Carrot | 500 | 1:13 |
| 4:00 | Nozzle Lv2 | 1.5K | 0:30 |
| 4:30 | Pen 7, Pen 8 | 300, 2K | 0:30 |
| 6:00 | Nest 4 | 1K | 1:30 |
| 7:00 | Blueberries | 15K | 1:00 |
| 8:30 | Stone Weights -> lift 60 s | 50K | 1:30 |
| 9:30 | Ember Volcano | lifting | 1:00 |
| 11:00 | Nozzle Lv3, Pen 9, Nest 5 | 60K, 10K, 20K | 1:30 |
| 13:00 | Pen 10 | 50K | 2:00 |
| 15:00 | Pancakes | 1M | 2:00 |
| 19:00 | Iron Weights -> lift | 3M | 4:00 |
| 20:00 | Coral Reef | lifting | 1:00 |
| 22:00 | Nozzle Lv4, Pen 11 | 4M, 250K | 2:00 |
| 25:00 | Nest 6, Pen 12 | 500K, 1.5M | 3:00 |
| 30:00 | Strawberry | 60M | 5:00 |
| 38:00 | Gold Weights -> lift | 200M | 8:00 |
| 40:00 | Starfield | lifting | 2:00 |
| 43:00 | Nozzle Lv5 | 300M | 3:00 |
| 48:00 | Pen 13, Pen 14, Nest 7 | 10M, 80M, 20M | 5:00 |
| 55:00 | Star Cookie | 3B | 7:00 |
| 70:00 | First rebirth | 10B | 15:00 |

Gaps are 0:10-1:30 in the first 10 minutes, 2-5 minutes until 30 minutes, 5-15 minutes after. Book claims (15 of them, plus Golden Hour) fill the longer gaps with smaller wins.

**Idling cannot skip content:**
- Zones need Strength, and Strength only comes from accepted Lift reps (input every 0.6-1.1 s, random timing, per-minute and 10-minute caps). Coins cannot buy Strength.
- Creatures (and Book entries) only come from throws plus active washing; the server requires facing chunks and caps damage per second.
- An idle player in the Marsh with 440/s earns about 530K in 20 minutes (Roblox's own idle kick time). That buys Stone Weights and the Marsh upgrades but not the Volcano: they still need 60 s of lifting and new eggs.
- No offline earnings. Income stops when the player leaves.
- Autoclicker on Lift: about 25% hit rate on a fixed interval, and perfect-ratio cap. Autoclicker on the Washer: chunks facing away take no damage, so holding still at the centre washes about one third of the egg and stalls.

---

## 5. Onboarding

No tutorial screens. Each step has a banner (top-centre, one line), an arrow trail target, and a HUD element that appears at that step. Step index is saved (`tutorialStep`); returning players resume. Players who complete step 16 never see these banners again; the banner then shows the "next goal" (last row).

Arrow trail: white chevrons with a cyan neon outline, 1 stud apart, 2 x 1 studs, on the ground, path computed with `PathfindingService` from the HumanoidRootPart to the target every 0.5 s, hidden when the player is within 4 studs of the target. A chevron 3 studs above the target bobs. Chevrons fade near the camera so they are not hidden behind the character.

| # | Banner text | Trail leads to | HUD element that appears | Completes when |
|---|---|---|---|---|
| 1 | Walk to the ledge! | Ledge pad | (banner only) | Player on the Ledge |
| 2 | Hold to throw food to Mama Hen! | none | Phone: THROW button. PC: "Hold click to throw" chip | First throw released |
| 3 | Watch Mama Hen eat! | none (throw cam) | - | Egg lands in nest |
| 4 | Wash your muddy egg! | Washer ring | - | Wash started |
| 5 | Spray all the mud off! | none | Wash progress bar + aim hint chip | Wash done |
| 6 | It's hatching... | none | - | Reveal ends |
| 7 | New creature! Claim it in your Book | none (red dot + pointer hand on the Book button) | Coins counter; Book button | First Book claim |
| 8 | Throw 2 more eggs! | Ledge pad | Nest chip "Nest 0/2" | 2 more throws released |
| 9 | Wash your eggs! | Washer ring | - | Both eggs hatched |
| 10 | Buy a bigger nest! (shown when Coins >= 100; before that "Earn 100 coins: your pets are working!") | Nest sign | Upgrades button (red dot) | Nest slot 3 bought |
| 11 | Throw farther: train at the Lift Bench! | Lift Bench | Strength chip | Lift started |
| 12 | Lift until Strength 80! | none | Lift HUD | Strength >= 80 |
| 13 | Throw into the Bog Marsh! | Ledge pad | Meter shows the Marsh band | Egg from the Marsh hatched |
| 14 | Claim your new creature! | none (red dot on Book) | - | Book claim |
| 15 | Buy Carrots for better eggs! | Food Stall sign | - | Carrot bought |
| 16 | You're a Sanctuary Keeper! Keep hatching! (3 s) | none | Pets button, Daily Gift button, Golden Hour timer, Settings button | 3 s elapsed |
| - | After 16: "Next: <next unlock> (<cost or Strength>)" e.g. "Next: Stone Weights (50K) to reach Ember Volcano" | none, unless the player taps the banner: then a trail to the relevant sign or station for 15 s | Shop button appears at 10 minutes total playtime | - |

Gated areas say why: walking onto the Lift Bench before step 11 shows "Wash your first egg first!"; a locked nest cup shows a padlock and "Buy in Upgrades".

---

## 6. Collection Book and Golden Hour

### 6.1 Collection Book

- 5 pages (one per zone), 3 entries each. Undiscovered: black silhouette, "???", rarity word, and "Found in: Ember Volcano". Discovered: ViewportFrame of the creature (slow spin), name, rarity word, income, and 3 mutation badges (Shiny, Golden, Rainbow) that light up when that mutation has been hatched.
- Each page lists the odds for the player's current food (table 4.5).
- Each first discovery is claimable once for 30 x income (table 4.4). Claim: CLAIM button (green, pulsing), coin burst to the counter (section 8).
- Completing a page's 3 entries gives +5% coins permanently (shown as a gold page border and "+5%" ribbon). 5 pages = +25%.
- HUD Book button shows a red badge with the number of unclaimed entries.
- Server validates: species is in the player's `book` as found and not claimed; then marks claimed and pays.

### 6.2 Golden Hour (server-wide event on the day/night cycle)

Replaces `ServerScriptService.DayNightCycle`. The cycle is 10 minutes: 8 minutes day, 2 minutes Golden Hour.

- **Lighting:** day = bright, `Ambient` never below (120, 120, 130). Golden Hour = warm sunset (`ClockTime` 17.8, orange `ColorCorrection` tint (255, 230, 200), `Bloom` up slightly). The server only sets `ReplicatedStorage.GameClock` attributes (`phase`, `phaseEndsAt`); clients tween lighting locally over 3 s. No 20x per second server updates.
- **Effect during Golden Hour:** slot-C weight x2 and mutation odds x3 for all throws released during it (odds in table 4.5). Mama Hens wear a gold glow.
- **Announcements:** 10 s before: toast to all "Golden Hour in 10 s!" with a countdown. At start: full-width golden banner sweep (1.2 s) "GOLDEN HOUR! Rare eggs x2 for 2 minutes!", chime. During: server-wide toast for every Legendary, Mythic or Secret hatch: "Mia hatched a MYTHIC Pearl Whale!" (rarity word in colour). Outside Golden Hour only Mythic and Secret hatches are announced.
- **Timer chip:** sun icon "Golden Hour in 4:12" during the day, gold sun "Golden Hour 1:36 left" during it; turns red under 10 s.
- **Paid trigger:** the "Golden Hour for everyone" product (section 9) starts one immediately (not during one, and at most once per 20 minutes per server); the cycle then restarts from day.

---

## 7. HUD and screens

### 7.1 UI kit and style

Per `MAIN_PLAN.md` phase 3 and `reference-bobux-gang.md` section 7: `src/client/UI/Theme.luau` (role-named colours and fonts) and `src/client/UI/Kit.luau` (`frame`, `text`, `button`, `iconButton`, `shell`, `toast`, press-scale on every button, one panel open at a time behind a 40% shade + blur 18).

| Role | Colour |
|---|---|
| `money` / positive / affordable | `#2BD45B` text, `#1C8F3C` stroke |
| `primary` (main action button) | `#2B8000` face, `#1C5700` base strip |
| `reward` (coins, gold) | `#FFC800` |
| `info` | `#1CB0F6` |
| `danger` / unaffordable / close | `#FF4B4B` |
| `premium` (Robux) | `#CE82FF` |
| `panel` body | `#2A2438` with 4 px `#14111C` outline |
| `paper` text | `#FFFFFF` with 3 px dark stroke |

Fonts: `Enum.Font.FredokaOne` for titles, numbers, banner and buttons; `Builder Sans Bold` (FontFace) for body text. 5 text sizes at 1080p reference: 56, 40, 28, 20, 16, scaled by `UIScale = viewportHeight / 1080` clamped 0.55-1.2. Touch targets >= 56 px after scaling on phone. Corner radius 16 (buttons), 24 (panels).

### 7.2 Always-on HUD

`ScreenGui.ScreenInsets = CoreUISafeInsets`. Positions are anchor points in scale.

| Element | PC position | Phone position | Appears | Notes / art |
|---|---|---|---|---|
| Objective banner | top-centre, y 0.10 | top-centre, y 0.12 | step 1 | white Fredoka One, stroke, no panel; tap = re-show trail |
| Toasts | top-centre under banner, up to 3 | same, up to 2 | always | green gain / red error / gold announce; 3 s; serial guard |
| Coins counter | bottom-left (0.02, 0.95) | top-left (0.02, 0.10) | step 7 | `Currency\Coin\256px\Golden Coin 1st 256px.png`; rolling number; small `+/s` line under it; "+" badge after Shop unlocks |
| Nest chip | right of Coins | under Coins | step 8 | `Item\Egg\256px\Egg 1st 256px.png`, "Nest 2/3", red when full |
| Strength chip | right of Nest chip | under Nest chip | step 11 | **missing art: dumbbell icon** (fallback `Main\Lighting\256px\Blue Lighting 1st 256px.png`) |
| Left menu column: Book, Upgrades, Pets, Daily, Shop, Settings | left edge, centred vertically, 150 x 56 pills with icon overhanging left | left edge, y 0.25-0.60, 56 x 56 square tiles, icon only (label as tooltip) | Book 7, Upgrades 10, Pets 16, Daily 16, Settings 16, Shop at 10 min | icons: Book `Item\Book\...` (1st 256), Upgrades `Main\Upgrade\256px\Golden Upgrade 1st 256px.png`, Pets `Main\Paw\256px\Golden Paw 1st 256px.png`, Daily `Item\Gift\256px\Green Gift 1st 256px.png`, Shop `Main\Shopping Bag\256px\Golden Shopping Bag 1st 256px.png`, Settings `Main\Settings\256px\Settings 1 1st 256px.png`. New-button red dot + pointer hand (`UI\Cursor\...`) |
| Golden Hour timer | bottom-right (0.98, 0.97) | top-right (0.98, 0.10) | step 16 | **missing: sun icon** (fallback `Item\Clock\256px\Clock 1st 256px.png`) |
| THROW button | not shown (hold click / Space) | bottom-right, 130 px circle, above the jump button | on Ledge | yellow face, apple icon of current food |
| Power meter | bottom-centre, y 0.80, 50% width | bottom-centre, y 0.72, 80% width (clear of jump and thumbstick) | while charging | zone bands, needle, SWEET band green |
| Eat Cards | bottom-centre above meter | same, smaller | after compact throws | ViewportFrame |
| Reveal card (compact) | top-centre y 0.22 | same | compact hatches | rarity colour frame |

PC key hints only when `UserInputService.KeyboardEnabled`; gamepad hints when the last input was a gamepad.

### 7.3 Contextual HUDs

| HUD | Contents | Layout |
|---|---|---|
| Wash HUD | progress bar (top-centre, replaces banner), zone name, Nozzle chip with "too weak" upgrade price, X button top-right | Phone: bar 80% width; X 56 px |
| Lift HUD | ring centre, Strength bar "320 / 800" under it, dumbbell name, X | Phone: tap anywhere outside X |
| Full reveal | rarity word (56), name (40), mutation word, "+X/s" (28); "Tap to continue" after 1.5 s | centred above the pet in world-space Billboard plus screen card on phone |

### 7.4 Panels (one shell, coloured title bar, red X top-right)

| Panel | Title colour | Contents |
|---|---|---|
| Upgrades | green | Tabs: Food, Weights, Nest & Pen, Washer, Rebirth (Rebirth tab appears at Starfield). Each row: icon, name, effect ("Luck x4"), price button green/red by affordability (updates live), progress bar to the price when red. Owned rows show a check. |
| Pets | orange | Pen grid (6-16 spots) and Storage grid (60). Card: ViewportFrame, name, rarity frame colour, income. Buttons: Equip Best (primary), card tap -> Release (with confirm). |
| Book | cyan | 5 page tabs, 3 entries each (section 6.1), CLAIM buttons, page bonus ribbon. |
| Daily Gift | green | 7-day row, today's reward big, CLAIM. |
| Shop (Robux) | purple | Passes grid, Coin packs, Lucky Snack, Golden Hour for everyone. Each card states exactly what it does. |
| Settings | grey | Music on/off, SFX on/off, Follow every throw (camera), Reduced motion (also on when `GuiService.ReducedMotionEnabled`). Icons `Main\Music ON`/`Music OFF`, `Main\Sound ON`/`Sound OFF`. |
| Confirm dialog | red title | Used for Release and Rebirth. |

Phone: panels take 94% width x 86% height, one column; grids 3 per row. PC: 900 x 620 at 1080p, grids 5 per row.

Panel art: `ui-kits\sungraphica-casual-game-interface-kit\...\1080p\Upgrade\Header.png` and `Shop\Header.png` (title ribbons), `Upgrade\Footer button green.png` / `Footer button red.png` (price buttons), `Upgrade\Slider.png` + `Slider Filler.png` (progress bars), `Items\Frame copy 2.png` (item cards), `Reward\Image Frame.png` (reveal card frame). All 9-sliced by hand (`ScaleType = Slice`). Close button: `UI\Close Button\256px\Close Button 1st 256px.png`.

### 7.5 Missing art (to make or source)

1. Mama Hen rig with 5 hats; idle, run, peck, lay animations.
2. 10 new creature models (table 4.4) and the 5 existing templates rebuilt as meshes (under 4k tris each, per `3D_ARTIST_GUIDE.md`).
3. Egg meshes: 5 zone crusts + clean shell + 3 crack stages + shell shards.
4. Food 3D models (6) or reuse icons as billboards for the slice.
5. Rarity frames and backgrounds (7 colours) and a Secret rainbow frame.
6. Icons: dumbbell (Strength), sun / gold sun (Golden Hour), nozzle, nest, Rebirth star (the Gvesster `Main\Rebirth and Auto Open` set may cover Rebirth: check), Mama Hen face for the Odds Board.
7. VFX textures: sparkle, mud splat, water spray, confetti, light rays, crack overlay.
8. Button states (pressed, disabled) for the casual kit buttons.
9. Full sound set (section 8 list): none exists.
10. Game icon, 3 thumbnails, pass and product art.
11. Lift curl Animation and throw Animation (uploaded Animation assets).

---

## 8. Juice list

Respect Reduced motion: no camera shake, no FOV punch, particles halved, tweens kept.

| Moment | Tween | Particles | Sound | Camera | Duration |
|---|---|---|---|---|---|
| Charge | meter needle; THROW button scales 1 -> 0.92 while held | food glows in hand | rising whoosh, pitch follows needle | FOV 70 -> 66 | while held |
| Throw | release label pops (scale 0.6 -> 1, Back), SWEET label gold with 8-star burst | food trail (food colour) | whoosh; SWEET adds a ding | FOV snaps back to 70 over 0.2 s; throw cam follow (Quint out) | 1.2 s |
| Eat | Mama run, peck bob x3, squash on lay | crumbs (food colour), 3 hearts | "nom" x3, cluck | throw cam holds a 3/4 view | 1.5 s |
| Egg lands | squash Y 0.7 for 0.08 s, Back to 1 in 0.25 s | dust puff 12 particles | thunk | shake 0.15 s, 0.3 studs | 0.35 s |
| Wash tick (chunk pop) | chunk shrinks 1 -> 0.6, then 0 in 0.1 s; "+10%" floats to the bar | mud splat 10 particles in zone colour | splat, pitch +4% per chunk | none | 0.4 s |
| Wash done | shine sweep (UIGradient over a highlight), egg scale 1 -> 1.15 -> 1, "CLEAN!" pop | 20 sparkles, water droplets | bright chime | ease out of wash view only if nest is empty | 0.8 s |
| Hatch roll | egg wobble ±12 degrees, growing; crack decals at 1/2/3 s; slot card ticks | small chips at each crack | crack x3, rising hum, tick per name | slow push-in 10% | 3 s + 2 s |
| Rarity reveal | shell shards fly out; rarity word scale 0 -> 1.2 -> 1 (Back); background rays rotate (Rare+) | burst in rarity colour; Legendary+ adds confetti 1 s; Secret adds rainbow ring | fanfare tier by rarity (3 tiers: common, rare, legendary+) | Rare+: FOV punch 70 -> 64 -> 70; hold on pet 1.5 s | 1.5-2.5 s |
| Income tick | "+X" floats 3 studs up, fades, 0.9 s; Coins counter rolls (number tween 0.4 s) | none | none (too frequent); soft coin tick when the counter crosses a K/M/B boundary | none | 0.9 s |
| Coin burst (claims, gifts) | 12-20 coin icons spawn at the source, curve to the Coins counter in 0.8 s with stagger 0.03 s; counter scale 1 -> 1.15 -> 1 on each arrival | none | coin jingle | none | 1.0 s |
| Purchase | price button press-scale; row flashes green; the world object upgrades (new nest cup pops in with Back) | 12 green sparkles on the row | "ka-ching" | none | 0.5 s |
| Cannot afford | price button shakes ±6 px x3 in 0.25 s, stays red; toast "Need 1.2K more coins" | none | soft "bonk" | none | 0.25 s |
| Nest full | THROW button shakes red; Nest chip pulses red twice | none | bonk | none | 0.4 s |
| New Book entry | Book button bounces (scale 1 -> 1.25 -> 1, x2), red badge +1, pointer hand appears for the first 3 | 6 stars around the button | page-flip + sparkle | none | 1.2 s |
| Book claim | entry card silhouette fades to the creature (0.4 s), then coin burst | stars | sparkle + jingle | none | 1.4 s |
| Zone unlocked | stamp "VOLCANO UNLOCKED!" drops from y -0.2 (Back), holds 1.2 s | confetti | big fanfare | none | 2 s |
| Golden Hour start | gold banner sweeps left to right 1.2 s | gold motes in the sky for 2 min | chime + light music layer | none | 1.2 s |

Sound set to source (Roblox Creator Store audio, licensed for use; uploaded under the group): click, whoosh-charge, whoosh-throw, ding, nom, cluck, thunk, water hiss loop, splat, chime, crack, hum, tick, 3 fanfares, coin jingle, coin tick, ka-ching, bonk, page flip, stamp fanfare, 1 calm music loop, 1 Golden Hour music layer. All 3D sounds use `RollOffMaxDistance` 60 (fixes server-wide bleed); UI sounds play locally in `SoundService`.

---

## 9. Monetisation

Principles: never block progress, never show a Robux price next to a coin price on upgrade rows, never prompt a purchase the player did not tap, no paid random items. Products that change odds show the before/after odds table on their card, and are hidden when `PolicyService:GetPolicyInfoForPlayerAsync().ArePaidRandomItemsRestricted` is true. All purchases go through one `ProcessReceipt` with purchase-id idempotency saved in the profile before granting.

**Game passes**

| Pass | Effect | Price |
|---|---|---|
| x2 Coins | Pen income x2 | 399 R$ |
| Lucky Food | Food luck L x2 (odds shown) | 299 R$ |
| Fast Wash | Nozzle DPS x2 | 149 R$ |
| Big Pen | +4 pen slots (max 20) | 249 R$ |
| VIP | Gold name tag and chat tag, gold Mama Hen hats on your plot, +10% coins | 199 R$ |

**Developer products**

| Product | Effect | Price |
|---|---|---|
| Coin Pouch | 10 minutes of current pen income (min 500) | 25 R$ |
| Coin Bag | 1 hour of current pen income (min 3K) | 99 R$ |
| Coin Chest | 4 hours of current pen income (min 12K) | 299 R$ |
| Lucky Snack | Next 10 throws: food luck x3 (odds shown) | 49 R$ |
| Golden Hour for everyone | Starts Golden Hour for the whole server now; announced "Filip started Golden Hour for everyone!" | 199 R$ |

**Where they surface:** the Shop panel (button appears at 10 minutes playtime); the "+" badge on the Coins counter opens the Coin tab; the Washer's "Nozzle too weak" chip has a small purple Fast Wash tile beside the coin price only in the Washer HUD (not in the Upgrades rows); the Golden Hour timer chip has a small "Start now" tile during the day. No pop-ups.

---

## 10. Retention

- **Daily Gift (7-day loop):** day 1: 5 min of income (min 200); 2: 10 min; 3: Lucky Snack x1 (free); 4: 20 min; 5: 30 min; 6: 45 min; 7: next hatch guaranteed Shiny (a free mutation, not paid). Server uses UTC days. Missing one day keeps the streak; missing two resets to day 1. The Daily button shows a red dot when claimable.
- **Session gifts:** at 5, 15, 30 and 60 minutes of play in a session, a gift ready on the Daily button: 5, 10, 20, 40 minutes of income.
- **Golden Hour** every 10 minutes (section 6.2) is the in-session appointment.
- **Book completion** with page bonuses is the long goal; mutation badges are the very long goal.
- **Social:** server announcements of rare hatches; big base signs with income and rebirth stars; other players' pens visible; Friends bonus +10% coins per friend in the server (max +30%), shown as a chip "Friends +20%"; one in-world leaderboard board at the plaza (Top income/s, Most species found; refreshed every 60 s from in-server data, global OrderedDataStore later). Trading and gifting are cut.
- **What's new pop-up** (BG pattern) for content updates.

---

## 11. Build order

Prerequisite for all: `MAIN_PLAN.md` Phase 0 done (repo matches Studio, wash script fixed, tooling, exploits closed). Each package is sized for one agent. "Accept" is the test the playtest agent runs; record PASS / FAIL / NOT RUN.

### Vertical slice (proves the new loop: Meadow and Marsh only)

| # | Package | Depends on | Scope | Accept |
|---|---|---|---|---|
| VS-1 | Economy module | Phase 0 | `src/shared/Economy.luau` with every table in section 4 and pure functions `eggOdds`, `rollEgg`, `throwMultiplier`, `zoneForDistance`, `washTimeEstimate`, `incomePerSecond`, `upgradeCost`; assert test in `tests/` run through Studio MCP. | Test prints PASS; odds match table 4.5 to 0.1%; `throwMultiplier(0.9) == 1.25`. |
| VS-2 | Save schema v7 | VS-1 | Pure transform module: fields `coins, strength, foodTier, dumbbellTier, nestSlots, penSlots, nozzleLevel, rebirths, tutorialStep, pets[], nest[], book{}, daily{}, settings{}, receipts{}`, `sanitize()`, session lock, failed writes retried, nest eggs saved. | Assert test for sanitize and transform; leave with 2 eggs in nest, rejoin: eggs still there. |
| VS-3 | Compact plot (map) | Phase 0 | Rebuild one plot (then copy to 6) on the canyon rim per section 3.0; tag stations `FLStation`; Meadow and Marsh landing floors. Studio-only; document in the repo. | Walk Ledge -> Washer -> Hatch Pad -> Ledge in under 3 s total. |
| VS-4 | UI kit core | Phase 0 | `Theme.luau`, `Kit.luau` (button with press-scale, toast, banner, shell, `layout()` compact switch), Coins counter with rolling number and coin burst. | Phone 375 x 667 and PC 1920 x 1080 screenshots: nothing overflows; toast shows server message. |
| VS-5 | Egg pipeline (server) | VS-1, VS-2, VS-3 | `EggService`: StartCharge / ReleaseThrow, egg state machine Flight -> Nest -> Washing -> Hatching -> Pet, nest capacity, `HatchResult` push, pen placement and swap, income tick. Remotes per plan handler shape. | Script-driven test: 3 throws accepted, 4th rejected "Nest full"; release without StartCharge rejected; species never in any client-bound payload before hatch. |
| VS-6 | Throw, Mama Hen, egg flight (client) | VS-4, VS-5 | Meter with zone bands, throw cam rule, Eat Card, client-local Mama Hen (placeholder part rig is fine), egg arc and landing juice. | First throw to egg-in-nest in 4.0 s ±0.2; Eat Card shows from throw 4. |
| VS-7 | Wash v3 | VS-5 | Server-owned chunk HP, facing check, DPS cap, `SprayHits` unreliable event, ChunkPopped/WashDone, auto-load next egg, Nozzle Lv1-2 only. Delete the old 2D WashModal code. | Meadow egg at Lv1 washes in 5-9 s; firing `SprayHits` at 60 Hz washes no faster than 10 Hz; spraying only the egg's back stalls progress. |
| VS-8 | Hatch reveal and pen earners | VS-5, VS-6 | Full and compact reveal, slot roll, rarity colours, pet jump to pen, wander, `+X/s` floaters. | First hatch is Moss Turtle with "UNCOMMON" in green; floaters every 1 s over each pen pet. |
| VS-9 | Lift Bench | VS-5 | Ring minigame, server rep validation, curl Animation asset, Twig and Stone weights. | Reaching Strength 80 takes 20-40 s of active play; a 1 Hz autoclicker gains under 40% of an active player's rate. |
| VS-10 | Onboarding steps 1-15 | VS-6, VS-7, VS-8, VS-9 | Banner, arrow trail, progressive HUD reveal, saved step, minimal Upgrades panel (Nest slot 3, Carrot, Nozzle Lv2 only). | Fresh account: first reward under 60 s; Marsh egg hatched under 3:30; no HUD button visible before its step. |
| VS-11 | Slice playtest | all VS | Opus agent plays 3 fresh sessions on PC and phone emulation, times every target. | Report with PASS/FAIL per `MAIN_PLAN.md` target; owner decides go/no-go. |

### After the slice

| # | Package | Depends on | Accept |
|---|---|---|---|
| P-1 | Full Upgrades panel + world signs (all tabs, affordability colours, live updates) | VS-10 | Every row in section 4 buyable; price turns red/green within 1 s of coins changing. |
| P-2 | Zones 3-5, all 15 creatures (placeholder rigs ok), Mama tints, canyon floors renamed | VS-8, P-1 | Throws at each Strength gate land in the right zone; all 15 species obtainable in a debug run. |
| P-3 | Collection Book | P-2 | Claims pay once; page bonus applied; silhouettes for unfound. |
| P-4 | Pets panel (pen/storage, Equip Best, Release with confirm) | VS-8 | Release asks confirm; cannot release last pet; Equip Best is optimal. |
| P-5 | Golden Hour + announcements, remove DayNightCycle | P-2 | Ambient never below (120,120,130); odds double during event (server log); announcement reaches a second client. |
| P-6 | Rebirth | P-1, P-2 | Reset/keep list exactly as 4.8; cost scales x4. |
| P-7 | Onboarding step 16 + goal banner + full progressive HUD | P-1, P-3, P-4 | "Next:" banner always names a real unlock. |
| P-8 | Juice and sound pass (section 8 in full) | VS slice | Every row in section 8 visible in a capture; no sound heard beyond 60 studs. |
| P-9 | Art: Mama Hen, eggs, 15 creature meshes, VFX textures | P-2 | 0 primitive-part pets left; tri budget met. |
| P-10 | Monetisation (passes, products, ProcessReceipt, PolicyService) | P-1, P-5 | Test purchases in Studio grant once even when ProcessReceipt is called twice; odds-changing items hidden under the restricted policy. |
| P-11 | Daily Gift, session gifts, friends bonus, leaderboard board | P-3 | Streak rules as section 10 with a mocked clock in the assert test. |
| P-12 | Settings panel and reduced motion | VS-4 | Settings persist across rejoin; reduced motion removes shake. |
| P-13 | Stats and live flags (BG `stats` + `liveFlags` port) | Phase 0 | Hatch counts per rarity visible in the stats store. |
| P-14 | Phone and console layout QA at 1280x720, 1920x1080, 360x640, 320x568, 640x360 | P-1 to P-7 | Screenshot set, no overflow, all targets >= 44 px. |

---

## 12. Open questions for the owner

1. Wipe saves at v3 launch (economy numbers change), or convert old pets to the new species?
2. Is "Mama Hen" (one rig, five tints) fine as the eater, or do you want a different creature per zone?
3. Max players per server: keep 6 plots?
4. Can we use Roblox Creator Store audio, or do you have a sound budget?
5. Are you OK cutting Auto-Thrower and Auto-Washer (GDD top sellers) for fairness?
6. Do you have a Roblox group (for audio ownership and a group-join reward)?
