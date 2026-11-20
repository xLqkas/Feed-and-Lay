# Task for OpenCode: fix the My Animals panel (review findings) and remove the NEXT card

Owner: OpenCode, in the open Studio place "Feed an Lay". Do NOT publish, commit or push. Save only when the user says so. Do not touch SaveStore or the save mutex/pendingSaves logic. Gemini's Loop.ThrowCinematic and Loop.Throw: do not touch.

The architect reviewed your Part 3 (read-only). The server side is sound for money and duplicates. The client side is broken: the panel cannot open with real pets. Fix in this order and test WITH REAL PETS this time (hatch a few, or give the test profile pets via the Studio-only FLDebugProfile attribute).

## HIGH
1. **Animals panel errors with any pet, so it never opens.** Loop.Menus ~422 and ~455 call `Economy.petIncome(pet)`, which reads `pet.Species` / `pet.Mutation` (capitalised). Client pets are `{id, species, mutation, rarity, pen, income}` (EggService.snapshot, Hatch ~253), so `CreatureByName[nil].Income` throws. `refreshAnimals()` runs before `Kit.showPanel` (~821), so the tile does nothing. Fix: use `pet.income` (server-supplied). Sort by income, then id.
2. **Pen models and the client list go stale after every action.** Nothing calls `Pen.sync()` (or Pen.add/remove) after PickUp, Place, Sell or EquipBest; Pen.sync only runs at startup (Main ~120). A picked-up or sold pet stays in the pen; a placed one never appears. The pen is client-rendered, so update it client-side: call `Pen.sync()` in `petAction` after the local update, or have Loop.Pen listen to the "pets" event.
3. **EquipBest corrupts the client list.** Loop.Menus ~477 sets `p.pen = true` for every pet because the server only returns `count` (EggService ~362). UI shows 30/6, later actions fail ("Already in storage"). Fix: server returns the list of `{id, pen}` (or the placed ids) and the client applies exactly that. Use the same pattern for all four actions: the server reply is the truth.

## MEDIUM
4. **Ghost pet after a reveal.** The server creates the pet at hatch, so it can be sold or picked up while the reveal plays; then Loop.Hatch (~203-211, ~232-240) calls `Pen.add({... pen = true})` anyway. Fix: before Pen.add, check the pet is still in `Ctx.pets` with `pen == true`.
5. **Old pets without a pen flag load into storage and earn nothing.** SaveSchema ~177 `pen = bool(p.pen, false)`. Spec says old saves keep pets on the plot. Fix: default `true` and let `fitPen` (~99) demote the surplus; give fitPen's sort an id tie-break.

## LOW
6. EquipBest tie-break unstable (EggService ~354-357): add `or (a.pen and not b.pen) or a.id < b.id` so equal pets don't churn.
7. Sell confirmation uses species rarity only (Menus ~433). Confirm when `sellValue >= a threshold` (TODO-BALANCE, start at 10 minutes of the player's current income) OR the pet has a mutation OR rarity is Epic+.
8. `PenSlots` is never set as a player attribute (Main ~509-520), so the count pill always shows the fallback. Set it (and keep it updated when slots change).
9. `function petAction` (Menus ~466) is a global defined after its users; declare `local petAction` before first use (strict mode warning).

## Plot proximity (user decision; default below)
Every pet action requires `isNear(player, "Ledge")` and fails with "Walk to your plot first!", although the panel opens anywhere. DEFAULT: remove the proximity check from all four actions (they only change data; the pen updates wherever the player is). Keep every other check. If the user says otherwise, keep it only on Place/PickUp and grey those buttons out with "Go to your plot" when away.

## Remove the NEXT card (user request, missed last round)
The user wants the right-side "NEXT ??? UNSEEN 0/8 eggs" card gone and the Animals tile in its place. It is the Hud next-creature card (not in Menus). Remove it from the HUD (or hide it behind a flag if other code reads it), move the Animals tile into that spot, and update the x2 placement avoid-list accordingly.

## Windows sit at the bottom of the screen and get cut off (user report, do FIRST)
All windows (Inventory, Index/Book, Upgrades, Shop) open low on the screen and their bottom is cut off (user screenshots in the Studio Device Simulator: the window title sits around the middle of the screen and the body runs off the bottom). They must open centred on screen and fully visible on every device.
- Find the cause before changing anything. Kit.shell sets AnchorPoint 0.5,0.5 and Position (0.5, 0, 0.5, 24), so check what moves or stretches it: fit() / FLBaseHeight / FLSquare sizing, the UIScale on the root, the parent frame (screen.root) size/position or a UIListLayout on it, IgnoreGuiInset, and the ribbon offset added above the body.
- Rule: the whole window, ribbon/header and X included, stays inside the safe area with a margin, centred, on desktop 1920x1080, phone portrait and landscape, and tablet. If the window is taller than the screen, scale it down (UISizeConstraint/UIScale), never let it run off. My Animals stays docked right but vertically centred and fully visible.

## Wrong icons: almost everything shows a star (user report)
The Index tile shows a star, and most other UI icons are stars too. Each icon must match its label. Index = book.
- Find why: probably IconKeys missing from UI.Icons (or misspelled) and falling back to a default star. List every IconKey used in the UI and what it currently resolves to.
- Map each to the closest icon from the 31 uploaded ones (icon pack "1st Outline" set), for example: Index = Book, Upgrades = Upgrade arrow, Shop = Shopping Cart / Shopping Bag, Animals = Paw, Inventory/eggs = Egg, coins/cash = Cash or Coin, strength = Arm, gems = Diamond, settings = Settings, close = UI X, info = Info, lock = Lock, trophy/goals = Trophy, gift = Gift.
- If a needed icon was not uploaded, do NOT upload it yourself: list the exact pack file path for the user to upload and use the closest uploaded one until then.
- Remove the star fallback for real UI (keep a visible "missing icon" warning in Output instead) so a missing key is noticed.

## Test (Play Solo + Device Simulator phone; both required)
1. With 8+ real pets: open Animals, rows show render, name, mutation tag, income. Count pill shows placed/PenSlots.
2. Pick up, place, sell (confirm appears per rule 7), equip best: pen models update immediately, counts right, no errors; rejoin (API Services on, no no-save flag) gives the same state.
3. Sell or pick up a pet during its hatch reveal: no ghost model.
4. Fire the remotes with bad ids, someone else's id, fast loops: rejected, no coins, no dupes.
5. NEXT card gone; Animals tile in its place; x2 never covers it.
6. No new Output errors. Studio back in Edit mode.

## Report
Per item: script, lines, change. Test results per item (anything not run = "not verified"). Screenshots of My Animals with pets on desktop and phone. Update CHANGES.md.
