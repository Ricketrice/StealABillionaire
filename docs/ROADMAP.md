# Roadmap — step by step
One milestone = one prompt = one branch `milestone-0NN`. Each ends with a commit, a local `.rbxl` backup, and an updated `PROJECT_STATUS.md`. Keep each milestone small enough to finish in one session.

## Phase A — Make it look and play like a real game
**027 Bug sweep + simple trendy map** — Phase 1 bugs, one compact bright island, lots facing a central strip. *(prompt exists)*
**028 Worker Parade + juice** *(prompt: `docs/prompts/028.md`)* — central lane with walking mystery workers (D7), Golden Parade timer, rarity-scaled reveal/cash/steal VFX + sounds + AI/code-driven animations (`RETENTION_AND_JUICE.md`, D12), one-goal HUD, first worker within 10 s.
**029 UI kit + V1 screens** *(prompt: `docs/prompts/029.md`)* — one UITheme (chunky simulator style: thick outlines, ribbons, gradients, big icons), restyle all existing UI incl. 028's; Shop/Store (passes, cash packs, starter pack), Inventory, Index with completion bonus, Daily rewards (7-day), Offline earnings popup, Playtime rewards, Settings (music, low effects). Original icons only.
**030 Zone 6 revamp + Royale Race** *(prompt: `docs/prompts/030.md`)* — sky island, racing-club look, simple race every 3 min with capsule rewards (D21).

## Growth rule (applies to every milestone)
No players = no money. Every milestone should help at least one of: **click** (icon, thumbnail, title), **first 60 seconds** (instant fun, no confusion), **come back** (daily rewards, events, updates), **share** (things worth showing friends: big steals, rare reveals, leaderboards).

## Phase B — Launch-ready V1 (make money)
**031 Core loop + monetization** — worker stats + types on all 16 (icons on cards), levels 1–10, base slots 7–12 for cash; gamepasses 2x Cash, Extra Slots, VIP; cash packs + starter pack (dev products, `ProcessReceipt` + save); favourite-worker protection, steal cooldown/cap; group reward.
**032 Launch polish** — game icon + 3 thumbnails, loading screen, sound pass, mobile check, AnalyticsService funnel (join → tutorial → first catch → first upgrade → first purchase), error logging.
**→ Soft launch.** Then a small update every week (new worker, event or limited-time item) with "UPDATE" in the title — trending games live on weekly updates.
**→** Watch D1 retention, session length, tutorial drop-off, payer conversion for 1–2 weeks before adding content.

## Phase C — Content updates (one per 1–2 weeks after launch)
**033 Merge** — Golden/Diamond, merge machine, Lucky Merge pass later.
**034 Shop gear tiers** — worker weapons/shields, player weapons/armour, effects; tiers per zone.
**035 Zone bosses** — Zone 1 boss vault + chase; Zone 6 final heist.
**036 Rebirth** — reset for a permanent multiplier; base slots 13–18 by rank.
**037+** — Legendary/Secret signature animations; remaining passes (Strong Arms first, then Auto Collect, Speed Runner, Lucky, Discount, Billionaire), events, limited workers.

Teammate zones 2–5 plug in whenever they're ready — we only provide gate + bridge + unlock price.
