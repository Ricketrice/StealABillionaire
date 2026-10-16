# Horizontal cross-sections of the optimised AI knight: how many separate contours (limbs/torso) at each height, and their x extents. Tells whether limbs are fused.
import bpy, bmesh, os
import numpy as np
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.open_mainfile(filepath=os.path.expanduser("~/Pictures/035_preview/gw/opt8k_b/knight_lo.blend"))
o = next(o for o in bpy.data.objects if o.type == "MESH")
print("tris", sum(len(p.vertices) - 2 for p in o.data.polygons), "bbox z", [round(min(v.co.z for v in o.data.vertices), 3), round(max(v.co.z for v in o.data.vertices), 3)])
for z in [0.02, 0.06, 0.10, 0.15, 0.20, 0.24, 0.27, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85]:
    zz = z - 0.5
    bm = bmesh.new(); bm.from_mesh(o.data)
    res = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, zz), plane_no=(0, 0, 1))
    cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    verts = {v for e in cut for v in e.verts}
    seen = set(); loops = []
    adj = {}
    for e in cut:
        a, b = e.verts; adj.setdefault(a, []).append(b); adj.setdefault(b, []).append(a)
    for v in adj:
        if v in seen: continue
        st = [v]; seen.add(v); comp = []
        while st:
            a = st.pop(); comp.append(a)
            for b in adj[a]:
                if b not in seen: seen.add(b); st.append(b)
        xs = [c.co.x for c in comp]; ys = [c.co.y for c in comp]
        if len(comp) >= 8: loops.append((round(min(xs), 3), round(max(xs), 3), round(min(ys), 3), round(max(ys), 3), len(comp)))
    loops.sort()
    print(f"z={z:.2f} loops>=8verts: {len(loops)}  " + " | ".join(f"x[{a:+.2f},{b:+.2f}] y[{c:+.2f},{d:+.2f}]" for a, b, c, d, n in loops))
    bm.free()
