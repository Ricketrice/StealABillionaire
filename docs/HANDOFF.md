# Handoff — planner notes (read this first in a new chat)
Any Claude (any account) can take over from this file + `CLAUDE.md`. Don't read other files until needed.

## You are the planner
The owner makes a Roblox game with two Claude roles:
- **Planner (this chat):** writes prompts for the builder, reviews its reports, checks numbers, explains next steps in simple words, gives copy-paste messages.
- **Builder (Claude Code on the owner's Linux PC):** works in Roblox Studio (under Wine) via the Roblox Studio MCP and headless Blender. Repo `Ricketrice/StealABillionaire`. Plans live on branch `claude/cli-device-account-switch-co1rps`; builder work on `milestone-0NN` branches. The builder's `docs/PROJECT_STATUS.md` is the live build state.

## Owner preferences
- Simple, short language. Tables + copy-paste blocks. Recommend ONE option (max 4 questions).
- Goal #1 is making money; audience ~80% kids, phone first. Fair monetization only (odds shown, no pressure, no fake timers).
- **No milestones any more:** one prompt = one big sweep. **Build first, test later** (one full test pass before launch).
- Save tokens: `/clear` between tasks, `/model sonnet` for routine work, one session at a time (two sessions ran the PC out of memory).

## The game
**Steal a Boss** (was Steal a Billionaire). Loop: catch creatures → carry home → place on base pads → earn coins → level up, buy pads → unlock zones → Boss Heist, Spell Run, steal from others.
Zones: Hideout Camp (bases) → **ours** 1 Knight's Keep · 2 Sunken Kingdom · 3 Ember Academy → **teammate** zones 4–7 (never touch).
Rarities: Common/Rare/Epic/Legendary/Secret (no "Uncommon"). 9 per zone (3C/2R/2E/1L/1S). Secret = the zone boss.
Purchases (live IDs): passes 2x Cash 2033726439, Extra Slots 2032784431, VIP 2032880454; products Cash Stack 3718403577, Cash Bag 3718403637, Cash Vault 3718403689, Starter Pack 3718403719.

## Where we are (updated 2026-10-18)
**Done today (builder commits up to `977048d` + map fit; check they are pushed):**
- **Bosses (each has 2 versions):** Boss Heist chaser at ~2.5× size + normal-size Secret collectible that roams with existing Secret odds.
  Knight's Keep = **Sir Malgrave** (5,550 tris) · Sunken Kingdom = **Aquaris** dragon (8,478; 4 new attacks: Tail Swipe, Tidal Breath, Whirlpool Slam, Riptide Dash) · Ember Academy = **Vault Wizard** (8,898). Attack timing copied from Sir Ironclad's `HeistConfig.ATTACKS`. Only Knight's Keep has a vault; Sunken/Ember vaults are after launch.
- **Knight's Keep NPCs (R6, Claude Design → GLB → Import 3D → NpcBuilder):** Common Peasant/Squire/Guard, Rare Archer/Crusader. Baron (Epic), 2nd Epic and Vanguard (Legendary) still use B1 models (no exports yet).
- **NPC "lying down / head glitch" bug fixed:** hidden R15 body animations fought the R6 rig; rigged creatures now play only their own clips.
- **New map `knights_keep_ruined`** replaced the old Keep (old one parked in ServerStorage). ~22.7k tris vs ~40.7k old. Courtyard widened, grass layer removed, clutter cut. Owner likes it.
- **Spawns:** max 8 wild creatures, refresh every 2 min (~240 rolls/h vs ~600 before; odds unchanged). If the zone feels empty → 1 min.
- Tests: creature035 439/439, lane030 97/97 (single machine; multi-client = SIMULATED when memory blocks).

**Launch sweep done (2026-10-18, commits `8fc989e`…`03c48ce`, `6d54cde`):** spawn moved off parade lane + idle drift fixed (parade creatures no longer push players), Equip OK, first-60-s arrow/goal, phone UI OK (≥40 px buttons), AnalyticsService funnel, Studio-only photo mode (press P), publish check, final smoke PASS. **Private phone test PASSED.**
- Mesh fix: Squire/Peasant/Guard/Archer uploads were broken → they use their old part-built look (`RIG_MESHES_UNAVAILABLE` in `CreatureSpecs`). Creature heads now built in code (old head mesh was another user's). Studio under Vinegar can't fetch assets ("Authentication required") — judge visuals on a live server/phone, not Studio Play.

**Now:** last polish pass on Knight's Keep (one castle-style bridge camp→gate instead of two, more detail/materials, Knight's Keep-only blue sky). Then launch.

**Launch steps (owner):** share access for 7 UI sounds → icon + 3 thumbnails (photo mode) → Dashboard: Cash→Coins, API access on, Maturity questionnaire, devices → File → Save + push → **set Public (soft launch, no promo 2–3 days)** → watch Analytics funnel (catch / pad place / 5-min stay) → TikTok/Shorts.

**First update after launch:** re-import the 4 NPCs (Import 3D, untick anims) + rebuild Templates; Baron/2nd Epic/Vanguard art; Sunken + Ember NPCs and vaults; one zone per update.
**Known small items:** pad purchases are switched OFF for launch (owner to decide — recommended ON); bottom menu row overlaps thumbstick on ≤320 px tall screens; `[ZoneSpawner]` debug prints.

## Rules that keep biting
- Model swaps only: never change IDs, rarity, odds, income, save schema (=3), progression unless the owner says.
- Kid-safe: no skulls, graves, undead (renamed Gravecall→Ironcall, Revenant→Vanguard). Original designs only.
- Builder can't take screenshots: the owner play-checks and sends pictures.
- Never report an unrun test as passed.

## Machine quirks (tell the builder when relevant)
- Low memory: restart PC before test passes, close browser, only ONE Claude session. `tools/kill_tests.sh --check` before / `tools/kill_tests.sh` after each test. Full test pass ≈ 1–2 h.
- Studio under Wine only sees `~/Documents` and `~/Pictures`.
- **Import 3D:** use File → Import 3D (not the Import Queue — it only uploads). Name the model, Scale Unit = Stud, Rig Type None/Custom, **untick the animation items** (they fail to upload); the builder rebuilds clips from its Lua builder + JSON. Drag result to ServerStorage.
- Owner must File → Save in Studio, then `! git push` after each step — commits only reach GitHub when pushed.
