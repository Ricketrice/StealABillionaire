import bpy, sys, time
print("PROBE blender", bpy.app.version_string)
sc = bpy.context.scene
print("PROBE engines", [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items])
try:
    sc.render.engine = "CYCLES"
    print("PROBE cycles ok; devices:", sc.cycles.device)
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.refresh_devices() if hasattr(prefs, "refresh_devices") else None
    print("PROBE compute types", [d.name + ":" + d.type for d in prefs.devices][:6])
except Exception as e:
    print("PROBE cycles error", e)
print("PROBE bake types", [e.identifier for e in bpy.types.BakeSettings.bl_rna.properties["type"].enum_items] if hasattr(bpy.types, "BakeSettings") else "n/a")
print("PROBE gltf", hasattr(bpy.ops.export_scene, "gltf"), "fbx", hasattr(bpy.ops.export_scene, "fbx"))
# tiny bake smoke test: cube, smart UV, emission bake to 256px
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
bpy.ops.mesh.primitive_cube_add()
ob = bpy.context.active_object
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.uv.smart_project(angle_limit=1.0, island_margin=0.02); bpy.ops.object.mode_set(mode="OBJECT")
img = bpy.data.images.new("t", 256, 256, float_buffer=True)
m = bpy.data.materials.new("m"); m.use_nodes = True
nt = m.node_tree; tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img; nt.nodes.active = tex
ob.data.materials.append(m)
sc.render.engine = "CYCLES"; sc.cycles.samples = 4; sc.cycles.device = "CPU"
sc.render.bake.use_selected_to_active = False
t = time.time()
bpy.ops.object.bake(type="AO")
print("PROBE AO bake ok", round(time.time() - t, 2), "s", img.pixels[0])
