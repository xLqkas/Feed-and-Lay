# Feed and Lay: main plan

Goal: turn the current prototype ("Egg Sanctuary") into a catchy Roblox game. Written 2026-11-19 by the coordinator from four Opus reports in this folder:

- `audit-feed-and-lay.md`: what exists and what is wrong
- `assets-inventory.md`: usable assets and gaps
- `reference-bobux-gang.md`: patterns to copy from the owner's previous game
- `game-study-scare-your-favorite-streamer.md`: why a hit game works

## Decisions

- **Stay on plain Luau** with Rojo. Add `--!strict`, selene and stylua, pinned with rokit. No roblox-ts rewrite.
- **Keep the concept** (train, throw food, egg flies back, wash, hatch, pet earns), but rebuild pacing, payoff, UI and onboarding around it.
- **Studio is the source of truth until Phase 0 is done.** Nobody runs `rojo serve` from the repo before then: the repo wash script is broken (duplicated block at lines 1056-1064).
- **Assets:** Gvesster icons used unmodified (licence forbids edits); Sungraphica casual kits for panels and buttons; `styles/09-playful-bold/STYLE.md` for type, spacing, colour and motion.

## Targets every phase is judged against

- First reward within 60 seconds of joining; no tutorial screens.
- One full loop in 45 seconds or less early on (today: about 2 minutes).
- Every reward has a visible build-up (3-5 s) and a reveal.
- Everything readable and tappable on a phone.
- The server decides every payout.

## Phases

**0. Foundation.** Make repo match Studio (fix the wash script from the Studio copy). Bring Studio-only scripts into git and document what stays place-only (map, models). Add rokit, rojo, selene, stylua. Split the two 45-54 KB client scripts into modules. Fix the two exploits: server must own wash progress, and pet sell price must not pay 15x.

**1. Core loop.** Written as a spec first (`design-v3.md`), then built.
- Several eggs in flight or waiting at once; shorter walks.
- Wash becomes 5-10 s of active play with a progress bar and floating numbers, not a 60 s hold.
- A creature visibly eats the thrown food before the egg appears.
- Slot-machine hatch reveal showing the rarity word in its colour.
- Each pet is a permanent earner with `+$X/s` floating above it every second.
- Training needs real input; no idling to the last zone.

**2. Onboarding.** Glowing arrow trail on the ground plus a one-line objective banner that changes each step. HUD buttons appear only when they become useful.

**3. UI rebuild.** A small Luau UI kit: colours named by role, one panel shell, one panel open at a time behind a blur, toasts, press-shrink on every button. Scale-based sizing with a per-screen layout function for phone vs PC. Prices turn green or red with affordability.

**4. Content and progression.** 15 creatures with rarities. Collection book of "???" silhouettes with a cash burst on each new entry. Zones, rebirth, and a server-wide event on the existing day/night cycle that announces rare spawns.

**5. Art and sound.** Real meshes for pets, eggs and stations; particles; a proper sound set. Fill the asset gaps: rarity frames, egg art, hunger icons, button states, a Roblox-usable font.

**6. Monetisation and retention.** Game passes and products from the GDD, daily rewards, live feature flags and simple stats.

**Ongoing.** Study each reference game the owner names with `AIGuidesAndTooling/roblox-play`, and add a `game-study-*.md` here. After each phase an Opus agent playtests in Studio and reports PASS / FAIL / NOT RUN per target.

## Rules for every agent

- Read this file and the reports it needs before starting.
- `BobuxGangClothingAIClaude` is reference only: never edit it.
- Team project: do not publish the place or delete teammates' work; do not commit or push unless told.
- Remote handlers validate input, apply a cooldown, block double requests, wrap work in `pcall` and return `{ok, message}`.
- Save logic lives in pure modules with an assert test; a failed write must never silently lose data.
- Report what was verified and what was not.

## Open questions for the owner

- Who on the team runs Rojo, and can Studio be treated as the truth until Phase 0 lands?
- Licences for the asset packs other than Gvesster, and for the BrushyBoom font.
- Which reference games to study next.
