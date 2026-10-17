# FX animation inventory from the GLB JSON: which FX_ node is animated by which clip, with which path and value range.
import json, struct, os, collections, struct as S
p = os.path.expanduser("~/Pictures/035_preview/concept/Vault.glb")
d = open(p, "rb").read(); cl, _ = S.unpack("<II", d[12:20]); j = json.loads(d[20:20 + cl]); binstart = 20 + cl + 8
N = j["nodes"]
def acc(i):
    a = j["accessors"][i]; bv = j["bufferViews"][a["bufferView"]]; off = binstart + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    comps = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[a["type"]]; n = a["count"] * comps
    return [S.unpack_from("<%df" % n, d, off)[k * comps:(k + 1) * comps] for k in range(a["count"])]
rows = collections.defaultdict(list)
for a in j["animations"]:
    for ch in a["channels"]:
        nm = N[ch["target"]["node"]]["name"]
        if not nm.startswith("FX_"): continue
        s = a["samplers"][ch["sampler"]]; t = [x[0] for x in acc(s["input"])]; v = acc(s["output"])
        path = ch["target"]["path"]
        if path == "scale": rng = "scale %.3f..%.3f" % (min(min(x) for x in v), max(max(x) for x in v))
        elif path == "translation": rng = "pos y %.2f..%.2f z %.2f..%.2f" % (min(x[1] for x in v), max(x[1] for x in v), min(x[2] for x in v), max(x[2] for x in v))
        else:
            import math
            ang = [2 * math.degrees(math.acos(max(-1, min(1, abs(x[3]))))) for x in v]; rng = "rot up to %.0f deg (%d keys)" % (max(ang), len(v))
        rows[nm].append("%s/%s: %s keys=%d" % (a["name"], path[0], rng, len(t)))
for nm, r in sorted(rows.items()):
    print(nm); [print("   ", x) for x in r if not (nm in ("FX_AuraFlames_A", "FX_AuraFlames_B", "FX_CoinOrbit_Spin", "FX_GroundSigil", "FX_ScepterGem", "FX_VaultHalo") and not x.startswith(("Idle", "Event_VaultLock")))]
