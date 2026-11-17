# Egg Sanctuary: Feed, Clean & Hatch — 3D Artist & Environment Guide

Welcome! This guide contains the art direction, asset breakdown, technical constraints, and export standards for **Egg Sanctuary: Feed, Clean & Hatch**.

---

## 1. Art Direction & Style Guide

- **Visual Tone:** Friendly, colorful, stylized, and punchy (appealing to all ages, optimized for 60 FPS on mobile devices).
- **Inspiration:** Top-tier stylized Roblox experiences (*Pet Simulator 99*, *Adopt Me*, *Super Golf*, *Bee Swarm Simulator*).
- **Color Palette:** Saturated, warm, inviting tones. Avoid grim, muddy, or desaturated textures.
- **Lighting & Materials:** Smooth Plastic / Stylized PBR / Glass / Neon accents. Soft bevels on hard edges.

---

## 2. Creatures to Model & Polish (5 Biome Tiers)

Each creature is awarded when food is thrown down the canyon into their biome. When cleaned and placed in a player's garden, each creature lives, bobs, and generates passive **Bio-Essence ($/s)**.

| Biome Zone | Distance | Creature | Archetype & Details | Scale (Studs) | Target Polycount |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1. Dewdrop Meadow** | 0 – 300m | **Meadow Bunny** | Chubby round silhouette, floppy ears, cheeks, sprout leaves on head, soft mint/white fur. | ~3.8 x 3.6 x 4.2 | 1,500 – 2,500 tris |
| **2. Toxic Slime Marsh** | 300 – 1,000m | **Slime Drake** | Translucent gelatinous dragon with horns, stubby wings, slime bubbles, emerald green. | ~4.2 x 3.8 x 5.0 | 2,000 – 3,200 tris |
| **3. Cinder Volcano** | 1,000 – 2,500m | **Ember Hound** | 3-headed cerberus hound, charcoal obsidian body, glowing magma veins, fiery head crests. | ~5.0 x 4.2 x 5.5 | 2,500 – 4,000 tris |
| **4. Sunken Coral Reef** | 2,500 – 5,000m | **Coral Leviathan** | Serpentine ocean dragon, bioluminescent cyan plates, staghorn coral horns, energy blade tail. | ~5.5 x 4.0 x 6.5 | 2,500 – 4,500 tris |
| **5. Celestial Galaxy** | 5,000m+ | **Galaxy Titan** | Majestic 9-tailed celestial kitsune, solar crest crown, shrine rope collar with golden bell, cosmic aura. | ~7.0 x 5.5 x 7.5 | 3,500 – 5,000 tris |

### Creature Variant Mutations (Handled in Material / Shader)
Models should be UV-mapped to support material tinting or skin variations:
- **Normal:** Standard biome colors.
- **Shiny (Ice/Diamond):** Ice material / diamond cyan shimmer.
- **Golden:** Glass / metallic gold sheen.
- **Rainbow:** Animated rainbow neon hue cycle.

---

## 3. Environment & Interactive Props

### A. Fenced Garden Yard (Multiplayer Base Plot)
- **Footprint:** 46 x 46 studs square open paddock.
- **Style:** Rustic split-rail wooden fence with warm cedar/oak wood texture.
- **Entrance:** Open gate opening (~10 studs wide) on the front-facing side.
- **Yard Floor:** Vibrant green grass lawn where pets and eggs sit directly (no individual nests).

### B. Base Interactive Machines
Beside each garden fence, three machines must be modeled:
1. **Egg Washer (Egg Cleaner):**
   - A wooden/stone wash basin with running water or soap bubbles.
   - Center pedestal where dirty eggs rest during cleaning.
2. **Workout Treadmill (Gym):**
   - High-energy stylized treadmill or lifting bench with an animated belt surface or glowing power gauge (`+10 Reach / Step`).
3. **Chef Stall (Kitchen / Food Shop):**
   - Wooden market stall with a striped awning (red/white or blue/yellow), display counter, and food crates.

### C. Distance Canyon & Launch Runway
- **Launch Station:**
  - Dark asphalt/metal approach runway with glowing border lamps and cyan chevron direction arrows.
  - Glowing **Yellow Launch Pad** (`20 x 6` studs) where players stand to charge throws.
- **Canyon Walls & Red Carpet:**
  - Sandstone cliff modules (36 studs tall) lining the sides.
  - Vibrant red carpet runway (16 studs wide) extending 300+ studs down the canyon.
- **Biome Gateways:**
  - Gateway arches marking each biome milestone (Dewdrop Meadow Arch, Slime Arch, Volcano Arch, Coral Arch, Galaxy Arch).

---

## 4. Technical Constraints & Rigging Standards

### Dimensions & Scale
- Roblox conversion: **1 Roblox Stud = 0.28 meters** (or roughly 1 stud = 1 foot).
- Default Roblox avatar height is **5.0 studs**.
- All models must be scaled proportionally against a standard R15/R6 character rig.

### Hierarchy & Pivot Points
- **PrimaryPart:** Every model **must** designate a single central root part named `Body` or `Chest`.
- **Pivot:** The pivot point must be at the bottom center of the creature (at ground level `Y = 0`) so `:PivotTo()` places it flush with the ground.
- **Facing Direction:** Models must face towards **$-Z$** (or $+Z$) in Blender so they face forward upon import.
- **Collision:** All parts will have `CanCollide = false` applied by game code.

### Polycount Budget
- Pets: **< 4,000 triangles** per creature.
- Environment Props: **< 2,500 triangles**.
- Modular Fence Section: **< 500 triangles**.

### Textures & UVs
- **Resolution:** 512x512 or 1024x1024 `.png` texture maps.
- **Texture Packing:** Prefer texture atlases where possible to minimize draw calls on mobile devices.
- **SurfaceAppearance:** If using PBR, provide `ColorMap`, `NormalMap`, `RoughnessMap`, and `MetalnessMap`.

---

## 5. How to Import Into Roblox Studio

1. **Export from Blender:**
   - File $\rightarrow$ Export $\rightarrow$ **FBX (.fbx)**.
   - Settings: Selected Objects, Scale: 1.0, Forward: `-Z Forward`, Up: `Y Up`.
2. **Import in Roblox Studio:**
   - Open the **Asset Manager** (`View` $\rightarrow$ `Asset Manager`).
   - Click **Bulk Import** and select your `.fbx` and texture files.
3. **Place in Project:**
   - For Pet Models: Move completed models into `ReplicatedStorage.PetTemplates` matching the exact name:
     - `Meadow Bunny`
     - `Slime Drake`
     - `Ember Hound`
     - `Coral Leviathan`
     - `Galaxy Titan`
   - Set the model's `PrimaryPart` to the central `Body` or `Chest`.
