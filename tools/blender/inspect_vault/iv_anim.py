# Per-clip motion analysis of the imported Vault rig (copy of the GLB import): joint ranges, feet vs ground, root motion, mesh-vs-mesh intersections (clipping).
import bpy, bmesh, os, math, json
from mathutils import Vector, Quaternion, Matrix
from mathutils.bvhtree import BVHTree
bpy.ops.wm.open_mainfile(filepath=os.path.expanduser("~/Pictures/035_preview/vault/vault_inspect_copy.blend"))
sc = bpy.context.scene; objs = bpy.data.objects
CLIPS = ["Idle", "Walk", "Steal_Grab", "Normal_Repossess", "Event_MarketCrash", "Event_VaultLock", "Event_HostileTakeover", "Event_BankruptNova"]
JOINTS = ["Root", "Waist", "Neck", "LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow", "RightWrist", "LeftHip", "LeftKnee", "LeftAnkle", "RightHip", "RightKnee", "RightAnkle"]
rest = {o.name: (o.rotation_quaternion.copy(), o.location.copy(), o.scale.copy()) for o in objs}
def setclip(c):
    for o in objs:  # un-keyed joints must return to rest (Blender keeps the last evaluated value otherwise)
        o.rotation_quaternion, o.location, o.scale = rest[o.name][0].copy(), rest[o.name][1].copy(), rest[o.name][2].copy()
    for o in objs:
        ad = o.animation_data
        if not ad: continue
        ad.action = None
        for t in ad.nla_tracks: t.mute = t.name != c
def bodymesh(name): return objs.get(name)
BODY = ["Head", "WizardTopHat", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", "LedgerScepter"]
PAIRS = [("LeftHand", "UpperTorso"), ("RightHand", "UpperTorso"), ("LeftHand", "Head"), ("RightHand", "Head"), ("LeftHand", "LowerTorso"), ("RightHand", "LowerTorso"), ("LeftLowerArm", "UpperTorso"), ("RightLowerArm", "UpperTorso"),
         ("LeftLowerArm", "LowerTorso"), ("RightLowerArm", "LowerTorso"), ("LeftUpperArm", "UpperTorso"), ("RightUpperArm", "UpperTorso"), ("LeftFoot", "RightFoot"), ("LeftLowerLeg", "RightLowerLeg"), ("LeftUpperLeg", "RightUpperLeg"),
         ("LeftFoot", "RightLowerLeg"), ("RightFoot", "LeftLowerLeg"), ("LedgerScepter", "UpperTorso"), ("LedgerScepter", "Head"), ("LedgerScepter", "RightLowerLeg"), ("LedgerScepter", "LeftLowerLeg"), ("WizardTopHat", "UpperTorso"), ("LeftHand", "LeftUpperLeg"), ("RightHand", "RightUpperLeg"), ("LeftLowerArm", "LeftUpperLeg"), ("RightLowerArm", "RightUpperLeg")]
def bvhs(dg):
    out = {}
    for n in BODY:
        o = objs[n]; bm = bmesh.new(); bm.from_object(o, dg); bm.transform(o.matrix_world)
        bmesh.ops.triangulate(bm, faces=bm.faces[:]); out[n] = (BVHTree.FromBMesh(bm), bm)
    return out
def measure(frame):
    sc.frame_set(frame); dg = bpy.context.evaluated_depsgraph_get()
    rot = {}
    for j in JOINTS:
        o = objs[j]; qr, lr, sr = rest[j]
        q = qr.inverted() @ o.rotation_quaternion; e = q.to_euler("XYZ")
        rot[j] = [math.degrees(e.x), math.degrees(e.y), math.degrees(e.z), o.location.z - lr.z, o.location.x - lr.x, o.location.y - lr.y]
    feet = {}
    for f in ("LeftFoot", "RightFoot"):
        o = objs[f]; m = o.evaluated_get(dg).to_mesh(); mw = o.matrix_world
        feet[f] = min((mw @ v.co).z for v in m.vertices); o.evaluated_get(dg).to_mesh_clear()
    B = bvhs(dg); ov = {}
    for a, b in PAIRS: ov[(a, b)] = len(B[a][0].overlap(B[b][0]))
    for t in B.values(): t[1].free()
    root = objs["HumanoidRootPart"].matrix_world.translation.copy()
    return rot, feet, ov, root
report = {}
# baseline at rest (no animation)
for o in objs:
    if o.animation_data:
        o.animation_data.action = None
        for t in o.animation_data.nla_tracks: t.mute = True
for o in objs: o.rotation_quaternion, o.location, o.scale = rest[o.name][0].copy(), rest[o.name][1].copy(), rest[o.name][2].copy()
r0, f0, ov0, root0 = measure(1)
print("REST feet z", {k: round(v, 3) for k, v in f0.items()}, "overlaps at rest", {"%s|%s" % k: v for k, v in ov0.items() if v})
for c in CLIPS:
    setclip(c)
    end = int(max(s.frame_end for o in objs if o.animation_data for t in o.animation_data.nla_tracks if t.name == c for s in t.strips))
    frames = list(range(1, end + 1, 2))
    pk = {j: [0, 0, 0, 0, 0, 0] for j in JOINTS}; fmin = {"LeftFoot": 9, "RightFoot": 9}; fmax = {"LeftFoot": -9, "RightFoot": -9}; ovmax = {k: 0 for k in PAIRS}; rootr = [[9, -9], [9, -9], [9, -9]]
    ovf = {k: 0 for k in PAIRS}
    for f in frames:
        r, ft, ov, root = measure(f)
        for j in JOINTS:
            for i in range(6): pk[j][i] = max(pk[j][i], abs(r[j][i]))
        for k in ft: fmin[k] = min(fmin[k], ft[k]); fmax[k] = max(fmax[k], ft[k])
        for k in PAIRS:
            ovmax[k] = max(ovmax[k], ov[k]); ovf[k] += 1 if ov[k] > ov0[k] + 4 else 0
        for i in range(3): rootr[i] = [min(rootr[i][0], root[i]), max(rootr[i][1], root[i])]
    n = len(frames)
    print("\nCLIP %s frames 1..%d (%d samples)" % (c, end, n))
    print("  peak joint rotation from rest (deg, XYZ euler) / translation (m):")
    print("   " + " ".join("%s:%s" % (j, "/".join("%.0f" % v for v in pk[j][:3])) for j in JOINTS if max(pk[j][:3]) > 1))
    print("  root(HRP) world range x %.3f..%.3f y %.3f..%.3f z %.3f..%.3f ; Root joint z-shift peak %.3f" % (rootr[0][0], rootr[0][1], rootr[1][0], rootr[1][1], rootr[2][0], rootr[2][1], pk["Root"][3]))
    print("  feet min z: L %.3f..%.3f R %.3f..%.3f (rest L %.3f R %.3f; negative = sinks through ground, >0.05 = off ground)" % (fmin["LeftFoot"], fmax["LeftFoot"], fmin["RightFoot"], fmax["RightFoot"], f0["LeftFoot"], f0["RightFoot"]))
    flag = [("%s|%s" % k, ovmax[k], ov0[k], ovf[k]) for k in PAIRS if ovmax[k] > ov0[k] + 4]
    print("  mesh intersections above rest baseline (pair, max tri-pairs, rest, frames affected):", flag if flag else "none")
    report[c] = dict(frames=end, pk={j: [round(v, 1) for v in pk[j]] for j in JOINTS}, feet=[fmin, fmax], inter=[list(f) for f in flag])
json.dump(report, open(os.path.expanduser("~/Pictures/035_preview/vault/anim_report.json"), "w"), indent=1, default=str)
