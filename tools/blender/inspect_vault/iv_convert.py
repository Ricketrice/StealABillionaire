# Prototype GLB -> Roblox Motor6D converter (pure Python, no Blender, no Studio). Emits rig + animation data and VERIFIES the Motor6D algebra offline:
#   Part1 = Part0 * C0 * Transform * C1^-1   vs   direct glTF forward kinematics, for every clip, every 1/24 s.   (Not an in-Roblox test.)
import json, struct, os, math, sys
import numpy as np
S_STUDS = float(os.environ.get("VAULT_STUDS_PER_UNIT", "3.0"))
p = os.path.expanduser("~/Pictures/035_preview/concept/Vault.glb")
d = open(p, "rb").read(); cl, _ = struct.unpack("<II", d[12:20]); j = json.loads(d[20:20 + cl]); BIN = 20 + cl + 8; N = j["nodes"]
def acc(i):
    a = j["accessors"][i]; bv = j["bufferViews"][a["bufferView"]]; off = BIN + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    c = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[a["type"]]; n = a["count"] * c
    v = struct.unpack_from("<%df" % n, d, off); return np.array(v, dtype=np.float64).reshape(a["count"], c)
parent = {}
for i, n in enumerate(N):
    for c in n.get("children", []): parent[c] = i
byname = {n.get("name"): i for i, n in enumerate(N)}
def q2m(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)], [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)], [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
def m2q(R):
    t = np.trace(R)
    if t > 0: s = math.sqrt(t + 1) * 2; return np.array([(R[2, 1] - R[1, 2]) / s, (R[0, 2] - R[2, 0]) / s, (R[1, 0] - R[0, 1]) / s, s / 4])
    i = int(np.argmax(np.diag(R))); jj, k = (i + 1) % 3, (i + 2) % 3
    s = math.sqrt(R[i, i] - R[jj, jj] - R[k, k] + 1) * 2; q = np.zeros(4); q[i] = s / 4; q[3] = (R[k, jj] - R[jj, k]) / s; q[jj] = (R[jj, i] + R[i, jj]) / s; q[k] = (R[k, i] + R[i, k]) / s; return q
def trs(t, q, s):
    M = np.eye(4); M[:3, :3] = q2m(q) @ np.diag(s); M[:3, 3] = t; return M
def slerp(a, b, u):
    if np.dot(a, b) < 0: b = -b
    dp = min(1.0, np.dot(a, b))
    if dp > 0.9995: r = a + u * (b - a); return r / np.linalg.norm(r)
    th = math.acos(dp); return (math.sin((1 - u) * th) * a + math.sin(u * th) * b) / math.sin(th)
def rest_trs(i):
    n = N[i]; return np.array(n.get("translation", [0, 0, 0]), float), np.array(n.get("rotation", [0, 0, 0, 1]), float), np.array(n.get("scale", [1, 1, 1]), float)
CLIPS = {a["name"]: a for a in j["animations"]}
def sample_node(clip, i, t):
    tr, q, s = rest_trs(i)
    for ch in CLIPS[clip]["channels"]:
        if ch["target"]["node"] != i: continue
        smp = CLIPS[clip]["samplers"][ch["sampler"]]; T = acc(smp["input"])[:, 0]; V = acc(smp["output"]); path = ch["target"]["path"]
        tt = min(max(t, T[0]), T[-1]); k = int(np.searchsorted(T, tt, side="right") - 1); k = min(k, len(T) - 2); u = 0 if T[k + 1] == T[k] else (tt - T[k]) / (T[k + 1] - T[k])
        if path == "rotation": q = slerp(V[k], V[k + 1], u)
        elif path == "translation": tr = V[k] + u * (V[k + 1] - V[k])
        else: s = V[k] + u * (V[k + 1] - V[k])
    return tr, q, s
def world_g(i, clip, t, cache):
    if i in cache: return cache[i]
    tr, q, s = sample_node(clip, i, t) if clip else rest_trs(i)
    M = trs(tr, q, s); w = (world_g(parent[i], clip, t, cache) @ M) if i in parent else M; cache[i] = w; return w
# --- R15 joint table: joint node -> (Part0, Part1) (part names = mesh node names; HumanoidRootPart is an empty)
JT = {"Root": ("HumanoidRootPart", "LowerTorso"), "Waist": ("LowerTorso", "UpperTorso"), "Neck": ("UpperTorso", "Head")}
for sd in ("Left", "Right"):
    JT.update({sd + "Shoulder": ("UpperTorso", sd + "UpperArm"), sd + "Elbow": (sd + "UpperArm", sd + "LowerArm"), sd + "Wrist": (sd + "LowerArm", sd + "Hand"),
               sd + "Hip": ("LowerTorso", sd + "UpperLeg"), sd + "Knee": (sd + "UpperLeg", sd + "LowerLeg"), sd + "Ankle": (sd + "LowerLeg", sd + "Foot")})
CV = np.diag([-1.0, 1, -1, 1])           # glTF (front +Z, right -X) -> Roblox (front -Z, right +X): 180 deg about Y
SC = np.diag([S_STUDS, S_STUDS, S_STUDS, 1.0])
def toR(M):                               # conjugate a world transform into Roblox space (rotation part of CV is its own inverse), positions scaled to studs
    R = CV @ M @ CV; R[:3, 3] *= S_STUDS; R[:3, :3] = R[:3, :3] / np.linalg.norm(R[:3, 0]) if abs(np.linalg.norm(R[:3, 0]) - 1) > 1e-6 else R[:3, :3]; return R
cache0 = {}
rw = lambda name: toR(world_g(byname[name], None, 0, cache0))
rig = {}
for jn, (a, b) in JT.items():
    Jw = rw(jn); P0 = rw(a); P1 = rw(b)
    rig[jn] = dict(part0=a, part1=b, C0=(np.linalg.inv(P0) @ Jw), C1=(np.linalg.inv(P1) @ Jw), Jrest_local=None)
def local_trs_R(jn, clip, t):
    i = byname[jn]; tr, q, s = sample_node(clip, i, t) if clip else rest_trs(i); M = trs(tr, q, s)
    R = CV @ M @ CV; R[:3, 3] *= S_STUDS; return R
# --- verification: Motor6D FK vs glTF FK
worst_p = worst_r = 0; nsamp = 0
for clip, a in CLIPS.items():
    dur = max(j["accessors"][s["input"]]["max"][0] for s in a["samplers"])
    for f in range(int(dur * 24) + 1):
        t = f / 24; cache = {}
        # glTF truth in Roblox space
        truth = {nm: toR(world_g(byname[nm], clip, t, cache)) for nm in ["HumanoidRootPart"] + [v[1] for v in JT.values()]}
        # Motor6D chain
        part = {"HumanoidRootPart": truth["HumanoidRootPart"]}
        for jn in ["Root", "Waist", "Neck", "LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow", "RightWrist", "LeftHip", "LeftKnee", "LeftAnkle", "RightHip", "RightKnee", "RightAnkle"]:
            r = rig[jn]; Lrest = local_trs_R(jn, None, 0); Lanim = local_trs_R(jn, clip, t); Tr = np.linalg.inv(Lrest) @ Lanim
            part[r["part1"]] = part[r["part0"]] @ r["C0"] @ Tr @ np.linalg.inv(r["C1"])
        for nm, M in part.items():
            dp = np.linalg.norm(M[:3, 3] - truth[nm][:3, 3]); dr = np.abs(M[:3, :3] - truth[nm][:3, :3]).max()
            worst_p, worst_r = max(worst_p, dp), max(worst_r, dr)
        nsamp += 1
print("VERIFY Motor6D algebra vs glTF FK: %d (clip, frame) samples x 16 parts: worst position error %.6f studs, worst rotation-matrix error %.2e" % (nsamp, worst_p, worst_r))
# --- emit data
def cf(M): return [round(float(x), 5) for x in list(M[:3, 3]) + list(M[:3, :3].reshape(-1))]
out = dict(studs_per_unit=S_STUDS, joints={jn: dict(Part0=r["part0"], Part1=r["part1"], C0=cf(r["C0"]), C1=cf(r["C1"])) for jn, r in rig.items()}, clips={})
nk = 0
for clip, a in CLIPS.items():
    dur = max(j["accessors"][s["input"]]["max"][0] for s in a["samplers"]); jc = {}
    for jn in rig:
        i = byname[jn]; chs = [c for c in a["channels"] if c["target"]["node"] == i]
        if not chs: continue
        times = sorted({round(float(t), 5) for c in chs for t in acc(a["samplers"][c["sampler"]]["input"])[:, 0]})
        Lrest = local_trs_R(jn, None, 0)
        jc[jn] = [[t] + cf(np.linalg.inv(Lrest) @ local_trs_R(jn, clip, t)) for t in times]; nk += len(times)
    out["clips"][clip] = dict(length=dur, joints=jc)
os.makedirs(os.path.expanduser("~/Pictures/035_preview/vault/convert"), exist_ok=True)
json.dump(out, open(os.path.expanduser("~/Pictures/035_preview/vault/convert/vault_roblox_motor6d.json"), "w"))
print("EMITTED joints", len(rig), "clips", len(out["clips"]), "keyframes (joint-keys)", nk, "json bytes", os.path.getsize(os.path.expanduser("~/Pictures/035_preview/vault/convert/vault_roblox_motor6d.json")))
print("rest C0 samples (studs, Roblox space):", {k: cf(rig[k]["C0"])[:3] for k in ("Root", "Waist", "Neck", "LeftShoulder", "RightHip")})
print("C1 is identity-like (mesh origin sits on the joint):", all(np.allclose(r["C1"][:3, 3], 0, atol=1e-6) for r in rig.values()), "; C1 rotations non-identity:", [k for k, r in rig.items() if not np.allclose(r["C1"][:3, :3], np.eye(3), atol=1e-4)])
print("rest world heights (studs): HRP %.2f, Waist %.2f, Neck %.2f, hat top ~%.2f; hips %.2f; ankles %.2f" % (rw("HumanoidRootPart")[1, 3], rw("Waist")[1, 3], rw("Neck")[1, 3], rw("WizardTopHat")[1, 3] + 0.5 * S_STUDS, rw("LeftHip")[1, 3], rw("LeftAnkle")[1, 3]))
# --- independent cross-check against Blender's own animation evaluation (needs iv_blender_pose_dump.py output)
dumpf = os.path.expanduser("~/Pictures/035_preview/vault/convert/blender_pose_dump.json")
if os.path.exists(dumpf):
    dump = json.load(open(dumpf)); worst = 0
    for key, pts in dump.items():
        clip, f = key.split("@"); t = (int(f) - 1) / 24; cache = {}
        for nm, bp in pts.items():
            g = world_g(byname[nm], clip, t, cache)[:3, 3]            # glTF coords
            bl = np.array([g[0], -g[2], g[1]])                          # glTF -> Blender (x, -z, y)
            worst = max(worst, np.linalg.norm(bl - np.array(bp)))
    print("CROSS-CHECK vs Blender evaluated poses: %d poses x %d meshes, worst world-position difference %.5f units (= %.4f studs)" % (len(dump), len(next(iter(dump.values()))), worst, worst * S_STUDS))
