# Feasibility experiment: weld + decimate the raw AI knight to N tris, re-UV, bake albedo / normal / packed metal-rough from the 96k original, export GLB.
# Usage: blender -b -P gw_optimise.py -- <target_tris> <outdir>      (never touches the source GLB)
import bpy, bmesh, os, sys, math
argv = sys.argv[sys.argv.index("--") + 1:]
N = int(argv[0]); out = os.path.expanduser(argv[1]); os.makedirs(out, exist_ok=True)
RES = 1024
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.expanduser("~/Pictures/035_preview/concept/GatehouseWarden_AI.glb"))
hi = next(o for o in bpy.data.objects if o.type == "MESH"); hi.name = "hi"
sc = bpy.context.scene
# --- low: weld, drop floating specks, decimate
bm = bmesh.new(); bm.from_mesh(hi.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0001)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if False], context="FACES")
me = bpy.data.meshes.new("lo"); bm.to_mesh(me); bm.free()
lo = bpy.data.objects.new("lo", me); sc.collection.objects.link(lo)
for o in (hi, lo): o.select_set(False)
bpy.context.view_layer.objects.active = lo; lo.select_set(True)
# remove shells < 40 faces (floating specks)
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="DESELECT")
bm = bmesh.from_edit_mesh(me); seen = set(); kill = []
for f in bm.faces:
    if f.index in seen: continue
    st = [f]; seen.add(f.index); grp = []
    while st:
        a = st.pop(); grp.append(a)
        for e in a.edges:
            for g in e.link_faces:
                if g.index not in seen: seen.add(g.index); st.append(g)
    if len(grp) < 40: kill += grp
bmesh.ops.delete(bm, geom=kill, context="FACES"); bmesh.update_edit_mesh(me)
bpy.ops.object.mode_set(mode="OBJECT")
n0 = len(me.polygons)
# the welded AI mesh has ~1.7k non-manifold edges that stop collapse decimation at ~14k: voxel-remesh it into one clean shell first
vx = lo.modifiers.new("r", "REMESH"); vx.mode = "VOXEL"; vx.voxel_size = float(os.environ.get("GW_VOXEL", "0.004")); vx.use_smooth_shade = True
bpy.ops.object.modifier_apply(modifier="r")
print("voxel remesh ->", len(lo.data.polygons), "faces")
for _pass in range(4):
    cur = len(lo.data.polygons)
    if cur <= N * 1.03: break
    mod = lo.modifiers.new("d", "DECIMATE"); mod.ratio = max(N / cur, 0.05)
    bpy.ops.object.modifier_apply(modifier="d")
    print("pass", _pass, "->", len(lo.data.polygons))
print("RESULT lo tris", sum(len(p.vertices) - 2 for p in lo.data.polygons), "from", n0)
bpy.ops.object.shade_smooth()
# --- UV
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.006)
bpy.ops.uv.pack_islands(margin=0.006)
bpy.ops.object.mode_set(mode="OBJECT")
# --- bake setup
cy = sc.cycles; sc.render.engine = "CYCLES"; cy.samples = 8; cy.device = "GPU"
try:
    pref = bpy.context.preferences.addons["cycles"].preferences
    for t in ("OPTIX", "CUDA"):
        pref.compute_device_type = t; pref.get_devices()
        if any(d.type == t for d in pref.devices):
            for d in pref.devices: d.use = d.type == t
            break
except Exception as e: print("gpu?", e)
b = sc.render.bake; b.use_selected_to_active = True; b.cage_extrusion = float(os.environ.get("GW_EXT", "0.012")); b.max_ray_distance = float(os.environ.get("GW_RAY", "0.06")); b.margin = 6; b.use_clear = True
hm = hi.material_slots[0].material; nt = hm.node_tree
tex_c = next(n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image.name == "Image_0")
tex_m = next(n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image.name == "Image_1")
outn = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
def emit_from(tex, ch=None):
    for n in [n for n in nt.nodes if n.name == "EM"]: nt.nodes.remove(n)
    em = nt.nodes.new("ShaderNodeEmission"); em.name = "EM"
    nt.links.new(tex.outputs[0], em.inputs[0]); nt.links.new(em.outputs[0], outn.inputs[0])
lm = bpy.data.materials.new("lo_mat"); lm.use_nodes = True; lo.data.materials.append(lm); lnt = lm.node_tree
def newimg(name, cs):
    im = bpy.data.images.new(name, RES, RES, alpha=False); im.colorspace_settings.name = cs; return im
def bake(name, cs, typ, setup):
    im = newimg(name, cs); tn = lnt.nodes.new("ShaderNodeTexImage"); tn.image = im; lnt.nodes.active = tn; tn.name = "T_" + name
    setup()
    for o in sc.objects: o.select_set(False)
    hi.select_set(True); lo.select_set(True); bpy.context.view_layer.objects.active = lo
    bpy.ops.object.bake(type=typ)
    im.filepath_raw = os.path.join(out, name + ".png"); im.file_format = "PNG"; im.save(); print("baked", name)
    return im, tn
im_a, ta = bake("albedo", "sRGB", "EMIT", lambda: emit_from(tex_c))
im_m, tm = bake("metalrough", "Non-Color", "EMIT", lambda: emit_from(tex_m))
im_n, tn_ = bake("normal", "Non-Color", "NORMAL", lambda: None)
# --- final low material for glTF export
for n in list(lnt.nodes):
    if n.type not in ("TEX_IMAGE",): lnt.nodes.remove(n)
bs = lnt.nodes.new("ShaderNodeBsdfPrincipled"); mo = lnt.nodes.new("ShaderNodeOutputMaterial"); lnt.links.new(bs.outputs[0], mo.inputs[0])
lnt.links.new(ta.outputs[0], bs.inputs["Base Color"])
sp = lnt.nodes.new("ShaderNodeSeparateColor"); lnt.links.new(tm.outputs[0], sp.inputs[0])
lnt.links.new(sp.outputs[1], bs.inputs["Roughness"]); lnt.links.new(sp.outputs[2], bs.inputs["Metallic"])
nm = lnt.nodes.new("ShaderNodeNormalMap"); lnt.links.new(tn_.outputs[0], nm.inputs["Color"]); lnt.links.new(nm.outputs[0], bs.inputs["Normal"])
bpy.data.objects.remove(hi, do_unlink=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(out, "knight_lo.glb"), export_format="GLB", export_image_format="AUTO")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "knight_lo.blend"))
print("DONE")
