# Vault wizard: Claude Design GLB -> Blender -> Roblox (status 2026-10-17)

**Status: offline half DONE and verified offline; Studio half BLOCKED at the backup gate (no Studio write made).** Nothing here is enabled in production; nothing lives in the Workspace/StarterPlayer; all scripts go to `ServerStorage.VaultWizardTest` (inert).

## Offline results (all measured, not simulated; none of it ran in Roblox)
- Geometry: 27 body meshes 14,996 -> **8,898 tris** (welded, collapse-decimated with UV seams delimited, smooth-by-angle shading, palette UVs snapped to swatch centres, flat 256x32 palette so no bleed). Halo 3,0k -> 1,488. 11 FX meshes (19.8k tris) dropped and rebuilt as native effects. Compare images: `~/Pictures/035_preview/vault2/r/compare_*.png`.
- Rig: `assets/export/vault/VALIDATION.txt` (PASS): R15 hierarchy, 15 R15 parts, mesh origins on joints (C1 = identity), L/R symmetric. 19 Motor6Ds (15 R15 + hat, scepter, halo, gem) + 11 neon welds = 30 parts. Chain vs glTF FK: worst 0.0074 stud over 8 clips x every 1/24 s.
- Clips (solver `vw_anim_fix.py`, depth of arm/scepter vertices inside torso/head/hat/legs, minus the rest overlap): Market Crash 90 -> 8 arm-frames over tolerance, Bankrupt Nova 107 -> 5 (15.6 -> 2.0 cm worst), Repossess 5 -> 1, Steal_Grab 2 -> 0; foot sink 7.7 / 7.0 / 4.2 / 4.1 cm -> <= 1.0 cm (Root lift); Idle/Walk/VaultLock/HostileTakeover verified (only the foot lift applied). Max arm offsets used: 30 deg abduction, 29 deg flexion, 21 deg elbow. Before/after sheet: `assets/export/vault/VAULT_clips_before_after.jpg`. Loops close (first=last < 0.5 deg), no root motion, 0.15 s cross-fade covers every Idle transition.
- Residual: Nova 5 and Market Crash 8 arm-frames still ~1-2 cm over tolerance; a tolerance of 1.2 cm is about 0.03 stud.

## Reproduce (offline)
`tools/blender/vault/run_pipeline.sh` (solver ~25 min; `--skip-fix` reuses it). Scripts: `vw_prep` (weld/decimate/FBX), `vw_textures`, `vw_fx_textures`, `vw_anim_fix`, `vw_convert` (+ `_lib`: Motor6D C0/C1/Transform, key reduction, Luau + expected values), `vw_validate`, `vw_render`/`vw_sheet`.
Convention contract for future characters: R15 joint-node names, one mesh per joint node with identity local transform, `_Neon` sibling meshes, `FX_` nodes = cosmetic (spinners must be n-fold symmetric), palette-only UVs on 8 swatch centres.

## Studio steps (owner, in this order)
1. In the open place: **File > Save** (this is the restorable backup; do NOT import first). Then tell me; I copy `~/Documents/latest.rbxl` to `backups/` and verify it against live Studio.
2. **Home > Import 3D** (or Asset Manager > Bulk Import is NOT enough): pick `assets/export/vault/VaultWizard.fbx`; Scene: scale 1, "Import as Model" / one model, no rig generation, no "Upload to Roblox" if the dialog offers it; accept. Drag the resulting Model into `ServerStorage` (any folder). I move it to `ServerStorage.VaultWizardTest.Imported`.
3. Do not save again until I report.
Then (me): upload 6 images (palette colour/metalness/roughness + ring/sigil/coin from `assets/export/vault/`), push the `src/ServerStorage/VaultWizardTest` scripts (`tools/push_to_studio.py`), `Builder.build`, then the Play tests (`Tests/Checks`, `Probe`, `Harness`; solo + 2 clients).
