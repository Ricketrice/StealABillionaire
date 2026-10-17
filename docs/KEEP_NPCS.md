# Knight's Keep NPCs (036 sweep)
Owner exports: `~/Downloads`-style folders copied (originals kept) to `~/Documents/SAB_Imports/KnightsKeep/<Name>/` (GLB `<Name>_R6.glb`, `<Name>_BuildNPC.lua`, Color/Metalness/Roughness PNGs, `<Name>_rig.json`).
Exports present: Peasant, Squire, Guard, Archer, Crusader. NOT exported: Baron, Vanguard (their slots keep the current look). Archer has no `_rig.json` and no Roughness map; Guard's two maps were filed in the Squire folder (fixed in the copy).
All five `_BuildNPC.lua` have byte-identical code after the `SPEC` table (read once, 036); only the SPEC data differs. The scripts are NOT run: `tools/keep_rigs.py` reads the SPEC.

| Rig | Slot (id, display name, rarity) | tris | parts | Motor6D |
|---|---|---|---|---|
| Squire | broke_bob, Rookie Squire, Common | 688 | 6 | 6 |
| Peasant | delivery_dave, Scroll Page, Common | 652 | 6 | 6 |
| Guard | training_dummy, Training Dummy, Common | 2,056 | 6 | 6 |
| Archer | street_hustler, Apple Archer, Rare | 536 | 6 | 6 |
| Crusader | business_betty, Banner Bearer, Rare | 8,976 | 9 | 9 |
Epic (security_sam, crypto_carl), Legendary (ceo_chad): unchanged (current part-built look). Secret: Sir Malgrave (boss rig).

Pipeline: `python3 -I tools/keep_rigs.py` -> `src/ServerStorage/BossRigs/<Name>/{Data,Assets}.lua + Clips/{Idle,Walk,Attack}.lua` -> push -> owner **Import 3D** of `<Name>_R6.glb` (file units studs, one Model) into `ServerStorage.BossRigs.<Name>.Imported` ->
`require(ServerStorage.BossRigs.Shared.NpcBuilder).build("<Name>", Imported:FindFirstChildWhichIsA("Model"))`, name the result `Template`. The game then treats it like a boss rig (`CreatureSpecs.KEEP_NPC_RIGS`, `CreatureBuilder.attachBossRig`, client `BossRigs.Shared.Client` + `Shared.Driver`, no effects: `Shared.NullVfx`).
Texture ids (uploaded 2026-10-17 through the MCP) are in each `Assets.lua`. Display names unchanged. Kid-safe: no undead (owner rename: Gravecall -> Ironcall, Revenant -> Vanguard).

## Import findings (2026-10-17, from the owner's Import 3D)
- Import 3D lands each model in `Workspace` (not where you point it); moved into `ServerStorage.BossRigs.<Name>.Imported`. Sizes are exact (studs).
- It turns the whole model half a turn about Y (X and Z of every offset negated): `NpcBuilder` detects it (`report.flipped`) and turns the parts back.
- It drops GLB node rotations and keeps the mesh upright: Crusader Longsword (-90 deg about X, pivot at the grip) and Cape (-6.9 deg) are restored from `NpcBuilder.NODE_ROT_X` (values read from `Crusader_R6.glb`).
- Motor6D `C1` is derived from the built rest pose (`Part1.CFrame:Inverse() * Part0.CFrame * C0`), so a re-pose never needs the SPEC c1.
- Result: all five `Template` models built, every part within 0.25 studs of the SPEC, rest error 0.00000, Idle / Walk / Attack finite (FK check; Crusader sword swing 6.6 studs). Looks not viewed (no screenshots).
