# Headless: import a GLB into an empty scene and print object / triangle / material stats.
# flatpak run org.blender.Blender -b --factory-startup -P stats.py -- <file.glb>
import bpy, sys, collections
path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
dg = bpy.context.evaluated_depsgraph_get()
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
tris, mats, rows = 0, collections.Counter(), []
lo = [1e9] * 3; hi = [-1e9] * 3
for o in meshes:
    m = o.evaluated_get(dg).to_mesh()
    t = sum(len(p.vertices) - 2 for p in m.polygons)
    tris += t
    for c in o.bound_box:
        w = o.matrix_world @ __import__("mathutils").Vector(c)
        for i in range(3):
            lo[i] = min(lo[i], w[i]); hi[i] = max(hi[i], w[i])
    dims = o.dimensions
    rows.append((t, o.name, tuple(round(d, 1) for d in dims), [s.material.name if s.material else "-" for s in o.material_slots]))
    for s in o.material_slots:
        mats[s.material.name if s.material else "-"] += 1
    o.evaluated_get(dg).to_mesh_clear()
print("OBJECTS", len(bpy.context.scene.objects), "MESHES", len(meshes), "TRIS", tris)
print("BOUNDS", [round(v, 1) for v in lo], [round(v, 1) for v in hi])
print("MATERIALS", len(mats))
for m in bpy.data.materials:
    bsdf = next((n for n in (m.node_tree.nodes if m.node_tree else []) if n.type == "BSDF_PRINCIPLED"), None)
    col = tuple(round(x, 2) for x in bsdf.inputs["Base Color"].default_value[:3]) if bsdf else None
    tex = bool(bsdf and bsdf.inputs["Base Color"].is_linked)
    print("  MAT", m.name, col, "tex" if tex else "", mats[m.name])
print("IMAGES", len(bpy.data.images), [i.name for i in bpy.data.images][:10])
rows.sort(reverse=True)
print("TOP 15 BY TRIS")
for r in rows[:15]: print("  ", r)
small = [r for r in rows if max(r[2]) < 2.0]
print("SMALL (<2 m) objects:", len(small), "tris", sum(r[0] for r in small))
names = collections.Counter(r[1].rstrip("0123456789.").rstrip("_") for r in rows)
print("NAME GROUPS", len(names)); print("  ", sorted(names.items(), key=lambda x: -x[1])[:60])
