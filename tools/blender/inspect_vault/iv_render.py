# Renders of the Vault inspection copy: rest views + 8 frames per clip (contact sheets are assembled afterwards with PIL).
import bpy, os, math
from mathutils import Vector
OUT = os.path.expanduser("~/Pictures/035_preview/vault/r"); os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=os.path.expanduser("~/Pictures/035_preview/vault/vault_inspect_copy.blend"))
sc = bpy.context.scene; objs = bpy.data.objects
CLIPS = ["Idle", "Walk", "Steal_Grab", "Normal_Repossess", "Event_MarketCrash", "Event_VaultLock", "Event_HostileTakeover", "Event_BankruptNova"]
cy = sc.cycles; sc.render.engine = "CYCLES"; cy.samples = int(os.environ.get("V_SAMPLES", "14")); cy.use_denoising = True
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
def shot(path, az, el=6, scale=4.0, target=(0, 0, 1.45), res=(300, 420)):
    sc.render.resolution_x, sc.render.resolution_y = res; cam.ortho_scale = scale; ar, er = math.radians(az), math.radians(el); t = Vector(target)
    co.location = t + Vector((math.sin(ar) * math.cos(er), -math.cos(ar) * math.cos(er), math.sin(er))) * 20
    co.rotation_euler = (t - co.location).to_track_quat("-Z", "Y").to_euler(); sc.render.filepath = path; bpy.ops.render.render(write_still=True)
for o in objs:
    if o.animation_data:
        o.animation_data.action = None
        for t in o.animation_data.nla_tracks: t.mute = True
sc.frame_set(1)
shot(OUT + "/rest_front.png", 0, res=(480, 660)); shot(OUT + "/rest_back.png", 180, res=(480, 660)); shot(OUT + "/rest_tq.png", -35, res=(480, 660))
for c in CLIPS:
    for o in objs:
        ad = o.animation_data
        if ad:
            for t in ad.nla_tracks: t.mute = t.name != c
    end = int(max(s.frame_end for o in objs if o.animation_data for t in o.animation_data.nla_tracks if t.name == c for s in t.strips))
    fr = [1 + round(i * (end - 1) / 7) for i in range(8)]
    for i, f in enumerate(fr):
        sc.frame_set(f); shot(OUT + "/%s_%d.png" % (c, i), -35, scale=(5.2 if c.startswith("Event") or c == "Normal_Repossess" else 4.2), target=(0, 0, 1.5 if c.startswith("Event") else 1.45))
    print("DONE", c, fr)
