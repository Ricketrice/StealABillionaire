# Renders Vault parts from vault_meshes.npz (decimated) or the original GLB, in a given pose.
# Usage: flatpak run org.blender.Blender -b -P $PWD/tools/blender/vault/vw_render.py -- <mode> <outdir> [args]
#   mode compare            original (GLB, body only) vs decimated, front/back/3-4 + close-ups      -> outdir/compare_*.png
#   mode clip <json> <clip> <n>   poses the rig from the converted Roblox data (vault_roblox.json written by vw_convert.py) at n frames -> outdir/<clip>_<i>.png
# The clip mode poses parts with the SAME Motor6D chain the Studio builder uses (C0 * Transform * C1^-1), so it checks the converted data, not Blender's own animation.
import bpy
import json
import math
import os
import sys

import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vw_common as C  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
mode, OUT = argv[0], os.path.expanduser(argv[1])
os.makedirs(OUT, exist_ok=True)
G = C.Glb()
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
CG2B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
CB2G = CG2B.inverted()


def setup_render(res=(480, 660)):
    cy = sc.cycles
    sc.render.engine = "CYCLES"
    cy.samples = int(os.environ.get("V_SAMPLES", "16"))
    cy.use_denoising = True
    try:
        pref = bpy.context.preferences.addons["cycles"].preferences
        for t in ("OPTIX", "CUDA"):
            pref.compute_device_type = t
            pref.get_devices()
            if any(d.type == t for d in pref.devices):
                for d in pref.devices:
                    d.use = d.type == t
                cy.device = "GPU"
                break
    except Exception:
        pass
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.2, 0.21, 0.25, 1)
    sc.render.resolution_x, sc.render.resolution_y = res


cen = Vector((0, 0, 1.45))


def light(n, loc, e, size=4):
    d = bpy.data.lights.new(n, "AREA")
    d.energy = e
    d.size = size
    o = bpy.data.objects.new(n, d)
    sc.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (cen - o.location).to_track_quat("-Z", "Y").to_euler()


light("k", (4, -6, 6), 1800)
light("f", (-6, -4, 2), 700, 6)
light("r", (0, 6, 5), 900)
cam = bpy.data.cameras.new("c")
cam.type = "ORTHO"
co = bpy.data.objects.new("c", cam)
sc.collection.objects.link(co)
sc.camera = co
setup_render()


def shot(path, az, el=6, scale=4.0, target=(0, 0, 1.45), res=(480, 660)):
    sc.render.resolution_x, sc.render.resolution_y = res
    cam.ortho_scale = scale
    ar, er = math.radians(az), math.radians(el)
    t = Vector(target)
    co.location = t + Vector((math.sin(ar) * math.cos(er), -math.cos(ar) * math.cos(er), math.sin(er))) * 20
    co.rotation_euler = (t - co.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


# materials: palette image (nearest) and neon emission
pal_img = bpy.data.images.load(os.path.join(C.EXPORT, "VaultPalette_Color.png"))
pal_img.colorspace_settings.name = "sRGB"
m_pal = bpy.data.materials.new("pal")
m_pal.use_nodes = True
nt = m_pal.node_tree
bs = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
tx = nt.nodes.new("ShaderNodeTexImage")
tx.image = pal_img
tx.interpolation = "Closest"
nt.links.new(tx.outputs["Color"], bs.inputs["Base Color"])
bs.inputs["Roughness"].default_value = 0.5
m_neon = bpy.data.materials.new("neon")
m_neon.use_nodes = True
bsn = next(n for n in m_neon.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
bsn.inputs["Base Color"].default_value = (0.37, 0.15, 1, 1)
bsn.inputs["Emission Color"].default_value = (0.37, 0.15, 1, 1)
bsn.inputs["Emission Strength"].default_value = 1.48


def make_mesh_obj(name, v, f, uv, neon, W=None):
    """v in node-local glTF coords; W = 4x4 glTF world matrix (numpy) of the part's node."""
    vb = np.stack([v[:, 0], -v[:, 2], v[:, 1]], axis=1)
    me = bpy.data.meshes.new(name)
    me.from_pydata(vb.tolist(), [], f.tolist())
    me.update()
    uvl = me.uv_layers.new(name="UVMap")
    for k, p in enumerate(me.polygons):
        for c, li in enumerate(p.loop_indices):
            uvl.data[li].uv = tuple(uv[k, c])
    C.shade_by_angle(me)
    me.materials.append(m_neon if neon else m_pal)
    ob = bpy.data.objects.new(name, me)
    sc.collection.objects.link(ob)
    if W is not None:
        ob.matrix_world = CG2B @ Matrix(W.tolist()) @ CB2G
    return ob


def load_npz():
    z = np.load(os.path.join(C.WORK, "vault_meshes.npz"))
    return {n: dict(v=z[n + "__v"], f=z[n + "__f"], uv=z[n + "__uv"], neon=bool(z[n + "__neon"][0])) for n in z["names"]}


if mode == "compare":
    import bmesh
    # original: import the GLB (body meshes only) on the left, decimated on the right
    bpy.ops.import_scene.gltf(filepath=C.GLB)
    orig = [o for o in bpy.data.objects if o.type == "MESH"]
    keep = {n for n in load_npz()}
    for o in orig:
        if o.name not in keep:
            o.hide_render = True
        else:
            for ms in o.material_slots:
                pass
    for o in bpy.data.objects:
        if o.parent is None and o.type == "EMPTY":
            o.location.x -= 1.1
    # the original uses nearest-filtered palette via its own materials (kept)
    z = load_npz()
    cache = {}
    for n, d in z.items():
        W = G.rest_world(G.byname[n], cache)
        ob = make_mesh_obj(n + "_dec", d["v"], d["f"], d["uv"], d["neon"], W)
        ob.location.x += 1.1
    for o in bpy.data.objects:  # no animation state: rest
        if o.animation_data:
            o.animation_data.action = None
            for t in o.animation_data.nla_tracks:
                t.mute = True
    sc.frame_set(1)
    shot(OUT + "/compare_front.png", 0, scale=4.4, res=(1100, 760))
    shot(OUT + "/compare_tq.png", -35, scale=4.4, res=(1100, 760))
    shot(OUT + "/compare_back.png", 180, scale=4.4, res=(1100, 760))
    shot(OUT + "/compare_head.png", -25, el=10, scale=3.0, target=(0, 0, 2.45), res=(1100, 640))
    shot(OUT + "/compare_scepter.png", -50, el=8, scale=3.2, target=(0, 0, 1.0), res=(1100, 640))
    # after: halo is hidden in the original (FX) so also keep an explicit halo-only look
elif mode == "clip":
    data = json.load(open(os.path.expanduser(argv[2])))
    clip, nfr = argv[3], int(argv[4])
    z = load_npz()
    objs = {n: make_mesh_obj(n, d["v"], d["f"], d["uv"], d["neon"]) for n, d in z.items()}
    S = data["studs_per_unit"]
    from vw_convert_lib import chain_pose, scales_at   # noqa: E402  (pose every part from the Roblox data)
    el = float(os.environ.get("V_EL", "6")); az = float(os.environ.get("V_AZ", "-35")); scale = float(os.environ.get("V_SCALE", "4.8"))
    L = data["clips"][clip]["length"]
    for i in range(nfr):
        t = L * i / max(nfr - 1, 1) if nfr > 1 else 0.0
        poses = chain_pose(data, clip, t)               # part -> 4x4 world (Roblox space, studs) of the part's authored frame
        for n, ob in objs.items():
            if n not in poses:
                ob.hide_render = True
                continue
            Wr = poses[n]
            # Roblox (x,y,z) -> glTF (-x, y, -z) /S -> blender (x,-z,y)
            Wg = np.diag([-1, 1, -1, 1.0]) @ Wr @ np.diag([-1, 1, -1, 1.0]); Wg[:3, 3] /= S
            # node-local mesh coords live in the node's frame, whose world rotation is the rest-rotation: handled by chain_pose (it returns the node frame)
            ob.matrix_world = CG2B @ Matrix(Wg.tolist()) @ CB2G
        for n, sv in scales_at(data, clip, t).items():
            if n in objs:
                objs[n].scale = (sv, sv, sv)
        shot(OUT + "/%s_%d.png" % (clip, i), az, el=el, scale=scale, target=(0, 0, 1.5), res=(int(os.environ.get("V_W", "340")), int(os.environ.get("V_H", "470"))))
print("render done", mode)
