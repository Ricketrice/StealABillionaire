# Vault wizard, step 1: weld + decimate a COPY of Vault.glb, snap palette UVs, export the rigid parts.
# Usage: flatpak run org.blender.Blender -b -P $PWD/tools/blender/vault/vw_prep.py -- [--scale S] [--mul M]
# Reads ~/Pictures/035_preview/concept/Vault.glb (never written). Writes (WORK = ~/Pictures/035_preview/vault2, EXPORT = assets/export/vault):
#   WORK/vault_meshes.npz   decimated meshes in glTF node-local space (unit scale) for the animation solver / renderer
#   EXPORT/VaultWizard.fbx  one MeshPart per rigid part, object origin = its joint, rest pose, studs, Studio axes (Anchor + Axis markers)
#   EXPORT/vault_parts.json per-part report (tris, bbox)
import bpy
import bmesh
import json
import math
import os
import sys

import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vw_common as C  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
S = float(argv[argv.index("--scale") + 1]) if "--scale" in argv else 2.5       # studs per model unit
MUL = float(argv[argv.index("--mul") + 1]) if "--mul" in argv else 1.0         # global multiplier on the decimation ratios
os.makedirs(C.WORK, exist_ok=True)
os.makedirs(C.EXPORT, exist_ok=True)

# Effects that are rebuilt with Roblox-native emitters / beams / parts: NOT exported as meshes.
DROP = {"CoinRainMarks_Neon", "GroundSigil_Neon", "NovaRing_Neon", "Shockwave_Neon", "TakeoverBeam_Neon", "CoinOrbit", "CoinOrbit_Neon", "CoinRain", "CoinRain_Neon",
        "AuraFlames_A_Neon", "AuraFlames_B_Neon"}
# Collapse-decimation ratios (meshes not listed are small and stay as authored).
RATIO = {"UpperTorso": 0.48, "UpperTorso_Neon": 0.6, "LowerTorso": 0.5, "LedgerScepter": 0.5, "LedgerScepter_Neon": 0.5, "WizardTopHat": 0.6, "WizardTopHat_Neon": 0.6, "Head": 0.55,
         "LeftFoot": 0.6, "RightFoot": 0.6, "LeftLowerArm": 0.6, "RightLowerArm": 0.6, "VaultHalo": 0.5, "VaultHalo_Neon": 0.5}
SWATCH = [(k + 0.5) / 8 for k in range(8)]

G = C.Glb()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=C.GLB)
sc = bpy.context.scene
deps = bpy.context.evaluated_depsgraph_get()
# glTF (x, y, z) -> Blender (x, -z, y)
CG2B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
CB2G = CG2B.inverted()


def np4(M):
    return np.array([list(r) for r in M])


report = {}
store = {}
for o in sorted([o for o in bpy.data.objects if o.type == "MESH" and o.name not in DROP], key=lambda o: o.name):
    me0 = o.data
    n0 = len(me0.polygons)
    bm = bmesh.new()
    bm.from_mesh(me0)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    for f in bm.faces:
        f.smooth = False
    me = bpy.data.meshes.new(o.name + "_w")
    bm.to_mesh(me)
    bm.free()
    # outward orientation check on the welded shell (signed volume)
    vol = sum(np.dot(np.array(me.vertices[p.vertices[0]].co), np.cross(np.array(me.vertices[p.vertices[1]].co), np.array(me.vertices[p.vertices[2]].co))) for p in me.polygons) / 6.0
    flipped = vol < 0
    ratio = min(1.0, RATIO.get(o.name, 1.0) * MUL) if o.name in RATIO else 1.0
    tmp = bpy.data.objects.new(o.name + "_w", me)
    sc.collection.objects.link(tmp)
    if flipped:
        bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.reverse_faces(bm, faces=bm.faces[:]); bm.to_mesh(me); bm.free()
    if ratio < 0.999:
        # Welded copy of the UV layer first: collapse with UV seams delimited keeps colour-island borders (palette swatches) exactly.
        m = tmp.modifiers.new("d", "DECIMATE")
        m.decimate_type = "COLLAPSE"
        m.ratio = ratio
        m.use_collapse_triangulate = True
        m.delimit = {"UV"}
        bpy.context.view_layer.update()
    ev = tmp.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me2 = bpy.data.meshes.new_from_object(ev)
    me2.calc_loop_triangles()
    uvl = me2.uv_layers.active
    verts = np.array([list(v.co) for v in me2.vertices], dtype=np.float64)
    tris = np.array([list(t.vertices) for t in me2.loop_triangles], dtype=np.int64)
    uv = np.zeros((len(tris), 3, 2))
    neon = o.name.endswith("_Neon") or o.name.startswith("ScepterGem")
    for k, t in enumerate(me2.loop_triangles):
        for c in range(3):
            u, v = (uvl.data[t.loops[c]].uv if uvl else (0.5, 0.5))
            if neon:
                u, v = 0.5, 0.5
            else:
                u = min(SWATCH, key=lambda s: abs(s - u)); v = 0.5   # snap to the swatch centre (no bleed)
            uv[k, c] = (u, v)
    # Blender local -> glTF node-local
    vg = np.stack([verts[:, 0], verts[:, 2], -verts[:, 1]], axis=1)
    # recompute outward-consistent winding in glTF space: (x, z, -y) is a proper rotation so the winding is preserved
    store[o.name] = dict(v=vg, f=tris, uv=uv, neon=np.array([neon]))
    report[o.name] = dict(tris_before=n0, tris=len(tris), verts=len(verts), ratio=ratio, flipped=bool(flipped), vol=float(abs(vol)))
    sc.collection.objects.unlink(tmp)

np.savez_compressed(os.path.join(C.WORK, "vault_meshes.npz"), names=np.array(sorted(store)), **{n + "__v": d["v"] for n, d in store.items()}, **{n + "__f": d["f"] for n, d in store.items()},
                    **{n + "__uv": d["uv"] for n, d in store.items()}, **{n + "__neon": d["neon"] for n, d in store.items()})

body = [n for n in store if n not in ("VaultHalo", "VaultHalo_Neon", "ScepterGem_Neon")]
tb = sum(report[n]["tris"] for n in body)
tb0 = sum(report[n]["tris_before"] for n in body)
th = sum(report[n]["tris"] for n in ("VaultHalo", "VaultHalo_Neon"))
print("BODY tris %d -> %d (%d meshes); halo %d; gem %d; total exported tris %d" % (tb0, tb, len(body), th, report["ScepterGem_Neon"]["tris"], sum(r["tris"] for r in report.values())))
for n, r in sorted(report.items(), key=lambda kv: -kv[1]["tris"])[:14]:
    print("  %-20s %5d -> %5d  ratio %.2f%s" % (n, r["tris_before"], r["tris"], r["ratio"], " FLIPPED" if r["flipped"] else ""))

# ---------------------------------------------------------------- FBX: one object per part, origin = joint (rest world translation), rotation baked into the mesh, studs, Studio axes
exp = []
mat_pal = bpy.data.materials.new("Vaultbane_Palette"); mat_pal.diffuse_color = (0.3, 0.3, 0.3, 1)
mat_neon = bpy.data.materials.new("Neon"); mat_neon.diffuse_color = (0.64, 0.42, 1.0, 1)
cache = {}
for name, d in store.items():
    i = G.byname[name]
    Wg = G.rest_world(i, cache)
    Wb = CG2B @ Matrix(Wg.tolist()) @ CB2G
    R = Wb.to_3x3().normalized()
    loc = Wb.to_translation()
    # local blender coords back from glTF-local
    vb = np.stack([d["v"][:, 0], -d["v"][:, 2], d["v"][:, 1]], axis=1)
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(S * (R @ Vector(v))) for v in vb], [], [tuple(f) for f in d["f"]])
    me.update()
    uvl = me.uv_layers.new(name="UVMap")
    for k, p in enumerate(me.polygons):
        for c, li in enumerate(p.loop_indices):
            uvl.data[li].uv = tuple(d["uv"][k, c])
    C.shade_by_angle(me)
    me.materials.append(mat_neon if bool(d["neon"][0]) else mat_pal)
    ob = bpy.data.objects.new(name, me)
    sc.collection.objects.link(ob)
    ob.location = loc * S
    exp.append(ob)
    xs = np.array([list(ob.location + v.co) for v in me.vertices])
    st = np.stack([-xs[:, 0], xs[:, 2], xs[:, 1]], axis=1)          # Studio = (-bx, bz, by)
    report[name]["bbox_studio"] = [st.min(0).round(3).tolist(), st.max(0).round(3).tolist()]
    report[name]["origin_studio"] = [round(-ob.location.x, 4), round(ob.location.z, 4), round(ob.location.y, 4)]
# markers: Anchor at the ground origin, axes 2 studs out on the character's right (+X), up (+Y), front (-Z) in Studio
for nm, st in (("Anchor", (0, 0, 0)), ("AxisX", (2, 0, 0)), ("AxisY", (0, 2, 0)), ("AxisFront", (0, 0, -2))):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=0.2); me = bpy.data.meshes.new("VaultWizard_" + nm); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new("VaultWizard_" + nm, me); sc.collection.objects.link(ob); ob.location = (-st[0], st[2], st[1]); exp.append(ob)
for o in bpy.data.objects:
    o.select_set(False)
for ob in exp:
    ob.select_set(True)
fbx = os.path.join(C.EXPORT, "VaultWizard.fbx")
bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, axis_forward="-Z", axis_up="Y", global_scale=0.01, apply_unit_scale=True, bake_space_transform=False,
                         mesh_smooth_type="EDGE", add_leaf_bones=False, object_types={"MESH"})
print("FBX", fbx, os.path.getsize(fbx), "bytes,", len(exp), "objects")
json.dump(dict(studs_per_unit=S, parts=report), open(os.path.join(C.EXPORT, "vault_parts.json"), "w"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(C.WORK, "vault_prepped.blend"))
