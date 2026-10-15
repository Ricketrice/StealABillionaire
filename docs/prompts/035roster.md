# 035roster — Character production reset (plan first, then batches)
Follow CLAUDE.md. Branch `art-roster` from `art-aquaris`. FAST MODE: ONE planning checkpoint, then batch production. **Weak laptop:** solo tests only, one at a time. No MCP editor-camera moves or screenshots.
This replaces `035art.md` and the 035 "LOOK RULE" (noob body). Game name: **Steal a Boss**.

## Goal
Stop building characters one at a time. Set up a reusable pipeline that brings the whole collectible roster up to the quality of a polished, modern Roblox game, with batches the owner approves once each. Aquaris V5 (now in game, `AQUARIS_BOSS = true`) is the quality benchmark for bosses, not a shared body.

## 1. Read and look
- Read `CLAUDE.md`, `PROJECT_STATUS.md`, `SCRIPT_MAP.md`, `CreatureSpecs`, `CreatureBuilder`, `DragonKit`, `tools/blender/*`, `assets/blender/*`.
- Find the owner's reference images by searching `~/Pictures`, `~/Documents`, `~/Downloads` and the repo for: `wizard1` (may not exist), `wizard2`, `wizard3`, `knight1` (may not exist), `knight2`, `knight3`, `knight4`, `normal1`, `boss1`, `sigBoss1` (any extension). **Open and look at each image.** List any you can't find or read. Never claim to have seen one you didn't.
- Use them for design language only (proportions, armour and clothing build, silhouette, detail level). Never copy a character, logo or protected design.

## 2. Art direction
A polished, modern Roblox look: stylised, readable on a phone, kid-friendly (cool or cute, never scary).
- **Want:** distinct silhouettes, expressive faces, sculpted clothing and armour that look built-in, clear rarity steps, one cohesive style across the roster.
- **Avoid:** Minecraft or LEGO blockiness, balloon bodies, plain default avatars with stuck-on accessories, repeated silhouettes, random shapes, neon or particles hiding a weak model.
- **Faces:** our own. Sculpted into the head mesh or part-built. No community decals or outside asset IDs.

## 3. Quality tiers
| Tier | Rarity | Reference | Bar |
|---|---|---|---|
| 1 Standard | Common, Rare | `normal1` | Polished stylised body, readable face and hair or hat, efficient detailed outfit, one prop, clear personality. Minimal FX. Shared body and animation base. |
| 2 Premium | Epic, Legendary | `knight2-4`, `wizard2-3`, `boss1` | Knights: distinctive helmet and crest, layered chest plate, real pauldrons, gauntlets, boots, cape, belts. Wizards: distinctive hat or hood, layered robes, collars, sleeves, staff or book, controlled element FX. Strong front and back silhouettes. |
| 3 Signature boss | Secret (zone bosses) | `sigBoss1`, `boss1`, Aquaris V5 | Unique body (not always a dragon, knight or humanoid), sculpted detail that works without FX, its own expression, signature idle, its own aura. Two states: **World** (full aura, big presence) and **Captured** (same identity, small, light FX). |

## 4. Audit (read only, change nothing)
- Count every collectible in the actual config, not the gallery: ID, name, rarity, zone, current model and rig, active / prototype / gallery-only, meets the bar (yes / minor / redesign), family, reusable assets.
- **Teammate zones 4–7:** list their creatures, but mark them `teammate-owned, out of scope`. Never touch them.
- Don't rebuild what already meets the bar.

## 5. Reusable pipeline (propose, don't build yet)
Families: 1 standard folk and workers · 2 knights and armoured · 3 wizards and mages · 4 premium humanoids · 5 dragons · 6 other creatures and unique bosses.
Shared per family: base body mesh, part library (helmets, plates, robes, hats, weapons), material and colour palette, rig and joint standard, code animation set, export script, contact-sheet script, validator. Individuality comes from heads, outfits, gear, proportions and colour. Never one identical body for everyone.
The pipeline must do batch builds, automatic FBX export, contact sheets (front, back, three-quarter, silhouette, 128px icon, scale vs a 5-stud noob), batch Studio wiring, and automatic validation (budgets, joints, names, `creature035`).

## Fixed technical rules (from 035, still apply)
- Keep Humanoid + hidden R15 root + R15 names, so wander, carry, pad, income and Index need no gameplay code changes.
- Separate MeshParts per moving piece, pivots at joints, Motor6D. Each mesh under Roblox's 20k-triangle limit.
- **Triangle targets:** Common ≤2k, Rare ≤3k, Epic ≤5k, Legendary ≤8k, Secret ≤12k. **Part budgets:** C30 / R45 / E80 / L150 / S250, FX included.
- Colours and materials first. Textures only if a family really needs them; list them, because the owner uploads them.
- FX tiers: world (≤80 studs), captured (carry and pad, subtle), UI cards (static glow only; particles don't show in ViewportFrames). Low-effects mode turns FX off.
- Animation in code: one shared client loop, distance-gated, paused off-screen. No uploaded Animation assets.
- Scale caps: carried 1.3x, pad 1.6x, Index and reveal full size.
- Owner only does Import 3D. Naming, scale, colours and wiring are the builder's job.
- Keep old models as fallbacks behind a switch (like `AQUARIS_BOSS`).

## Batch rules (after plan approval)
Per batch: design → Blender models with the shared tools → ONE contact sheet + 3 s idle and signature preview → validate → STOP for ONE owner approval → owner Import 3D → builder wires, runs `creature035` solo (hang → pending) → commit → owner File → Save.
No per-character approvals.

## Launch priority
P0 working gameplay, saves, inventory, PvP · P1 the visible roster consistent, Knight's Keep first (what new players see) · P1 one polished signature boss (Aquaris, done) · P2 Epic and Legendary batches · P3 more bosses and extras after soft launch. Don't hold the launch for cosmetic perfection.

## Safety
Teammate zones untouched · IDs, names, rarities, odds, income, spawns, progression unchanged · schema 3 · fallbacks kept · no deleting working models during the audit · back up and commit before big changes · no 035b or 035c.

## FIRST DELIVERABLE, then STOP
One compact report (≤400 words):
1. Number of real collectibles (ours vs teammate).
2. Quality status counts (meets / minor / redesign).
3. What each reference set shows (wizard, knight, normal, boss, sigBoss), plus any missing refs.
4. Families and which creatures are in each.
5. Reusable systems we already have.
6. Batches with counts, in order.
7. Pre-launch priorities.
8. Technical and performance risks (weak laptop, wanderer counts, phone FPS).
9. The largest safe first batch.

Plus `docs/ROSTER_MANIFEST.md`: one row per collectible with ID, name, rarity, zone, family, tier, asset status, planned batch.
**STOP for owner approval of the plan.** Production starts only after that.
