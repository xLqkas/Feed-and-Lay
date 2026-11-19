# Image upload list (v3 loop HUD)

Written 2026-11-19 with VS-6 to VS-8. Nothing has been uploaded: every image slot below draws the UI kit's coloured placeholder disc. To fill one, upload the file (Gvesster icons **unmodified**, licence forbids edits), then paste the `rbxassetid://` id where the "Goes in" column says.

Gvesster root: `C:\Users\filip\Documents\GitHub\AIGuidesAndTooling\assets\packs\icons\gvesster-free-icon-pack-basic\files\Free Icon Pack v3.1 (Basic)\` (see `assets-inventory.md`).

| Slot | Where it shows | Source file (under the Gvesster root) | Goes in |
|---|---|---|---|
| Coin | Coins pill (HUD bottom-left / phone top-left), coin burst | `Currency\Coin\256px\Golden Coin 1st 256px.png` | `src/client/UI/Theme.luau` `Theme.Images.coin` |
| Close | Wash HUD X button, panel close | `UI\Close Button\256px\Close Button 1st 256px.png` | `Theme.Images.close` |
| Apple (food) | Food chip icon (red disc now) | `Nature\Apple\256px\Apple 1st 256px.png` | add `Theme.Images.food1`, use in `Loop/Hud.luau` `chip(... "FoodChip" ...)` |
| Egg | Nest chip icon (cream disc now) | `Item\Egg\256px\Egg 1st 256px.png` | add `Theme.Images.egg`, Nest chip in `Loop/Hud.luau` |
| Info / hint | Throw hint and wash aim hint chips (blue disc now) | `UI\Info\256px\Info 1st 256px.png` | optional; `Loop/Hud.luau` `chip(... C.info ...)` |
| Nozzle too weak | Wash HUD nozzle chip (red disc now) | missing art (nozzle icon, `design-v3.md` 7.5 item 6); fallback `Main\Upgrade\256px\Golden Upgrade 1st 256px.png` | `Loop/Hud.luau` `NozzleChip` |
| Heart | Hearts over Mama Hen while she eats (text glyph now) | `Main\Heart\256px\Heart 1st 256px.png` | `Loop/Hen.luau` (`Fx.floatText` "♥") |
| Sparkle / splat / confetti | Particle textures (default Roblox sparkle now) | missing art (`design-v3.md` 7.5 item 7) | `Loop/Fx.luau` `Fx.burst` |

Not images but also placeholders: Mama Hen, eggs and all pets are primitive parts (P-9 art pass).
