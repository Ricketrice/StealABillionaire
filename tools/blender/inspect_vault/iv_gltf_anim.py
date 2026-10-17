# Animation inventory straight from the GLB JSON (no Blender): clips, channels, paths, keyframe counts, interpolation, rates.
import json, struct, os, collections, sys
p = os.path.expanduser("~/Pictures/035_preview/concept/Vault.glb")
d = open(p, "rb").read(); cl, _ = struct.unpack("<II", d[12:20]); j = json.loads(d[20:20 + cl]); N = j["nodes"]
print("clips:", len(j["animations"]))
for a in j["animations"]:
    paths = collections.Counter(); kf = []; interp = collections.Counter(); dur = 0; times = None
    for ch in a["channels"]:
        s = a["samplers"][ch["sampler"]]; ia = j["accessors"][s["input"]]
        paths[ch["target"]["path"]] += 1; kf.append(ia["count"]); interp[s.get("interpolation", "LINEAR")] += 1; dur = max(dur, ia["max"][0])
    body = [N[c["target"]["node"]]["name"] for c in a["channels"] if not N[c["target"]["node"]]["name"].startswith("FX_")]
    fx = sorted({N[c["target"]["node"]]["name"] for c in a["channels"] if N[c["target"]["node"]]["name"].startswith("FX_")})
    rate = (kf[0] - 1) / dur if dur else 0
    print("%-18s dur %.2fs channels %2d paths %s keys/channel min %d max %d interp %s ~%.0f keys/s | body joints animated: %d | FX: %s" % (a["name"], dur, len(a["channels"]), dict(paths), min(kf), max(kf), dict(interp), rate, len(set(body)), ",".join(x.replace("FX_", "") for x in fx)))
    # which body joints and which paths
    jp = collections.defaultdict(set)
    for c in a["channels"]:
        n = N[c["target"]["node"]]["name"]
        if not n.startswith("FX_"): jp[n].add(c["target"]["path"][0])
    print("     ", " ".join("%s:%s" % (k, "".join(sorted(v))) for k, v in sorted(jp.items())))
