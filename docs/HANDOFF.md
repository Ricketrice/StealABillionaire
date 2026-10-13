# Handoff — planner notes (read this first in a new chat)
Paste this whole file into a new Claude chat to continue planning with full context.

## You are the planner
The owner makes a Roblox game with two Claude roles:
- **Planner (this chat):** writes milestone prompts (`docs/prompts/0NN.md`), reviews the builder's reports, checks numbers, explains next steps in simple words, gives copy-paste messages.
- **Builder (Claude Code on the owner's Linux PC):** works in Roblox Studio (under Wine) via the Roblox Studio MCP and headless Blender. Repo `Ricketrice/StealABillionaire`; plans live on branch `claude/cli-device-account-switch-co1rps`, builds on `milestone-0NN` branches.

## Owner preferences
- Simple, short language. Tables + copy-paste blocks. Recommend one option when asking (max 4 questions).
- Goal #1 is making money; audience ~80% kids, phone first. Fair monetization only (odds shown, no pressure, no fake timers).
- Build features first, polish later. Will market on TikTok/YouTube Shorts (marketing plan due in 036).
- Save tokens: `/clear` between milestones, `/model` Sonnet for routine work, one test at a time.

## The game
**Steal a Boss** (pivot from Steal a Billionaire; reskin happens in 034). Details: `docs/PIVOT.md`. Pitch page: https://claude.ai/artifact/PNphBHAsYovmxcsTMQT6ks
Loop: catch creatures (parade / zones) → carry home → place on base pads → earn coins → level up, buy pads → unlock higher zones → Boss Heist, Spell Run, steal from others.
Lane (rising): Hideout Camp (bases) → **our** 1 Knight's Keep · 2 Sunken Kingdom · 3 Ember Academy (+ Spell Run parkour race) → **teammate** zones 4–7 (they agreed; their content is never touched by us).
Creatures: 9 per zone (3C/2R/2E/1L/1S); Secret = the zone boss; only $/s shown for V1.

## Built (027–033, all tested)
Parade + Golden Parade, catching + reveals, carry/steal PvP (bat, lock, safe zone), rising lane + Home/zone teleports, ranks, UI kit + store/daily/playtime/offline/index, Royale Race (031), Boss Heist + Speed trails (032), living bases, levels 1–10, pads 7–14, fair stealing, purchases (033).
Purchases (live IDs): passes 2x Cash 2033726439 (349 R$), Extra Slots 2032784431 (249), VIP 2032880454 (399); products Cash Stack 3718403577 (25), Cash Bag 3718403637 (75), Cash Vault 3718403689 (199), Starter Pack 3718403719 (49). Rename to "Coins" on the dashboard after 034.
Decisions log: `docs/GAME_DESIGN.md` → Decisions. Order: `docs/ROADMAP.md`.

## Where we are now
**034 Steal a Boss world — at Checkpoint 1, approved by the planner, waiting to be pasted to the builder:**
```
Checkpoint 1 approved:
1. Roster 3C/2R/2E/1L/1S per zone; add training_dummy ($5) and bookling ($500).
2. Sunken Kingdom incomes as listed (x10). Prices: Sunken 50k (needs Keep), Ember 500k (needs Sunken).
3. Teammate zones T4–T7: set gate ladder prices 2.5M / 7.5M / 25M / 75M, requiring Ember first. Gates show "Coming soon" (locked, no entry) until each teammate's zone is ready (one flag per zone). Don't change their worker data. Write a short income guideline for teammates in docs/PIVOT.md (zone 4 ~x300, 5 ~x1,000, 6 ~x3,000, 7 ~x10,000 of Main Street).
4. Change "worker" to "creature" in all UI text. Legendary = Golden Paladin.
Log as decisions. Studio is restarted. Make the pre034 backups and start Phase 1.
```
Next in 034: Phase 1 lane re-order → Phase 2 zones → imports (Blender meshes, owner imports with 3D Importer into `ServerStorage.Imports034`) → Spell Run → Sir Ironclad + text reskin → final report.

## Then
035 Creatures + art & detail pass (creature models, Dragon Pup fixes, heist polish, vault door trim) → 036 Launch polish + trailer kit + TikTok marketing plan + make a Roblox group → soft launch → weekly updates.

## Open items
- Owner play-check of 033 (Store tab screenshots) and the 032 stomp jump.
- Pass bought by a second account (after launch).
- Send teammates the income guideline once written.

## Machine quirks (tell the builder when relevant)
- Restart Studio before tests (swap fills up). `tools/kill_tests.sh --check` before, `tools/kill_tests.sh` after every test. Close the browser during multi-client tests.
- Studio under Wine only sees `~/Documents` and `~/Pictures` in file dialogs: copy FBX/PNG files there before importing.
- GPU "Device removed" crash = a test window; save the main editor before clicking OK.
- Owner must: File → Save in Studio, then `! git push -u origin milestone-0NN` after each milestone.
