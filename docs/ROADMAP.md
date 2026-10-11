# Roadmap — step by step
One milestone = one prompt = one branch `milestone-0NN`. Each ends with a commit, a local `.rbxl` backup, and an updated `PROJECT_STATUS.md`. Keep each milestone small enough to finish in one session.

## Phase A — Make it look and play like a real game
**027 Bug sweep + simple trendy map** — Phase 1 bugs, one compact bright island, lots facing a central strip. *(prompt exists)*
**028 Worker Parade + juice** *(prompt: `docs/prompts/028.md`)* — central lane with walking mystery workers (D7), Golden Parade timer, rarity-scaled reveal/cash/steal VFX + sounds + AI/code-driven animations (`RETENTION_AND_JUICE.md`, D12), one-goal HUD, first worker within 10 s.
**029 Core loop audit** — finish worker stats + types for all 16 workers (icons on cards), worker levels 1–10 (cash cost, +stats, visible change at 5/10), base slots 7–12 for cash. Tutorial covers catch → carry → place → collect → upgrade in under 2 minutes.

## Growth rule (applies to every milestone)
No players = no money. Every milestone should help at least one of: **click** (icon, thumbnail, title), **first 60 seconds** (instant fun, no confusion), **come back** (daily rewards, events, updates), **share** (things worth showing friends: big steals, rare reveals, leaderboards).

## Phase B — Launch-ready V1 (make money)
**030 Monetization** — gamepasses 2x Cash, Extra Slots, VIP; 3–4 cash-pack dev products; receipt handling that never loses a purchase (`ProcessReceipt` + save); in-game store UI; owner sets prices by hand.
**031 Retention** — daily login reward (7-day streak), offline earnings popup ("You earned $X while away"), group join reward, friend-in-server bonus, favourite-worker protection, steal cooldown/cap.
**032 Launch polish** — UI redesign in Figma, game icon + 3 thumbnails, loading screen, settings (music/SFX, low graphics), sound pass, mobile UI check at phone size, AnalyticsService funnel (join → tutorial done → first catch → first upgrade → first purchase), error/report logging.
**→ Soft launch.** Then a small update every week (new worker, event or limited-time item) with "UPDATE" in the title — trending games live on weekly updates.
**→** Watch D1 retention, session length, tutorial drop-off, payer conversion for 1–2 weeks before adding content.

## Phase C — Content updates (one per 1–2 weeks after launch)
**033 Merge** — Golden/Diamond, merge machine, Lucky Merge pass later.
**034 Shop gear tiers** — worker weapons/shields, player weapons/armour, effects; tiers per zone.
**035 Zone bosses** — Zone 1 boss vault + chase; Zone 6 final heist.
**036 Rebirth** — reset for a permanent multiplier; base slots 13–18 by rank.
**037+** — Legendary/Secret signature animations; remaining passes (Strong Arms first, then Auto Collect, Speed Runner, Lucky, Discount, Billionaire), events, limited workers.

Teammate zones 2–5 plug in whenever they're ready — we only provide gate + bridge + unlock price.
