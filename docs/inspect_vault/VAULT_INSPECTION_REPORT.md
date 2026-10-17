# Vault.glb (Baron Vaultbane) technical inspection — 2026-10-17
Inspection only. Original `~/Pictures/035_preview/concept/Vault.glb` untouched; the live Blender session was not used (headless Blender on a fresh import copy, `~/Pictures/035_preview/vault/vault_inspect_copy.blend`). No Studio, no gameplay, no paid tools. Scripts: `tools/blender/inspect_vault/iv_*.py`. Images/data in this folder: `VAULT_rest.png`, `VAULT_clips_A.png`, `VAULT_clips_B.png` (8 frames per clip), `VAULT_optimise_compare.png`, `anim_analysis.txt` (all numbers below), `vault_roblox_motor6d.json` (converter output).
**Nothing here was tested in Roblox. "Convertible" means the data maps; it is not a claim that it plays in Studio.**

## 1. Model
- Generator: three.js GLTFExporter r184. **41 meshes, 32 empties, 0 armatures, 0 skins, 2 materials, 2 images (128x16 palette), 8 animations.** Scene `AuxScene`, root `Baron_Vaultbane`.
- **Triangles 39,136, vertices 117,408 (every vertex is split: flat-shaded, 3 verts per triangle; weld before use; "non-manifold/boundary" counts in the raw scan are only this splitting).**
- Character meshes (not under `FX_`): 27 meshes, **14,996 tris**, of which 6 are `_Neon` pieces. FX under `FX_` nodes: 14 meshes, **24,140 tris (62% of the file)**: pure effects 19,756 (CoinRainMarks 6,400; GroundSigil 4,056; NovaRing 3,840; Shockwave 2,560; TakeoverBeam 1,344; CoinRain 1,408; AuraFlames 140; ScepterGem 8) + two design pieces parked under FX nodes: VaultHalo (ship wheel, 2,976) and CoinOrbit (1,408).
- Heaviest body parts: UpperTorso 3,524 (+348 neon), LowerTorso 1,924, LedgerScepter 1,432 (+960 neon), WizardTopHat 1,208 (+520), Head 1,124, feet 484 each. Largest mesh 6,400 (Roblox limit 20,000 per mesh: all pass).
- Materials: `Vaultbane_Palette` (20 meshes, base colour palette 128x16, rough 0.5, metal 0) and `Neon` (21 meshes, emissive lavender 0.37/0.15/1.0, strength 1.48). Every mesh has a UV map (palette swatches). No missing materials, no degenerate triangles, no duplicate objects found.
- Size: character 1.47 x 0.83 x 2.91 units (hat tip at 2.91; HRP at 0.994). Front is glTF +Z, right is -X (Roblox: front -Z, right +X = a 180-degree turn about Y). At 3.0 studs/unit: ~8.7 studs tall with hat (HRP 2.98, neck 5.0); 2.0-2.5 studs/unit gives Legendary-size 5.8-7.3.
- Look: strong, very Roblox-friendly blocky style (top hat, ship-wheel halo, scepter, gold trim, lavender neon). Faceless (visor/monocle). Suitable.
- **Optimisation test (copy): weld + planar dissolve only saves 1%; collapse-decimate at 55% on the 12 meshes >300 tris gives 9,060 tris (60%) and the look is unchanged at normal view** (`VAULT_optimise_compare.png`). So ~9k character tris is realistic, within the Legendary (8k) to Secret (12k) budgets with a little more trimming.

## 2. Rig and joints
- **No armature, no skinning: 27 separate rigid meshes under a hierarchy of 32 joint empties with animated transforms.** That is the ideal input for Motor6D (rigid parts), not for skinned meshes.
- Hierarchy: `Baron_Vaultbane > HumanoidRootPart > Root > {LowerTorso, Waist > {UpperTorso, Neck > Head (+ Accessory_WizardTopHat), LeftShoulder > Elbow > Wrist > Hand, RightShoulder > ... (Tool_LedgerScepter on RightWrist)}, LeftHip > Knee > Ankle > Foot, RightHip > ...}`; plus FX nodes under the HRP.
- Names are **exactly the R15 Motor6D joint names** (Root, Waist, Neck, Left/RightShoulder, Elbow, Wrist, Hip, Knee, Ankle) and R15 part names (UpperTorso ... LeftFoot). Mesh origins sit exactly on their joint (C1 is the identity for all 15 joints). It is not "already an R15 rig" (it is a node tree, proportions are boss-stubby: hips at 30% of height), but the mapping is mechanical.
- **Motor6D conversion (done offline in `iv_convert.py`):** C0 = Part0^-1 * JointRestWorld, C1 = Part1^-1 * JointRestWorld, Transform = RestLocal^-1 * AnimLocal, converted by a 180-degree turn about Y and scaled to studs. Verified: Part1 = Part0 * C0 * Transform * C1^-1 reproduces the glTF forward kinematics with **0.000000 studs error over 404 (clip, frame) samples x 16 parts**, and matches Blender's evaluated poses to <= 0.004 units in 10 of 12 test poses (the only differences, <= 0.043 units / 0.13 stud, are the scepter in `Event_BankruptNova`, where Blender keeps stale values on un-keyed channels). Output: 15 joints, 8 clips, 366 joint-keyframes, 34 KB JSON.

## 3. Animations (8 clips found, matching the description)
All clips: real keyframes, 24 fps, LINEAR interpolation, 2-7 keys per channel (sparse), first key = last key (every clip loops cleanly), body joints rotation only (+ Root translation), FX nodes scale / translate / rotate. HRP never moves (clips have no travel; speed is the game's). Peak angles from rest (deg), feet (cm vs ground), "inter." = limb-vs-body triangle intersections above the rest baseline (rest already has upper arms 72/64 and the scepter 397 inside the torso).
| Clip | Dur | Joints | Peak motion | Feet | Intersections above rest | Data convertible | Motion verdict |
|---|---|---|---|---|---|---|---|
| Idle | 3.0 s | 14 | <= 8 deg | -1.9 cm | upper arm 92 | PASS | **PASS** |
| Walk | 1.0 s | 11 | hips 32, knees 40, shoulders 23 | -3.9..+4.7 cm | upper arms 135/157 | PASS | **PASS** (arms swing into the pauldron/torso overlap) |
| Steal_Grab | 1.4 s | 12 | L shoulder 94, elbow 66 | R foot -7.6 cm | L forearm 34, upper arm 221 | PASS | **PARTIAL** (forearm into torso, foot sinks) |
| Normal_Repossess | 1.6 s | 14 | R shoulder 137, wrist 126 | -4.1 cm | R forearm 293, hand 22, upper arm 435 | PASS | **PARTIAL** (arm through torso at the raise) |
| Event_MarketCrash | 2.4 s | 7 | shoulders 131/157, wrist 143 | none | hand 115, L/R forearm 196/290, upper arms 412/440 | PASS | **PARTIAL** (hands/forearms into torso, 19-28 of 29 samples) |
| Event_VaultLock | 2.4 s | 5 | L shoulder 86, elbow 57 | none | L forearm 17, upper arms 245/195 | PASS | **PASS** with minor overlap (wheel moves in front as a shield) |
| Event_HostileTakeover | 2.0 s | 9 | L shoulder 92, elbow 65 | -4.2 cm | forearm 21, one-frame R forearm 14 | PASS | **PASS** with minor overlap |
| Event_BankruptNova | 2.8 s | 13 | shoulders to 132 deg twist, hips 33, knees 50 | -7.0..+9.6 cm | hands into torso 47-102, forearms 209-233, scepter 783 / head 74 | PASS | **PARTIAL** (hands/scepter through body; foot sinks 7 cm) |
No clip is broken or distorted (no scale on body joints, no pops); the issue is the usual rigid-block problem of arms passing through a boxy torso. All rendered frames are in `VAULT_clips_*.png`.

## 4. VFX (14 meshes under `FX_` nodes): which become Roblox-native
| FX | Now | Animation | Roblox replacement | Mobile cost as authored |
|---|---|---|---|---|
| FX_AuraFlames_A/B | 70-tri neon spikes | bob 0.1 | keep as 2 small Neon parts or a ParticleEmitter | cheap |
| FX_GroundSigil | 4,056-tri disk | spin 60-180 deg | flat part + Decal/texture (12 tris), Tween spin | **too heavy** |
| FX_BossAura | group of the above | - | grouping only | - |
| FX_VaultHalo (wheel) | 1.6k + 1.4k neon, design piece | spin, scale 1->1.9, flies in front (VaultLock) | keep as MeshPart (decimate ~50%), animate by Motor6D/Weld tween | medium |
| FX_CoinOrbit | 896 + 512 | spin 45-135 deg | keep or ParticleEmitter coins | medium |
| FX_ScepterGem | 8 tris | spin | keep | trivial |
| FX_Shockwave | 2,560-tri ring | scale 0.001 -> 4.5 | flat ring mesh (~100 tris) or ParticleEmitter ring texture + tween | **too heavy** |
| FX_NovaRing | 3,840 | scale -> 10 (several rings) | ring texture ParticleEmitter / thin cylinder tween | **too heavy** |
| FX_CoinRain | 896 + 512 | scale + falls 2.9 m | ParticleEmitter (coin texture), burst | **too heavy as one mesh** |
| FX_CoinRainMarks | 6,400 | scale 0.001 -> 1 | Decal marks / small ring particles | **too heavy** |
| FX_TakeoverBeam | 1,344 neon beam | scale 0.001 -> 1 from the hand | Roblox `Beam` between two Attachments | native, cheap |
Effects are real animated geometry (scale ramps from 0.001), not placeholders; the intended look survives as long as colours (lavender neon, gold) and timings are copied. Estimated mobile-safe version: effects ~<2k tris or particle-based.

## 5. Pipeline feasibility: Claude Design -> GLB -> Blender -> Roblox
Recommendation: **custom conversion script + data-driven animation**, with Studio's Import 3D only as the mesh importer. Studio docs say the importer accepts `.fbx`, `.obj`, `.gltf` (not `.glb`) and "supports meshes with... rigging, skinning, and animation data" but do not say that unskinned joint nodes become Motor6Ds or that embedded clips become animations; that must be tested in Studio before relying on it, and a custom path gives deterministic results anyway.
| Step | Automatable? | Status |
|---|---|---|
| Parse GLB, map R15 names, build C0/C1/Transform, bake clips to keyframe tables | **Yes, fully** (names are R15) | prototype done and verified offline |
| Weld + decimate + export each part as its own FBX/glTF, mesh origin on the joint | Yes (headless Blender) | decimation proven on a copy |
| Import the meshes into Studio | **Manual**: Import 3D dialog, one click-through per character (no script API for FBX import) | ~5 min |
| Create MeshParts + Motor6D + welds from the JSON, assign MeshIds, colours/SurfaceAppearance, Neon material | Yes (Luau through MCP) | not written/tested |
| Animation playback | Yes: code sets `Motor6D.Transform` from the tables (no uploaded assets), or KeyframeSequence for Studio previews | not tested in Roblox |
| VFX | **Manual first time per effect type** (Shockwave, Nova, CoinRain, Beam, Sigil templates), then reusable and parameterised (colour, size, time) | 4-5 templates cover this boss |
| Palette texture (128x16) | Automatic, but bilinear filtering may bleed swatch edges: test; fallback = one Part.Color per colour group | untested |
| Gameplay hookup (hidden R15, pad, carry, Index) | Manual per integration pattern, reusable | not started |
Estimated manual work per future character after the pipeline exists: ~30-60 min (import, scale choice, collision/hitbox, test) + new FX only when the design adds one (1-2 h each the first time). First character incl. templates: ~1-2 days.
Knight's Keep / Sunken Kingdom / Wizard's Realm support: yes if Claude Design keeps the same naming convention and node structure; one sample proves nothing about consistency.

## 6. Three biggest blockers
1. **Nothing is proven in Roblox yet**: importing 27+ parts, building Motor6D rigs with non-R15 proportions, playing the data on a Humanoid-less or hidden-R15 NPC, palette texture filtering, Neon look. (Needs a Studio test with the owner's backup rule.)
2. **Part and effect count / cost**: 41 MeshParts per boss (27 character incl. 6 Neon, 14 FX) plus ~19.8k effect tris authored as full geometry; 20 such NPCs on a phone is unmeasured and likely too heavy. FX must be replaced by particles/beams/decals, and Neon parts cannot be merged.
3. **Rigid-block clipping**: arms pass through the torso in 4 of 8 clips (Steal_Grab, Repossess, MarketCrash, BankruptNova; one fits only by tolerance), plus 4-8 cm foot sink; needs per-character animation fixes (shoulder pivots/offsets or retiming) because the pipeline cannot invent clearance.

## Verdict: **PARTIAL**
Best input so far: named R15 joints, rigid parts with origins on joints, 8 clean looping clips, palette-only textures, a design that survives 40% decimation. The conversion maths is verified offline. It is not PASS because nothing has run in Roblox, the effects are heavy geometry that must be rebuilt natively, and arm clipping needs fixes. Next step (needs your approval, Studio rules apply): a one-character Studio proof with the converted rig and the Walk/Idle/Steal_Grab clips, before any more Claude Design characters are ordered.
