# Quick look at any character GLB as authored (Blender's own animation): rest views + N frames per clip, FX visible. Usage:
#   VAULT_GLB=<glb> VAULT_WORK=<out> flatpak run org.blender.Blender -b -P $PWD/tools/blender/vault/vw_glb_look.py -- [frames per clip] [clip,clip...]
import bpy, os, sys, math
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vw_common as C
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
NF = int(argv[0]) if argv else 6
ONLY = argv[1].split(",") if len(argv) > 1 else None
OUT = os.path.join(C.WORK, "look"); os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=C.GLB)
sc = bpy.context.scene; objs = bpy.data.objects
cy = sc.cycles; sc.render.engine = "CYCLES"; cy.samples = int(os.environ.get("V_SAMPLES", "8")); cy.use_denoising = True
try:
    pref = bpy.context.preferences.addons["cycles"].preferences
    for t in ("OPTIX", "CUDA"):
        pref.compute_device_type = t; pref.get_devices()
        if any(d.type == t for d in pref.devices):
            for d in pref.devices: d.use = d.type == t
            cy.device = "GPU"; break
except Exception: pass
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (0.2, 0.21, 0.25, 1)
cen = Vector((0, 0, 1.45))
def light(n, loc, e, size=4):
    d = bpy.data.lights.new(n, "AREA"); d.energy = e; d.size = size; o = bpy.data.objects.new(n, d); sc.collection.objects.link(o); o.location = loc
    o.rotation_euler = (cen - o.location).to_track_quat("-Z", "Y").to_euler()
light("k", (4, -6, 6), 1800); light("f", (-6, -4, 2), 700, 6); light("r", (0, 6, 5), 900)
cam = bpy.data.cameras.new("c"); cam.type = "ORTHO"; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
def shot(path, az, el=6, scale=4.0, target=(0, 0, 1.45), res=(360, 480)):
    sc.render.resolution_x, sc.render.resolution_y = res; cam.ortho_scale = scale; ar, er = math.radians(az), math.radians(el); t = Vector(target)
    co.location = t + Vector((math.sin(ar) * math.cos(er), -math.cos(ar) * math.cos(er), math.sin(er))) * 20
    co.rotation_euler = (t - co.location).to_track_quat("-Z", "Y").to_euler(); sc.render.filepath = path; bpy.ops.render.render(write_still=True)
tracks = sorted({t.name for o in objs if o.animation_data for t in o.animation_data.nla_tracks})
print("CLIPS", tracks)
for o in objs:
    if o.animation_data:
        o.animation_data.action = None
        for t in o.animation_data.nla_tracks: t.mute = True
sc.frame_set(1)
if not ONLY:
    shot(OUT + "/rest_front.png", 0, res=(520, 700)); shot(OUT + "/rest_tq.png", -35, res=(520, 700)); shot(OUT + "/rest_back.png", 180, res=(520, 700))
for c in tracks:
    if ONLY and c not in ONLY: continue
    for o in objs:
        if o.animation_data:
            for t in o.animation_data.nla_tracks: t.mute = t.name != c
    end = int(max(s.frame_end for o in objs if o.animation_data for t in o.animation_data.nla_tracks if t.name == c for s in t.strips))
    for i in range(NF):
        f = 1 + round(i * (end - 1) / max(NF - 1, 1)); sc.frame_set(f)
        shot(OUT + "/%s_%d.png" % (c, i), -35, scale=6.0, target=(0, 0, 1.6), res=(320, 440))
    print("DONE", c)
