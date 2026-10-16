# Debug render of one part: caps in red, plus open boundary / non-manifold counts. Usage: -- <parts_unit.blend> <PartName> <outpng>
import bpy, bmesh, os, sys, math
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.open_mainfile(filepath=os.path.expanduser(a[0]))
sc = bpy.context.scene
for o in bpy.data.objects:
    if o.type == "MESH" and a[1] not in o.name: o.hide_render = True
ob = next(o for o in bpy.data.objects if o.type == "MESH" and a[1] in o.name and not o.hide_render)
me = ob.data; uv = me.uv_layers.active.data
bm = bmesh.new(); bm.from_mesh(me)
print("PART", ob.name, "tris", len(bm.faces), "boundary", sum(1 for e in bm.edges if e.is_boundary), "nonmanifold>2", sum(1 for e in bm.edges if len(e.link_faces) > 2))
red = bpy.data.materials.new("red"); red.diffuse_color = (1, 0, 0, 1); red.use_nodes = True
rb = next(n for n in red.node_tree.nodes if n.type == "BSDF_PRINCIPLED"); rb.inputs["Base Color"].default_value = (1, 0, 0, 1)
me.materials.append(red)
for p in me.polygons:
    if all(abs(uv[li].uv[0] - 0.015) < 1e-5 and abs(uv[li].uv[1] - 0.015) < 1e-5 for li in p.loop_indices): p.material_index = 1
sc.render.engine = "CYCLES"; sc.cycles.samples = 24
sc.render.resolution_x = sc.render.resolution_y = 640
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.62, 0.66, 1)
bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]; cen = sum(bb, Vector()) / 8; size = max((max(b[i] for b in bb) - min(b[i] for b in bb)) for i in range(3))
for nm, loc, e in (("k", (2, -2.5, 2), 400), ("f", (-2.5, -1.5, 0.5), 150)):
    d = bpy.data.lights.new(nm, "AREA"); d.energy = e; d.size = 2; o = bpy.data.objects.new(nm, d); sc.collection.objects.link(o); o.location = loc
    o.rotation_euler = (cen - o.location).to_track_quat("-Z", "Y").to_euler()
cam = bpy.data.cameras.new("c"); cam.type = "ORTHO"; cam.ortho_scale = size * 1.3; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
for i, az in enumerate((-30, 150)):
    ar = math.radians(az); co.location = cen + Vector((math.sin(ar), -math.cos(ar), 0.35)) * 4
    co.rotation_euler = (cen - co.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.expanduser(a[2]) + "_%d.png" % i; bpy.ops.render.render(write_still=True)
