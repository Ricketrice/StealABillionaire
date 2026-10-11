# Project Status
_Keep under ~60 lines. Replace sections at each milestone end; don't append history._

**Current milestone:** 027 — bug sweep + simple trendy map (D6) (prompt: `docs/prompts/027.md`)
**Last finished:** 026 — hub gameplay. 022 — PvP.
**Save schema:** 3 (Studio-only DataStore for testing).

## Built
- Mystery catch + rarity reveal (ViewportFrame previews).
- 16 workers with custom looks (`CustomWorkerLooks`, `AvatarBuilder019R.buildAll()`).
- Worker stats + types — **partial** (some workers/stats only; audit in 028).
- 12 business lots, pads 1–8 per lot (stations 7–8 new), collector, owner sign, lock barrier.
- Lot stealing PvP: carry, bat, lock, protection, safe zone.
- Arena, shops, Guide tutorial, daily quests, shopkeeper NPCs (`Venues/*`).
- Zone 1 Main Street with NPC wander; Zone 6 Velocity Royale circuit.
- Feature flags (game must behave as before with all OFF).

## Not built
Worker Parade (028), worker levels, merge, gamepasses / cash packs, shop gear tiers, zone bosses, rebirth, base visual growth.

## Known issues (fixed in 027 Phase 1 unless noted)
Margaret 7 studs tall · prop grips · previews without WorldModel · station 7–8 spacing · static NPCs · stray Hello-world script in Zone 6 boss reserve · lighting style.

## Open questions (ask the owner; move answers to GAME_DESIGN → Decisions)
- Q1 V1 doc scope says Zones 1 + 2, but Zone 2 is teammates'. Is Zone 2 in our launch, and are teammates ready?
- Q2 Zone 6 boss / final heist: what is it in a racing theme? (e.g. rich racer's trophy vault)
- Q3 HP: fixed 100, or tied to Defence?
- Q4 Arena "winner takes a worker" + open lot stealing: is losing workers two ways too harsh for kids? Consider protected favourite + daily steal cap.
- Q5 Max players per server, and does base slot count fit the 12 lots?

## By-hand list for owner
(Claude fills this in — Studio settings, imports, publishing steps.)
