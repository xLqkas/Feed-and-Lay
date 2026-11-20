# Feed and Lay: world art bible (3D)

One page every agent follows for anything built in the 3D world. UI style stays in docs/ui_style_spec.md (Chunky Nest). The target look is a bright toy-brick world: saturated colours, studs on every surface, chunky stepped shapes, clean blue sky. Our own palette and shapes; never copy another game's models, textures or layout.

## 1. Materials
- **Plastic for everything solid** (ground, cliffs, fences, stations, props, creature bodies). MaterialService overrides Plastic with `FLStuds` (StudsPerTile 2), so Plastic = studs. Never use Grass, Rock, Concrete, Slate, WoodPlanks, Fabric, Mud or SmoothPlastic for solid world parts.
- **Neon** only for things that glow: lamps, rings, crystals, eyes, READY effects, zone gate trims. Neon is an accent, never more than about 10% of what's on screen.
- Glass and ForceField only for special effects. No Metal/Foil.
- Don't edit MaterialService or Lighting (owned by the art pass). Ask first.

## 2. Palette (world)
| Use | Colour (RGB) |
|---|---|
| Grass light / dark (checker, 4×4 stud tiles) | 120, 220, 70 / 90, 190, 55 |
| Grass top band on cliffs | 110, 210, 60 |
| Dirt cliff / dirt dark | 150, 95, 55 / 120, 75, 45 |
| Path / sand | 240, 210, 140 |
| Fence wood light / dark | 230, 175, 95 / 190, 135, 70 |
| Fence alt (blue toy fence) | 90, 180, 255 / 60, 140, 230 |
| Station accent (yolk) | 255, 200, 61 |
| Water | 70, 190, 255 |
| Shadow/outline dark (trims) | 18, 32, 42 |
Zone tints for the canyon (one dominant + one accent per zone): Meadow green 120,220,70 + yellow 255,220,80; Marsh 100,200,90 + slime 170,255,90; Volcano 120,70,55 + ember 255,120,40; Reef 60,170,210 + coral 255,130,150; Galaxy 70,55,130 + star cyan 90,240,230.
Rarity colours always from ui_style_spec.md.

## 3. Shapes
- Everything is built on a **stud grid**: sizes and positions in whole studs (1 or 2 stud steps). No odd rotations except 90°/45°.
- **Chunky and stepped:** cliffs are stacked 4-8 stud blocks with a grass band on top and dirt below, stepping in and out (never one flat wall). Fences are posts + 2 rails. Stations are big and readable: at least the player's height, simple silhouettes.
- Blocks, wedges and corner wedges. No spheres or cylinders for world props (round studs from the Brick Kit are OK as decoration).
- Every object must read at 3 distances: across the map (silhouette + colour), from 20 studs (shape), up close (details/studs).

## 4. Lighting (applied 2026-11-21; backup in ServerStorage._LightingBackup)
ClockTime 13, Brightness 3, Ambient 120,125,140, OutdoorAmbient 165,175,190, ColorShift_Top 255,246,228, ShadowSoftness 0.35. ColorCorrection Brightness 0.03 / Contrast 0.12 / Saturation 0.35. Bloom 0.6 / Size 24 / Threshold 0.9. Atmosphere Density 0.18, Offset 0.1, Haze 0, Glare 0. Default Roblox sky (the purple sky was moved to the backup). Don't change these without asking. If something looks washed out, fix the part colour, not the lighting.

## 5. Creatures
Blocky monsters (Loop.Creatures): Plastic bodies in the zone colours, Neon crystals/eyes scaled by rarity, max ~25 parts, friendly eyes for low rarities.

## 6. Do / don't
- DO: one dominant colour per object + one accent; dark trims on edges where shapes need separation; two-tone checker floors; big readable signs only when needed (the user removed most signs).
- DON'T: grey or desaturated parts, flat untextured slabs, textured realistic materials, tiny props scattered around, lights on every lamp, neon floors.

## 7. Check before you report
Screenshot from above and from player height. Ask: do all parts use Plastic or Neon? Any grey/dull part? Any flat wall without a grass band? Does it match the palette table?
