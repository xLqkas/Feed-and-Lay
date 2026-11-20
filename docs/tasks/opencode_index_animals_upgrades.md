# Task for OpenCode: fix Upgrade prices, rebuild the Index, replace NEXT with an Animals panel

Owner: OpenCode, in the open Studio place "Feed an Lay". Do NOT save, publish, commit or push. Do not touch SaveStore or the save mutex/pendingSaves logic. Style: docs/ui_style_spec.md (Chunky Nest), shared Kit components only.

## Do not touch (Gemini may be working on the throw cinematic)
Loop.Throw, Loop.Cam, Loop.Fx, Loop.Hatch, any Loop.ThrowCinematic module. You own UI.Kit / UI.Theme for this task; if Gemini has edited them, read the current version first and don't undo its changes.

Order: Part 1 first (bug), then 2, then 3. Report after each part so a broken part does not block the others.

## Part 1: BUG: prices don't show in the Upgrades panel
User screenshot: every upgrade row's buy box on the right is an empty grey rectangle with an orange progress bar under it. No price, no button text, no buy colour.
- Find the root cause before changing anything (likely candidates: price text never set, text colour equals the face colour, the label sized to zero by fit()/FLBaseHeight/FLSquare, ZIndex under the face, TextScaled with a too-small UITextSizeConstraint, or the button left in the "disabled" role after the Chunky refactor). Report it with script and line.
- Each row must show: icon, name, short effect text ("now X → next Y"), level as "Lv 3/10", a progress bar that means level progress (say what it shows; if it means nothing, remove it), and a 3D buy button with the price and the currency icon. Green when affordable, grey "disabled" with the price still visible when not, "MAX" when maxed.
- Button updates live when coins change (no reopen needed).
- Long descriptions must not overflow (the Stone Weights row text is cut off).

## Part 2: Rebuild the Index (today it is the "Book" panel in Loop.Menus)
Target (user's reference screenshot of another game; copy the layout idea, not its colours, names or text):
- Wide window, purple header with a big outlined title ("Index") and red square X.
- Under the header a row of tabs. For now only one tab, "World". Do not build a "Limited" tab until limited creatures exist.
- Left: a large zone card for the selected zone (zone name, zone art or a render, completion %). Zones listed vertically in a scroll, one card per zone from Economy.Zones; tapping a zone selects it.
- Middle: grid of creature tiles for that zone, tile background in the rarity colour from the spec.
  - Found: render of the creature (ViewportFrame factory from the spec), name on top, rarity word at the bottom.
  - Not found: black silhouette of the same model, "???" on top, rarity word at the bottom.
  - Claimable (found, not claimed yet): small badge/dot plus a gentle pulse.
- Under the grid: zone progress bar "2/8" with the zone's reward icon at the end.
- Right: detail card for the selected tile: big render or silhouette, name or "???", rarity, and the CLAIM button using the existing BookClaim remote (server already validates and pays once). Claimed shows "CLAIMED".
- Bottom: overall progress bar "Unlocked: 33/164" with the book icon.
- Keep using the existing Ctx.book data and BookClaim remote. Do not change what claiming pays.
- Zone completion reward (the reference gives one per finished zone): do NOT add a new reward or server code yet. Show the bar; leave the reward slot as a placeholder icon and say so. The user will decide the reward.
- The left-column menu tile is renamed "Index" with the book icon (keep the notification dot for unclaimed).

## Part 3: Replace the "NEXT" tile with an Animals button and a "My Animals" panel
Remove the right-column "NEXT ??? UNSEEN 0/8 eggs" tile (keep any data it used if something else needs it). Put an "Animals" menu tile (paw icon, label under it) in its place.

"My Animals" panel (target is the user's reference): docked on the RIGHT side of the screen, not centred.
- Header: "My Animals", a count pill with paw icon "placed/capacity" (for example 20/20), red X.
- Section label "ON YOUR PLOT 20/20" (count in green).
- Scrolling list of rows. Each row: creature render on a rarity-coloured plate; name in rarity colour; a size/mutation tag if the pet has one (for example BIG, SHINY); income per second in green; a blue PICK UP button and a red SELL button stacked on the right.
- Pinned at the bottom: a big orange EQUIP BEST button.
- Second section below the plot list: "IN STORAGE" with the pets not on the plot, each with a PLACE button instead of PICK UP.

Server actions (read EggService / EggRules / SaveSchema first; reuse what exists, add only what is missing, same validation standard as the rest of V3: types, NaN, ownership by pet id, rate limit through _wrap, no Instances from the client):
- PickUp(petId): moves a pet from the plot to storage. Server removes its model from the pen.
- Place(petId): moves from storage to the plot if there is a free slot.
- Sell(petId): removes the pet and pays coins. Sell value = `SELL_SECONDS_OF_INCOME * pet income per second`, constant in Economy marked TODO-BALANCE (start with 60). Ask for confirmation in the UI for Epic and above ("Sell Mythic Poltergeist for 1.2K?"). Never sell the last pet the player owns.
- EquipBest(): fills the plot slots with the highest-income pets, moves the rest to storage. One server call, no loop of client calls.
- If storage does not exist in the save yet, add it to SaveSchema with a safe default (empty list) and sanitize clamps; old saves must load and keep all their pets on the plot. If the design can't fit without a big save change, STOP after the UI and write down what the server needs instead of forcing it.

## Part 4: small fixes from the architect's re-check of your training code (all items there PASS)
- MEDIUM, Loop.Lift placeX2 (~250-264): the random x2 spot can land on the Lift training bar/title/hint (~y 0.6h-0.62h) or on the left/right menu columns (Hud ~98-114), so a tap can hit the wrong control. Pick a spot and reject/retry against the AbsolutePosition/AbsoluteSize of Hud.leftColumn, Hud.rightColumn, the training bar, title and hint (and the new Animals tile), or limit it to the middle 40-60% of width and 0.25-0.5h. Check on phone.
- LOW, Loop.Lift clearX2 (~283-298): Visible=false is set in the same frame as Motion.pop/fadeOut, so the pop is never seen. Hide after the fade completes.
- LOW, TrainingRules.clear (~173): resets warnedTick/warnedMinute, so the cap warn fires once per respawn instead of once per player. Move the reset to player join only.

## Test (Play Solo + Device Simulator phone; phone is required this time)
1. Upgrades: every row shows price and level; buy one, price and level update; cannot afford shows grey with price; max shows MAX.
2. Index: zone switch, found vs silhouette tiles, detail card, claim once (second claim impossible), counters correct.
3. Animals: pick up, place, sell (with confirm for Epic+), equip best; plot models update; counts update; rejoin keeps storage and plot (API Services on, no Studio no-save flag).
4. Abuse: fire the new remotes with someone else's pet id, a missing id, NaN, and fast in a loop: rejected, no dupes, no coins.
5. Only one window open at a time; X, Escape and tap outside close; nothing opens on join.
6. No new Output errors. Studio back in Edit mode.

## Report
Root cause of the missing prices; per part: scripts and lines changed; any save change; final sell constant; screenshots of Upgrades, Index and My Animals on desktop and phone; test results (mark anything not run "not verified"); a CHANGES.md bundle for the architect like last time.
