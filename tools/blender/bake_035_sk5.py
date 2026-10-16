# Shield Knight v5: UV atlas + Cycles bakes -> maps.npz (+ the unwrapped .blend). Texture composition is plain numpy (compose_035_sk5.py).
#   flatpak run org.blender.Blender -b -P $PWD/tools/blender/bake_035_sk5.py -- [--res 2048]
import os, sys, time, json
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
import bpy
import numpy as np
from kit035 import geo, studio, sk5, pbr

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
res = int(argv[argv.index("--res") + 1]) if "--res" in argv else 2048
OUT = os.path.expanduser("~/Pictures/035_preview/sk5_dev")
os.makedirs(OUT, exist_ok=True)
ch = sk5.shield_knight_v5()
sc = studio.setup(256)
ch.build_objects()
objs = [ob for (g, c), ob in sorted(ch.objs.items()) if ch.groups[g]["tier"] is None and g != "Flash"]
groups = sorted({g for (g, c) in ch.objs if g != "Flash"})
for (g, c), ob in ch.objs.items():
    ob["mid"] = pbr.KIND_ID[c] / 16.0
    ob["gid"] = (groups.index(g) + 1) / 64.0 if g in groups else 0.0
t = time.time()
pbr.unwrap_pack(objs)
print("BAKE unwrap", round(time.time() - t, 1), "s")
t = time.time()
maps = pbr.bake_joined(objs, res=res)
print("BAKE bakes", round(time.time() - t, 1), "s")
np.savez_compressed(os.path.join(OUT, "maps.npz"), **{k: v.astype(np.float16) for k, v in maps.items()})
json.dump({"groups": groups, "kinds": pbr.KIND_ID, "meta": ch.meta}, open(os.path.join(OUT, "maps_meta.json"), "w"))
for ob in objs:
    ob.data.materials.clear()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "sk5_uv.blend"))
print("BAKE done", len(objs), "objects", res)
