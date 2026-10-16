# per-object culling diff: which pieces are visible from outside only with culling OFF (inverted) - run inside Blender: -- sk4|sk3
import math, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
import bpy, numpy as np
from mathutils import Vector as V
from kit035 import geo, studio, sk3, sk4, body
which = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "sk4"
ch = {"sk4": sk4.shield_knight_v4, "sk3": sk3.shield_knight_v3}[which]()
sc = studio.setup(240)
ch.build_objects(); ch.pose(0.0)
m = bpy.data.materials.new("c"); m.use_nodes = True
next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.5, 0.5, 0.5, 1)
bpy.context.view_layer.material_override = m
objs = [(k, o) for k, o in sorted(ch.objs.items()) if not ch.groups[k[0]]["tier"] and k[0] != "Flash"]
lo, hi = studio.bounds([o for _, o in objs]); ctr = V(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2)); d = studio.fit_dist(lo, hi, margin=1.05)
def shot(path):
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(path, check_existing=False); a = np.empty(len(im.pixels), np.float32); im.pixels.foreach_get(a); bpy.data.images.remove(im)
    return a.reshape(-1, 4)[:, :3]
rows = []
for k, o in objs:
    for _, o2 in objs:
        o2.hide_render = o2 is not o
    tot = cov = 0
    for az, el in ((0, 8), (180, 8), (-90, 10), (90, 10), (-35, 40)):
        studio.aim(sc, ctr, az, el, d)
        res = []
        for cull in (False, True):
            m.use_backface_culling = cull
            res.append(shot("/tmp/co_%d.png" % cull))
        bg = res[0][0]
        c = (np.abs(res[0] - bg).sum(1) > 0.02)
        df = np.abs(res[0] - res[1]).sum(1) > 0.05
        tot += df.sum(); cov += c.sum()
    rows.append((tot / max(cov, 1), tot, cov, k))
for fr, tot, cov, k in sorted(rows, reverse=True)[:24]:
    print("CULLOBJ %.2f  diff %5d of %6d  %s_%s" % (fr, tot, cov, k[0], k[1]))
