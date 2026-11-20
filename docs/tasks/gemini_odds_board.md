# Task for Gemini: make the ODDS board show live drop odds (client only)

Owner: Gemini, in the open Studio place "Feed an Lay". Do NOT save, publish, commit or push.

## Do not touch (OpenCode is editing these right now)
UI.Kit, UI.Theme, UI.Icons, Loop.Menus, Loop.Hud, Loop.Pen, Loop.Hatch, Loop.Lift, Loop.Inventory, EggService, EggRules, Main, SaveSchema, SaveStore, TrainingRules, Economy. You may READ them. No server code in this task. If you think a server change is needed, write it down in the report and stop there.

## Goal
phase0_decisions.md Step 1 asks for an ODDS board. Your own audit (docs/v3_status.md) found the part at `Workspace.PlotsV3.Plot_<n>.ViewingDeck.OddsBoard` with no working display. Make it show, for the local player, what they can get right now:
- Header: "ODDS" and the player's equipped food (name + tier) and its luck multiplier.
- One row per zone they can reach and the next locked zone (greyed, "Need X strength"): zone name, and for that zone the chance of each rarity as a percentage and as "1 in N" for rare ones.
- A small "Best creature here" line per zone (name or "???" if not discovered yet, from Ctx.book).
- Updates live when the player buys food, gains strength or discovers a creature. No polling every frame; refresh on those changes or at most once per second.

## Rules
- The numbers MUST come from the same shared function the server uses to roll (Economy in ReplicatedStorage, the odds/weights functions around Economy ~line 320-340). Call it; never copy the formula. If the server applies extra factors (rebirth, pity, gamepass) that the shared function does not show, label the board "base odds" and list those factors in the report.
- Client only: a SurfaceGui on the board, built by a NEW module (for example Loop.OddsBoard) started from the client bootstrap with a one-line hook. Each player sees only their own odds on their own plot's board (other plots' boards show nothing or a generic title).
- Style: Chunky Nest colours and fonts from docs/ui_style_spec.md, rarity colours from the spec. Use Theme values by reading them (do not edit Theme). Readable from 15-20 studs away; check SurfaceGui PixelsPerStud / SizingMode.
- No new parts unless the board part is missing; if you must add one, put it on the ViewingDeck and say so.

## Test (Play Solo)
1. Walk to your plot: the board shows your food, luck and per-zone odds; percentages per zone add up to about 100%.
2. Buy a better food (or set it with the Studio-only debug profile): odds shift toward rarer creatures immediately.
3. Discover a creature: its "???" changes to the name.
4. Compare 2 numbers by hand with the Economy function (show the calculation in the report).
5. Another player's board does not show your odds (use a 2-player local test if you can; otherwise say "not verified").
6. No new errors. Studio back in Edit mode.

## Report
New module, the hook line, what the board shows, the odds function used and any server-only factors not shown, screenshot of the board, test results (anything not run = "not verified").
