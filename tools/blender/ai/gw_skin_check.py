# Re-import the skinned FBX: bones, names (.001?), skin weights, influences per vertex, size in studs.
import bpy, os, sys, numpy as np
a = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=os.path.expanduser(a[0]))
arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]; meshes = [o for o in bpy.data.objects if o.type == "MESH"]
print("OBJECTS", [(o.name, o.type) for o in bpy.data.objects])
for ar in arms: print("BONES", len(ar.data.bones), sorted(b.name for b in ar.data.bones)); print("ROOTS", [b.name for b in ar.data.bones if not b.parent])
print("DOT001", [o.name for o in bpy.data.objects if ".00" in o.name] + [b.name for ar in arms for b in ar.data.bones if ".00" in b.name])
for m in meshes:
    if "Skin" not in m.name: continue
    infl = np.array([len([g for g in v.groups if g.weight > 0.003]) for v in m.data.vertices]); tot = np.array([sum(g.weight for g in v.groups) for v in m.data.vertices])
    ws = [m.matrix_world @ v.co for v in m.data.vertices]
    lo = [min(w[i] for w in ws) for i in range(3)]; hi = [max(w[i] for w in ws) for i in range(3)]
    print("SKIN", m.name, "tris", sum(len(p.vertices) - 2 for p in m.data.polygons), "groups", len(m.vertex_groups), "max infl", infl.max(), "unweighted", int((tot < 0.5).sum()), "weight sum min/max", round(float(tot.min()), 3), round(float(tot.max()), 3))
    print("SIZE blender units (x100 = studs after the FBX 0.01)", [round(hi[i] - lo[i], 4) for i in range(3)], "min", [round(x, 4) for x in lo], "parent", m.parent.name if m.parent else None, "modifiers", [x.type for x in m.modifiers])
