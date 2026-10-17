# Vault wizard, step 2: measure + repair clipping and foot sinking in the 8 clips (data-level, on the decimated meshes).
# Usage: flatpak run org.blender.Blender -b -P $PWD/tools/blender/vault/vw_anim_fix.py -- [--tol 0.012] [--max 40]
# Method (all in glTF space, units = metres of the authored model, 1 unit = 2.5 studs):
#   * every 1/24 s: forward kinematics from the GLB tracks, meshes -> world, one BVH of the "obstacles" (torso, head, hat, legs);
#   * penetration depth = how far the arm / hand / scepter vertices sit inside the obstacles (find_nearest + face normal), minus the same measure at the REST pose (the pauldrons overlap by design);
#   * the shoulder is swung OUTWARD (rotation about arm x outward axis, about the shoulder pivot) by the smallest angle that brings every moving part under rest + tol;
#   * that angle track is dilated + smoothed in time (wrap-around for loops) and re-verified; the feet are lifted with the Root joint so the lowest sole point never sinks below the ground by more than tol.
# Output: WORK/anim_fixed.json (dense per-1/24 s quaternions for corrected joints), WORK/anim_fix_report.json + printed table (before / after).
import json
import math
import os
import sys

import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vw_common as C  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
TOL = float(argv[argv.index("--tol") + 1]) if "--tol" in argv else 0.012       # 1.2 cm of the authored model = 0.03 stud
FOOT_TOL = float(argv[argv.index("--foot") + 1]) if "--foot" in argv else 0.010
MAXDEG = float(argv[argv.index("--max") + 1]) if "--max" in argv else 40.0
STEP = 2.0
G = C.Glb()
z = np.load(os.path.join(C.WORK, "vault_meshes.npz"))
V = {str(n): z[str(n) + "__v"] for n in z["names"]}
F = {str(n): z[str(n) + "__f"] for n in z["names"]}
NODE = {n: G.byname[n] for n in V}
OBST = [p for p in C.CFG["obstacles"] if p in V]
ARM = {"Left": ["LeftUpperArm", "LeftLowerArm", "LeftHand"], "Right": ["RightUpperArm", "RightLowerArm", "RightHand"] + list(C.CFG["right_extra"])}
ARM = {k: [p for p in v if p in V] for k, v in ARM.items()}


def samples(part):
    """Surface samples in node-local space: vertices, edge midpoints, centroids of every triangle."""
    v, f = V[part], F[part]
    a, b, c = v[f[:, 0]], v[f[:, 1]], v[f[:, 2]]
    return np.concatenate([v, (a + b) / 2, (b + c) / 2, (c + a) / 2, (a + b + c) / 3])


SAMP = {p: samples(p) for s_ in ARM.values() for p in s_ if not p.endswith("_Neon")}
FEET = ["LeftFoot", "RightFoot"]
SCEPTER = [p for p in C.CFG["weapon"] if p in V]
SHOULDER = {"Left": "LeftShoulder", "Right": "RightShoulder"}
WAIST_PARENT = "Waist"
LOOPS = set(C.CFG["loops"])


class Pose:
    """Forward kinematics with optional per-node overrides {node index: (translation or None, quaternion or None)}."""

    def __init__(self, tracks, t, ov=None):
        self.tracks, self.t, self.ov, self.cache = tracks, t, ov or {}, {}

    def local(self, i):
        tr, q, s = C.sample_node(G, self.tracks, i, self.t)
        o = self.ov.get(i)
        if o:
            if o[0] is not None:
                tr = o[0]
            if o[1] is not None:
                q = o[1]
        return tr, q, np.ones(3)

    def world(self, i):
        return C.world_of(G, i, self.local, self.cache)


def wverts(pose, part):
    W = pose.world(NODE[part])
    return V[part] @ W[:3, :3].T + W[:3, 3]


class Obstacles:
    """One BVH + AABB per obstacle part. A point is INSIDE a part when 2 of 3 fixed-direction rays cross its surface an odd number of times; depth = distance to that part's surface."""
    DIRS = [np.array(d) / np.linalg.norm(d) for d in ((0.5773, 0.5774, 0.5771), (-0.3, 0.9, 0.31), (0.2, -0.35, 0.91))]

    def __init__(self, pose, parts):
        self.items = []
        for p in parts:
            w = wverts(pose, p)
            bv = BVHTree.FromPolygons([tuple(x) for x in w], [tuple(int(k) for k in f) for f in F[p]])
            self.items.append((p, w.min(0) - 1e-6, w.max(0) + 1e-6, bv))

    @staticmethod
    def crossings(bv, o, d):
        n, org = 0, Vector(o)
        dv = Vector(d)
        for _ in range(12):
            hit = bv.ray_cast(org, dv)
            if hit[0] is None:
                break
            n += 1
            org = hit[0] + dv * 1e-5
        return n

    def depth(self, pts):
        mx = 0.0
        for name, lo, hi, bv in self.items:
            m = np.all((pts >= lo) & (pts <= hi), axis=1)
            for p in pts[m]:
                votes = sum(1 for d in self.DIRS if self.crossings(bv, p, d) % 2 == 1)
                if votes >= 2:
                    loc, nor, idx, dist = bv.find_nearest(Vector(p))
                    if dist is not None and dist > mx:
                        mx = dist
        return mx


def make_bvh(pose, parts):
    return Obstacles(pose, parts)


def depth_of(bvh, pts):
    return bvh.depth(pts)


def swverts(pose, part):
    W = pose.world(NODE[part])
    return SAMP[part] @ W[:3, :3].T + W[:3, 3]


def arm_depths(pose, side, bvh=None):
    bvh = bvh or make_bvh(pose, OBST)
    return {p: depth_of(bvh, swverts(pose, p)) for p in ARM[side] if p in SAMP}


def foot_min(pose):
    return min(float(wverts(pose, f)[:, 1].min()) for f in FEET)


def scepter_min(pose):
    return min(float(wverts(pose, f)[:, 1].min()) for f in SCEPTER)


# ---- baselines at rest
rest_pose = Pose({}, 0.0)
BASE = {s: arm_depths(rest_pose, s) for s in ARM}
GROUND = foot_min(rest_pose)
SC_REST = scepter_min(rest_pose)
print("REST: foot ground %.4f, scepter tip %.4f" % (GROUND, SC_REST))
print("REST arm penetration (cm):", {s: {p: round(d * 100, 1) for p, d in b.items() if d > 0.0005} for s, b in BASE.items()})


def smooth(th, loop, dil=2, sigma=1.3):
    th = np.asarray(th, float)
    n = len(th)
    pad = 8
    ext = np.concatenate([th[-pad - 1:-1], th, th[1:pad + 1]]) if loop and n > pad + 2 else np.concatenate([np.full(pad, th[0]), th, np.full(pad, th[-1])])
    d = np.array([ext[max(0, i - dil):i + dil + 1].max() for i in range(len(ext))])
    k = np.exp(-0.5 * (np.arange(-4, 5) / sigma) ** 2)
    k /= k.sum()
    s = np.convolve(np.pad(d, 4, mode="edge"), k, mode="valid")
    return s[pad:pad + n]



ELBOW = {"Left": "LeftElbow", "Right": "RightElbow"}
WRIST = {"Left": "LeftWrist", "Right": "RightWrist"}
TOLP = {"UpperArm": 0.02, "LowerArm": 0.012, "Hand": 0.012, **{w: 0.02 for w in C.CFG["right_extra"]}}
DOFW = np.array([1.0, 1.5, 1.2, 1.0])      # deviation cost per degree: abduction, flexion, elbow, wrist
STEPS = (6.0, 3.0, 1.5)
LIM = np.array([MAXDEG, MAXDEG, 45.0, 45.0])


def tol_of(part):
    return next(v for k, v in TOLP.items() if k in part)


def arm_overrides(pose0, side, dof):
    """Overrides for one arm from dof = [abduction (>=0, outward), flexion about the torso side axis, extra elbow flex (local X), extra wrist flex (local X)] in degrees."""
    ov = {}
    sh = G.byname[SHOULDER[side]]
    a, f, e, w = dof
    if abs(a) > 1e-6 or abs(f) > 1e-6:
        Ws, We = pose0.world(sh), pose0.world(G.byname[ELBOW[side]])
        d = We[:3, 3] - Ws[:3, 3]
        d /= np.linalg.norm(d)
        par = pose0.world(G.parent[sh])
        sign = 1.0 if G.rest(sh)[0][0] > 0 else -1.0
        xout = par[:3, 0] * sign
        xt = par[:3, 0] / np.linalg.norm(par[:3, 0])
        Pq = C.m2q(par[:3, :3] / np.linalg.norm(par[:3, 0]))
        q0 = pose0.local(sh)[1]
        D = np.array([0, 0, 0, 1.0])
        n = np.cross(d, xout)
        if abs(a) > 1e-6 and np.linalg.norm(n) > 1e-3:
            D = C.qmul(C.axis_angle_q(n, math.radians(a)), D)
        if abs(f) > 1e-6:
            D = C.qmul(C.axis_angle_q(xt, math.radians(f)), D)
        ov[sh] = (None, C.qmul(C.qmul(C.qmul(C.qconj(Pq), D), Pq), q0))
    if abs(e) > 1e-6:
        el = G.byname[ELBOW[side]]
        ov[el] = (None, C.qmul(pose0.local(el)[1], C.axis_angle_q((1, 0, 0), math.radians(e))))
    if abs(w) > 1e-6:
        wr = G.byname[WRIST[side]]
        ov[wr] = (None, C.qmul(pose0.local(wr)[1], C.axis_angle_q((1, 0, 0), math.radians(w))))
    return ov


def violation(pose, side, bvh):
    dd = arm_depths(pose, side, bvh)
    return sum(max(0.0, d - BASE[side][p] - tol_of(p)) for p, d in dd.items()), dd


def cost(pose0, tracks, t, side, dof, bvh):
    pose = Pose(tracks, t, arm_overrides(pose0, side, dof))
    v, dd = violation(pose, side, bvh)
    return v * 1000.0 + 0.02 * float(np.sum(np.abs(dof) * DOFW)), v, dd


def optimise(pose0, tracks, t, side, start, bvh):
    """Coordinate descent from `start` (warm start = previous frame's offsets)."""
    dof = np.array(start, float)
    best, v, _ = cost(pose0, tracks, t, side, dof, bvh)
    for step in STEPS:
        for _ in range(6):
            improved = False
            for i in range(4):
                for sg in (+1, -1):
                    trial = dof.copy()
                    trial[i] += sg * step
                    if i == 0 and trial[0] < 0:
                        trial[0] = 0.0
                    if abs(trial[i]) > LIM[i]:
                        continue
                    c, vv, _ = cost(pose0, tracks, t, side, trial, bvh)
                    if c < best - 1e-9:
                        best, dof, v, improved = c, trial, vv, True
            if not improved:
                break
    return dof, v


def times_for(clip):
    d = G.duration(clip)
    n = int(math.floor(d * C.FPS + 1e-6))
    ts = [k / C.FPS for k in range(n + 1)]
    if abs(ts[-1] - d) > 1e-6:
        ts.append(d)
    return ts


def smooth_signed(x, sigma=1.0):
    x = np.asarray(x, float)
    if len(x) < 3:
        return x
    k = np.exp(-0.5 * (np.arange(-3, 4) / sigma) ** 2)
    k /= k.sum()
    return np.convolve(np.pad(x, 3, mode="edge"), k, mode="valid")


report, fixed = {}, {}
SIDES = ("Left", "Right")
NODES_OF = lambda s: [SHOULDER[s], ELBOW[s], WRIST[s]]  # noqa: E731
only = argv[argv.index("--clip") + 1] if "--clip" in argv else None
for clip in C.CLIP_ORDER:
    if only and clip != only:
        continue
    tracks = G.tracks(clip)
    ts = times_for(clip)
    N = len(ts)
    loop = clip in LOOPS
    before = dict(arm={s: {p: 0.0 for p in ARM[s]} for s in ARM}, foot=0.0, scepter=0.0, viol=0)
    dofs = {s: np.zeros((N, 4)) for s in SIDES}
    poses0 = [Pose(tracks, t) for t in ts]
    bvhs = [make_bvh(pz, OBST) for pz in poses0]
    # ---- BEFORE + first optimisation pass (warm start from the previous frame)
    for s in SIDES:
        prev = np.zeros(4)
        for k, t in enumerate(ts):
            v0, dd = violation(poses0[k], s, bvhs[k])
            for p, d in dd.items():
                before["arm"][s][p] = max(before["arm"][s][p], d - BASE[s][p])
            before["viol"] += 1 if v0 > 0 else 0
            if v0 > 0 or np.abs(prev).max() > 0.5:
                prev, _ = optimise(poses0[k], tracks, t, s, prev, bvhs[k])
            else:
                prev = np.zeros(4)
            dofs[s][k] = prev
    for k, t in enumerate(ts):
        before["foot"] = min(before["foot"], foot_min(poses0[k]) - GROUND)
        before["scepter"] = min(before["scepter"], scepter_min(poses0[k]) - SC_REST)
    # ---- smooth, verify, re-optimise violating frames from the smoothed start (up to 3 rounds)
    for s in SIDES:
        for i in range(4):
            dofs[s][:, i] = smooth_signed(dofs[s][:, i])
        dofs[s][:, 0] = np.maximum(dofs[s][:, 0], 0.0)
    for it in range(3):
        nbad = 0
        for s in SIDES:
            for k, t in enumerate(ts):
                pose = Pose(tracks, t, arm_overrides(poses0[k], s, dofs[s][k]))
                v, _ = violation(pose, s, bvhs[k])
                if v > 0:
                    nbad += 1
                    dofs[s][k], _ = optimise(poses0[k], tracks, t, s, dofs[s][k], bvhs[k])
        if nbad == 0:
            break
    # ---- feet lift via Root translation (after the arm offsets; arms do not change foot height)
    lift = np.zeros(N)
    for k in range(N):
        lift[k] = max(0.0, (GROUND - FOOT_TOL) - foot_min(poses0[k]))
    lift = smooth(lift, loop, dil=2, sigma=1.5) if lift.max() > 0 else lift
    # ---- AFTER with the final overrides
    after = dict(arm={s: {p: 0.0 for p in ARM[s]} for s in ARM}, foot=0.0, scepter=0.0, viol=0)
    root = G.byname["Root"]
    out_q = {n: [] for s in SIDES for n in NODES_OF(s)}
    root_p = []
    for k, t in enumerate(ts):
        ov = {}
        for s in SIDES:
            ov.update(arm_overrides(poses0[k], s, dofs[s][k]))
        trr = poses0[k].local(root)[0].copy()
        trr[1] += lift[k]
        root_p.append(trr)
        if lift[k] > 1e-9:
            ov[root] = (trr, None)
        pose = Pose(tracks, t, ov)
        bvh = make_bvh(pose, OBST)
        for s in SIDES:
            v, dd = violation(pose, s, bvh)
            after["viol"] += 1 if v > 0 else 0
            for p, d in dd.items():
                after["arm"][s][p] = max(after["arm"][s][p], d - BASE[s][p])
        for s in SIDES:
            for n in NODES_OF(s):
                i = G.byname[n]
                out_q[n].append(ov[i][1] if (i in ov and ov[i][1] is not None) else poses0[k].local(i)[1])
        after["foot"] = min(after["foot"], foot_min(pose) - GROUND)
        after["scepter"] = min(after["scepter"], scepter_min(pose) - SC_REST)
    ent = {}
    for s in SIDES:
        for j, n in enumerate(NODES_OF(s)):
            used = (np.abs(dofs[s][:, 0:1]).max() > 1e-6 and j == 0) or (np.abs(dofs[s][:, 1]).max() > 1e-6 and j == 0) or (j == 1 and np.abs(dofs[s][:, 2]).max() > 1e-6) or (j == 2 and np.abs(dofs[s][:, 3]).max() > 1e-6)
            if used:
                ent[n] = dict(t=ts, q=[[float(x) for x in q] for q in out_q[n]], p=None)
    if lift.max() > 1e-9:
        ent["Root"] = dict(t=ts, q=[[float(x) for x in C.sample_node(G, tracks, root, t)[1]] for t in ts], p=[[float(x) for x in p] for p in root_p])
    fixed[clip] = ent
    mx = {s: [round(float(np.abs(dofs[s][:, i]).max()), 1) for i in range(4)] for s in SIDES}
    report[clip] = dict(before=dict(arm={s: {p: round(v * 100, 2) for p, v in d.items()} for s, d in before["arm"].items()}, foot_cm=round(before["foot"] * 100, 2), scepter_cm=round(before["scepter"] * 100, 2), frames_over_tol=before["viol"]),
                        after=dict(arm={s: {p: round(v * 100, 2) for p, v in d.items()} for s, d in after["arm"].items()}, foot_cm=round(after["foot"] * 100, 2), scepter_cm=round(after["scepter"] * 100, 2), frames_over_tol=after["viol"]),
                        max_offsets_deg=mx, max_lift_cm=round(float(lift.max()) * 100, 2), frames=N)
    b, a = report[clip]["before"], report[clip]["after"]
    wb = max(max(d.values()) for d in b["arm"].values()); wa = max(max(d.values()) for d in a["arm"].values())
    print("%-22s arm depth over rest %5.1f -> %5.1f cm, arm-frames over tol %3d -> %3d | foot sink %5.1f -> %5.1f cm | scepter tip %5.1f -> %5.1f | max offsets L %s R %s (abd,flex,elbow,wrist deg), lift %.1f cm" % (
        clip, wb, wa, b["frames_over_tol"], a["frames_over_tol"], b["foot_cm"], a["foot_cm"], b["scepter_cm"], a["scepter_cm"], mx["Left"], mx["Right"], report[clip]["max_lift_cm"]), flush=True)
tag = "_" + only if only else ""
json.dump(dict(tol=TOL, foot_tol=FOOT_TOL, clips=fixed), open(os.path.join(C.WORK, "anim_fixed%s.json" % tag), "w"))
json.dump(dict(tol=TOL, foot_tol=FOOT_TOL, max_deg=MAXDEG, ground=GROUND, rest_depth_cm={s: {p: round(d * 100, 2) for p, d in b.items()} for s, b in BASE.items()}, clips=report), open(os.path.join(C.WORK, "anim_fix_report%s.json" % tag), "w"), indent=1)
print("wrote anim_fixed%s.json (overrides:" % tag, {c: sorted(v) for c, v in fixed.items()}, ")")
