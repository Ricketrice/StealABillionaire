# Project Status
_Keep under ~60 lines. Replace sections at each milestone end; don't append history._

**Current milestone:** 028 — Worker Parade + juice (not started). **Last finished:** 027 — bug sweep + sky-island map (D6/D9, layout A).
**Save schema:** 3 (Studio-only DataStore for testing). **Map:** `Workspace.World.SkyCity`, built by `tools/build027` (see SCRIPT_MAP).

## Built
- Mystery catch + rarity reveal (ViewportFrame + WorldModel previews).
- 16 workers as Roblox avatars (`CustomWorkerLooks`, `AvatarBuilder019R.buildAll()`); props fitted by rule.
- Worker stats + types — **partial** (audit in 028).
- Sky island (layout A): spawn square → 16-stud red parade lane → 12 lots in two rows → Billionaire Plaza with the Golden Vault and Battle Arena; gates to Zones 2–6 on the plaza ring. Spawn at the hub, YOUR BASE marker, Top Billionaires board.
- Zone 1 Main Street: 2-section avenue (Coin Fountain, Clock Tower, 6 catch spots, 8 shops), reserved boss-vault plot; 2 reserved hub plots.
- 12 lots, pads 1–8 (7–8 bought at the Upgrade Office), owner sign, lock barrier. Lot stealing PvP, arena, shops, Guide tutorial, daily quests, shopkeepers with idle/look-at/wave.
- Feature flags (all OFF = old behaviour).

## Not built
Worker Parade (028), worker levels, merge, gamepasses / cash packs, shop gear tiers, zone bosses, rebirth, base visual growth.

## Known issues
- Zones 2–5 sit in the old sea (kept for the teammates); our island floats over clouds. Teammates: islands may want rock undersides.
- Only Toy Town's gate is enforced (`ZoneConfig` gate flags); Food Court / Beach / Neon / Zone 6 can be walked into (pre-027).
- 022 main PvP run (3 clients) stopped by the memory watchdog after 174/174 checks; later scenarios unverified on the new map.
- Phone layout not screenshotted; `CityLife` client script is inert (025 tickers removed).
- Carry from the Zone 1 exit to the farthest lot ≈ 20.2 s (limit ~20 s).

## Open questions (ask the owner; move answers to GAME_DESIGN → Decisions)
- Q1 V1 doc scope says Zones 1 + 2, but Zone 2 is teammates'. Is Zone 2 in our launch, and are teammates ready?
- Q2 Zone 6 boss / final heist: what is it in a racing theme? (e.g. rich racer's trophy vault)
- Q3 HP: fixed 100, or tied to Defence?
- Q4 Arena "winner takes a worker" + open lot stealing: is losing workers two ways too harsh for kids? Consider protected favourite + daily steal cap.
- Q5 Max players per server, and does base slot count fit the 12 lots?
- Q6 Should Zones 2–5 float over clouds like our island (needs teammates' OK)?

## By-hand list for owner
- Publish the place when happy (File → Publish to Roblox). Blender meshes are already imported (027).
- Optional: run the 3-client 022 PvP test with more free memory (close the browser first).
