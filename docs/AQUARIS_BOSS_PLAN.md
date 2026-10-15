# Aquaris boss: design, budget and integration plan (concept stage, nothing imported)
Design source: `tools/blender/concept_035_aquaris_v5.py` -> `assets/blender/creatures/` / `~/Pictures/035_preview/concept_v5/` (sheet + `Aquaris_concept_v5.blend`). Studio is untouched; the current DragonKit Aquaris stays as the fallback.

## Design (v5)
Mature water dragon, blue / ice / cyan / gold. Identity without FX: long S-neck, fan-shaped gold crown + forehead gem, long swept horns, cobra-plated neck + chin tendrils, kite chest shield with cyan gem, sculpted gold shoulder plates, gold bracers, pale big claws, dark dorsal shards, bone-structured wings with hooks, tail fan. Same mesh at every scale (no baby version).

## Mesh budget (measured in Blender)
| group | tris |
|---|---|
| body (tail+hips+chest+neck+head, one mesh) | 1,312 |
| head details (jaw, brow, eyes, teeth, whiskers, mane, tendrils, neck plates) | 2,688 |
| horns + crown | 788 |
| armour (shield, shoulder plates, bracers, joint plates, belly plates) | 1,292 |
| legs, paws, claws | 1,120 |
| wings | 2,540 |
| tail finish, dorsal shards, flank + hip details | 2,876 |
| other | 160 |
| **model total** | **12,776** (target <= 14k, 196 pieces) |
FX (separate objects): captured tier 492 tris, world tier +3,236. Production merges the 196 pieces by colour/animation group to about 14 MeshParts: Body (blue/ice/plate-line split), Jaw, WingR, WingL, TailTip, Horns, Crown+Armour (gold), Trim (ice/cyan), Claws, Eyes/Gem (neon), Shards.

## Scale (existing rules, nothing changes)
World wild = `spec.scale` 3 (model as built). `CreatureScaler`: carried <= 1.3, pad <= 1.6, i.e. about 43% / 53% of world size, same model. Previews on the sheet use a 5-stud noob. At 128 px the silhouette, crown and wings read; the chest gem does not.

## FX tiers (both scalable, off by default on low-end)
- Captured: spine glow line + 4 tip orbs (~0.5k tris), client-gated by distance like other auras (`CreatureAnim`, 70 studs).
- World spawn: + flowing water ribbon, paw swirls, wave splashes, pool, 16 droplets (~3.2k tris), wild creature only (no `ClaimPhase`). Optional dramatic spawn = client-side effect on spawn, no change to spawn logic.

## Integration plan (not started; needs approval)
1. Export one FBX per colour/animation part from the .blend (extend the 035 export script); owner imports into `ServerStorage.Imports035` as `AquarisBoss`.
2. `CreatureSpecs.aquaris`: add flag `AQUARIS_BOSS` (default false). True = `model` prop `AquarisBoss` through the existing `makeModelParts` (jaw / wings / tail tip via `partAnim`); false = current DragonKit build (fallback kept).
3. FX as spec `fx` emitters + neon parts in two tiers; reveal card / Index use the same model via `WorkerPreview.frame`.
4. Tests: `creature035` solo (budget, animated parts bind, carried <= 1.3, pad <= 1.6) + a triangle-total check <= 14k + flag-off = old look.
5. Do not touch rarity, odds, spawn logic, capture, worker ids or income. Rarity is shown by the design and presentation.
Open for the owner: per-colour MeshParts (no uploads) vs one texture atlas (needs an uploaded asset id).

## Production pass (branch `art-aquaris`) - ready to import, NOT imported
- Script `tools/blender/build_035_aquaris_boss.py` -> `assets/blender/creatures/AquarisBoss.blend`, `assets/export/035/AquarisBoss.fbx`, `AquarisBossFX.fbx`, `AquarisBoss_parts.json` (copies in `~/Documents/035`). Preview sheet `~/Pictures/035_preview/boss/aquaris_boss_sheet.png`.
- 49 MeshParts named `AquarisBoss_<Piece>_<Colour>`, 8,478 tris, biggest mesh 592. Pieces: Head, Jaw, Neck, Body, TailA/B/C, WingR/L, LegFR/FL/HR/HL. FX meshes: Ring, StreamR, StreamL (864 tris); bubbles = plain Neon spheres (positions in the json).
- Import: Studio 3D Importer, one Model per FBX (Imports035: `AquarisBoss`, `AquarisBossFX`); the FBX is in Blender metres so Studio shows it 100x: do not resize, `CreatureBuilder` scales with `fit`. Size at spec.scale 1 = 2.7 x 7.1 x 3.6 studs (world = x3).
