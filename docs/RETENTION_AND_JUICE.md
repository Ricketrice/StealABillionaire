# Retention & Juice
_Read when a milestone touches the first minute, rewards, UI, VFX, animation or sound. Every feature should name which hook below it serves._

## Hooks we use (kid-safe)
| Hook | What the player feels | In our game |
|---|---|---|
| Instant win | "I'm already good at this" | First worker caught from the parade within ~10 s of spawning, free. |
| Mystery reward | "What will I get?!" | Rarity rolled on catch, big colour pop. Odds always shown. |
| Clear next goal | "Just one more" | HUD always shows ONE next goal + progress bar (next slot, next zone, next level). |
| Visible progress | "Look how far I've come" | Base grows (floors, lights, signs); cash counter rolls up; income/sec shown. |
| Social status | "Everyone can see I'm rich" | Bases face each other, Top Billionaires board, server message when someone catches Legendary/Secret. |
| Tension | "Protect my stuff!" | Stealing + lock timer + bat. Capped so kids don't rage-quit (protected favourite, steal cooldown). |
| Appointment | "Something's coming soon" | Golden Parade every ~15 min with a visible countdown: higher rare odds for everyone (shown). |
| Come back | "My workers kept earning" | Offline earnings popup, 7-day login streak, weekly update. |
| Collection | "Gotta get them all" | Worker index per zone with silhouettes for missing ones. |

## Never (Roblox policy + kids)
Fake or hidden odds · fake countdowns on purchases · "buy now" prompts right after losing or being robbed · guilt messages ("your workers miss you") · paywalls on core progress · pressure to spend · near-miss tricks (rigging reveals to look almost-rare).

## Juice checklist (every interaction gets at least one)
- **Catch / reveal:** worker spins up, rarity-coloured burst (grey/blue/purple/gold/rainbow), sound sting scaled to rarity, light camera shake for Epic+, name + rarity banner.
- **Cash:** floating "+$20" numbers from workers, coin burst + chime at the collector, counter rolls up (not jumps).
- **Buy / upgrade:** button squash, sparkle, new item pops in with scale-bounce.
- **Steal:** alarm light + sound on the victim's base, red trail on the thief, "SAFE!" burst on reaching home.
- **Arena win:** confetti + victory effect.
- **UI:** big rounded buttons, bounce on open, icons over text (kids skim), readable at phone size.

## Rules for effects
Built in Studio: ParticleEmitter, Beam, Trail, TweenService, Highlight, Animation Editor. One master per effect in `ReplicatedStorage`, cloned on client, auto-cleanup. Client-side only for visuals. Total particles on screen kept low for phones; a "Low effects" setting.
