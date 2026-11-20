# Egg Sanctuary: Feed and Lay (V3) 🥚✨

A satisfying Roblox pet sanctuary and distance launcher game where players train strength, launch luxury food to canyon creatures, power-wash dirty eggs, and hatch passive income-generating companions.

> **Core Loop:** Train Strength at the Dumbbell Lift Station $\rightarrow$ Walk to the Canyon Launch Ledge $\rightarrow$ Charge and time your throw on the sweet spot needle meter $\rightarrow$ Wild canyon beast catches food and lays an egg $\rightarrow$ Egg flies back to your Nest $\rightarrow$ Wash the 3D crust off on the rotating turntable basin with your power nozzle $\rightarrow$ Egg hatches into a pet $\rightarrow$ Top pets roam your garden Pen generating coins ($/sec) $\rightarrow$ Upgrade food, weights, nozzles & nest capacity $\rightarrow$ Repeat!

---

## 🎮 Game Systems & Mechanics

### 1. Dumbbell Lift Station (Strength = Distance)
* Stand at the bicep curl station on your plot to train strength.
* Interactive rhythm ring mini-game (`LiftRules.luau`): tap within the timing window to earn strength. Fixed-interval autoclickers are countered by server-side ring timing.
* Strength determines maximum throw distance, unlocking deeper canyon biomes (Dewdrop Meadow $\rightarrow$ Toxic Slime Marsh $\rightarrow$ Cinder Volcano $\rightarrow$ Sunken Coral Reef $\rightarrow$ Celestial Galaxy).

### 2. Canyon Ledge Launch & Sweet Spot Meter
* Gated by proximity to the Canyon Launch Ledge. Stepping away cancels the active charge.
* Timed needle charge meter (`EggRules.needle`):
  * **Tap:** `x0.50`
  * **Speed:** `x0.70` – `x0.85`
  * **Full:** `x1.00`
  * **Sweet Spot:** `x1.25` multiplier on throw reach
  * **Overcharge:** drops to `x0.90`
* Canyon beasts catch the food and drop an egg whose species is determined by the landing zone and whose rarity/mutation is boosted by equipped food tier.

### 3. Food Tiers (Food = Luck & Mutations)
* Higher food tiers purchased from the economy multiply rarity rolls and shiny/golden/rainbow mutation probabilities.
* Food tiers range from Red Apple (T1, 1.0x luck) up to Cosmic Ambrosia (T8, 100.0x luck).
* Mutations provide substantial multipliers to creature income:
  * **Normal:** 1.0x
  * **Shiny:** 2.5x
  * **Golden:** 5.0x
  * **Rainbow:** 10.0x

### 4. Nest & Washing Station
* Laid eggs fly back from the canyon and enter the player's **Nest** queue.
* The player takes an egg from the nest to the **EggCleaner** wash basin.
* Interactive 3D Turntable Washing:
  * The egg rotates on a turntable while encased in 30 destructible 3D crust chunks (`EggRules.chunkNormal`, `EggRules.spray`).
  * Spraying water damages and pops chunks off, revealing the pristine shell underneath.
  * Upgrading the spray nozzle increases damage rate and spray radius.

### 5. Hatching, Garden Pen & Storage
* Once an egg reaches 100% cleanliness, the hatch reveal completes.
* **Pen Capacity:** The garden pen holds the player's top-earning pets (up to `penSlots`).
* **Passive Income:** Placed pen pets generate coins every second based on species base yield and mutation multipliers.
* **Storage:** Extra pets beyond the pen slot limit are kept in collection storage.

### 6. Robust Save & Session Locking (v7)
* Plain DataStore persistence with active session locking (`SaveStore.luau`, `SaveSchema.luau`).
* Prevents data wiping, pet duplication, and concurrent multi-server overwrites via lease locks.
* Automatic backward-compatibility migration converts old v5 and v6 saves on join.

*(Note: In-game growth timers for eggs on plot ground and the central Hub marketplace are tracked as future milestones in `docs/phase0_decisions.md` [unverified in live place]).*

---

## 📁 Repository Structure

```
Feed and Lay/
├── default.project.json          # Rojo 7 project configuration
├── README.md                     # V3 project documentation
├── 3D_ARTIST_GUIDE.md            # Art bible & technical specifications
├── docs/
│   ├── ARCHITECTURE.md           # Module list, remotes & save system details
│   ├── phase0_decisions.md       # Production roadmap and design decisions
│   ├── ui_style_spec.md          # Chunky Nest UI design tokens
│   └── tasks/                    # Agent task specifications
├── legacy/                       # Preserved V1 scripts (unmapped)
│   ├── server/
│   │   └── MainGameServer.server.luau
│   └── client/
│       ├── EggRestoration3D.client.luau
│       ├── EggSanctuaryClient.client.luau
│       └── PetShowcaseAnimator.client.luau
├── src/
│   ├── server/
│   │   └── V3/                   # Authoritative V3 game engine
│   │       ├── Main.server.luau  # Server lifecycle, remotes & autosave
│   │       ├── SaveStore.luau    # DataStore wrapper with session locking
│   │       ├── SaveSchema.luau   # Pure v7 schema, migration & validation
│   │       ├── EggService.luau   # Remote dispatcher & action routing
│   │       ├── EggRules.luau     # Pure rules for throws, washing & hatching
│   │       ├── LiftRules.luau    # Pure dumbbell workout rhythm mechanics
│   │       └── Onboarding.luau   # Pure tutorial step evaluator
│   └── shared/                   # Shared pure modules
│       ├── Economy.luau          # Biomes, food, upgrade tracks & drop math
│       ├── Goals.luau            # HUD goal evaluators
│       ├── GameConfig.luau       # Shared configuration constants
│       └── SoundHelper.luau      # Positional sound helper
└── tests/
    ├── test_game_math.luau       # Economy & throw ratio unit tests
    └── test_v3_saves_and_rules.luau # SaveSchema v5/v6/v7 migration & EggRules tests
```

---

## 🚀 Rojo Synchronization

To sync repo files into Roblox Studio using Rojo:

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/).
2. Run the Rojo server from the repository root:
   ```bash
   rojo serve
   ```
3. Open the `Feed and Lay` place in **Roblox Studio** and click **Connect** in the Rojo plugin tab.
