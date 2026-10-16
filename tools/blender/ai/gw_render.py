# Render the raw AI GLB (or a given .blend object) from front/back/three-quarter, lit PBR + flat albedo + wire. Usage: blender -b -P gw_render.py -- <glb> <outprefix>
import bpy, os, sys, math
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
glb = os.path.expanduser(argv[0]) if argv else os.path.expanduser("~/Pictures/035_preview/concept/GatehouseWarden_AI.glb")
out = os.path.expanduser(argv[1]) if len(argv) > 1 else os.path.expanduser("~/Pictures/035_preview/gw/raw")
bpy.ops.wm.read_factory_settings(use_empty=True)
if glb.endswith(".blend"):
    bpy.ops.wm.open_mainfile(filepath=glb)
else:
    bpy.ops.import_scene.gltf(filepath=glb)
objs = [o for o in bpy.data.objects if o.type == "MESH"]
sc = bpy.context.scene
cy = sc.cycles
sc.render.engine = "CYCLES"
cy.samples = 40
cy.use_denoising = True
try:
    pref = bpy.context.preferences.addons["cycles"].preferences
    for t in ("OPTIX", "CUDA"):
        try:
            pref.compute_device_type = t
            pref.get_devices()
            if any(d.type == t for d in pref.devices):
                for d in pref.devices:
                    d.use = d.type == t
                cy.device = "GPU"
                break
        except Exception:
            pass
except Exception:
    pass
sc.render.resolution_x, sc.render.resolution_y = 720, 960
sc.render.film_transparent = False
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
bg = w.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.62, 0.64, 0.68, 1); bg.inputs[1].default_value = 1.0
H = 1.0; cen = Vector((0, 0, 0))
def light(name, loc, e, size=2.0):
    d = bpy.data.lights.new(name, "AREA"); d.energy = e; d.size = size
    o = bpy.data.objects.new(name, d); sc.collection.objects.link(o); o.location = loc
    o.rotation_euler = (cen - o.location).to_track_quat("-Z", "Y").to_euler()
light("key", (1.6, -2.2, 1.6), 260); light("fill", (-2.2, -1.6, 0.4), 90, 3); light("rim", (0, 2.5, 1.5), 140)
cam = bpy.data.cameras.new("c"); cam.type = "ORTHO"; cam.ortho_scale = 1.25
co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
def shot(name, az, el=6, scale=1.25, target=(0, 0, 0)):
    cam.ortho_scale = scale
    a, e = math.radians(az), math.radians(el)
    t = Vector(target)
    co.location = t + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * 4
    co.rotation_euler = (t - co.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = out + "_" + name + ".png"
    bpy.ops.render.render(write_still=True)
mats = [(o, [s.material for s in o.material_slots]) for o in objs]
def flat_albedo():
    for o in objs:
        for s in o.material_slots:
            m = s.material; nt = m.node_tree
            bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
            tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None)
            em = nt.nodes.new("ShaderNodeEmission")
            if tex: nt.links.new(tex.outputs[0], em.inputs[0])
            outn = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
            nt.links.new(em.outputs[0], outn.inputs[0])
views = [("front", 0), ("back", 180), ("tq", -35)]
only = os.environ.get("GW_VIEWS")
for n, a in views: shot("pbr_" + n, a)
shot("pbr_head", -25, 8, 0.42, (0, 0, 0.36))
if not os.environ.get("GW_NOALB"):
    flat_albedo()
    for n, a in views: shot("alb_" + n, a)
    shot("alb_head", -25, 8, 0.42, (0, 0, 0.36))
