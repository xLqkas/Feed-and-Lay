# Egg Sanctuary (Feed and Lay) — V3 Architecture

This document outlines the architecture, script responsibilities, network interface, and save system of the V3 codebase.

---

## 1. Module Inventory

### Server Scripts (`src/server/V3/`)
* **`Main.server.luau`**: Server entry point that manages player join/leave lifecycle, station tagging/caching, network remotes, autosave loops, and `BindToClose` shutdown.
* **`SaveStore.luau`**: Thin DataStore wrapper implementing session locking (300s lease, 60s refresh), exponential backoff retries, and legacy v5/v6 migration reads.
* **`SaveSchema.luau`**: Pure data schema (v7), field-level sanitizer, legacy conversion logic, serialization, and lock state verification without Roblox service dependencies.
* **`EggService.luau`**: Remote function dispatcher with player session validation, rate-limiting cooldowns, busy flags, and action dispatch to pure game rules.
* **`EggRules.luau`**: Pure logic for throw charging, sweet spot multiplier calculation, egg nest queues, turntable 3D chunk washing, and hatch reveals.
* **`LiftRules.luau`**: Pure rhythm and timing logic for dumbbell strength training, server ring schedules, and hit windows.
* **`Onboarding.luau`**: Pure state-driven tutorial progression (steps 1–16) evaluating completed milestones directly from saved data.

### Shared Modules (`src/shared/`)
* **`Economy.luau`**: Authoritative game design constants, biome zones, creature tables, food luck multipliers, nozzle upgrades, and pet income formulas.
* **`Goals.luau`**: Pure progression evaluator determining dynamic next-goal recommendations and creature discovery targets for HUD display.
* **`GameConfig.luau`**: Centralized configuration constants and math formulas retained for shared client/server compatibility.
* **`SoundHelper.luau`**: Utility for positional sound playback and automatic cleanup.

---

## 2. Network Remotes (`ReplicatedStorage.RemotesV3`)

All V3 communication takes place under `ReplicatedStorage.RemotesV3` to prevent collision with legacy remotes:

### RemoteEvents
| Remote Name | Direction | Purpose |
| :--- | :---: | :--- |
| `ChunkPopped` | S $\rightarrow$ C | Fired when a 3D crust segment is completely broken off. |
| `ChunkHit` | S $\rightarrow$ C | Replicates particle impacts and damage feedback on egg crust chunks. |
| `WashDone` | S $\rightarrow$ C | Signals that an egg has reached 100% cleanliness. |
| `HatchResult` | S $\rightarrow$ C | Announces hatched pet details upon reveal completion. |
| `WashLoaded` | S $\rightarrow$ C | Mounts an egg onto the wash basin turntable. |
| `WashStopped` | S $\rightarrow$ C | Notifies client that washing has ended or was interrupted. |

### UnreliableRemoteEvents
| Remote Name | Direction | Purpose |
| :--- | :---: | :--- |
| `SprayHits` | C $\rightarrow$ S | High-frequency spray particle hit stream from client pressure wand (rate-limited and validated). |

### RemoteFunctions
| Remote Name | Client Arguments | Purpose |
| :--- | :--- | :--- |
| `GetState` | *none* | Fetches initial player save data, active egg state, and assigned plot ID. |
| `StartCharge` | *none* | Validates ledge proximity and records server charge start timestamp. |
| `ReleaseThrow` | *clientReportedDuration* | Validates charge duration, rolls distance/rarity/mutations, and launches egg down canyon. |
| `StartWash` | `eggId` | Validates washer proximity and loads selected nest egg onto turntable. |
| `StopWash` | *none* | Cancels active turntable wash session. |
| `StartLift` | *none* | Validates dumbbell proximity and initiates gym lift session. |
| `Lift` | `tapTime` | Evaluates player tap against server ring schedule for strength gains. |
| `StopLift` | *none* | Exits dumbbell workout. |
| `Buy` | `track` (`"Food"`, `"Dumbbell"`, `"Nest"`, `"Nozzle"`) | Deducts coins and purchases next tier in requested upgrade track. |
| `ClaimBook` | `speciesName` | Claims index discovery reward for newly unlocked creatures. |

---

## 3. Save Architecture & Ownership

Persistence is divided strictly by responsibility:
1. **`SaveSchema` (Data Ownership & Sanitation)**:
   - Defines the v7 canonical schema (`Data`).
   - Implements `SaveSchema.load(v7, legacy, legacyVersion)` which cleanly migrates old v5 and v6 records into v7 while resetting legacy currency to maintain game balance.
   - Implements `SaveSchema.sanitize()` to ensure malformed types, `NaN`, or corrupted records are safely clamped to defaults without data loss.
2. **`SaveStore` (Storage Authority & Session Locking)**:
   - The only code that touches `DataStoreService`.
   - Uses `UpdateAsync` to maintain an active server lease lock in the record (`lock.jobId`, `lock.time`).
   - Rejects writes if another live server holds the lease, preventing multi-server overwrites and pet duplication.
   - Stale locks expire automatically after 300 seconds (5 minutes).
3. **`Main` (Lifecycle Orchestration)**:
   - On `PlayerAdded`: triggers `SaveStore.load()` and registers player with `EggService`. Kicks if save fails or session is locked elsewhere.
   - Periodic Autosave: worker routine saves modified player states every 60 seconds.
   - On `PlayerRemoving`: performs final `SaveStore.save()` and clears active server lock.
   - On `game:BindToClose`: synchronously flushes all active player saves during server shutdown.
