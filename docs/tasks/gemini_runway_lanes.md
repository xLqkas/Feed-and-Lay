# Task for Gemini: runway lanes (phase0 Step 2), world + client only

Owner: Gemini, in the open Studio place "Feed an Lay". Do NOT save, publish, commit or push. Do NOT run `rojo serve` / sync: default.project.json maps the server and Economy to the repo, which is stale, and would overwrite live code.

## Do not touch (OpenCode is building egg growth right now)
EggService, EggRules, Main, SaveSchema, SaveStore, TrainingRules, Economy, Loop.Hatch, Loop.Pen, Loop.Inventory, Loop.Menus, Loop.Hud, UI.Kit, UI.Theme, UI.Icons. You may READ them. Your own modules (Loop.Throw, Loop.ThrowCinematic, Loop.OddsBoard) are yours.

## Why
Today every player throws from the one shared launch pad (Main ~112 notes the ledge box is shared by all). With several players, characters stack on the pad and throws fly through each other. phase0 decision 3: the future auto-throw gamepass must hold a lane, so lanes are needed first.

## What exists (read before building)
- `Workspace.EggSanctuaryMap.LaunchStation`: YellowLaunchPad, RunwayBed, LaunchArch, RunwayEdgeLamp parts.
- `Workspace.CanyonV3`: Gate_1, Gate_2 (beam with SurfaceGuis), LandingFloor_1, LandingFloor_2.
- `Workspace.PlotsV3.Plot_1..6`.
- Main `isNear(player, "Ledge")` with LEDGE_C0 / LEDGE_EXTENTS / Economy.LEDGE_RADIUS, and the teleport that faces the pad (Main ~303).
First write down which of these the V3 game actually uses (EggSanctuaryMap may be legacy). Build on the one the server checks.

## Build
1. **6 lanes** on the launch ledge, one per plot: `Lane_1..Lane_6` (Lane_n belongs to Plot_n), each a start pad part with attribute `LaneId = n`, tagged `FLLane`, side by side with clear dividers, plus a matching straight strip down the runway so each lane reads as its own track. Put them in one folder (say where). Every new lane pad must sit INSIDE the current ledge box, so the existing server check keeps passing. Check this with the real LEDGE_C0/EXTENTS numbers and report them.
2. **Zone markers along each lane** at the Economy.Zones distance cutoffs (read only): an arch or sign with the zone name in Chunky Nest style. Your ThrowCinematic zone banner should switch at the same distances, so the world and the banner agree.
3. **Client: your lane.** A new client module (for example Loop.Lanes) with a one-line hook in the bootstrap. Your own lane glows softly (Chunky Nest yolk), shows "YOUR LANE" and your name on its start pad. Other lanes stay neutral. When the player walks onto the ledge outside their lane, show a small arrow/hint to their lane. Do not teleport or block movement from the client.
4. **Throw path:** Loop.Throw / ThrowCinematic animate the food down the thrower's own lane: a sideways offset to that lane's centre line. Distance and zone stay exactly what the server sent. The sideways offset is cosmetic only.
5. **Respect FLReduceMotion** (no pulsing glow). Readable on phone.

## Server (write it down, do not wire it)
Lane reservation must be server-side, but Main is OpenCode's right now. Write in the report exactly what the server needs, for OpenCode to do after egg growth:
- Which lane each player owns (PlotId → LaneId, or first free), stored where.
- Release check: the throw only counts from the player's own lane pad (box per lane), replacing the shared ledge box.
- Teleport-to-ledge puts the player on their own lane.
- Auto-throw (later gamepass) holds the lane while active.
You may add a pure, unwired ModuleScript (for example V3.RunwayLanes with `laneFor(player)` / `isInLane(pos, laneId)`) with no requires from Main. If you do, list it so the architect reviews it.

## Order
Do this AFTER gemini_plot_redesign.md (the ODDS board is removed there, and the map is closed in). Lanes must fit the new walls and the new shared Food Shop position.

## Test (Play Solo, plus a 2-player local server test)
1. Each lane visible and labelled. Your lane glows. Throws from your lane still pass the server (no "walk to the ledge" rejection).
2. Throws fly down your own lane. The zone markers match the cinematic banner and the egg's zone in the inventory.
3. 2 players: each sees their own lane highlighted, throws don't overlap visually. If you can't run 2 players, write "not verified".
4. Phone (Device Simulator): the lane hint is readable, nothing covers the throw meter.
5. No new errors. Studio back in Edit mode (check with Studio state, don't just assume).

## Report
Which map the V3 server uses, folders and parts added (paths), new modules and the hook line, the ledge box numbers and proof that each lane pad is inside, the server changes written down for OpenCode, screenshots on desktop and phone (lanes, your-lane glow, a throw down a lane), and test results (anything not run = "not verified"). "Verified" means you ran it and say what you saw.
