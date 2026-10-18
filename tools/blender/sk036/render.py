# Headless: import a GLB and render a few Workbench views (flat material colours) for a look / kid-safe check.
# flatpak run org.blender.Blender -b --factory-startup -P render.py -- <file.glb> <outdir> [objectNameFilter]
import bpy, sys, math, mathutils, os
args = sys.argv[sys.argv.index("--") + 1:]
path, out = args[0], args[1]
flt = args[2] if len(args) > 2 else None
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "MATERIAL"
sc.display.shading.show_shadows = True
sc.render.resolution_x, sc.render.resolution_y = 1280, 800
sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.55, 0.75, 0.9)
objs = [o for o in sc.objects if o.type == "MESH" and (not flt or flt.lower() in o.name.lower())]
for o in sc.objects:
    if o.type == "MESH" and o not in objs:
        o.hide_render = True  # only the filtered objects are drawn
lo = mathutils.Vector((1e9,) * 3); hi = mathutils.Vector((-1e9,) * 3)
for o in objs:
    for c in o.bound_box:
        w = o.matrix_world @ mathutils.Vector(c)
        lo = mathutils.Vector(map(min, lo, w)); hi = mathutils.Vector(map(max, hi, w))
centre = (lo + hi) / 2; rad = (hi - lo).length / 2
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 35
os.makedirs(out, exist_ok=True)
for name, d in {"three_quarter": (1, -1, 0.8), "front": (0, -1, 0.35), "back": (0, 1, 0.5), "top": (0, -0.01, 1), "side": (1, 0, 0.4)}.items():
    v = mathutils.Vector(d).normalized()
    cam.location = centre + v * max(rad * 2.0, 3.0)
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(out, (flt or "all") + "_" + name + ".png")
    bpy.ops.render.render(write_still=True)
print("RENDERED", len(objs), "objects to", out)
