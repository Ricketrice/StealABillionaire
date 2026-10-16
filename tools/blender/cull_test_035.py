# Orientation test: renders the model with and without back-face culling from several angles; any pixel that differs is an inverted (invisible-in-Roblox) face.
#   flatpak run org.blender.Blender -b -P tools/blender/cull_test_035.py -- sk4|sk3|sk2
import math, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
import bpy, numpy as np
from mathutils import Vector as V
from kit035 import geo, studio, sk2, sk3, sk4, body
which = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "sk4"
ch = {"sk4": sk4.shield_knight_v4, "sk3": sk3.shield_knight_v3, "sk2": sk2.shield_knight_v2}[which]()
sc = studio.setup(500)
ch.build_objects()
ch.pose(0.0)
for (g, c), ob in ch.objs.items():
    if ch.groups[g]["tier"] or g == "Flash":
        ob.hide_render = True
m = bpy.data.materials.new("c"); m.use_nodes = True
b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"); b.inputs["Base Color"].default_value = (0.5, 0.5, 0.5, 1)
bpy.context.view_layer.material_override = m
vis = [o for o in ch.objs.values() if not o.hide_render]
lo, hi = studio.bounds(vis)
ctr = V(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2))
d = studio.fit_dist(lo, hi, margin=1.05)
sc.render.film_transparent = False
tot_bad = 0
for az, el in ((0, 8), (-35, 14), (180, 8), (90, 10), (-90, 10), (0, 60), (180, 50), (40, -20)):
    imgs = []
    for cull in (False, True):
        m.use_backface_culling = cull
        studio.aim(sc, ctr, az, el, d)
        sc.render.filepath = "/tmp/cull_%d.png" % cull
        bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(sc.render.filepath, check_existing=False)
        a = np.empty(len(im.pixels), np.float32); im.pixels.foreach_get(a)
        imgs.append(a.reshape(-1, 4)[:, :3]); bpy.data.images.remove(im)
    diff = np.abs(imgs[0] - imgs[1]).sum(1) > 0.05
    covered = (np.abs(imgs[0] - imgs[0][0]).sum(1) > 0.02).sum()
    print("CULL view az=%d el=%d  differing pixels %d of %d covered (%.2f%%)" % (az, el, diff.sum(), covered, 100 * diff.sum() / max(covered, 1)))
    tot_bad += diff.sum()
print("CULL total differing pixels", tot_bad)
