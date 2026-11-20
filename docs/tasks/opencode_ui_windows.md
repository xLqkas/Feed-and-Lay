# Task for OpenCode: fix the stuck Inventory window, then build the Index / Shop / Animals windows

Owner: OpenCode. It is the ONLY agent allowed to edit the open Studio place "Feed an Lay" right now.
Scope: UI only (StarterPlayer.StarterPlayerScripts.UI.* and Loop.* UI modules). No server, save, economy or gameplay code.
Rules: do NOT save, publish, commit or push (the user saves). Read every script in full before editing it.
Context to read first: docs/ui_style_spec.md (Chunky Nest), docs/phase0_decisions.md.

## Part 1: Bug fix (do this first, one small change at a time)

Symptom (user screenshot, Studio Device Simulator, Client view): the Inventory window is stuck on screen.
- Two windows are visible at once: the purple Book window behind and the teal Inventory window in front.
- Two red X buttons are visible and clicking them does nothing.
- The window opened by itself. It must NOT open on its own.

Required behaviour:
1. Inventory (the washer egg picker) opens ONLY when the player presses the Inventory/hotbar action, or when they walk up to the washer and choose to wash. It never opens automatically on join or respawn.
2. Only ONE window is open at a time. Opening one closes the others (check Kit.showPanel / Kit.hidePanel / Kit.onPanel in UI.Kit and Menus.show in Loop.Menus).
3. The X always closes its window. Escape and tapping outside the window also close it.
4. Closing restores the HUD (Hud.setHidden("panel", ...)).

Hypotheses to check (NOT confirmed, nobody has run this):
- Your last change to Loop.Hud (BagTap / food tap overlays, FLBaseHeight=52) or to UI.Kit fit()/FLSquare may have put an invisible element over the X, so the click never reaches it. Check ZIndex, Active and Size of everything over the close button.
- Kit.shell sets every panel to ZIndex 60 and Visible=false. Find whoever sets Visible=true without going through Kit.showPanel (Loop.Wash chooser, Loop.EggBag, Loop.Inventory washMode, Loop.Hatch).
- Loop.EggBag and Loop.Inventory both build an egg panel. Confirm only one is meant to exist; if both are, say so and do not delete either without telling the user.
- The window sits low and is cut off at the bottom in the Device Simulator. Check Kit.shell position (0.5, 0, 0.5, 24) and size against small viewports.
Prove the root cause (print or inspect in Play Solo) before you change anything, and report it.

## Part 2: Build the target windows (reference screenshots attached by the user)

Target look: dark slate/pine body, thick dark outline, gradient header with a big bold outlined title, red square X, rounded cards, big green buy buttons with a darker bottom edge. Use the Chunky Nest tokens in docs/ui_style_spec.md. Do not copy the reference game's exact colours or layout; keep Feed and Lay's own palette.

Build these three using the shared Kit components (no one-off styling):
1. **Animals** (reference: "My Animals"): panel docked on the RIGHT side, header with count pill (e.g. 20/20) and X, a section label ("ON YOUR PLOT 20/20"), scrolling list of rows (creature render on the left on a rarity-coloured plate, name, rarity word, income per second, PICK UP and SELL buttons), and a big orange EQUIP BEST button pinned at the bottom.
2. **Index** (reference: "Animal Index"): purple header, tabs under it, a left column of biome tiles with a completion %, a grid of rarity tiles (found = render + name, not found = black silhouette + "???" + rarity word), a detail card on the right, and an "Unlocked: x/y" progress bar at the bottom. Use the game's real zones/creatures from Economy, not the reference's animals.
3. **Shop** (reference: Featured egg card with odds + gamepass cards): yolk-coloured header with X, a "Featured" pill, an egg card with its odds row and Buy x1 / x3 / x10 buttons, then a "Gamepasses" pill and two-per-row gamepass cards. The Shop is NOT built yet. Build the shell and layout only. Do NOT wire any real purchase, MarketplaceService call or Robux price; show placeholder prices and make the buttons print a message. The user will decide products later.

HUD (reference screenshot 4): left column buttons Index and Shop (icon + label under it), currency stack bottom-left. Keep existing HUD behaviour; only restyle and re-place.

Icons: do NOT upload anything. Use IconKey placeholders. At the end list the exact icon pack file paths I need to upload (use only the "1st Outline" variants).

## Test (Play Solo + Device Simulator: desktop, phone portrait, phone landscape, tablet)
- Join: no window is open. Open and close each window with X, Escape and outside tap.
- Open two windows in a row: the first closes.
- Wash an egg from the picker and hatch it, die in the washer and respawn: UI intact, no stuck window.
- Output has no new errors. Studio back in Edit mode afterwards.

## Report (only what you ran; mark the rest "not verified")
- Root cause of the stuck window, with script and line.
- Per part: scripts changed, lines, what changed.
- Screenshots of Animals, Index, Shop and HUD on desktop and phone.
- Icon upload list.
- Anything you did not do or decided differently.
