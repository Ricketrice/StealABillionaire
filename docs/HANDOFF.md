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

## Where we are now (updated 2026-10-16)
**034 done.** **035 creature art:** Aquaris V5 (Blender dragon) is in the game (`AQUARIS_BOSS = true`, creature035 332/332). B1 = all 9 Knight's Keep creatures built in Blender on `art-roster` (`78bf50c`), not yet imported (`KIT_B1 = false`). Gatehouse Warden AI-model test on `b6745da` (15-part cut had seams); `docs/prompts/035skin.md` = one-day skinned-mesh pilot (one smooth mesh + bones).

**Owner decision (D-next3):** launch first, $0 budget, art time-boxed. Characters ship as built. No more redesign loops; any new art method gets one pilot with a hard deadline. Character upgrades after launch, one zone per update.

**Lesson:** we lost weeks redesigning one character (V1–V5, then AI) and treating every NPC as premium. Don't recommend another art experiment without a time limit.

**Next:** builder finishes the Warden day, then **036 soft launch** (`docs/prompts/036.md`): finish B1 import, launch switches, first 60 s, phone check, icon + 3 thumbnails, simple trailer mode, analytics, publish checklist. 035b/035c postponed until after launch.

**Owner art rules (for later updates):** smooth stylised look, not blocky; kid-friendly (no skulls, bones, undead); references (wizard2/3 etc.) are design ideas only, never copy movie characters; faces our own (no community decals). Design canvas: https://claude.ai/artifact/7PceCMx1Jzw47rtp6WG8Kt

## Open items
- Owner: File → Save, push branches, Dashboard renames (Coins), teammate zone 4–7 message, delete `CreatureGallery_TEMP`, Aquaris play-check screenshots.
- Pass bought by a second account (after launch).

## Machine quirks (tell the builder when relevant)
- Restart Studio before tests (swap fills up). `tools/kill_tests.sh --check` before, `tools/kill_tests.sh` after every test. Close the browser during multi-client tests.
- Studio under Wine only sees `~/Documents` and `~/Pictures` in file dialogs: copy FBX/PNG files there before importing.
- GPU "Device removed" crash = a test window; save the main editor before clicking OK.
- Owner must: File → Save in Studio, then `! git push -u origin milestone-0NN` after each milestone.
