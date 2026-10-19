# Headless: base GLB -> occupancy in plot-local studs (x, z) for geometry in a height band; writes JSON of
# 2D polygons (clipped triangles) + a PNG map. Mapping from Studio Base1 (see notes): k=3.5714,
# local x = sx*(Bx-41.44)*k, local y = 9.75 + (Bz-2.8)*k, local z = -1.75 - (By-4.424)*k
import bpy, sys, json, math
import numpy as np
args = sys.argv[sys.argv.index("--") + 1:]
glb, out = args[0], args[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
dg = bpy.context.evaluated_depsgraph_get()
K = 3.5714
Y0, Y1 = 0.3, 12.0
skip = ("Slot", "Threshold")
polys = []
for o in bpy.context.scene.objects:
    if o.type != "MESH" or o.name.startswith(skip):
        continue
    m = o.evaluated_get(dg).to_mesh(); mw = o.matrix_world
    vs = [mw @ v.co for v in m.vertices]
    for p in m.polygons:
        pts = [vs[i] for i in p.vertices]
        loc = [(( p_.x - 41.44) * K, 9.75 + (p_.z - 2.8) * K, -1.75 - (p_.y - 4.424) * K) for p_ in pts]
        # clip polygon against y >= Y0 and y <= Y1 (Sutherland-Hodgman on y)
        def clip(poly, keep, edge):
            res = []
            for i in range(len(poly)):
                a, b = poly[i], poly[(i + 1) % len(poly)]
                ka, kb = keep(a), keep(b)
                if ka: res.append(a)
                if ka != kb:
                    t = (edge - a[1]) / (b[1] - a[1])
                    res.append(tuple(a[j] + t * (b[j] - a[j]) for j in range(3)))
            return res
        c = clip(loc, lambda q: q[1] >= Y0, Y0)
        if c: c = clip(c, lambda q: q[1] <= Y1, Y1)
        if len(c) >= 1:
            polys.append({"mesh": o.name, "xz": [[round(q[0], 3), round(q[2], 3)] for q in c], "ymin": round(min(q[1] for q in c), 2)})
    o.evaluated_get(dg).to_mesh_clear()
json.dump(polys, open(out, "w"))
print("POLYS", len(polys))
