# Script & Place Map
_One line per thing: `Path — what it does`. Claude adds lines as it finds things, so later sessions skip searching Studio._
Sources: `src/<Service>/<Path>.lua` mirrors the place (first line = `-- Studio location: ...`). Push with `tools/push_to_studio.py`, check with `tools/verify_sync.py`.

## Systems
- Catch / reveal: `NPCSpawner` + `ZoneSpawner` + `NPCWanderer` + `ZoneArea` (zone NPCs, needs `Workspace.Zones.<Name>.ZoneBoundary` + `SpawnPoints`) · `NPCClaim` (Steal prompt, reserve) · `WorkerReveal` (roll + reveal) · `WorkerService` (identity attributes) · `WorkerAppearance` + `CustomWorkerRigs` (looks) · client `WorkerRevealCard`, `Notifications`
- Carry / steal / safe zone: `NPCCarry` (shoulder carry, speed penalty) · PvP: `PvPServer` → `PvPBase` (flags, lock, protection, safe zones), `PvPSteal`, `PvPCombat` (bats), `PvPTransfer` (crash-safe journal, key `pvpx_<userId>`) · client `PvPClient`, `PvPFx`, `PvPAlerts`
- Lots, pads, collector: `PlotService` (assigns plots; first descendant named "Label" = owner sign) · `NPCPlacement` (Place prompts) · client `PlotPrompts`
- Income tick: `PassiveIncome` (rates from `WorkerService.getIncome` / `WorkerCatalogue`; interval in `EconomyConfig`) · `CashService` (Cash attribute)
- Save / migration: `PlayerData` (schema 3, autosave) · `SessionStore` (session lock) · `DataStoreMock` (API off / tests) · `WorkerInventory` (where each worker is; `setSlotBonus`, `setStationBonus`)
- Shops: `HubShops` (Bat Boutique, Lot & Decor, Upgrade Office; stations 7–8 built at run time)
- Arena: `HubArena` (Takeover Tower battles)
- Tutorial / Guide / Daily quests / shopkeepers: `HubQuests` (avatars from `ServerStorage.HubNPCs_026`, root anchored only) · client `HubClient` · client `HubNPCLife` (idle, look-at ≤15 studs, wave; tag `HubNPC`)
- Feature flags: `ReplicatedStorage.HubConfig` (ARENA/SHOPS/NPC_QUESTS/UPGRADES) and `PvPConfig` (stealing, weapons); Studio overrides = `ServerStorage` attributes `Studio*`
- Zone gates / unlocks: `ZoneConfig` · `ZoneServer` → `ZoneProgress` · client `ZoneGates`
- Entry points: `HubServer` (plots, placement, income, saves) · `HubServer026` (hub gameplay) · `PvPServer` · `ZoneServer` · `NPCSpawner`
- Workers: `WorkerCatalogue` (ids, rarity, stats, odds) · `CustomWorkers` (switch) · `ServerStorage.CustomWorkerLooks` + `_DevOnly.AvatarBuilder019R.buildAll()` → `ServerStorage.WorkerRigs019R`, `ReplicatedStorage.WorkerPreviews019R` (props fitted by rule: grip ≤0.3, upright, clear of body)
- Extra stations 7–8: spots in `HubConfig.EXTRA_STATION_SPOTS` (lot-local), pads built by `HubShops.buildStations`
- UI: `UIStyle` (tokens) · `UIKit` (components) · `WorkerState` (inventory snapshot) · `WorkerPreview` (ViewportFrame previews) · client `Hud`, `InventoryUI`, `CityLife` (025 tickers / FOR SALE)
- Zone 6 circuit: (TBD)

## Places in the world
- `Workspace.Venues/Arena/*`, `Venues/Shops/*`, `Venues/NPCs/*` — venue anchors (names fixed)
- `Workspace.World.BillionaireCity` — 025 hub/lots/Main Street/metro/skyline geometry
- `ServerStorage._Backups` — in-place backups, one folder per change

## Studio-only test harnesses (inert in live servers)
`DevTest_PvP022` (tag `@@T022|`), `DevTest_Hub026` (`@@T026|`, arg `hub026`, 2 clients), `DevTest_Workers019`, `DevTest_BrokeBob_018B/018B4` (disabled)
- `DevTest_Save027` (`@@T027|`, REAL Studio DataStore): solo Play with ServerStorage `StudioTest027`="a", Stop, ="b" (+ StudioUpgrades off) = rejoin; or 2 clients arg `save027:steal`. Solo uses the Studio user's own key: back it up and seed schema 2 first, write it back after. Studio Stop does not release the session lock: the next Play takes it over after ~15 s.

## Hard-coded positions (update when the map moves)
