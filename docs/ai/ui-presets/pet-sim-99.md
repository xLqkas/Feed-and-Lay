# Preset: LightDock (from Pet Simulator 99)

Module: `src/client/UI/Presets/LightDock.luau`. Study: `../ui-study-popular-games.md` section 3.
Captured 2026-11-19 at 1002x750, ~20 frames per second bursts. "Sampled" = read from pixels, "est." = by eye.

Character: **bright white cards with chunky dark outlines, everything bubbly, one menu button, a quest card that always tells you what to do.**

## Palette

| Role | Hex | Source |
|---|---|---|
| Panel and quest card body | `#FFFFFF` with a faint pictogram pattern (`#EEF1F5`, est.) | sampled / est. |
| Outline, ink text, text stroke | `#2A2B31` | sampled |
| Section heading inside panels | `#1297FC` | sampled |
| Quest title | `#70EDFC` with dark stroke | sampled |
| Progress fill / track | `#38C8F0` (est.) / `#7F7F7F` | |
| Green button | `#8CF816` → `#68F10A`, outline `#2B5207` | sampled |
| Pink-red button | `#FF1F6B` → `#FF0E48` | sampled |
| Close | `#FF1F6A` → `#FF114E`, outline `#A1113E`, white X | sampled |
| Count / "!" badge | `#FF1B62`, white text, white rim | sampled |
| Achievement card | `#FFFFFF` → `#E8FFFF` | sampled |
| Diamond number | `#6FE8FF` | est. |
| Coin number | `#FFFFFF` | |
| Dock glow behind open icon | `#FFE45C` radial | est. |
| Tier pips | `#FFC21A` | est. |

## Shape and type

- **Font:** one heavy rounded face everywhere (Fredoka One), including body text.
- **Type (1080 ref):** big button 65 (0.060), panel title 59 (0.055, white with dark stroke, sits on the top edge), settings labels 43 (0.040), currency 38 (0.035), card titles 32 (0.030), quest text 27 (0.025), captions 16.
- **Stroke:** panels 7 px `#2A2B31`, cards 6 px, text 4 px, buttons 4 px.
- **Radius:** panels 26, cards / buttons / close 14, search and toolbar pills fully round.
- **Depth:** green buttons have a darker bottom bevel (~6 px).

## HUD map

| Where | What | Size |
|---|---|---|
| Bottom centre | Single menu button (count badge top-left) → opens a dock of 5 big icons with no tiles | 0.13 H button, icons 0.12 H |
| Top centre, y 0.03 H | Quest card: icon left, cyan title, goal, progress bar + "88/180" | 0.373 x 0.16 H |
| Left edge, y 0.36-0.55 H | Promo shortcuts (event, shop with "!" badge, free gift) | ~0.08 H icons with stroked captions |
| Left edge, from y 0.6 H | Diamonds, Coins: icon 0.06 H + number 0.035 H, no backing, "3.26k" | |
| Bottom-right | "Invite Friends! FREE Reward" caption | small |
| World | Area gate price + Buy button grey → green when affordable; big 3D yellow arrow on the ground; pictogram tutorial signs | |

## Component recipes

- **Panel:** white patterned body, 7 px dark outline, radius 26. No title bar: the title is big stroked white text on the top edge, the menu's 3D icon overhangs the top-left corner, the close (0.093 H) overhangs the top-right corner. A toolbar pill and a search pill can sit on the top edge too. The dock stays visible below the panel; the quest card hides while a panel is open.
- **Quest card:** white card, 6 px outline, radius 14; when a quest completes it is replaced by the next one in place.
- **Empty slot:** dashed outline of the item's silhouette.
- **Selection:** green circle with a white check overlapping the chosen card's corner.
- **Settings row:** dark label left, green "Edit" or pink "Set" bevelled button right.
- **Reward chip:** small square tile coloured by tier, icon, "x25" bottom-right.
- **Affordability:** the world Buy button is grey until the player can pay, then green.

## Motion (measured)

| Motion | From → To | Time | Easing | Notes | Evidence |
|---|---|---|---|---|---|
| Menu button → dock + panel | Panel appears at once, OffsetY +0.02 H → 0 | ≤ 0.08 s | Quad Out | content (pets) pops in one frame later | [sheet](../shots/ui-presets/pet-sim-99/motion-dock-and-panel-open.jpg) |
| Dock fan-out | Icons start bunched at the menu button, Scale ~0.85 → 1.0, spread to slots | ~0.16 s | Back Out (est.) | all icons together, no stagger seen | same |
| Panel close | **instant**; dock collapses next frame; quest card back instantly | 0 | | | [sheet](../shots/ui-presets/pet-sim-99/motion-panel-close.jpg) |
| Coin pickup | white arcs sweep round the player (Transparency 0 → 1, grows) | ~0.4 s | Quad Out | est. | [sheet](../shots/ui-presets/pet-sim-99/motion-coin-billboard.jpg) |
| Gain billboard | "+coins" number over the head drops ~0.02 H on each gain and floats back | 0.30 s | Quad Out | number snaps to the new total | same |
| Big break | white star flash + coins burst outward, billboard jumps by the total | ~0.3 s flash (est.) | | | same, frames 1.27-1.47 s |
| Left counter | lags the billboard and rolls up | ~0.4 s (est.) | Quad Out | `../shots/ui-study/pet-sim-99/03-reward-quest-arrow.png` | |
| Gain toast | green stroked line above the hotbar | (not timed) | | `../shots/ui-study/pet-sim-99/08-reward-burst-buy-green.png` | |
| Shortcut icon wobble | Rotation about ±8°, rocks continuously | ~1.0 s cycle (est.) | Sine InOut | the "!" badge itself does not pulse | [sheet](../shots/ui-presets/pet-sim-99/motion-icon-wobble.jpg) |
| Quest swap | old quest replaced by the next without a visible tween at 1 s sampling | | | | |
| Cannot afford | grey Buy button; no shake seen | | | | |

## Use it for

The friendliest, most child-readable look, and the closest to our cream SunGraphica art: light bodies, thick dark outlines, chunky bevelled buttons. The single dock button is great on phone but hides the menus from first-time players.
