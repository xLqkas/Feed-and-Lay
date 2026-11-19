# Backup of the old game (pre-v3)

Made 2026-11-19, before any v3 work. There are three independent restore points: git, a copy inside the Studio place, and Roblox's own version history.

## 1. Git

| What | Where |
|---|---|
| Old game exactly as it was before any AI changes | tag `backup/pre-v3` (commit `5781a3d`) |
| Phase 0 (repo synced to the live Studio place, fixed `EggRestoration3D`, `DayNightCycle` and Teams script brought in, rokit/selene/stylua) and `docs/ai` | first commit on branch `v3` (`a5c30da`) |
| `main` | untouched, still at `5781a3d` |

Nothing was pushed. To keep the tag safe off this machine: `git push origin backup/pre-v3`.

**Restore with git**

1. `git fetch --tags` (if working from another clone).
2. Look at it: `git switch --detach backup/pre-v3`.
3. Or make it a branch to work from: `git switch -c restore-old backup/pre-v3`.
4. Sync it into Studio with Rojo (`rojo serve`, connect from the Rojo plugin). Note the old `default.project.json` has no `$ignoreUnknownInstances`, so Rojo may remove Studio-only instances it does not know: back up the place (section 2) first, or use the `v3` commit's project file, which keeps them.
5. The map, pet templates, HUD and other Studio-only content are not in git (see `studio-only-inventory.md`); restore those from section 2.

## 2. Studio: `ServerStorage._Backup_PreV3`

A local `.rbxl` copy was not possible: the place is a cloud Team Create place, the MCP `save_place` tool only saves a new cloud version (never a local file), and `execute_luau` has no file access. So the old content was cloned inside the place. Originals were not changed or removed.

Folder `ServerStorage._Backup_PreV3` (attributes: `CreatedUtc`, `Note`, and `Lighting_*` = the Lighting service's properties at backup time):

| Subfolder | Contents (copies of) |
|---|---|
| `Workspace` | `EggSanctuaryMap` (3,063 descendants: `MultiplayerBases` with `PlayerBase_1`..`_6`, each with its `BicepCurlStation`; `LaunchStation`; `DistanceCanyon`; `SanctuaryGround`; 6 lamps, 6 lantern posts), `Baseplate` |
| `ServerScriptService` | `DayNightCycle` (Script), `EggSanctuaryServer` folder with `MainGameServer` |
| `ReplicatedStorage` | `Remotes` (10), `Modules` (`GameConfig`, `SoundHelper`), `Sounds` (8), `PetTemplates` (428 descendants) |
| `StarterGui` | `EggSanctuaryHUD` (the only ScreenGui; 134 descendants) |
| `StarterPack` | `Dumbbell` tool |
| `StarterPlayerScripts` | `EggSanctuaryClient`, `PetShowcaseAnimator`, `EggRestoration3D` |
| `StarterCharacterScripts` | (was empty) |
| `Lighting` | `SanctuaryAtmosphere`, `Bloom`, `ColorCorrection`, `SereneSanctuarySky` |
| `Teams` | `Script` |

The washer (power-wash) station has no map model: `EggRestoration3D` builds it at runtime, so it is covered by that script's copy.

Every script copy has `Enabled = false`, and an attribute `OriginalEnabled` with the original value (all were `true`). They sit in ServerStorage, which never runs scripts anyway.

**Verification (run through Studio MCP right after cloning):** for each of the 18 top-level copies, descendant count of copy = original (total 3,678 descendants in the backup), every script's class, name and source identical to the original (0 mismatches), 0 enabled script copies, and all 6 original scripts still `Enabled = true`.

**Restore in Studio**

1. In Edit mode, delete or move away the v3 versions of the items you are restoring (for example `Workspace.EggSanctuaryMap`, the scripts in `ServerScriptService` and `StarterPlayerScripts`, `StarterGui` ScreenGuis, `ReplicatedStorage` folders).
2. Run in the command bar (copies, so the backup stays intact):

```lua
local root = game.ServerStorage._Backup_PreV3
local targets = { Workspace = workspace, ServerScriptService = game.ServerScriptService, ReplicatedStorage = game.ReplicatedStorage, StarterGui = game.StarterGui, StarterPack = game.StarterPack, StarterPlayerScripts = game.StarterPlayer.StarterPlayerScripts, StarterCharacterScripts = game.StarterPlayer.StarterCharacterScripts, Lighting = game.Lighting, Teams = game.Teams }
for _, folder in root:GetChildren() do
	for _, item in folder:GetChildren() do
		local copy = item:Clone()
		local all = copy:GetDescendants(); table.insert(all, copy)
		for _, d in all do
			if d:IsA("BaseScript") and d:GetAttribute("OriginalEnabled") ~= nil then
				d.Enabled = d:GetAttribute("OriginalEnabled"); d:SetAttribute("OriginalEnabled", nil)
			end
		end
		copy.Parent = targets[folder.Name]
	end
end
for name, value in root:GetAttributes() do
	local prop = name:match("^Lighting_(.+)")
	if prop then game.Lighting[prop] = value end
end
```

3. Play-test, then save. Publishing is the owner's call.

## 3. Roblox version history

Every save of the place is a version on Roblox. Open the place's **Version History** (Creator Dashboard > the experience > Places > the place > Version History, or in Studio: Asset Manager > Places > right-click the place > View Version History) and restore a version from on or before 2026-11-19. This restores the whole place, including the v3 changes being lost.

## Player saves

The old game saves to DataStore `EggSanctuary_SaveData_v6`. v3 must write only to a new key (design-v3 "Owner decisions" point 2), so restoring the old game also brings back players' old progress as it was at the v3 switch.
