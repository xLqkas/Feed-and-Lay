# Task for OpenCode: blocky crystal monsters + a small Brick Kit library

Owner: OpenCode, in the open Studio place "Feed an Lay", **Edit mode only**. Start after opencode_stud_material.md. Do NOT save, publish, commit or push. Save only when the user says so. **Ask the user before every asset upload.** Don't touch Workspace map parts or Gemini's modules (Loop.Lanes, Loop.FoodShop, Loop.Throw, Loop.ThrowCinematic, Loop.Trail, Loop.Main, Goals).

## Part 1: restyle the creatures (main job)
Today Loop.Creatures builds the 15 species from primitive parts in a cute style (big eyes, blush). It's used by the pen, the hatch reveal and the Index cards. The user wants **cool blocky monsters** to come out of the eggs. Their reference images (not to copy, only the style): chunky dark blocky bodies built from boxes and wedges, **glowing white/pastel crystal shards** sticking out of the back and head, small glowing eyes (often in a slit/visor), neon accents on claws and joints, a soft glow under the creature.

Style rules (our own version):
- **Blocky only:** Block, Wedge and CornerWedge parts (no balls or cylinders), chunky proportions (big head/shoulders, short legs), clear silhouette per species. Plastic so the stud material shows on the body. Neon for crystals, eyes and accents.
- **Keep our 15 species and their names**, and give each a monster form that matches its name and zone (meadow → mossy/leafy crystals, marsh → slime green glow, volcano → ember/orange, reef → aqua coral shards, galaxy → violet/star shards). Body colours per zone, glow colours from the rarity colours in docs/ui_style_spec.md.
- **Rarity = more glow:** Common: few small shards, eyes glow. Rare/Epic: more and bigger shards, accent lines. Legendary+: a crown of shards, a light glow under it (one PointLight, small Range), gentle particles. Mythic/Secret: the strongest, still readable.
- **Cute stays a little:** don't make it scary. Fun "cool toy monster", friendly eyes for low rarities. (If the user wants fully dark monsters for every rarity, that's a one-line change of the palette.)
- **Same contract:** keep the Creatures API, model pivot = body centre facing -Z, PrimaryPart "Body", the size used by the pen and by the weight scale (petVisualScale), and Fx hooks. Pen, Hatch and Index must work unchanged.
- **Performance:** at most ~25 parts per creature, one PointLight only for Legendary+, particles only for Legendary+, all parts Anchored/welded the same way as today, CanCollide/CanQuery/CanTouch off on decoration. Test 20 pets in a pen on the Device Simulator phone.
- **Index silhouettes** (not-found tiles) must still work with the new models.

## Part 2: small Brick Kit library (only after Part 1)
The user downloaded Kenney's Brick Kit (CC0, free for commercial use, no credit required) to `C:\Users\USER\Downloads\kenney_brick-kit` (296 models in FBX/GLB/OBJ, variants bevel/none/round × hq/lq). Most of it is plain bricks that Roblox parts + the stud material already cover, so import ONLY these pieces for decoration (round studs and slopes that parts can't make), **lq** versions, GLB if the importer takes it, otherwise FBX:
- `bevel-lq-brick-1x1-round`, `bevel-lq-plate-1x1-round`, `bevel-lq-brick-slope-2x2`, `bevel-lq-brick-slope-corner-outside-2x2`, `bevel-lq-brick-slope-inverted-2x2`, `bevel-lq-brick-corner`.
Put them in `ServerStorage.BrickKit` (or ReplicatedStorage if the client needs them; say which), each as a clean Model with the mesh scaled to Roblox studs and a neutral colour so it can be tinted. Ask the user before uploading. List the asset ids. Gemini will use them later to decorate walls, the Food Shop and the gates. You don't place them in the map.

## Test (Play Solo + Device Simulator phone)
1. Hatch one creature of each rarity (Studio-only debug profile is fine): the reveal shows the new blocky monster, the glow scales with rarity, and the name reveal still works.
2. Pen with 20 pets: no FPS drop on phone, pets don't clip or float, weight scale still changes the size.
3. Index: found tiles show the new models, not-found tiles show silhouettes.
4. No new errors. Stop Play and confirm everything exists in **Edit** mode.

## Report
Per species: a short description of its monster form, part count, and rarity effects. Screenshots: all 15 in a row (one rarity each), a Legendary/Mythic close-up, a full pen on phone, the Index. The Brick Kit asset ids and where they are. Test results (anything not run = "not verified").
