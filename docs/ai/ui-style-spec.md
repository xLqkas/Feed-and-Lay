# Feed and Lay UI style spec (v3 restyle)

Build rules for the UI restyle. Evidence: `ui-study-popular-games.md` (Throw Food For Animals, Steal An Egg, Pet Simulator 99, 2026-11-19) and `game-study-scare-your-favorite-streamer.md`. Art: `image-asset-ids.md` / `src/client/UI/ImageIds.luau`. Code: `src/client/UI/Theme.luau`, `Kit.luau`.

This replaces `design-v3.md` 7.1-7.4 where they disagree; the HUD contents (what exists, when it appears) still come from `design-v3.md` 7.2 and section 5.

**Units.** All sizes are reference pixels at 1080 px screen height, scaled by the Kit's one `UIScale` (viewport height / 1080, clamped 0.55-1.2). The fraction of screen height (H) is given in brackets so it can be checked against the study screenshots. After scaling, every tappable thing must be at least 56 px on phone.

**Take craft, not identity.** Use the conventions below; never another game's names, characters, logos, layouts copied pixel for pixel, or art.

---

## 1. What players expect (shared by every game studied) vs flourishes

### Conventions (do all of these)

| # | Convention | Seen in |
|---|---|---|
| C1 | **Menu buttons live on the screen edges**, mid-height; the centre and the bottom-centre stay clear for the world and the action. Shop is always the top button on the left. | all four |
| C2 | **Currencies are an icon plus a big stroked number with no backing box**, on the left edge, abbreviated (1.2K, 3.4M), rolling up rather than snapping. | all four |
| C3 | **One panel shell for every menu**: coloured title per menu, red square close button top-right, world blurred behind, one panel open at a time. | all four |
| C4 | **Rarity = the whole tile filled with the rarity colour, plus the rarity word**; undiscovered entries are black silhouettes with "???". | Throw Food, Steal An Egg, Scare |
| C5 | **Affordability by colour, live**: price green / button green when affordable, red (or grey) when not; pressing an unaffordable price shows a short red "Not enough coins" line. | all four |
| C6 | **All HUD text is a heavy rounded font, white, with a thick dark stroke, on no background**: objective line, toasts, labels, numbers. | all four |
| C7 | One imperative objective line at top centre plus a world arrow to the target. | all four |
| C8 | Gains and errors appear **just above the hotbar** (bottom centre); server-wide news appears at top centre. Two separate lanes. | Steal An Egg, PS99, Scare |
| C9 | "New" is loud: rainbow "New!" pill on cards, red dot with "!" or a count on HUD buttons. | all four |
| C10 | **Action modes hide the menus**: while throwing, only the meter and the one relevant stat show. | Throw Food |

### Flourishes (optional, per game identity)

- Dark vs light panel body: Throw Food / Steal An Egg dark, PS99 white with a pictogram pattern. **We go light** (cream), because our panel art is cream and because PS99 shows light panels read well for a young audience.
- Title inside a bar (Throw Food, Steal An Egg) vs title text sitting on the panel edge with an overhanging 3D icon (PS99). **We use the ribbon art on the top edge with the menu icon overhanging its left end** (a mix of both).
- Labelled big tiles (Throw Food, 0.13 H) vs slim pills (Steal An Egg, 0.06 H) vs one dock button (PS99). **We use labelled tiles at 0.10 H**: young players read the label, and there are only five buttons.
- Section-jump icons outside the Shop panel, value ribbons ("Most Value") on product cards, tilted "NEW!" sticker on a reveal, 3D decoration overhanging an event panel. Use the sticker and the jump icons; skip the rest for now.

### 1.1 Which preset: a blend, element by element

Four presets were captured (docs in `ui-presets/`, data in `src/client/UI/Presets/`):

| Preset module | Game it comes from | Doc |
|---|---|---|
| `LightDock` | Pet Simulator 99 | `ui-presets/pet-sim-99.md` |
| `DarkTiles` | Throw Food For Animals | `ui-presets/throw-food.md` |
| `SlimPills` | Steal An Egg | `ui-presets/steal-an-egg.md` |
| `GlassPanels` | Scare Your Favorite Streamer | `ui-presets/scare-streamer.md` |

**Base: `LightDock`** for panels, outlines, buttons and type. Why: our uploaded art (SunGraphica) is cream panels with saturated bevelled buttons, which is the same family as LightDock's white panels with thick dark outlines; it is the most readable for young players; and it needs the least code-drawn art. Not the whole of LightDock: its single dock button hides the menus from new players, and its instant panel close feels abrupt.

| Element | Take from | Values to use (from the preset module unless noted) | Why |
|---|---|---|---|
| Panel body, outline, radius | LightDock | cream art body + `Stroke.panel` 7 px `#2A2B31`-style dark rim, `Radius.panel` 26 | matches our art; thick dark rim reads on any background |
| Panel title | LightDock idea + our ribbons | ribbon on the top edge, menu icon overhanging top-left (3.1) | LightDock's floating title with our ribbon art |
| Close button | LightDock | overhanging top-right, 0.067-0.093 H | big, obvious, thumb-friendly |
| Panel open | DarkTiles | `DarkTiles.Motion.panelOpen` (Scale 0.6 → 1, Back Out, 0.3 s; tune to ~3 % overshoot) | the bounce reads as playful; LightDock/SlimPills open with almost no motion |
| Panel close | DarkTiles | `DarkTiles.Motion.panelClose` (Scale 1 → 0.77, Quad In, 0.15 s) | quick but not a jump cut |
| HUD while a panel is open | DarkTiles | `hudTilesHide` / `hudTilesShow` (slide off 0.15 H, back with Back Out) | clears the screen on phone; LightDock hides only the quest card |
| HUD menu buttons | DarkTiles | labelled square tiles (2.2), 0.10 H instead of 0.13 H, hover label colour + shine sweep | labels for young players; LightDock's dock hides menus, SlimPills is too small |
| Button press / release | DarkTiles | `buttonPress` 0.98, `buttonRelease` Back Out 0.15 s (spec 4.1 keeps 0.94 for a stronger squash on phone) | measured, feels springy |
| Buttons (colours, bevel) | LightDock + our art | `LightDock.Buttons.primary` / `accent`; `ButtonDepth` 6 | same family as `buttonWide*` art |
| Currencies | LightDock | icon 0.048-0.06 H + number 0.035 H, no backing, left edge under the menu column | identical convention in all four; LightDock's position is phone-safe |
| Counter on gain | DarkTiles + LightDock | count up (`DarkTiles.numberRoll` for ticks, `LightDock.counterRoll` for big gains) | |
| Gain burst | GlassPanels | `GlassPanels.Motion.cashFly` (icons fly to the counter, stagger 0.015 s) | strongest reward feeling seen |
| Error toast | SlimPills | `errorToastIn` (Scale 0.83 → 1, Back Out 0.3 s), hold 2.0 s, `errorToastOut`; position just above the hotbar | measured; clear and short |
| Notification dot | SlimPills / LightDock colours | `#FF1B62`-style red, white "!" or count, white rim; add our own pulse (5) since none of the games pulse it | |
| Objective | LightDock quest card **only** for count goals; otherwise plain line (DarkTiles / GlassPanels) | 2.4 | the card is great for "Earn 180 Coins" progress |
| Rarity tiles | DarkTiles | whole tile in rarity colour, lighter top (3.2) | C4 |
| Reveal | GlassPanels roll + DarkTiles flash and sticker | `GlassPanels.revealRoll`, `revealLand`; `DarkTiles.revealFlash`, `revealSticker` | |
| Floor arrows | DarkTiles | `floorArrowScroll` (linear, one gap per 0.85 s) | measured |
| Side drawer (Pets on PC) | SlimPills | `drawerOpen` (slide from right, Back Out 0.3 s) | measured; keeps the pen visible |
| Shortcut wobble (new Daily gift, event) | LightDock | `shortcutWobble` ±8°, Sine InOut, loop | draws the eye without a pulse |
| Type scale | own (6) | Fredoka One everywhere on HUD; sizes in 6 sit between LightDock and DarkTiles | |

Where section 5 (Motion) and a preset disagree, **this table wins**; section 5 keeps the values for motions no preset covers (tabs, objective change, price turns affordable, timer urgent).

---

## 2. HUD

Screen gui with `ScreenInsets = CoreUISafeInsets`. Anchor and position in scale; size in reference px.

### 2.1 Layout

```
 [Roblox buttons] [gear]           OBJECTIVE LINE              (phone: timer)
                                  [mini progress bar]
                                   announcement lane
 [SHOP ]                                                         [UPGRADES]
 [PETS ]                                                         [ DAILY  ]
 [BOOK ]
 (coin) 12.4K
 (egg)  Nest 2/3
 (bolt) 320                       gain / error lane
                                     [hotbar / station UI]       (PC: timer)
```

| Element | Anchor / position (PC and phone unless noted) | Size | Order / notes |
|---|---|---|---|
| **Settings gear** | Top-left, immediately right of Roblox's own top-bar buttons (use `GuiService.TopbarInset` to place it) | 44 px dark circle (#1B1B22 at 0.35 transparency), white gear | Same row and look as Roblox's buttons, as Throw Food and Steal An Egg do. Image `settings`. |
| **Objective line** | Anchor (0.5, 0), position (0.5, 0.10) PC, (0.5, 0.12) phone | text 40 (0.037 H) | Section 2.4. Replaced by the station bar while in a station HUD. |
| **Announcement lane** | (0.5, 0.17), stacks downward, max 2 lines | text 28 | Golden Hour, server news. Never overlaps the objective line (Steal An Egg's overlap is the bug to avoid). |
| **Left menu column** | Anchor (0, 0.5), x 16 px, y centre 0.40 | tiles 104x104 (0.10 H), gap 14 | Top to bottom: **Shop, Pets, Book**. Section 2.2. |
| **Right menu column** | Anchor (1, 0.5), x -16 px, y centre 0.40 | same tiles | Top to bottom: **Upgrades, Daily**. |
| **Currency stack** | Left edge, x 20, top at y 0.62 (under the left column) | rows 52 px tall (icon 52 = 0.048 H, number 38 = 0.035 H), gap 6 | Coins, then Nest chip, then Strength chip. Not bottom-left: on phone that is the thumbstick. Section 2.3. |
| **Golden Hour timer** | PC: bottom-right (1, 1) at (-16, -16). Phone: top-right (1, 0) at (-16, 0.10) (bottom-right is the jump button) | strip 260x48, icon 44, text 28 italic | Dark gradient strip fading to the left (#000 at 0.45 → transparent), clock icon, "in 3m 12s". Turns `danger` red under 10 s. |
| **Gain / error lane** | Anchor (0.5, 1), position (0.5, 0.80) PC, (0.5, 0.70) phone | text 32 | Toasts, section 4.8. |
| **Station UI** (power meter, wash bar, lift ring, THROW) | As `design-v3.md` 7.2 / 7.3 | | While any station HUD is open, **hide both menu columns and the Daily/Upgrades dots** (C10). Keep Coins and the one stat the station uses. |

Appearance order (which step shows which button) stays as `design-v3.md` section 5; a newly shown button enters with the "new button" motion (section 5) and gets the pointer hand.

### 2.2 Menu tile

| Part | Spec | Art |
|---|---|---|
| Body | 104x104 | `buttonSquareBlue` 9-sliced (`SliceCenter` from ImageIds, `SliceScale` 0.6). Per menu tint is not needed: the icon carries the colour. |
| Icon | 84x84, centred 8 px above the middle, **overhangs the top edge by 10 px** | Shop `shopBag`, Pets `pawGolden`, Book `book`, Upgrades `upgrade`, Daily `giftDaily` |
| Label | Below the icon, centre at the tile's bottom edge (half outside), text 24 Fredoka One white, stroke 3 `outline` | "Shop", "Pets", "Book", "Upgrades", "Daily" |
| Notification dot | Top-right corner, centre on the corner | Section 4.7 |
| Open state | While its panel is open the tile's body darkens (ImageColor3 #B4B4B4) and the icon scales 1.08 | |
| Phone | Same tile; label stays (at 0.55 scale it is 13 px: use 26 on phone so it stays readable, or drop the label if the screen height is below 400 px) | |

### 2.3 Currency row (pill without the pill)

- Icon 52x52 on the left (`coin`; Nest chip `egg`; Strength chip `lightningBlue`, missing a dumbbell).
- Number right of the icon with 6 px gap, Fredoka One 38, **white**, stroke 3 `outline`. Abbreviate above 9,999: `12.4K`, `3.40M`, `1.2B` (3 significant figures).
- No background box (C2). For legibility on bright ground add a soft shadow: a duplicate label offset (0, 3) in `outline` at 0.5 transparency.
- Coins row has a 26 px `plus` badge just right of the number once the Shop exists (opens Shop at coin packs).
- Under Coins, a small rate line `+120/s` in text 20 `money` green.
- Nest chip text "Nest 2/3" turns `danger` red when full. Strength chip "320".
- Change: number rolls to the new value over 0.4 s (Kit `setPillValue` animate), icon pops 1.0 → 1.15 → 1.0.

### 2.4 Objective line

- Text only, Fredoka One 40, white, stroke 4 `outline`, max width 70% W, one line (shrink with `TextScaled` + `UITextSizeConstraint` max 40, min 28).
- If the step has a count ("Lift until Strength 80!") show a mini bar under it: 220x14, track `barTrack`, fill `barFill`, text "52 / 80" 18 on the right of the bar.
- Tap/click re-shows the world arrow trail (design-v3 7.2).
- Art: none needed. `insetBar` is available if a backing is ever wanted; the convention says no backing.

---

## 3. Panels

### 3.1 Shell

| Part | Spec | Art |
|---|---|---|
| Shade | Full screen `shade` at 0.6 transparency + `BlurEffect` size 18 | - |
| Size | PC 900x620 (0.57 H tall), phone 94% W x 86% H | - |
| Body | Cream 9-sliced image | `panelWide` (PC), `panelTall` (phone, Book), `panelSmall` (confirm). Body text on cream is **ink `#4A3424`** (dark brown), never white. |
| Outline | The art has a thin tan rim; add a dark rim for HUD consistency: wrapper Frame behind the image, 4 px larger each side, `outline` colour, UICorner 28 | - |
| Title ribbon | Centred on the top edge, 60% of the body width, 0.35 of it above the edge; title Fredoka One 44 white, stroke 4 in the ribbon's dark tone | Pets `headerOrange`, Book `headerCyan`, Shop `headerPurple`, Upgrades `headerMagenta` (green missing), Daily `headerYellow` (green missing), Settings `headerBrown`, Confirm `headerRed`, info `headerBlue` |
| Menu icon | The same icon as the HUD tile, 96 px, **overhanging the ribbon's left end** (PS99 flourish) | same as tile |
| Close | 72 px square (0.067 H), **overhanging the top-right corner** by 24 px each way | `close` |
| Tabs | Row under the ribbon, inside the body, 140x56 each, gap 8; selected tab sits 6 px higher | `tabSelected`, `tabDeselected` |
| Content | 24 px padding; `ScrollingFrame` with `ScrollBarThickness` 8, bar colour #C9A27A, `ScrollingDirection.Y` | scroll bar art missing (use colour) |
| Section label | Text 28 Fredoka One ink, centred, with a 2 px #C9A27A line either side (Throw Food "Featured") | - |
| Grids | PC 5 per row, phone 3 per row (design-v3) | - |
| Empty state | Two centred lines, text 24 ink, that say how to fill it ("Hatch an egg on the Hatch Pad to get your first pet!") | - |

Drawer variant (Steal An Egg / Throw Food "My Animals"): for **Pets** on PC only, the shell may dock to the right edge (35% W x 77% H) with no blur, so the player sees the pen while equipping. Phone always uses the centred shell.

### 3.2 Item / pet card (Pets grid, Book entries, reveal)

| Part | Spec |
|---|---|
| Size | 150x170 PC, 120x140 phone |
| Body | Code-drawn: Frame filled with the **rarity colour** (`Theme.Rarity`), UIGradient top 1.0 → bottom 0.8 brightness, 3 px `outline` stroke, UICorner 14. (C4) Missing art: rarity frames; this code version is the plan, not a stopgap. |
| Secret | Same frame with a rainbow UIGradient rotating 360° every 4 s. |
| Model | ViewportFrame 110x110 centred in the top part. Undiscovered: model black (`ImageColor3`/`Ambient` 0), "???" 24 white stroked over it. |
| Rarity word | Bottom, text 18 white stroke 2, the rarity name |
| Income | Top-left chip "+5/s": text 18 `money` on a #000 0.5 rounded pill |
| Mutation | Top-right word chip: "Golden", "Shiny", "Rainbow" (text 16, gold / cyan / rainbow gradient). Missing art: mutation badges. |
| Count | Bottom-right "x3" text 20 white stroke, only if more than one |
| Equipped | `check` 32 px on the top-left corner |
| New | Notification dot (4.7) until first viewed |
| Locked (Book page not reached) | Grey frame #8C8C8C, `lock` 48 px centred, no "???" |
| Empty slot | `slotDark`, or a dashed outline of an egg (missing art) |

### 3.3 Shop row (Upgrades) and product card (Robux shop)

**Upgrade row** (full width, 104 tall): `cardCream` row strip; `iconTile` 80 px with the item icon; name text 28 ink; effect text 20 ink at 70% ("Luck x4"); right side **price button** 220x76: `buttonPriceGreen` when affordable, `buttonPriceRed` when not, `coin` 32 px + price text 30 white stroke; updates live (C5). When red, a thin progress bar (`barTrack`/`barFill`, 220x10) under the button shows coins / price. Owned: button replaced by `check` 48 px and "Owned" text 24 `money`.

**Product card (Robux)**: `cardBrown` 184x227 body, icon 120 px with a soft white radial glow behind (missing art: light rays; use a white circle ImageLabel at 0.6 transparency for now), name 24 white stroke, what it does in one line 18, price button bottom: purple face (missing art: purple button; draw in code with `premium` / `premiumBase`) with a Robux glyph (use the text "R$" if no glyph art) + price. Optional ribbon on the top edge: "Best value" pill (code-drawn, rainbow gradient). Tapping the price calls `MarketplaceService:Prompt...` straight away (no in-game confirm), as every studied game does.

### 3.4 Confirm dialog

`panelSmall` body, `headerRed` ribbon, `warning` icon 80 px left of the question text (24 ink), two buttons: Cancel (secondary, left) and the danger action (right).

---

## 4. Components

### 4.1 Buttons

All buttons: label Fredoka One, white, stroke 3 in the button's base colour darkened (or `outline`); 9-sliced art with `SliceScale` so the bevel stays ~6 px; min height 64 PC / 56 phone after scale.

| Role | Use | Art | Fallback colours (Kit `button`) | Label |
|---|---|---|---|---|
| Primary | CLAIM, Equip Best, Ok, Hatch | `buttonWideGreen` | face `#2B8000`, base `#1C5700` | 32 |
| Reward | Collect, Claim gift | `buttonWideYellow` | face `#FFC800`, base `#C99700`, text `ink` (no stroke) | 32 |
| Secondary | Cancel, Back, info actions | `buttonWideBlue` | face `#1CB0F6`, base `#1182B8` | 28 |
| Danger | Release, Rebirth confirm | `buttonWideRed` | face `#FF4B4B`, base `#C22E2E` | 28 |
| Price | Upgrade rows | `buttonPriceGreen` / `buttonPriceRed` | money / danger | 30 |
| Premium | Robux | **missing art** | face `#CE82FF`, base `#9150BD` | 30 |
| Disabled | CLAIM with nothing to claim, LOCKED | **missing art** | face `#9A9A9A`, base `#6B6B6B`, label `#E6E6E6` stroke `#5A5A5A`; no press motion; `AutoButtonColor` false | same |
| Icon square | small actions (sort, delete, music) | `buttonSquareGreen` / `Red` / `Yellow` / `Blue` | - | icon 70% |

States: hover scale 1.04 (PC only), press scale 0.94 and face moves down 4 px (the base strip shows less), release back with Back easing (section 5). Unaffordable price buttons still press, then show the error toast (C5).

### 4.2 Currency pill: section 2.3.

### 4.3 Progress bar

`barTrack` 9-sliced track, `barFill` inside with 4 px padding, fill width tweened. Text over the bar centre, 18 white stroke 2 ("88 / 180"). Colours: fill art is green; for wash use the same art (no blue fill art: tint `ImageColor3` `info` if wanted, SunGraphica allows tinting).

### 4.4 Rarity treatment (everywhere)

| Rarity | Colour | Star icon (where a small icon is needed) |
|---|---|---|
| Common | `#B8C0CC` | `starWhite` (silhouette; a grey star is missing) |
| Uncommon | `#5BD45B` | `starGreen` |
| Rare | `#3BA7FF` | `starBlue` |
| Epic | `#B65CFF` | `starPurple` |
| Legendary | `#FFC800` | `starGolden` |
| Mythic | `#FF4B6E` | `starRed` |
| Secret | rainbow gradient | missing (rainbow star) |

Always show the word too (colour-blind safe, and every studied game does).

### 4.5 Objective banner: section 2.4.

### 4.6 Tutorial arrow

- **World**: chevron trail on the ground from the player's feet to the target (Scare study), re-routed on every step change. Missing art: chevron texture for a `Beam`; until then use a neon `Part` chevron mesh or the `skip` image on a SurfaceGui.
- **Screen**: `cursor` image 72 px pointing at a newly shown HUD tile, offset to its lower-right, bobbing 8 px toward the tile every 0.6 s; removed on the first press.
- **Over a station**: a yellow ▼ marker (Throw Food) floating 4 studs above the target, bobbing 0.5 stud. Missing art: down arrow (use a rotated `skip`).

### 4.7 Notification dot

- 30 px circle (0.028 H), fill `danger` `#FF4B4B`, 2 px white stroke, centred on the tile's top-right corner.
- Content: a count (text 18 white, Fredoka One) when there is a number (unclaimed Book entries, Daily ready = "1"); "!" otherwise. Art for "!": `exclamation` (Gvesster, unmodified) instead of the drawn circle.
- Motion: pulse 1.0 → 1.15 → 1.0 every 1.2 s while present.

### 4.8 Toasts

Two lanes (C8):

| Lane | Where | Kind | Look |
|---|---|---|---|
| Gain / error | Bottom centre above the hotbar (2.1) | `gain` green `#2BD45B` / `error` red `#FF4B4B` | Text 32 Fredoka One in the colour, stroke 3 `outline`, **no background**. Max 2 lines stacked upward; a new one pushes the old one up. 2.0 s visible. |
| Announce | Top centre under the objective (2.1) | `announce` gold `#FFC800` / rarity colour for the rarity word | Text 28 white with the key word coloured (RichText), stroke 3. 4 s. |

Error texts are short and say what to do: "Not enough coins!", "Nest is full! Collect your eggs."

### 4.9 Reveal (hatch / catch result)

Order (Throw Food and Scare): white flash → rolling names (Scare) → land. Layout: white ring vignette (missing art: ring texture; a `UIStroke` 4 px white on a circular Frame at 0.4 transparency works), stack under the creature: mutation word 32 (its colour), name 80 (`hero`, white stroke 5), rarity word 40 (rarity colour), income "+5/s" 32 `money`. First-time catch: **"NEW!" sticker** rotated -12°, cream fill `#FFF1D6`, orange text `#FF8A00` 28, 3 px dark stroke, placed right of the name. "Tap to continue" 20 after 1.5 s.

---

## 5. Motion

`TweenInfo` values. Reduced motion (setting or `GuiService.ReducedMotionEnabled`): replace every scale/slide with a 0.15 s fade and drop bobbing and pulses.

| What | How | Duration | Easing |
|---|---|---|---|
| Button hover (PC) | scale 1.00 → 1.04 | 0.12 s | Quad Out |
| Button press | scale → 0.94, face down 4 px | 0.06 s | Quad Out |
| Button release | → 1.0 with overshoot | 0.18 s | Back Out |
| Panel open | shade fade 0 → 0.6 and blur 0 → 18 (0.15 s, Quad Out); panel scale 0.6 → 1.0 (measured peak ~1.03) | 0.30 s | Back Out (`DarkTiles.panelOpen`) |
| Panel close | scale 1.0 → 0.77, then hide; shade and blur out together | 0.15 s | Quad In (`DarkTiles.panelClose`) |
| HUD columns while a panel is open | slide off their edge 0.15 H; return with overshoot | 0.15 s out, 0.30 s back (delay 0.05) | Quad In / Back Out (`DarkTiles.hudTiles*`) |
| Drawer open (Pets PC) | slide in from the right edge, OffsetX 0.08 H → 0 | 0.30 s | Back Out (`SlimPills.drawerOpen`) |
| Tab switch | content cross-fade; selected tab up 6 px | 0.12 s | Quad Out |
| Menu columns hide (station mode) | slide off their edge 140 px + fade | 0.2 s | Quad In; back with Quad Out |
| New HUD button | scale 0 → 1.15 → 1.0, then the dot pulses and the hand bobs | 0.35 s | Back Out |
| Notification dot | pulse 1.0 → 1.15 → 1.0, loop | 1.2 s cycle | Sine InOut |
| Currency change | number rolls; icon pop 1.0 → 1.15 → 1.0 | 0.4 s roll, 0.2 s pop | Quad Out |
| Coin burst (gain from world or claim) | 8-20 `coin` icons spawn at the source, arc to the coin icon with random 0.0-0.15 s stagger, each shrinking to 0.6; the counter pops on each arrival | 0.6 s each | Quad In (position), Quad Out (spawn scale) |
| Toast in / out | scale 0.83 → 1.0 + fade in; hold 2.0 s; fade out | 0.3 s in, 0.1 s out | Back Out / Linear (`SlimPills.errorToast*`) |
| Objective change | old line fades up 10 px, new line pops 0.8 → 1.0 | 0.15 + 0.25 s | Quad In / Back Out |
| Price turns affordable | price button pops 1.0 → 1.1 → 1.0 once, colour swaps red → green | 0.25 s | Back Out |
| Error press | the pressed button shakes ±6 px x3 | 0.25 s | Linear |
| Reveal | flash white 0 → 1 → 0 (0.12 in, 0.35 out); name roll 2 s slowing (interval 0.05 → 0.25 s); land: scale 1.3 → 1.0 | ~2.6 s total | Quad Out, Back Out on land |
| "NEW!" sticker | scale 0 → 1.2 → 1.0 with rotation -30° → -12° | 0.3 s, 0.2 s after land | Back Out |
| World arrow / marker bob | ±0.5 stud vertical | 1.0 s cycle | Sine InOut |
| Timer under 10 s | text turns red and pulses 1.0 → 1.08 each second | 0.3 s | Quad Out |

Sound (not observable in the study, from the convention of the genre): click on press, soft pop on panel open, coin tick per arriving coin (rate-limited to 12/s), rising chime on reveal land, low "bonk" on error. Missing: the whole sound set (design-v3 7.5).

---

## 6. Type scale

Fonts available in Roblox: **Fredoka One** (`Enum.Font.FredokaOne`) for everything shown on the HUD, titles, numbers, buttons; **Builder Sans Bold** for longer body text inside panels (descriptions, settings rows, odds). Every text on the 3D world or HUD has a stroke (C6); text on cream panels has no stroke and uses ink `#4A3424`.

| Token | Size (1080 ref) | Fraction of H | Use | Stroke |
|---|---|---|---|---|
| hero | 80 | 0.074 | Reveal name | 5 |
| display | 56 | 0.052 | Reveal rarity on phone, big numbers on CLAIM screens | 4 |
| title | 44 | 0.041 | Panel title on ribbon | 4 |
| banner | 40 | 0.037 | Objective line | 4 |
| number | 38 | 0.035 | HUD currency numbers | 3 |
| button | 32 | 0.030 | Primary and price buttons, gain/error toasts | 3 |
| heading | 28 | 0.026 | Card and row names, section labels, announce toasts | 3 on HUD, 0 on cream |
| label | 24 | 0.022 | HUD tile labels, empty states | 3 |
| body | 20 | 0.019 | Effects, descriptions (Builder Sans Bold) | 0 on cream, 2 on HUD |
| small | 16 | 0.015 | Rarity word on small cards, captions | 2 |

On phone the scale is clamped at 0.55, so nothing may be set below 24 if it must be read during play (HUD labels, toasts, objective). `Theme.TextSize` today has display 56, title 40, heading 28, body 20, small 16: add `hero`, `banner`, `number`, `button`, `label` and move title to 44.

---

## 7. Colour tokens (additions to `Theme.Colors`)

| Token | Hex | Use |
|---|---|---|
| `ink` (change) | `#4A3424` | Body text on cream panels (was `#3C3C3C`) |
| `panelRim` | `#C9A27A` | Divider lines and scroll bar on cream |
| `disabled` / `disabledBase` | `#9A9A9A` / `#6B6B6B` | Disabled buttons, locked cards |
| `newSticker` / `newText` | `#FFF1D6` / `#FF8A00` | "NEW!" sticker |
| `topbarButton` | `#1B1B22` @0.35 | Settings gear circle |

Existing tokens stay. `panel` `#2A2438` remains for dark surfaces on the HUD (timer strip, card chips), not for panel bodies.

---

## 8. Art map (element → uploaded image)

| Element | Image(s) | Status |
|---|---|---|
| HUD menu tile body | `buttonSquareBlue` | ok |
| HUD icons | `shopBag`, `pawGolden`, `book`, `upgrade`, `giftDaily`, `settings` | ok |
| Currency rows | `coin`, `egg`, `lightningBlue`, `plus` | Strength: **missing dumbbell** |
| Golden Hour timer | `clock`, `clockGolden` | **missing sun / gold sun** |
| Objective mini bar | `barTrack`, `barFill` | ok |
| Panel body | `panelWide`, `panelTall`, `panelSmall` | ok |
| Panel title | `headerOrange`, `headerCyan`, `headerPurple`, `headerMagenta`, `headerYellow`, `headerBrown`, `headerRed`, `headerBlue` | **missing green and grey ribbons** |
| Close | `close` | ok |
| Tabs | `tabSelected`, `tabDeselected` | ok |
| Scroll bar | - | **missing** (colour only) |
| Item card | code-drawn rarity frame; `slotDark` for empty; `check`, `lock` | **missing rarity frames, mutation badges, egg-shaped empty slot** |
| Upgrade row | `cardCream`, `iconTile`, `buttonPriceGreen`, `buttonPriceRed`, `coin`, `check` | ok |
| Product card | `cardBrown`, `giftPurple`, `cash`, `chest`, `vip`, `lightning`, `autoOpen`, `goldenApple`, `clover`, `house` | **missing purple Robux button, Robux glyph, light-ray glow, pass art** |
| Buttons | `buttonWideGreen`, `buttonWideYellow`, `buttonWideBlue`, `buttonWideRed`, `buttonSquare*` | **missing disabled and pressed states, premium** |
| Confirm | `panelSmall`, `headerRed`, `warning`, `buttonWideRed`, `buttonWideBlue` | ok |
| Notification dot | `exclamation` or drawn circle | ok |
| Toasts | none (text only) | ok |
| Rarity icons | `starWhite`, `starGreen`, `starBlue`, `starPurple`, `starGolden`, `starRed` | **missing grey and rainbow star** |
| Tutorial pointer | `cursor` | ok |
| World arrow trail / ▼ marker | `skip` stand-in | **missing chevron texture and down arrow** |
| Reveal | `eggCracked`, `eggGoldenCracked`, `stars3` | **missing ring/flash/light-ray/confetti VFX, NEW sticker (code-drawn is fine)** |
| Daily Gift | `calendar`, `giftDaily`, `headerYellow` | ok (green ribbon missing) |
| Settings | `musicOn/Off`, `soundOn/Off`, `headerBrown` | **missing toggle switch art** (code-drawn green pill with white knob, as Throw Food and Steal An Egg) |
| Book | `book`, `headerCyan`, `starX` | ok |

### Missing art, consolidated

1. Dumbbell icon; sun and gold sun icons.
2. Green and grey title ribbons.
3. Purple premium button and a Robux glyph.
4. Disabled and pressed button states.
5. Rarity frames (7 + rainbow Secret) and mutation badges (Golden, Shiny, Rainbow); grey and rainbow stars. (Code-drawn frames are the plan; art would be an upgrade.)
6. Arrow art: floor chevron texture for a Beam, down-pointing marker.
7. VFX: flash ring, light rays behind product icons and reveals, sparkle, confetti.
8. Scroll bar and toggle switch art in the kit style.
9. Egg-shaped empty-slot outline; creature icons beyond the bunny.
10. Sound set.

---

## 9. Build checklist for the restyle session

1. Add the tokens in sections 6 and 7 to `Theme.luau`.
2. `Kit.shell`: cream body + dark rim + ribbon + overhanging icon + overhanging close (3.1); one shade/blur; motion from section 5.
3. `Kit.iconButton` → menu tile (2.2) with label and dot slot; `Kit.button` → art-backed roles (4.1) with fallbacks.
4. `Kit.currencyPill` → backless row (2.3).
5. `Kit.toast` → two lanes (4.8).
6. Rarity card builder (3.2) used by Pets, Book and the reveal.
7. Station modes hide the menu columns (2.1, C10).
8. Check on a phone-sized emulator (Studio Device: iPhone SE / small Android, landscape) that every tile and button is at least 56 px and nothing overlaps the thumbstick or jump button.
