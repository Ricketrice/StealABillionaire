# Gatehouse Warden: skinned pilot (035skin, branch `art-skin`, 2026-10-17)
Blender + previews only. No Studio, nothing imported. Script: `tools/blender/ai/gw_skin.py` (one command, ~55 s unattended incl. bake). Board `~/Pictures/035_preview/skin/WARDEN_skin_board.png`, GIF `~/Pictures/035_preview/skin/WARDEN_skin_anim.gif` (copy in `assets/export/035/warden_skin/`).

## Report
- **Tris:** 4,753 skinned (Epic budget 5k). **Bones:** 15, R15 names, root `LowerTorso`. **Texture:** one 1024 atlas (albedo / normal / metalness / roughness). FBX re-import: 1 skinned mesh + armature + anchor/axis markers, Lcl Scaling 1, no `.001` names, max 4 influences, weight sums 1.0, 4.7 x 2.6 x 6.5 studs.
- **3D model licence:** `microsoft/TRELLIS.2` model card says MIT, no commercial restriction stated; dependency licences (nvdiffrast etc.) and the Space's background-removal model (BRIA RMBG-2.0, non-commercial; runs only on images without transparency) still need the owner's confirmation. Here the generation was done by the owner (quota blocked me), so the owner-drop path (`~/Downloads/035in/`) was the one used.
- **Time:** about 1 minute per character in Blender once the GLB exists.
- **Method:** weld + voxel remesh (0.003) + decimate, bake from the 96k AI mesh, procedural weights from the same joint table as the 15-part version (smooth sigmoid blends at hip/waist/neck/knee/ankle/elbow/wrist/shoulder; arm vs body split by distance from the body axis), then removed 321 faces that bridge arms and body between hip and chest (decimation made thin webs across a 2 cm gap).
- **Props:** none exist for this model; sword/shield would be separate rigid MeshParts on the hand bone.

## What worked / what still needs hand fixing
Works: idle, walk, carry (and walk while carrying): one continuous surface, no seams, no slabs, helmet / chest / pauldrons / boots stay rigid, elbows and knees bend smoothly.
Needs hand fixing: arm swing >= 90 degrees and arms-out show thin stretched needle shards at the hips (tasset flares fused to the hands) and a smeared forearm; the pauldron is fused to the chest so a big swing drags a skin sheet; the hands are small blobs (no grips); the 5k mesh is faceted and the atlas is soft. Fix = carve gaps at hand/hip and arm/torso contact on the high mesh before decimation, re-topologise the shoulder, paint hip flares to the torso, and repaint hand/forearm weights.
Bug found and fixed on the way: limb weights were inverted (step() is 1 above a joint); the renders on the board are after the fix.
Not tested: any Roblox behaviour (Bone.Transform in code, Studio import of bones, phone cost). Those need the owner's approval.

## v2 repair pass (2026-10-17, time-boxed, same mesh / textures / helmet)
Board `~/Pictures/035_preview/skin/WARDEN_skin_before_after.png`; GIF `WARDEN_skin_anim.gif` (v1 kept as `GatehouseWarden_Skin_v1.fbx`, `WARDEN_skin_anim_v1.gif`).
- **Hand/hip:** arm-vs-body ownership is now found by diffusion over the mesh surface (seeds = surely arm / surely body), not by x alone, so a hip plate that overlaps the fist in x follows the hip. Below the chest line the decision is hard and the 115 faces that still joined hand and hip (or arm and chest between hip and chest) are removed = a real slit at the contact. Result: hip needle shards and dark ribbons gone in all 90 degree poses.
- **Shoulder:** kept fused (the pauldron sits on the chest) but the ownership there is a graph gradient instead of a hard x step, so the transition spreads over the surface instead of one row of triangles. Large swings no longer show the stretched sheet in forward swings; arms-out 90 can still pull a thin skin web.
- **Forearm weights:** vertices that were already >= 85% one bone are snapped to 100% (rigid plates and forearm), only truly mixed vertices blend; fists now read as fists.
- **Numbers:** 4,955 tris (budget 5,000), 15 bones, 15 weighted groups, max 4 influences, weight sums 1.0, 1024 atlas unchanged. 43 s per run.
- **Poses tested (Blender bone rotations): rest, idle, walk, carry, carry + walk, both arms forward 90, arms out 90, one arm forward 90 / one back 45.** Remaining defects: a few small spikes on the hip flares at big swings; a faint skin web at the shoulder with arms out 90; hands are fists only; faceted mesh, soft atlas.
- **Not tested:** anything in Roblox (nothing was imported; Studio untouched).

## Isolated Studio import: suitable? PASS for an isolated import test, HOLD for any gameplay use
Checked on the FBX (re-imported in Blender): one skinned mesh `GatehouseWarden_Skin` + armature `GatehouseWarden_Rig` + anchor/axis markers; 15 bones with R15 names, root `LowerTorso`; no `.001` names; Lcl Scaling 1; 4.8 x 2.6 x 6.5 studs; textures are four separate 1024 PNGs.
Unknown until Studio: how Import 3D names/orients the bones, whether the weights import intact, `Bone.Transform` axes (the bones point down the limbs, local axes are not R15 motor axes), whether four maps become a SurfaceAppearance, and frame cost of 20 skinned NPCs.
Conditions for the import test (all from the standing rules): verified restorable backup first (Studio must be open and the place saved by the owner), a throw-away folder under `ServerStorage` or a new test place, flag off, no live worker replaced, no teammate zone touched. HOLD on anything beyond that until the import is verified.
