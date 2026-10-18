import bpy, sys
path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
for o in bpy.context.scene.objects:
    if o.type == "MESH" and any(k in o.name for k in ("Mer", "NPC", "Statue", "Dragon", "FX_", "Fish", "Skull", "Bone")):
        print("OBJ", o.name, tuple(round(d, 1) for d in o.dimensions), tuple(round(v, 1) for v in o.matrix_world.translation), len(o.data.polygons))
