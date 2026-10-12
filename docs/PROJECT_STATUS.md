# Project Status
_Keep under ~60 lines. Replace sections at each milestone end; don't append history._

**Current milestone:** 029 — UI kit + V1 screens (built, pushed to Studio, tested; awaiting owner review). **Last finished:** 028 — Worker Parade + juice.
**Save schema:** 3 (029 adds optional `hub.daily/play/seen/offline/index/settings/favs`). **Map:** `Workspace.World.SkyCity`, built by `tools/build027`.

## Built
- Mystery catch + rarity reveal; 16 workers as Roblox avatars. Worker Parade + juice + goal HUD + book (028, four `ParadeConfig` flags). Golden Parade odds 50/30/14.5/5/0.5 (D16, never worse than normal).
- **029, four `V1Flags` switches (all OFF = old look and behaviour):**
  - `UI_V1_ENABLED`: Check-UI look (D18) through `UITheme` for every screen (older UIKit screens follow via `UIStyle`): slate windows, per-menu header colours (Store magenta, Daily lime, Gifts cyan, Settings silver, Index purple, popups amber), 3D bevelled buttons, square [X], GothamBlack. V1 HUD (cash pill only, D19 no gems; icon buttons), Index, Settings, inventory sort + favourites. 31 original icons on two uploaded sheets.
  - `STORE_ENABLED`: Store (2x Cash, Extra Slots, VIP, cash packs, Starter Pack): all "Coming soon" until `ProductConfig` ids are set (031).
  - `REWARDS_ENABLED`: 7-day daily streak (kind restart), playtime gifts, offline earnings popup. `INDEX_BONUS_ENABLED`: D15 bonus, claimed per zone tier, adds to income.
- Sky island, lots, lot PvP, arena, shops, Guide, quests, Top Billionaires board.

## Tests (2026-10-12, Studio, all run)
- `DevTest_Save029` on the REAL Studio DataStore (test users -1/-2): parade rejoin 24/24, rewards rejoin 24/24 (2 SIM: 5 min played, 1 h away). Fixed in the harness: a simulated leave now clears the plot like a real one; rewards setup skipped a worker (list changed while walked).
- `DevTest_V1029`: `v1029:off` 48/48 (11 SIM: server clock moved), `v1029:ui` 39/39 (every screen opens/closes, fits, touch targets).
- `DevTest_PvP022` main (3 clients): 330/330 (16 SIM). Earlier low-memory runs failed when A's StoreCarried request got no server answer within 3 s; the harness now retries and logs it. Not proven which side lost it.
- `DevTest_Parade028`: 72/72 (2 SIM; harness updated for the $75 price and the banner timing). `DevTest_Hub026`: 118/118 (12 SIM, PvP Studio switches off).
- UI instances in PlayerGui: 1,544 with V1 on, 1,070 off (029 screens are built hidden when off). No per-frame work; two 1 s loops (badges, open-window countdowns).
- Not done: phone/tablet emulator check and screenshots of the Check-UI look (I don't drive the camera or take screenshots; owner's visual check).

## Not built
Purchases (031), worker levels, merge, gear tiers, zone bosses, rebirth, base visual growth, Legendary/Secret keyframe animations (D12, later).

## Known issues
- Checkerboard + sunburst textures are made (`assets/export/ui/Checker.png`, `Sunburst.png`) but not uploaded: `UITheme.TEXTURES` = 0, so those two touches are left out.
- 3-client tests need ~3.5 GB free; with the browser open the guard stopped one run.
- Zones 2–5 sit in the old sea (teammates'); only Toy Town's gate is enforced. Walkers are full R15 rigs (~245 instances each). Carry Zone 1 exit → farthest lot ≈ 20.2 s.

## Open questions (ask the owner; move answers to GAME_DESIGN → Decisions)
- Q1 Is Zone 2 in our launch? · Q2 Zone 6 boss theme? · Q3 HP fixed 100 or tied to Defence? · Q4 Arena stakes + lot stealing too harsh for kids? · Q5 Max players per server vs 12 lots? · Q6 Zones 2–5 over clouds?
- Q8 (029) Approve `RewardsConfig`: daily 300/500/750/1,000/1,500/2,000/5,000; playtime 5/10/20/30/45/60 min = 150/250/400/600/900/1,500; offline 15% of income, cap 2 h, min 5 min; index +10% at half a page, +25% + badge at a full page.

## By-hand list for owner
- Upload `Checker.png` + `Sunburst.png` as Images (same account, D11) and paste the ids; I put them in `UITheme.TEXTURES`.
- Look at the V1 screens in Play (ServerStorage StudioUiV1/StudioStore/StudioRewards/StudioIndexBonus = true, plus StudioMemoryStore = true), phone + tablet emulator.
- Publish when happy; turn on the `ParadeConfig` and `V1Flags` switches you want.
