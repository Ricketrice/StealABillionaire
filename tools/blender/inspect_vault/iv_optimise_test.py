# Optimisation feasibility on a COPY: weld split vertices + planar dissolve (UV/material seams kept) on the character meshes; counts only (no export).
import bpy, bmesh, os, math
bpy.ops.wm.open_mainfile(filepath=os.path.expanduser("~/Pictures/035_preview/vault/vault_inspect_copy.blend"))
objs = bpy.data.objects
def isfx(o):
    while o:
        if o.name.startswith("FX_"): return True
        o = o.parent
    return False
body = [o for o in objs if o.type == "MESH" and not isfx(o)]
before = after_weld = after = 0; rows = []
for o in sorted(body, key=lambda o: -len(o.data.polygons)):
    me = o.data; bm = bmesh.new(); bm.from_mesh(me); t0 = sum(len(f.verts) - 2 for f in bm.faces)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00002); t1 = sum(len(f.verts) - 2 for f in bm.faces)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(4), verts=bm.verts, edges=bm.edges, delimit={"UV", "MATERIAL"})
    bmesh.ops.triangulate(bm, faces=bm.faces[:]); t2 = len(bm.faces)
    bm.to_mesh(me); bm.free(); before += t0; after += t2; rows.append((o.name, t0, t2))
print("CHARACTER body meshes (27): tris before %d -> after weld+planar-dissolve %d (%.0f%%)" % (before, after, 100 * after / before))
for r in rows[:10]: print("  %-18s %5d -> %5d" % r)
# stronger test: collapse decimation to 55% on each body mesh with more than 300 tris (UV seams are kept by the weld), then a front render for comparison
big = [o for o in body if len(o.data.polygons) > 300]
for o in big:
    for oo in bpy.context.view_layer.objects: oo.select_set(False)
    bpy.context.view_layer.objects.active = o; o.select_set(True)
    m = o.modifiers.new("d", "DECIMATE"); m.ratio = 0.55; m.use_collapse_triangulate = True; bpy.ops.object.modifier_apply(modifier="d")
n2 = sum(len(o.data.polygons) for o in body)
print("CHARACTER after collapse-decimate 55%% on the %d big meshes: %d tris (%.0f%% of original 14,996)" % (len(big), n2, 100 * n2 / 14996))
import mathutils
sc = bpy.context.scene; cy = sc.cycles; sc.render.engine = "CYCLES"; cy.samples = 14; cy.use_denoising = True
try:
    pref = bpy.context.preferences.addons["cycles"].preferences
    for t in ("OPTIX", "CUDA"):
        pref.compute_device_type = t; pref.get_devices()
        if any(d.type == t for d in pref.devices):
            for d in pref.devices: d.use = d.type == t
            cy.device = "GPU"; break
except Exception: pass
for o in objs:
    if o.type == "MESH" and isfx(o): o.hide_render = True
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (0.2, 0.21, 0.25, 1)
cen = mathutils.Vector((0, 0, 1.45))
for n, loc, e, sz in (("k", (4, -6, 6), 1800, 4), ("f", (-6, -4, 2), 700, 6)):
    d = bpy.data.lights.new(n, "AREA"); d.energy = e; d.size = sz; lo = bpy.data.objects.new(n, d); sc.collection.objects.link(lo); lo.location = loc
    lo.rotation_euler = (cen - lo.location).to_track_quat("-Z", "Y").to_euler()
cam = bpy.data.cameras.new("c"); cam.type = "ORTHO"; cam.ortho_scale = 3.4; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
sc.render.resolution_x, sc.render.resolution_y = 600, 760
import math as m_
for nm, az in (("front", 0), ("tq", -35)):
    a = m_.radians(az); co.location = cen + mathutils.Vector((m_.sin(a) * 20, -m_.cos(a) * 20, 3)); co.rotation_euler = (cen - co.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.expanduser("~/Pictures/035_preview/vault/r/opt_%s.png" % nm); bpy.ops.render.render(write_still=True)
