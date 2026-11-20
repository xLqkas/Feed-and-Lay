# Task for OpenCode: blocky stud look for the whole game (one MaterialVariant)

Owner: OpenCode, in the open Studio place "Feed an Lay", **Edit mode only** (anything made during Play is lost). Do NOT save, publish, commit or push. Save only when the user says so.

## Do not touch (Gemini is rebuilding the map right now)
No edits to any Workspace part (no moving, recolouring or changing materials), no Loop.Lanes, Loop.FoodShop, Loop.Throw, Loop.ThrowCinematic, Loop.Trail, Loop.Main, Goals. This task only adds things in **MaterialService**. Because the override applies to every Plastic part automatically, you don't need to edit any part.

## Goal
The user wants the blocky toy-brick look of their reference (every surface has small square studs/indents, two-tone checker grass, brown dirt walls with green tops). Make it our own: our own texture, Chunky Nest colours, nothing copied from that game.

## Do
1. **Make the stud texture** (our own, tiling seamlessly):
   - One square stud per tile: a raised rounded square with a soft bevel and a thin darker outline, light neutral grey/white base so the part Color tints it.
   - ColorMap (light, low contrast, so tinting gives clean colours) + NormalMap (studs read as raised). Optional RoughnessMap (slightly glossy plastic). No MetalnessMap.
   - Use Studio's material generator if you have it (generate_material / MaterialGenerator). If you need to upload an image as a new asset, **STOP and ask the user first** (uploading needs their OK).
2. **MaterialVariant** `FLStuds` in MaterialService: BaseMaterial = Plastic, the maps above, StudsPerTile = 2 to start (TODO-ART: test 1, 2 and 4 and pick the one closest to the reference, where one stud is about one stud of character scale).
3. **Override:** set MaterialService's Plastic override to `FLStuds`, so every Plastic part gets it. SmoothPlastic, Neon, Glass, Grass etc. stay untouched.
4. **Inventory (read only):** list the main ground/wall/pen/runway parts that are NOT Plastic (name, path, current material), so Gemini can switch them to Plastic in its next pass. Don't change them yourself.
5. **UI is not affected** (it's a 3D material only). Check that pets and pen models built from Plastic still look right and don't get too busy. If the creature models look worse, write it down and suggest a second variant with bigger studs, or leaving creatures on SmoothPlastic.

## Test (Edit mode + Play Solo, Device Simulator phone)
1. Plots, pens, walls and runway (whatever is Plastic) show even studs, tinted by each part's colour, with no stretching on long parts (StudsPerTile is world-scaled, so check a long wall and a small fence).
2. Pick StudsPerTile from 1/2/4 with a screenshot of each.
3. Phone: no visible FPS drop. Textures load.
4. Turning the override off brings back the old look (so it can be reverted in one click).
5. No new errors. Stop Play and confirm FLStuds and the override still exist in **Edit** mode.

## Report
Texture maps (asset ids or how they were made), the MaterialVariant settings, the StudsPerTile chosen + the 3 comparison screenshots, the non-Plastic parts list for Gemini, notes on creatures, and test results (anything not run = "not verified").
