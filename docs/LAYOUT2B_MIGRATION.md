# Map Layout 2b (Grand Hub v7): migration plan

Prepared 2026-10-19 from commit `ade7c6f`. **No Studio map changes have been made.** Read-only checks only.

## 0. Status of the prerequisites

| Check | Result |
|---|---|
| Live place saved with the Sunken work | **NO.** The Studio log shows no save to Roblox ("PublishSuccessful") since Studio opened at 01:24. Owner: File -> Save. |
| Fresh backup | `backups/sunken_done_20261019.rbxl` (4.86 MB, 292 scripts), verified by part counts: SunkenKingdom 195 (174 meshes, Access049 20), Zones.SunkenKingdom 9, KnightsKeep 322, EmberAcademy 335, _ParkedZones4to7 706, Hub.Plots 252. |
| Disk | **Critically low: 984 MB free** on `/` (436 of 460 GB used). Enough for backups (5 MB each), not for import work. Free at least 5 GB first. Easy candidates (owner's call): Trash 1.6 GB, `~/.cache` 4.7 GB, Roblox logs 0.75 GB. |

## 1. What the export is

- **Files.** 31 GLBs, made by the three.js exporter, all in one shared coordinate frame. Each module imports in place.
  - `~/Documents/Hub2b_*.glb` (24 files)
  - `~/Documents/Spawn/`: Base3–5, Bushes, GardenFountains, Markers, and `steal-a-billionaire-hub-2b.glb`, which is all of it combined: 346 nodes, 178 meshes, 57,550 tris.
- **Scale.** Every coordinate is a multiple of 0.28, so the hub was laid out in studs and exported as metres. **The import scale is ×3.5714** (Import 3D maps 1 unit to 1 stud, as the Sunken import showed). In studs:
  - hub floor 340 × 244, whole export 420 × 442
  - 36-stud base pitch, the same as today's 36 × 36 plots
  - base 37.6 × 53 outside, about 28 × 42 inside (between the wall boxes), 37 tall
  - slots 12 studs apart; front doors 15 wide; portals 13 tall; NorthGate 50 tall
- **Orientation.** North = -Z, the same as the game: zones lie north of the hub. Needs yaw 0 and one translate.
- **Hierarchy.** 26 top-level groups, each split per material (`<Group>_<material>`):
  - floors and walls: HubFloor, ContestedLane_2a, KingdomWall, NorthGate
  - Base1–8, each with OwnerSign, Front/BackDoor_Threshold, Slot1–6
  - buildings: TeleportHall (4 portals), ArrivalPlaza, CosmeticShop, UpgradeForge, IndexHall, RebirthAltar, TradingPlaza (2 leaderboard faces), EventStage
  - dressing: Gardens, Lanterns, Bushes, GardenFountains, AgeDetails, BaseWalk_Planters
  - `ZoneConnectors_Unchanged`: grey placeholders for the existing zone links. Don't import.
- **Markers** (`Hub2b_Markers.glb`, 35):
  - BaseFront/BaseBack B1–8, NorthGate
  - Portal_{EmberAcademy, SunkenKingdom, KnightsKeep, Sealed_Future}
  - Spawn_1–8 (a ring around the arrival fountain)
  - Service_{CosmeticShop, UpgradeForge, IndexHall, RebirthAltar, TradingPlaza, EventStage}, ArenaGate
- **Collision** (`Hub2b_Collision.glb`): 101 boxes named `COL_*` (12 tris each). These become plain Parts made by a script generated offline from the file, so they need **no Import 3D and no collision computing**. All hub meshes go non-colliding. Gaps:
  - **The contested lane field has no floor box**, apart from the central Spine_T1 and the ReturnPlaza strip. It needs one big box part.
  - The NorthGate posts and the north side of the KingdomWall have no boxes.
- **Materials.** 31, flat colours, emissive used for portals and glow. 3 small textures (water, forge). Water uses alpha blend. Expect the same colour loss as the Sunken import: a restore script keyed by material name (like Sunken's S0).
- **Skip** `Hub2b_Townsfolk_Placeholders.glb`: 1.5 m placeholder figures. The game's own hub NPCs stay.

## 2. Current game references to relocate or reconnect

The game finds things by name, tag or part, never by map coordinates (SCRIPT_MAP). The only fixed numbers are lot-local constants. So most moves are moving tagged or named parts, with no code edits.

| Thing | Now | 2b target | Work |
|---|---|---|---|
| Player plots | `Workspace.Hub.Plots` Plot1–12, 36×36, two rows facing the parade lane, `PlotId` order | Base1–8 (+4, see Q1) | Move the existing Plot models with their working parts (PrimaryPart, sign, pads, lock); swap only the visuals. Renumber PlotId by distance to the NorthGate. |
| Pad spots | `BaseConfig.PAD_SPOTS` 14 spots across 30 × 32 studs, plus `DECOR_SPOTS`, `HubConfig.EXTRA_STATION_SPOTS`, `PlotService.SPAWN_OFFSET` | 2b base inside is about 28 × 42 | New lot-local layout (positions only; pad count, prices and saves unchanged), behind a layout flag so the live game is untouched (Q2). |
| Parade lane | `SkyCity.Ground.ParadeLane.Lane` (attr ParadeLane, 322 studs east–west) | One invisible ParadeLane part across the contested field, in front of the base doors (about 340 studs) | Walkers follow the part's long axis. Nothing else changes. |
| Player spawn | `Workspace.SpawnLocation` (-157, 0.5, -22) | Arrival plaza centre (Spawn_1–8 ring) | Keep ONE SpawnLocation (PvPBase's spawn radius follows it). The markers are decoration. |
| Safe zones | `SafeHubVolume` (tag PvPSafeZone, x -174..-139), `SafeLaneVolume` | Arrival plaza + TeleportHall + lobby; not the contested field or bases | Resize/move the tagged parts. |
| Home anchor | `Workspace.Hub.Floor` (ZoneProgress home anchor) | Lobby centre | Move the part. |
| Shops | `Venues.Shops.UpgradeOffice / LotAndDecor / BatBoutique` | Service_UpgradeForge / Service_CosmeticShop / Bat Boutique has no building (Q4) | Move the venue anchors; names stay fixed. |
| Leaderboard | `Venues.Leaderboards.TopBillionaires` | Leaderboard_W face (EventStage); E face spare | Move the board part. |
| Quest board, Guide | `Venues.NPCs.QuestBoard / Guide` | Arrival plaza beside the TeleportHall (no marker) | Move the anchors. |
| Zone teleports | Zones menu (LaneService, no map needed); `LanePortal` triggers only on the parked zones | TeleportHall portals Ember / Sunken / Keep | New PortalTrigger parts with `ZoneId` + ProximityPrompt, tagged `LanePortal`: `LaneService.hookPortal` already handles them and unlock checks stay. The Sealed_Future portal is decoration only. |
| Zone chain, gates, catch zones | `SkyCity.Lane` (x -157), `FutureZones.*.Gate.Barrier` (LaneGate), `Zones.MainStreet / SunkenKingdom / BillionaireHills`, Keep / Sunken / Ember models | Unchanged ("ZoneConnectors_Unchanged") | Only join Spine_T1's north end to the first lane ramp. |
| Arena, Boss Heist vault, plaza | `Venues.Arena` + `FutureZones.BillionairePlaza.ArenaFloor` (ZoneProgress plaza anchor) at x 138–156; vault in `SkyCity.Hub` | 2b only has `ArenaGate_Doors_Future` | Q3. |
| 2b venues with no game feature | RebirthAltar, TradingPlaza, IndexHall, EventStage, Sealed portal | Decoration ("coming soon"); IndexHall can open the existing Index screen | No new systems (economy rules). |

**8 bases vs 12 plots.** Saves never store a plot (PlotService hands them out each session in PlotId order), so the base count only sets players per server. Studio shows MaxPlayers 60, but the real server size is set on the website and is still open (PROJECT_STATUS Q5). To keep capacity and persistence unchanged, the hub needs 12 base slots:
- **(A, recommended)** The hub author re-exports a 12-base variant: 6 each side of the NorthGate, with HubFloor, KingdomWall, base-row floor, contested lane and collision widened by 2 × 36 studs per side.
- **(B)** Keep the 8-base row and add 4 bases (the same Base module) across the contested lane facing them, 2 each side of the spine. That's closer to today's two rows with the parade between them, but needs a floor box and is lopsided.

Cutting the server to 8 would change capacity, so it is out.

## 3. Staged migration (safest order)

Every stage runs in a **separate development place**, as a script with UNDO. Back up before each stage and commit after it. One review stop per stage.

0. **Setup.**
   - Owner: File -> Save the live place, free 5 GB or more of disk, then close the live place (two Studios won't fit in 13 GB).
   - Copy `backups/sunken_done_20261019.rbxl` to `backups/dev_layout2b.rbxl` and open it with File -> Open from File. That makes it a local place: its File -> Save writes the file, never the live game.
   - Every migration script starts with `assert(game.PlaceId == 0, "dev place only")`. Optional later: publish it as a new place in the same experience for phone tests.
1. **Scale probe (tiny).**
   - Generate the 101 COL boxes and 35 markers as Parts offline from the GLBs (no import).
   - Owner imports ONE base. Apply ×3.5714 and check against an R15 character: door, slots, 36-stud pitch, and that the 2b interior holds the 14 pad spots.
2. **Hub shell.**
   - Owner imports HubFloor, ContestedLane_2a, KingdomWall, NorthGate, TeleportHall and ArrivalPlaza into ServerStorage. Run the colour restore and place them with one transform (yaw 0, ×3.5714, lobby floor at y 0).
   - Collision = COL parts + the contested-field floor box; meshes non-colliding.
   - Park the old SkyCity hub and lot bases to `ServerStorage._ParkedHub027` (dev place only).
3. **Connect zones.** Join Spine_T1 to `SkyCity.Lane`. Walk the hub -> Keep -> Sunken -> Ember and back. Zones untouched.
4. **Bases.** After Q1 and Q2: move Plot1–12 into the base slots (working parts kept, visuals swapped), add the pad-layout flag, renumber PlotId. Tests: `base033:solo` plus Play (place, steal, lock, income).
5. **Parade, spawn, safety.** ParadeLane part, SpawnLocation, SafeHubVolume, Hub.Floor. Tests: parade catch, safe zone, Home teleport in Play.
6. **Venues and portals.** Shop, leaderboard, quest and guide anchors; arena/vault per Q3; LanePortal triggers. Tests: `hub026` / `lane030` sections still valid, plus Play.
7. **Dressing.** CosmeticShop, UpgradeForge, IndexHall, RebirthAltar, TradingPlaza, EventStage, Gardens, Lanterns, Bushes, Fountains, AgeDetails, Planters. fps A/B against the old hub.
8. **Live merge (owner approval).** Save the finished hub as a model, then bring it and the same scripts into the live place with the old hub parked, not deleted. Keep the backup first.

## 4. Main compatibility risks

1. **Pads.** 14 pad spots need about 30 × 33 studs; the 2b inside is about 28 × 42 (narrower, deeper). The layout changes (positions only), or the bases get wider in the re-export.
2. **8 vs 12 bases** (above). Capacity and saves stay unchanged either way.
3. **Collision gaps.** No floor box on the contested field, and none on the NorthGate posts or the north KingdomWall. They are added as parts, never precise mesh collision.
4. **Things living in the old hub area** (arena plaza, Boss Heist vault, HideoutCamp, `SkyCity.Dressing`, race / Spell Run safe volumes) need a home or stay where they are, joined to the new hub.
5. **Materials.** Import 3D drops GLB colours (seen on Sunken), so the restore script is needed. Alpha-blended water becomes transparent Glass and emissive becomes Neon.
6. **Import is owner-only** (no scripted Import 3D) and needs disk space; import module by module, not the combined file, so a failure only costs one piece.
7. **Live safety.** Work only in the local dev place (PlaceId 0 guard). The pad-layout code change sits behind a flag that stays off in the live game until the merge.

## 5. Owner questions

- **Q1** 12 bases: (A, recommended) hub author re-exports 6 + 6; (B) 8 + 4 across the lane.
- **Q2** Pads inside a 2b base: (A, recommended) new lot-local layout fitted to 28 × 42, e.g. 4 columns × 4 rows of 6-stud pads with 1-stud gaps (16 spots for 14 pads), exact spots settled in the stage-1 probe; (B) widen the bases to 40 studs in the re-export.
- **Q3** Battle Arena and Boss Heist vault: (A, recommended) keep them in the old plaza, joined through the ArenaGate; (B) move the arena to the EventStage.
- **Q4** Bat Boutique: (A, recommended) west stall of the TradingPlaza; (B) share the UpgradeForge.
