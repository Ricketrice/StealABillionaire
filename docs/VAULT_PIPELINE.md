# Vault wizard: Claude Design GLB -> Blender -> Roblox (status 2026-10-17)

**Status 2026-10-17 (evening): offline half DONE; Studio half DONE for solo Play (server + client DataModels), TWO-CLIENT test written but NOT RUN (memory guard).** Backup before the Studio writes: `backups/pre_vault_wizard_20261017_1504.rbxl`. Scripts: `ServerStorage.VaultWizardTest` (inert) + `ServerScriptService.DevTest_Vault035` (inert unless Studio test args). One visible preview copy: `Workspace._VaultWizardPreview` (sky platform at 300,900,0; DELETE before publishing; it runs its client driver in Play).

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

## Studio results (solo Play = separate Server and Client DataModels; measured in the engine)
- Import: 30 MeshParts + 4 markers; axes exact; size 7.11 x 3.65 studs incl. hat; Import 3D appended `.001` to part names (Builder strips it); engine face counts: body 8,898, total 10,394.
- Assembly: 30 parts, 19 Motor6D, 11 Weld trims, 18 SurfaceAppearance, 12 Neon, 13 attachments; engine joint graph reaches 30/30 parts; rest pivots vs glTF FK 0.00006 studs.
- Poses: all 8 clips x 4 times, server-applied AND client-driven: max pivot error 0.0072 studs (Nova), most < 0.003. Halo scale x1.9 verified (5.586 studs).
- Live clips (client): effects appear at their authored times (beam +0.55 s, Repossess ring +0.64, Market Crash rain +0.68, Vault Lock trail +0.55, Nova ring +1.26); every temporary is gone 3-4 s after each clip; persistent aura = 3 emitters + 6 helper parts. Walk: root moved 24 studs, hip swing +-31 deg, back to Idle.
- Replication: a SERVER-set Motor6D.Transform does NOT reach the client (client shows the rest pose); hence the attribute + client-driver design. Standard Animator: works in this one-machine Studio (track matches the table, client sees it) but the registered id is local to the machine, so a real server needs an uploaded Animation asset: not verifiable offline.
- Performance (client frame time under Wine on the owner's laptop, NOT a phone): 1 wizard 21.1 ms, 5 wizards 21.5 ms, 20 wizards 28.1 ms (p95 50 ms), all on the Walk loop; ~600 MeshParts at 20.
- NOT tested: two real clients (guard stopped the launch: swap free 3.3 GB < 5 GB), a phone, how it LOOKS (no screenshots by rule: owner review), Animator across machines.
