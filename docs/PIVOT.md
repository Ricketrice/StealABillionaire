# Theme pivot: Steal a Boss
Owner's direction. **Being built in milestone 034** (decisions D41-D43). Every system built so far stays and works the same (catch, parade, carry, steal, bases, levels, pads, heist, race rules, speed, rewards, ranks, store). Pitch page: https://claude.ai/artifact/PNphBHAsYovmxcsTMQT6ks

## One line
Climb a world of kingdoms, catch their creatures, make them earn coins at your base, steal from other players, and rob each kingdom's boss while it chases you.

## Uniqueness rule
Every zone = **element + its own culture + its own building style + one signature landmark**. Two zones may share an element later (more zones upward), but never the same look. No generic "fire level" or "water level".

## Lane order (7 zones, rising)
| Zone | Owner | Theme |
|---|---|---|
| Start | us | **Hideout Camp**: bases (little forts), spawn, parade, shops. Safe zone. |
| 1 | us | **Knight's Keep** (warriors) |
| 2 | us | **Sunken Kingdom** (underwater, water dragon) |
| 3 | us | **Ember Academy** (fire wizards) + **Spell Run** parkour race |
| 4–7 | teammates | They choose their own themes freely (they move up from 2–5). |

## Our zones (names are placeholders)
| Zone | Looks like | Creatures (Common → Secret) | Boss · its 3 warned moves |
|---|---|---|---|
| **1 Knight's Keep** | Stone castle walls, banners, training yard with dummies, jousting lane, blacksmith forge. Bright, catchy first zone. | Rookie Squire · Archer · Shield Knight · Paladin · Golden King | **Sir Ironclad**, a giant armoured knight · arrow volley (circle) · sword sweep (line) · shield slam (jump ring) |
| **2 Sunken Kingdom** | Underwater: coral and shell palaces, sunken ruins, kelp forest, bubble domes, glowing anemones | Bubble Fish · Puffer Guard · Mermaid Mage · Shark Knight · Pearl Seahorse | **Aquaris, the water dragon** · whirlpool (circle) · water beam (line) · tidal wave (jump ring) |
| **3 Ember Academy** | Fire as magic, not a volcano: wizard towers with fire-crystal tops, floating spellbooks, rune circles, brass alchemy labs, lantern-lit libraries | Candle Imp · Ember Owl · Fire Apprentice · Phoenix · Flame Archmage | **Ignis the Pyromancer**, fire wizard · fireball (circle) · flame wall (line) · rune blast (jump ring) |

Every boss reuses the heist robot's 3 attack types (circle, line, ring), just themed. The Boss Heist built in 032 becomes Sir Ironclad first; the other bosses come as updates.

## Creature roster rules (owner, per zone)
- **9 creatures per zone:** 6 "normal" ones (4 Common, 2 Rare) that fit the zone theme, each with **one unique little twist** (a hat, a tool, a colour, a funny habit); then **Epic, Legendary, Secret = mega cool**.
- **Secret = the zone's boss** as a collectible (e.g. Sir Ironclad in Knight's Keep). Legendary = the boss's champion. You literally steal a boss.
- **Look and aura scale with rarity:** Common/Rare simple; Epic glow + particle aura; Legendary big aura + signature idle animation + own sound; Secret mega aura, bigger size, unique effect, server-wide announcement.
- **Stats:** for V1 the **only stat that matters and is shown is money ($/s)**, balanced so each zone out-earns the one below (zone 1 < 2 < 3) and higher rarity earns more. Attack/Speed/Defence stay in the data, hidden, for battles later (workers will fight in a future battle mode).

## Spell Run (replaces the race track, zone 3)
- A **horizontal parkour course** that climbs a little, inside zone 3 (not a tall tower): floating platforms, rune bridges, moving spellbooks, short gaps.
- **Same rules as the Royale Race** (D21/D36): pad + 15 s join, 5 s countdown, ordered checkpoints (rune gates), time limit, every finisher gets a capsule (Gold/Silver, small-race rule), Leave button.
- **Falling is not death:** you pop back at your last rune gate.
- Phone-friendly: wide platforms, short jumps, no precision jumps, ~45–60 s for a normal run.

## What else changes
- **Name:** Steal a Billionaire → Steal a Boss. Cash → Coins (display only; save fields keep their names).
- **Workers → creatures** (extends D26). IDs, rarities, odds, income stay; looks and display names change.
- **Ranks:** Peasant → Squire → Knight → Captain → Lord → Boss (same thresholds).
- **Gamepasses:** 2x Coins, Extra Slots, VIP (same perks).

## Needs before building
- **Teammates agree** to move their zones from 2–5 to 4–7 (renumbering and a 7th terrace touch shared things: zone IDs, gates, unlock prices, district detection). Their content inside their zones is not touched.
- Final names. Unlock prices for zones 2–3 (new) and the shifted ones.

## Approved creature mapping (034, D43; same id, rarity, income)
| Id | Rarity | $/s | Knight's Keep | Id | $/s | Ember Academy |
|---|---|---|---|---|---|---|
| broke_bob | C | 5 | Rookie Squire (helmet keeps slipping) | butler_barnaby | 500 | Candle Imp (flame on its head) |
| delivery_dave | C | 6 | Scroll Page (scroll tube) | caddie_gus | 600 | Ember Newt (tiny lantern) |
| training_dummy (new) | C | 5 | Training Dummy (hops on its post) | bookling (new) | 500 | Bookling (chomping spellbook) |
| street_hustler | R | 9 | Apple Archer | polo_pro_penny | 900 | Ember Owl (burning quill) |
| business_betty | R | 14 | Banner Bearer (huge flag) | chef_pierre | 1,400 | Fire Apprentice (oversized hat) |
| security_sam | E | 22 | Shield Knight | bodyguard_boris | 2,200 | Rune Golem |
| crypto_carl | E | 35 | Forge Master (glowing hammer) | hedge_fund_hank | 3,500 | Phoenix |
| ceo_chad | L | 100 | Golden Paladin (Ironclad's champion) | oil_baron_oswald | 10,000 | Flame Archmage (Ignis's champion) |
| mystery_millionaire | S | 500 | Sir Ironclad | the_trillionaire | 50,000 | Ignis the Pyromancer |

Sunken Kingdom (`SunkenKingdom`, new ids, x10): bubble_fish C 50 · hermit_porter C 60 · coral_snail C 50 · puffer_guard R 90 · mermaid_mage R 140 · shark_knight E 220 · pearl_seahorse E 350 · tide_warden L 1,000 · aquaris S 5,000.

## Income guideline for teammate zones (D43)
Our zones earn x1 (Knight's Keep), x10 (Sunken Kingdom), x100 (Ember Academy) of Main Street's slot incomes ($5 / 6 / 5 Common, 9 / 14 Rare, 22 / 35 Epic, 100 Legendary, 500 Secret). Your zones come after them, so please aim for about **zone 4 x300, zone 5 x1,000, zone 6 x3,000, zone 7 x10,000** (same 9-creature shape and the normal odds 70/20/8/1.8/0.2). Unlock prices are set by us: 2.5M / 7.5M / 25M / 75M. Your gate stays "Coming soon" until your zone's ready flag (`ZoneConfig`) is switched on. Today's placeholder rosters (Beach x6, Toy Town x15, Neon x40) are yours to replace; we don't change them.
