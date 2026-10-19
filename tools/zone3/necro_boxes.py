# Headless: loose-part bounding boxes (Blender coords, metres) of the necromap's solid meshes -> JSON.
import bpy, bmesh, sys, json
args = sys.argv[sys.argv.index("--") + 1:]
glb, out = args[0], args[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
SOLID = ["Ground_stone_dark","Ground_stone_grey","Gate_stone_dark","Gate_stone_grey","Gate_iron_black","Plaza_stone_dark","Plaza_stone_grey",
         "Plaza_iron_black","Plaza_wood_dark","Ruins_stone_grey","Ruins_stone_dark","Ruins_iron_black","Spire_stone_dark","Spire_stone_grey",
         "Spire_iron_black","Spire_roof_purple","Houses_stone_grey","Houses_stone_dark","Houses_plaster_worn","Houses_wood_dark",
         "Houses_brick_exposed","Houses_iron_black","Houses_roof_purple","Houses_roof_shingle_dark","Props_stone_dark","Props_iron_black"]
res = []
for o in bpy.context.scene.objects:
    if o.type != "MESH" or o.name not in SOLID: continue
    bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(o.matrix_world)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.002)
    bm.verts.ensure_lookup_table(); bm.verts.index_update()
    seen = set()
    for v in bm.verts:
        if v.index in seen: continue
        stack = [v]; seen.add(v.index); pts = []
        while stack:
            a = stack.pop(); pts.append(a.co.copy())
            for e in a.link_edges:
                b = e.other_vert(a)
                if b.index not in seen: seen.add(b.index); stack.append(b)
        lo = [min(p[i] for p in pts) for i in range(3)]; hi = [max(p[i] for p in pts) for i in range(3)]
        res.append({"mesh": o.name, "lo": [round(x,3) for x in lo], "hi": [round(x,3) for x in hi]})
    bm.free()
json.dump(res, open(out, "w"))
print("BOXES", len(res))
