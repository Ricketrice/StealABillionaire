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
