# Shield Knight v2 benchmark: renders (old B1 vs new) + close-ups, budget numbers, FBX test export (not for import).
#   flatpak run org.blender.Blender -b -P $PWD/tools/blender/build_035_sk2.py -- [--views a,b] [--res 640] [--old] [--final]
import json, math, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
import bpy
from mathutils import Vector as V
from kit035 import geo, studio, b1, sk2, sk3, body

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
opt = {"views": "front,tq,back", "res": 640, "old": False, "ver": 2, "out": os.path.expanduser("~/Pictures/035_preview/b1_dev")}
i = 0
while i < len(argv):
    a = argv[i]
    if a == "--views": opt["views"] = argv[i + 1]; i += 1
    elif a == "--res": opt["res"] = int(argv[i + 1]); i += 1
    elif a == "--old": opt["old"] = True
    elif a == "--ver": opt["ver"] = int(argv[i + 1]); i += 1
    elif a == "--out": opt["out"] = argv[i + 1]; i += 1
    i += 1
os.makedirs(opt["out"], exist_ok=True)
body.set_skel(body.DEFAULT)
if "--pair" in argv:
    pass
ch = (b1.shield_knight if opt["old"] else (sk3.shield_knight_v3 if opt["ver"] == 3 else sk2.shield_knight_v2))()
tag = "old" if opt["old"] else ("v3" if opt["ver"] == 3 else "new")
sc = studio.setup(opt["res"])
ch.build_objects()
ch.pose(0.0)
for (g, c), ob in ch.objs.items():
    if ch.groups[g]["tier"]:
        ob.hide_render = True
vis = list(ch.objs.values())
lo, hi = studio.bounds(vis)
ctr = V(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2))
d = studio.fit_dist(lo, hi, margin=1.06)
# name: (target in frame A, azimuth, elevation, distance)   (azimuth: + toward the character's left, 180 = behind)
CLOSE_NEW = {
    "helm": ((0, 5.4, 0), -28, 8, 5.4), "chest": ((0, 3.9, 0), -22, 8, 7.0), "pauldron": ((1.8, 4.2, 0), -42, 14, 6.4), "arm": ((1.8, 3.3, 0), -50, 8, 7.0),
    "legs": ((0, 1.6, 0), -30, 6, 8.5), "boots": ((0, 0.7, 0), -35, 10, 6.0), "shield": ((-2.3, 3.1, -0.8), 28, 8, 8.0),
}
CLOSE_OLD = {
    "helm": ((0, 4.7, 0), -28, 8, 5.4), "chest": ((0, 3.2, 0), -22, 8, 7.0), "pauldron": ((1.6, 3.7, 0), -42, 14, 6.4), "arm": ((1.6, 2.9, 0), -50, 8, 7.0),
    "legs": ((0, 1.1, 0), -30, 6, 8.5), "boots": ((0, 0.5, 0), -35, 10, 6.0), "shield": ((-2.0, 2.75, -0.8), 28, 8, 8.0),
}
CLOSE = CLOSE_OLD if opt["old"] else CLOSE_NEW
CLOSE_NEW["crest"] = ((0, 6.0, 0.4), -45, 10, 6.5)
for v in opt["views"].split(","):
    if v in ("front", "tq", "back", "side"):
        az, el = {"front": (0, 8), "tq": (-35, 14), "back": (180, 8), "side": (-90, 6)}[v]
        studio.aim(sc, ctr, az, el, d)
    else:
        t, az, el, dist = CLOSE[v]
        studio.aim(sc, V(geo.to_blender(t)), az, el, dist, lens=60)
    studio.shoot(sc, os.path.join(opt["out"], "SK_%s_%s.png" % (tag, v)))
r = ch.report()
print("SK", tag, "tris", ch.tris(), "parts", ch.part_count(), "max mesh", r["max_mesh_tris"])
print("  by group:", sorted(((sum(m.tris() for (g, c), m in ch.parts.items() if g == gg), gg) for gg in {g for (g, c) in ch.parts}), reverse=True)[:12])


if "--pair" in argv:
    # old (viewer's left) and new (viewer's right) in one scene at their spec scales, same camera and light
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = studio.setup(opt["res"] * 2 // 1)
    objs_all = []
    for label, maker, skel, dx in (("old", sk2.shield_knight_v2 if opt["ver"] == 3 else b1.shield_knight, body.HERO if opt["ver"] == 3 else body.DEFAULT, 4.0), ("new", sk3.shield_knight_v3 if opt["ver"] == 3 else sk2.shield_knight_v2, body.HERO, -4.0)):
        body.set_skel(skel)
        c = maker()
        c.build_objects()
        c.pose(0.0)
        root = bpy.data.objects.new("root_" + label, None)
        bpy.context.scene.collection.objects.link(root)
        root.location = (-dx, 0, 0)
        root.scale = (c.scale,) * 3
        for (g, col), ob in c.objs.items():
            if c.groups[g]["tier"]:
                ob.hide_render = True
            ob.parent = root
            objs_all.append(ob)
    bpy.context.view_layer.update()
    lo, hi = studio.bounds([o for o in objs_all if not o.hide_render])
    ctr = V(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2))
    import math
    t = math.tan(math.atan(18.0 / 70.0))  # horizontal half-fov of the 70 mm lens
    asp = 2.0
    d = 1.16 * max((hi.x - lo.x) / 2 / t, (hi.z - lo.z) / 2 * asp / t) + (hi.y - lo.y) / 2
    print("PAIR bounds", tuple(round(c, 1) for c in lo), tuple(round(c, 1) for c in hi), "dist", round(d, 1))
    for v, (az, el) in {"front": (0, 8), "tq": (-30, 14), "back": (180, 8)}.items():
        for lab, dx in (("old", 4.0), ("new", -4.0)):
            bpy.data.objects["root_" + lab].location = (-(dx if v != "back" else -dx), 0, 0)  # seen from behind, keep OLD on the viewer's left
        studio.aim(sc, ctr, az, el, d)
        sc.render.resolution_x, sc.render.resolution_y = opt["res"] * 2, opt["res"]
        studio.shoot(sc, os.path.join(opt["out"], "SK_pair_%s.png" % v))
