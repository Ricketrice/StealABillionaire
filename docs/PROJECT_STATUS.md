# Project Status
_Keep under ~60 lines. Replace sections at each milestone end; don't append history._

**Current milestone:** 028 — Worker Parade + juice (built, awaiting owner review + number approval). **Last finished:** 027 — bug sweep + sky-island map.
**Save schema:** 3 (028 adds optional `hub.book` and `hub.paradeFree` inside the existing hub field). **Map:** `Workspace.World.SkyCity`, built by `tools/build027`.

## Built
- Mystery catch + rarity reveal (ViewportFrame + WorldModel previews); 16 workers as Roblox avatars.
- **Worker Parade (028, flag `PARADE_ENABLED`)**: 8 mystery gift-box figures walk the red lane spawn → plaza (client-drawn, server path by time), Catch prompt with odds panel, first worker free, race-safe catch → reveal → carry, "Too slow!" puff, Golden Parade (60 s / 15 min, better odds, pill + lane sign countdown), server-wide Legendary/Secret message.
- **Juice (028, `JUICE_ENABLED`)**: rarity-scaled reveal (burst, shake Epic+, pillar Legendary+, name banner), carry wriggle + gold trail (Legendary+) + shocked "!!" when stolen, place hop + coins, "+$X" pops, cash roll-up, SAFE! burst, idle bounce/look + Rare+ personality moves + Epic+ aura near camera, Low-effects toggle. Code-driven only.
- **One-goal HUD (`GOAL_HUD_ENABLED`) + collection book (`BOOK_ENABLED`)**: shared top bar (Golden pill · goal · book · FX), book pages per zone with silhouettes. All 028 UI via `UITheme` (029 restyles there).
- Sky island (layout A), Zone 1 Main Street avenue, 12 lots with pads 1–8, lot PvP, arena, shops, Guide tutorial, quests, Top Billionaires board. All feature flags OFF = old behaviour.

## Tests (2026-10-12)
- `DevTest_Parade028` (2 clients): 70/70 (2 simulated). First catch after spawning 0.93 / 4.12 / 1.25 / 1.84 s; 3 same-frame races + 1 remote race = exactly one winner, no duplicates; refund on mid-spin death; Golden starts/ends, odds 40k-roll check; saves contain parade workers + book; flags off hides everything.
- `DevTest_Hub026` regression: 118/118 (PvP Studio switches off; with them on, 1 check is environment-dependent).
- Phone (Galaxy A06) + tablet (iPad 10th): no overlaps / off-screen / clipped text after fixes. Perf (Studio PC, phone emulator): 16.7 ms avg both flags on/off; +177 parts, +~2,000 instances with 8 walkers.
- Real-DataStore rejoin with parade workers: **not run** (in-memory save + leave/save JSON + sanitize reload only).

## Not built
Worker levels, merge, gamepasses / cash packs, gear tiers, zone bosses, rebirth, base visual growth, Legendary/Secret signature keyframe animations (D12, later).

## Known issues
- Zones 2–5 sit in the old sea (teammates'); only Toy Town's gate is enforced.
- Studio can't trigger the parade prompt on the server (prompt distance is checked on the unmoved server copy), so the client relays Catch; the server does its own checks.
- Walkers are full R15 rigs (~245 instances each); could be slimmed if phones struggle.
- Carry from the Zone 1 exit to the farthest lot ≈ 20.2 s (limit ~20 s).

## Open questions (ask the owner; move answers to GAME_DESIGN → Decisions)
- Q1 Is Zone 2 in our launch, and are teammates ready? · Q2 Zone 6 boss theme? · Q3 HP fixed 100 or tied to Defence?
- Q4 Arena worker stakes + lot stealing: too harsh for kids? · Q5 Max players per server vs 12 lots? · Q6 Zones 2–5 over clouds?
- Q7 (028) Approve ParadeConfig numbers: $25 catch, first free, 4 studs/s, 9 s spawn, 8 max, Golden 60 s every 15 min (first after 5 min), golden odds 45/30/17/6.5/1.5 %, golden price $25.

## By-hand list for owner
- Publish when happy; turn the four `ParadeConfig` flags on (they ship OFF).
- Optional: real-DataStore rejoin test of parade workers (DevTest_Save027 method).
