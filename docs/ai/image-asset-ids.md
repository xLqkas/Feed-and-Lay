# Image asset ids (v3 UI)

Uploaded 2026-11-19 through the Roblox Studio MCP `upload_image` tool, with Studio open on "Feed an Lay" (placeId 113603218122384). Code: `src/client/UI/ImageIds.luau`. Not wired into the kit yet.

- **99 images**, all asset type Image, every id verified to load in Studio (`ContentProvider:PreloadAsync` returned `Success` for all of them on 2026-11-19).
- **Owner:** Roblox user `xxfilippoxx33` (userId 547106226), the account logged into Studio. The place is owned by user 4858176881, a different account. Images are normally usable across accounts, but check they render in a live server of the published game before relying on them.
- **Names on Roblox:** the tool names every asset `Assistant_<hash>.png` and has no name parameter. This file is the name list; rename them on create.roblox.com if wanted.
- **Moderation:** every id loaded right after upload; Roblox can still moderate an image later.
- **Possible orphans:** four upload calls failed mid-way (a timeout, two "connection closed" and one "target is closed", while another session toggled Play mode) and returned no ids; they were retried. Images in them may exist twice as unused duplicates under the same account (Golden Coin 2nd to Red Star; Golden Star to Purple Gift; Golden Trophy to Blue Lighting; Warning to Sound OFF). Harmless; delete on create.roblox.com if found.
- Sources are read from `C:\Users\filip\Documents\GitHub\AIGuidesAndTooling\assets\packs\` (local only, not in this repo). No file was resized or edited; every file was 1024 px or smaller.

## Licences

- **Gvesster Free Icon Pack v3.1** (`icons\gvesster-free-icon-pack-basic`): commercial use OK, credit optional ("Icons by Gvesster"), **no edits**. Uploaded unmodified; do not recolour with `ImageColor3`. Keep out of the public Creator Store.
- **SunGraphica Casual Game Interface Kit** (`ui-kits\sungraphica-casual-game-interface-kit`, `1080p` PNGs): commercial-full (user-stated, see `assets-inventory.md` section 6); no redistribution of the raw files. Tinting and slicing are fine.

## SliceCenter

For panels, headers, buttons and bars: `ScaleType = Enum.ScaleType.Slice`, `SliceCenter = ImageIds.SliceCenter.<name>` (pixels, `Rect.new(minX, minY, maxX, maxY)`). Left/right edges come from the alpha shape plus 2 px; top/bottom from where the colour stops changing, so bevels and the darker bottom strip stay in the corners. Use `SliceScale` (for example 0.5) when the element is drawn smaller than the source. Headers are curved ribbons: keep them near their 524x181 aspect. The wide 544x170 buttons have gently curved long edges, hence the large left/right corners.

## Currency

| Name | Asset id | Size | SliceCenter | Intended slot | Source (under `packs\`) | Licence |
|---|---|---|---|---|---|---|
| `coin` | `rbxassetid://137012994656003` | 256x256 | - | Coins counter, coin burst, prices (Theme.Images.coin) | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Currency\Coin\256px\Golden Coin 1st 256px.png` | Gvesster, unmodified |
| `coinStack` | `rbxassetid://119247303801148` | 256x256 | - | x2 Coins pass card | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Currency\Coin\256px\Golden Coin 2nd 256px.png` | Gvesster, unmodified |
| `cash` | `rbxassetid://123056166584750` | 256x256 | - | Coin Pouch / Coin Bag products | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Currency\Cash\256px\Golden Cash 1st 256px.png` | Gvesster, unmodified |

## Food

| Name | Asset id | Size | SliceCenter | Intended slot | Source (under `packs\`) | Licence |
|---|---|---|---|---|---|---|
| `food1Apple` | `rbxassetid://78901767518867` | 256x256 | - | Food tier 1, Food chip, THROW button | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Nature\Apple\256px\Apple 1st 256px.png` | Gvesster, unmodified |
| `food2Carrot` | `rbxassetid://101649748125654` | 256x256 | - | Food tier 2 | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Food\Carrot\256w\Carrot 1st 256px.png` | Gvesster, unmodified |
| `food3Blueberry` | `rbxassetid://115495909093387` | 256x256 | - | Food tier 3 | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Food\Blueberry\256w\Blueberry 1st 256px.png` | Gvesster, unmodified |
| `food4Pancake` | `rbxassetid://94211863694819` | 256x256 | - | Food tier 4 | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Food\Pancake\256px\Pancake 1st 256px.png` | Gvesster, unmodified |
| `food5Strawberry` | `rbxassetid://100987193154317` | 256x256 | - | Food tier 5 | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Nature\Strawberry\256px\Strawberry 1st 256px.png` | Gvesster, unmodified |
| `food6Cookie` | `rbxassetid://83677279268638` | 256x256 | - | Food tier 6 (Star Cookie) | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Food\Cookie\256px\Cookie 1st 256px.png` | Gvesster, unmodified |
| `goldenApple` | `rbxassetid://77195183609187` | 256x256 | - | Lucky Snack product | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Nature\Apple\256px\Golden Apple 1st 256px.png` | Gvesster, unmodified |
| `clover` | `rbxassetid://121200415142773` | 256x256 | - | Lucky Food pass, luck / odds rows | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Nature\Clover\256px\Clover 1st 256px.png` | Gvesster, unmodified |

## Eggs

| Name | Asset id | Size | SliceCenter | Intended slot | Source (under `packs\`) | Licence |
|---|---|---|---|---|---|---|
| `egg` | `rbxassetid://129711052988353` | 256x256 | - | Nest chip, egg icon | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Item\Egg\256px\Egg 1st 256px.png` | Gvesster, unmodified |
| `eggGolden` | `rbxassetid://135860371346060` | 256x256 | - | Golden mutation / Golden Hour egg | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Item\Egg\256px\Golden Egg 1st 256px.png` | Gvesster, unmodified |
| `eggCracked` | `rbxassetid://111769891099452` | 256x256 | - | Hatch Pad / hatch prompt | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Item\Cracked Egg\256px\Cracked Egg 1st 256px.png` | Gvesster, unmodified |
| `eggGoldenCracked` | `rbxassetid://75438553426818` | 256x256 | - | Golden hatch | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Item\Cracked Egg\256px\Golden Cracked Egg 1st 256px.png` | Gvesster, unmodified |

## Pets

| Name | Asset id | Size | SliceCenter | Intended slot | Source (under `packs\`) | Licence |
|---|---|---|---|---|---|---|
| `paw` | `rbxassetid://92139146603865` | 256x256 | - | Pets button (alt) | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Paw\256px\Paw 1st 256px.png` | Gvesster, unmodified |
| `pawGolden` | `rbxassetid://111096317153160` | 256x256 | - | Pets menu button | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Paw\256px\Golden Paw 1st 256px.png` | Gvesster, unmodified |
| `bunny` | `rbxassetid://120344069041459` | 256x256 | - | Pet placeholder icon (Meadow Bunny) | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Animal\Bunny\256px\Bunny 1st 256px.png` | Gvesster, unmodified |
| `bunnyGolden` | `rbxassetid://119076225461746` | 256x256 | - | Golden pet placeholder | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Animal\Bunny\256px\Golden Bunny 1st 256px.png` | Gvesster, unmodified |
| `heart` | `rbxassetid://134140450282248` | 256x256 | - | Hearts over Mama Hen while she eats | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Heart\256px\Heart 1st 256px.png` | Gvesster, unmodified |
| `heartGolden` | `rbxassetid://127086274860795` | 256x256 | - | Favourite / VIP heart | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Heart\256px\Golden Heart 1st 256px.png` | Gvesster, unmodified |

## Rarity

| Name | Asset id | Size | SliceCenter | Intended slot | Source (under `packs\`) | Licence |
|---|---|---|---|---|---|---|
| `starGreen` | `rbxassetid://89618810311477` | 256x256 | - | Rarity Uncommon | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Star\256px\Green Star 1st 256px.png` | Gvesster, unmodified |
| `starBlue` | `rbxassetid://121805778317330` | 256x256 | - | Rarity Rare | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Star\256px\Blue Star 1st 256px.png` | Gvesster, unmodified |
| `starPurple` | `rbxassetid://138197943627661` | 256x256 | - | Rarity Epic | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Star\256px\Purple Star 1st 256px.png` | Gvesster, unmodified |
| `starGolden` | `rbxassetid://95237364987917` | 256x256 | - | Rarity Legendary, rebirth stars | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Star\256px\Golden Star 1st 256px.png` | Gvesster, unmodified |
| `starRed` | `rbxassetid://130244902068760` | 256x256 | - | Rarity Mythic | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Star\256px\Red Star 1st 256px.png` | Gvesster, unmodified |
| `starWhite` | `rbxassetid://115561487370489` | 256x256 | - | Rarity Common (silhouette) | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Star\256px\Star White 256px.png` | Gvesster, unmodified |

## Menu

| Name | Asset id | Size | SliceCenter | Intended slot | Source (under `packs\`) | Licence |
|---|---|---|---|---|---|---|
| `book` | `rbxassetid://83020267370754` | 256x256 | - | Collection Book menu button | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Item\Book\256px\Blue Book 1st 256px.png` | Gvesster, unmodified |
| `upgrade` | `rbxassetid://105442170876884` | 256x256 | - | Upgrades menu button, Nozzle-too-weak fallback | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Upgrade\256px\Golden Upgrade 1st 256px.png` | Gvesster, unmodified |
| `shopBag` | `rbxassetid://139508046620157` | 256x256 | - | Shop menu button | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Shopping Bag\256px\Golden Shopping Bag 1st 256px.png` | Gvesster, unmodified |
| `settings` | `rbxassetid://75344542318578` | 256x256 | - | Settings menu button | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Settings\256px\Settings 1 1st 256px.png` | Gvesster, unmodified |
| `rebirth` | `rbxassetid://92693830085391` | 256x256 | - | Rebirth tab / confirm | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Rebirth and Auto Open\256px\Rebirth 1st 256px.png` | Gvesster, unmodified |
| `autoOpen` | `rbxassetid://88316640473508` | 256x256 | - | Auto-Thrower and Auto-Washer pass cards | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Rebirth and Auto Open\256px\Auto Open 1st 256px.png` | Gvesster, unmodified |
| `giftDaily` | `rbxassetid://113609896893963` | 256x256 | - | Daily Gift menu button | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Item\Gift\256px\Green Gift 1st 256px.png` | Gvesster, unmodified |
| `giftRed` | `rbxassetid://104733739456503` | 256x256 | - | Session gifts | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Item\Gift\256px\Red Gift 1st 256px.png` | Gvesster, unmodified |
| `giftPurple` | `rbxassetid://132101633066781` | 256x256 | - | Shop gift / product art | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Item\Gift\256px\Purple Gift 1st 256px.png` | Gvesster, unmodified |
| `calendar` | `rbxassetid://112064809101469` | 256x256 | - | Daily Gift 7-day row | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Item\Calendar\256px\Calendar 1st 256px.png` | Gvesster, unmodified |
| `chest` | `rbxassetid://123777567418339` | 256x256 | - | Coin Chest product | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Item\Chest\256px\Chest 1st 256px.png` | Gvesster, unmodified |
| `trophy` | `rbxassetid://90534310430839` | 256x256 | - | Leaderboard board | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Item\Trophy\256w\Golden Trophy 1st 256px.png` | Gvesster, unmodified |
| `crown` | `rbxassetid://75268815930921` | 256x256 | - | Top player / leaderboard #1 | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Item\Crown\256px\Crown 1st 256px.png` | Gvesster, unmodified |
| `friend` | `rbxassetid://87162985070999` | 256x256 | - | Friends bonus chip | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Player\Friend\256px\Friend 1st 256px.png` | Gvesster, unmodified |
| `stats` | `rbxassetid://122014440304383` | 256x256 | - | Odds Board | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Stats\256px\Stats 1st 256px.png` | Gvesster, unmodified |
| `house` | `rbxassetid://128270532183292` | 256x256 | - | Big Pen pass, Nest & Pen tab | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\House\256px\Green House 1st 256px.png` | Gvesster, unmodified |

## Passes

| Name | Asset id | Size | SliceCenter | Intended slot | Source (under `packs\`) | Licence |
|---|---|---|---|---|---|---|
| `vip` | `rbxassetid://74432797373209` | 256x256 | - | VIP pass | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Exclusive\VIP\256px\VIP 1st 256px.png` | Gvesster, unmodified |
| `lightning` | `rbxassetid://96884393653348` | 256x256 | - | Fast Wash pass | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Lighting\256px\Lighting 1st 256px.png` | Gvesster, unmodified |
| `lightningBlue` | `rbxassetid://133160907741952` | 256x256 | - | Strength chip (fallback for dumbbell) | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Lighting\256px\Blue Lighting 1st 256px.png` | Gvesster, unmodified |

## Timers

| Name | Asset id | Size | SliceCenter | Intended slot | Source (under `packs\`) | Licence |
|---|---|---|---|---|---|---|
| `clock` | `rbxassetid://80137667008414` | 256x256 | - | Golden Hour timer (day, fallback for sun) | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Item\Clock\256px\Clock 1st 256px.png` | Gvesster, unmodified |
| `clockGolden` | `rbxassetid://85624190990965` | 256x256 | - | Golden Hour timer (during), Golden Hour for everyone product | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Item\Clock\256px\Golden Clock 1st 256px.png` | Gvesster, unmodified |

## Ui

| Name | Asset id | Size | SliceCenter | Intended slot | Source (under `packs\`) | Licence |
|---|---|---|---|---|---|---|
| `close` | `rbxassetid://125849023029168` | 256x256 | - | Panel and Wash HUD close X (Theme.Images.close) | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\UI\Close Button\256px\Close Button 1st 256px.png` | Gvesster, unmodified |
| `checkButton` | `rbxassetid://80425175706771` | 256x256 | - | Confirm button | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\UI\Checkmark Button\256px\Checkmark Button 1st 256px.png` | Gvesster, unmodified |
| `check` | `rbxassetid://134390407618840` | 256x256 | - | Owned row check | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\UI\Checkmark\256px\Checkmark 1st 256px.png` | Gvesster, unmodified |
| `plus` | `rbxassetid://92170512522411` | 256x256 | - | Coins "+" badge | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\UI\Plus\256px\Plus 1st 256px.png` | Gvesster, unmodified |
| `minus` | `rbxassetid://139964362672474` | 256x256 | - | Decrease | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\UI\Minus\256px\Minus 1st 256px.png` | Gvesster, unmodified |
| `info` | `rbxassetid://120390818772508` | 256x256 | - | Throw and wash hint chips | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\UI\Info\256px\Info 1st 256px.png` | Gvesster, unmodified |
| `question` | `rbxassetid://84884273859724` | 256x256 | - | Help / odds info | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\UI\Question Mark\256px\Question Mark 1st 256px.png` | Gvesster, unmodified |
| `warning` | `rbxassetid://127132884655885` | 256x256 | - | Confirm dialog (Release, Rebirth) | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\UI\Warning\256px\Warning 1st 256px.png` | Gvesster, unmodified |
| `exclamation` | `rbxassetid://121715395379490` | 256x256 | - | New-button red dot / alert | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\UI\Exclamation Mark\256px\Exclamation Mark 1st 256px.png` | Gvesster, unmodified |
| `lock` | `rbxassetid://89551385335734` | 256x256 | - | Locked zone, locked row | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Item\Lock\256px\Lock 1st 256px.png` | Gvesster, unmodified |
| `unlock` | `rbxassetid://123175600875609` | 256x256 | - | Zone unlocked | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Item\Lock\256px\Unlock 1st 256px.png` | Gvesster, unmodified |
| `skip` | `rbxassetid://89229891733047` | 256x256 | - | Next / arrow stand-in | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\UI\Skip\256w\Skip 1st 256px.png` | Gvesster, unmodified |
| `cursor` | `rbxassetid://95100915483962` | 256x256 | - | Onboarding pointer hand | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\UI\Cursor\256px\Cursor 1st 256px.png` | Gvesster, unmodified |
| `trash` | `rbxassetid://75574875783952` | 256x256 | - | Release pet | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Trash Can\256w\Trash Can 1st 256px.png` | Gvesster, unmodified |
| `musicOn` | `rbxassetid://138914666847088` | 256x256 | - | Settings music on | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Music ON\256w\Music ON 1st 256px.png` | Gvesster, unmodified |
| `musicOff` | `rbxassetid://101075917479243` | 256x256 | - | Settings music off | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Music OFF\256w\Music OFF 1st 256px.png` | Gvesster, unmodified |
| `soundOn` | `rbxassetid://96354769678927` | 256x256 | - | Settings SFX on | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Sound ON\256w\Sound ON 256px.png` | Gvesster, unmodified |
| `soundOff` | `rbxassetid://104282678124897` | 256x256 | - | Settings SFX off | `icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\Main\Sound OFF\256w\Sound OFF 256px.png` | Gvesster, unmodified |

## Panels

| Name | Asset id | Size | SliceCenter | Intended slot | Source (under `packs\`) | Licence |
|---|---|---|---|---|---|---|
| `panelTall` | `rbxassetid://80852325554606` | 654x896 | 17,66,636,841 | Panel body, tall (phone panels, Book) | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Information\Frame.png` | SunGraphica, commercial |
| `panelWide` | `rbxassetid://131122338240694` | 920x780 | 20,63,899,726 | Panel body, wide (PC 900x620 panels) | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Map\Frame.png` | SunGraphica, commercial |
| `panelSmall` | `rbxassetid://99169026601721` | 653x406 | 17,35,635,372 | Confirm dialog body, toasts | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Exit\Frame.png` | SunGraphica, commercial |
| `cardCream` | `rbxassetid://128626937748773` | 352x352 | 14,15,337,327 | Item / pet card | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\HUD\Frame Item selector-2.png` | SunGraphica, commercial |
| `slotDark` | `rbxassetid://136120266721636` | 160x159 | 9,33,150,120 | Empty slot (Pen, Storage) | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\HUD\Frame Item selector.png` | SunGraphica, commercial |
| `cardBrown` | `rbxassetid://123662241834255` | 184x227 | 10,31,173,151 | Shop product card | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Shop\Rectangle 1.png` | SunGraphica, commercial |
| `insetBrown` | `rbxassetid://131506410028320` | 279x217 | 10,32,268,181 | Reveal card frame, image well | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Reward\Image Frame.png` | SunGraphica, commercial |
| `insetBar` | `rbxassetid://115315227176332` | 372x82 | 8,25,363,53 | Objective / info strip | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\HUD\Mission Frame.png` | SunGraphica, commercial |
| `insetField` | `rbxassetid://74034196146632` | 534x72 | 8,21,525,47 | Text field / Codes input | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Log in\Info box 1.png` | SunGraphica, commercial |

## Headers

| Name | Asset id | Size | SliceCenter | Intended slot | Source (under `packs\`) | Licence |
|---|---|---|---|---|---|---|
| `headerRed` | `rbxassetid://104177539507393` | 524x181 | 172,52,351,123 | Title ribbon: Confirm dialog | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Game over\Header.png` | SunGraphica, commercial |
| `headerOrange` | `rbxassetid://130281515201132` | 524x181 | 172,54,351,123 | Title ribbon: Pets | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Victory\Header.png` | SunGraphica, commercial |
| `headerYellow` | `rbxassetid://140410175765434` | 524x181 | 172,53,351,123 | Title ribbon: reward / Daily (no green ribbon in kit) | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Reward\Header.png` | SunGraphica, commercial |
| `headerCyan` | `rbxassetid://99740927877972` | 524x181 | 172,56,351,117 | Title ribbon: Book | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Log in\Header.png` | SunGraphica, commercial |
| `headerBlue` | `rbxassetid://110025525897194` | 524x181 | 172,57,351,117 | Title ribbon: info panels | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Mails\Header.png` | SunGraphica, commercial |
| `headerPurple` | `rbxassetid://71838995260808` | 524x181 | 172,55,351,120 | Title ribbon: Shop | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Achievement\Header.png` | SunGraphica, commercial |
| `headerMagenta` | `rbxassetid://99790016409658` | 524x181 | 172,54,351,120 | Title ribbon: Upgrades (no green ribbon in kit) | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Upgrade\Header.png` | SunGraphica, commercial |
| `headerBrown` | `rbxassetid://85659932437899` | 524x181 | 172,54,351,120 | Title ribbon: Settings (grey stand-in) | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Levels 1\Header.png` | SunGraphica, commercial |

## Buttons

| Name | Asset id | Size | SliceCenter | Intended slot | Source (under `packs\`) | Licence |
|---|---|---|---|---|---|---|
| `buttonWideGreen` | `rbxassetid://102652304218937` | 544x170 | 101,57,441,106 | Primary button (CLAIM, Equip Best) | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Levels 1\Button Footer.png` | SunGraphica, commercial |
| `buttonWideYellow` | `rbxassetid://118398299460470` | 544x170 | 101,26,441,123 | Reward / secondary button | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Pause\Button Yellow.png` | SunGraphica, commercial |
| `buttonWideBlue` | `rbxassetid://137162390108698` | 544x170 | 101,32,441,110 | Info / neutral button | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Pause\Button Blue.png` | SunGraphica, commercial |
| `buttonWideRed` | `rbxassetid://115990147405613` | 544x170 | 101,61,441,103 | Danger button (Release, Rebirth) | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Options\Button Red.png` | SunGraphica, commercial |
| `buttonPriceGreen` | `rbxassetid://78305945255704` | 279x95 | 12,12,265,57 | Affordable price button | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Upgrade\Footer button green.png` | SunGraphica, commercial |
| `buttonPriceRed` | `rbxassetid://72069837272018` | 279x95 | 12,10,265,74 | Unaffordable price button | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Upgrade\Footer button red.png` | SunGraphica, commercial |
| `buttonSquareGreen` | `rbxassetid://135745096766075` | 163x163 | 10,9,152,132 | Square icon button, green | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Victory\Green Button.png` | SunGraphica, commercial |
| `buttonSquareRed` | `rbxassetid://90680444813399` | 163x163 | 10,12,152,113 | Square icon button, red | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Victory\Red button.png` | SunGraphica, commercial |
| `buttonSquareYellow` | `rbxassetid://83739327873049` | 163x163 | 10,11,152,132 | THROW button face, square yellow | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Victory\Yellow Button.png` | SunGraphica, commercial |
| `buttonSquareBlue` | `rbxassetid://87772310877516` | 159x159 | 10,26,148,129 | Menu tile (phone left column) | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\HUD\Button QS copy 13.png` | SunGraphica, commercial |
| `tabSelected` | `rbxassetid://113735189872393` | 183x171 | 11,32,172,135 | Tab, selected | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Items\Selected button.png` | SunGraphica, commercial |
| `tabDeselected` | `rbxassetid://124274102183137` | 183x171 | 11,12,172,138 | Tab, not selected | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Items\Deselect button.png` | SunGraphica, commercial |
| `iconTile` | `rbxassetid://107540980440879` | 113x113 | 9,10,103,89 | Small icon backing tile | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Upgrade\Icon button.png` | SunGraphica, commercial |

## Bars

| Name | Asset id | Size | SliceCenter | Intended slot | Source (under `packs\`) | Licence |
|---|---|---|---|---|---|---|
| `barTrack` | `rbxassetid://83214103981051` | 404x43 | 10,9,393,29 | Progress bar track (wash, strength, price progress) | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Upgrade\Slider.png` | SunGraphica, commercial |
| `barFill` | `rbxassetid://99600916225593` | 276x21 | 7,6,268,14 | Progress bar fill | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Upgrade\Slider Filler.png` | SunGraphica, commercial |

## Badges

| Name | Asset id | Size | SliceCenter | Intended slot | Source (under `packs\`) | Licence |
|---|---|---|---|---|---|---|
| `stars3` | `rbxassetid://73407029534936` | 579x177 | - | 3-star reward badge | `ui-kits\sungraphica-casual-game-interface-kit\files\Casual Game Interface Kit Full ver\PNG - Files\1080p\Victory\Stars.png` | SunGraphica, commercial |

## Still missing (not in these packs)

- Dumbbell / Strength icon (using `lightningBlue`), sun and gold sun for Golden Hour (using `clock` / `clockGolden`), nozzle, nest, Mama Hen face for the Odds Board.
- Arrows (left, right, up, down): neither pack has them; `skip` and `cursor` are stand-ins.
- Rarity frames and backgrounds in the 7 rarity colours plus a Secret rainbow frame; mutation badges (Shiny, Golden, Rainbow). Stars stand in for rarity; there is no grey Common star (`starWhite` is a flat silhouette).
- Green and grey title ribbons (Upgrades, Daily, Settings) and a purple button for Robux purchases: the kit has none.
- Pressed and disabled button states; tooltip, toast and scroll bar art in the kit style.
- Icons for the 15 creatures (only a bunny exists) and egg crusts per zone.
- VFX textures: sparkle, confetti, mud splat, water spray, light rays, crack overlay.
- Game icon, thumbnails, pass and product art (pass cards reuse icons for now).
