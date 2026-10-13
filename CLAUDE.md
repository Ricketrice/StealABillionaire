# Steal a Billionaire — Claude rules

Roblox, phone-first. ~80% kids. Code lives in Studio only (no Rojo); work through Roblox Studio MCP + headless Blender.

## Read order (stop as soon as you have enough)
1. `docs/PROJECT_STATUS.md` — what is built, open questions. Always read.
2. `docs/SCRIPT_MAP.md` — where things live in the place. Read before searching Studio.
3. `docs/GAME_DESIGN.md` — only the section you need.
4. `docs/ROADMAP.md` — only when planning the next milestone.
5. `docs/RETENTION_AND_JUICE.md` — when touching the first minute, rewards, UI, VFX, sound.
6. `docs/TOOLS.md` — when using Blender, Figma or other outside tools.

7. `docs/PIVOT.md` — planned Steal a Boss reskin (034). Don't apply it before 034.

## Hard rules
- **Teammate zones (today's zones 2–5; shown as zones 4–7 after milestone 034) are teammate-owned. Never modify anything inside them.** Bridges/paths/gates may stop at their entrances. Our new zones 2–3 (Sunken Kingdom, Ember Academy) are ours.
- Never change worker IDs, rarities, odds, income, economy formulas, progression or zone IDs unless the milestone prompt says so.
- Save schema = 3. Bumping it needs a migration + my approval.
- Robux never buys arena gear or zone unlocks. Odds shown on anything random. No pressure tactics. Kid-safe, original (no real brands, logos, landmarks).
- Venue anchor names are fixed: `Venues/Arena/*`, `Venues/Shops/*`, `Venues/NPCs/*`.
- Back up (local `.rbxl` + script backup folder) before each phase; commit after each working step.
- Never report an unrun test as passed. Label simulated tests.

## Token rules
- Batch MCP work into large scripts; print summaries and failures only.
- Don't re-read verified work. Don't dump whole trees — query by path from `SCRIPT_MAP.md`.
- When you discover where something lives, add one line to `docs/SCRIPT_MAP.md`.
- At milestone end, update `docs/PROJECT_STATUS.md` (keep it short; replace, don't append history).
- Running low on context: commit, write progress to `PROJECT_STATUS.md`, stop.

## Questions
The design doc may be out of date. When it conflicts with the built game or a decision is the owner's (economy, monetization, scope, teammate zones), ask — max 4 questions at a time, with a recommended option. Log answers in `docs/GAME_DESIGN.md` → Decisions.
