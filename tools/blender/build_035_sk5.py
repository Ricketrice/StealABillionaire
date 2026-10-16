# Shield Knight v5 (art-direction reset): geometry check, PBR bake, renders.
#   flatpak run org.blender.Blender -b -P $PWD/tools/blender/build_035_sk5.py -- --mode clay|flat [--views front,tq,back] [--res 700] [--out DIR]
import json, math, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
import bpy
from mathutils import Vector as V
from kit035 import geo, studio, sk5, body
from kit035 import body as _b

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
opt = {"views": "front,tq,back", "res": 700, "mode": "clay", "out": os.path.expanduser("~/Pictures/035_preview/sk5_dev")}
i = 0
while i < len(argv):
    a = argv[i]
    if a in ("--views", "--res", "--mode", "--out"):
        opt[a[2:]] = argv[i + 1]; i += 1
    i += 1
opt["res"] = int(opt["res"])
os.makedirs(opt["out"], exist_ok=True)
ch = sk5.shield_knight_v5()
sc = studio.setup(opt["res"])
ch.build_objects()
ch.pose(0.0)
for (g, c), ob in ch.objs.items():
    if ch.groups[g]["tier"] or g == "Flash":
        ob.hide_render = True
if opt["mode"] == "clay":
    m = bpy.data.materials.new("clay"); m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (0.16, 0.17, 0.19, 1); b.inputs["Roughness"].default_value = 0.55
    m.use_backface_culling = True  # Roblox culls back faces: inverted plates must show up as holes here
    bpy.context.view_layer.material_override = m
vis = [o for o in ch.objs.values() if not o.hide_render]
lo, hi = studio.bounds(vis)
ctr = V(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2))
d = studio.fit_dist(lo, hi, margin=1.06)
CLOSE = {
    "helm": ((0, 5.5, 0), -28, 8, 5.4), "chest": ((0, 3.9, 0), -22, 8, 7.0), "pauldron": ((1.9, 4.3, 0), -42, 14, 6.4), "arm": ((1.8, 3.3, 0), -50, 8, 7.0),
    "waist": ((0, 2.8, 0), -25, 6, 7.0), "legs": ((0, 1.6, 0), -30, 6, 8.5), "boots": ((0, 0.7, 0), -35, 10, 6.0), "shield": ((-2.3, 3.0, -0.8), 28, 8, 8.5),
    "backc": ((0, 3.9, 0.5), 180, 8, 8.5), "helm_side": ((0, 5.5, 0), -90, 6, 5.4),
}
for v in opt["views"].split(","):
    if v in ("front", "tq", "back", "side"):
        az, el = {"front": (0, 8), "tq": (-35, 14), "back": (180, 8), "side": (-90, 6)}[v]
        studio.aim(sc, ctr, az, el, d)
    else:
        t, az, el, dist = CLOSE[v]
        studio.aim(sc, V(geo.to_blender(t)), az, el, dist, lens=60)
    studio.shoot(sc, os.path.join(opt["out"], "SK5_%s_%s.png" % (opt["mode"], v)))
r = ch.report()
print("SK5 tris", ch.tris(), "parts", ch.part_count(), "max mesh", r["max_mesh_tris"])
print("  by group:", sorted(((sum(m.tris() for (g, c), m in ch.parts.items() if g == gg), gg) for gg in {g for (g, c) in ch.parts}), reverse=True)[:14])
