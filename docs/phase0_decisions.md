# Phase 0 decisions (2026-11-20)

These override `phase0_report.md` and the original brief wherever they conflict.

## Decided
1. **Washer stays on the plot.** Plot = garden yard (pen) + egg growth spots + bicep curl station (dumbbell) + EggCleaner. Only the ChefStall (food shop) and a new ODDS board move to the hub.
2. **Egg growth replaces instant hatch** (new feature, its own phase, after Phase 3):
   - After an egg is fully cleaned, the player places it on their plot, and it grows over time.
   - Grow time depends on rarity: Common is fastest (30s), Rare (120s), Epic (300s), Legendary (900s), Mythic (1800s). Codified in `Economy.luau` and `GameConfig.luau`.
   - While it grows, the egg gains weight (kg) and gets visibly bigger, like "Steal an Egg". The final weight scales the hatched pet's size (`petVisualScale`, 0.75x–1.6x) and awards a subtle income bonus (`weightIncomeMultiplier`, up to +25%).
   - The server owns the timer and the weight roll. Growth state must be saved (DataStore) so it survives a rejoin.
   - This replaces the "PUT IN GARDEN TO GROW & HATCH" copy, which currently promises a growth phase that doesn't exist.
3. **Auto-throw (future gamepass) must hold a runway lane** and goes through the same server checks as a manual throw. No gamepass code in Phases 1–3.
4. **Saves stay on plain DataStore.** No ProfileService exists. Phases 1–3: add `CurrentEgg` to the save payload and replace per-purchase saves with a dirty flag plus autosave. Session lock / ProfileStore is a separate later task.

## Order of work
- **Step 0.5 (blockers, tiny):** H1 (delete the duplicate block at `EggRestoration3D.client.luau:1056-1064`) and H4 (a throw with no `StartCharge` counts as a tap; never read the client duration). Without H1 nothing past the throw can be tested.
- **Step 1:** Phase 1 hub (ChefStall shop + new ODDS board), plus the M9 radius constants into `GameConfig`.
- **Step 2:** Phase 2 runway.
- **Step 3:** Phase 3 dumbbell. Note: the gym gives strength per rep scaling with dumbbell tier (Tier 1: +10/rep up to higher tiers), with zone cutoffs at 300/1000/2500/5000. Balance tuning confirmed in `Economy.luau`.
- **Step 4:** Egg growth (decision 2).
- **Later:** H3/H6 server-owned wash progress (the washer stays on the plot, so it's a pure authority fix), M8 session lock, M2 economy curve.

## Not covered by the report
- Agent setup: there is no project-level `.claude/` folder. The studio agents are user-global, so there's nothing project-specific to fix.
- No ODDS board or Auto-Thrower exists in code. Both would be new work, not migrations.
