# Preset: SlimPills (from Steal An Egg)

Module: `src/client/UI/Presets/SlimPills.luau`. Study: `../ui-study-popular-games.md` section 2 (and the same template family in `../game-study-scare-your-favorite-streamer.md`).
Captured 2026-11-19 at 1002x750, ~20 frames per second bursts. "Sampled" = read from pixels, "est." = by eye.

Character: **small, flat, fast. Slim pills and tiny tiles hug the edges, panels snap in and out, side drawers for the things you check often.**

## Palette

| Role | Hex | Source |
|---|---|---|
| Panel body (faint stud texture) | `#333342` | sampled |
| Settings rows | `#35445C` | sampled |
| Side drawer body / title strip | `#323241` / `#E8C9A0` | sampled / est. |
| Shop pill | `#83FF01` → `#4BFF0C`, outline `#0B4800`, inner rim `#BEFFB4` | sampled |
| Collection pill | `#0CE9FB` → `#08C9FF`, outline `#1A0048` | sampled |
| Pill on hover | face multiplied to ~70 % (`#62B511` → `#42B812`) | sampled |
| Shop title bar | `#7DF057` with stud pattern + diagonal streak | sampled |
| Buy button | `#81FD01` → `#49FE01` | sampled |
| Close | `#D81111`, outline `#4F0707`, white X | sampled |
| Gift square beside price | `#E21FE0` | est. |
| Section titles "-- FEATURED --" | `#FFD800` | est. |
| Struck-through old price | `#FF2929` | sampled |
| "Not enough money" | `#FF4040` + dark stroke | sampled |
| Notification dot | `#FF0000` with white "!" and a dark rim | sampled |
| Slider / toggle | `#FFEA7E` / `#92FF00` | sampled |
| Disabled CLAIM | `#ABABAB` | sampled |
| Rarity tiles | Common `#8C8C8C` (est.), Uncommon `#5DEB68`, Rare `#1F5BFF` (est.), Epic magenta `#D81FD8` (est.), Legendary `#FFD000` (est.), Divine rainbow text | |

## Shape and type

- **Fonts:** heavy rounded display face for labels and titles; **italic heavy** for numbers (cash, timer, prices). Roblox: Fredoka One + Builder Sans Heavy Italic.
- **Type (1080 ref):** panel title 43 (0.040), top title band 43, error toast 43, stat 38 (0.035), pill label 32 (0.030), price 30, section titles 30.
- **Stroke:** text 4 px black; pill outline 3 px in a dark shade of the pill colour, plus a 2 px light inner rim.
- **Radius:** almost square: pills and tiles 4, panels 12, buttons 6, close 3.

## HUD map

| Where | What | Size |
|---|---|---|
| Left edge, from y 0.41 H | Shop pill, Collection pill (icon inside, label) | 0.161 x 0.061 H, gap 0.013 |
| Right edge, from y 0.39 H | Three icon tiles (eggs, pets, event) | 0.061 H squares, gap 0.027 |
| Top centre, y 0.12 H | Game title / objective on a dark band fading out at both ends | 0.040 H |
| Bottom-left | Speed (with "+" buy badge) and Cash rows, italic, no backing | 0.035 H |
| Bottom-right | Day/night timer on a dark gradient strip | 0.03 H |
| Bottom centre | Hotbar slots 0.1 H; error toast centre at y 0.83 H | |

## Component recipes

- **Pill button:** gradient face, 3 px dark outline + 2 px light rim, radius 4, line icon inside on the left, label right. Hover darkens; press shrinks to 0.9. Dot on the top-right corner.
- **Panel:** stud-textured dark body, patterned title bar per menu colour, red square close inside the bar, title left. Tabs and section jump icons sit **outside** the panel on its right edge.
- **Drawer:** replaces the right tile column; beige title strip with a count ("0/7 Active") and a small action chip; a red ">" tab on its left edge collapses it.
- **Event panel:** themed frame with 3D decoration overhanging, event currency chip inside the title bar, horizontal milestone track of cards with grey "Locked" buttons.
- **Price chip / plate:** red when unaffordable, label "+1 EQUIP [$1K]".

## Motion (measured)

| Motion | From → To | Time | Easing | Notes | Evidence |
|---|---|---|---|---|---|
| Panel open | OffsetY +0.016 H → 0, **no scale** | 0.15 s | Quad Out | Full size from the first frame; tiny 1-2 % settle; images load a frame later | [sheet](../shots/ui-presets/steal-an-egg/motion-panel-open.jpg) |
| Blur in | world blur fades in with the panel | ~0.14 s | Quad Out | est. | same |
| Prices on open | numbers count up to their value | ~0.25 s (est.) | Quad Out | seen as changing digits in frames 1-5 | same |
| Panel close | **instant** hide (≤ 0.05 s), blur off with it | 0 | | HUD pills never move | [sheet](../shots/ui-presets/steal-an-egg/motion-panel-close.jpg) |
| Drawer open | OffsetX ≥ +0.08 H → 0 from the right edge | 0.30 s | Back Out | Overshoots ~0.05 H to the left at 0.12-0.18 s, settled 0.30 s | [sheet](../shots/ui-presets/steal-an-egg/motion-drawer-open.jpg) |
| Pill hover | face to ~70 % brightness, outline lightens | ≤ 0.05 s | Linear | no scale | [sheet](../shots/ui-presets/steal-an-egg/motion-pill-hover.jpg) |
| Chip press / release | Scale 1 → 0.9 → 1 | 0.05 s + 0.08 s | Quad Out | no shake | toast sheet |
| Error toast in | Scale 0.83 → 1.0 | 0.30 s | Back Out | peak ~1.02 at 0.25-0.3 s | [sheet](../shots/ui-presets/steal-an-egg/motion-error-toast.jpg) |
| Error toast hold / out | holds 2.0 s, gone within 0.08 s | 0.08 s | Linear | no slide | |
| Server announcement | new line under the top band | (not timed) | | overlapped the band once (bug) | `../shots/ui-study/steal-an-egg/` |
| Idle HUD, notification dot pulse | not observed | | | | |

## Use it for

Maximum free screen and a fast, no-nonsense feel for older players. Too small and terse for our youngest players; no labels on the right tiles.
