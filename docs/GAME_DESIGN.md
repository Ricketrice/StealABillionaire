# Game Design — Steal a Billionaire

**One line:** collect workers across the city, make them earn cash at your base, and steal or fight your way from broke to billionaire.
**Fantasy:** everyone wants to be rich, and everyone can see how rich you are.
Numbers marked *(tune)* are placeholders.

## Decisions (newest first — this section wins over everything below)
| # | Decision | Date |
|---|---|---|
| D37 | **Race play-check fixes (032):** first race open right away after the server starts (then every 180 s). Standing on the pad always shows a big message on screen + above the pad ("Join the race! 12", "Next race in 2:41", "Race in progress, wait for the next one", or the reason: "Drop your worker first", "Your base is full"). Pad sign = ROYALE RACE + status + "3 laps · every finisher wins a capsule"; odds on their own board beside the pad. Racers frozen on the pad for the last 5 s. Next checkpoint shown as a glowing arch (racer only) + HUD arrow. Invisible track walls for racers only. "Leave race" button in the race HUD (server-checked; no reward, walls off for them, race goes on). Time limit stays 75 s (D36): the 62 s change was reverted, bots run perfect lines, kids on phones don't. | 2026-10 |
| D36 | **031 review:** join window = the first player on the pad starts a 15 s "Join the race!" countdown on the pad sign; the big 5-4-3-2-1 shows only in the last 5 s; anyone on the pad at GO races. Time limit 75 s (2x the slowest measured 3-lap run, 36.9 s). Replaces the 5 s countdown and 64 s limit in D34. | 2026-10 |
| D35 | **Race save field `hub.race` approved** (optional, schema stays 3): `{ id, cap, uid, place }` of the player's last race capsule, written with the worker so one race can never pay twice. Creature prototypes stay as imported; MechBeast tri trim + part merge and the Dragon Pup rework go to the 034 art pass. | 2026-10 |
| D34 | **Royale Race numbers (031 Checkpoint 1):** a race every 180 s if someone is on the pad, 5 s countdown, 3 laps, limit = 2x a measured 3-lap run (31.7 s -> 64 s, max 90), podium 20 s, big "LAP 2/3" counter. **Capsule odds: Silver = normal parade odds 70/20/8/1.8/0.2, Gold = Golden Parade odds 50/30/14.5/5/0.5** (capsules are free and solo players win Gold every race), shown on the pad sign; rolled from the Zone 6 pool `BillionaireHills` (ours, 8 workers; teammates own Zones 2-5 only). | 2026-10 |
| D33 | **Zone 6 unlock price = 250,000** (owner, replaces the 500,000 proposal in D32) while teammate Zones 2-5 are closed; to be raised when they open. | 2026-10 |
| D30 | **Build first, polish in one dedicated art pass** once the lane layout is final (after 033, before launch polish/trailer). Before that, only a cheap global lighting/atmosphere tune. New builds follow `ART_STYLE.md` so nothing needs redoing. | 2026-10 |
| D32 | **030 review:** Zone 6 sits behind a cash unlock (price 500,000 proposed while Zones 2-5 are closed, 5,000,000 ladder price later; needs only Main Street); ranks never go down (peak net worth saved as `hub.peak`); thresholds Broke <1k, Intern 1k, Manager 25k, CEO 250k, Millionaire 1M, Billionaire 1B. | 2026-10 |
| D31 | **Rising Lane built (030, owner-approved changes):** lane runs north (-Z) from the spawn square, 12-stud steps, 24-wide railed ramps; T2-T5 are short ~40-stud portal stops (colour arch, sign, gate; unlock rules unchanged, teleport to the teammate island), sizes in `Kit.L.lane.stops`; T1 = Main Street, T6 = Velocity Royale, both moved as blocks. Home + Zones teleports only when not carrying / not in a fight, 3 s cooldown, server-checked. Ranks Broke > Intern > Manager > CEO > Millionaire > Billionaire from net worth = cash + 300 s of income (thresholds proposed, waiting for approval). | 2026-10 |
| D29 | **Arena hidden for V1**: keep the code and the venue, turn it off for players with a flag (ArenaEnabled = false live). No HUD button, no quests or tutorial steps pointing to it. Can return later as an update. Venue anchor names stay. | 2026-10 |
| D28 | **Simplicity rule: reveal features gradually.** New players see only the core loop (catch → carry → place → earn). Other features appear as they progress, each with a one-time "NEW!" intro (see `RETENTION_AND_JUICE.md` → Feature reveal). Max 2 event timers on the HUD at once (show the next ones). One-sentence test for every feature. | 2026-10 |
| D27 | Keep the 12 bases (2 rows of 6), spawn, shops and red parade lane as the start of the rising route; rebuild only if testing shows navigation/visibility problems. Teammates must agree before their zones or shared requirements change. | 2026-10 |
| D26 | **Theme = hybrid "Billionaire's Collection"**: keep the Steal a Billionaire brand, cash economy, workers, vaults and zones (his properties). Add creatures, monsters, robots and bosses as collectibles at **every** rarity, with more impressive designs higher up. Prototype first (Zone 6: Slime Rookie, Dragon Pup, Mech Beast), showcase only; adding to live pools needs a separate decision on roster size and odds. | 2026-10 |
| D25 | **Map = one rising lane** (like top lane-steal games, but climbing): bases + spawn + parade behind a SAFE ZONE line at the start, then zones in a line, each floating higher; Home button + zone teleports when empty-handed, run back when carrying. Uniqueness: rising lane, workers visibly working at bases, net-worth rank over heads (Broke → Intern → Manager → CEO → Millionaire → Billionaire), signature events. Needs teammate agreement for Zones 2–5. Theme: see D26. | 2026-10 |
| D24 | **Heist details + Speed**: vault opens every 10 min for 60 s (server-wide countdown); Boss Capsule = guaranteed Epic+, small Legendary/Secret chance; boss = giant security robot (slow, telegraphed attacks, 2 hits). **Speed stat before launch**: shown on HUD, raised by cash-only trails, capped; Royale Race uses fixed speed. | 2026-10 |
| D23 | **Trailer kit before launch**: a Studio-only trailer mode (hide HUD, cinematic camera paths, scripted scenes: parade, Golden Parade, reveal, steal, Boss Heist chase, Royale Race) so the owner can record ads and a trailer. | 2026-10 |
| D22 | **Boss Heist before launch (design C)**: at the end of Main Street the billionaire boss guards a vault; grab the vault worker → boss chases you to the safe zone with big telegraphed, dodgeable attacks. Caught = lose only the vault worker, keep everything else. Normal catching has no chase. | 2026-10 |
| D21 | **Zone 6 = Royale Race** (kept simple): stand on pad → race every 3 min on the existing circuit → every finisher gets a capsule (Gold top 3, Silver others; 1–3 racers: only 1st Gold) → reveal → Zone 6 worker. Ordered invisible checkpoints, 90 s limit, one capsule per player per race, no collisions, no abilities. Odds in `RaceConfig`, approved by owner. | 2026-10 |
| D20 | **Rewards are income-based** (owner, 2026-10-12), the 029 numbers are minimum floors: daily days 1–6 = 2/3/5/7/10/15 min of the player's income, day 7 = 30 min + one Golden catch ticket; playtime gifts at 5/10/20/30/45 min = 1/2/3/5/8 min of income, 60 min = one free parade catch; offline = 25% of income, max 3 h. Index bonus unchanged (D15). Values in `RewardsConfig`. | 2026-10 |
| D19 | **Cash only, no gems** (owner, 2026-10-12): one currency. HUD shows a cash pill only; no gem pill, gem prices or gem products. | 2026-10 |
| D18 | **UI style = Check-UI** (github.com/TemporaryLooker22/Check-UI-Clean-Roblox, MIT, commit 52ac1ed): adapt its theme/components/controller code; use only our own icons and textures, never its asset IDs. | 2026-10 |
| D17 | **Hub layout A, "avenue into the plaza"**: straight strip from the spawn (west) to the fixed Billionaire Plaza (east, Golden Vault + Zone 2–6 gates); Zone 1 Main Street at the west end, 158 studs end to end (~10 s); 2 reserved hub plots + 1 boss-vault plot. | 2026-10 |
| D16 | **Parade numbers approved (028, owner changes):** catch $75 (first catch still free), Golden Parade odds Common 50 / Rare 30 / Epic 14.5 / Legendary 5 / Secret 0.5 % (updated 2026-10-12: never worse than the normal parade, which keeps 70/20/8/1.8/0.2 % incl. 0.2 % Secret), Golden price = catch price. Rest as proposed: 4 studs/s, new walker every 9 s, max 8, Golden 60 s every 15 min (first after 5 min). Values in `ParadeConfig`. | 2026-10 |
| D15 | **Index completion bonus: yes.** Per zone: collect 50% of its workers → +10% cash, 100% → +25% cash + badge. Bonuses add across zones and apply to all income. Numbers *(tune)* live in `RewardsConfig`. | 2026-10 |
| D14 | **UI icons are AI-made**: Claude models simple glossy 3D icons in headless Blender, renders them to PNG (transparent, 256px), packs them into 1–2 sprite sheets, owner uploads in one batch. Panels/buttons/text are built in Studio code (UIStroke, UIGradient, UICorner, bold Roblox fonts). No icons copied from other games. | 2026-10 |
| D13 | Strong Arms pass (carry 2) comes after V1. V1 passes: 2x Cash, Extra Slots, VIP. | 2026-10 |
| D12 | **Animations are AI-made.** V1: code-driven animation by Claude (bounce, wiggle, spin, squash, tweens), so no uploads are needed. Legendary/Secret signature moves: Claude builds keyframe animations in Studio, owner publishes them in one batched checkpoint; optional: Roblox Animation Capture from a video. Uniqueness scales with rarity (`RETENTION_AND_JUICE.md`). | 2026-10 |
| D11 | Game owned by the **owner's personal account** for now. Upload all custom animations (and audio) from that same account, or they won't play. If the game ever moves to a group, re-upload them under the group. | 2026-10 |
| D10 | **V1 arena = trophies + cash only** (no worker stakes). Worker stakes come later as an opt-in mode. | 2026-10 |
| D9 | **Our zones get room to breathe**: Zone 1, hub/lots and Zone 6 medium-sized (about 2x the old Main Street, roughly teammate-island size, never overwhelming). Zones are avenues with 2 sections (Catch a Beast-style depth), landmarks, and empty reserved plots for future content. Better than teammate zones, same palette and style. | 2026-10 |
| D8 | Use player psychology + juice (VFX, animation, sound) to attract and keep players, kid-safe only — see `RETENTION_AND_JUICE.md`. Use outside tools (Blender, Figma…) when they make things better — see `TOOLS.md`. | 2026-10 |
| D7 | **Worker Parade** (Steal a Brainrot-style): mystery workers walk down a lane on the central strip; first catches happen right at spawn. Zones 1–6 = where rarer workers come from. | 2026-10 |
| D6 | **Art direction = simple and trendy** (Grow a Garden / Steal a Brainrot style): one compact bright map, lots facing a central strip, simple stalls, no detailed building kit. Attracting players beats detail. | 2026-10 |
| D5 | Next milestone after 027 = Launch-ready V1 (loop polish + monetization). | 2026-10 |
| D4 | Keep both PvP modes: open lot stealing (bat, lock, protection) **and** opt-in arena. | 2026-10 |
| D3 | Zone 6 = **Velocity Royale** (not Billionaire Hills). Still the top zone (Legendary + Secret). | 2026-10 |
| D2 | Build half from this doc, half from what's already built. The built game is the starting point; this doc is the target. | 2026-10 |
| D1 | Zones 2–5 are teammate-owned. We own Hub, Lots, Zone 1, Zone 6, and all systems. | 2026-10 |

## Core loop
1. **Start:** starter stand gives first cash (1-minute tutorial, Guide NPC).
2. **Unlock zones** with cash.
3. **Catch** mystery workers → rarity rolled on catch → pop reveal (grey, blue, purple, gold, rainbow) → carry to base.
4. **Earn:** workers earn cash every second, including AFK.
5. **Upgrade:** base slots, worker levels, merge.
6. **Fight & steal:** steal from other players' lots, or battle in the arena.

## Zones
| Zone | Theme | Workers | Owner |
|---|---|---|---|
| 1 Main Street | Starter shops | Common, Rare | us |
| 2 Food Court | Food | Food-themed | teammates |
| 3 Beach Boardwalk | Beach | Beach-themed | teammates |
| 4 Toy Town | Toys, arcade | Toys, robots | teammates |
| 5 Neon Downtown | Skyscrapers | Epic, Legendary | teammates |
| 6 Velocity Royale | Racing circuit | Legendary, Secret | us |

Map (027, D6): one compact floating island — central strip (spawn, shops, Vault, arena), 12 lots in two rows facing it, Zone 1 and Zone 6 gates at the ends, paths to Zones 2–5 entrances.

**Zone Bosses** *(not built)*: each zone's Boss guards a vault with its rarest worker; rob it and survive the chase. Zone 6 boss = final heist (theme TBD, see Q-list).

## Worker Parade (D7, built in 028 behind `ParadeConfig` flags; numbers PROPOSED)
- A lane (red carpet) runs down the central strip past the bases. Mystery workers spawn at one end and walk slowly to the other.
- Walk up, press to catch (cash price, cheap at start), rarity reveal, carry to your base. Others can grab the same worker first: race + fun.
- Parade pool = starter tier (Zone 1 rarities, cheaper). Zones 1–6 still hold their own sets and better odds: the reason to unlock zones.
- **Golden Parade** every ~15 min with a countdown: better odds for everyone (shown).
- Server message for Legendary/Secret catches.
- Uses existing worker IDs only (Main Street pool and odds). Built: $25 per catch, first worker free, 8 on the lane, Golden Parade 60 s every 15 min (odds 45/30/17/6.5/1.5%) — all PROPOSED in `ParadeConfig`.

## Workers
Stats (shown as icons): **Money** ($/sec), **Attack**, **Speed** (who hits first, how often), **Defence**. HP fixed at 100 *(or tied to Defence — open)*.

| Type | Strong | Weak |
|---|---|---|
| Earner | Money | Attack, Defence |
| Fighter | Attack, Speed | Money |
| Tank | Defence | Speed, Money |
| All-rounder | a bit of all | nothing special |

Zone 1 example *(tune)*: Penny Pincher (Common Earner $2), Bike Courier (Common Fighter $4), Mall Cop (Rare Tank $10), Robo Cashier (Epic All-rounder $20).

Stat raises: level (+10%/level *(tune)*), merge, worker gear, later zones have higher base stats.

## Arena
- Speed decides first hit. Damage = Attack − part of Defence, min 1. First to 0 HP loses.
- Winner takes one worker. Opt-in, power-level matchmaking, protected favourite worker, friends-only no-stakes mode.

## Base
| Slots | How |
|---|---|
| 6 | start |
| 7–12 | cash, rising cost |
| 13–18 | rank + cash |
| 19–24 | late game or Extra Slots pass |

Levels 1–10 (visible change every 5). Merge: 3 same → Golden (3x), 3 Golden → Diamond (10x). Base visibly grows (floors, signs, lights).

## Shop (cash only)
Worker effects $1K–50K · player weapons $5K–500K · player armour $5K–500K · worker shields $2K–200K · worker weapons $2K–200K · victory effects $1K–25K. Gear tiers match zones. *(tune all)*

## Monetization (Robux)
**V1 passes:** 2x Cash (300–500), Extra Slots (250–400), VIP (300–600). Plus small cash packs (dev products) that speed up, never skip.
**Later:** Auto Collect, Speed Runner, Strong Arms, Lucky (odds shown), Lucky Merge (odds shown), Discount Card, Billionaire.
Rules: no arena gear for Robux, zones cash-only, odds shown, no pressure, power-level matchmaking.

## V1 scope (adjusted)
Starter stand, Zone 1 + Zone 6, ~8+ workers, upgradable slots, worker levels, mystery catch, arena, lot stealing, saving, 3 passes + cash packs. Later: shop gear tiers, merge, bosses, rebirth.
