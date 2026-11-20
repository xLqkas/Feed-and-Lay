# Feed and Lay: UI style spec ("Chunky Nest")

Status: proposal for Director approval. Owner: Art Director. Audience: UI programmer.
Style reference (traits only): a Roblox pet game with thick near-black outlines, rounded bold type, 3D-edged buttons. We take the *construction* (thick outline, bottom edge, gradient header, pill labels). We do NOT take its palette, layout, names or icons.
Reference pillars: **Chunky, Warm, Readable.** Never: thin/flat, neon-on-black, glassy/blurry.

Sources checked: reference images 4.webp (viewed; 1-3 not re-opened, traits taken from the brief), 2 icon PNGs (viewed), icon folder tree (listed), phase0_decisions.md (read), live Studio tree + one capture (looked only, no edits). `UI.Theme` and `Loop.Menus` sources are truncated in the inspector, so exact current hex/sizes were NOT read.

## 0. Conflict note (read first)
The place already has `UI.Theme` / `UI.Kit` / `UI.Presets` (LightDock, DarkTiles, SlimPills, GlassPanels, "Blend") and references a `docs/ai/ui-style-spec.md` plus "SunGraphica" panel art. That file is not in this repo; I did not read it. This spec defines a new `Chunky` preset. Programmer: add it as a Theme preset (same token names), do not delete the others until the Director picks. Raw PNG panel art is not needed: everything below is built from Frames + UIStroke + UICorner + UIGradient.

## 1. Colour tokens
Rule: every UI colour comes from this table. Anything else needs Art Director approval (palette creep).

### 1.1 Core
| Token | Hex | Use |
|---|---|---|
| `Outline` | `#12202A` | ALL strokes on panels, buttons, cards, text (near-black teal, not pure black) |
| `PanelBody` | `#1E3B3A` | window body (deep pine) |
| `PanelInner` | `#2A524E` | inset areas, scroll well, card backing |
| `PanelInnerDark` | `#16302F` | inset shadow strip, empty slots |
| `Cream` | `#FFF3D6` | egg-shell highlight, pill label fill, light plates |
| `Yolk` | `#FFC83D` | Feed and Lay signature accent, selected states, focus |
| `YolkDeep` | `#F0961B` | yolk gradient bottom |
| `TextWhite` | `#FFFFFF` | all main text |
| `TextShadow` | `#12202A` | text UIStroke colour (same as Outline) |
| `TextMuted` | `#B9D3CC` | hints, secondary body (min contrast 4.5:1 on PanelBody, measured by calc: ~8:1) |
| `Disabled` | `#7C8C8A` / edge `#566665` | disabled buttons |
| `Danger` | `#FF4D4D` | insufficient funds text, warnings |
| `Success` | `#7BE04B` | affordable price text, ok |

### 1.2 Buttons
| Token | Top | Bottom (gradient end) | Edge (3D bottom layer) |
|---|---|---|---|
| `BuyGreen` | `#69E04A` | `#2FB033` | `#1A6E24` |
| `CloseRed` | `#FF5A4F` | `#D12B2E` | `#8A1519` |
| `NeutralBlue` (secondary) | `#5CC8FF` | `#2D8FE0` | `#1A5599` |
| `RobuxGold` (premium buy) | `#FFD84D` | `#F0961B` | `#A8570C` |
| `Disabled` | `#9AA9A7` | `#7C8C8A` | `#566665` |

### 1.3 Header gradients (rotation 90 = top to bottom; 2 stops unless noted)
| Screen | Top | Bottom | Header icon |
|---|---|---|---|
| Shop | `#FFD84D` | `#F0961B` | cart |
| Inventory / Nest | `#5FE0C8` | `#1FA38F` | egg |
| Creature Book | `#C58BFF` | `#8446D6` | book |
| Upgrades | `#9BEA52` | `#4FB02D` | upgrade arrow |
| Odds board (hub) | `#FF9F6B` | `#E0562E` | dice |
| Toast/popups | use the header of the screen that raised it | | |
Each header gets a 2px lighter top highlight strip: `Color3.new(1,1,1)` at 0.75 transparency, 40% header height, UICorner same as header.

### 1.4 Card gradients (rotation 90)
| Card | Top | Bottom |
|---|---|---|
| Product (default) | `#3A7C74` | `#245650` |
| Featured | `#7A5BD8` | `#4A33A8` |
| Gamepass | `#FFB84A` | `#D9731A` with `Cream` 15% overlay on the icon plate |
| Locked / unowned index | `#3C4A4A` | `#283434` |
Card text sits on a darker plate (`PanelInnerDark`, transparency 0.35) if the gradient is lighter than `#3A7C74`.

### 1.5 Currency
| Currency | Icon tint | Number colour | Notes |
|---|---|---|---|
| Coins (main) | none, use Golden Coin | `#FFE066` | always the top row |
| Eggs held (x/y) | Egg icon | `#FFB36B` (low capacity: `Danger`) | row 2 |
| Strength / weights | Arm icon | `#9BEA52` | only while on plot/gym |
| Robux | Robux icon | `#FFFFFF` | price pills only |
| Rate (`+3/s`) | none | `Success` | 60% of the number's size |
All numbers: white fill is allowed only for Robux; others use the number colour above with the `Outline` stroke.

### 1.6 Rarity (single source of truth, used for card frames, name text, glow, index tiles)
Game ranks in code today: Common, Rare, Epic, Legendary, Mythic (checked GameConfig). `Uncommon` is reserved so the table matches common player expectation; do not show it until the economy adds it. `Godly` is mentioned in the GDD (phase0 M2 says add or delete the claim); reserved.
| Rarity | Frame/main | Gradient top | Gradient bottom | Name text |
|---|---|---|---|---|
| Common | `#B8C4C2` | `#D5DEDC` | `#8E9C9A` | `#FFFFFF` |
| Uncommon (reserved) | `#6BDB4B` | `#8CF06A` | `#35A82E` | `#B6FF9A` |
| Rare | `#4DB0FF` | `#7CC8FF` | `#2272D6` | `#9AD6FF` |
| Epic | `#B36BFF` | `#CD94FF` | `#7A33D1` | `#DDB4FF` |
| Legendary | `#FFB021` | `#FFD65A` | `#E0780F` | `#FFD65A` |
| Mythic | `#FF4F7A` | `#FF8FB0` | `#C81E5A` | `#FFB0C8`; add animated hue shimmer (see 7) |
| Godly (reserved) | `#37F0E0` | `#9CFFF4` | `#139BB8` | `#B5FFF8` |
Colour-blind rule: rarity is NEVER colour-only. Every tile shows the rarity word and a star count (Common 1, Rare 2, Epic 3, Legendary 4, Mythic 5) or gem shape.

## 2. Typography
| Role | Font | Size (reference px @1080p) | Text stroke | Colour |
|---|---|---|---|---|
| Window title (header) | `Enum.Font.FredokaOne` | 40 | 3px `TextShadow` | White |
| Section pill | FredokaOne | 24 | 2.5px | White (on dark pill) or `Outline` text on `Cream` pill, no stroke |
| Card title | FredokaOne | 24 | 2.5px | rarity name colour or White |
| Button label (BUY, CLAIM) | FredokaOne | 28 | 3px | White |
| Button price | FredokaOne | 26 | 2.5px | White (never red/green on a green button) |
| HUD number | FredokaOne | 34 (value), 20 (rate) | 3px / 2px | currency colour |
| HUD button label | FredokaOne | 22 | 3px | White |
| Body / hints | `Enum.Font.BuilderSansBold` | 20 | 1.5px `Outline`, transparency 0.2 | `TextMuted` |
| Tiny (hotbar key, qty) | FredokaOne | 16 min | 2px | White |
Rules:
- Only FredokaOne and BuilderSansBold. No Gotham, SourceSans, Arial, Legacy.
- Stroke: `UIStroke.ApplyStrokeMode = Contextual`, `LineJoinMode = Round`, `Color = TextShadow`.
- TextScaled: only for dynamic strings (names, numbers). Always pair with `UITextSizeConstraint` (Max = role size, Min = 14). Fixed labels use explicit `TextSize`, scaled by the root `UIScale`.
- Numbers: abbreviate K, M, B, T from 10,000 up (`12.4K`), 1 decimal max. Use `LocalizationService`-safe formatting; no scientific notation.
- Uppercase for buttons and pills; Title Case for card and window titles.

## 3. Shapes and construction
### 3.1 Corner, stroke, padding
| Element | UICorner | UIStroke (colour `Outline`) | Padding inside |
|---|---|---|---|
| Window outer | 18px | 5px | 14px |
| Window body inner well | 12px | 3px | 10px |
| Header | 14px (top corners only, see 3.3) | 4px (shared) | 12px sides |
| Card | 12px | 4px | 8px |
| Button (large) | 12px | 4px | 0 (label centered) |
| Button (small / close) | 10px | 3.5px | 0 |
| Section pill | `UDim.new(0.5,0)` (full) | 3px | 14px sides |
| HUD icon button | 14px | 4px | 6px |
| Hotbar slot | 12px | 4px (selected: 5px `Yolk`) | 4px |
| Progress bar track | `0.5` full | 4px | 3px fill inset |
| Toast | 14px | 4px | 12px |
Minimum stroke anywhere on a surface: 3px. 1-2px outlines are banned except text stroke on tiny text.
Gap between cards: 10px. Gap between sections: 16px. Window margin from screen edge: 5% scale.

### 3.2 3D button (layered frames, no images)
```
Button (TextButton, transparency 1, Size = {1,0},{0,H+E})   -- E = edge height = 8px (large), 6px (small)
  Edge  (Frame, Position 0,E, Size {1,0},{0,H})  colour = edge token, UICorner R, UIStroke 4 Outline
  Face  (Frame, Position 0,0, Size {1,0},{0,H})  colour = white + UIGradient(top->bottom), UICorner R, UIStroke 4 Outline
    Shine (Frame, top 35%, white 0.8 transp, UICorner R, inset 4px)
    Label (TextLabel, see typography)
```
- Pressed: Face.Position = (0,E-2) (sinks), Shine hidden. Released: back to (0,0).
- Hover (desktop): Face gradient lightens 10% (brightness blend with white 0.1), MotionScale 1.04.
- Disabled: swap to `Disabled` row, Label transparency 0.15, no hover, no press, no sound.
- Hit area: the transparent root TextButton, never smaller than 44x44 px at device scale.

### 3.3 Window construction
```
Window (Frame, no fill)           UIAspectRatio per screen (see 8)
  Shadow (Frame, offset +0,+8, Outline @0.55 transp, UICorner 20)
  Body (Frame PanelBody, UICorner 18, UIStroke 5)
    Well (Frame PanelInner, inset 10px, UICorner 12, UIStroke 3) -> ScrollingFrame
  Header (Frame, overlaps Body top by 50%, height 64, gradient 1.3, UICorner 14, UIStroke 4)
    Title (FredokaOne 40), HeaderIcon (left, 56x56, overlaps header bottom by 8px)
  Close (3.2 button, CloseRed, 56x56, top-right, overlaps header corner by 16px; label = UI/Close Button icon)
```
Header top corners rounded, bottom flat: two stacked frames (rounded one 2x tall, clipped by a `ClipsDescendants` parent).
Scrollbar: `ScrollBarThickness 10`, `ScrollBarImageColor3 = Yolk`, track transparent, `ScrollingDirection Y`, `AutomaticCanvasSize Y`.

### 3.4 Gradients (UIGradient)
- Header/card/button: `Rotation = 90`, `ColorSequence` two stops (0 = top, 1 = bottom) from tables above.
- Progress fill: `Rotation = 90`, three stops: 0 light, 0.5 base, 1 dark (base +/-15% brightness).
- Never use rotation other than 90 or 0, never more than 3 stops. No radial gradients.
- Mythic rarity shimmer: UIGradient `Rotation = 25`, animate `Offset` -1 to 1, 2.4s linear loop (see 7).

## 4. Components
Each row: purpose, size at 1080p reference, parts.

| Component | Size | Construction | States |
|---|---|---|---|
| Window | per screen | 3.3 | open / closed |
| Section pill | H 40, auto-width | pill 3.1, fill `PanelInnerDark` + text White 24, OR `Cream` + `Outline` text for featured; optional 28px icon left | static |
| Product card | 180x240 | card gradient 1.4, top: title (card title 24); middle: icon/ViewportFrame 120x120 on `PanelInnerDark` 0.35 circle plate; rarity strip 8px at top edge (rarity main colour); bottom: BUY button 3.2 H 48 with price row (currency icon 28 + number) | normal / owned (button becomes `NeutralBlue` "OWNED", no price) / can't afford (price `Danger`) / locked (grey gradient + lock icon) |
| Featured egg card | 360x300 | Featured gradient; egg render 160px; odds list on the right: one row per rarity: rarity dot 14px + name + `%` (body font 20); BUY button spans width | same as product |
| Gamepass card | 300x260 | Gamepass gradient; icon plate top; title; short benefit line (body, 2 lines max); BUY button `RobuxGold` with Robux icon + price | owned shows `NeutralBlue` "OWNED" |
| Buy button | 160x56 (+8 edge) | 3.2 | normal, hover, pressed, disabled (table in 1.2) |
| HUD side button | 88x88 (+ label under, 22 FredokaOne) | rounded square 14px: Face gradient `#3A7C74`->`#245650` (or screen header colour), Outline 4px, 56px icon centred, label overlaps bottom edge by 6px; red dot badge 26px top-right (`CloseRed`, number White 16) | normal / hover (1.05) / pressed (0.94) / attention (badge + bounce) |
| Currency stack | row H 44 | per row: icon 40px (Outline variant) + value text with 3px stroke; rate line under the first row; no panel behind (text stroke carries it); rows gap 4px | updating (tick-up, pop) |
| Progress / level bar | H 36, width 40% (min 320) | track `PanelInnerDark` pill + 4px Outline; fill gradient 3.4 (colour by meaning: blue `#5CC8FF` level, `Success` growth, `Yolk` goal); centred label 24 with 3px stroke ("Level 3" left, "120/300" right) | filling (tween) / full (flash Cream 0.15s) |
| Hotbar slot | 72x72 (mobile 64) | rounded square 12px; empty = `PanelInnerDark` + faint 40% egg silhouette; filled = rarity gradient + egg icon 44px + key number top-left (16) + qty bottom-right (16) | empty / filled / selected (5px Yolk stroke, scale 1.1, raised 6px, small down-triangle marker) / locked (lock icon) |
| Rarity tile (Index) | 120x150 | card 3.1; rarity gradient border 4px via UIStroke + inner plate; creature render 84px; name 20; star row 5 slots (filled = rarity colour, empty = dark); unseen = silhouette (render with `Color3 = Outline`, ImageColor3 black) + "???" ; new-to-claim = `Yolk` pulsing stroke + "NEW" pill | seen / unseen / claimable / selected |
| Toast | 320x56 | rounded 14px, fill `PanelBody`, stroke 4, left 40px icon, text 22; accent stripe 8px left in semantic colour (Success / Yolk / Danger); stack from top, max 3, gap 8 | enter / hold 2.5s / exit |
| Popup / confirm | 420x260 | Window 3.3 with 2 buttons (BuyGreen confirm right, NeutralBlue cancel left) | modal over `MenuShade` (Outline, transp 0.45) |
| Egg-reveal card (hatch) | 380x460 | rarity gradient, creature viewport 240px, name 36, rarity pill, weight pill (kg) | reveal anim in 7 |

## 5. Motion (TweenInfo)
Define in `UI.Motion`. All durations in seconds.
| Event | Tween | TweenInfo |
|---|---|---|
| Window open | Scale 0.85 -> 1, Transparency 1 -> 0 on shade | `(0.32, Back, Out)`; Back overshoot default (1.70158) |
| Window close | Scale 1 -> 0.9, fade | `(0.18, Quad, In)` |
| Button press | MotionScale 1 -> 0.94 + Face drop (3.2) | `(0.06, Quad, Out)` |
| Button release | -> 1.0 (overshoot 1.06 then 1) | `(0.14, Back, Out)` |
| Hover (desktop only) | MotionScale 1.04 | `(0.10, Quad, Out)` |
| HUD number tick-up | tween NumberValue to target, text = format(NumberValue) | `(0.45, Quad, Out)`; on each change pop MotionScale 1.15 -> 1, `(0.18, Back, Out)` |
| Currency gain popup | float +N text 40px up, fade | `(0.8, Quad, Out)` |
| Hotbar select | slot scale 1.1 + raise 6px | `(0.12, Back, Out)` |
| Card appear (grid stagger) | Scale 0.8 -> 1, fade | `(0.22, Back, Out)`, delay `index * 0.03` (max 0.3 total) |
| Attention badge bounce | Position Y -6 -> 0, repeat 3 | `(0.35, Bounce, Out)` every 6s while attention |
| Progress fill | Size X | `(0.25, Quad, Out)` |
| Toast enter / exit | slide Y 30px + fade | in `(0.25, Back, Out)`, out `(0.2, Quad, In)` |
| Mythic shimmer | gradient Offset | `(2.4, Linear, InOut, -1 loops)` |
Respect `reduced motion`: if player attribute `FLReduceMotion` is true, skip overshoot and shimmer. Cap to <= 3 simultaneous looping tweens on screen. Sound: tie each press/open to `Loop.Sfx` (not specified here).

## 6. Icon mapping
Root: `C:\Users\USER\Downloads\Free Icon Pack v3.1 (Basic)\Free Icon Pack v3.1 (Basic)\`. Style rule: ALWAYS the `... 1st Outline` variant (thick dark-navy outline, viewed: matches `Outline`). Use 256px for panel/HUD icons, 64px only for icons rendered at <= 40px. Never mix `1st` and `2nd` sets, never use Black/White variants as art (only as tinted glyphs in badges). Food folders use `256w`/`64w` subfolders instead of `256px`/`64px`.
Filenames below omit the root; pattern: `<Category>\<Name>\256px\<File> 256px.png`.

| Game concept | File (256px) |
|---|---|
| Coins (currency) | `Currency\Coin\256px\Golden Coin 1st Outline 256px.png` |
| Robux | `Currency\Robux\256px\` (pick the `1st Outline` file; folder listed, filename not opened) |
| Eggs held / egg (generic) | `Item\Egg\256px\Egg 1st Outline 256px.png` |
| Golden egg (rare/Mythic) | `Item\Egg\256px\Golden Egg 1st Outline 256px.png` |
| Cracked egg (hatching) | `Item\Cracked Egg\256px\Cracked Egg 1st Outline 256px.png` |
| Book / Creature index | `Item\Book\256px\Blue Book 1st Outline 256px.png` (Purple matches the Book header) |
| Animals (creatures tab) | `Main\Paw\256px\Paw 1st Outline 256px.png` |
| Shop | `Main\Shopping Cart\256px\Golden Shopping Cart 1st Outline 256px.png` |
| Upgrades | `Main\Upgrade\256px\Green Upgrade 1st Outline 256px.png` |
| Inventory / bag | `Item\Backpack\256px\` (`1st Outline` file) |
| Settings | `Main\Settings\256px\Settings 1 1st Outline 256px.png` |
| Strength / bicep curl | `Player\Arm\256px\` (`1st Outline` file) |
| Close | `UI\Close Button\256px\Close Button 1st Outline 256px.png` |
| Confirm / check | `UI\Checkmark Button\256px\` (`1st Outline`) |
| Info / hint | `UI\Info\256px\` (`1st Outline`) |
| Lock | `Item\Lock\256px\Lock 1st Outline 256px.png` |
| Unlock | `Item\Lock\256px\Unlock 1st Outline 256px.png` |
| New-gift / reward | `Item\Gift\256px\Purple Gift 1st Outline 256px.png` |
| Odds board | `Item\Dice\256px\Dice 1st Outline 256px.png` |
| Rebirth / auto (future) | `Main\Rebirth and Auto Open\256px\Auto Open 1st Outline 256px.png` |
| Star (rarity pips) | `Main\Star\256px\` (`1st Outline`) |
| Chest / crate | `Item\Chest\256px\Chest 1st Outline 256px.png` |
| Food: generic treat | `Food\Carrot\256w\Carrot 1st Outline 256px.png` |
| Food alternates | Cookie, Burger, Pizza, Pancake, Avocado, Blueberry, Lemon in `Food\<Name>\256w\` |
| Weights (dumbbell) | gap (no dumbbell in pack); closest is `Item\Hammer`, do not use |
| Warning / error | `UI\Warning\256px\` (`1st Outline`) |
Where a filename says "(`1st Outline` file)" I confirmed the folder exists, but did not open it; programmer must confirm exact name on import (pattern `<Name> 1st Outline 256px.png`, colour prefixes like `Golden`/`Green` vary).
Import: upload as Decal/Image, `ResampleMode = Default`, `ScaleType = Fit`, keep `ImageColor3 = White`, `BackgroundTransparency 1`. Record asset IDs in `UI.ImageIds` and note licence "Free Icon Pack v3.1 (Basic), commercial use OK, not redistributable" in the asset references doc. Uploading is the Director's call; this spec does not authorise it.

### 6.1 Gaps the pack cannot cover
| Needed | Why missing | Recommendation |
|---|---|---|
| Washer / EggCleaner | not in pack | ViewportFrame render of the in-game washer model, or a Studio-captured 256px PNG with the same 4px dark outline |
| Feed / food shop stall (ChefStall) | only generic fruit/burger | ViewportFrame of ChefStall model; food rows use Food icons |
| Chicken / Hen | pack has only Bunny, Cat, Dog | ViewportFrame of the game's Hen model |
| Every creature species (Book, hatch, hotbar-next) | pack animals do not match | ViewportFrame of each creature model (see 6.2) |
| Egg per rarity/tier | only plain and golden egg | tint with `UIGradient` over `Egg 1st Outline` OR ViewportFrame of the real egg model (preferred, matches throw art) |
| Dumbbell / weights | none | ViewportFrame of the plot dumbbell model |
| Muddy egg | none | `Egg 1st Outline` + brown speckle Frames (`#7A5A3A`), or ViewportFrame of mud-egg model |
| Nozzle / sprayer | none | ViewportFrame or text chip |

### 6.2 ViewportFrame rule for game models
- One shared `ViewportFrame` factory in `UI.Kit` (`Kit.ModelIcon(model, size)`), cached per model, camera FOV 30, 3/4 front angle (yaw 25 degrees, pitch -15), model auto-fit to bounds, `Ambient = #A0A0A0`, `LightColor = #FFFFFF`, `LightDirection = (-1,-1,-1)`.
- Background transparent; a 4px `Outline` cannot be drawn on 3D, so ALWAYS place the render on the `PanelInnerDark` circular plate (3.1) with stroke 4px.
- Same camera angle for ALL creatures (consistency). Max 12 live viewports on screen; Book uses virtual scrolling or static renders.
- Unseen creature: `ImageColor3`-style silhouette = model parts set to `Color #12202A`, `Material SmoothPlastic`, no textures.

## 7. Responsive rules
| Rule | Value |
|---|---|
| Authoring resolution | 1920x1080; `UI.Kit` root `UIScale` = `min(viewX/1920, viewY/1080)` clamped 0.6 to 1.4 (already how Kit scales; keep) |
| Positions/sizes | Scale for window and layout containers; Offset only for strokes, corner radii, icon sizes, gaps |
| Windows | `Size = {0.62,0},{0.74,0}` on desktop, `{0.92,0},{0.86,0}` on phone (<= 700 px short side); `UIAspectRatioConstraint` 1.4 (Shop, Book), 1.1 (Inventory, Upgrades), `DominantAxis Height`; `UISizeConstraint` Max 1100x800 |
| Square icons/buttons | always `UIAspectRatioConstraint = 1` |
| Safe insets | `ScreenGui.ScreenInsets = CoreUISafe`; HUD edge margin 16px + top 56px for Roblox top bar buttons; bottom hotbar clear of home bar (+12px on touch) |
| Min tap target | 44x44 device px (HUD side button 88 ref px becomes ~53 px at 0.6 scale; OK). Close button >= 48 |
| Phone layout | currency stack stays top-left under the top bar; side buttons shrink to 72; hotbar slot 64, shows 5 visible + scroll if > 5 on width < 600; Shop grid 2 columns (desktop 4) via `UIGridLayout.FillDirectionMaxCells` computed from width |
| Text on small screens | `UITextSizeConstraint.Min = 14`; never shrink body below 14 px actual |
| Do not overlap | THROW button, chat, jump button (phone): THROW bottom-right above jump; hint text hides on touch |
| Grid cards | `UIGridLayout.CellSize` in Offset (card ref size), `HorizontalAlignment Center` |

## 8. Per-screen layout (screens found in the place)
Found under `PlayerGui.FLHud.Root` (looked, not modified): Toasts, Announce, LeftColumn (Book), RightColumn (NextCreature, Upgrades), Stats (4 CurrencyRows), THROW, ThrowHint, Meter (throw power bands), EatCards, WashHud, MenuShade, Book, Upgrades, LiftHud, PerfectFlash, Inventory (Tabs), EggHotbar (Slot1-8), Banner, Goal. Legacy `EggSanctuaryHUD.MainFrame` and `Freecam` also exist (not styled here; recommend removing the legacy HUD to avoid two styles, Director's call). From phase0: Shop (ChefStall), Odds board, egg-growth UI are planned and not built.

| Screen | Header colour | Layout |
|---|---|---|
| HUD left | n/a | top-left: Stats (coins, eggs x/y, strength), 4 rows, 16px from edge; below: Book HUD side button (88px, badge for claimable) |
| HUD right | n/a | NextCreature card (reshape to a Product card without buy; silhouette + "???" + rarity pill + `0/1 eggs` progress bar), Upgrades side button below it. Replace the current grey card + brown count with `PanelBody` plate and the progress bar 4 |
| Hotbar (bottom centre) | n/a | 8 slots, gap 8, caption "EGGS" pill above (replaces "EGGS . PRESS1-8 TO HOLD", move key hint to slot corners and hide on touch); `Yolk` selected state |
| THROW button + Meter | n/a | THROW = `BuyGreen` large button (140x140 round-rect, label THROW 32); Meter = progress bar style with 4px outline and band colours Danger/Yolk/Success; sweet spot `Yolk`; `Perfect` flash = Cream burst |
| Goal / Banner / Announce | n/a | Banner = title text 40 with 3px stroke, no panel; Goal = progress bar (Yolk) with count; Announce = toast style centre-top, 1 line, max 2 s |
| Inventory | Teal | 2 tabs as section pills (active = Yolk fill + Outline text, inactive = `PanelInnerDark`); grid of hotbar-style slots 80x80 (6 columns desktop, 4 phone), egg count pill; selected item shows detail strip at bottom: name, rarity pill, weight, ACTION button (BuyGreen "EQUIP" or `NeutralBlue`) |
| Book (Index) | Purple | top pill row = progress "12/60 found" (progress bar) + rarity filter pills; grid of rarity tiles 5-6 columns; CLAIM = `BuyGreen` button inside tile when claimable; tile detail popup (creature render 240, rarity, income, weight range) |
| Upgrades | Lime | vertical list of rows 100px tall: icon plate 72, title 24, level pips, effect text (body), BUY button right (price colour: Success if affordable, Danger if not; the BUY button itself goes `Disabled` when unaffordable) |
| Shop (hub ChefStall, planned) | Yolk | section pills: FOOD / EGGS / GAMEPASSES; Product cards for food; Featured egg card with odds list at top; Gamepass cards with `RobuxGold` buttons |
| Odds board (hub, planned) | Orange-red | read-only Window: one row per egg tier, rarity pills with % ; no buy buttons |
| WashHud | n/a (in-world HUD) | progress bar (NeutralBlue `#5CC8FF`) top centre, NozzleChip pill, Crosshair 2-ring (Outline 4px + Cream), small Close (CloseRed 48) top-right of the HUD group |
| LiftHud | n/a | ring + target use `Outline` 4px rim; progress bar Success; reps text 40 with 3px stroke; Close as WashHud |
| Hatch / reveal (Loop.Hatch) | by rarity | Egg-reveal card (4); full-screen `MenuShade`, card centre, Yolk burst particles; CLAIM button |
| Egg growth (planned, phase 4) | Teal | per-egg billboard: progress bar `Success`, weight pill "2.4 kg", time left pill; no window |

## 9. Don't list
1. No outline thinner than 3px on any panel, card or button; no 1px strokes except tiny text.
2. No default Roblox fonts (SourceSans, Gotham, Arial, Legacy); only FredokaOne and BuilderSansBold.
3. No mixed icon styles: only `1st Outline` pack icons, or ViewportFrame renders on a plate; no emoji, no `2nd`, no flat Black/White glyphs as art.
4. No copying the reference's exact palette, layout, wording, or icons. Our identity is pine panel, yolk accent, cream pills.
5. No colour-only rarity; always word plus stars.
6. No glass/blur/transparent panels; panels are opaque.
7. No text baked into images; all text live, localisable.
8. No Offset-only window sizing; no elements under the Roblox top bar or phone home bar.
9. No new colours outside sections 1.1 to 1.6 without Art Director approval.
10. No more than one `Yolk` highlight per screen region (selected state only); it loses meaning if everything is yellow.
11. No ripped assets; icons stay inside the licence (no redistribution of the PNGs in public repos; upload for in-game use only with Director OK).

## 10. Acceptance checklist (QA)
Three-distance check: at phone size (0.6 scale) every label is >= 14 px and legible; at 1080p all strokes read as one weight; in context against the green meadow, dark runway and purple sky captured in the live game, text with `Outline` stroke stays readable. Verify: strokes >= 3px, fonts only the two, every button has pressed/disabled state, rarity tiles show a word and stars, close button on every window, tap targets >= 44 px, no asset outside the icon-pack or model renders.
