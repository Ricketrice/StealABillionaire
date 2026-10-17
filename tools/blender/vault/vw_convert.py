#!/usr/bin/env python3
# Vault wizard, step 3: GLB (+ optional corrected animation overrides) -> Roblox Motor6D rig + clip tables.
#   python3 -I tools/blender/vault/vw_convert.py [--scale 2.5] [--anim WORK/anim_fixed.npz] [--tag name]
# Writes assets/export/vault/vault_roblox.json (full data) and the Luau modules under src/ServerStorage/VaultWizardTest/RuntimeSrc/ (VaultData + Clips/*).
# VERIFIES (offline, not in Roblox): Part1 = Part0 * C0 * Transform * C1^-1 against glTF forward kinematics for every clip every 1/24 s, before and after key reduction.
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vw_common as C  # noqa: E402
import vw_convert_lib as L  # noqa: E402

argv = sys.argv[1:]
S = float(argv[argv.index("--scale") + 1]) if "--scale" in argv else 2.5
ANIM = argv[argv.index("--anim") + 1] if "--anim" in argv else None
LOOPS = {"Idle", "Walk"}
TOL_ROT_DEG, TOL_POS = 0.2, 0.004
G = C.Glb()
z = np.load(os.path.join(C.WORK, "vault_meshes.npz"))
mesh_names = [str(n) for n in z["names"]]
rig = L.build_rig(G, S, mesh_names)
tris = {n: int(len(z[n + "__f"])) for n in mesh_names}

# ---- animation overrides from the solver: {clip: {node name: {"t": [...], "q": [[x,y,z,w]...], "p": [[x,y,z]...] or None}}}
over = {}
if ANIM:
    o = json.load(open(ANIM))
    over = o["clips"]
    print("animation overrides from", ANIM, {c: sorted(v) for c, v in over.items()})


def tracks_for(clip):
    tr = G.tracks(clip)
    for nm, d in over.get(clip, {}).items():
        i = G.byname[nm]
        tr.setdefault(i, {})
        tr[i]["rotation"] = (np.array(d["t"]), np.array(d["q"]))
        if d.get("p") is not None:
            tr[i]["translation"] = (np.array(d["t"]), np.array(d["p"]))
    return tr


def clip_len(clip):
    return G.duration(clip)


def joint_times(clip, jn, tracks):
    node = rig["joints"][jn]["node"]
    if node not in tracks:
        return None
    if jn in over.get(clip, {}):
        d = clip_len(clip)
        n = int(math.floor(d * C.FPS + 1e-6))
        ts = [k / C.FPS for k in range(n + 1)]
        if abs(ts[-1] - d) > 1e-6:
            ts.append(d)
        return ts
    ts = set()
    for T, V in tracks[node].values():
        ts.update(round(float(t), 5) for t in T)
    return sorted(ts)


def quat_of(T):
    return C.m2q(T[:3, :3])


def reduce_keys(ts, qs, ps):
    """Greedy removal of keys that linear/slerp interpolation of the neighbours reproduces within the tolerances."""
    keep = list(range(len(ts)))
    changed = True
    while changed and len(keep) > 2:
        changed = False
        for idx in range(1, len(keep) - 1):
            a, k, b = keep[idx - 1], keep[idx], keep[idx + 1]
            # check every dropped/intermediate original key between a and b against interpolation a->b
            ok = True
            for m in range(a + 1, b):
                u = (ts[m] - ts[a]) / (ts[b] - ts[a])
                qi = C.slerp(qs[a], qs[b], u)
                ang = 2 * math.degrees(math.acos(min(1.0, abs(float(np.dot(qi, qs[m]))))))
                dp = np.linalg.norm((ps[a] + u * (ps[b] - ps[a])) - ps[m])
                if ang > TOL_ROT_DEG or dp > TOL_POS:
                    ok = False
                    break
            if ok:
                del keep[idx]
                changed = True
                break
    return keep


out = dict(studs_per_unit=S, hrp_frame=L.cf_list(rig["frameP"]["HumanoidRootPart"]) , order=rig["order"], joints={}, welds=[], rest_rot={}, clips={}, fx={}, parts={})
out["hrp_frame"] = [float(x) for x in rig["frameP"]["HumanoidRootPart"].reshape(-1)]
for jn, j in rig["joints"].items():
    out["joints"][jn] = dict(part0=j["part0"], part1=j["part1"], C0=L.cf_list(j["C0"]), C1=L.cf_list(j["C1"]))
for w in rig["welds"]:
    out["welds"].append(dict(part0=w["part0"], part1=w["part1"], C0=L.cf_list(w["C0"]), C1=L.cf_list(w["C1"])))
for nm in mesh_names:
    out["rest_rot"][nm] = [round(float(x), 6) for x in rig["rest_rot"][nm].reshape(-1)]
    out["parts"][nm] = dict(neon=bool(z[nm + "__neon"][0]), tris=tris[nm])

# ---- clips
worst_p = worst_r = 0.0
nkeys_raw = nkeys = 0
for clip in C.CLIP_ORDER:
    tracks = tracks_for(clip)
    dur = clip_len(clip)
    cl = dict(length=round(dur, 5), loop=clip in LOOPS, joints={}, scales={})
    for jn in rig["order"]:
        ts = joint_times(clip, jn, tracks)
        if ts is None:
            continue
        node = rig["joints"][jn]["node"]
        Ts = [L.joint_transform(G, S, node, tracks, t) for t in ts]
        qs = []
        for T, s in Ts:
            q = quat_of(T)
            if qs and np.dot(q, qs[-1]) < 0:
                q = -q
            qs.append(q)
        ps = [T[:3, 3].copy() for T, s in Ts]
        hasp = max(float(np.abs(p).max()) for p in ps) > 1e-6
        keep = reduce_keys(ts, qs, ps)
        nkeys_raw += len(ts)
        nkeys += len(keep)
        keys = []
        for i in keep:
            row = [round(float(ts[i]), 4)] + [round(float(x), 5) for x in qs[i]]
            if hasp:
                row += [round(float(x), 4) for x in ps[i]]
            keys.append(row)
        cl["joints"][jn] = dict(pos=bool(hasp), keys=keys)
        sc = [s for T, s in Ts]
        if max(abs(s - 1) for s in sc) > 1e-4:                                     # uniform scale of a rigid group (the halo)
            cl["scales"][rig["joints"][jn]["part1"]] = [[round(float(ts[i]), 4), round(float(sc[i]), 4)] for i in keep]
    out["clips"][clip] = cl
    # --- verify the chain (after key reduction) against glTF FK, every 1/24 s
    n = int(math.floor(dur * C.FPS + 1e-6))
    for f in range(n + 1):
        t = f / C.FPS
        cache = {}
        def lf(i, tracks=tracks, t=t):
            tr, q, s = C.sample_node(G, tracks, i, t)
            return tr, q, np.ones(3)
        poses = L.chain_pose(out, clip, t)
        for jn, j in rig["joints"].items():
            truth = L.to_roblox(C.world_of(G, j["node"], lf, cache), S)
            p1 = j["part1"]
            Wn = poses[p1]
            # the joint node frame equals part node frame for meshes hanging from it with identity local transform
            dp = float(np.linalg.norm(Wn[:3, 3] - truth[:3, 3]))
            dr = float(np.abs(Wn[:3, :3] - truth[:3, :3]).max())
            worst_p, worst_r = max(worst_p, dp), max(worst_r, dr)
print("VERIFY Motor6D chain vs glTF FK (all 8 clips, every 1/24 s, after key reduction): worst position error %.5f studs, worst rotation error %.2e" % (worst_p, worst_r))
print("keys: %d raw -> %d after reduction (tolerance %.2f deg / %.3f stud)" % (nkeys_raw, nkeys, TOL_ROT_DEG, TOL_POS))

# ---- FX nodes (timing + placement for the Roblox-native effects)
FX = [n for n in G.byname if n and n.startswith("FX_")]
cache = {}
Whrp = L.to_roblox(G.rest_world(G.byname["HumanoidRootPart"], cache), S)
group_nodes = rig["base_of"]
for nm in FX:
    i = G.byname[nm]
    W = L.to_roblox(G.rest_world(i, cache), S)
    parent_part = "HumanoidRootPart"
    for a in [i] + G.ancestors(i):
        if a in group_nodes and a != i:
            parent_part = group_nodes[a]
            break
    pf = rig["frameP"][parent_part]
    ent = dict(parent=parent_part, local=L.cf_list(np.linalg.inv(pf) @ W), in_hrp=[round(float(x), 4) for x in (np.linalg.inv(Whrp) @ W)[:3, 3]], clips={})
    for clip in C.CLIP_ORDER:
        tr = G.tracks(clip).get(i)
        if not tr:
            continue
        d = {}
        for path, (T, V) in tr.items():
            if path == "scale":
                d["scale"] = [[round(float(t), 4), round(float(np.mean(v)), 4)] for t, v in zip(T, V)]
            elif path == "translation":
                d["pos"] = [[round(float(t), 4)] + [round(float(x), 4) for x in (S * np.array([-v[0], v[1], -v[2]]))] for t, v in zip(T, V)]
            else:
                d["rot"] = [[round(float(t), 4), round(2 * math.degrees(math.acos(min(1.0, abs(float(v[3]))))), 2)] for t, v in zip(T, V)]
        ent["clips"][clip] = d
    out["fx"][nm] = ent
# bounding boxes of the dropped effect meshes (Roblox axes, studs) for sizing the native effects
fxm = {}
for nm in ["CoinRainMarks_Neon", "GroundSigil_Neon", "NovaRing_Neon", "Shockwave_Neon", "TakeoverBeam_Neon", "CoinOrbit", "CoinRain", "AuraFlames_A_Neon"]:
    lo, hi = L.mesh_bbox(G, nm)
    a, b = S * np.array([-hi[0], lo[1], -hi[2]]), S * np.array([-lo[0], hi[1], -lo[2]])
    fxm[nm] = dict(min=[round(float(x), 3) for x in a], max=[round(float(x), 3) for x in b])
out["fx_mesh_bbox"] = fxm
out["hrp_height"] = round(float(Whrp[1, 3]), 4)

tag = argv[argv.index("--tag") + 1] if "--tag" in argv else "vault_roblox"
jp = os.path.join(C.EXPORT, tag + ".json")
json.dump(out, open(jp, "w"), separators=(",", ":"))
print("wrote", jp, os.path.getsize(jp), "bytes")
print("joints", len(out["joints"]), "welds", len(out["welds"]), "parts", len(out["parts"]), "fx nodes", len(out["fx"]))
print("rest: HRP height %.3f studs; C1 translation magnitudes (should be ~0):" % out["hrp_height"], {k: round(float(np.linalg.norm(np.array(v["C1"][:3]))), 5) for k, v in out["joints"].items() if np.linalg.norm(np.array(v["C1"][:3])) > 1e-4})


# ================================================================ Luau modules + expected values for the in-engine tests
NEON_COLOR = [0.70, 0.58, 1.0]          # sRGB; the authored emissive is (0.643, 0.42, 1.0) x1.48, which reads as pale lavender after tone mapping: lifted a little for Roblox Neon
LUA_KW = {"end", "and", "or", "not", "nil", "true", "false", "if", "then", "else", "do", "for", "in", "local", "function", "return", "while", "repeat", "until", "break", "elseif"}


def lv(v, ind=0):
    pad = "\t" * (ind + 1)
    if isinstance(v, dict):
        if not v:
            return "{}"
        rows = []
        for k, x in v.items():
            key = k if (isinstance(k, str) and k.isidentifier() and k not in LUA_KW) else "[%s]" % lv(k)
            rows.append("%s%s = %s," % (pad, key, lv(x, ind + 1)))
        return "{\n" + "\n".join(rows) + "\n" + "\t" * ind + "}"
    if isinstance(v, (list, tuple)):
        if all(isinstance(x, (int, float)) for x in v):
            return "{ " + ", ".join(lv(x) for x in v) + " }"
        return "{\n" + "\n".join("%s%s," % (pad, lv(x, ind + 1)) for x in v) + "\n" + "\t" * ind + "}"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        s = ("%.5f" % v).rstrip("0").rstrip(".")
        return "0" if s in ("-0", "") else s
    if isinstance(v, int):
        return str(v)
    return '"%s"' % str(v).replace('"', '\\"')


SRC = os.path.join(C.REPO, "src", "ServerStorage", "VaultWizardTest", "RuntimeSrc")
HDR = "-- Studio location: ServerStorage.VaultWizardTest.RuntimeSrc.%s (ModuleScript)\n-- GENERATED by tools/blender/vault/vw_convert.py from Vault.glb + the corrected clips. Do not edit by hand.\n"


def cf12(M):
    return L.cf_list(M)


if "--no-lua" not in argv:
    os.makedirs(os.path.join(SRC, "Clips"), exist_ok=True)
    hrp = rig["frameP"]["HumanoidRootPart"]
    fxl = {}
    for nm, e in out["fx"].items():
        d = {}
        for clip, tr in e["clips"].items():
            t = {}
            if "scale" in tr:
                t["scale"] = tr["scale"]
            if "pos" in tr:
                t["pos"] = tr["pos"]
            if t:
                d[clip] = t
        fxl[nm] = dict(parent=e["parent"], localFrame=e["local"], inHrp=e["in_hrp"], clips=d)
    vd = dict(studs=S, hrpHeight=out["hrp_height"], hrpFrame=cf12(hrp), order=out["order"], neonColor=NEON_COLOR,
              joints={k: dict(p0=v["part0"], p1=v["part1"], c0=v["C0"], c1=v["C1"]) for k, v in out["joints"].items()},
              welds=[dict(p0=w["part0"], p1=w["part1"], c0=w["C0"], c1=w["C1"]) for w in out["welds"]],
              parts={k: dict(neon=v["neon"], tris=v["tris"]) for k, v in out["parts"].items()},
              fx=fxl, spin=[jn for jn in out["order"] if jn.startswith("FX_")], meshBox=out["fx_mesh_bbox"], clips=C.CLIP_ORDER, loops={c: True for c in sorted(LOOPS)})
    open(os.path.join(SRC, "VaultData.lua"), "w").write(HDR % "VaultData" + "return " + lv(vd) + "\n")
    for clip, cl in out["clips"].items():
        joints = {}
        for jn, tr in cl["joints"].items():
            stride = 8 if tr["pos"] else 5
            flat = [stride]
            for row in tr["keys"]:
                flat += row
            joints[jn] = flat
        scales = {}
        for part, sc in cl["scales"].items():
            scales[part] = [x for row in sc for x in row]
            for w in out["welds"]:
                if w["part0"] == part:
                    pass
        c = dict(length=cl["length"], loop=cl["loop"], joints=joints, scales=scales)
        open(os.path.join(SRC, "Clips", clip + ".lua"), "w").write(HDR % ("Clips." + clip) + "return " + lv(c) + "\n")
    sizes = {f: os.path.getsize(os.path.join(SRC, "Clips", f)) for f in os.listdir(os.path.join(SRC, "Clips"))}
    print("Lua modules written: VaultData %d bytes, clips %s" % (os.path.getsize(os.path.join(SRC, "VaultData.lua")), sizes))

    # expected values for the in-engine tests (glTF forward kinematics = independent of the Motor6D chain): part frame origins relative to the root, at 6 times per clip
    exp = dict(studs=S, hrp=[float(x) for x in hrp[:3, 3]], samples={}, rest_extents=None)
    for clip in C.CLIP_ORDER:
        tracks = tracks_for(clip)
        dur = clip_len(clip)
        rows = []
        for i in range(4):
            t = dur * i / 3.0
            cache = {}
            def lf(n, tracks=tracks, t=t):
                tr, q, s = C.sample_node(G, tracks, n, t)
                return tr, q, np.ones(3)
            pos = {}
            for jn, j in rig["joints"].items():
                W = L.to_roblox(C.world_of(G, j["node"], lf, cache), S)
                pos[j["part1"]] = [round(float(x), 4) for x in (W[:3, 3] - hrp[:3, 3])]
            rows.append(dict(t=round(t, 4), pos=pos))
        exp["samples"][clip] = rows
    cache = {}
    rest = {}
    for jn, j in rig["joints"].items():
        W = L.to_roblox(G.rest_world(j["node"], cache), S)
        rest[j["part1"]] = [round(float(x), 4) for x in (W[:3, 3] - hrp[:3, 3])]
    exp["rest"] = rest
    lo = np.full(3, 1e9)
    hi = np.full(3, -1e9)
    cache = {}
    for nm in mesh_names:
        if nm in ("VaultHalo", "VaultHalo_Neon"):
            continue
        W = L.to_roblox(G.rest_world(G.byname[nm], cache), S)
        v = z[nm + "__v"]
        wv = (v @ np.diag([-1, 1, -1.0]) @ np.eye(3))                      # node-local glTF -> Roblox axes
        wv = (W[:3, :3] @ wv.T).T + W[:3, 3] - hrp[:3, 3]
        lo, hi = np.minimum(lo, wv.min(0)), np.maximum(hi, wv.max(0))
    exp["rest_extents"] = dict(min=[round(float(x), 3) for x in lo], max=[round(float(x), 3) for x in hi])
    json.dump(exp, open(os.path.join(C.EXPORT, "vault_expected.json"), "w"), indent=1)
    os.makedirs(os.path.join(C.REPO, "src", "ServerStorage", "VaultWizardTest", "Tests"), exist_ok=True)
    ex_lua = dict(rest=exp["rest"], restExtents=exp["rest_extents"], samples={c: [dict(t=r["t"], pos=r["pos"]) for r in rows] for c, rows in exp["samples"].items()})
    open(os.path.join(C.REPO, "src", "ServerStorage", "VaultWizardTest", "Tests", "Expected.lua"), "w").write(
        "-- Studio location: ServerStorage.VaultWizardTest.Tests.Expected (ModuleScript)\n-- GENERATED by tools/blender/vault/vw_convert.py: glTF forward-kinematics positions (studs, relative to the root) used as the independent truth in the Studio tests.\nreturn " + lv(ex_lua) + "\n")
    print("rest extents relative to the root (studs, halo excluded):", exp["rest_extents"])
