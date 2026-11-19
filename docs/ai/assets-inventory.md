# Asset inventory: AIGuidesAndTooling, for the Feed and Lay UI rebuild

Source folder: `C:\Users\filip\Documents\GitHub\AIGuidesAndTooling` (read only; nothing there was changed).
Surveyed 2026-11-19. `roblox-play/` was ignored as instructed.

Short version: one icon pack (**Gvesster Free Icon Pack**) is almost made for a Roblox pet/egg game, and one UI kit (**Casual Game Interface Kit**) gives bright, chunky cartoon panels and buttons. Everything else is either dark/sci-fi/horror, monochrome glyphs, or web-only guidance. There is no sound, no Roblox-usable font, no rarity frames and no large egg/pet art.

---

## 1. Catalogue

### Top level

| Path | What it is |
|---|---|
| `assets/` | The asset library: 17 licensed packs, ~36,000 files, ~6.2 GB (README says 25,790 unique files / 10,077 items, ~6.5 GB). Has its own browsable site (`assets/index.html`), licence docs and catalog. |
| `styles/` | 13 web style packages (`STYLE.md` + `preview.html` each) plus `index.html` gallery and `README.md`. Text only, ~0.1 MB. |
| `IMPORTED/` | **Empty.** Inbox for new zips (git-ignored). |
| `Claude outputs/` | 3 files: `index.html` (45 KB), `build_catalog.py`, `write_packs.py`. Older versions of `assets/index.html` and `assets/tools/*.py` (hashes differ). Irrelevant to the game. |
| `WEB_DESIGN_GUIDE.md` | 20 KB general web design rules (type, spacing, colour, motion, accessibility). |

### `assets/` structure

| Path | Contents |
|---|---|
| `assets/README.md`, `LICENSES.md`, `ASSET_LIBRARIAN.md` | Pack table with licence + quality score; licence tag legend; instructions for importing future batches. |
| `assets/index.html` | Offline searchable library browser (filters by licence, quality, style, format). Handy for picking icons visually. |
| `assets/catalog/` | `packs.json` (64 KB), `items.jsonl` (13 MB, one JSON per item with tags `section: cat: style: color: size: format:`), `catalog.js` (5 MB, site data), `PROGRESS.md`, `dedup-scan.txt`, `imported-log.json`, `logs/`. |
| `assets/tools/` | Python import/catalog scripts, `plan.json`, `pack_meta.json`; `_review/` (450 `.bin` temp chunks, review screenshots, a 28 MB `site.tar`) and `_trash/`. Not relevant. |
| `assets/packs/<section>/<slug>/` | Each pack: `README.md`, `LICENSE.md`, `pack.json`, `manifest.json`, `items.jsonl`, `preview.webp` (contact sheet), `previews/`, `thumbs/` (webp), and `files/` (the originals, git-ignored, local only). |

Naming scheme: pack folders are `<author>-<pack-name>` slugs. Inside `files/` the vendor's original zip layout is kept, so naming varies by pack (Gvesster: clean `"<Colour> <Thing> <1st|2nd> [Outline] <size>px.png"`; SunGraphica: generic `Button copy 3.png`, `Asset 10@2x.png`, `Layer 13.png`).

### Packs (counts are files on disk incl. previews/thumbs)

| Pack (path under `assets/packs/`) | Files | Size | Main formats | Pixel sizes | Licence | Quality |
|---|---|---|---|---|---|---|
| `icons/gvesster-free-icon-pack-basic` | 3,276 (2,044 PNG) | 14 MB | PNG | 64, 256 | custom (see §6) | 4.0 A |
| `icons/sungraphica-600-minimal-icons` | 9,453 (7,019 PNG) | 274 MB | PNG, PSD, AI, EPS, SVG | 128–1024, 0.5x/1x/2x | commercial-full | 4.0 A |
| `icons/sungraphica-icon-collection-outline` | 1,950 (1,258 PNG) | 135 MB | PNG, AI, EPS, PSD, SVG | 256–1024 | commercial-full | 4.0 A |
| `icons/sungraphica-hand-painted-icons` | 5,668 (4,828 PNG) | 2.0 GB | PNG, PSD | 32–1024 | commercial-full | 4.0 A |
| `icons/golden-fantasy-icon-collection` | 1,588 (774 PNG) | 310 MB | PNG, EPS, AI, PDF | 128, 256, 512, 1024 | commercial-full | 3.5 B |
| `icons/sungraphica-pixel-retro-game-icons` | 3,047 (1,803 PNG) | 34 MB | PNG, PSD | 24–128 | commercial-full | 3.0 B |
| `ui-kits/sungraphica-casual-game-interface-kit` | 389 (202 PNG) | 90 MB | PNG, PSD, JPG | 1080p + 4k exports | commercial-full | 4.0 A |
| `ui-kits/sungraphica-casual-game-ui` | 64 | 171 MB | AI, EPS, SVG, PDF, sheet PNG/JPG | vector sheets | commercial-full | 3.0 B |
| `ui-kits/sungraphica-simple-flat-game-interface-pack` | 179 (129 PNG) | 40 MB | PNG, PSD | mixed | commercial-full | 3.0 B |
| `ui-kits/sungraphica-flat-design-game-ui` | 48 | 45 MB | AI, EPS, SVG, sheet PNG | vector sheets | commercial-full | 3.0 B |
| `ui-kits/sungraphica-mobile-game-ui-maker-kit` | 88 | 65 MB | PNG, PSD | mixed | commercial-full | 3.0 B |
| `ui-kits/sungraphica-game-asset-ui-pack` | 503 | 59 MB | PNG, AI, EPS, PSD | 64–1024 | commercial-full | 3.5 B |
| `ui-kits/sungraphica-game-ui-collection` | 3,012 (2,032 PNG) | 210 MB | PNG, AI, EPS, SVG | 0.5x/1x/2x | commercial-full | 3.5 B |
| `ui-kits/golden-fantasy-game-ui` | 563 | 1.05 GB | PNG, AI, EPS, PDF | 0.667x/1x/2x | commercial-full | 4.0 A |
| `ui-kits/sungraphica-creepy-game-ui` | 307 | 341 MB | PNG, PSD, JPG | 1080p/4k | commercial-full | 3.5 B |
| `ui-kits/sungraphica-sci-fi-game-ui` | 5,761 (3,299 PNG) | 1.37 GB | PNG, PSD/PSB, AI, EPS, SVG | huge canvases (e.g. 5763x8887) | commercial-full | 3.5 B |
| `fonts/brushyboom-font` | 14 | 0.2 MB | OTF (+2 QR PNGs) | n/a | commercial-full ⚠ unverified | 3.0 B |

---

## 2. Images and icons: what they actually look like

Judged from the pack contact sheets plus full-size files opened directly.

| Pack | Style | Colour | Transparency | Fits a bright kids' Roblox UI? |
|---|---|---|---|---|
| **Gvesster Free Icon Pack** | Chunky cartoon, thick dark-navy outline, glossy highlight, slight 3D shading. The modern "Roblox simulator / Brawl" look. | Saturated full colour; most icons come in several colourways (Golden, Blue, Green, Purple, Red) plus "Outline", "Black" and "White" silhouettes. | Yes, 32-bit ARGB, clean edges (checked: `Egg 2nd Outline 256px.png` 256x256 ARGB). | **Yes, best fit by far.** Has Egg, Cracked Egg, Golden Egg, Paw, Bunny/Cat/Dog pets (+golden), Coin, Cash, Diamond, Crystal, Ingot, Ticket, Premium, Robux, food (apple, carrot, strawberry, wheat, cookie...), Rebirth, Auto Open, Trade, Shop bag/cart, Settings, Upgrade, Lock, Gift, Chest, Potion, Clover, Lightning, Star, Trophy, Medal, VIP, Close/Check/Plus/Minus/Info buttons. |
| **Casual Game Interface Kit** | Cartoon casual mobile UI: soft bevels, rounded "pillow" header ribbons, wobbly cream parchment panels with a brown rim, glossy yellow/green/red/blue/orange buttons. | Cream panels + saturated button colours. Bright and friendly. | Yes, all 114 PNGs in `1080p` and 88 in `4k` have alpha. | **Yes.** Panels, header ribbons, buttons, slot frames, sliders/progress bars, item grids, stars. Sizes at 1080p: parts 21 px to 920x780; the 22 full-screen mockups are 1920x1080 (reference only). Not 9-slice prepared. Text in mockups is not baked into parts (headers are blank ribbons). |
| Casual Game UI (6 colourways) | Same cartoon family, rounded panels in blue, brown, green, orange, purple, red/grey. | Bright, matched colour variants. | Only as whole sheets. | Good colour reference (e.g. a different panel colour per rarity or per shop), but every part must be cut from AI/SVG/EPS sheets by hand. |
| 600 Minimal Icons | Flat solid glyphs (controller, emoji, food, items, weapons, UI). | Pure white or pure black. | Yes. | As tintable small glyphs inside buttons only. Generic, includes many weapons. |
| Icon Collection Outline | Even-stroke white line icons. | White only. | Yes. | Weak: thin lines read poorly on bright, busy Roblox screens. |
| Hand-Painted Brush Icons | Dry-brush painted silhouettes. | Black and white. | Yes, up to 1024 px. | No, horror/survival feel. |
| Pixel Retro (misnamed) | Chalky hand-drawn white strokes, pink fringe. | White/pink. | Yes, max 128 px. | No. |
| Golden Fantasy Icons | Metallic gold glyphs with baked grey drop shadow. | Gold gradient. | Yes. | Weak; dated look, RPG subjects. A gold "money bag" exists. |
| Golden Fantasy Game UI | Ornate teal-and-gold RPG frames, serif gold text baked in. | Dark teal + gold. | Yes. | No, too serious. |
| Simple Flat Game Interface | Flat orange/brown boxes with thick dark border, colour variants. | Orange, brown, blue, green, pink, red. | Yes. | Prototype quality only; plain. |
| Flat Design Game UI | Flat teal/brown/orange menus. | Muted flat. | Sheets only. | Low value. |
| Mobile Game UI Maker Kit | Flat dark slate with soft glow. | Dark. | Yes. | No (dark theme). |
| Game Asset UI Pack | Flat dark navy, text baked in ("OPTIONS", "SFX"). | Dark navy/white. | Yes. | No. |
| Game UI Collection | Angular sci-fi fragments (cyan, green, purple). | Neon. | Yes. | No. |
| Creepy Game UI | Grunge horror, blood streaks. | Dark. | Yes. | No. |
| Sci-Fi Game UI | Neon-on-navy, huge mostly empty canvases. | Neon. | Yes. | No. |
| BrushyBoom font | Brush capitals. | n/a | n/a | No (and see §4). |

### Best sets, exact paths

1. **Icons (currency, eggs, pets, food, HUD buttons):**
   `C:\Users\filip\Documents\GitHub\AIGuidesAndTooling\assets\packs\icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\`
   - Eggs: `Item\Egg\256px\` (Egg 1st/2nd, Golden Egg, Outline variants), `Item\Cracked Egg\256px\`
   - Pets: `Animal\Bunny|Cat|Dog\256px\` (normal + Golden), `Main\Paw\256px\`
   - Currency: `Currency\Coin|Cash|Diamond|Crystal|Ingot|Ticket|Premium|Robux\256px\` (5 colourways each for Coin/Cash)
   - Food/feed: `Food\*` and `Nature\Apple|Carrot*|Strawberry|Wheat|Clover|Leaf\256px\` (Carrot is under `Food`)
   - HUD/meta: `Main\Rebirth and Auto Open`, `Main\Trade`, `Main\Shopping Bag|Shopping Cart`, `Main\Settings`, `Main\Upgrade`, `Main\Star`, `Main\Heart`, `Main\Lighting`, `Main\Codes`, `Exclusive\VIP`, `Item\Gift|Chest|Lock|Potion|Trophy|Medal|Crown|Lucky Block|Clock|Backpack`
   - Buttons/glyphs: `UI\Close Button|Checkmark Button|Plus|Minus|Info|Question Mark|Warning|Exclamation Mark`
   - Some subfolders use `256w`/`64w` instead of `256px`/`64px`.
2. **Panels, ribbons, buttons, bars:**
   `C:\Users\filip\Documents\GitHub\AIGuidesAndTooling\assets\packs\ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\`
   (subfolders per screen: `Shop`, `HUD`, `Items`, `Reward`, `Upgrade`, `Victory`, `Options`, `Pause`, `Warning`, `Information`...). Use 1080p parts; the `4k\` copies are mostly over 1024 px. Full-screen `Shop.png`, `HUD.png` etc. are layout references, not upload material.
3. **Alternate panel colours (vector source):**
   `C:\Users\filip\Documents\GitHub\AIGuidesAndTooling\assets\packs\ui-kits\sungraphica-casual-game-ui\files\Casual game ui\` (AI/EPS/SVG per colour).
4. **Tintable small glyphs (fallback):**
   `C:\Users\filip\Documents\GitHub\AIGuidesAndTooling\assets\packs\icons\sungraphica-600-minimal-icons\files\600 Minimal icons\PNG Light\` (white, tint with `ImageColor3`).
5. **Design rules for bright UI:** `C:\Users\filip\Documents\GitHub\AIGuidesAndTooling\styles\09-playful-bold\STYLE.md` (variant `friendly`).

---

## 3. Style and design documents: rules worth carrying into Roblox

Sources: `WEB_DESIGN_GUIDE.md`, `styles/README.md`, `styles/09-playful-bold/STYLE.md` (the only style aimed at kids/games; the other 12 are for SaaS, editorial, luxury, docs etc. and are irrelevant).

**Transfer to Roblox UI:**

- **One focal point per screen, one primary button per view.** Primary = solid bright colour; secondary = outlined/neutral; close = small icon top-right.
- **Hierarchy by size, then weight, then colour.** Make labels small and muted, values (coin counts, prices) big and bold.
- **Type scale (Playful Bold, translate px to TextSize at 1080p reference):** display 88, H1 56, H2 40, H3 22, body 17, button 17–19 heavy, label 14, eyebrow 13 caps. On Roblox use about 4–6 sizes total; with `TextScaled` off and a `UITextSizeConstraint`, or scale from a 1080p reference.
- **Fonts:** chunky, rounded heavy weights; never thin. Playful Bold uses Nunito (800 for buttons) + Bricolage Grotesque. Nunito is in Roblox's built-in font families; Bricolage is not, so substitute Fredoka / Luckiest Guy / Builder Sans Bold for headings (check in Studio).
- **Spacing scale:** 4, 8, 12, 16, 24, 32, 48, 64. Space inside a group smaller than space between groups. Use `UIPadding`/`UIListLayout.Padding` from this scale only.
- **Colour (Playful Bold `friendly`):** primary green `#2B8000` with darker base `#1C5700`; yellow `#FFC800` for rewards/coins; blue `#1CB0F6` info; red `#FF4B4B` errors/hearts; purple `#CE82FF` premium. Large areas low saturation, saturated colour only on small things (buttons, badges). Semantic colours only for their meaning.
- **Contrast:** text ≥ 4.5:1, large text and icons ≥ 3:1; add a `UIStroke` on text over busy backgrounds. Don't rely on colour alone (add icon/label, important for rarity).
- **Shape:** one radius scale (12 / 16 / 24; buttons 16) via `UICorner`. "3D" button = darker strip 4 px below the face; press = move face down 4 px.
- **Touch targets ≥ 44x44 px** (more on Roblox mobile; aim ~56+).
- **Motion:** press 80 ms; hover/select 150–200 ms; panel open 250–400 ms; exits ~75% of entrance. Ease-out for entering, ease-in for leaving; never linear except progress. Reward pop: scale 0.6 → 1 with slight overshoot (Back easing), confetti ≤ 1 s. Animate position/size/transparency only for a reason; don't animate everything. In Roblox: `TweenService` with `Enum.EasingStyle.Quint/Back`.
- **Microcopy:** short verb buttons ("Hatch", "Feed", "Buy 100"), plain words a 12-year-old reads, numbers over adjectives. Card text ≤ 25 words.
- **Avoid the "AI look":** purple-blue gradients, glows everywhere, identical cards, too many "NEW" badges.

**Web-only, does not transfer:** CSS custom properties/tokens syntax, `clamp()`/vw sizing, Google Fonts embeds, `prefers-color-scheme` dark mode, `prefers-reduced-motion` media query (Roblox has `GuiService.ReducedMotionEnabled` instead), semantic HTML/`alt`/keyboard tab order, line length in `ch`, `IntersectionObserver` scroll reveals, page recipes (hero, pricing, footer), `color-mix()`, `box-shadow` (fake with offset frames or 9-slice images), page/section padding (64–128 px) and container widths.

---

## 4. Roblox usability

Roblox constraints: images upload as Decal/Image assets (PNG, JPG, BMP, TGA); anything over **1024x1024** is downscaled, so keep each upload ≤ 1024 on both sides. **SVG, AI, EPS, PDF, PSD/PSB cannot be uploaded**; they must be rasterised to PNG first. Fonts cannot be uploaded (OTF/TTF unusable); only Roblox's built-in / Creator Store font families work. Audio must be uploaded separately (none exists here anyway).

| Category | Assets | Action |
|---|---|---|
| **Directly usable** (upload as-is) | Gvesster PNGs (256 px; use 256 for anything shown ≥ 48 px, 64 px only for tiny chips). Casual Game Interface Kit `1080p` part PNGs (all ≤ 920 px except the full-screen mockups). 600 Minimal Icons 512/256 PNGs. | Upload. For panels set `ScaleType = Slice` and pick `SliceCenter` by hand (kit is not 9-slice prepared; the wobbly parchment edges slice OK if corners are kept). Consider packing small icons into one ≤1024 spritesheet with `ImageRectOffset/Size` to save asset count. |
| **Needs conversion** | Casual Game Interface Kit `4k` PNGs (41 of 88 > 1024 px: downscale or use the 1080p copy). Casual Game UI colourways and Flat Design UI (AI/EPS/SVG sheets: cut and export parts to PNG). Any PSD source (export layers). Full-screen 1920x1080 mockups (reference only; would be downscaled). | Rasterise/crop/resize offline, then upload. |
| **Irrelevant** | Sci-Fi UI, Game UI Collection, Creepy UI, Golden Fantasy UI + icons, Mobile Game UI Maker, Game Asset UI Pack, Hand-Painted and Pixel Retro icons, Outline icons (mostly), BrushyBoom font, `assets/tools`, `assets/catalog` (except as a search aid), `Claude outputs/`, 12 of 13 `styles/`. | Ignore. |

---

## 5. Gaps for a pet / egg / feeding game

Not present in the folder:

- **Large egg art and hatch sequence:** only 256 px egg icons (plain, golden, cracked). No egg variants per world/tier, no shell pieces, no hatch animation frames, no "egg opening" background burst/rays.
- **Pet art:** only bunny, cat, dog (+golden). No pet portraits matching Feed and Lay's actual pets (game pets are 3D models, so viewport-frame renders may be needed instead).
- **Rarity system visuals:** no rarity frames/borders, gradient backgrounds, rarity badges (Common/Uncommon/Rare/Epic/Legendary/Mythic), or shine/glint overlays. The colourways in Gvesster and the Casual Game UI could hint at tiers but nothing is made for it.
- **Feeding specifics:** no feed bag, bowl, seeds/grain sack, hunger/happiness meter icons, "full" or "hungry" status icons. Food icons (apple, carrot, wheat...) are close substitutes.
- **Buttons with states:** the kit's buttons have no hover/pressed/disabled variants; no white/neutral rounded button for secondary actions.
- **9-slice-ready panels** in a lighter, cleaner style; no tooltip, toast/notification, tab bar, scroll-bar, or close-button in the kit's own style (Gvesster's Close Button can stand in).
- **Progress/boost UI:** no timer ring, x2/luck boost badges, level/XP bar in the cartoon style (kit has a plain slider).
- **Fonts:** nothing usable in Roblox; BrushyBoom is unsuitable and unverified.
- **Sound:** no audio at all (clicks, pops, coin, hatch, level-up, music).
- **VFX textures:** no sparkle, confetti, glow ring, or star-burst sprites for ParticleEmitters or UI.
- **Marketing art:** no game icon, thumbnails, logo/wordmark for "Feed and Lay", gamepass/dev-product art (VIP icon exists).
- **Mobile layout guidance specific to Roblox** (safe areas, top-bar inset, controller/console selection): not in any guide.

---

## 6. Licence and attribution notes

- **15 SunGraphica + Golden Fantasy packs:** tagged `commercial-full`, but **user-stated** (no licence file in the zips, only an info file pointing to gamedevmarket.net/member/sgasset and sungraphica.itch.io). Commercial use OK, no credit; never redistribute or resell the raw files. Golden Fantasy packs: author not named; FREE.zip content kept as commercial-full per the owner. See `assets/LICENSES.md`.
- **Gvesster Free Icon Pack v3.1:** licence file in zip (verbatim in its `LICENSE.md`). Commercial and client use OK, **credit optional** (@gvesster appreciated). **Editing only in personal projects**: no recolour, redraw, or edit-and-resell in any form; no claiming as own; no building asset packs from them. For a monetised Roblox game, use the icons **unmodified** (pick an existing colourway rather than tinting with `ImageColor3` or redrawing), and keep uploaded images out of the public Creator Store. An optional credit line ("Icons by Gvesster") is a cheap safety margin.
- **Robux icon** in the Gvesster pack: Roblox has its own Robux glyph and brand rules; prefer Roblox's official Robux symbol in price labels.
- **BrushyBoom font:** no author or licence found; do not use commercially.
- **Style library fonts** (Nunito, Bricolage etc.) are SIL Open Font License; irrelevant on Roblox except as names to match.
- Repo rule: `AIGuidesAndTooling` must stay private; raw `files/` folders are git-ignored and exist only on this PC (6.5 GB). Copies placed in the Feed-and-Lay repo would be redistribution if that repo is ever public; upload to Roblox from the local path instead of committing PNGs, or keep the game repo private.
