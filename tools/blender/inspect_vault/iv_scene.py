# Vault.glb inspection (headless, on a fresh import: the original GLB and the user's live Blender project are not touched).
import bpy, bmesh, os, math, json
import numpy as np
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
P = os.path.expanduser("~/Pictures/035_preview/concept/Vault.glb")
bpy.ops.import_scene.gltf(filepath=P)
sc = bpy.context.scene
objs = list(bpy.data.objects)
print("COUNTS objects", len(objs), "mesh", sum(o.type == "MESH" for o in objs), "empty", sum(o.type == "EMPTY" for o in objs), "armature", sum(o.type == "ARMATURE" for o in objs), "skinned meshes", sum(1 for o in objs if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers)))
print("FPS", sc.render.fps, "frame range", sc.frame_start, sc.frame_end, "unit scale", sc.unit_settings.scale_length)
tot_t = tot_v = 0; rows = []
for o in objs:
    if o.type != "MESH": continue
    me = o.data; bm = bmesh.new(); bm.from_mesh(me)
    t = sum(len(f.verts) - 2 for f in bm.faces); v = len(bm.verts)
    nm = sum(1 for e in bm.edges if not e.is_manifold); bd = sum(1 for e in bm.edges if e.is_boundary)
    deg = sum(1 for f in bm.faces if f.calc_area() < 1e-12)
    bm.free()
    mats = [s.material.name if s.material else None for s in o.material_slots]
    dim = o.dimensions
    rows.append((o.name, t, v, nm, bd, deg, mats, tuple(round(x, 3) for x in dim), bool(me.uv_layers), o.parent.name if o.parent else None))
    tot_t += t; tot_v += v
fx = [r for r in rows if r[0].startswith(("FX", "AuraFlames", "GroundSigil", "Shockwave", "NovaRing", "CoinRain", "CoinOrbit", "TakeoverBeam", "VaultHalo", "ScepterGem"))]
def isfx(o):
    p = o
    while p:
        if p.name.startswith("FX_"): return True
        p = p.parent
    return False
fxnames = {o.name for o in objs if o.type == "MESH" and isfx(o)}
ch = [r for r in rows if r[0] not in fxnames]; fxr = [r for r in rows if r[0] in fxnames]
neon = [r for r in rows if r[0].endswith("_Neon")]
print("TOTAL tris", tot_t, "verts", tot_v, "meshes", len(rows))
print("CHARACTER (non-FX) meshes", len(ch), "tris", sum(r[1] for r in ch), "verts", sum(r[2] for r in ch))
print("VFX (under FX_ nodes) meshes", len(fxr), "tris", sum(r[1] for r in fxr))
print("_Neon (emissive) meshes", len(neon), "tris", sum(r[1] for r in neon))
print("%-26s %6s %6s %4s %4s %3s %-22s %s" % ("mesh", "tris", "verts", "nonM", "bnd", "deg", "mats", "dims"))
for r in sorted(rows, key=lambda r: -r[1]): print("%-26s %6d %6d %4d %4d %3d %-22s %s uv=%s" % (r[0], r[1], r[2], r[3], r[4], r[5], str([m for m in r[6]]), r[7], r[8]))
print("MATERIALS")
for m in bpy.data.materials:
    nt = m.node_tree; bs = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None) if nt else None
    imgs = [(n.image.name, tuple(n.image.size)) for n in nt.nodes if n.type == "TEX_IMAGE" and n.image] if nt else []
    info = {}
    if bs:
        for k in ("Base Color", "Metallic", "Roughness", "Emission Color", "Emission Strength", "Alpha"):
            if k in bs.inputs:
                v = bs.inputs[k].default_value; info[k] = tuple(round(x, 3) for x in v[:4]) if hasattr(v, "__len__") else round(v, 3)
    print(" ", m.name, "users", m.users, "blend", m.blend_method if hasattr(m, "blend_method") else "", imgs, info)
print("IMAGES", [(i.name, tuple(i.size), i.filepath) for i in bpy.data.images])
# bounds / scale
ws = []
for o in objs:
    if o.type == "MESH" and o.name not in fxnames:
        for c in o.bound_box: ws.append(o.matrix_world @ Vector(c))
lo = [min(w[i] for w in ws) for i in range(3)]; hi = [max(w[i] for w in ws) for i in range(3)]
print("CHARACTER bounds (blender Z-up, metres): min", [round(x, 3) for x in lo], "max", [round(x, 3) for x in hi], "size", [round(hi[i] - lo[i], 3) for i in range(3)])
# hierarchy with rest world positions
print("HIERARCHY (rest, world pos z-up)")
def walk(o, d=0):
    mw = o.matrix_world
    print("  " * d + o.name, o.type, "pos", tuple(round(x, 3) for x in mw.translation), "rotmode", o.rotation_mode, "scale", tuple(round(x, 3) for x in o.scale) if abs(o.scale[0] - 1) > 1e-3 else "")
    for c in o.children: walk(c, d + 1)
for o in objs:
    if o.parent is None: walk(o)
# actions
print("ACTIONS", len(bpy.data.actions))
for a in bpy.data.actions:
    print(" ", a.name, "frame_range", tuple(round(x, 2) for x in a.frame_range), "fcurves", len(a.fcurves) if hasattr(a, "fcurves") else "?", "users", a.users)
print("NLA/animdata:", [(o.name, o.animation_data.action.name if o.animation_data and o.animation_data.action else None, len(o.animation_data.nla_tracks) if o.animation_data else 0) for o in objs if o.animation_data][:6], "...")
bpy.ops.wm.save_as_mainfile(filepath=os.path.expanduser("~/Pictures/035_preview/vault/vault_inspect_copy.blend"))
