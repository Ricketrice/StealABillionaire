# kit035.studio - Blender render setup for contact sheets and idle/signature frames (EEVEE, transparent background; the
# sheets are composed with PIL afterwards by tools/blender/assemble_b1_035.py). Character frame: front = Blender -Y, right = Blender -X.
import math
import os

import bpy
from mathutils import Vector

from . import geo
from .char import hexc
from .body import noob_meshes

V = Vector


def setup(res=480, samples=24):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
    try:
        sc.eevee.taa_render_samples = samples
    except Exception:
        pass
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes["Background"].inputs
    bg[0].default_value, bg[1].default_value = (0.82, 0.85, 0.92, 1), 0.75
    for loc, en, rot in (
        ((6, -9, 10), 2.6, (math.radians(52), 0, math.radians(32))),  # key: front, from the character's left
        ((-8, -4, 6), 0.9, (math.radians(70), 0, math.radians(-55))),  # fill
        ((0, 9, 7), 1.4, (math.radians(125), 0, math.radians(180))),  # rim from behind
    ):
        bpy.ops.object.light_add(type="SUN", location=loc)
        L = bpy.context.active_object
        L.data.energy, L.rotation_euler = en, rot
    bpy.ops.object.camera_add()
    sc.camera = bpy.context.active_object
    sc.render.resolution_x = sc.render.resolution_y = res
    return sc


def noob_objects(offset_x=0.0):
    """The classic noob (game rig proportions) as Blender objects at A-frame x = offset_x; returns the list."""
    objs = []
    for name, m, hx in noob_meshes():
        m = m.copy().move(offset_x, 0, 0)
        ob = geo.to_object("REF_" + name, m, smooth_angle=30)
        mat = bpy.data.materials.new("REF_" + name + hx)
        mat.use_nodes = True
        b = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        b.inputs["Base Color"].default_value = hexc(hx)
        b.inputs["Roughness"].default_value = 0.6
        ob.data.materials.append(mat)
        objs.append(ob)
    return objs


def bounds(objs):
    lo = V((1e9, 1e9, 1e9))
    hi = V((-1e9, -1e9, -1e9))
    for ob in objs:
        for v in ob.data.vertices:
            p = ob.matrix_world @ v.co
            lo = V((min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z)))
            hi = V((max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z)))
    return lo, hi


def aim(sc, target, az_deg, el_deg, dist, lens=70.0):
    """Camera on a sphere around target: az 0 = in front of the character (Blender -Y), +az swings toward Blender +X
    (the character's LEFT), 180 = behind; el = degrees above the horizon."""
    cam = sc.camera
    cam.data.lens = lens
    a, e = math.radians(az_deg), math.radians(el_deg)
    d = V((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    cam.location = V(target) + d * dist
    cam.rotation_euler = (V(target) - cam.location).to_track_quat("-Z", "Y").to_euler()


def fit_dist(lo, hi, lens=70.0, margin=1.12, aspect=1.0):
    h = max(hi.z - lo.z, (hi.x - lo.x) / aspect, 1.0) * margin
    fov = 2 * math.atan(18.0 / lens)
    return (h / 2) / math.tan(fov / 2) + max(hi.y - lo.y, hi.x - lo.x) * 0.5


def shoot(sc, path, res=None):
    if res:
        sc.render.resolution_x = sc.render.resolution_y = res
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
