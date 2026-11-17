# Egg Sanctuary: Feed, Clean & Hatch 🥚✨

A friendly, colorful, satisfying pet sanctuary and collection game on Roblox.

> **Core Loop:** Train strength at the gym $\rightarrow$ Walk onto the marked Launch Station looking down the canyon $\rightarrow$ Charge and release a food toss down the red carpet runway $\rightarrow$ A wild creature catches it and lays an egg $\rightarrow$ Bring the egg to the wash station and brush it clean $\rightarrow$ Place the clean egg in your open wooden garden yard to grow & hatch $\rightarrow$ Pet visibly lives and roams inside your yard, generating passive Bio-Essence ($/s) $\rightarrow$ Upgrade food & repeat!

---

## 🎮 Game Systems & Features

- **Location-Gated Throw Mechanic:**
  - Launching is only enabled when the player stands on the glowing **Yellow Launch Pad**.
  - Stepping off immediately cancels active charges and hides the throw UI.
  - Server validates distance, state, and cooldown to prevent invalid throws anywhere on the map.
- **6-Segment Power Meter:**
  - Stacked segmented charge meter inspired by top launch games:
    - Segment 1: Tap (`x0.5`)
    - Segment 2: Speed (`x0.7`)
    - Segment 3: Speed (`x0.85`)
    - Segment 4: Full (`x1.0`)
    - Segment 5: **Golden Sweet Spot (`<| x1.25 SWEET SPOT! 🔥`)**
    - Segment 6: Overcharge (`x0.9`)
- **Tactile Egg Washing Station:**
  - Dirty eggs return from the canyon with 4 dirt patches.
  - Players brush dirt patches clean (25% per brush) before hatching.
- **Open Fenced Pet Gardens (No Nests):**
  - Spacious 46x46 split-rail wooden fenced yards.
  - Pets live and roam directly on the grass floor.
  - Every new player receives 1 attractive 3D starter pet (**Meadow Bunny**).
- **Passive Income & Base Expansion:**
  - Placed pets generate passive Bio-Essence every 2 seconds.
  - Base signs display real-time earnings (e.g. `XLQKAS'S BASE (+6 $/s)`).
  - Accumulated Bio-Essence unlocks higher food tiers at the Chef Stall for higher luck and shiny chances.
- **Gym Training:**
  - Treadmill workouts permanently increase throw distance reach (+10 studs per workout).
- **DataStore Persistence:**
  - Robust auto-saving for Strength, Bio-Essence, Food Tiers, and placed Garden Pets with session fallback.

---

## 📁 Repository Structure

```
EggSanctuary/
├── default.project.json          # Rojo project configuration
├── 3D_ARTIST_GUIDE.md            # Comprehensive art bible & technical specs for 3D modelers
├── Egg_Sanctuary_GDD.md          # Full Game Design Document
├── Egg_Sanctuary_Clean_and_Hatch_GDD.pdf # Visual GDD PDF
├── src/
│   ├── server/
│   │   └── MainGameServer.server.luau   # Server engine (DataStores, Plots, Throws, Hatching)
│   ├── client/
│   │   └── EggSanctuaryClient.client.luau # Client HUD, 6-Segment Meter, Camera, Wash UI
│   └── shared/
│       ├── GameConfig.luau              # Biome zones, food luck tiers, mutations
│       └── SoundHelper.luau             # Dynamic audio manager with procedural fallback
└── .gitignore
```

---

## 🎨 For 3D Artists & Modelers

Please read [3D_ARTIST_GUIDE.md](./3D_ARTIST_GUIDE.md) before creating models. It covers:
- Polycount budgets (< 4,000 tris per pet).
- Scale, pivot point standards, and bone hierarchy.
- The 5 biome creature concepts (`Meadow Bunny`, `Slime Drake`, `Ember Hound`, `Coral Leviathan`, `Galaxy Titan`).
- Modular environment props (split-rail fence, treadmill, wash basin, chef market stall, canyon cliffs).

---

## 🚀 How to Sync with Roblox Studio (Rojo)

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/) (or the Rojo VS Code extension / Studio plugin).
2. Clone this repository:
   ```bash
   git clone <REPO_URL>
   cd EggSanctuary
   ```
3. Start the Rojo server:
   ```bash
   rojo serve
   ```
4. Open the place in **Roblox Studio** and click **Connect** in the Rojo plugin tab.
