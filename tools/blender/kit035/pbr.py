# kit035.pbr - the PBR texture workflow for kit characters (Roblox SurfaceAppearance: ColorMap, MetalnessMap, RoughnessMap, NormalMap).
#   1. UV atlas: every (group, kind) object is unwrapped and packed into ONE atlas (equal texel density).
#   2. Cycles bakes (all objects into the same images): world position, shading normal, ambient occlusion, bevel-edge masks at 3 radii,
#      and a material-kind ID. These maps carry the geometry's information into texture space.
#   3. numpy composes the real maps from them: gunmetal with low-frequency mottling and brushed streaks, edge wear (polished steel on convex edges),
#      crevice darkening and grime (AO), scratches and dents, engraved border lines that follow every plate outline, regional ornament
#      (fluting on the pauldrons, vent slots and brow line on the helm, filigree bands on the breastplate), heraldic paint on the shield,
#      cloth weave, leather grain, aged gold. Height -> tangent-space normal map.
#   4. Final materials use the maps; parts are merged per group (one MeshPart per animated group) and exported to GLB.
import math
import os

import bpy
import numpy as np

# material-kind ids (the ID bake stores id / 16)
KIND_ID = {"Plate": 1, "Dark": 2, "Trim": 3, "Gold": 4, "Blue": 5, "Cloth": 6, "Leather": 7, "Blade": 8, "Glow": 9}
ID_KIND = {v: k for k, v in KIND_ID.items()}


# ------------------------------------------------------------------ UV atlas
def unwrap_pack(objs, margin=0.004, angle=62.0):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=margin, area_weight=0.6, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(margin=margin, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")


# ------------------------------------------------------------------ baking
_GPU = None


def _gpu():
    """Enable the first OptiX / CUDA device for baking (an RTX card makes the AO and bevel bakes minutes instead of tens of minutes)."""
    global _GPU
    if _GPU is not None:
        return _GPU
    _GPU = False
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for kind in ("OPTIX", "CUDA"):
            try:
                prefs.compute_device_type = kind
                prefs.refresh_devices() if hasattr(prefs, "refresh_devices") else None
                devs = [d for d in prefs.devices if d.type == kind]
                if devs:
                    for d in prefs.devices:
                        d.use = d.type == kind
                    _GPU = True
                    print("BAKE gpu", kind, [d.name for d in devs], flush=True)
                    break
            except Exception as e:
                print("BAKE gpu", kind, "failed", e)
    except Exception as e:
        print("BAKE no gpu", e)
    return _GPU


def _bake_material(name, build, image):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    colour = build(nt)
    nt.links.new(colour, emit.inputs["Color"])
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    nt.nodes.active = tex
    return mat


def _bake(objs, mat, image, samples=1, kind="EMIT", margin=10):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = samples
    sc.cycles.device = "GPU" if _gpu() else "CPU"
    sc.render.bake.margin = margin
    sc.render.bake.margin_type = "EXTEND"
    sc.render.bake.use_selected_to_active = False
    for ob in objs:
        ob.data.materials.clear()
        ob.data.materials.append(mat)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.bake(type=kind, use_clear=True)


def _arr(image):
    n = image.size[0] * image.size[1] * 4
    a = np.empty(n, dtype=np.float32)
    image.pixels.foreach_get(a)
    return a.reshape(image.size[1], image.size[0], 4)


def joined_copy(objs):
    """One mesh object holding duplicates of all parts, with per-vertex attributes mid / gid taken from the objects' custom properties.
    Baking a single object is orders of magnitude faster than baking 70 objects into one image (each object re-processes the whole image)."""
    dups = []
    for ob in objs:
        d = ob.copy()
        d.data = ob.data.copy()
        bpy.context.scene.collection.objects.link(d)
        n = len(d.data.vertices)
        for key in ("mid", "gid"):
            at = d.data.attributes.new(key, "FLOAT", "POINT")
            at.data.foreach_set("value", [float(ob[key])] * n)
        dups.append(d)
    bpy.ops.object.select_all(action="DESELECT")
    for d in dups:
        d.select_set(True)
    bpy.context.view_layer.objects.active = dups[0]
    bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def bake_maps(objs, res=2048, ao_samples=32):
    """Returns dict of float arrays (H, W, 4): pos (Blender world position), nrm (0..1 encoded), ao, e1, e2, e3, idm."""
    sc = bpy.context.scene
    imgs = {}
    for k in ("pos", "nrm", "idm", "gid", "ao", "e1", "e2", "e3"):
        imgs[k] = bpy.data.images.new("bk_" + k, res, res, float_buffer=True)
        imgs[k].colorspace_settings.name = "Non-Color"

    def geo(nt, out):
        g = nt.nodes.new("ShaderNodeNewGeometry")
        return g.outputs[out]

    def pos_build(nt):
        return geo(nt, "Position")

    def nrm_build(nt):
        g = nt.nodes.new("ShaderNodeNewGeometry")
        m = nt.nodes.new("ShaderNodeVectorMath"); m.operation = "MULTIPLY_ADD"
        m.inputs[1].default_value = (0.5, 0.5, 0.5); m.inputs[2].default_value = (0.5, 0.5, 0.5)
        nt.links.new(g.outputs["Normal"], m.inputs[0])
        return m.outputs["Vector"]

    def attr_build(name):
        def f(nt):
            a = nt.nodes.new("ShaderNodeAttribute"); a.attribute_type = "GEOMETRY"; a.attribute_name = name
            return _scalar_to_color(nt, a.outputs["Fac"])
        return f

    def edge_build(radius):
        def f(nt):
            bv = nt.nodes.new("ShaderNodeBevel"); bv.inputs["Radius"].default_value = radius; bv.samples = 4
            g = nt.nodes.new("ShaderNodeNewGeometry")
            d = nt.nodes.new("ShaderNodeVectorMath"); d.operation = "DOT_PRODUCT"
            nt.links.new(bv.outputs["Normal"], d.inputs[0]); nt.links.new(g.outputs["Normal"], d.inputs[1])
            inv = nt.nodes.new("ShaderNodeMath"); inv.operation = "SUBTRACT"; inv.inputs[0].default_value = 1.0
            nt.links.new(d.outputs["Value"], inv.inputs[1])
            return _scalar_to_color(nt, inv.outputs["Value"])
        return f

    def ao_build(nt):
        ao = nt.nodes.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.9; ao.samples = 16
        return ao.outputs["Color"]

    import time
    plan = [("pos", pos_build, 1), ("nrm", nrm_build, 1), ("idm", attr_build("mid"), 1), ("gid", attr_build("gid"), 1), ("e1", edge_build(0.035), 12), ("e2", edge_build(0.08), 12), ("e3", edge_build(0.16), 12), ("ao", ao_build, ao_samples)]
    for key, build, samples in plan:
        t0 = time.time()
        mat = _bake_material("bake_" + key, build, imgs[key])
        _bake(objs, mat, imgs[key], samples=samples)
        print("BAKE pass", key, round(time.time() - t0, 1), "s", flush=True)
    return {k: _arr(v) for k, v in imgs.items()}


def bake_joined(objs, **kw):
    joined = joined_copy(objs)
    try:
        return bake_maps([joined], **kw)
    finally:
        bpy.data.objects.remove(joined, do_unlink=True)


def _scalar_to_color(nt, sock):
    c = nt.nodes.new("ShaderNodeCombineColor")
    for n in ("Red", "Green", "Blue"):
        nt.links.new(sock, c.inputs[n])
    return c.outputs["Color"]


# ------------------------------------------------------------------ numpy noise (vectorised, seamless in 3-D position space)
def _hash3(ix, iy, iz, seed):
    h = (ix * 374761393 + iy * 668265263 + iz * 2147483647 + seed * 1274126177) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return (h & 0xFFFF).astype(np.float32) / 65535.0


def vnoise(p, freq, seed=0):
    """Trilinear value noise at 3-D points p (N, 3) scaled by freq, values 0..1."""
    q = p * freq
    i = np.floor(q).astype(np.int64)
    f = (q - i).astype(np.float32)
    f = f * f * (3 - 2 * f)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out = out + w * _hash3(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out


def fbm(p, freq, octaves=4, seed=0):
    tot, amp, norm = 0.0, 0.5, 0.0
    for o in range(octaves):
        tot = tot + amp * vnoise(p, freq * (2 ** o), seed + o)
        norm += amp
        amp *= 0.5
    return tot / norm


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)
