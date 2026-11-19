# Preset: GlassPanels (from Scare Your Favorite Streamer)

Module: `src/client/UI/Presets/GlassPanels.luau`. Study: `../game-study-scare-your-favorite-streamer.md` (sections 4-6), screenshots in `../shots/scare-streamer/`.
**No revisit:** its place id is not recorded anywhere this session could find (not in the study, not in any session log, no web hit), so the values below come from the existing study and from pixel samples of its screenshots. **All motion values are estimates** from screenshots 1-2 s apart; no burst capture.

Character: **see-through dark glass panels over a blurred world, one bright title colour per menu that matches its HUD button, everything green means money.**

## Palette

| Role | Hex | Source |
|---|---|---|
| Panel body | `#2D2D33` at ~0.3 transparency (world shows through, blurred) | est. |
| Cards inside panels | `#737273`, also see-through | sampled |
| Outline, text stroke | `#13131A` | sampled |
| Title bar (costume menu) | `#E677FF` → `#C967FF`, stud pattern; other menus cyan, red, blue, lime | sampled / study |
| Cash button | `#10EA4A` → `#15BC20` | sampled |
| Robux button | `#B31FBC` | sampled |
| Close | `#E81E1E` (est.), outline `#7C0000`, white X | |
| Multiplier text "x2" | `#5FD4FF` | sampled |
| Threat news line | `#D32E45` | sampled |
| Cash number / gains | `#3BE33B` | est. |
| Tutorial ring round a new button | `#E8762A` glow | est. |
| Rarity words | Common `#A6A6A8`, Uncommon `#65BA0E`, Rare `#1EE0FF` (sampled); Epic `#B54CFF`, Legendary `#FFC21A`, Insane `#FF5A1F` (est.); higher tiers rainbow | |

## Shape and type

- **Fonts:** heavy rounded display face for titles and labels; italic heavy for prices and timers.
- **Type (1080 ref):** panel title 54 (0.050), objective 50 (0.047), pill label 38 (0.035), news line 36 (0.033), cash 36, price 34, card names 32, rarity word 18.
- **Stroke:** text 4 px, panel 6 px near-black, buttons 3 px.
- **Radius:** panels 12, cards 8, buttons 6, close 4, pills 10.

## HUD map

| Where | What | Size |
|---|---|---|
| Left edge, y 0.42-0.6 H | Wide pills (Collection cyan, Shop green), 3D icon overhanging the left end | 0.2 x 0.073 H |
| Right edge, y 0.41-0.67 H | Square icon tiles (packages, items) | 0.117 H |
| Top centre, y 0.14 H | Objective line, no backing | 0.047 H |
| Top centre, y 0.05 H | News / gain line over Roblox's top bar | 0.033 H |
| Bottom-left | Cash: icon + green number | 0.033 H |
| Bottom-right | Day/night timer on a dark gradient strip, red under 10 s | |
| Bottom centre | Hotbar | 0.093 H |

## Component recipes

- **Panel:** see-through dark body, 6 px near-black outline, radius 12; title bar in the menu's own colour with stud pattern, big title left; red square close top-right. Opens centred, blurs the world, cash and timer stay visible.
- **Card:** see-through grey, name top-left, rarity word under it in rarity colour, item art centre, effect line ("x2 Scare" with the number in cyan), price buttons bottom (green cash, purple Robux side by side).
- **New button:** red count dot, glowing orange ring round the pill, animated pointing hand below.
- **Affordability:** price green when affordable, red when not, live.

## Motion (all estimated)

| Motion | From → To | Time | Easing | Notes |
|---|---|---|---|---|
| Claim cash burst | ~20 cash icons spray from the button and fly to the counter, Scale 1 → 0.6 | ~0.7 s each, stagger ~0.015 s | Quad In | `13-claim-cash-fly.png` |
| Counter roll | rolls to the new total | ~1.0 s, delay 0.3 s | Quad Out | $21K → $84K in about a second |
| Floating numbers | "-1" hits and "+$510" income float up 0.05 H and fade | ~0.6 s | Quad Out | `09-fans-break.png` |
| Reveal roll | names/models cycle like a slot machine, slowing | ~2.5 s | Quad Out | `10-reveal-roll.png` |
| Reveal land | Scale 1.3 → 1.0 | ~0.3 s | Back Out | |
| New button | ring pulses Scale 1 → 1.12, Transparency 0 → 0.4, loop; hand bobs 0.012 H | 0.6 s / 0.5 s | Sine InOut | `11-hud-unlock-index.png` |
| Night change | full-screen white flash with a big moon and a 3 s count, then fade | ~0.5 s fade | Quad Out | |
| Timer urgent | turns red under 10 s | | | |
| Panel open / close, hover, press | not captured; the same template family as SlimPills, so assume its values | | | |

## Use it for

The drama: cash bursts, slot-machine reveal, world announcements. The see-through panels look good over a busy world but are hard to read for small children and do not fit our cream art.
