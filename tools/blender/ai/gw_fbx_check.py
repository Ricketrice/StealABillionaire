# Re-import the exported Warden FBX and report parts, triangles, size (studs after the x100 FBX unit), open edges per part.
import bpy, bmesh, os, sys
a = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=os.path.expanduser(a[0]))
tot = 0; lo = [1e9] * 3; hi = [-1e9] * 3
for o in sorted((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: o.name):
    me = o.data; bm = bmesh.new(); bm.from_mesh(me)
    tris = sum(len(f.verts) - 2 for f in bm.faces); bnd = sum(1 for e in bm.edges if e.is_boundary)
    nm = o.name.startswith("GatehouseWarden_") and not o.name.split("_")[1] in ("Anchor", "AxisX", "AxisY", "AxisFront")
    ws = [o.matrix_world @ v.co for v in me.vertices]
    if nm:
        tot += tris
        for w in ws:
            for i in range(3): lo[i] = min(lo[i], w[i]); hi[i] = max(hi[i], w[i])
    print("FBXPART %-34s tris %5d open_edges %3d uv %s mats %d" % (o.name, tris, bnd, bool(me.uv_layers), len(me.materials)))
    bm.free()
print("FBXTOTAL tris", tot, "size (blender units; 1 = 1 stud after import scale)", [round(hi[i] - lo[i], 3) for i in range(3)], "min", [round(x, 3) for x in lo])
