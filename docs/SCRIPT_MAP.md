# Script & Place Map
_One line per thing: `Path — what it does`. Claude adds lines as it finds things, so later sessions skip searching Studio._
Sources: `src/<Service>/<Path>.lua` mirrors the place (first line = `-- Studio location: ...`). Push with `tools/push_to_studio.py`, check with `tools/verify_sync.py`.

## Systems
- Catch / reveal: `NPCSpawner` + `ZoneSpawner` + `NPCWanderer` + `ZoneArea` (zone NPCs, needs `Workspace.Zones.<Name>.ZoneBoundary` + `SpawnPoints`) · `NPCClaim` (Steal prompt, reserve) · `WorkerReveal` (roll + reveal) · `WorkerService` (identity attributes) · `WorkerAppearance` + `CustomWorkerRigs` (looks) · client `WorkerRevealCard`, `Notifications`
- Carry / steal / safe zone: `NPCCarry` (shoulder carry, speed penalty) · PvP: `PvPServer` → `PvPBase` (flags, lock, protection, safe zones), `PvPSteal`, `PvPCombat` (bats), `PvPTransfer` (crash-safe journal, key `pvpx_<userId>`) · client `PvPClient`, `PvPFx`, `PvPAlerts`
- Lots, pads (no collector part: income is automatic): `PlotService` (assigns plots in PlotId order; `SPAWN_AT_PLOT` = false since 027, players spawn at the hub) · `NPCPlacement` (Place prompts) · client `PlotPrompts`
- Income tick: `PassiveIncome` (rates from `WorkerService.getIncome` / `WorkerCatalogue`; interval in `EconomyConfig`) · `CashService` (Cash attribute)
- Save / migration: `PlayerData` (schema 3, autosave) · `SessionStore` (session lock) · `DataStoreMock` (API off / tests) · `WorkerInventory` (where each worker is; `setSlotBonus`, `setStationBonus`)
- Shops: `HubShops` (Bat Boutique, Lot & Decor, Upgrade Office; stations 7–8 built at run time)
- Arena: `HubArena` (Battle Arena in the plaza; scoreboard = `Venues.Arena.Scoreboard` Label)
- Tutorial / Guide / Daily quests / shopkeepers: `HubQuests` (avatars from `ServerStorage.HubNPCs_026`, root anchored only) · client `HubClient` · client `HubNPCLife` (idle, look-at ≤15 studs, wave; tag `HubNPC`)
- Feature flags: `ReplicatedStorage.HubConfig` (ARENA/SHOPS/NPC_QUESTS/UPGRADES) and `PvPConfig` (stealing, weapons); Studio overrides = `ServerStorage` attributes `Studio*`
- Zone gates / unlocks: `ZoneConfig` · `ZoneServer` → `ZoneProgress` · client `ZoneGates`
- Entry points: `HubServer` (plots, placement, income, saves) · `HubServer026` (hub gameplay) · `PvPServer` · `ZoneServer` · `NPCSpawner`
- Workers: `WorkerCatalogue` (ids, rarity, stats, odds) · `CustomWorkers` (switch) · `ServerStorage.CustomWorkerLooks` + `_DevOnly.AvatarBuilder019R.buildAll()` → `ServerStorage.WorkerRigs019R`, `ReplicatedStorage.WorkerPreviews019R` (props fitted by rule: grip ≤0.3, upright, clear of body)
- Extra stations 7–8: spots in `HubConfig.EXTRA_STATION_SPOTS` (lot-local), pads built by `HubShops.buildStations`
- UI: `UIStyle` (tokens) · `UIKit` (components) · `WorkerState` (inventory snapshot) · `WorkerPreview` (ViewportFrame previews) · client `Hud`, `InventoryUI`, `CityLife` (025 tickers / FOR SALE)
- Zone 6 circuit: `Workspace.World.VelocityRoyale` (frozen)
- Hub screens: `TopBoard` (server; Top Billionaires rows on `Venues.Leaderboards.TopBillionaires`) · client `SkyCityLife` (YOUR BASE pillar/beam; particles on tags `Fx027Sparkle`/`Fx027Coins`/`Fx027Leaves`, culled at 140 studs) · client `CityLife` (025, now inert)
- Worker Parade (028): `ParadeServer` → `ParadeService` (walkers in `Workspace.Parade.Walkers`, path = attributes SpawnT/Speed/Offset + lane attributes on the folder; catch via client `ParadeAction` "Catch" → `tryCatch` → `NPCClaim.tryReserve`; Golden window = `Workspace.Parade` attributes GoldenStart/GoldenEnd/NextGolden; book = save `hub.book`, free catch = `hub.paradeFree`) · client `ParadeClient` (draws/animates walkers, odds panel, Golden pill, lane sign under the TopBoard gantry, FREE arrow) · numbers + flags `ReplicatedStorage.ParadeConfig` (Studio attrs StudioParade/StudioJuice/StudioGoalHud/StudioBook; published as ReplicatedStorage ParadeOn/JuiceOn/GoalHudOn/BookOn; Studio `StudioGoldenNow` = start one now)
- Juice (028): client `JuiceClient` (reveal shake/banner/pillar, carry wriggle + gold trail, place hop + coins, "+$X" pops, SAFE!, idle moves/aura, Low effects toggle = player attribute LowEffects) · `ReplicatedStorage.FxKit` (effect masters in `ReplicatedStorage.FxMasters`, built on each client) · `Hud` cash roll-up when JuiceOn
- One-goal HUD + collection book (028): client `GoalBookClient` (goals = `ParadeConfig.GOALS`) · all 028 UI styled only through `ReplicatedStorage.UITheme`
- Prompt gotcha (028): Roblox checks a ProximityPrompt's distance against the SERVER copy of its part. Client-moved parts (parade walkers) need a client-relayed remote instead of the server `Triggered`.
- Save tests: ServerStorage `StudioMemoryStore` = true puts `PlayerData` on the in-memory store in Studio (use for every Play test)

## Places in the world
- `Workspace.Venues/Arena/*`, `Venues/Shops/*`, `Venues/NPCs/*` — venue anchors (names fixed)
- `Workspace.World.SkyCity` — the 027 map: `Ground` (island slabs, paving, `ParadeLane.Lane` (attr ParadeLane), hedge, rocks, clouds, `SafeHubVolume` tagged PvPSafeZone), `LotBases`, `Hub` (spawn medallion, stalls, quest board, gantry, Zone 1 arch, `Vault` (persistent model), `Arena`, `GateLines`), `MainStreet`, `Dressing`, `ReservedPlots`
- `Workspace.World.BillionaireCity` — only `Zone6Plaza` (Zone 6, frozen) and run-time `LotDecor` remain
- `Workspace.Hub.Floor` — invisible home anchor for `ZoneProgress` (avenue centre); `Workspace.Hub.Plots` — the 12 plot models
- `Workspace.Zones.MainStreet` — NPC area 137 x 36 at x -318..-181 + 6 spawn points (catch spots)
- `ServerStorage.CityKit_027` — prop masters (Blender meshes + part props); `CityKit_027_Imports` — the raw FBX imports
- `ServerStorage._Backups` — in-place backups, one folder per change

## Studio-only test harnesses (inert in live servers)
`DevTest_PvP022` (tag `@@T022|`), `DevTest_Hub026` (`@@T026|`, arg `hub026`, 2 clients), `DevTest_Parade028` (`@@T028|`, arg `parade028`, 2 clients, needs StudioMemoryStore), `DevTest_Workers019`, `DevTest_BrokeBob_018B/018B4` (disabled)
- `DevTest_Save027` (`@@T027|`, REAL Studio DataStore): solo Play with ServerStorage `StudioTest027`="a", Stop, ="b" (+ StudioUpgrades off) = rejoin; or 2 clients arg `save027:steal`. Solo uses the Studio user's own key: back it up and seed schema 2 first, write it back after. Studio Stop does not release the session lock: the next Play takes it over after ~15 s.

## Map builder
`tools/build027/` (Kit = palette + layout numbers, Masters (+ `fromImports()`), B0_Clear … B7_Reserved). Push with `push_to_studio.py` into `ServerStorage.Build027`, run each step from a clone (`require(Build027:Clone().B1_Ground)()`); every step rebuilds its own folder. Hero meshes: `tools/blender/build_027_assets.py` → `assets/export/027`.

## Hard-coded positions (update when the map moves)
- None in game scripts (027 search). Lot-local only: `HubConfig.EXTRA_STATION_SPOTS` (0,7.5),(0,-1.5), `HubConfig.DECOR_SPOTS`, `PlotService.SPAWN_OFFSET`. All map coordinates live in `tools/build027/Kit.lua`.
