# Headless: for named meshes in a GLB, print each connected island's bounds in game studs
# (x3.5714, glTF frame: x, y up, z) so floors/paths/platforms can be located.
# flatpak run org.blender.Blender -b --factory-startup -P <abs>/islands.py -- <file.glb> <name-substring>...
import bpy, sys, bmesh

args = sys.argv[sys.argv.index("--") + 1 :]
path, keys = args[0], args[1:]
S = 3.5714
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
for o in bpy.context.scene.objects:
    if o.type != "MESH" or not any(k in o.name for k in keys):
        continue
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.transform(o.matrix_world)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bm.verts.ensure_lookup_table()
    seen = set()
    isl = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack = [v]
        seen.add(v.index)
        pts = []
        while stack:
            x = stack.pop()
            pts.append(x.co.copy())
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen:
                    seen.add(y.index)
                    stack.append(y)
        isl.append(pts)
    print("MESH", o.name, "islands", len(isl), "tris", sum(len(f.verts) - 2 for f in bm.faces))
    rows = []
    for pts in isl:
        # blender (x, y, z) -> glTF (x, z, -y) -> studs
        xs = [p.x * S for p in pts]
        ys = [p.z * S for p in pts]
        zs = [-p.y * S for p in pts]
        rows.append((min(xs), max(xs), min(ys), max(ys), min(zs), max(zs), len(pts)))
    rows.sort()
    for r in rows[:80]:
        print("   x %7.1f..%7.1f  y %6.1f..%6.1f  z %7.1f..%7.1f  v%d" % r)
    bm.free()
