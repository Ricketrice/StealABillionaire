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

## Studio test, step log (2026-10-17, from `d1b366f`)
- **Studio MCP:** connected (1 instance, "Steal a Billionaire", placeId 96425239551061, Edit mode, Studio 0.743.0.7431133).
- **Backup (verified):** the owner saved the open place at 03:34:25 to `~/Documents/latest.rbxl`; copied to `backups/pre035_warden_import_20261017_0334.rbxl` (git-ignored, sha256 identical). Checked against live Studio: all 145 scripts match by length+hash (script-level check only; non-script instances were not compared). Older files (`latest.rbxl` of Oct 16, `pre035_boss_import.rbxl`) predate this session and were not used.
- **Rig conventions found:** hidden R15 rig = `ServerStorage.NPCModels.MysteryNPC` (Humanoid R15, stored HipHeight 0, `Animate` LocalScript with stock animation ids, HumanoidRootPart 2x2x1) re-proportioned by `CreatureBuilder`; `NPCAnimation` plays walk/idle through the Animator; kit meshes are welded to the hidden parts. The skinned Warden is a Roblox "R1" rigged mesh (MeshPart + Bone children); Studio docs: bones are driven by animations on skinned meshes (`Bone.Transform`) and can be set from code like `Motor6D.Transform`.
- **Textures uploaded (4 images, 1024, to the owner's account via the MCP uploader):** ColorMap `rbxassetid://110498778424966`, NormalMap `rbxassetid://125035680603411`, MetalnessMap `rbxassetid://114367726927540`, RoughnessMap `rbxassetid://121614510476986`.
- **Blocked at the import:** Studio's Import 3D dialog (needed for skinned meshes; the Asset Manager cannot import rigged meshes) must be run by the owner; no script API imports an FBX. Nothing was imported, assigned or tested in Studio yet.

## Studio test results (2026-10-17, executed through MCP; no scripts added to the place, no live asset touched)
Backup `backups/pre035_warden_import_20261017_0334.rbxl` verified first. Import went into Workspace by default; I moved it to `ServerStorage.Imports035.GatehouseWarden_Skin` (kept) and added a SurfaceAppearance with the 4 uploaded maps. All test clones were created in temporary Workspace folders and removed. Play sessions used the game's in-memory Studio store ("StudioMemoryStore"), no DataStore writes; player anchored during tests.
| Test | Result |
|---|---|
| Import: scale, orientation, hierarchy | PASS: MeshPart 4.82 x 6.47 x 2.64 studs, front -Z, +X = character right, axis markers exactly 1 stud; 15 `Bone`s with the R15 hierarchy, root LowerTorso; plus an AnimationController and RootPart |
| Skin weights (read through EditableMesh) | PASS: 7,588 vertices, 4 influences each, weight sums 1.000, 0 unweighted, 4,967 faces |
| Textures | PARTIAL: PreloadAsync OK, no error; looks (colour/normal/metal/rough correctness) NOT inspected (no screenshots by rule) |
| Standard R15 animations on the skinned bones | PASS with a defect: idle, walk and run drive 12-14 bones through the Animator on the AnimationController, no controller needed. Defect: the arm/leg bones were exported pointing down, so their local frames are flipped 180 degrees; forward/back swing is right, but sideways and twist components are mirrored (up to ~30 deg difference at peaks of the stock walk). Fix = export bones with identity (upright) local frames, a rig-export change, or a retarget controller |
| Carry / 90 deg arm movement (engine) | PASS (mechanics): setting Bone.Transform 90 deg about +X moves the hand 2.0 studs forward at shoulder height |
| Stretching, computed from the real imported weights (CPU linear skinning, my own poses) | FAIL at large swings: walk 1.6-1.8% of edges >1.5x (max 3.6x), carry 2.8% (max 7.2x), arms forward 90 2.8% (max 8.6x), arms out 90 max 7.0x; worst spot every time = front of the shoulder where pauldron meets chest (about x 1.0, y 0.5, z -1.0); elbow 120 max 2.8x, knee 90 max 3.0x |
| Clipping, visual stretching, texture look | NOT TESTED (needs screenshots or the owner looking in Studio) |
| Performance, 1 knight (desktop Studio under Wine, NOT a phone) | frame 16.67 ms vs 16.66 ms baseline (60 fps); texture memory +7 MB for the four maps; mesh memory unchanged at the counter's resolution |
| Performance, 5 and 20 knights | NOT COMPLETED: usage limit reached; earlier 5-knight runs were invalid (off-screen, or Studio throttled to 15 fps) |
| Code-driven Bone.Transform loop, carry in game, station placement, reveal preview | NOT TESTED |
Remaining blockers: shoulder-front stretch at big swings; bone frame orientation (mirrored lateral/twist); 5/20-knight cost; visual check by the owner.
