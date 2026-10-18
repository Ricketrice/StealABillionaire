# Steal a Billionaire — Claude rules

Roblox, phone-first. ~80% kids. Work through Roblox Studio MCP (Studio runs through Vinegar on Linux).

## Code
- Every script's source lives in this repo under `src/` (`src/<Service>/<Path>.lua`, first line `-- Studio location: <Service.Path> (<Class>)`). No Rojo.
- Edit the file, then sync it into the open Studio: `python3 tools/push_to_studio.py <files>` prints a Luau snippet to run in Edit mode (back up the old scripts first). Afterwards run the snippet from `python3 tools/verify_sync.py`: it must say "all match" before you commit.
- `tools/rbxl_scripts.py place.rbxl [--export src]` lists or exports scripts from a saved place. `tools/test_guard.sh` guards multi-client tests (max 3 clients on this 13 GB machine). `tools/kill_tests.sh --check` before every test (must be CLEAN), `tools/kill_tests.sh` after every test (pass, fail or crash): kills test server/clients, never the editor. Prefer solo tests; multi-client only when needed.
- Local place backups go in `backups/` (git-ignored).
- Linters (pinned in `rokit.toml`; `rokit install`, binaries in `~/.rokit/bin`): `selene.toml`, `stylua.toml`. Before pushing to Studio, run selene and stylua --check on changed files. Type check: `luau-lsp analyze --platform=roblox --definitions=tools/types/globalTypes.d.luau <files>` (download that file from the luau-lsp repo's `scripts/` folder; without a sourcemap, "Unknown require" and missing-child warnings are expected).

## Read order (stop as soon as you have enough)
1. `docs/PROJECT_STATUS.md` — what is built, open questions. Always read.
2. `docs/SCRIPT_MAP.md` — where things live in the place. Read before searching Studio.
3. `docs/GAME_DESIGN.md` — only the section you need.
4. `docs/ROADMAP.md` — only when planning the next milestone.
5. `docs/RETENTION_AND_JUICE.md` — when touching the first minute, rewards, UI, VFX, sound.
6. `docs/TOOLS.md` — when using Blender, Figma or other outside tools.

7. `docs/PIVOT.md` — planned Steal a Boss reskin (034). Don't apply it before 034.

## Hard rules
- **Teammate zones 4–7 (Food Court, Beach Boardwalk, Toy Town, Neon Downtown) were removed from the game (D48, owner, 2026-10-18).** Their map pieces are parked in `ServerStorage._ParkedZones4to7` (not deleted); their worker ids, rosters and save data stay in code so saves never break, but nothing reaches them. The game is 3 zones: Knight's Keep -> Sunken Kingdom -> Ember Academy. Don't bring them back or edit the parked folder without the owner's approval.
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
