# Render the skinned Warden: board views + poses (+ GIF frames). Usage: blender -b -P gw_skin_render.py -- <warden_skin.blend> <outdir> [board|gif|both]
import bpy, os, sys, math
from mathutils import Vector, Quaternion
a = sys.argv[sys.argv.index("--") + 1:]
src, out = os.path.expanduser(a[0]), os.path.expanduser(a[1]); mode = a[2] if len(a) > 2 else "both"
os.makedirs(out, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=src)
sc = bpy.context.scene
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
skin = next(o for o in bpy.data.objects if o.type == "MESH" and o.name.endswith("_Skin"))
PB = arm.pose.bones
for pb in PB: pb.rotation_mode = "QUATERNION"
AX = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}
cur = {}
def reset(): cur.clear(); [setattr(pb, "rotation_quaternion", Quaternion((1, 0, 0, 0))) for pb in PB]
def rot(name, axis, deg):
    """rotate bone `name` about a world-space axis (rest orientation), accumulating"""
    pb = PB[name]; ax_local = pb.bone.matrix_local.to_3x3().inverted() @ AX[axis]
    q = Quaternion(ax_local.normalized(), math.radians(deg))
    cur[name] = q @ cur.get(name, Quaternion((1, 0, 0, 0))); pb.rotation_quaternion = cur[name]
def arm_(side, fwd=0, elbow=0, out_=0):
    sg = 1 if side == "Right" else -1
    if fwd: rot(side + "UpperArm", "X", -fwd)
    if out_: rot(side + "UpperArm", "Y", sg * out_)
    if elbow: rot(side + "LowerArm", "X", -elbow)
def leg_(side, hip=0, knee=0, ankle=0):
    if hip: rot(side + "UpperLeg", "X", -hip)
    if knee: rot(side + "LowerLeg", "X", knee)
    if ankle: rot(side + "Foot", "X", ankle)
def pose(name, t=0.0):
    reset()
    if name == "rest": pass
    elif name == "idle":
        s = math.sin(t * 2 * math.pi)
        rot("UpperTorso", "X", 1.5 * s); arm_("Right", 3 * s, 4); arm_("Left", -3 * s, 4); rot("Head", "Z", 6 * math.sin(t * 2 * math.pi + 1)); rot("Head", "X", -2 * s)
    elif name == "walk":
        p = t * 2 * math.pi; s = math.sin(p)
        arm_("Right", 32 * s, 12 + 10 * max(0, s)); arm_("Left", -32 * s, 12 + 10 * max(0, -s))
        leg_("Right", 30 * s, 45 * max(0, -math.cos(p)) + 5, -10 * max(0, -s)); leg_("Left", -30 * s, 45 * max(0, math.cos(p)) + 5, -10 * max(0, s))
        rot("UpperTorso", "Z", 5 * s); rot("Head", "Z", -4 * s); rot("LowerTorso", "Z", -3 * s)
    elif name == "carry":
        k = min(1.0, t * 3) if t >= 0 else 1.0
        arm_("Right", 72 * k, 75 * k); arm_("Left", 72 * k, 75 * k); rot("Head", "X", 8 * k)
        s = math.sin(t * 2 * math.pi * 2); rot("UpperTorso", "X", 2 * s * k)
    elif name == "carry_walk":
        p = t * 2 * math.pi; s = math.sin(p)
        arm_("Right", 72, 75); arm_("Left", 72, 75); rot("Head", "X", 8)
        leg_("Right", 28 * s, 45 * max(0, -math.cos(p)) + 5); leg_("Left", -28 * s, 45 * max(0, math.cos(p)) + 5); rot("UpperTorso", "Z", 4 * s)
    elif name == "swing90":
        arm_("Right", 90, 0); arm_("Left", 90, 0)
    elif name == "side90":
        arm_("Right", 0, 0, 90); arm_("Left", 0, 0, 90)
    elif name == "swing90b":   # one arm forward 90, one back 45: the extreme of a hard swing
        arm_("Right", 90, 0); arm_("Left", -45, 0)
    bpy.context.view_layer.update()
# ---- scene
cy = sc.cycles; sc.render.engine = "CYCLES"; cy.samples = int(os.environ.get("GW_SAMPLES", "20")); cy.use_denoising = True
try:
    pref = bpy.context.preferences.addons["cycles"].preferences
    for t in ("OPTIX", "CUDA"):
        pref.compute_device_type = t; pref.get_devices()
        if any(d.type == t for d in pref.devices):
            for d in pref.devices: d.use = d.type == t
            cy.device = "GPU"; break
except Exception: pass
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
bgn = w.node_tree.nodes["Background"]; bgn.inputs[0].default_value = (0.45, 0.47, 0.52, 1)
cen = Vector((0, 0, 3.0))
def light(name, loc, e, size=6.0):
    d = bpy.data.lights.new(name, "AREA"); d.energy = e; d.size = size
    o = bpy.data.objects.new(name, d); sc.collection.objects.link(o); o.location = loc
    o.rotation_euler = (cen - o.location).to_track_quat("-Z", "Y").to_euler()
light("key", (6, -9, 9), 3600); light("fill", (-9, -6, 3), 1300, 8); light("rim", (0, 10, 8), 2200)
# noob 5 studs tall (R15-ish blocks), to the knight's side
def block(name, size, loc, col):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o = bpy.context.active_object; o.name = name; o.scale = size
    m = bpy.data.materials.new(name); m.use_nodes = True; next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (*col, 1)
    o.data.materials.append(m); return o
NOOB_X = 4.6
noob = [block("n_head", (1.2, 1.2, 1.2), (NOOB_X, 0, 4.4), (0.96, 0.8, 0.19)), block("n_torso", (2, 1, 2), (NOOB_X, 0, 3.0), (0.05, 0.41, 0.67)),
        block("n_armL", (1, 1, 2), (NOOB_X - 1.5, 0, 3.0), (0.96, 0.8, 0.19)), block("n_armR", (1, 1, 2), (NOOB_X + 1.5, 0, 3.0), (0.96, 0.8, 0.19)),
        block("n_legL", (1, 1, 2), (NOOB_X - 0.5, 0, 1.0), (0.31, 0.59, 0.31)), block("n_legR", (1, 1, 2), (NOOB_X + 0.5, 0, 1.0), (0.31, 0.59, 0.31))]
def show_noob(v):
    for o in noob: o.hide_render = not v
cam = bpy.data.cameras.new("c"); cam.type = "ORTHO"; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
def shot(path, az, el=5, scale=8.6, target=(0, 0, 3.15), res=(540, 700)):
    sc.render.resolution_x, sc.render.resolution_y = res
    cam.ortho_scale = scale; ar, er = math.radians(az), math.radians(el); t = Vector(target)
    co.location = t + Vector((math.sin(ar) * math.cos(er), -math.cos(ar) * math.cos(er), math.sin(er))) * 30
    co.rotation_euler = (t - co.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)
def silhouette(path, az):
    mats = list(skin.data.materials); m = bpy.data.materials.new("sil"); m.use_nodes = True
    nt = m.node_tree; [nt.nodes.remove(n) for n in list(nt.nodes)]
    e = nt.nodes.new("ShaderNodeEmission"); e.inputs[0].default_value = (0, 0, 0, 1); o = nt.nodes.new("ShaderNodeOutputMaterial"); nt.links.new(e.outputs[0], o.inputs[0])
    skin.data.materials.clear(); skin.data.materials.append(m)
    old = bgn.inputs[0].default_value[:]; bgn.inputs[0].default_value = (1, 1, 1, 1); bgn.inputs[1].default_value = 1.0
    saved = [(l.hide_render) for l in bpy.data.objects if l.type == "LIGHT"]
    shot(path, az)
    bgn.inputs[0].default_value = old; skin.data.materials.clear(); [skin.data.materials.append(x) for x in mats]
if mode in ("board", "both"):
    show_noob(False); pose("rest")
    shot(out + "/front.png", 0); shot(out + "/back.png", 180); shot(out + "/tq.png", -35)
    silhouette(out + "/sil.png", 0)
    show_noob(True); shot(out + "/scale.png", 0, scale=12.5, target=(2.3, 0, 2.9), res=(800, 560)); show_noob(False)
    shot(out + "/icon512.png", -25, scale=7.4, target=(0, 0, 3.2), res=(512, 512))
    for pn in ("walk", "carry", "swing90", "side90", "swing90b"):
        pose(pn, 0.25 if pn == "walk" else 1.0)
        shot(out + "/pose_%s_front.png" % pn, 0); shot(out + "/pose_%s_tq.png" % pn, -40)
    # close-ups of stretch zones in the hard pose
    pose("swing90"); shot(out + "/close_shoulder.png", -35, 8, 3.4, (-1.9, 0, 4.0), (540, 540))
    pose("walk", 0.25); shot(out + "/close_hip.png", -30, 8, 3.8, (0, 0, 2.2), (540, 540))
    pose("carry", 1.0); shot(out + "/close_elbow.png", -50, 8, 4.0, (-1.8, -0.6, 3.4), (540, 540))
if mode in ("gif", "both"):
    show_noob(False); os.makedirs(out + "/frames", exist_ok=True); n = 0
    seq = [("idle", i / 12) for i in range(12)] + [("walk", i / 16) for i in range(16)] + [("carry", i / 8 * 0.4) for i in range(6)] + [("carry", 1.0 + i / 12) for i in range(12)] + [("carry_walk", i / 16) for i in range(16)]
    for pn, t in seq:
        pose(pn, t); shot(out + "/frames/f%03d.png" % n, -30, 5, 8.2, (0, 0, 3.15), (300, 400)); n += 1
    print("FRAMES", n)
