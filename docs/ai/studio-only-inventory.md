# Studio-only inventory

Date: 2026-11-19. Read from the live place "Feed an Lay" (placeId 113603218122384) in Edit mode. Nothing in Studio was changed.

Everything below exists **only in the place file**, not in git. `rojo build` produces a place without any of it, so never publish a Rojo-built place. `default.project.json` sets `$ignoreUnknownInstances: true` on every service and folder it touches, so `rojo serve` leaves all of this alone.

## What is in git (for contrast)

All 8 scripts in the place are in git and byte-identical to Studio (checked 2026-11-19 by full-text hash, CR stripped):

| Instance | File |
|---|---|
| `ServerScriptService.EggSanctuaryServer.MainGameServer` | `src/server/MainGameServer.server.luau` |
| `ServerScriptService.DayNightCycle` | `src/server/DayNightCycle.server.luau` |
| `StarterPlayer.StarterPlayerScripts.EggSanctuaryClient` | `src/client/EggSanctuaryClient.client.luau` |
| `StarterPlayer.StarterPlayerScripts.EggRestoration3D` | `src/client/EggRestoration3D.client.luau` |
| `StarterPlayer.StarterPlayerScripts.PetShowcaseAnimator` | `src/client/PetShowcaseAnimator.client.luau` |
| `ReplicatedStorage.Modules.GameConfig` | `src/shared/GameConfig.luau` |
| `ReplicatedStorage.Modules.SoundHelper` | `src/shared/SoundHelper.luau` |
| `Teams.Script` (junk: `print("Hello world!")`) | `src/teams/Script.server.luau` |

There are no other scripts in the place. `StarterPack.Dumbbell` has no script.

## Workspace

- `Workspace.Baseplate` (Part, 2048x16x2048, Transparency 1)
- `Workspace.Terrain` (empty)
- `Workspace.EggSanctuaryMap` (Model, 3063 descendants: 2492 Parts, 120 Unions, 55 Models, 200 WeldConstraints, 47 PointLights, 33 ParticleEmitters, 24 Fire, 18 ProximityPrompts, 7 SurfaceGuis, 5 BillboardGuis, 6 SpotLights)
  - `SanctuaryGround` (Folder): `SeamlessSanctuaryGround`, `BedrockFoundation`
  - `LaunchStation` (Folder, 25): `YellowLaunchPad`, `RunwayBed`, `LaunchArch`, `Chevron_1..4_L/R`, 13x `RunwayEdgeLamp`
  - `MultiplayerBases` (Folder, 2511): `PlayerBase_1..6` (Models). Each has `GardenYard` (Folder, 176), `PetsInGarden` (Folder; on bases 2-6 holds showcase pets `ShowcasePet_*`, 183 descendants, wiped by the server when a player takes the plot), `BicepCurlStation` (Model, 35), `ChefStall` (Model, 34), `EggCleaner` (Model, 12), `BaseSign` (Part)
  - `DistanceCanyon` (Model, 503): biome folders `Dewdrop Meadow`, `Luminescent Swamp`, `Cinder Volcano`, `Sunken Coral Reef`, `Celestial Galaxy`. Each holds `BiomeFloor`, `BiomeArch_<name>`, `LaunchCarpet`, `CarpetRail`s, `CanyonWall_L/R`, `AnimalDais_<creature>`, `<creature>_Statue`
  - Loose lamps: `Lamp_1..6` (Part + PointLight), `LanternPost_1..6`

The server script looks these up by name (plots, stations, launch pad, canyon), so renaming them breaks code.

## StarterGui

- `StarterGui.EggSanctuaryHUD` (ScreenGui, 134 descendants), all under `MainFrame`:
  - `TopBar` (24), `NavStack` (13: SHOP / PETS / GYM), `ThrowButton` (3), `ChargeMeterFrame` (45, 6 segments), `NoticeLabel` (2), `ShopModal` (8), `PetInventoryModal` (8), `WashModal` (22, dead: never shown by code)

All other UI is built in code by the client scripts.

## ReplicatedStorage

- `ReplicatedStorage.PetTemplates` (Folder): `Meadow Bunny` (49), `Slime Drake` (59), `Ember Hound` (81), `Coral Leviathan` (59), `Galaxy Titan` (175). Part-built Models, no meshes.
- `ReplicatedStorage.Sounds` (Folder, 8 Sounds, Roblox built-ins): `ThrowWhoosh` and `EggPop` (snap.wav), `AnimalChomp` and `WaterSpray` (splat.wav), `PristineChime` and `CoinCollect` (electronicpingshort.wav), `HatchFanfare` (victory.wav), `GymWorkout` (button.wav)
- `ReplicatedStorage.Remotes` (Folder, 10 RemoteFunctions): `TrainStrength`, `ThrowFood`, `CleanEgg`, `HatchEgg`, `UpgradeFood`, `ExpandSanctuary`, `ManagePet`, `GetSanctuaryState` (also created by the server at runtime if missing), plus stale `SelectFood` and `CollectCoins` (no handler)

## StarterPack

- `StarterPack.Dumbbell` (Tool): `Handle`, 2x `WeightPlate` (Parts with WeldConstraints). No script.

## Lighting

- Properties in edit mode: ClockTime 14, Brightness 2.5, Ambient (90,100,120), OutdoorAmbient (130,150,180). `DayNightCycle` changes ClockTime, Ambient, OutdoorAmbient, Brightness and the Atmosphere at runtime.
- Children: `SanctuaryAtmosphere` (Atmosphere), `Bloom` (BloomEffect), `ColorCorrection` (ColorCorrectionEffect), `SereneSanctuarySky` (Sky)

## Other services

- `TextChatService.BubbleChatConfiguration` has 4 customised children (ImageLabel, UICorner, UIGradient, UIPadding).
- Empty: `ServerStorage`, `ReplicatedFirst`, `SoundService`, `StarterPlayer.StarterCharacterScripts`, `MaterialService`.
- Place settings (Max Players, game passes, place/universe config) were not read.
