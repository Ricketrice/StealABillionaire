# Headless: dump every object of a GLB (name, parent, type, world bounds, tris, materials) to JSON.
# flatpak run org.blender.Blender -b --factory-startup -P <abs>/inspect_glb.py -- <file.glb> <out.json>
# Output path must be under $HOME (the flatpak /tmp is private).
import bpy, sys, json
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1 :]
path, out = args[0], args[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
dg = bpy.context.evaluated_depsgraph_get()

objs = []
for o in bpy.context.scene.objects:
    row = {"name": o.name, "type": o.type, "parent": o.parent.name if o.parent else None}
    mw = o.matrix_world
    row["loc"] = [round(v, 4) for v in mw.translation]
    row["rot"] = [round(v, 4) for v in mw.to_euler()]
    row["scale"] = [round(v, 4) for v in mw.to_scale()]
    if o.type == "MESH":
        m = o.evaluated_get(dg).to_mesh()
        row["tris"] = sum(len(p.vertices) - 2 for p in m.polygons)
        lo = [1e9] * 3
        hi = [-1e9] * 3
        for v in m.vertices:
            w = mw @ v.co
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
        row["lo"] = [round(v, 4) for v in lo]
        row["hi"] = [round(v, 4) for v in hi]
        row["mats"] = [s.material.name if s.material else "-" for s in o.material_slots]
        o.evaluated_get(dg).to_mesh_clear()
    objs.append(row)

mats = {}
for m in bpy.data.materials:
    b = next((n for n in (m.node_tree.nodes if m.node_tree else []) if n.type == "BSDF_PRINCIPLED"), None)
    if not b:
        continue
    em = b.inputs.get("Emission Color")
    es = b.inputs.get("Emission Strength")
    mats[m.name] = {
        "base": [round(x, 4) for x in b.inputs["Base Color"].default_value[:4]],
        "tex": b.inputs["Base Color"].is_linked,
        "alpha": round(b.inputs["Alpha"].default_value, 3),
        "rough": round(b.inputs["Roughness"].default_value, 3),
        "metal": round(b.inputs["Metallic"].default_value, 3),
        "emit": [round(x, 3) for x in em.default_value[:3]] if em else None,
        "emitStrength": round(es.default_value, 3) if es else None,
    }
json.dump({"file": path, "objects": objs, "materials": mats}, open(out, "w"), indent=0)
print("WROTE", out, len(objs), "objects")
