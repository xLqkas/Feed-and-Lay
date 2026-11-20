# Task for Gemini (Antigravity): bring the repo in line with the V3 game (files only)

Owner: Gemini. It edits FILES IN THE REPO ONLY. It must NOT edit, save or publish the Studio place (OpenCode is editing UI there right now).
Rules: no commit, no push. Report a git diff summary at the end. If you do not have access to Studio, stop at "Blocked" and say so; do not guess file contents.

## Why
The repo `src/` still holds the old V1 scripts (MainGameServer, EggSanctuaryClient, EggRestoration3D, PetShowcaseAnimator). Those were deleted from the live place. The real game (V3) exists only inside the Studio place, so there is no git history or backup for it, and agents cannot work on it as files.

## Do
1. READ-ONLY on the place: export the V3 SERVER and SHARED scripts to files under `src/`:
   - ServerScriptService.EggSanctuaryServer.V3.* (Main, SaveStore, SaveSchema, EggService, EggRules, LiftRules, and the rest)
   - ReplicatedStorage.Modules.* (Economy, GameConfig and the rest)
   - Do NOT export StarterPlayer UI / Loop scripts. OpenCode is changing them right now and a copy would be stale.
   - Keep the exact script names and nesting; use `.server.luau` / `.luau` / `.client.luau` naming Rojo expects.
2. Update `default.project.json` so Rojo maps the new files. Remove the mappings for the four deleted legacy scripts. Do not add a mapping for anything you did not export.
3. Move the four legacy files out of the live `src/` mapping into `legacy/` (keep them, do not delete). Update the header comments in V3.Main (lines 2-3) that claim they are mapped with Enabled=false, only in the exported repo copy.
4. Rewrite README.md to describe V3 as it actually is (flow: throw, wash, hatch, nest/pen, lift station, save/lock). Read docs/phase0_decisions.md and the exported scripts first. Mark anything you could not confirm as "unverified" instead of inventing it.
5. Add a short `docs/ARCHITECTURE.md`: module list with one line each, the remotes in ReplicatedStorage.RemotesV3, and which scripts own saving.
6. Tests: add `tests/` specs for SaveSchema.load with old v5, v6 and v7 data and a corrupted record, and for EggRules pure functions. Use the existing test style in tests/test_game_math.luau. If no runner is installed, write them to run under the existing pattern and say so.

7. STATUS AUDIT (read-only, this is the most important deliverable): write `docs/v3_status.md`. Compare what V3 actually contains against `docs/phase0_decisions.md` (Steps 1-4: hub with ChefStall and ODDS board, runway lane, dumbbell/lift, egg growth) and the GDD (food tiers T1-T8, 5 biomes, shiny/mutations, rebirth, gamepasses). For each item write DONE / PARTIAL / MISSING, the script and line that proves it, and a rough size (S/M/L). Only mark DONE if you read the code. End with a proposed build order for a complete playable game, smallest steps first.

## Do NOT
- Touch any UI, art or economy values.
- Change game logic while exporting. The export must be byte-for-byte the script source from the place.
- Edit GDD files. The GDD is out of date (it mentions ProfileService; the game uses plain DataStore per phase0 decision 4). List the mismatches you find in your report instead.

## Done when
- `git status` shows only the new/changed repo files above.
- Every exported file matches the place source (state how you checked).
- Report: files added/changed, anything blocked, GDD-vs-V3 mismatches, tests written and whether they ran.
