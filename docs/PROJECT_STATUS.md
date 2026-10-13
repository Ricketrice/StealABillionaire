# Project Status
_Keep under ~60 lines. Replace sections at each milestone end; don't append history._

**Current milestone:** 031 — Zone 6 Royale Race + creature prototypes (built and tested, waiting for review). **Last finished:** 030 — The Rising Lane.
**Save schema:** 3 (029 adds optional `hub.daily/play/seen/offline/index/settings/favs`; 031 adds optional `hub.race`, D35). **Map:** `Workspace.World.SkyCity`, built by `tools/build027`.

## Built
- **031 Royale Race (D21/D34/D35), flag `RaceConfig.ENABLED` (Studio `StudioRace`), OFF = Zone 6 as before.** Glowing pad on the grid; once 180 s have passed since the last start, the next eligible player on the pad starts a 5 s countdown; whoever is on the pad at GO races (Zone 6 unlocked, not carrying, room for a worker). 3 laps, ordered server-side gates (5 checkpoints + line), fixed speed 16, no racer collisions, circuit is a no-bat safe zone while on, 64 s limit (2x a measured 31.7 s run). Every finisher: one capsule, auto-reveal, worker straight to a free pad or storage; Gold = top 3 (1st only under 4 racers) at Golden Parade odds, Silver = normal odds; odds on the gantry sign. One capsule per player per race (`hub.race` + worker written together, save started). Top 3 over the podium for 20 s. HUD: countdown, big LAP x/3 + timer, capsule pop, results.
- **031 Zone 6 look:** template props out of the world, show cars off the racing line (flank the podium), string lights/bunting/half the lamp banners/team flags/2 display cars/16 tiny orange-teal neon bits removed; gold kerbs, white barriers, one gold/navy checkered start line, 5 gold chevron arrows, VIP grandstand board, rocks + clouds under the rim. Parts: workspace 2,928 -> 2,713 (Zone 6 986 -> ~770). Not looked at in a picture (no screenshots): owner check.
- **031 creatures (D26, showcase only):** Slime Rookie / Dragon Pup / Mech Beast as imported in `ServerStorage.Prototypes.Creatures`; Studio-only stand (`StudioCreatures`) in front of the podium, one anchored body + Welds, code idles on the client. In no pool, capsule, parade or index.
- **030 Rising Lane** (D25/D27/D31, reviewed): lane north from the spawn square, 12 studs per terrace, in the ART_STYLE look (warm-grey tiled walkways with gold borders, railings with posts, gardens, rock undersides, gold/navy hazard line). T1 Main Street (moved + rotated, y 12), T2-T5 portal stops (40 long, sizes in `Kit.L.lane.stops`), T6 Velocity Royale (moved with its gate/bridge/island, y 72). **Zone 6 is behind a cash unlock** (`ZoneConfig`: price 250,000 per D33, `requires = "MainStreet"`; its gate is flagged `LaneGate`, `ZoneProgress` treats everything north of the barrier as the district). Home + Zones HUD buttons (menu grid now tries 2/3/4/6 columns; squeezes to >= 48 px on very short screens). Teleports server-validated (`LaneService`). **Ranks from the saved peak net worth** (`hub.peak`, optional field, schema 3): Broke <1k, Intern 1k, Manager 25k, CEO 250k, Millionaire 1M, Billionaire 1B. Lighting tuned per ART_STYLE (backup `_Backups.Pre030_Lighting`). Removed for the lane: reserved plot 2, the boss-vault plot, the Zone 1 gateway. Run-home measured (13.6 studs/s): T1 far catch spot 14.9 s, T2 23.0, T3 29.6, T4 36.2, T5 42.8, T6 gate 48.1. Parts 2,526 -> 2,928.
- Mystery catch + rarity reveal; 16 workers as Roblox avatars. Worker Parade + juice + goal HUD + book (028, four `ParadeConfig` flags). Golden Parade odds 50/30/14.5/5/0.5 (D16, never worse than normal).
- **029, four `V1Flags` switches (all OFF = old look and behaviour):**
  - `UI_V1_ENABLED`: Check-UI look (D18) through `UITheme` for every screen (older UIKit screens follow via `UIStyle`): slate windows, per-menu header colours (Store magenta, Daily lime, Gifts cyan, Settings silver, Index purple, popups amber), 3D bevelled buttons, square [X], GothamBlack. V1 HUD (cash pill only, D19 no gems; icon buttons), Index, Settings, inventory sort + favourites. 31 original icons on two uploaded sheets.
  - `STORE_ENABLED`: Store (2x Cash, Extra Slots, VIP, cash packs, Starter Pack): all "Coming soon" until `ProductConfig` ids are set (031).
  - `REWARDS_ENABLED` (D20, income-based with floors): 7-day daily streak (kind restart; day 7 adds a Golden ticket), playtime gifts (60 min = free parade catch), offline earnings popup (25%, max 3 h). Free catches / Golden tickets live in `hub.freeCatches/goldenCatches` and are used by `ParadeService` before cash. `INDEX_BONUS_ENABLED`: D15 bonus, claimed per zone tier, adds to income.
- Inventory requests are delivery-safe: ids + InventoryAck, client re-sends until answered, server answers repeats without running them again; a Place press with no result is re-sent as a `Place` request.
- Sky island, lots, lot PvP, arena, shops, Guide, quests, Top Billionaires board.

## Tests
- **031 (2026-10-13, Studio, all run, 2 clients):** `DevTest_Race031` `race031` (in-memory save) 127/127 (4 SIM: teleport cut, leave + rejoin mid-race): flag off/on, sign odds, eligibility (locked, full), race 1 both finish (A Gold, B Silver: small-race rule), reveal + `hub.race`, laps, podium, re-sent client messages + repeated grant = nothing, race 2 back-and-forth over the line = no lap + time limit = no reward, race 3, phone HUD (countdown, LAP/timer, results; 7 sizes), creature showcase (upright, welded, idles move, not in pools), flag off = parts as before. `race031:save` (REAL Studio DataStore) 17/17: race worker + `hub.race` survive a real save/load, second capsule refused. 3-lap times: 26.8 s solo, 31.7 / 36.9 s with 2 clients. Regression: `DevTest_Parade028` 76/76 (2 SIM). verify_sync: all match (also synced the D33 Zone 6 price into Studio, which had 500,000). Not rerun: v1029, pvp022, hub026, lane030, save029.
- 030 (2026-10-13): `DevTest_Lane030` 63/63 (layout 28 runs, portals, Zone 6 unlock, peak rank, carry + bat).
## Tests before 030 (2026-10-12 after the 029 review, Studio, all run)
- `DevTest_V1029` off 67/67 (17 SIM: clock moved, messages dropped on purpose), ui 39/39. Covers D20 amounts, Golden ticket, free catch, lost Store/Place messages re-sent, a late duplicate id not run twice.
- `DevTest_Save029` rewards rejoin 26/26 on the REAL Studio DataStore (2 SIM; catches kept); parade rejoin 24/24 (earlier today, unchanged code path).
- `DevTest_Parade028` 76/76 (2 SIM; Golden ticket first outside a Golden Parade, then free catch). `DevTest_PvP022` main 330/330 (16 SIM). `DevTest_Hub026` 118/118 (12 SIM).
- Textures: both load once their window opens (checked in Play). UI instances: 1,544 V1 on / 1,070 off (measured before the review changes).
- HUD layout (2026-10-13, `9d0a5e2`): left group x1.25 phones / x1.15 tablet+PC, overlap check at 7 sizes: 0 issues; v1029:ui 39/39 (sizes simulated).
- HUD follow-up (2026-10-13): cash pill + income directly above the menu grid as one left-centre group (top-left free for chat; tablet/PC keep under the chat window's spot, on phones the open chat may cover it); the top piece moves right of an open chat; right column (Protected, Bat, Locker, Lock Base, Special) in Check-UI 3D style (`UITheme.plate` for status tags); on short landscape phones the column is always 2 columns (buttons right, status tags left under the top piece) so it stays above the jump button. Layout check in Play, 17 cases (window, 1080p, iPad mini, iPhone 14 + SE landscape/portrait, 705x338; chat open; carrying) x normal and worst-case column (protected + bat out + charging, SIM attributes): 0 issues. Parade 76/76 (2 SIM). v1029:ui 39/39.
- Mobile is landscape only (2026-10-13): StarterGui.ScreenOrientation = LandscapeSensor (was Sensor; a place setting, not in `src/`). HUD check at the 14 landscape cases x normal/worst-case column: 0 issues.
- Windows (2026-10-13): never scale a button under 44 px (floor = 44.5 / 52, the smallest authored tap; [X] now 54 px); on screens too small for that the window is cut to the screen and its content scrolls. Checked in Play at 9 sizes (window, 1080p, iPad mini, iPhone 14 + SE landscape/portrait, 705x338, 570x270 like the test clients): every window button >= 44 px and on screen. v1029:ui 39/39 (test probe: content inside a scrolling window counts as reachable).

## Not built
Purchases (store ids still unset), worker levels, merge, gear tiers, zone bosses, rebirth, base visual growth, Legendary/Secret keyframe animations (D12, later).

## Known issues
- 034 art pass: MechBeast tri trim + part merge, Dragon Pup rework (D35). Creature imports lie pitched -90 deg (the showcase stands them up through the body part).
- Race HUD/visuals checked by layout tests only, never in a picture.
- 3-client tests need ~3.5 GB free; with the browser open the guard stopped one run.
- Zones 2–5 sit in the old sea (teammates'); only Toy Town's gate is enforced. Walkers are full R15 rigs (~245 instances each). Carry Zone 1 exit → farthest lot ≈ 20.2 s.

## Open questions (ask the owner; move answers to GAME_DESIGN → Decisions)
- Q1 Is Zone 2 in our launch? · Q2 Zone 6 boss theme? · Q3 HP fixed 100 or tied to Defence? · Q4 Arena stakes + lot stealing too harsh for kids? · Q5 Max players per server vs 12 lots? · Q6 Zones 2–5 over clouds?

## By-hand list for owner
- Save the place in Studio (031 changes are in the open Edit session; local copies `backups/pre031_phase2.rbxl`, `backups/post031.rbxl`).
- Look at Velocity Royale in Play with `StudioRace` (+ `StudioCreatures`) = true: arrows, checkered line, sign, podium names, cleaned plaza. Phone emulator for the race HUD.
- Look at the V1 screens in Play (ServerStorage StudioUiV1/StudioStore/StudioRewards/StudioIndexBonus = true, plus StudioMemoryStore = true), phone + tablet emulator.
- Publish when happy; turn on the `ParadeConfig`, `V1Flags` and `RaceConfig.ENABLED` switches you want.
