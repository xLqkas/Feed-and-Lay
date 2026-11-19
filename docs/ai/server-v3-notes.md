# Server v3 notes (VS-2 save, VS-5 egg pipeline)

Written 2026-11-19. Code: `src/server/v3/`. Tests: `tests/SaveSchema.spec.luau`, `tests/EggService.spec.luau` (run with `lune run <file>` from the repo root). Nothing here has been run in Studio yet.

## What was switched

- `default.project.json`: `ServerScriptService.EggSanctuaryServer.MainGameServer` is still mapped to `src/server/MainGameServer.server.luau` (file unchanged) but with `"$properties": { "Disabled": true }`. New folder `ServerScriptService.EggSanctuaryServer.V3` maps `src/server/v3` (script `Main` plus modules `SaveSchema`, `SaveStore`, `EggRules`, `EggService`).
- To restore the old server: delete the `$properties` block and the `V3` entry. The live Studio place is unchanged until someone syncs with Rojo.
- Old remotes (`ReplicatedStorage.Remotes`: ThrowFood, CleanEgg, HatchEgg, ManagePet, ...) are no longer created. The old client scripts (`EggSanctuaryClient`, `EggRestoration3D`) are still mapped and will wait forever on them until VS-6 to VS-8 replace them. The client-reported wash percentage and the 15x pet sale exist only in the disabled script.
- `src/shared/Economy.luau` gained a "Server timings" block (throw cooldown, flight time, turntable speed, facing threshold, reveal lengths, station radii).

## Map contract (VS-3)

Stations are found with `CollectionService` tag `FLStation` and attribute `Kind`. A station's plot is the nearest ancestor (or itself) with a number attribute `PlotId`, or a model named `PlayerBase_<n>`. Kinds the server uses: `Ledge` (within 6 studs horizontally, 8 vertically), `Washer` (10 studs), `Spawn` (optional: the character is placed there facing the Ledge). Players get plots 1 to 6 in join order; a 7th is kicked. If a station is missing, every request needing it is rejected, never allowed.

## Remotes

All live in `ReplicatedStorage.RemotesV3`. Times are server time (`workspace:GetServerTimeNow()`), so the client can compare them directly. Every RemoteFunction reply has `ok: boolean` and `message: string` (empty on success, a player-facing toast on failure). Shared rejections: "Still loading, one moment!" (save not loaded), "Slow down!" (cooldown), "Busy, one moment!", "Something went wrong. Try again!" (error caught by `pcall`, logged on the server).

| Remote | Kind | Client sends | Reply / payload | Cooldown |
|---|---|---|---|---|
| `GetState` | RemoteFunction | nothing | snapshot: `serverTime, coins, strength, incomePerSecond, foodTier, dumbbellTier, nozzleLevel, nestSlots, penSlots, rebirths, tutorialStep, stats{throws,hatches}, settings{}, revealUntil`, `nest[] {id, zone, state ("Flight"/"Nest"/"Washing"), sparkle, chunks, arrivesAt?}`, `pets[] {id, species, mutation, rarity, pen, income}`, `washing` (wash info, see StartWash) or nil | 0.5 s |
| `StartCharge` | RemoteFunction | nothing | `{ok, message, startedAt}`. Fails: "Walk to your ledge to throw!", "Leave the washer to throw!", "Wait a moment!" (1.5 s throw cooldown), "Nest full! Wash an egg first.", "Storage full! Release a pet first." | 0.25 s |
| `ReleaseThrow` | RemoteFunction | `clientElapsed: number?` (seconds held) | `{ok, message, eggId, zone, zoneName, landingDistance, needle (0..1), multiplier, label ("SWEET!", "Too much!", "x0.55"), sparkle, throwNumber, releasedAt, foodLandsAt, eggLaunchAt, arrivesAt, nestUsed, nestSlots}`. Never species or mutation. Fails: "Hold to charge first!", "Held too long! Try again." (over 6 s), "Bad request." (non-number or NaN), plus the StartCharge checks again. | 0.25 s |
| `StartWash` | RemoteFunction | nothing | wash info `{ok, message, eggId, zone, zoneName, sparkle, chunks, chunkHP, hp[], normals[] ({x,y,z} per chunk, egg-local), washStart, degPerSec, facingMin, nozzleLevel, maxChunksPerHit}`. Loads the oldest landed egg (or returns the one already loaded). Fails: "Step into your washer!", "Egg still flying!", "No eggs in your nest!" | 0.5 s |
| `StopWash` | RemoteFunction | nothing | `{ok, message}`. The egg goes back to the nest and keeps its chunk HP for this session only. | 0.25 s |
| `SprayHits` | UnreliableRemoteEvent, client to server | `{eggId: number, chunkIds: {number}}` | no reply. Ignored when: not the loaded egg, more ids than `maxChunksPerHit`, bad or duplicate ids, player not at the Washer, or sent within 0.05 s of the last batch. Damage per facing chunk = nozzle DPS x time since the last batch, capped at 0.15 s. | 20 Hz drop |
| `ChunkPopped` | RemoteEvent, server to client | | `(eggId, chunkId)` | |
| `WashDone` | RemoteEvent | | `(eggId)`. Sent when all chunks are popped and at least 1.5 s passed since the egg was loaded. | |
| `HatchResult` | RemoteEvent | | `{eggId, species, rarity, mutation, income, zone, mode ("full"/"compact"), revealAt, revealSeconds, firstOfSpecies, placement {where ("pen"/"storage"), swappedOutId?, swappedOutSpecies?}}`. Follows `WashDone` immediately; the pet already exists on the server. | |
| `WashLoaded` | RemoteEvent | | wash info (as StartWash) for the next egg, auto-loaded 0.6 s after a compact hatch or when a full reveal ends, while the player is still in the washer. | |

Player attributes (replicate without a remote, updated 10 times a second): `Coins` (floored), `Strength`, `IncomePerSecond`, `NestUsed`, `NestSlots`, `PlotId`.

## Rules the server owns

- **Throw:** needle position comes from the server's hold time (the client's value is used only when within 0.15 s of it); multiplier from `Economy.throwMultiplier`, distance = Strength x multiplier, zone from `Economy.zoneForDistance`, species from `Economy.rollEgg` with the current food's luck, mutation from `Economy.rollMutation`. The first egg ever (no throws, no pets) is the 6-chunk tutorial Moss Turtle in the Meadow. Eggs count against the nest from release (`state = "Flight"`, `arrivesAt = release + 4.0 s`).
- **Wash:** turntable angle = `(now - washStart) x 40` degrees about the egg's Y axis. A chunk takes damage only when its normal, rotated by that angle (`CFrame.Angles(0, angle, 0)`), has a +Z part of at least 0.2: the wash camera must sit on the turntable's local +Z side looking toward -Z. Chunks are two rings at +-25 degrees elevation (`EggRules.chunkNormal`); the client should place its chunk meshes on the `normals` it receives.
- **Hatch:** the egg leaves the nest and the pet is added the moment washing finishes (pen if a spot is free, else it swaps out the worst pen pet if better, else storage), so leaving during the reveal cannot lose it. Full reveal for hatches 1-5, Rare or better, any mutation, or a first-of-species; washing the next egg waits for it. `revealUntil` queues reveals.
- **Income:** pen pets only, `Economy.incomePerSecond`, paid by the server about once a second. No offline earnings.

## Save format (DataStore `EggSanctuary_SaveData_v7`, key `Player_<UserId>`)

```
{ version = 7, coins, strength, foodTier, dumbbellTier, nestSlots, penSlots, nozzleLevel, rebirths, tutorialStep,
  pets = { { id, species, mutation ("Normal"/"Shiny"/"Golden"/"Rainbow"), pen } },
  nest = { { id, zone, species, mutation, sparkle, chunks } },     -- eggs in flight or half washed are saved here
  book = { [species] = { found, claimed, mutations = { [name] = true } } },
  daily = { streak, lastDay }, settings = { music, sfx, followThrows, reducedMotion },
  receipts = { [purchaseId] = true }, stats = { throws, hatches }, nextId, migratedFrom?,
  lock = { jobId, t } }                                              -- session lock, added by SaveStore
```

- **Load:** take the lock with `UpdateAsync`. If another live server holds it (refreshed less than 300 s ago), wait 5 s and retry up to 6 times, then kick ("still open on another server"). If the v7 record has no `version`, read the old `EggSanctuary_SaveData_v6`, then `_v5`, once (read only) and convert: pets by name (unknown -> Meadow Bunny, logged), mutation kept, best income into the pen, `migratedFrom` set; old coins, Strength, food, slots and cleaner upgrades are dropped. Every load runs `SaveSchema.sanitize`. A record with a newer `version` is not touched (kick).
- **Failed read:** the player is kicked ("Could not load your save"); in Studio they play with an unsaved fresh profile. It never starts a fresh save that could overwrite pets.
- **Save:** autosave every 60 s, on leave (releases the lock) and on shutdown (all players in parallel, waits up to 25 s). Each write is an `UpdateAsync` retried 4 times (1, 2, 4 s backoff). If all fail, the data stays in memory and the next autosave retries; a failed final save is logged as `FINAL SAVE FAILED` with the user id (at most 60 s of progress lost). If another server has taken the lock, the write is refused and the player is kicked, because that server holds the newer data.
- The v6 and v5 stores are never written, so the old game stays restorable.

## What the client packages need to call

- **Throw (VS-6):** on the Ledge, call `StartCharge` when the hold begins; shake the THROW button and toast `message` if it fails. Animate the needle locally with `Economy.NEEDLE_HALF_CYCLE`; on release call `ReleaseThrow(secondsHeld)`. Use the reply for the release label, the zone band, throw-cam rules (`throwNumber <= 3`, `sparkle`) and timings (`foodLandsAt`, `eggLaunchAt`, `arrivesAt`, compare with `workspace:GetServerTimeNow()`). Nest chip: `NestUsed` / `NestSlots` attributes.
- **Wash (VS-7):** entering the washer ring -> `StartWash`; leaving -> `StopWash`. Spin the egg with `washStart` and `degPerSec`, place chunks on `normals`, put the camera on the turntable's +Z side. While spraying, every 0.1 s send `SprayHits {eggId, chunkIds}` with at most `maxChunksPerHit` ids. Shrink and pop chunks on `ChunkPopped`; progress = popped / chunks. `WashDone` ends the egg; `WashLoaded` brings the next one.
- **Hatch (VS-8):** on `HatchResult`, play the full or compact reveal at `revealAt` for `revealSeconds`, then jump the pet to the pen or show the storage/swap toast from `placement`.
- **Pen (VS-8):** `GetState().pets` (filter `pen`) for the models and `+income` floaters; `IncomePerSecond` and `Coins` attributes for the HUD. Call `GetState` on join and after reconnecting, not every frame.

## Not done here (later packages)

Upgrades / buying (VS-10, P-1), Lift Bench and Strength (VS-9), Release and Equip Best (P-4), Book claims (P-3; discoveries are already recorded in `book`), Golden Hour (P-5; always off), pet models in the world, rare-hatch announcements, passes and receipts (P-10).
