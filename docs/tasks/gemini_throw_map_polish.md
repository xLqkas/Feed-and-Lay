# Task for Gemini: polish the throwing map (canyon) and wall it in

Owner: Gemini, in the open Studio place "Feed an Lay", **Edit mode only** (anything built during Play is lost). Start only after gemini_restore_missing.md is done and the client loads. Do NOT save, publish, commit or push. Do NOT run rojo serve. No server code. Don't touch OpenCode's modules (EggService, EggRules, GrowthRules, Main server, SaveSchema, SaveStore, Economy, Loop.Menus, Loop.Hud, Loop.Pen, Loop.Hatch, Loop.Growth, Loop.Inventory).

## Reference
The user's reference short (a food-throwing simulator): the food flies down **one long, straight, clean runway**, with **the creatures standing along both sides**, and a **gate/arch at each zone** that the camera passes through. Walls/cliffs close it in on the left, right and behind. Copy that layout idea, not that game's look, names or text. Keep Feed and Lay's blocky Chunky Nest style.

## Today
The user says the throwing map looks messy. Read what's there first and write it down: Workspace.CanyonV3 (Gate_1, Gate_2, LandingFloor_1/2), Workspace.EggSanctuaryMap (DistanceCanyon, LaunchStation: Pad, YellowLaunchPad, RunwayBed, LaunchArch, RunwayEdgeLamp), your RunwayLanes. List what is legacy/unused (grep scripts for each name). The server's `onPad` uses `EggSanctuaryMap.LaunchStation.Pad`: **don't move, resize or rename Pad.**

## Do
1. **Clean up:** remove or hide leftover legacy parts the V3 game doesn't use, but only if no script references them. Move each one you remove to ServerStorage._MapBackup (don't delete), and list them.
2. **One clear runway:** a straight, even floor from the launch ledge to the end of the last zone, zone-coloured per biome (Economy.Zones names and distances, read only). Lane strips from your lanes task continue down it.
3. **Zone gates:** one arch per zone cutoff with the zone name, matching ThrowCinematic's banner distances (Gate 1 Z = 22, Gate 2 Z = 1422, Gate 3 Z = 2822, and so on for every zone). All gates the same style.
4. **Creatures along both sides:** the zone's creatures (from the Index/creature models, client-rendered or static display models) standing on low platforms along the runway edges in their zone. Keep the count modest for phone performance (for example 2-3 per side per zone). Mark undiscovered ones as silhouettes only if it's cheap; otherwise just show them.
5. **Walls left, right and behind:** tall blocky cliff walls (dirt with grass top, like the plot walls) along both sides of the whole runway and behind the launch ledge. Players must not be able to walk, jump or fall off anywhere. Where a wall would block the throw camera, use an invisible wall (CanCollide true, Transparency 1, CanQuery false) behind a low visible border. The food's flight path and the chase camera must stay clear: run several throws and check the camera never clips a wall.
6. **Safety net:** the Y = -120 net from the restore task must cover the canyon too.
7. **Stud look (Plastic):** OpenCode set up a stud material: MaterialService overrides **Plastic** with `FLStuds` (StudsPerTile 2). It only shows on parts whose Material is **Plastic**. Today almost everything is SmoothPlastic/Grass/WoodPlanks/Rock/Concrete/Slate/Fabric/Mud, so nothing shows studs yet. Switch to **Plastic** (and pick the colour you want, since the texture is tinted by the part colour): the runway floor, canyon walls/cliffs, the plot Floor and PenFloor (two-tone green checker like the reference), fences and posts, Washer/LiftBench/HatchPad bases, the Food Shop, gates and pillars. Keep Neon parts Neon (lamps, rings, glow), and keep invisible walls invisible. OpenCode's full list of non-Plastic parts is in `C:\Users\USER\AppData\Local\Temp\opencode\egg_growth_review\CHANGES.md` (section "stud material"). Don't edit MaterialService.
8. **Fix your Loop.FoodShop error:** Play Solo shows a `ScrollBarImageColor3` error from Loop.FoodShop. Fix it.
9. **MOVED TO OPENCODE (opencode_core_loop_fixes.md Part B) — skip the plot part of this item and don't touch Workspace.PlotsV3. Keep only the stepped cliff walls part.** Original note: plots look empty (from a Studio screenshot after your restore): each 60×60 plot is mostly bare grass. The pen is a low grey wall, and the Washer/LiftBench/HatchPad are tiny in one corner in front of it. Make the pen a proper blocky studded fence (posts + rails, like the user's reference, two colours), big enough to fill most of the plot. Scale the stations up so they read from a distance, with a clear path from the plot entrance → washer → growth spots → pen. Make the enclosure walls stepped blocky cliffs (brown dirt with a green grass top band, like the reference) instead of flat dark slabs.
10. **Performance:** Anchored parts, merge or use unions/meshes where it helps, no lights on every lamp (a few PointLights at most), StreamingEnabled-friendly. Check that FPS stays fine in the Device Simulator phone.

## Test (Play Solo + Device Simulator phone)
1. Throw weak, medium and sweet-spot: food lands on the runway, the camera chase is clear, the banner zone changes when passing each gate.
2. Try to walk/jump off the ledge sides, the back and along the canyon: impossible. Fall on purpose (Studio): you respawn at your plot.
3. Pad still works (no "go to the ledge" rejections).
4. No new errors. Stop Play and confirm everything still exists in **Edit** mode.

## Report
What was legacy and moved to _MapBackup, new parts with paths, the zone gate list with distances, walls and invisible walls, performance notes. Screenshots: runway from the ledge, a zone gate, the creatures along a side, a wall edge, a throw mid-flight. Anything not run = "not verified".
