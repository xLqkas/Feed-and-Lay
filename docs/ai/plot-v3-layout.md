# Plot v3 layout (VS-3 "Compact plot")

Built 2026-11-19 in the live place "Feed an Lay" (placeId 113603218122384), edit mode, through Studio MCP. Studio-only content: none of it is in Rojo. Implements `design-v3.md` section 3.0 and the VS-3 row of section 11.

What exists now:

| Where | What |
|---|---|
| `Workspace.PlotsV3` | 6 plots, `Plot_1` .. `Plot_6`, identical structure, 59 parts each (354 total), no scripts |
| `Workspace.CanyonV3` | Meadow and Marsh landing floors + one gate each |
| `ReplicatedStorage.Models.MamaHen` | placeholder hen rig (15 primitive parts), five zone tints as attributes |
| `ReplicatedStorage.Models.MamaHenHats` | five hats, `1` .. `5` (one per zone) |
| `ServerStorage._OldMap_PreV3` | old content moved out of the way (not destroyed), see "Moved" below |

No Creator Store or generated assets were inserted: everything is primitive parts. **Inserted asset ids: none.**

Screenshots: `docs/ai/shots/plot-v3/` (`01-overview`, `02-plot4-from-back`, `03-plot4-spawn-view-to-canyon`, `04-plot3-close`, `05-mama-hen-five-tints`, `06-marsh-gate`).

## Where the plots are

The canyon in this place is a walled corridor at ground level, 48 studs wide inside (walls at X -79 and -31), running along +Z from its mouth at Z = 0. Six 60 x 60 plots cannot all touch a 48-stud mouth, so the plots sit on a semicircle of radius 142 around the point `(-55, -77.8, 8)` just in front of the mouth, each one turned to face that point. The front edge of each plot is its "rim" (a coloured curb); all six look straight down the canyon (screenshot 03). The old launch runway stays in the open plaza in the middle.

| Plot | Angle | Centre (world X, Z), floor top Y = -77.8 |
|---|---|---|
| `Plot_1` | +75 deg | (82.16, -28.75) |
| `Plot_2` | +45 deg | (45.41, -92.41) |
| `Plot_3` | +15 deg | (-18.25, -129.16) |
| `Plot_4` | -15 deg | (-91.75, -129.16) |
| `Plot_5` | -45 deg | (-155.41, -92.41) |
| `Plot_6` | -75 deg | (-192.16, -28.75) |

`Plot_1` is leftmost and `Plot_6` rightmost when you face the canyon. Adjacent plot centres are 73.5 studs apart; no plot overlaps another, the old ground covers every plot corner, and no non-v3 part intersects any plot volume (checked).

`Workspace.PlotsV3` attributes: `MouthX` = -55, `MouthZ` = 8, `Radius` = 142.

### Coordinate convention (important for code)

`plot:GetPivot()` is the centre of the floor top, and its `LookVector` points at the canyon. The spec's offsets are "(x right, y up, z toward the canyon)", so:

```lua
local function specToWorld(plot, x, y, z) return plot:GetPivot() * Vector3.new(x, y, -z) end
```

Spec +x is the player's right when standing on the plot facing the canyon.

## Instance tree of one plot

```
Workspace.PlotsV3.Plot_<N>        Model, tag FLPlot, PrimaryPart = Floor
  Floor           Part 60x4x60 grass; PivotOffset puts the pivot on its top face
  Rim             front curb (the canyon rim), accent colour
  EdgeL, EdgeR, EdgeBack   low side/back curbs, accent colour
  Hub             sand disc under the stations (no collision)
  Spawn           SpawnLocation 6x0.4x6 at spec (0,0,-6), faces the canyon, Neutral, Duration 0
  Ledge           Model, FLStation, Kind=Ledge, PrimaryPart = Pad
    Pad           8x0.4x6 at spec (0,0,12)
      ThrowOrigin   Attachment, where the food leaves (spec (0,4.5,14.5))
    Glow          neon outline under the pad (no collision)
    Rail, PostL, PostR   railing on the canyon side of the pad
    OddsBoard     3x2 board, SurfaceGui (Back face) > TextLabel "Text" = "ODDS"
    Zone          invisible 8x8x6 box over the pad (no collision/query/touch)
  Nest            Model, FLStation, Kind=Nest, PrimaryPart = Rack
    Rack          9x0.8x2.6 at spec (8,0,7.6)
      Count       BillboardGui > TextLabel "Text" = "0/2"
    Slot1..Slot8  cups on a curve, attribute SlotIndex = 1..8
      EggPoint    Attachment, egg centre
      Lock        BillboardGui padlock; Enabled for slots 3..8 at start
  Washer          Model, FLStation, Kind=Washer, PrimaryPart = Ring
    Ring          6.4-stud neon disc at spec (12,0,2) (no collision)
    Mat           5.6-stud disc on top of it
    Pedestal      1.6-stud column
    Turntable     2.4-stud plate on the pedestal (code rotates it)
      EggPoint    Attachment, egg centre during washing
    Zone          invisible 6x8x6 box over the ring
  HatchPad        Model, FLStation, Kind=HatchPad, PrimaryPart = Pedestal
    Pedestal      4-stud disc, 1 tall, at spec (12,0,-6)
      EggPoint    Attachment, egg centre while hatching
    Beam          translucent neon light column (no collision)
    QueueShelf    wooden shelf at spec (16,0,-6)
      Queue1..Queue8   Attachments, queued egg positions
  LiftBench       Model, FLStation, Kind=Lift, PrimaryPart = Ring
    Ring          4.4-stud neon disc at spec (-10,0,6) (no collision)
      StandPoint  Attachment, where the player stands
    Mat, Bench, Rack, Bar, PlateA, PlateB   props
    Zone          invisible 4x8x4 box over the ring
  Pen             Model, FLStation, Kind=Pen, PrimaryPart = PenFloor
    PenFloor      40x0.2x18 at spec (0,0,-19), spans x -20..20, z -10..-28
      Spot1..Spot16   Attachments, attribute SpotIndex; row-major, Spot1-4 = front row (nearest the stations), left to right
    FenceBack, FenceL, FenceR, FenceFrontL, FenceFrontR   (6-stud gate in the front middle)
  Sign_Food       Model, FLStation, Kind=Sign, Tab=Food     beside the Ledge
  Sign_Nest       Model, FLStation, Kind=Sign, Tab=Nest     beside the Nest
  Sign_Nozzle     Model, FLStation, Kind=Sign, Tab=Nozzle   beside the Washer
  Sign_Weights    Model, FLStation, Kind=Sign, Tab=Weights  beside the Lift Bench
  Sign_Pen        Model, FLStation, Kind=Sign, Tab=Pen      beside the Pen gate
    Post, Board   Board is PrimaryPart; SurfaceGui (Front face, facing the spawn) > TextLabel "Text"
  BaseSign        Model (not a station), PrimaryPart = Board
    PostL, PostR, Board   physical sign at the back edge, accent colour
    Anchor        invisible part at spec (0,12,-30)
      Billboard   BillboardGui, MaxDistance 300 > TextLabel "Title" ("FREE PLOT"), TextLabel "Income" ("")
```

### Names, tags and attributes the code must use

| Thing | Tag | Attributes |
|---|---|---|
| Plot model | `FLPlot` | `PlotId` (1..6), `OwnerUserId` (0 = free; code writes it), `AccentColor` (Color3) |
| Every station model | `FLStation` | `Kind` (`Ledge`, `Nest`, `Washer`, `HatchPad`, `Lift`, `Pen`, `Sign`), `PlotId` |
| Sign stations | `FLStation` | also `Tab` (`Food`, `Nest`, `Nozzle`, `Weights`, `Pen`) = which Upgrades tab it opens |
| Nest cups `Slot1..8` | | `SlotIndex` |
| Pen spots `Spot1..16` (Attachments) | | `SpotIndex` |
| Landing floors | `FLZoneFloor` | `ZoneId`, `ZoneName`, `FloorStartZ`, `FloorLength`, `CenterX`, `Width`, `SurfaceY` |

Choices made where the design is silent:

- **Stations are Models** with the tag on the model and a `PrimaryPart`; the station position is `model.PrimaryPart.Position`. Find a player's station with `CollectionService:GetTagged("FLStation")` filtered by `PlotId` and `Kind`, or simply `plot:FindFirstChild(name)`.
- **Trigger volumes:** `Ledge.Zone`, `Washer.Zone`, `LiftBench.Zone` are invisible boxes. Server check: `local p = zone.CFrame:PointToObjectSpace(rootPart.Position); inside = math.abs(p.X) <= zone.Size.X/2 and math.abs(p.Y) <= zone.Size.Y/2 and math.abs(p.Z) <= zone.Size.Z/2`. This replaces `GameConfig.IsInLaunchZone` (the "per-plot box" of section 3.2). The Lift server rule "within 8 studs of the bench" can use `LiftBench.Ring.Position`.
- **Egg and pet positions are Attachments** (`EggPoint`, `Queue1..8`, `Spot1..16`, `StandPoint`, `ThrowOrigin`): use `attachment.WorldPosition` / `WorldCFrame`. Pen spots are attachments rather than parts to keep the part count low; their Y is the pen floor top (place a pet's feet there).
- **Spawns:** all six `Spawn`s are enabled and neutral, so before the new server code lands a joining player spawns on a random plot. The v3 server should set `player.RespawnLocation = plot.Spawn` when it assigns a plot.
- **Base sign:** code writes `Billboard.Title.Text` (e.g. "FILIP'S SANCTUARY") and `Billboard.Income.Text`.
- **Nest lock icons:** code toggles `Slot<i>.Lock.Enabled` from the player's `nestSlots`; `Nest.Rack.Count.Text.Text` shows "used/size".
- **Template:** there is no separate template instance (a tagged copy in ServerStorage would show up in `GetTagged`). All six plots are made by one build function (appendix); to change the layout, edit the script and re-run it, which deletes and rebuilds `Workspace.PlotsV3` only. Three later fixes were applied in place and are already folded into the appendix: side/back curbs and a lighter floor colour, the nest moved from spec z 8.3 to 7.6 and narrowed (rack 10.4 to 9 wide, cup spacing 1.25 to 1.1) so it clears the Ledge pad, and the hub disc lowered 0.05 to stop it flickering against the pen floor.

## Canyon landing floors (`Workspace.CanyonV3`)

Section 3.4: each zone floor is 1,400 studs long, `Z = FloorStartZ + (dist - zone.min) / (zone.max - zone.min) * FloorLength`.

| Part | ZoneId | ZoneName | FloorStartZ | FloorLength | CenterX | Width | SurfaceY |
|---|---|---|---|---|---|---|---|
| `LandingFloor_1` | 1 | Dewdrop Meadow | 20 | 1400 | -55 | 48 | -76.8 |
| `LandingFloor_2` | 2 | Bog Marsh | 1420 | 1400 | -55 | 48 | -76.8 |

The floors sit 1 stud above the old biome floors and carpet, covering them. `Gate_1` / `Gate_2` are simple arches at each floor start with the zone name on both sides. Zones 3-5 (P-2) keep the old canyon beyond Z 2820 for now; those old biome folders still use the old Z ranges.

## Mama Hen placeholder (`ReplicatedStorage.Models`)

`MamaHen` (Model, PrimaryPart `Root`, origin between the feet, faces -Z, about 9 x 11 x 12 studs, all parts anchored, no collision). Parts with attribute `Tint = true` (`Body`, `Tail`, `Head`, `WingL`, `WingR`) take the zone colour from the model's attributes `Tint_1` .. `Tint_5` (cream, green, charcoal, teal, violet). `Head.HatPoint` is the hat attachment. `MamaHenHats.1` .. `5` are built around (0,0,0) = the hat point (flower crown, lily pad, ember comb, shell, star); place one with `hat:PivotTo(hen.Head.HatPoint.WorldCFrame * hat.PrimaryPart.CFrame)`. Screenshot 05 shows all five.

## Verification (execute_luau, edit mode; no play mode)

| Check | Result |
|---|---|
| `_Backup_PreV3` exists with the old plots before any change (3,678 descendants, `PlayerBase_1..6` inside `Workspace.EggSanctuaryMap`) | PASS |
| 6 plots tagged `FLPlot`, 66 stations tagged `FLStation` (11 per plot: 6 core + 5 signs), each with correct `PlotId` and a `PrimaryPart`; 2 `FLZoneFloor` | PASS |
| Every plot: 8 nest slots with `EggPoint` + `SlotIndex`, 16 pen spots with `SpotIndex`, 8 queue points | PASS |
| Every BasePart in `PlotsV3` anchored; no scripts in `PlotsV3`, `CanyonV3` or `Models` | PASS |
| No solid part of one station intersects another station (sign and base-sign posts stand on the curbs on purpose) | PASS |
| Spawns: at spec (0,0,-6) on every plot, facing the canyon, nothing solid in the 4x6x4 space above | PASS |
| Core stations within 14 studs of the plot centre (horizontal, to PrimaryPart) | PASS, max 13.42 |
| **Accept: walk Ledge -> Washer -> Hatch Pad -> Ledge under 3 s** (WalkSpeed 16) | PASS on all 6 plots: 37.1 studs = 2.32 s |
| Real walk in play mode | NOT RUN (task said no play mode, no input) |
| Place saved | NOT RUN (cloud Team Create place: `save_place` would write a new cloud version, not a local file; edits are already live in the team session) |

Distances from plot centre (identical on every plot):

| Station | Spec offset | Distance |
|---|---|---|
| Spawn | (0,0,-6) | 6.00 |
| Ledge pad | (0,0,12) | 12.00 |
| Nest rack | (8,0,7.6) | 11.03 |
| Washer ring | (12,0,2) | 12.17 |
| Hatch Pad | (12,0,-6) | 13.42 |
| Lift Bench ring | (-10,0,6) | 11.66 |
| Pen | gate at (0,0,-10), floor centre (0,0,-19) | 10.00 / 19.00 (the spec puts the pen in the back half on purpose) |
| Signs | Food, Weights, Pen, Washer, Nest | 11.98, 10.13, 9.78, 16.72, 17.42 (each 2 studs beside its station) |

How the walk was measured: the straight lines between station centres cross the nest rack and the washer turntable, so the test uses this route in spec (x, z) coordinates: Ledge pad centre (0,12) -> gap below the nest (2.0,5.3) -> inside the washer ring (9.15,2.94) -> beside the hatch pad (11.03,-2.95) -> gap (2.0,5.3) -> onto the Ledge pad (2.0,9.5). Every segment was swept with a 2 x 4 x 1 body box (`workspace:Blockcast`, solid parts only, bottom 0.6 studs above the floor) and is clear on all six plots. PathfindingService gave 35-54 studs for the same trip; its 4-stud grid makes the length noisy, so it was not used as the pass number. The gap between the washer turntable and the line to the hatch pad is only about 0.2 studs wider than the body box; a player simply walks round the pedestal.

## Moved to `ServerStorage._OldMap_PreV3`

Moved, not destroyed. Each moved item has attribute `OriginalParent`; restore by parenting it back. The folder mirrors the old paths.

| Moved item | Why |
|---|---|
| `Workspace.EggSanctuaryMap.MultiplayerBases` (all of `PlayerBase_1..6`: yards, fences, gym stations, chef stalls, egg cleaners, signs, showcase pets) | Every old base overlaps a new plot |
| `EggSanctuaryMap.Lamp_1`, `Lamp_2`, `LanternPost_1`, `LanternPost_2` | Stand inside `Plot_5` / `Plot_2` |
| `DistanceCanyon.Dewdrop Meadow`: `BiomeArch_Dewdrop Meadow`, `Meadow Bunny_Statue`, `AnimalDais_Meadow Bunny`, `Part` | Statue and dais sit in the Meadow landing lane; old arch at Z 15 duplicates the new gate |
| `DistanceCanyon.Luminescent Swamp`: `BiomeArch_Luminescent Swamp`, `Slime Drake_Statue`, `AnimalDais_Slime Drake`, `Part` | A "Swamp" arch and a Marsh creature inside the new Meadow floor |
| `DistanceCanyon.Cinder Volcano`: `BiomeArch_Cinder Volcano`, `Ember Hound_Statue`, `AnimalDais_Ember Hound`, `Part` | A "Volcano" arch in the Meadow floor and a Volcano statue in the Marsh floor |
| `DistanceCanyon.Sunken Coral Reef`: `BiomeArch_Sunken Coral Reef` | A "Reef" arch at Z 2515, inside the new Marsh floor |

Effect on the old scripts (still running until the v3 server lands): `MainGameServer`, `EggSanctuaryClient` and `PetShowcaseAnimator` look up `EggSanctuaryMap.MultiplayerBases` with `FindFirstChild` and nil checks, so they do not error, but the old plot features (old base sign, egg cleaner, garden pets, gym station) have no models while the bases are moved. The old game is fully restorable from `_Backup_PreV3` or by moving the items back.

## Left in place on purpose

| Item | Why |
|---|---|
| `EggSanctuaryMap.SanctuaryGround` (ground + bedrock) | The plots stand on it |
| `EggSanctuaryMap.DistanceCanyon` walls, old biome floors, carpet, rails, and the Reef / Galaxy statues beyond Z 2820 | Canyon shell; zones 3-5 are P-2 work |
| `EggSanctuaryMap.LaunchStation` (old runway, yellow pad, arch) | In the open plaza, overlaps nothing; it is the old game's throw zone (`GameConfig.LaunchZone`) until the v3 server replaces it |
| `Lamp_3..6`, `LanternPost_3..6` | Outside every plot |
| `Workspace.Baseplate`, Terrain, Lighting, sky | Not part of this package |
| Old `StarterGui.EggSanctuaryHUD` | Still shows in Studio edit view (visible in the screenshots); UI is other packages' work |

## Rough, needs art later

- Everything is primitive parts: the nest cups are plain cylinders, the washer has no nozzle or hose prop, the lift weights are three blocks, the pen fence is solid panels.
- Signs and the odds board are plain SurfaceGui text in Fredoka One; no icons.
- The Marsh floor (Mud material) reads almost the same green as the Meadow floor; gate text is small from far away.
- Plot floors are flat squares on a flat plain; there is no real "rim" or drop. A proper canyon edge (bowl or cliff around the mouth) would sell "throw down the canyon" better.
- The side plots (`Plot_1`, `Plot_6`) look at the canyon at a steep angle across the plaza; their throws travel about 110 studs before entering the canyon.
- The Mama Hen is a ball rig with tiny hats.

## Appendix: build script

Run in the Studio command bar or through `execute_luau` (edit mode). It rebuilds `Workspace.PlotsV3` only; it does not touch `CanyonV3`, `Models` or the old map.

```lua
-- VS-3 build script: creates Workspace.PlotsV3 (6 plots) from one template built in code.
-- Re-runnable: deletes and rebuilds Workspace.PlotsV3 only.
local CS = game:GetService("CollectionService")
local GROUND_Y = -77.8 -- floor top (old ground top is -78)
local MOUTH = Vector3.new(-55, GROUND_Y, 8) -- point the plot arc is centred on (canyon mouth)
local RADIUS = 142
local ANGLES = { 75, 45, 15, -15, -45, -75 } -- PlotId 1..6, left to right when facing the canyon
local ACCENTS = {
	Color3.fromRGB(255, 99, 132), Color3.fromRGB(255, 159, 64), Color3.fromRGB(255, 205, 86),
	Color3.fromRGB(75, 192, 120), Color3.fromRGB(54, 162, 235), Color3.fromRGB(153, 102, 255),
}

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end
local function ghost(p) p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false; return p end
local function zoneBox(parent, size, cf)
	local z = ghost(part(parent, "Zone", size, cf, Color3.new(1, 1, 1)))
	z.Transparency = 1
	return z
end
local function label(p, face, text, color)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 50
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color or Color3.fromRGB(60, 40, 30)
	t.Text = text
	t.Parent = g
	g.Parent = p
	return g
end
local function station(parent, name, kind)
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Kind", kind)
	CS:AddTag(m, "FLStation")
	m.Parent = parent
	return m
end
local function att(p, name, worldPos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = p
	a.WorldPosition = worldPos
	return a
end
local VERT = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's axis to vertical

-- spec offset (x, y, z): X right, Z toward the canyon. Pivot looks at the canyon, so spec z -> -Z.
local function build(pivot, accent)
	local function at(x, y, z) return pivot * CFrame.new(x, y, -z) end
	local function pos(x, y, z) return at(x, y, z).Position end
	local plot = Instance.new("Model")
	plot.Name = "Plot"
	CS:AddTag(plot, "FLPlot")

	local floor = part(plot, "Floor", Vector3.new(60, 4, 60), at(0, -2, 0), Color3.fromRGB(165, 225, 120), Enum.Material.Grass)
	floor.PivotOffset = CFrame.new(0, 2, 0)
	plot.PrimaryPart = floor
	part(plot, "Rim", Vector3.new(60, 0.8, 1.2), at(0, 0.4, 29.4), accent)
	part(plot, "EdgeL", Vector3.new(1.2, 0.5, 57.6), at(-29.4, 0.25, 0), accent)
	part(plot, "EdgeR", Vector3.new(1.2, 0.5, 57.6), at(29.4, 0.25, 0), accent)
	part(plot, "EdgeBack", Vector3.new(60, 0.5, 1.2), at(0, 0.25, -29.4), accent)
	ghost(part(plot, "Hub", Vector3.new(0.2, 34, 34), at(4, 0.05, 3) * VERT, Color3.fromRGB(245, 225, 175), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)).CanQuery = false

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.CFrame = at(0, 0.2, -6)
	spawn.Color = accent
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = plot

	-- Ledge (0,0,12): 8x6 pad, glow ring, railing, odds board
	local ledge = station(plot, "Ledge", "Ledge")
	local pad = part(ledge, "Pad", Vector3.new(8, 0.4, 6), at(0, 0.2, 12), Color3.fromRGB(255, 214, 64))
	ledge.PrimaryPart = pad
	ghost(part(ledge, "Glow", Vector3.new(9, 0.2, 7), at(0, 0.1, 12), Color3.fromRGB(255, 170, 0), Enum.Material.Neon))
	part(ledge, "Rail", Vector3.new(8, 0.5, 0.5), at(0, 3, 15.6), Color3.fromRGB(255, 255, 250))
	part(ledge, "PostL", Vector3.new(0.6, 3, 0.6), at(-3.7, 1.5, 15.6), Color3.fromRGB(255, 255, 250))
	part(ledge, "PostR", Vector3.new(0.6, 3, 0.6), at(3.7, 1.5, 15.6), Color3.fromRGB(255, 255, 250))
	local odds = part(ledge, "OddsBoard", Vector3.new(3, 2, 0.3), at(-5.6, 2.4, 15.6), Color3.fromRGB(255, 248, 230))
	label(odds, Enum.NormalId.Back, "ODDS")
	zoneBox(ledge, Vector3.new(8, 8, 6), at(0, 4.4, 12))
	att(pad, "ThrowOrigin", pos(0, 4.5, 14.5))

	-- Nest (8,0,8): 8 cups on a curved rack
	local nest = station(plot, "Nest", "Nest")
	local rack = part(nest, "Rack", Vector3.new(9, 0.8, 2.6), at(8, 0.4, 7.6), Color3.fromRGB(196, 134, 74), Enum.Material.Wood)
	nest.PrimaryPart = rack
	for i = 1, 8 do
		local t = (i - 4.5) / 3.5
		local cup = part(nest, "Slot" .. i, Vector3.new(0.7, 1.15, 1.15), at(8 + (i - 4.5) * 1.1, 1.15, 7.1 + 0.8 * (1 - t * t)) * VERT,
			Color3.fromRGB(255, 226, 140), Enum.Material.Fabric, Enum.PartType.Cylinder)
		cup:SetAttribute("SlotIndex", i)
		att(cup, "EggPoint", cup.Position + Vector3.new(0, 1.1, 0))
		local bb = Instance.new("BillboardGui")
		bb.Name = "Lock"
		bb.Size = UDim2.fromScale(1, 1)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 1.2, 0)
		bb.Enabled = i > 2 -- start: 2 slots open
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1; l.TextScaled = true; l.Text = "🔒"
		l.Parent = bb
		bb.Parent = cup
	end
	local count = Instance.new("BillboardGui")
	count.Name = "Count"
	count.Size = UDim2.fromScale(3, 1.2)
	count.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	count.MaxDistance = 60
	local cl = Instance.new("TextLabel")
	cl.Name = "Text"; cl.Size = UDim2.fromScale(1, 1); cl.BackgroundTransparency = 1; cl.TextScaled = true
	cl.Font = Enum.Font.FredokaOne; cl.TextColor3 = Color3.new(1, 1, 1); cl.TextStrokeTransparency = 0.3; cl.Text = "0/2"
	cl.Parent = count
	count.Parent = rack

	-- Washer (12,0,2): 6-stud ring with a turntable pedestal at its centre
	local washer = station(plot, "Washer", "Washer")
	local ring = ghost(part(washer, "Ring", Vector3.new(0.2, 6.4, 6.4), at(12, 0.1, 2) * VERT, Color3.fromRGB(64, 200, 255), Enum.Material.Neon, Enum.PartType.Cylinder))
	washer.PrimaryPart = ring
	part(washer, "Mat", Vector3.new(0.2, 5.6, 5.6), at(12, 0.15, 2) * VERT, Color3.fromRGB(180, 232, 255), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(washer, "Pedestal", Vector3.new(2.2, 1.6, 1.6), at(12, 1.1, 2) * VERT, Color3.fromRGB(250, 250, 255), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	local tt = part(washer, "Turntable", Vector3.new(0.3, 2.4, 2.4), at(12, 2.35, 2) * VERT, Color3.fromRGB(64, 160, 255), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	att(tt, "EggPoint", pos(12, 4.2, 2))
	zoneBox(washer, Vector3.new(6, 8, 6), at(12, 4.2, 2))

	-- Hatch Pad (12,0,-6): 4-stud pedestal, light beam, queue shelf
	local hatch = station(plot, "HatchPad", "HatchPad")
	local hp = part(hatch, "Pedestal", Vector3.new(1, 4, 4), at(12, 0.5, -6) * VERT, Color3.fromRGB(190, 120, 255), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	hatch.PrimaryPart = hp
	att(hp, "EggPoint", pos(12, 2.8, -6))
	local beam = ghost(part(hatch, "Beam", Vector3.new(14, 3.2, 3.2), at(12, 8, -6) * VERT, Color3.fromRGB(235, 210, 255), Enum.Material.Neon, Enum.PartType.Cylinder))
	beam.Transparency = 0.8
	local shelf = part(hatch, "QueueShelf", Vector3.new(2.4, 1.2, 4.8), at(16, 0.6, -6), Color3.fromRGB(196, 134, 74), Enum.Material.Wood)
	for i = 1, 8 do
		att(shelf, "Queue" .. i, pos(15.4 + ((i - 1) // 4) * 1.2, 1.9, -7.8 + ((i - 1) % 4) * 1.2))
	end

	-- Lift Bench (-10,0,6): 4-stud ring, bench, weights rack
	local lift = station(plot, "LiftBench", "Lift")
	local lr = ghost(part(lift, "Ring", Vector3.new(0.2, 4.4, 4.4), at(-10, 0.1, 6) * VERT, Color3.fromRGB(255, 140, 64), Enum.Material.Neon, Enum.PartType.Cylinder))
	lift.PrimaryPart = lr
	part(lift, "Mat", Vector3.new(0.2, 3.8, 3.8), at(-10, 0.15, 6) * VERT, Color3.fromRGB(255, 205, 160), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	att(lr, "StandPoint", pos(-10, 0.3, 6))
	part(lift, "Bench", Vector3.new(3.2, 1.2, 1.2), at(-10, 0.6, 3.2), Color3.fromRGB(235, 80, 80))
	part(lift, "Rack", Vector3.new(1, 2.4, 3.2), at(-13.4, 1.2, 6), Color3.fromRGB(90, 90, 105))
	part(lift, "Bar", Vector3.new(0.3, 0.3, 3.6), at(-13.4, 2.6, 6), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
	part(lift, "PlateA", Vector3.new(0.4, 1.4, 1.4), at(-13.4, 2.6, 4.2) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(60, 60, 75), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(lift, "PlateB", Vector3.new(0.4, 1.4, 1.4), at(-13.4, 2.6, 7.8) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(60, 60, 75), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	zoneBox(lift, Vector3.new(4, 8, 4), at(-10, 4.2, 6))

	-- Pen (-20..+20, -10..-28): fenced, 16 spots in a 4x4 grid
	local pen = station(plot, "Pen", "Pen")
	local pf = part(pen, "PenFloor", Vector3.new(40, 0.2, 18), at(0, 0.1, -19), Color3.fromRGB(150, 225, 110), Enum.Material.Grass)
	pen.PrimaryPart = pf
	local white = Color3.fromRGB(255, 252, 245)
	part(pen, "FenceBack", Vector3.new(40, 2, 0.5), at(0, 1, -28), white, Enum.Material.WoodPlanks)
	part(pen, "FenceL", Vector3.new(0.5, 2, 18), at(-20, 1, -19), white, Enum.Material.WoodPlanks)
	part(pen, "FenceR", Vector3.new(0.5, 2, 18), at(20, 1, -19), white, Enum.Material.WoodPlanks)
	part(pen, "FenceFrontL", Vector3.new(17, 2, 0.5), at(-11.5, 1, -10), white, Enum.Material.WoodPlanks)
	part(pen, "FenceFrontR", Vector3.new(17, 2, 0.5), at(11.5, 1, -10), white, Enum.Material.WoodPlanks)
	local xs, zs = { -15, -5, 5, 15 }, { -13, -17.5, -22, -26 }
	for r = 1, 4 do
		for c = 1, 4 do
			local a = att(pf, "Spot" .. ((r - 1) * 4 + c), pos(xs[c], 0.2, zs[r]))
			a:SetAttribute("SpotIndex", (r - 1) * 4 + c)
		end
	end

	-- Upgrade signs, 2 studs beside their station, facing the spawn
	local signs = {
		{ "Food", "FOOD", -6.6, 10, Color3.fromRGB(255, 120, 90) },
		{ "Nest", "NEST", 14.6, 9.5, Color3.fromRGB(255, 190, 80) },
		{ "Nozzle", "WASHER", 16.6, 2, Color3.fromRGB(64, 180, 255) },
		{ "Weights", "WEIGHTS", -10, 1.6, Color3.fromRGB(255, 140, 64) },
		{ "Pen", "PEN", -5, -8.4, Color3.fromRGB(120, 200, 90) },
	}
	for _, s in signs do
		local m = station(plot, "Sign_" .. s[1], "Sign")
		m:SetAttribute("Tab", s[1])
		local base = pos(s[3], 0, s[4])
		local face = CFrame.lookAt(base, Vector3.new(spawn.Position.X, base.Y, spawn.Position.Z))
		part(m, "Post", Vector3.new(0.4, 3.4, 0.4), face * CFrame.new(0, 1.7, 0), Color3.fromRGB(196, 134, 74), Enum.Material.Wood)
		local board = part(m, "Board", Vector3.new(3.2, 1.5, 0.3), face * CFrame.new(0, 3.6, 0), s[5])
		label(board, Enum.NormalId.Front, s[2], Color3.new(1, 1, 1))
		m.PrimaryPart = board
	end

	-- Base sign (0,12,-30): owner name and income
	local bs = Instance.new("Model")
	bs.Name = "BaseSign"
	bs.Parent = plot
	part(bs, "PostL", Vector3.new(0.8, 9, 0.8), at(-7, 4.5, -29.2), Color3.fromRGB(196, 134, 74), Enum.Material.Wood)
	part(bs, "PostR", Vector3.new(0.8, 9, 0.8), at(7, 4.5, -29.2), Color3.fromRGB(196, 134, 74), Enum.Material.Wood)
	local bboard = part(bs, "Board", Vector3.new(15, 3, 0.6), at(0, 8.5, -29.2), accent)
	bs.PrimaryPart = bboard
	local anchor = ghost(part(bs, "Anchor", Vector3.new(1, 1, 1), at(0, 12, -30), Color3.new(1, 1, 1)))
	anchor.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.Name = "Billboard"
	bb.Size = UDim2.fromScale(18, 5)
	bb.MaxDistance = 300
	bb.LightInfluence = 0
	local title = Instance.new("TextLabel")
	title.Name = "Title"; title.Size = UDim2.fromScale(1, 0.6); title.BackgroundTransparency = 1; title.TextScaled = true
	title.Font = Enum.Font.FredokaOne; title.TextColor3 = Color3.new(1, 1, 1); title.TextStrokeTransparency = 0; title.Text = "FREE PLOT"
	title.Parent = bb
	local inc = title:Clone()
	inc.Name = "Income"; inc.Position = UDim2.fromScale(0, 0.6); inc.Size = UDim2.fromScale(1, 0.4)
	inc.TextColor3 = Color3.fromRGB(120, 255, 120); inc.Text = ""
	inc.Parent = bb
	bb.Parent = anchor
	return plot
end

local old = workspace:FindFirstChild("PlotsV3")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "PlotsV3"
folder:SetAttribute("MouthX", MOUTH.X); folder:SetAttribute("MouthZ", MOUTH.Z); folder:SetAttribute("Radius", RADIUS)
folder.Parent = workspace
for id, deg in ANGLES do
	local th = math.rad(deg)
	local center = MOUTH + Vector3.new(math.sin(th), 0, -math.cos(th)) * RADIUS
	local pivot = CFrame.lookAt(center, MOUTH)
	local plot = build(pivot, ACCENTS[id])
	plot.Name = "Plot_" .. id
	plot:SetAttribute("PlotId", id)
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("AccentColor", ACCENTS[id])
	for _, d in plot:GetDescendants() do
		if d:GetAttribute("Kind") then d:SetAttribute("PlotId", id) end
	end
	plot.Parent = folder
	task.wait()
end
return "built " .. #folder:GetChildren() .. " plots, parts=" .. #(function() local n = {} for _, d in folder:GetDescendants() do if d:IsA("BasePart") then table.insert(n, d) end end return n end)()
```
