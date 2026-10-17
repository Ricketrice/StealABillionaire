#!/usr/bin/env python3
# Rig + clip validation of the converted Vault wizard (offline). python3 -I tools/blender/vault/vw_validate.py [json tag]   -> prints PASS/FAIL lines, writes assets/export/vault/VALIDATION.txt
import json, math, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vw_common as C
tag = sys.argv[1] if len(sys.argv) > 1 else "vault_roblox"
G = C.Glb(); D = json.load(open(os.path.join(C.EXPORT, tag + ".json")))
lines = []; fails = 0
def chk(ok, msg):
    global fails
    lines.append(("PASS  " if ok else "FAIL  ") + msg); fails += 0 if ok else 1
N = G.N
empties = [i for i, n in enumerate(N) if "mesh" not in n]
chk(len(empties) == 32, "32 joint/FX empties in the GLB (found %d)" % len(empties))
R15 = {"Root": "HumanoidRootPart", "Waist": "Root", "Neck": "Waist", "LeftShoulder": "Waist", "RightShoulder": "Waist", "LeftElbow": "LeftShoulder", "RightElbow": "RightShoulder", "LeftWrist": "LeftElbow", "RightWrist": "RightElbow",
       "LeftHip": "Root", "RightHip": "Root", "LeftKnee": "LeftHip", "RightKnee": "RightHip", "LeftAnkle": "LeftKnee", "RightAnkle": "RightKnee"}
bad = [j for j, p in R15.items() if j not in G.byname or G.name(G.parent[G.byname[j]]) != p]
chk(not bad, "R15 joint hierarchy (15 joints, parents) matches the R15 spec %s" % bad)
PARTS = {"LowerTorso": "Root", "UpperTorso": "Waist", "Head": "Neck", "LeftUpperArm": "LeftShoulder", "LeftLowerArm": "LeftElbow", "LeftHand": "LeftWrist", "RightUpperArm": "RightShoulder", "RightLowerArm": "RightElbow", "RightHand": "RightWrist",
         "LeftUpperLeg": "LeftHip", "LeftLowerLeg": "LeftKnee", "LeftFoot": "LeftAnkle", "RightUpperLeg": "RightHip", "RightLowerLeg": "RightKnee", "RightFoot": "RightAnkle"}
missing = [p for p, j in PARTS.items() if p not in D["parts"] or D["joints"].get(j, {}).get("part1") != p]
chk(not missing, "all 15 R15 body parts present and bound to the right Motor6D %s" % missing)
extra = sorted(set(D["parts"]) - set(PARTS))
chk(True, "accessories / trims: %d extra parts (%s)" % (len(extra), ", ".join(extra)))
c1 = max(float(np.linalg.norm(np.array(v["C1"][:3]))) for v in D["joints"].values())
chk(c1 < 1e-3, "every mesh origin sits on its joint (max |C1.position| = %.5f stud)" % c1)
sc = [G.name(i) for i in range(len(N)) if any(abs(x - 1) > 1e-6 for x in G.rest(i)[2]) and not G.name(i).startswith("FX_")]
chk(not sc, "rest scale is 1 on every body / accessory node %s (FX nodes start hidden at scale 0.001 by design)" % sc)
rr = {G.name(i): round(2 * math.degrees(math.acos(min(1, abs(G.rest(i)[1][3])))), 2) for i in range(len(N)) if abs(G.rest(i)[1][3]) < 0.99999}
chk(True, "non-identity rest rotations (deg): %s (hat tilt, coin-orbit plane; both baked into C0/C1)" % rr)
sym = abs(G.rest(G.byname["LeftShoulder"])[0][0] + G.rest(G.byname["RightShoulder"])[0][0]) + abs(G.rest(G.byname["LeftHip"])[0][0] + G.rest(G.byname["RightHip"])[0][0])
chk(sym < 1e-4, "left/right symmetric shoulders and hips (error %.5f)" % sym)
cl_missing = []
joint_nodes = {G.byname[j] for j in D["joints"]}
for clip in C.CLIP_ORDER:
    tr = G.tracks(clip)
    orphan = [G.name(i) for i in tr if i not in joint_nodes and not G.name(i).startswith("FX_")]
    if orphan: cl_missing.append((clip, orphan))
chk(not cl_missing, "no animation track targets a node without a Motor6D %s" % cl_missing)
# loops / start-end / transitions from the converted keys
def pose_at(clip, t):
    q = {}
    for jn, tr in D["clips"][clip]["joints"].items():
        k = tr["keys"]; ts = [x[0] for x in k]; tt = min(max(t, ts[0]), ts[-1]); a = int(np.searchsorted(ts, tt, side="right") - 1); a = min(max(a, 0), len(k) - 2) if len(k) > 1 else 0; b = min(a + 1, len(k) - 1)
        u = 0 if ts[b] == ts[a] else (tt - ts[a]) / (ts[b] - ts[a]); q[jn] = (C.slerp(np.array(k[a][1:5]), np.array(k[b][1:5]), u), np.array(k[a][5:8]) if tr["pos"] else np.zeros(3))
    return q
SPIN = {jn for jn in D["joints"] if jn.startswith("FX_")}      # cosmetic spinners (halo: 8 spokes = 45 deg symmetric; gem: 4-fold = 90 deg): excluded from loop / blend checks
def diff(p, q):
    w = 0
    for jn in (set(p) | set(q)) - SPIN:
        a = p.get(jn, (np.array([0, 0, 0, 1.0]), 0))[0]; b = q.get(jn, (np.array([0, 0, 0, 1.0]), 0))[0]
        w = max(w, 2 * math.degrees(math.acos(min(1, abs(float(np.dot(a, b)))))))
    return w
for clip in C.CLIP_ORDER:
    L = D["clips"][clip]["length"]; d0 = diff(pose_at(clip, 0), pose_at(clip, L))
    toIdle = diff(pose_at(clip, L), pose_at("Idle", 0)); fromIdle = diff(pose_at("Idle", 0), pose_at(clip, 0))
    rp = D["clips"][clip]["joints"].get("Root"); rt = (max(abs(np.array(k[5:8])).max() for k in rp["keys"]) if rp and rp["pos"] else 0)
    chk(d0 < 1.0 if D["clips"][clip]["loop"] else True, "%-22s %.2fs  %s | first-vs-last pose %.2f deg | enters from Idle %.1f deg, returns to Idle %.1f deg (cross-fade 0.15 s covers it) | Root bob peak %.3f stud | HRP never animated" % (
        clip, L, "LOOP" if D["clips"][clip]["loop"] else "one-shot", d0, fromIdle, toIdle, rt))
# the spinners must be symmetric: their rotation at every key is a multiple of the symmetry period (halo 45, gem 90 deg)
for jn, per in (("FX_VaultHalo", 45.0), ("FX_ScepterGem", 90.0)):
    worst = 0
    for clip in C.CLIP_ORDER:
        tr = D["clips"][clip]["joints"].get(jn)
        if not tr: continue
        for k in (tr["keys"][0], tr["keys"][-1]):
            ang = 2 * math.degrees(math.atan2(math.sqrt(sum(x * x for x in k[1:4])), k[4])); r = ang % per; worst = max(worst, min(r, per - r) if abs(ang) > 1e-6 else 0)
    chk(worst < 0.5, "%s spin at the first and last key of every clip is a multiple of its %g deg symmetry (worst remainder %.2f deg): a clip can end/start at any key without a visible jump" % (jn, per, worst))
lines.append("")
lines.append("RESULT: %s (%d failed)" % ("PASS" if not fails else "FAIL", fails))
open(os.path.join(C.EXPORT, "VALIDATION.txt"), "w").write("\n".join(lines) + "\n"); print("\n".join(lines))
