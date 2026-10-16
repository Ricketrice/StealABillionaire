# Pose the 15 Warden parts with rigid joint rotations (what the Roblox hidden R15 rig does) and render seam checks.
# Usage: blender -b -P gw_pose_render.py -- <parts_unit.blend> <outprefix> <pose: rest|stress|walk1|walk2|carry>
import bpy, os, sys, math
from mathutils import Vector, Matrix
a = sys.argv[sys.argv.index("--") + 1:]
src, out, pose = os.path.expanduser(a[0]), os.path.expanduser(a[1]), a[2]
bpy.ops.wm.open_mainfile(filepath=src)
sc = bpy.context.scene
P = {o.name.split("_")[1]: o for o in bpy.data.objects if o.type == "MESH"}
ZO = 0.5
def piv(x_kit, z): return Vector((-x_kit, 0.0, z - ZO - 0.0))  # blender bx = -x_kit
Z = dict(ankle=0.075, knee=0.19, hip=0.285, waist=0.385, sh=0.64, neck=0.668, elbow=0.45, wrist=0.31)
AX, LX = 0.25, 0.12
def rot(names, pv, axis, deg):
    M = Matrix.Translation(pv) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-pv)
    for n in names:
        if n in P: P[n].matrix_world = M @ P[n].matrix_world
def arm(side, shoulder_fwd=0, elbow=0, abd=0, wrist=0):
    sg = 1 if side == "Right" else -1
    n = lambda p: side + p
    rot([n("LowerArm"), n("Hand")], piv(sg * AX, Z["elbow"]), "X", -elbow)
    rot([n("Hand")], piv(sg * AX, Z["wrist"]), "X", -wrist)
    rot([n("UpperArm"), n("LowerArm"), n("Hand")], piv(sg * AX, Z["sh"]), "X", -shoulder_fwd)
    rot([n("UpperArm"), n("LowerArm"), n("Hand")], piv(sg * AX, Z["sh"]), "Y", sg * abd * -1)
def leg(side, hip=0, knee=0, ankle=0):
    sg = 1 if side == "Right" else -1
    n = lambda p: side + p
    rot([n("LowerLeg"), n("Foot")], piv(sg * LX, Z["knee"]), "X", knee)
    rot([n("Foot")], piv(sg * LX, Z["ankle"]), "X", ankle)
    rot([n(x) for x in ("UpperLeg", "LowerLeg", "Foot")], piv(sg * LX, Z["hip"]), "X", -hip)
def head(yaw=0, pitch=0):
    rot(["Head"], piv(0, Z["neck"]), "Z", yaw); rot(["Head"], piv(0, Z["neck"]), "X", pitch)
if pose == "stress":
    arm("Right", 65, 55); arm("Left", 0, 0, 40); leg("Left", 35, 30); head(25)
elif pose == "walk1":   # Roblox-like walk: arms swing +-35, legs +-35 with knee bend on the back leg
    arm("Right", 35, 10); arm("Left", -35, 10); leg("Right", -30, 5); leg("Left", 30, 45, -15); head(0)
elif pose == "walk2":
    arm("Right", -35, 10); arm("Left", 35, 10); leg("Right", 30, 45, -15); leg("Left", -30, 5); head(0)
elif pose == "carry":   # arms forward as if holding a bundle
    arm("Right", 70, 60); arm("Left", 70, 60); head(0, 10)
elif pose == "idle":
    arm("Right", 4, 3); arm("Left", -4, 3); head(6, 3)
if os.environ.get("GW_TINT"):
    import colorsys
    for i, (k, o) in enumerate(sorted(P.items())):
        m = bpy.data.materials.new("t" + k); m.use_nodes = True
        b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"); b.inputs["Base Color"].default_value = (*colorsys.hsv_to_rgb(i / 15.0, 0.8, 0.9), 1)
        o.data.materials.clear(); o.data.materials.append(m)
cy = sc.cycles; sc.render.engine = "CYCLES"; cy.samples = 36; cy.use_denoising = True
try:
    pref = bpy.context.preferences.addons["cycles"].preferences
    for t in ("OPTIX", "CUDA"):
        pref.compute_device_type = t; pref.get_devices()
        if any(d.type == t for d in pref.devices):
            for d in pref.devices: d.use = d.type == t
            cy.device = "GPU"; break
except Exception: pass
sc.render.resolution_x, sc.render.resolution_y = 720, 960
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
bg = w.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.62, 0.64, 0.68, 1)
cen = Vector((0, 0, 0))
def light(name, loc, e, size=2.0):
    d = bpy.data.lights.new(name, "AREA"); d.energy = e; d.size = size
    o = bpy.data.objects.new(name, d); sc.collection.objects.link(o); o.location = loc
    o.rotation_euler = (cen - o.location).to_track_quat("-Z", "Y").to_euler()
light("key", (1.6, -2.2, 1.6), 260); light("fill", (-2.2, -1.6, 0.4), 90, 3); light("rim", (0, 2.5, 1.5), 140)
cam = bpy.data.cameras.new("c"); cam.type = "ORTHO"; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
def shot(name, az, el=6, scale=1.25, target=(0, 0, 0)):
    cam.ortho_scale = scale; ar, er = math.radians(az), math.radians(el); t = Vector(target)
    co.location = t + Vector((math.sin(ar) * math.cos(er), -math.cos(ar) * math.cos(er), math.sin(er))) * 4
    co.rotation_euler = (t - co.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = out + "_" + name + ".png"; bpy.ops.render.render(write_still=True)
views = os.environ.get("GW_SHOTS", "front,tq,back,sh,hip").split(",")
if "front" in views: shot("front", 0)
if "tq" in views: shot("tq", -35)
if "back" in views: shot("back", 180)
if "side" in views: shot("side", 90)
if "sh" in views: shot("sh", -20, 8, 0.5, (-0.2, 0, 0.18))     # character's right shoulder (bx<0)
if "shL" in views: shot("shL", 20, 8, 0.5, (0.2, 0, 0.18))
if "hip" in views: shot("hip", -25, 8, 0.55, (0, 0, -0.2))
if "neck" in views: shot("neck", -25, 8, 0.5, (0, 0, 0.3))
