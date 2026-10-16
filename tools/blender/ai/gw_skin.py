# 035skin pilot: ONE smooth skinned mesh + R15-named bones (no cutting). Gatehouse Warden from the AI GLB.
# Usage: blender -b -P gw_skin.py -- <outdir>        env: GW_TRIS (5000 = Epic), GW_RES (1024), GW_BLEND (band widths scale)
# Steps: weld/clean -> voxel remesh -> decimate to budget -> UV + bake albedo/normal/metal-rough from the 96k original -> scale to studs
#        -> R15 armature from warden_rig.json -> procedural weights (smooth blends at joints, hard where a plate must stay rigid) -> FBX.
import bpy, bmesh, os, sys, math, json, time
import numpy as np
from mathutils import Vector, Matrix
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, os.path.dirname(HERE))
argv = sys.argv[sys.argv.index("--") + 1:]
OUT = os.path.expanduser(argv[0]); os.makedirs(OUT, exist_ok=True)
T0 = time.time()
TRIS = int(os.environ.get("GW_TRIS", "5000")); RES = int(os.environ.get("GW_RES", "1024")); VOXEL = float(os.environ.get("GW_VOXEL", "0.003"))
S = 6.4; NAME = "GatehouseWarden"
RIGJ = json.load(open(os.path.join(os.path.dirname(HERE), "..", "..", "assets", "export", "035", "warden", "warden_rig.json")))["rig"]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.expanduser("~/Pictures/035_preview/concept/GatehouseWarden_AI.glb"))
hi = next(o for o in bpy.data.objects if o.type == "MESH"); hi.name = "hi"
sc = bpy.context.scene
def activate(ob):
    for o in list(bpy.context.view_layer.objects):
        if o is not None: o.select_set(False)
    bpy.context.view_layer.objects.active = ob; ob.select_set(True)
def decimate_to(ob, n):
    for _ in range(6):
        cur = len(ob.data.polygons)
        if cur <= n * 1.03: break
        activate(ob); m = ob.modifiers.new("d", "DECIMATE"); m.ratio = max(n / cur, 0.03); bpy.ops.object.modifier_apply(modifier="d")
# ---- 1. clean
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
me = bpy.data.meshes.new("skin"); bm.to_mesh(me); bm.free()
lo = bpy.data.objects.new("skin", me); sc.collection.objects.link(lo); activate(lo)
vx = lo.modifiers.new("r", "REMESH"); vx.mode = "VOXEL"; vx.voxel_size = VOXEL; vx.use_smooth_shade = True
bpy.ops.object.modifier_apply(modifier="r")
decimate_to(lo, TRIS)
bpy.ops.object.shade_smooth()
print("SKIN tris", len(lo.data.polygons), "t=%.0fs" % (time.time() - T0))
def Sm(t): t = np.clip(t, 0, 1); return t * t * (3 - 2 * t)
BS = float(os.environ.get("GW_BLEND", "1.0"))
def step(z, j, band): return Sm((z - j) / (2 * band * BS) + 0.5)
def armness_of(X, Z):
    xt = 0.215 - 0.06 * step(Z, 0.375, 0.015)
    return Sm((np.abs(X) - xt) / 0.05 + 0.5) * step(Z, 0.205, 0.02)
# the hands rest on the hip plates: the AI mesh fuses them, and a skinned bridge there stretches into long webs. Remove only those bridge faces (below the belt).
_c = np.array([tuple(v.co) for v in lo.data.vertices]); _z0 = _c[:, 2].min()
_a = armness_of(-_c[:, 0], _c[:, 2] - _z0)
bm = bmesh.new(); bm.from_mesh(lo.data); bm.verts.ensure_lookup_table(); br = []
for f in bm.faces:
    av = [_a[v.index] for v in f.verts]; zc = sum(_c[v.index][2] - _z0 for v in f.verts) / 3
    if 0.2 < zc < 0.62 and max(av) > 0.4 and min(av) < 0.6: br.append(f)
print("BRIDGE faces removed", len(br))
bmesh.ops.delete(bm, geom=br, context="FACES_ONLY"); bm.to_mesh(lo.data); bm.free()
# ---- 2. UV + bake
activate(lo); bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(float(os.environ.get("GW_ANGLE", "80"))), island_margin=0.003)
bpy.ops.uv.average_islands_scale(); bpy.ops.uv.pack_islands(margin=0.003)
bpy.ops.object.mode_set(mode="OBJECT")
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
nt = hi.material_slots[0].material.node_tree
tex_c = next(n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image.name == "Image_0")
tex_m = next(n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image.name == "Image_1")
outn = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
def emit_from(tex):
    for n in [n for n in nt.nodes if n.name == "EM"]: nt.nodes.remove(n)
    em = nt.nodes.new("ShaderNodeEmission"); em.name = "EM"; nt.links.new(tex.outputs[0], em.inputs[0]); nt.links.new(em.outputs[0], outn.inputs[0])
lm = bpy.data.materials.new("Warden"); lm.use_nodes = True; lo.data.materials.append(lm); lnt = lm.node_tree
def bake(name, cs, typ, setup):
    im = bpy.data.images.new(name, RES, RES, alpha=False); im.colorspace_settings.name = cs
    tn = lnt.nodes.new("ShaderNodeTexImage"); tn.image = im; lnt.nodes.active = tn; setup()
    for o in sc.objects: o.select_set(False)
    hi.select_set(True); lo.select_set(True); bpy.context.view_layer.objects.active = lo
    bpy.ops.object.bake(type=typ); return im, tn
im_a, ta = bake("albedo", "sRGB", "EMIT", lambda: emit_from(tex_c))
im_m, tm = bake("metalrough", "Non-Color", "EMIT", lambda: emit_from(tex_m))
im_n, tn_ = bake("normal", "Non-Color", "NORMAL", lambda: None)
print("BAKED t=%.0fs" % (time.time() - T0))
def px(im): return np.array(im.pixels[:], dtype=np.float32).reshape(RES, RES, 4)
def fill_pits(arr, cover):
    # inpaint black bake misses inside islands (pixels dark but with covered neighbours) by diffusion
    miss = (arr[..., :3].sum(-1) < 0.01)
    for _ in range(6):
        ok = ~miss
        acc = np.zeros_like(arr[..., :3]); cnt = np.zeros(miss.shape, np.float32)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0: continue
                sh = np.roll(np.roll(arr[..., :3] * ok[..., None], dy, 0), dx, 1); c = np.roll(np.roll(ok.astype(np.float32), dy, 0), dx, 1)
                acc += sh; cnt += c
        upd = miss & (cnt > 3)
        arr[..., :3][upd] = acc[upd] / cnt[upd][:, None]; miss = miss & ~upd
    return arr
A = px(im_a); M_ = px(im_m); N_ = px(im_n)
im_a.pixels.foreach_set(A.reshape(-1)); im_a.update()
for im, nm_ in ((im_a, "albedo"), (im_n, "normal")):
    im.filepath_raw = os.path.join(OUT, nm_ + ".png"); im.file_format = "PNG"; im.save()
Mn = M_[..., :3]
for nm_, ch in (("roughness", 1), ("metalness", 2)):
    g = np.clip(Mn[..., ch], 0, 1); img = bpy.data.images.new(nm_, RES, RES, alpha=False); img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(np.stack([g, g, g, np.ones_like(g)], -1).astype(np.float32).reshape(-1)); img.update()
    img.filepath_raw = os.path.join(OUT, nm_ + ".png"); img.file_format = "PNG"; img.save()
for n in list(lnt.nodes):
    if n.type != "TEX_IMAGE": lnt.nodes.remove(n)
bs = lnt.nodes.new("ShaderNodeBsdfPrincipled"); mo = lnt.nodes.new("ShaderNodeOutputMaterial"); lnt.links.new(bs.outputs[0], mo.inputs[0])
lnt.links.new(ta.outputs[0], bs.inputs["Base Color"])
sp = lnt.nodes.new("ShaderNodeSeparateColor"); lnt.links.new(tm.outputs[0], sp.inputs[0])
lnt.links.new(sp.outputs[1], bs.inputs["Roughness"]); lnt.links.new(sp.outputs[2], bs.inputs["Metallic"])
nmn = lnt.nodes.new("ShaderNodeNormalMap"); lnt.links.new(tn_.outputs[0], nmn.inputs["Color"]); lnt.links.new(nmn.outputs[0], bs.inputs["Normal"])
bpy.data.objects.remove(hi, do_unlink=True); bpy.context.view_layer.update()
# ---- 3. to studs, ground at 0, torso centred
co = np.array([tuple(v.co) for v in lo.data.vertices]); zmin = co[:, 2].min()
cy0 = float(np.median(co[:, 1]))
Zp = co[:, 2] - zmin  # z' above sole (model units)
Xk = -co[:, 0]        # kit x: character right positive
for v, (x, y, z) in zip(lo.data.vertices, co): v.co = Vector((x * S, (y - cy0) * S, (z - zmin) * S))
lo.data.update(); lo.name = NAME + "_Skin"; lo.data.name = NAME + "_Skin"
# ---- 4. armature (R15 names), joint heights from warden_rig.json (studs); blender x = -kit x
J = RIGJ
def P(xk, z, y=0.0): return Vector((-xk * 1.0, y, z))
arm_obj = bpy.data.objects.new(NAME + "_Rig", bpy.data.armatures.new(NAME + "_Rig")); sc.collection.objects.link(arm_obj)
activate(arm_obj); bpy.ops.object.mode_set(mode="EDIT"); eb = arm_obj.data.edit_bones
def bone(name, head, tail, parent=None):
    e = eb.new(name); e.head, e.tail = head, tail; e.roll = 0.0
    if parent: e.parent = eb[parent]
    return e
bone("LowerTorso", P(0, J["hip"]), P(0, J["waist"]))
bone("UpperTorso", P(0, J["waist"]), P(0, J["neck"]), "LowerTorso")
bone("Head", P(0, J["neck"]), P(0, J["neck"] + J["head_h"] + 0.8), "UpperTorso")
for side, sg in (("Right", 1), ("Left", -1)):
    ax, lx = sg * J["arm_x"], sg * J["leg_x"]
    bone(side + "UpperArm", P(ax, J["shoulder_y"]), P(ax, J["elbow"]), "UpperTorso")
    bone(side + "LowerArm", P(ax, J["elbow"]), P(ax, J["wrist"]), side + "UpperArm")
    bone(side + "Hand", P(ax, J["wrist"]), P(ax, J["hand_end"]), side + "LowerArm")
    bone(side + "UpperLeg", P(lx, J["hip"]), P(lx, J["knee"]), "LowerTorso")
    bone(side + "LowerLeg", P(lx, J["knee"]), P(lx, J["ankle"]), side + "UpperLeg")
    bone(side + "Foot", P(lx, J["ankle"]), P(lx, J["ankle"], -0.9), side + "LowerLeg")
bpy.ops.object.mode_set(mode="OBJECT")
# ---- 5. weights
JZ = {k: v / S for k, v in J.items()}  # model units (z')
X, Z = Xk, Zp
armness = armness_of(X, Z)
t_hip, t_waist, t_neck = step(Z, JZ["hip"], 0.035), step(Z, JZ["waist"], 0.03), step(Z, JZ["neck"], 0.03)
t_knee, t_ank = step(Z, JZ["knee"], 0.04), step(Z, JZ["ankle"], 0.03)
t_elb, t_wr = step(Z, JZ["elbow"], 0.045), step(Z, JZ["wrist"], 0.03)
side_r = Sm((X + 0.07) / 0.14)          # legs / centre: 1 = right
arm_r = (X > 0).astype(np.float32)       # arms: right where kit x > 0
W = {}
def add(name, w):
    W[name] = W.get(name, 0) + w
body = 1 - armness
add("Head", body * t_neck)
add("UpperTorso", body * t_waist * (1 - t_neck))
add("LowerTorso", body * t_hip * (1 - t_waist))
legw = body * (1 - t_hip)
for side, sw in (("Right", side_r), ("Left", 1 - side_r)):
    add(side + "UpperLeg", legw * sw * t_knee); add(side + "LowerLeg", legw * sw * (1 - t_knee) * t_ank); add(side + "Foot", legw * sw * (1 - t_ank))  # step() is 1 ABOVE the joint
for side, sw in (("Right", arm_r), ("Left", 1 - arm_r)):
    add(side + "UpperArm", armness * sw * t_elb); add(side + "LowerArm", armness * sw * (1 - t_elb) * t_wr); add(side + "Hand", armness * sw * (1 - t_wr))
names = list(W); Wm = np.stack([W[n] for n in names], 1)
# keep the 4 strongest influences
idx = np.argsort(-Wm, 1)[:, 4:]
np.put_along_axis(Wm, idx, 0, 1); Wm /= Wm.sum(1, keepdims=True)
for n in names: lo.vertex_groups.new(name=n)
for vi in range(len(Wm)):
    for k, n in enumerate(names):
        if Wm[vi, k] > 0.003: lo.vertex_groups[n].add([vi], float(Wm[vi, k]), "REPLACE")
lo.parent = arm_obj; md = lo.modifiers.new("Armature", "ARMATURE"); md.object = arm_obj
print("WEIGHTS ok; max influences", int(((Wm > 0.003).sum(1)).max()), "t=%.0fs" % (time.time() - T0))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "warden_skin.blend"))
# ---- 6. FBX (markers = same anchor/axis convention as the kit)
from kit035 import geo
from kit035.geo import box
mk = [geo.to_object("%s_%s" % (NAME, nm), box(0.04, 0.04, 0.04, c=cc), collection=sc.collection) for nm, cc in (("Anchor", (0, 0, 0)), ("AxisX", (1, 0, 0)), ("AxisY", (0, 1, 0)), ("AxisFront", (0, 0, -1)))]
pm = bpy.data.materials.new("Warden_plain"); pm.use_nodes = True
saved = list(lo.data.materials); lo.data.materials.clear(); lo.data.materials.append(pm)
for o in mk: o.data.materials.append(pm)
for o in list(sc.objects): o.select_set(False)
for o in [lo, arm_obj] + mk: o.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, NAME + "_Skin.fbx"), use_selection=True, axis_forward="-Z", axis_up="Y", global_scale=0.01, apply_unit_scale=True,
                         bake_space_transform=False, mesh_smooth_type="FACE", add_leaf_bones=False, use_armature_deform_only=True, bake_anim=False, object_types={"MESH", "ARMATURE"}, path_mode="STRIP")
for o in mk: bpy.data.objects.remove(o, do_unlink=True)
lo.data.materials.clear(); [lo.data.materials.append(m) for m in saved]
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "warden_skin.blend"))
json.dump(dict(tris=len(lo.data.polygons), bones=len(arm_obj.data.bones), res=RES, seconds=round(time.time() - T0)), open(os.path.join(OUT, "skin_report.json"), "w"))
print("DONE t=%.0fs" % (time.time() - T0))
