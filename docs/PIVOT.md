# Theme pivot: Steal a Boss (planned)
Owner's direction. **Not built yet.** Every system built so far stays and works the same (catch, parade, carry, steal, bases, levels, pads, heist, race rules, speed, rewards, ranks, store). Pitch page: https://claude.ai/artifact/PNphBHAsYovmxcsTMQT6ks

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
