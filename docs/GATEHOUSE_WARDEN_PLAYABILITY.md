# Gatehouse Warden: playability prototype (2026-10-17, from `de1f737`)
Single isolated prototype. Studio was NOT touched (not running; see "Blocked"). Nothing is enabled; `KIT_B1` stays false; no CreatureSpecs / CreatureKitData / CreatureBuilder change.

## Done (Blender side, reproducible: `tools/blender/ai/gw_parts.py`)
Cut from one clean voxel-remeshed shell (voxel 0.003, 810k faces), no pre-decimation, so each part is decimated once from full detail.
- **15 rigid parts** named `GatehouseWarden_<Group>_Atlas` (group = the R15 part it welds to, same convention as the B1 kit: `Head, UpperTorso, LowerTorso, {Left,Right}{UpperArm,LowerArm,Hand,UpperLeg,LowerLeg,Foot}`), plus `_Anchor` / `_AxisX` / `_AxisY` / `_AxisFront` markers. FBX export settings and axis conventions are the existing `kit035.export` ones; re-import check: 19 models, Lcl Scaling 1, rotation -90, no extras. **7,248 tris** total (ceiling 8,000; caps cost ~10%), model 6.4 studs tall incl. crest, ~4.8 wide, ~2.6 deep.
- **Seams:** each part's cut box is `OV = 0.02` (about 0.13 studs) larger than the joint, so neighbours overlap and the cut surface sits inside the neighbour's armour. Caps are built AFTER decimation (a capped part decimated as one piece turned the cap into slivers), flat-shaded, and mapped to one reserved dark-steel texel (never baked from a ray). The forearm has a stepped inner edge (it is fused to the hip plates below the belt); legs stop at |x| 0.205 so the hand does not leave a ghost behind.
- **One shared 1024 atlas** (all 15 parts, one material) baked from the original 96k mesh: `albedo.png`, `normal.png`, `metalness.png`, `roughness.png` (metal/rough split out of glTF packing). Files: `assets/export/035/warden/` and `~/Documents/035/GatehouseWarden/` (FBX, maps, `warden_rig.json`).
- **Rig:** the AI body is stubbier than CHUNK (legs 25% of height), so forcing CHUNK (hip 2.75) would make the cuts wrong. A new joint table fitted to the mesh (same fields as CHUNK / `RIG_NOOB`, so `CreatureBuilder` can take it as `rig`): ankle 0.48, knee 1.216, hip 1.824, waist 2.464, shoulder_y 4.096, neck 4.275, elbow 2.88, wrist 1.984, hand_end 1.536, arm_x 1.6, leg_x 0.768, head_h 1.28, foot_h 0.48. Hip 1.82 is close to the noob rig (2.0), so HipHeight / pad placement should be near today's workers (still to be measured in Studio).
- **Sword / shield:** the AI model has none (the concept asked for them as separate props and no generation was allowed). Nothing is fused into the body; props are future separate groups.

## Pose evidence (Blender rigid-joint rotations = what the hidden R15 rig does; NOT engine tests)
Board `~/Pictures/035_preview/gw/warden/WARDEN_PROTOTYPE_board.png`; sheets `POSES_*.png`, `SEAMS_*.png`, `TINT.png` (per-part colour).
- Rest / idle: reads like the original at phone distance, but surface is more crumpled than the 8k single-mesh version (per-part decimation, gold edges look torn, crown spikier).
- Walk (arms +-35, legs +-30, knee bend): limbs articulate, no gaps between joints at 1x, outline ragged; small ghost fins from overlap bands.
- Carry (arms forward 70, elbows 60) and stress (arm 65 + elbow 55, leg 35 + knee 30): exposes cut surfaces: dark flat slabs at the hips (tassets fused to the thigh/hand zone) and a large dome (pauldron) swinging in front of the head. Visible failure for any big arm swing.
- Cause: the AI mesh is one fused body (hands on hips, pauldron fused to chest), so a rigid-part cut passes through solid armour. Overlap hides it only at small angles.

## Studio part: NOT done (blocked, nothing run)
- `rbxmcp serve`: "Studio isn't running". Studio was closed at 02:02 today (last log). Opened place id 96425239551061 (cloud). Newest local `.rbxl` files are `~/Documents/latest.rbxl` and `backups/pre035_boss_import.rbxl` (both 2026-10-16 early, identical size): OLDER than the live session, so they are NOT a snapshot of live Studio and I did not treat them as one. No backup made, no restore verified.
- Needs from the owner: open Studio on the place, File > Save As a local `.rbxl` into `backups/` (or tell me it is already saved), reconnect MCP (`/mcp`), import `GatehouseWarden.fbx` (Asset Manager > Import 3D, Model, into `ServerStorage.Imports035`), bulk-import the four PNGs (Asset Manager) and give me the ids (or set string attributes `ColorMap/NormalMap/MetalnessMap/RoughnessMap` on the import).
- Test written, lint/type clean, NOT pushed, NOT run: `src/ServerScriptService/DevTest_Warden035.lua` (arg `warden035`): import + axis check, stand, pad (NPCPlacement formula), idle, walk (feet never sink, limbs really swing, each mesh follows its rig part), carry numbers, preview framing, Heartbeat / mesh+texture memory for 1 vs 20 copies. It builds its own proxy rig in a throw-away folder; touches nothing live.

## Per-test results
| Test | Result |
|---|---|
| FBX structure (19 models, scale/rotation) | PASS (Blender re-import) |
| Triangle budget 7,248 / 8,000 | PASS |
| Rigid rotation, seams, caps (Blender renders) | PARTIAL: fine at rest/idle/walk, FAIL for carry / large swings |
| Studio import, stand, pad, idle, walk, carry, preview, performance | NOT RUN (Studio not running) |
