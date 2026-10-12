# Project Status
_Keep under ~60 lines. Replace sections at each milestone end; don't append history._

**Current milestone:** 029 — UI kit + V1 screens (reviewed 2026-10-12; review changes built and tested). **Last finished:** 028 — Worker Parade + juice.
**Save schema:** 3 (029 adds optional `hub.daily/play/seen/offline/index/settings/favs`). **Map:** `Workspace.World.SkyCity`, built by `tools/build027`.

## Built
- Mystery catch + rarity reveal; 16 workers as Roblox avatars. Worker Parade + juice + goal HUD + book (028, four `ParadeConfig` flags). Golden Parade odds 50/30/14.5/5/0.5 (D16, never worse than normal).
- **029, four `V1Flags` switches (all OFF = old look and behaviour):**
  - `UI_V1_ENABLED`: Check-UI look (D18) through `UITheme` for every screen (older UIKit screens follow via `UIStyle`): slate windows, per-menu header colours (Store magenta, Daily lime, Gifts cyan, Settings silver, Index purple, popups amber), 3D bevelled buttons, square [X], GothamBlack. V1 HUD (cash pill only, D19 no gems; icon buttons), Index, Settings, inventory sort + favourites. 31 original icons on two uploaded sheets.
  - `STORE_ENABLED`: Store (2x Cash, Extra Slots, VIP, cash packs, Starter Pack): all "Coming soon" until `ProductConfig` ids are set (031).
  - `REWARDS_ENABLED` (D20, income-based with floors): 7-day daily streak (kind restart; day 7 adds a Golden ticket), playtime gifts (60 min = free parade catch), offline earnings popup (25%, max 3 h). Free catches / Golden tickets live in `hub.freeCatches/goldenCatches` and are used by `ParadeService` before cash. `INDEX_BONUS_ENABLED`: D15 bonus, claimed per zone tier, adds to income.
- Inventory requests are delivery-safe: ids + InventoryAck, client re-sends until answered, server answers repeats without running them again; a Place press with no result is re-sent as a `Place` request.
- Sky island, lots, lot PvP, arena, shops, Guide, quests, Top Billionaires board.

## Tests (2026-10-12 after the review, Studio, all run)
- `DevTest_V1029` off 67/67 (17 SIM: clock moved, messages dropped on purpose), ui 39/39. Covers D20 amounts, Golden ticket, free catch, lost Store/Place messages re-sent, a late duplicate id not run twice.
- `DevTest_Save029` rewards rejoin 26/26 on the REAL Studio DataStore (2 SIM; catches kept); parade rejoin 24/24 (earlier today, unchanged code path).
- `DevTest_Parade028` 76/76 (2 SIM; Golden ticket first outside a Golden Parade, then free catch). `DevTest_PvP022` main 330/330 (16 SIM). `DevTest_Hub026` 118/118 (12 SIM).
- Textures: both load once their window opens (checked in Play). UI instances: 1,544 V1 on / 1,070 off (measured before the review changes).
- HUD layout (2026-10-13): left group (cash pill + menu) x1.25 on phones, x1.15 on tablet/PC (menu 70 px phone, 103 px 1080p); moves under the chat window while chat is open when it fits (PC/tablet; on phones the open chat covers it); portrait phones get the top piece on its own row and the carry bar above the touch controls. Overlap check at 7 sizes (window, iPhone 14 + SE landscape and portrait, iPad mini, 1080p) x chat closed/open/carrying: 0 issues. v1029:ui 39/39. Phone/tablet sizes and the phone chat window size are simulated.

## Not built
Purchases (031), worker levels, merge, gear tiers, zone bosses, rebirth, base visual growth, Legendary/Secret keyframe animations (D12, later).

## Known issues
- 3-client tests need ~3.5 GB free; with the browser open the guard stopped one run.
- Zones 2–5 sit in the old sea (teammates'); only Toy Town's gate is enforced. Walkers are full R15 rigs (~245 instances each). Carry Zone 1 exit → farthest lot ≈ 20.2 s.

## Open questions (ask the owner; move answers to GAME_DESIGN → Decisions)
- Q1 Is Zone 2 in our launch? · Q2 Zone 6 boss theme? · Q3 HP fixed 100 or tied to Defence? · Q4 Arena stakes + lot stealing too harsh for kids? · Q5 Max players per server vs 12 lots? · Q6 Zones 2–5 over clouds?

## By-hand list for owner
- Look at the V1 screens in Play (ServerStorage StudioUiV1/StudioStore/StudioRewards/StudioIndexBonus = true, plus StudioMemoryStore = true), phone + tablet emulator.
- Publish when happy; turn on the `ParadeConfig` and `V1Flags` switches you want.
