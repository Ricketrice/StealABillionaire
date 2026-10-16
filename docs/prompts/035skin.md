# 035skin — Smooth bending characters (one mesh + bones). Warden pilot first.
Follow CLAUDE.md. Branch `art-skin` from `art-roster` (keep `b6745da` work). FAST MODE. Weak laptop: solo tests only, one at a time.
Replaces the "cut into rigid parts" method from 035/035roster **for AI-generated bodies**. Everything else in 035roster still applies.

## Why
Cutting a fused AI body into 15 rigid parts gives seams and slabs at any big swing. Polished Roblox games don't cut. They keep the body as **one smooth skinned mesh** and bend it with **bones**. Do that.

## Pipeline (scripted, one command per character, target ≤15 min unattended)
1. **Concept image → 3D.** Use a Hugging Face image-to-3D model **whose licence allows commercial use** (prefer MIT, e.g. TRELLIS; check the licence of anything else and write it in the report). Run it yourself with `gradio_client` if you can, so the owner isn't in the loop. If quota or GPU blocks you, the owner drops the GLB in `~/Downloads/035in/` and you take it from there.
2. **Clean (Blender, headless):** remove floaters, merge, remesh only if needed, decimate to the rarity budget (C 2k / R 3k / E 5k / L 8k / S 12k tris). Bake the AI texture to one atlas: 512 for C/R, 1024 for E+.
3. **Auto-rig:** one standard skeleton for all humanoids, R15 names (`LowerTorso, UpperTorso, Head, Left/RightUpperArm, LowerArm, Hand, UpperLeg, LowerLeg, Foot`), ~15 bones, placed from the mesh's own proportions. Automatic weights, then **clean the weights**: hard armour (helmet, chest plate, pauldrons, boots) = 100% on one bone, so plates stay rigid; only cloth and joint areas blend.
4. **Props stay separate:** sword, shield, staff, hat, book = rigid MeshParts on the hand/head bone. Not skinned.
5. **Export:** FBX with armature, scale and axis fixed (known 100x and `.001` issues), into `~/Documents/035/<Name>/`.
6. **Preview board:** front, back, three-quarter, silhouette, 128px icon, next to a 5-stud noob, plus poses **rest, walk, carry, arm swing 90°**. GIF of idle + walk + carry. Note any stretching or clipping.

## In Studio (after owner Import 3D)
- Weld the skinned MeshPart to the hidden R15 root. Keep Humanoid + hidden R15 parts, so wander, carry, pad, income and Index need no gameplay changes.
- **Animation in code:** the shared client loop sets `Bone.Transform` (idle, walk, carry, pad idle, signature). Distance-gated, paused off-screen, low-effects mode = idle only. No uploaded Animation assets.
- Fallback switch per character (like `AQUARIS_BOSS`). Old look stays until the test passes.
- **Phone cost:** spawn 20 skinned NPCs in a test place and report frame time. Label it "weak laptop, estimate".

## Pilot: Gatehouse Warden ONLY, then STOP
Run the pipeline on the Warden from the same AI model you already have. Deliver one board + GIF and a ≤150-word report: tris, bones, texture size, licence of the 3D model, minutes per character, what still needs hand fixing.
Don't import the 15-part version. Don't touch Studio until the owner approves the pilot.

## If the pilot passes
Same pipeline for the whole roster, one zone per batch, one owner approval per batch. Concept images come in a set of 9 per zone, made in one sitting. Re-do B1 this way where the owner says it isn't good enough.

## Safety
Teammate zones untouched · IDs, names, rarities, odds, income, spawns unchanged · schema 3 · fallbacks kept · kid-friendly (no skulls, bones as visuals, undead) · no copying movie or brand characters · backup + commit before Studio changes.
