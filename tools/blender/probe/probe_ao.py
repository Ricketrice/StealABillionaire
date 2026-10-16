import os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
import bpy, numpy as np
from kit035 import pbr
bpy.ops.wm.open_mainfile(filepath=os.path.expanduser("~/Pictures/035_preview/sk4_dev/sk4_uv.blend"))
objs = [o for o in bpy.data.objects if o.type == "MESH" and o.data.uv_layers]
for o in objs:
    o["mid"] = 0.1; o["gid"] = 0.1
j = pbr.joined_copy(objs)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.samples = 24; sc.cycles.device = "GPU" if pbr._gpu() else "CPU"
w = sc.world or bpy.data.worlds.new("w"); sc.world = w
w.light_settings.distance = 0.9
img = bpy.data.images.new("ao", 1024, 1024, float_buffer=True)
mat = bpy.data.materials.new("m"); mat.use_nodes = True
tex = mat.node_tree.nodes.new("ShaderNodeTexImage"); tex.image = img; mat.node_tree.nodes.active = tex
j.data.materials.clear(); j.data.materials.append(mat)
bpy.ops.object.select_all(action="DESELECT"); j.select_set(True); bpy.context.view_layer.objects.active = j
bpy.ops.object.bake(type="AO", use_clear=True)
a = pbr._arr(img)[..., 0]
print("PROBE AO(type) pct", np.round(np.percentile(a[a > 0], [5, 25, 50, 75, 95]), 3))
# orientation: fraction of faces whose outward ray (normal) is free for 0.25 studs
from mathutils.bvhtree import BVHTree
dg = bpy.context.evaluated_depsgraph_get()
bvh = BVHTree.FromObject(j, dg)
free = 0; tot = 0
for p in j.data.polygons:
    c = j.matrix_world @ p.center; n = (j.matrix_world.to_3x3() @ p.normal).normalized()
    hit = bvh.ray_cast(c + n * 0.01, n, 0.25)
    tot += 1; free += hit[0] is None
print("PROBE faces with a free outward ray (0.25):", free, "/", tot)

rows = []
for o in objs:
    f = t = 0
    for p in o.data.polygons:
        c = o.matrix_world @ p.center; n = (o.matrix_world.to_3x3() @ p.normal).normalized()
        if p.area < 1e-6: continue
        hit = bvh.ray_cast(c + n * 0.01, n, 0.25)
        t += 1; f += hit[0] is None
    rows.append((f / max(t, 1), t, o.name))
for fr, t, nme in sorted(rows)[:40]:
    print("PROBE obj %.2f %3d %s" % (fr, t, nme))
