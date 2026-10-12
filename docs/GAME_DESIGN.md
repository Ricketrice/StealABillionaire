# Game Design — Steal a Billionaire

**One line:** collect workers across the city, make them earn cash at your base, and steal or fight your way from broke to billionaire.
**Fantasy:** everyone wants to be rich, and everyone can see how rich you are.
Numbers marked *(tune)* are placeholders.

## Decisions (newest first — this section wins over everything below)
| # | Decision | Date |
|---|---|---|
| D17 | **UI style = Check-UI** (github.com/TemporaryLooker22/Check-UI-Clean-Roblox, MIT, commit 52ac1ed): adapt its theme/components/controller code; use only our own icons and textures, never its asset IDs. | 2026-10 |
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

## Worker Parade (D7, not built — milestone 028)
- A lane (red carpet) runs down the central strip past the bases. Mystery workers spawn at one end and walk slowly to the other.
- Walk up, press to catch (cash price, cheap at start), rarity reveal, carry to your base. Others can grab the same worker first: race + fun.
- Parade pool = starter tier (Zone 1 rarities, cheaper). Zones 1–6 still hold their own sets and better odds: the reason to unlock zones.
- **Golden Parade** every ~15 min with a countdown: better odds for everyone (shown).
- Server message for Legendary/Secret catches.
- Open: does the parade use existing worker IDs only (no new IDs) — recommended yes.

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
