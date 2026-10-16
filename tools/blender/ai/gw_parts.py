# Gatehouse Warden (AI) -> 15 rigid rig parts with hidden seams, one shared 1024 PBR atlas, and a Roblox kit-frame FBX.
# Usage: blender -b -P gw_parts.py -- <outdir>        Source GLB is only read. Writes parts_unit.blend (model units, textured, for previews),
# GatehouseWarden.fbx (studs, kit frame), maps (albedo / normal / metalness / roughness PNG), warden_rig.json.
# Seam strategy: every part is cut from ONE clean voxel-remeshed shell with a box that is OV larger than its joint cut, so neighbours overlap
# and the cut surface (cap) lies inside the neighbour's armour. Caps are flat-shaded and mapped to a reserved dark texel (never baked from a ray).
import bpy, bmesh, os, sys, math, json
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
argv = sys.argv[sys.argv.index("--") + 1:]
OUT = os.path.expanduser(argv[0]); os.makedirs(OUT, exist_ok=True)
VOXEL = float(os.environ.get("GW_VOXEL", "0.003"))
RES = int(os.environ.get("GW_RES", "1024"))
OV = float(os.environ.get("GW_OV", "0.02"))
BUD = float(os.environ.get("GW_BUD", "0.84"))  # caps add ~10% triangles: budgets are scaled so the total stays under the 8k Epic ceiling
S = 6.4  # studs per model unit (crest tip included): Epic family 6.0-6.6
NAME = "GatehouseWarden"

# ---- rig (model z' above the soles, x = half spacing) -> studs via S
RIG_Z = dict(ankle=0.075, knee=0.19, hip=0.285, waist=0.385, shoulder_y=0.64, neck=0.668, elbow=0.45, wrist=0.31, hand_end=0.24)
ARM_X, LEG_X = 0.25, 0.12
XT = 0.155  # arm / torso cut
# part: (zlo, zhi, side_x_range as (xmin,xmax) in |x| terms, mirrored?) ; tri budget
PARTS = {
    "Head": ((0.668, 1.02), (0.0, 0.15), False, 1100),
    "UpperTorso": ((0.385, 0.668), (0.0, XT), False, 1500),
    "LowerTorso": ((0.285, 0.385), (0.0, 0.205), False, 900),
    "UpperArm": ((0.45, 0.82), (XT, 0.42), True, 700),
    "LowerArm": ((0.385, 0.45), (XT, 0.42), True, 380, [((0.31, 0.385), (0.215, 0.42), 0.45)]),  # below the belt the forearm is fused to the hip plates: its inner edge steps out
    "Hand": ((0.22, 0.31), (0.205, 0.42), True, 130),
    "UpperLeg": ((0.19, 0.285), (0.0, 0.205), True, 350),
    "LowerLeg": ((0.075, 0.19), (0.0, 0.27), True, 200),
    "Foot": ((-0.01, 0.075), (0.0, 0.27), True, 250),
}
ZO = 0.5  # blender z = z' - ZO

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.expanduser("~/Pictures/035_preview/concept/GatehouseWarden_AI.glb"))
hi = next(o for o in bpy.data.objects if o.type == "MESH"); hi.name = "hi"
sc = bpy.context.scene

# ---------------------------------------------------------------- clean master shell
def obj_from_bm(bm, name):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); ob = bpy.data.objects.new(name, me); sc.collection.objects.link(ob); return ob
def activate(ob):
    for o in bpy.context.view_layer.objects: o.select_set(False)
    bpy.context.view_layer.objects.active = ob; ob.select_set(True)
def decimate_to(ob, n):
    cur = len(ob.data.polygons)
    for _ in range(6):
        cur = len(ob.data.polygons)
        if cur <= n * 1.04: break
        activate(ob)
        m = ob.modifiers.new("d", "DECIMATE"); m.ratio = max(n / cur, 0.03)
        bpy.ops.object.modifier_apply(modifier="d")
bm = bmesh.new(); bm.from_mesh(hi.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0001)
seen = set(); kill = []
for f in bm.faces:
    if f.index in seen: continue
    st = [f]; seen.add(f.index); grp = []
    while st:
        a = st.pop(); grp.append(a)
        for e in a.edges:
            for g in e.link_faces:
                if g.index not in seen: seen.add(g.index); st.append(g)
    if len(grp) < 40: kill += grp
bmesh.ops.delete(bm, geom=kill, context="FACES")
master = obj_from_bm(bm, "master"); bm.free()
activate(master)
vx = master.modifiers.new("r", "REMESH"); vx.mode = "VOXEL"; vx.voxel_size = VOXEL; vx.use_smooth_shade = True
bpy.ops.object.modifier_apply(modifier="r")
print("voxel faces", len(master.data.polygons))
SM = int(os.environ.get("GW_SMOOTH", "0"))
if SM:
    sm = master.modifiers.new("s", "SMOOTH"); sm.factor = 0.6; sm.iterations = SM
    bpy.ops.object.modifier_apply(modifier="s")
if os.environ.get("GW_PREDEC", "0") != "0": decimate_to(master, int(os.environ["GW_PREDEC"]))
print("master tris", len(master.data.polygons))

# ---------------------------------------------------------------- cut parts
def make_part(pname, side, spec, box=None, share=1.0):
    (z0, z1), (xa, xb), mirrored, budget = spec[:4]
    if box is not None: (z0, z1), (xa, xb) = box
    # kit-frame x (right +) boundaries; blender bx = -x_k
    me = master.data.copy()
    bm = bmesh.new(); bm.from_mesh(me)
    planes = []  # (co, normal) keeping the positive-normal side
    def cut(co, no):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, dist=0.0, plane_co=co, plane_no=no, clear_inner=True, clear_outer=False)
        planes.append((Vector(co), Vector(no).normalized()))
    lo, hi_ = z0 - ZO - OV, z1 - ZO + OV
    if pname == "Head": hi_ = z1 - ZO
    if pname == "Foot": lo = z0 - ZO
    cut((0, 0, lo), (0, 0, 1)); cut((0, 0, hi_), (0, 0, -1))
    sg = side  # +1 = character right (bx<0), -1 = left, 0 = centre part
    if sg == 0:
        cut((xb + OV, 0, 0), (-1, 0, 0)); cut((-(xb + OV), 0, 0), (1, 0, 0))
    else:
        # |x_k| in [xa - OV, xb + OV] on the side sg: bx = -sg * |x_k|
        near, far = xa - OV if xa > 0 else -0.0, xb + OV
        bn, bf = -sg * near, -sg * far
        if sg > 0:  # bx in [bf, bn]
            cut((bf, 0, 0), (1, 0, 0)); cut((bn, 0, 0), (-1, 0, 0))
        else:       # bx in [bn, bf]
            cut((bn, 0, 0), (1, 0, 0)); cut((bf, 0, 0), (-1, 0, 0))
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    nm = "%s_%s" % (pname, {1: "Right", -1: "Left", 0: ""}[sg]) if sg else pname
    ob = obj_from_bm(bm, nm); bm.free(); bpy.data.meshes.remove(me)
    decimate_to(ob, max(40, int(budget * BUD * share)))  # open cut shell: no cap yet, so the decimator cannot chew a cap polygon into slivers
    bm = bmesh.new(); bm.from_mesh(ob.data)
    capl = bm.faces.layers.int.new("cap")
    bnd = [e for e in bm.edges if e.is_boundary]
    res = bmesh.ops.holes_fill(bm, edges=bnd, sides=4000)
    capfaces = list(res["faces"])
    tri = bmesh.ops.triangulate(bm, faces=[f for f in capfaces if len(f.verts) > 3])
    for f in capfaces + list(tri["faces"]):
        if f.is_valid: f[capl] = 1
    for f in bm.faces: f.smooth = True
    for e in bm.edges:
        fs = e.link_faces
        e.smooth = not (len(fs) == 2 and (fs[0][capl] != fs[1][capl]))
    bm.to_mesh(ob.data); bm.free()
    ob.data.attributes.new("pid", "INT", "FACE")
    return ob

parts = []
def join(objs):
    if len(objs) == 1: return objs[0]
    for o in bpy.context.view_layer.objects: o.select_set(False)
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]; bpy.ops.object.join(); return bpy.context.view_layer.objects.active
for pname, spec in PARTS.items():
    sides = (1, -1) if spec[2] else (0,)
    extra = spec[4] if len(spec) > 4 else []
    main_share = 1.0 - sum(e[2] for e in extra)
    for sg in sides:
        pieces = [make_part(pname, sg, spec, None, main_share)] + [make_part(pname, sg, spec, (e[0], e[1]), e[2]) for e in extra]
        ob = join(pieces)
        ob.name = "%s_%s" % (pname, {1: "Right", -1: "Left", 0: ""}[sg]) if sg else pname
        parts.append((pname, sg, ob))
bpy.data.objects.remove(master, do_unlink=True)
for i, (pn, sg, ob) in enumerate(parts):
    for p in ob.data.attributes["pid"].data: p.value = i
tot = 0
for pn, sg, ob in parts:
    n = len(ob.data.polygons); tot += n
    caps = sum(1 for a in ob.data.attributes["cap"].data if a.value)
    print("PART %-16s tris %5d caps %4d" % (ob.name, n, caps))
print("TOTAL part tris", tot)

# ---------------------------------------------------------------- join, UV, bake
for o in bpy.context.view_layer.objects: o.select_set(False)
for _, _, ob in parts: ob.select_set(True)
bpy.context.view_layer.objects.active = parts[0][2]
bpy.ops.object.join()
L = bpy.context.view_layer.objects.active; L.name = "L"
me = L.data
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(float(os.environ.get('GW_ANGLE', '80'))), island_margin=0.003)
bpy.ops.object.mode_set(mode="OBJECT")
# select non-cap faces, pack them; caps go to the reserved corner after
capflags = [a.value for a in me.attributes["cap"].data]
for p, cf in zip(me.polygons, capflags): p.select = cf == 0
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.uv.average_islands_scale()
bpy.ops.uv.pack_islands(margin=0.004)
bpy.ops.object.mode_set(mode="OBJECT")
me = L.data
uv = me.uv_layers.active.data
K = 0.03
for p, cf in zip(me.polygons, capflags):
    for li in p.loop_indices:
        u, v = uv[li].uv
        uv[li].uv = (K / 2, K / 2) if cf else (K + (1 - K) * u, K + (1 - K) * v)
print("uv ok")
# bake
cy = sc.cycles; sc.render.engine = "CYCLES"; cy.samples = 8; cy.device = "GPU"
try:
    pref = bpy.context.preferences.addons["cycles"].preferences
    for t in ("OPTIX", "CUDA"):
        pref.compute_device_type = t; pref.get_devices()
        if any(d.type == t for d in pref.devices):
            for d in pref.devices: d.use = d.type == t
            break
except Exception as e: print("gpu?", e)
b = sc.render.bake; b.use_selected_to_active = True; b.cage_extrusion = 0.045; b.max_ray_distance = 0.16; b.margin = 4; b.use_clear = True
hm = hi.material_slots[0].material; nt = hm.node_tree
tex_c = next(n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image.name == "Image_0")
tex_m = next(n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image.name == "Image_1")
outn = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
def emit_from(tex):
    for n in [n for n in nt.nodes if n.name == "EM"]: nt.nodes.remove(n)
    em = nt.nodes.new("ShaderNodeEmission"); em.name = "EM"
    nt.links.new(tex.outputs[0], em.inputs[0]); nt.links.new(em.outputs[0], outn.inputs[0])
lm = bpy.data.materials.new("Warden"); lm.use_nodes = True; L.data.materials.append(lm); lnt = lm.node_tree
def bake(name, cs, typ, setup):
    im = bpy.data.images.new(name, RES, RES, alpha=False); im.colorspace_settings.name = cs
    tn = lnt.nodes.new("ShaderNodeTexImage"); tn.image = im; lnt.nodes.active = tn
    setup()
    for o in sc.objects: o.select_set(False)
    hi.select_set(True); L.select_set(True); bpy.context.view_layer.objects.active = L
    bpy.ops.object.bake(type=typ)
    return im, tn
im_a, ta = bake("albedo", "sRGB", "EMIT", lambda: emit_from(tex_c))
im_m, tm = bake("metalrough", "Non-Color", "EMIT", lambda: emit_from(tex_m))
im_n, tn_ = bake("normal", "Non-Color", "NORMAL", lambda: None)
# reserved corner: dark gunmetal (median of the darkest quarter of covered pixels), flat normal, matte steel
def px(im): return np.array(im.pixels[:], dtype=np.float32).reshape(RES, RES, 4)
A = px(im_a); M_ = px(im_m); N_ = px(im_n)
lum = A[..., :3].mean(-1); cov = lum > 0.002
thr = np.percentile(lum[cov], 25)
dark = np.median(A[..., :3][cov & (lum <= thr)], axis=0)
c = int(RES * K)
A[:c, :c, :3] = dark; N_[:c, :c, :3] = (0.5, 0.5, 1.0); M_[:c, :c, :3] = (0.0, 0.55, 0.85)
for im, arr in ((im_a, A), (im_m, M_), (im_n, N_)):
    im.pixels.foreach_set(arr.reshape(-1)); im.update()
    im.filepath_raw = os.path.join(OUT, {"albedo": "albedo", "metalrough": "metalrough_packed", "normal": "normal"}[im.name] + ".png"); im.file_format = "PNG"; im.save()
# split packed glTF-style metal/rough -> Roblox maps
Mn = M_[..., :3]
def save_gray(name, ch):
    g = np.clip(Mn[..., ch], 0, 1)
    img = bpy.data.images.new(name, RES, RES, alpha=False); img.colorspace_settings.name = "Non-Color"
    rgba = np.stack([g, g, g, np.ones_like(g)], -1).astype(np.float32); img.pixels.foreach_set(rgba.reshape(-1)); img.update()
    img.filepath_raw = os.path.join(OUT, name + ".png"); img.file_format = "PNG"; img.save()
save_gray("roughness", 1); save_gray("metalness", 2)
print("dark texel", dark)
# preview material (textured) for renders
for n in list(lnt.nodes):
    if n.type != "TEX_IMAGE": lnt.nodes.remove(n)
bs = lnt.nodes.new("ShaderNodeBsdfPrincipled"); mo = lnt.nodes.new("ShaderNodeOutputMaterial"); lnt.links.new(bs.outputs[0], mo.inputs[0])
lnt.links.new(ta.outputs[0], bs.inputs["Base Color"])
sp = lnt.nodes.new("ShaderNodeSeparateColor"); lnt.links.new(tm.outputs[0], sp.inputs[0])
lnt.links.new(sp.outputs[1], bs.inputs["Roughness"]); lnt.links.new(sp.outputs[2], bs.inputs["Metallic"])
nm_ = lnt.nodes.new("ShaderNodeNormalMap"); lnt.links.new(tn_.outputs[0], nm_.inputs["Color"]); lnt.links.new(nm_.outputs[0], bs.inputs["Normal"])

# ---------------------------------------------------------------- split back into parts
bpy.data.objects.remove(hi, do_unlink=True)
names = [(pn, sg) for pn, sg, _ in parts]
pid_vals = [a.value for a in L.data.attributes["pid"].data]
print("pid check", len(set(pid_vals)), "capflags", sum(capflags))
final = []
for i, (pn, sg) in enumerate(names):
    bm = bmesh.new(); bm.from_mesh(L.data); bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if pid_vals[f.index] != i], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    gname = {1: "Right", -1: "Left", 0: ""}[sg] + pn
    ob = obj_from_bm(bm, "%s_%s_Atlas" % (NAME, gname)); bm.free()
    ob.data.materials.append(lm)
    ob.data.polygons.foreach_set("use_smooth", [True] * len(ob.data.polygons))
    final.append((gname, ob))
bpy.data.objects.remove(L, do_unlink=True)
# restore sharp cap edges is lost by the bmesh rebuild: recompute from the cap attribute is gone, so mark by cap UV (corner)
for g, ob in final:
    me = ob.data; uvd = me.uv_layers.active.data
    iscap = [all(abs(uvd[li].uv[0] - K / 2) < 1e-6 and abs(uvd[li].uv[1] - K / 2) < 1e-6 for li in p.loop_indices) for p in me.polygons]
    bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
    for e in bm.edges:
        fs = e.link_faces
        e.smooth = not (len(fs) == 2 and (iscap[fs[0].index] != iscap[fs[1].index]))
    bm.to_mesh(me); bm.free()
    print("FINAL", g, len(me.polygons), "tris, caps", sum(iscap))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "parts_unit.blend"))

# ---------------------------------------------------------------- kit frame (studs), markers, FBX
allv = np.array([tuple(v.co) for _, ob in final for v in ob.data.vertices])
zmin = allv[:, 2].min()
cy_ = float(np.median([v.co.y for g, ob in final if g in ("UpperTorso", "LowerTorso") for v in ob.data.vertices]))
print("ground", zmin, "torso centre y", cy_)
for g, ob in final:
    for v in ob.data.vertices:
        v.co = Vector(((v.co.x) * S, (v.co.y - cy_) * S, (v.co.z - zmin) * S))
    ob.data.update()
from kit035 import geo
from kit035.geo import box
mk = []
for nm, cc in (("Anchor", (0, 0, 0)), ("AxisX", (1, 0, 0)), ("AxisY", (0, 1, 0)), ("AxisFront", (0, 0, -1))):
    mk.append(geo.to_object("%s_%s" % (NAME, nm), box(0.04, 0.04, 0.04, c=cc), collection=sc.collection))
for o in sc.objects: o.select_set(False)
for _, ob in final: ob.select_set(True)
for o in mk: o.select_set(True)
# plain material for the FBX (textures are uploaded separately and applied as SurfaceAppearance)
pm = bpy.data.materials.new("Warden_plain"); pm.use_nodes = True
for _, ob in final: ob.data.materials.clear(); ob.data.materials.append(pm)
for o in mk: o.data.materials.append(pm)
fbx = os.path.join(OUT, NAME + ".fbx")
bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, axis_forward="-Z", axis_up="Y", global_scale=0.01, apply_unit_scale=True,
                         bake_space_transform=False, mesh_smooth_type="EDGE", add_leaf_bones=False, object_types={"MESH"})
rig = {k: round(v * S, 4) for k, v in RIG_Z.items()}
rig.update(arm_x=round(ARM_X * S, 4), leg_x=round(LEG_X * S, 4), head_h=round((0.868 - 0.668) * S, 4), foot_h=round(0.075 * S, 4))
meta = dict(scale=S, rig=rig, parts={g: len(ob.data.polygons) for g, ob in final}, total_tris=sum(len(ob.data.polygons) for _, ob in final), overlap=OV, res=RES)
json.dump(meta, open(os.path.join(OUT, "warden_rig.json"), "w"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "parts_studs.blend"))
print("DONE", json.dumps(meta))
