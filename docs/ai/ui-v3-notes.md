# UI v3 restyle notes

Written 2026-11-19. Implements `ui-style-spec.md` on the v3 slice. Commits on `v3`: `636efad` (restyle), `cdef1ef` and `5847e84` (fixes from the play runs). Studio and repo scripts are identical (26 / 26 client UI and Loop scripts, length and hash checked).

## What changed, in one line each

- `src/client/UI/Theme.luau`: tokens from the spec's Blend (LightDock base): type scale (hero 80 ... small 16), ink `#4A3424`, outline `#2A2B31`, panel rim, disabled, NEW-sticker colours, button roles incl. `priceOk` / `priceNo`, button art and ribbon per panel. Holds the preset switch.
- `src/client/UI/Motion.luau` (new): every UI tween, by name, taken from the preset modules (table below). Feature code calls `Motion.play / pop / scaleTo / pulse / bob / shake / roll / fly / float / fadeOut`; no `TweenInfo` outside it in the UI.
- `src/client/UI/Kit.luau`: art-backed buttons (9-slice `buttonWide*`, `buttonPrice*`, `buttonSquare*`), menu tiles, notification dot, tutorial pointer, panel shell (cream `panelWide` body, dark rim, ribbon, overhanging icon and close), scroll area, backless currency rows, two toast lanes, objective line and goal bar, art progress bar, rarity cards.
- `src/client/UI/ImageIds.luau` and `src/client/UI/Presets/*` were in the repo only; they are now in the place too (Studio was missing them).
- Feature code touched only for UI hooks: `Hud.luau`, `Menus.luau` (rebuilt screens); `Hatch.luau` (calls `Hud.revealLand`, hides the pet's name tag during the reveal); `Main.client.luau` (feeds `Hud.setGoal` for steps 10 and 12); `Lift.luau` and `Fx.luau` / `Pen.luau` (text strokes, Motion instead of raw tweens); `Throw.luau` (press scale is now `MotionScale`). No server code changed.

## Screens now (before / after shots under `docs/ai/shots/ui-v3/`)

| Screen | Now | PC | Phone | Shots |
|---|---|---|---|---|
| HUD corners | Book tile left, Upgrades tile right (104 px `buttonSquareBlue`, icon overhangs, label on the edge), backless stack Coins / Nest / Strength / Food under the left column, objective top centre | PASS | PASS | before 01, 04; after 01, 05, 15, 22 |
| Objective + goal bar | 40 px stroked line, old line fades up, new one pops; mini bar "50 / 80" for steps 10 and 12; hidden while a panel is open | PASS | PASS (line only) | after 06, 25 |
| Tutorial pointer | `cursor` image bobbing at the tile (mirrored for the right column); dot with count pulses | PASS | PASS | after 09, 15, 22 |
| World arrow trail | unchanged `Trail.luau` chevrons (already the spec's look); not re-timed to 0.85 s | NOT RUN (not changed) | - | after 15 |
| Food selector | Food row with the current food icon (apple, carrot, ...); tap pops the icon and explains | PASS (look) | PASS (look) | after 01 |
| Upgrades (shop rows) | ribbon panel, `cardCream` rows, `iconTile` icons, art price buttons green / red live, progress bar under red prices, gold outline on the row the sign opened, Owned check when maxed, shake + "Not enough coins!" | PASS | PASS | before 02; after 02, 16, 17, 23 |
| Book (cards) | grid of rarity-filled cards with the pet model, "???" black silhouettes, +X/s chip, "!" dot, CLAIM art button, check when claimed, coins fly to the counter | PASS | PASS | before 03; after 03, 04, 10, 20 |
| Wash | art bar (green fill), stroked hint, nozzle warning row, close icon, floating numbers via Motion | PASS | NOT RUN at phone size | after 08, 13 |
| Hatch reveal | white flash, slot roll in hero / rarity colour, land pop, NEW! sticker on a first catch | PASS | NOT RUN at phone size | after 14, 19, 21 |
| Throw meter | thicker rim, shaded bands, SWEET label, golden star burst | PASS | NOT RUN at phone size | after 07, 12 |
| Lift timing ring | white target and gold ring with dark rims, art Strength bar, stroked hint, MISS / GOOD words, unlock stamp via Motion | PASS | PASS after a fix (bar narrowed to 55 %, fix not re-shot) | after 18, 24 |
| Pen income labels | name tag and `+X` floaters with a real dark stroke | PASS (look) | - | after 15 |
| Toasts | text only; gain green / error red above the hotbar (bottom edge while a panel is open), announce gold under the objective | PASS | PASS | after 11, 17, 20 |
| Station mode (C10) | menu columns slide off while throwing, washing, lifting, revealing; back with overshoot | PASS | PASS | after 12, 18 |

Play runs: two fresh-save runs in Studio play mode (DataStore off, so every run is a fresh profile): run 1 steps 1-12 in about 6 minutes of tool time, run 2 steps 1-12 in about 4 minutes. Washing was driven by a scripted aim tracker sending `SprayHits` at the visible mud (MCP mouse moves are too coarse), as in the earlier sessions. Console over run 2: no errors; only the known DataStore-off messages and the old `rbxassetid://203785492` warning. Run 1 found one real error (goal bar `Fill` lookup, it stopped Main's objective loop at step 12); fixed in `cdef1ef` and confirmed in run 2.

Not verified: touch and gamepad input (no MCP support); the last three fixes in `5847e84` (full-screen shade / flash, pet tag hidden under reveal text, narrower phone lift bar) are code-reviewed and mirrored but not seen in play.

## How to switch preset

In Studio (Edit mode), select ReplicatedStorage and add a string attribute `FLUiPreset` with one of `Blend` (default, the spec), `LightDock`, `DarkTiles`, `SlimPills`, `GlassPanels`, then press Play. From the command bar: `game.ReplicatedStorage:SetAttribute("FLUiPreset", "DarkTiles")`. Remove the attribute to go back. A non-Blend preset overlays that game's colours, button and rarity colours, panel radius and stroke, and every motion it has a same-named tween for, and draws panels and buttons in code (no SunGraphica art), so the comparison shows the preset's own look (shot after 26). Known gap: in code-drawn mode the panel keeps the art ribbon's top spacing, so there is an empty band under the title bar.

## Motion module presets (`src/client/UI/Motion.luau`)

| Name | Timing | Source | Used by |
|---|---|---|---|
| panelOpen / panelClose | Scale 0.6 -> 1 Back Out 0.3 s / 1 -> 0.75 Quad In 0.15 s | DarkTiles | every panel |
| shadeIn / shadeOut | 0.15 s Quad, shade 0.6 + blur 18 | spec 5 | panel backdrop |
| hudHide / hudShow | slide 0.15 H, Quad In 0.15 s / Back Out 0.3 s delay 0.05 | DarkTiles | menu columns while a panel is open |
| stationHide / stationShow | 0.2 s Quad | spec 5 | menu columns in station mode |
| buttonHover / buttonPress / buttonRelease | 1.04 Quad 0.12 s / 0.94 Quad 0.06 s (face down 4 px) / Back Out 0.15 s | spec 4.1, DarkTiles | every button, tile, close |
| pop | peak -> 1, Back Out 0.25 s | spec 5 | counter icon, words, rows |
| newButton | Scale 0 -> 1 Back Out 0.35 s | spec 5 | new tiles, rows, dots |
| numberRoll / counterRoll | Linear 0.27 s / Quad Out 0.4 s | DarkTiles / LightDock | currency rows |
| coinFly / coinSpawn | Quad In 0.7 s, stagger 0.015 + random 0.15, shrink to 0.6 | GlassPanels | claim coin burst |
| toastIn / toastOut | Scale 0.83 -> 1 Back Out 0.3 s / fade 0.08 s after the hold | SlimPills | both toast lanes |
| floatNumber | up 0.05 H and fade, Quad Out 0.6 s | GlassPanels | floating numbers, SWEET stars |
| dotPulse | 1 -> 1.15, Sine InOut, 1.2 s cycle | spec 4.7 | notification dots |
| arrowBob / idleBob | 8 px, 0.6 s cycle / 6 px, 1.0 s cycle | spec 4.6 / 5 | tutorial pointer |
| wobble | +-8 deg Sine loop | LightDock | (available, unused in the slice) |
| shake | +-6 px x3 in 0.25 s | spec 5 | cannot-afford, nest full |
| objectiveOut / objectiveIn | up 10 px fade 0.15 s / 0.8 -> 1 Back Out 0.25 s | spec 5 | objective line |
| priceAffordable | 1.1 -> 1 Back Out 0.25 s | spec 5 | price turns green |
| revealFlashIn / revealFlashOut | 0.12 s / 0.35 s | spec 5, DarkTiles | reveal |
| revealLand | 1.3 -> 1 Back Out 0.3 s | GlassPanels | reveal name, rarity, CLEAN! |
| revealSticker | 0 -> 1, -30 -> -12 deg, Back Out 0.3 s, delay 0.2 | DarkTiles | NEW! sticker |
| timerUrgent, tabSwitch, fade, wordOut, stampIn, fill | see file | spec 5 | timer (future), tile open state, words, zone stamp, bars |

Reduced motion (`GuiService.ReducedMotionEnabled`): scale motions snap to their end value and loops do not start. The reveal slot-roll timing stays in `Hatch.luau` because it is synced to the server's reveal schedule. World-space tweens in `Fx.luau` (eggs, shards, 3D floaters) are not UI and stay there.

## Missing art (built in code for now) and what to commission

| Piece | Now | Should look like |
|---|---|---|
| Rarity card frames (7 + rainbow Secret) | code: rarity-colour frame, white-to-grey gradient, 3 px dark rim | SunGraphica-style bevelled card per rarity, lighter top, inner shine, star pips |
| Mutation badges (Golden, Shiny, Rainbow) | text only on the reveal | small rounded badge with icon, gold / cyan / rainbow |
| Grey and rainbow rarity stars | `starWhite` stand-in | Gvesster-style star in grey and in a rainbow gradient |
| Dumbbell icon (Strength row, Weights upgrade) | `lightningBlue` | chunky cartoon dumbbell, Gvesster style, 256 px |
| Nozzle / hose icon (Nozzle upgrade) | `lightning` | spray nozzle with a water burst |
| Sun and gold sun (Golden Hour timer) | not built (timer not in the slice) | round cartoon sun, plain and gold |
| Green and grey title ribbons | Upgrades uses magenta | `header*` ribbon in green (Upgrades, Daily) and grey (Settings alt) |
| Purple premium button + Robux glyph | not in the slice | `buttonWide` in purple with a white R$ glyph |
| Disabled and pressed button states | pressed = code scale + 4 px drop; disabled = code grey | greyed `buttonWide` and a pressed variant with a thinner bevel |
| NEW! sticker | code: cream rounded frame, orange text, tilt | die-cut cartoon sticker, orange outline, slight curl |
| Reveal VFX: flash ring, light rays, confetti, sparkle | code: full-screen white flash only | radial ray burst behind the name, ring texture, confetti sheet |
| Scroll bar, toggle switch | scroll bar = 8 px `panelRim` colour | rounded tan scroll thumb; green pill toggle with white knob |
| Floor chevron texture, down-pointing marker | `Trail.luau` neon part chevrons | chevron texture for a Beam, bouncy yellow down arrow |
| Egg-shaped empty slot | not used yet | dashed egg outline on dark slot |
| Creature icons beyond the bunny | Book cards render the placeholder pet model in a ViewportFrame | one icon per species for small lists |
| Sound set (click, pop, coin tick, reveal chime, bonk) | existing `Sfx.luau` sounds | genre-standard UI sound pack |

## Still weak

- Pet models in Book cards are the placeholder blobs, so cards read mostly by colour and text.
- The reveal is text over the 3D pad; no ring vignette or rays yet (missing VFX art).
- Phone landscape: the currency stack sits in the lower-left thumbstick zone (it starts at 47 % height on phone); readable but crowded on short screens.
- The upgrade rows' red progress bar is only visible when the row is scrolled into view; the cream panel art has a thin tan rim, so the dark rim wrapper does most of the outline work.
- `tests/test_game_math.luau` fails at its require on line 2; it is a pre-v3 test that this work did not touch.
