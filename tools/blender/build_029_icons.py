# Milestone 029 UI icons (D14), built from code in headless Blender (no downloads, all original):
#   flatpak run org.blender.Blender -b -P tools/blender/build_029_icons.py [-- name name ...]
# Chunky glossy shapes with a thick dark outline (inverted hull), soft studio light, slight tilt.
# Renders each icon to assets/export/ui/icons/<name>.png (256x256, transparent). Pack them into
# sprite sheets with tools/blender/pack_029_icons.py.
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix, Euler

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "export", "ui", "icons")
os.makedirs(OUT, exist_ok=True)
SIZE = 256
OUTLINE = (0.075, 0.06, 0.1)  # charcoal
OUTLINE_PX = 7  # outline thickness in pixels at 256

PALETTE = {
    "gold": (1.0, 0.74, 0.12), "goldDark": (0.85, 0.48, 0.05), "cream": (1.0, 0.95, 0.82),
    "white": (0.97, 0.97, 0.99), "green": (0.30, 0.82, 0.30), "greenDark": (0.10, 0.50, 0.18),
    "red": (0.95, 0.20, 0.22), "blue": (0.22, 0.58, 1.0), "cyan": (0.30, 0.90, 1.0),
    "purple": (0.60, 0.32, 0.95), "orange": (1.0, 0.52, 0.12), "pink": (1.0, 0.45, 0.70),
    "grey": (0.62, 0.66, 0.74), "greyDark": (0.30, 0.33, 0.40), "wood": (0.78, 0.50, 0.25),
    "woodDark": (0.50, 0.30, 0.14), "charcoal": (0.13, 0.12, 0.16), "sand": (1.0, 0.82, 0.35),
    "sky": (0.55, 0.80, 1.0), "yellow": (1.0, 0.88, 0.20),
}


# Scene ------------------------------------------------------------------------------------------
def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x = scene.render.resolution_y = SIZE
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError as err:
        print("VIEW", err)
    print("VIEW", scene.view_settings.view_transform)
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (1, 1, 1, 1)
    bg.inputs[1].default_value = 0.35
    scene.world = world

    def light(name, energy, loc, size):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size = energy, size
        ob = bpy.data.objects.new(name, data)
        ob.location = loc
        ob.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(ob)

    light("Key", 700, (-4, -6, 7), 5)
    light("Fill", 160, (6, -5, 1), 6)
    light("Rim", 400, (2, 6, 5), 4)

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.rotation_euler = (math.radians(90), 0, 0)  # looks along +Y
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene, cam


_mats = {}


def mat(key, rough=0.32):
    name = f"{key}_{rough}"
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    p.inputs["Base Color"].default_value = (*[c**2.2 for c in PALETTE[key]], 1)  # palette is sRGB
    p.inputs["Roughness"].default_value = rough
    for label, value in (("Coat Weight", 0.25), ("Coat Roughness", 0.12)):
        if label in p.inputs:
            p.inputs[label].default_value = value
    _mats[name] = m
    return m


def outline_mat():
    if "Outline" in _mats:
        return _mats["Outline"]
    m = bpy.data.materials.new("Outline")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs[0].default_value = (*[c**2.2 for c in OUTLINE], 1)
    clear = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    # Only camera rays see the shell (its back side); light and bounce rays pass through it.
    path = nt.nodes.new("ShaderNodeLightPath")
    notcam = nt.nodes.new("ShaderNodeMath")
    notcam.operation = "SUBTRACT"
    notcam.inputs[0].default_value = 1
    nt.links.new(path.outputs["Is Camera Ray"], notcam.inputs[1])
    either = nt.nodes.new("ShaderNodeMath")
    either.operation = "MAXIMUM"
    nt.links.new(geo.outputs["Backfacing"], either.inputs[0])
    nt.links.new(notcam.outputs[0], either.inputs[1])
    nt.links.new(either.outputs[0], mix.inputs[0])
    nt.links.new(emit.outputs[0], mix.inputs[1])
    nt.links.new(clear.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    _mats["Outline"] = m
    return m


# Shapes (all built in world units; parts are parented to one tilted root) -----------------------------
class Icon:
    def __init__(self, scene):
        self.scene = scene
        self.root = bpy.data.objects.new("Root", None)
        scene.collection.objects.link(self.root)
        self.parts = []

    def _add(self, bm, material, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.06, segments=3, smooth=True):
        mesh = bpy.data.meshes.new("part")
        bm.normal_update()
        bm.to_mesh(mesh)
        bm.free()
        for poly in mesh.polygons:
            poly.use_smooth = smooth
        ob = bpy.data.objects.new("part", mesh)
        mesh.materials.append(material)
        ob.location = loc
        ob.rotation_euler = [math.radians(a) for a in rot]
        ob.parent = self.root
        self.scene.collection.objects.link(ob)
        if bevel > 0:
            mod = ob.modifiers.new("Bevel", "BEVEL")
            mod.width, mod.segments, mod.limit_method = bevel, segments, "ANGLE"
            mod.harden_normals = False
        self.parts.append(ob)
        return ob

    def box(self, size, material, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.08):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1)
        bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
        return self._add(bm, material, loc, rot, min(bevel, min(size) * 0.45))

    def cyl(self, r, depth, material, loc=(0, 0, 0), rot=(0, 0, 0), r2=None, segs=40, bevel=0.05):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=depth)
        return self._add(bm, material, loc, rot, min(bevel, depth * 0.45))

    def sphere(self, r, material, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0)):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=20, radius=r)
        bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
        return self._add(bm, material, loc, rot, 0)

    def torus(self, R, r, material, loc=(0, 0, 0), rot=(0, 0, 0), arc=(0, 360), segs=48, ring=16):
        # Ring in the XZ plane (faces the camera), from angle arc[0] to arc[1] (degrees, 0 = +X).
        bm = bmesh.new()
        full = (arc[1] - arc[0]) >= 360
        n = segs if full else max(4, int(segs * (arc[1] - arc[0]) / 360))
        rings = []
        for i in range(n if full else n + 1):
            a = math.radians(arc[0] + (arc[1] - arc[0]) * i / n)
            centre = Vector((math.cos(a) * R, 0, math.sin(a) * R))
            out = Vector((math.cos(a), 0, math.sin(a)))
            loop = []
            for j in range(ring):
                b = 2 * math.pi * j / ring
                loop.append(bm.verts.new(centre + out * (math.cos(b) * r) + Vector((0, math.sin(b) * r, 0))))
            rings.append(loop)
        count = len(rings)
        for i in range(count if full else count - 1):
            a, b = rings[i], rings[(i + 1) % count]
            for j in range(ring):
                bm.faces.new((a[j], a[(j + 1) % ring], b[(j + 1) % ring], b[j]))
        if not full:
            bm.faces.new(rings[0][::-1])
            bm.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return self._add(bm, material, loc, rot, 0)

    def prism(self, points, depth, material, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.05):
        # Flat shape from (x, z) points, extruded along Y (towards / away from the camera).
        bm = bmesh.new()
        front = [bm.verts.new((x, -depth / 2, z)) for x, z in points]
        back = [bm.verts.new((x, depth / 2, z)) for x, z in points]
        bm.faces.new(front)
        bm.faces.new(back[::-1])
        k = len(points)
        for i in range(k):
            bm.faces.new((front[i], back[i], back[(i + 1) % k], front[(i + 1) % k]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
        return self._add(bm, material, loc, rot, bevel, segments=2, smooth=False)

    def text(self, body, size, material, loc=(0, 0, 0), extrude=0.12, rot=(0, 0, 0)):
        curve = bpy.data.curves.new("txt", "FONT")
        curve.body = body
        curve.size = size
        curve.extrude = extrude
        curve.bevel_depth = 0.012
        curve.offset = 0.012 * size / 0.6  # bolder strokes
        curve.align_x, curve.align_y = "CENTER", "CENTER"
        tmp = bpy.data.objects.new("tmp", curve)
        self.scene.collection.objects.link(tmp)
        bpy.context.view_layer.update()
        mesh = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
        bpy.data.objects.remove(tmp)
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "X"), verts=bm.verts)  # face -Y
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
        ob = self._add(bm, material, loc, rot, 0, smooth=False)
        ob["noOutline"] = True  # glyph strokes overlap: a shell would draw lines inside the letters
        return ob


def star_points(n, outer, inner, start=90):
    pts = []
    for i in range(n * 2):
        a = math.radians(start + 180 * i / n)
        r = outer if i % 2 == 0 else inner
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return pts


def cross_points(arm, half, rot=0):
    pts = [(-half, arm), (half, arm), (half, half), (arm, half), (arm, -half), (half, -half), (half, -arm), (-half, -arm), (-half, -half), (-arm, -half), (-arm, half), (-half, half)]
    c, s_ = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    return [(x * c - z * s_, x * s_ + z * c) for x, z in pts]


def arc_band(r_in, r_out, a0, a1, segs=24):
    outer = [(math.cos(math.radians(a0 + (a1 - a0) * i / segs)) * r_out, math.sin(math.radians(a0 + (a1 - a0) * i / segs)) * r_out) for i in range(segs + 1)]
    inner = [(math.cos(math.radians(a0 + (a1 - a0) * i / segs)) * r_in, math.sin(math.radians(a0 + (a1 - a0) * i / segs)) * r_in) for i in range(segs + 1)]
    return outer + inner[::-1]


# Icons ------------------------------------------------------------------------------------------
def i_cash(I):
    for k, ry in enumerate((-14, -4, 8)):
        I.box((1.9, 0.12, 1.0), mat("green"), (0.05 * k, -0.16 * k, -0.05 * k), (0, ry, 0), bevel=0.05)
    I.box((1.9, 0.12, 1.0), mat("green"), (0.12, -0.5, -0.12), (0, 4, 0), bevel=0.05)
    I.cyl(0.4, 0.06, mat("greenDark"), (0.15, -0.58, -0.12), (90, 0, 0), bevel=0.02)
    I.text("$", 0.72, mat("cream"), (0.15, -0.63, -0.14), extrude=0.03)
    I.box((0.28, 0.16, 1.06), mat("gold"), (-0.45, -0.5, -0.15), (0, 4, 0), bevel=0.04)


def i_coin(I):
    I.cyl(1.0, 0.32, mat("gold"), rot=(90, 0, 0), bevel=0.1)
    I.cyl(0.74, 0.06, mat("goldDark"), (0, -0.17, 0), (90, 0, 0), bevel=0.02)
    I.text("$", 1.2, mat("yellow"), (0, -0.25, 0.0), extrude=0.06)


def i_gem(I):
    bm = bmesh.new()
    top_r, mid_r, h_top, h_bot, n = 0.62, 1.0, 0.42, 0.95, 8
    top = [bm.verts.new((math.cos(2 * math.pi * i / n + math.pi / 8) * top_r, math.sin(2 * math.pi * i / n + math.pi / 8) * top_r, h_top)) for i in range(n)]
    mid = [bm.verts.new((math.cos(2 * math.pi * i / n + math.pi / 8) * mid_r, math.sin(2 * math.pi * i / n + math.pi / 8) * mid_r, 0)) for i in range(n)]
    tip = bm.verts.new((0, 0, -h_bot))
    bm.faces.new(top)
    for i in range(n):
        bm.faces.new((top[i], mid[i], mid[(i + 1) % n], top[(i + 1) % n]))
        bm.faces.new((mid[i], tip, mid[(i + 1) % n]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    I._add(bm, mat("cyan", 0.1), (0, 0, 0.1), (-18, 0, 0), bevel=0.02, smooth=False)


def i_shop(I):
    I.box((2.0, 1.0, 0.9), mat("cream"), (0, 0, -0.55))
    I.box((2.1, 1.1, 0.18), mat("wood"), (0, 0, -0.05))
    for x in (-0.85, 0.85):
        I.cyl(0.07, 1.0, mat("wood"), (x, -0.35, 0.45))
    for k in range(5):
        I.box((0.44, 1.2, 0.36), mat("red" if k % 2 == 0 else "white"), (-0.84 + k * 0.42, -0.15, 1.0), (-14, 0, 0), bevel=0.06)
    I.box((0.6, 0.1, 0.4), mat("gold"), (0, -0.52, -0.55), bevel=0.05)


def i_backpack(I):
    I.box((1.5, 0.8, 1.8), mat("orange"), bevel=0.32)
    I.box((1.0, 0.3, 0.75), mat("goldDark"), (0, -0.45, -0.35), bevel=0.15)
    I.box((1.52, 0.86, 0.62), mat("red"), (0, -0.02, 0.62), bevel=0.25)
    I.torus(0.32, 0.08, mat("charcoal"), (0, 0, 1.0), arc=(0, 180))
    I.box((0.22, 0.1, 0.22), mat("gold"), (0, -0.46, 0.32), bevel=0.05)


def i_book(I):
    I.box((1.55, 0.36, 1.95), mat("cream"), (0.06, 0.02, 0))
    I.box((1.6, 0.12, 2.05), mat("purple"), (0, -0.2, 0), bevel=0.06)
    I.box((1.6, 0.12, 2.05), mat("purple"), (0.02, 0.22, 0), bevel=0.06)
    I.box((0.22, 0.56, 2.05), mat("purple"), (-0.78, 0.01, 0), bevel=0.08)
    I.prism(star_points(5, 0.5, 0.22), 0.1, mat("gold"), (0.1, -0.3, 0.1))


def i_gift(I):
    I.box((1.7, 1.2, 1.3), mat("red"), (0, 0, -0.4))
    I.box((1.9, 1.35, 0.42), mat("red"), (0, 0, 0.38))
    I.box((0.34, 1.4, 1.75), mat("gold"), (0, 0, -0.17), bevel=0.04)
    I.torus(0.34, 0.12, mat("gold"), (-0.33, 0, 0.82), (0, 25, 0))
    I.torus(0.34, 0.12, mat("gold"), (0.33, 0, 0.82), (0, -25, 0))


def i_calendar(I):
    I.box((1.9, 0.3, 1.8), mat("white"), (0, 0, -0.1))
    I.box((1.9, 0.34, 0.5), mat("red"), (0, -0.02, 0.72))
    for x in (-0.5, 0.5):
        I.cyl(0.1, 0.5, mat("charcoal"), (x, -0.2, 1.0))
    for r in range(3):
        for c in range(4):
            key = "gold" if (r, c) == (1, 2) else "sky"
            I.box((0.3, 0.08, 0.26), mat(key), (-0.6 + c * 0.4, -0.18, 0.18 - r * 0.42), bevel=0.04)


def i_clock(I):
    I.cyl(1.0, 0.3, mat("white"), rot=(90, 0, 0), bevel=0.05)
    I.torus(1.0, 0.16, mat("blue"))
    I.box((0.14, 0.08, 0.62), mat("charcoal"), (0, -0.2, 0.26), bevel=0.03)
    I.box((0.5, 0.08, 0.14), mat("charcoal"), (0.22, -0.2, 0), bevel=0.03)
    I.cyl(0.12, 0.1, mat("red"), (0, -0.24, 0), (90, 0, 0))
    for k in range(4):
        a = math.radians(90 * k)
        I.cyl(0.07, 0.06, mat("greyDark"), (math.cos(a) * 0.72, -0.18, math.sin(a) * 0.72), (90, 0, 0))


def i_gear(I):
    I.cyl(0.78, 0.4, mat("grey"), rot=(90, 0, 0), bevel=0.06)
    for k in range(8):
        a = 360 * k / 8
        r = math.radians(a)
        I.box((0.36, 0.4, 0.42), mat("grey"), (math.cos(r) * 0.85, 0, math.sin(r) * 0.85), (0, -a, 0), bevel=0.07)
    I.cyl(0.3, 0.44, mat("greyDark"), rot=(90, 0, 0), bevel=0.04)


def i_close(I):
    I.prism(cross_points(1.05, 0.3, 45), 0.5, mat("red"), bevel=0.14)


def i_lock(I):
    I.torus(0.55, 0.16, mat("grey"), (0, 0, 0.35), arc=(0, 180))
    I.box((0.32, 0.32, 0.4), mat("grey"), (-0.55, 0, 0.2), bevel=0.1)
    I.box((0.32, 0.32, 0.4), mat("grey"), (0.55, 0, 0.2), bevel=0.1)
    I.box((1.7, 0.7, 1.35), mat("gold"), (0, 0, -0.45), bevel=0.22)
    I.cyl(0.16, 0.1, mat("charcoal"), (0, -0.36, -0.35), (90, 0, 0))
    I.box((0.12, 0.1, 0.36), mat("charcoal"), (0, -0.36, -0.58), bevel=0.03)


def i_check(I):
    I.prism([(-1.0, 0.1), (-0.55, 0.5), (-0.25, 0.15), (0.65, 1.0), (1.05, 0.6), (-0.25, -0.75)], 0.5, mat("green"), bevel=0.1)


def i_star(I):
    I.prism(star_points(5, 1.05, 0.48), 0.5, mat("gold"), bevel=0.12)


def i_trophy(I):
    I.cyl(0.75, 0.9, mat("gold"), (0, 0, 0.45), r2=None, bevel=0.05)
    I.cyl(0.42, 0.5, mat("gold"), (0, 0, -0.18), r2=0.75, bevel=0.03)
    I.torus(0.32, 0.1, mat("gold"), (-0.78, 0, 0.45), arc=(90, 270))
    I.torus(0.32, 0.1, mat("gold"), (0.78, 0, 0.45), arc=(-90, 90))
    I.cyl(0.14, 0.4, mat("goldDark"), (0, 0, -0.55))
    I.box((1.0, 0.7, 0.3), mat("woodDark"), (0, 0, -0.85), bevel=0.08)
    I.prism(star_points(5, 0.3, 0.13), 0.1, mat("yellow"), (0, -0.78, 0.48))


def i_arena(I):
    for a, key in ((40, "wood"), (-40, "wood")):
        bat = I.cyl(0.13, 2.2, mat(key), rot=(0, a, 0), r2=0.26, bevel=0.06)
        r = math.radians(a)
        I.cyl(0.15, 0.55, mat("red"), (-math.sin(r) * -0.85, 0, -math.cos(r) * 0.85), (0, a, 0), bevel=0.04)
    I.prism(star_points(5, 0.32, 0.14), 0.2, mat("yellow"), (0, -0.3, 0.75))


def i_base(I):
    I.box((1.6, 1.2, 1.2), mat("cream"), (0, 0, -0.45))
    I.prism([(-1.05, 0), (0, 0.85), (1.05, 0)], 1.4, mat("red"), (0, 0, 0.12), bevel=0.08)
    I.box((0.5, 0.1, 0.75), mat("wood"), (0, -0.6, -0.68), bevel=0.06)
    I.box((0.36, 0.1, 0.36), mat("sky"), (-0.5, -0.6, -0.3), bevel=0.05)
    I.box((0.36, 0.1, 0.36), mat("sky"), (0.5, -0.6, -0.3), bevel=0.05)


def i_parade(I):
    I.box((1.7, 1.5, 1.7), mat("purple"), (0, 0, -0.1), bevel=0.2)
    I.box((1.8, 1.6, 0.36), mat("pink"), (0, 0, 0.66), bevel=0.12)
    I.text("?", 1.55, mat("yellow"), (0, -0.8, -0.12), extrude=0.08)


def i_2x(I):
    I.cyl(1.05, 0.3, mat("green"), rot=(90, 0, 0), bevel=0.08)
    I.text("2x", 1.25, mat("yellow"), (0, -0.2, 0.0), extrude=0.08)


def i_vip(I):
    base = [(-1.0, -0.55), (1.0, -0.55), (1.08, 0.75), (0.5, 0.2), (0, 0.95), (-0.5, 0.2), (-1.08, 0.75)]
    I.prism(base, 0.55, mat("gold"), bevel=0.08)
    I.box((2.0, 0.6, 0.3), mat("goldDark"), (0, 0, -0.58), bevel=0.1)
    for x, key in ((-0.55, "red"), (0, "cyan"), (0.55, "red")):
        I.sphere(0.13, mat(key, 0.1), (x, -0.32, -0.58))
    for x, z in ((-1.08, 0.75), (0, 0.95), (1.08, 0.75)):
        I.sphere(0.15, mat("yellow"), (x, 0, z))


def i_slots(I):
    for c in range(2):
        for r in range(2):
            I.box((0.85, 0.3, 0.85), mat("blue"), (-0.48 + c * 0.96, 0, 0.48 - r * 0.96), bevel=0.14)
    I.cyl(0.42, 0.3, mat("green"), (0.62, -0.25, -0.62), (90, 0, 0))
    I.box((0.46, 0.1, 0.12), mat("white"), (0.62, -0.42, -0.62), bevel=0.04)
    I.box((0.12, 0.1, 0.46), mat("white"), (0.62, -0.42, -0.62), bevel=0.04)


def i_plus(I):
    I.prism(cross_points(1.0, 0.32), 0.5, mat("green"), bevel=0.14)


def i_hourglass(I):
    I.box((1.5, 0.8, 0.22), mat("wood"), (0, 0, 1.0), bevel=0.08)
    I.box((1.5, 0.8, 0.22), mat("wood"), (0, 0, -1.0), bevel=0.08)
    I.sphere(0.55, mat("sky", 0.08), (0, 0.05, 0.44), (1.0, 0.7, 0.85))
    I.sphere(0.55, mat("sky", 0.08), (0, 0.05, -0.44), (1.0, 0.7, 0.85))
    I.prism([(-0.36, 0.62), (0.36, 0.62), (0.0, 0.12)], 0.08, mat("sand"), (0, -0.38, 0), bevel=0.02)
    I.prism([(-0.48, -0.86), (0.48, -0.86), (0.3, -0.55), (0.0, -0.42), (-0.3, -0.55)], 0.08, mat("sand"), (0, -0.38, 0), bevel=0.02)
    for x in (-0.62, 0.62):
        I.cyl(0.07, 2.0, mat("woodDark"), (x, -0.32, 0))


def i_moon(I):
    # Crescent = unit circle minus a circle at (cx, cz) radius r2, both arcs ending where they cross.
    cx, cz, r2 = 0.42, 0.22, 0.8
    d = math.hypot(cx, cz)
    base = math.atan2(cz, cx)
    half = math.acos((1 + d * d - r2 * r2) / (2 * d))  # angle at the origin to the crossing points
    p1, p2 = base + half, base - half + 2 * math.pi
    pts = [(math.cos(p1 + (p2 - p1) * i / 40), math.sin(p1 + (p2 - p1) * i / 40)) for i in range(41)]
    q1 = math.atan2(math.sin(p2) - cz, math.cos(p2) - cx)
    q2 = math.atan2(math.sin(p1) - cz, math.cos(p1) - cx)
    while q2 > q1:
        q2 -= 2 * math.pi
    pts += [(cx + math.cos(q1 + (q2 - q1) * i / 40) * r2, cz + math.sin(q1 + (q2 - q1) * i / 40) * r2) for i in range(1, 40)]
    I.prism(pts, 0.5, mat("yellow"), (-0.15, 0, 0), bevel=0.04)
    I.prism(star_points(4, 0.32, 0.1), 0.15, mat("white"), (0.75, -0.1, 0.65), bevel=0.03)
    I.prism(star_points(4, 0.2, 0.07), 0.15, mat("white"), (0.95, -0.1, -0.05), bevel=0.02)


def i_music(I):
    I.sphere(0.36, mat("purple"), (-0.55, 0, -0.7), (1.2, 0.8, 0.9), (0, -20, 0))
    I.sphere(0.36, mat("purple"), (0.7, 0, -0.45), (1.2, 0.8, 0.9), (0, -20, 0))
    I.box((0.16, 0.3, 1.6), mat("purple"), (-0.18, 0, 0.1), bevel=0.06)
    I.box((0.16, 0.3, 1.6), mat("purple"), (1.06, 0, 0.35), bevel=0.06)
    I.box((1.42, 0.3, 0.3), mat("purple"), (0.44, 0, 1.02), (0, -12, 0), bevel=0.1)


def i_speaker(I):
    I.box((0.55, 0.6, 0.75), mat("blue"), (-0.75, 0, 0), bevel=0.1)
    I.prism([(-0.5, -0.35), (0.25, -0.95), (0.25, 0.95), (-0.5, 0.35)], 0.7, mat("blue"), bevel=0.08)
    I.prism(arc_band(0.55, 0.75, -45, 45), 0.3, mat("charcoal"), (0.25, 0, 0), bevel=0.04)
    I.prism(arc_band(0.95, 1.15, -45, 45), 0.3, mat("charcoal"), (0.25, 0, 0), bevel=0.04)


def i_sparkle(I):
    I.prism(star_points(4, 1.05, 0.28), 0.4, mat("yellow"), (-0.15, 0, -0.1), bevel=0.06)
    I.prism(star_points(4, 0.45, 0.13), 0.3, mat("cyan"), (0.85, -0.1, 0.8), bevel=0.04)
    I.prism(star_points(4, 0.3, 0.1), 0.3, mat("pink"), (0.85, -0.1, -0.75), bevel=0.03)


def i_quest(I):
    I.box((1.5, 0.2, 2.0), mat("wood"), bevel=0.12)
    I.box((1.2, 0.1, 1.6), mat("white"), (0, -0.14, -0.1), bevel=0.04)
    I.box((0.7, 0.3, 0.3), mat("grey"), (0, -0.1, 0.95), bevel=0.1)
    for k in range(3):
        z = 0.38 - k * 0.48
        I.prism([(-0.48, 0.0), (-0.38, 0.1), (-0.3, 0.02), (-0.12, 0.2), (-0.03, 0.11), (-0.3, -0.16)], 0.08, mat("green"), (0, -0.22, z), bevel=0.01)
        I.box((0.55, 0.06, 0.1), mat("greyDark"), (0.2, -0.21, z + 0.02), bevel=0.03)


def i_lightning(I):
    I.prism([(0.2, 1.1), (-0.65, -0.05), (-0.08, -0.05), (-0.35, -1.1), (0.7, 0.25), (0.12, 0.25), (0.55, 1.1)], 0.45, mat("yellow"), bevel=0.06)


def i_flag(I):
    I.cyl(0.08, 2.2, mat("greyDark"), (-0.7, 0, 0))
    I.sphere(0.16, mat("gold"), (-0.7, 0, 1.12))
    I.prism([(-0.62, 1.0), (1.0, 0.55), (-0.62, 0.05)], 0.18, mat("green"), bevel=0.05)
    I.prism([(-0.62, 0.68), (0.35, 0.55), (-0.62, 0.42)], 0.06, mat("white"), (0, -0.12, 0), bevel=0.0)
    I.cyl(0.4, 0.15, mat("greyDark"), (-0.7, 0, -1.1))


def i_heart(I):
    pts = []
    for i in range(41):
        t = 2 * math.pi * i / 40
        x = 16 * math.sin(t) ** 3
        z = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x / 16, z / 16))
    I.prism(pts[:-1], 0.5, mat("pink"), bevel=0.1)


ICONS = [
    ("cash", i_cash), ("coin", i_coin), ("gem", i_gem), ("shop", i_shop), ("backpack", i_backpack),
    ("book", i_book), ("gift", i_gift), ("calendar", i_calendar), ("clock", i_clock), ("settings", i_gear),
    ("close", i_close), ("lock", i_lock), ("check", i_check), ("star", i_star), ("trophy", i_trophy),
    ("arena", i_arena), ("base", i_base), ("parade", i_parade), ("x2", i_2x), ("vip", i_vip),
    ("slots", i_slots), ("plus", i_plus), ("hourglass", i_hourglass), ("moon", i_moon), ("music", i_music),
    ("sound", i_speaker), ("sparkle", i_sparkle), ("quest", i_quest), ("bolt", i_lightning), ("flag", i_flag),
    ("heart", i_heart),
]
TILT = {"close": (0, 0, 0), "check": (0, 0, 0), "plus": (0, 0, 0)}  # flat symbols: barely tilted


def render(name, build):
    scene, cam = setup_scene()
    _mats.clear()
    icon = Icon(scene)
    build(icon)
    tilt = TILT.get(name, (10, 0, -16))
    icon.root.rotation_euler = Euler([math.radians(a) for a in tilt])
    bpy.context.view_layer.update()
    lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    deps = bpy.context.evaluated_depsgraph_get()
    for ob in icon.parts:
        ev = ob.evaluated_get(deps)
        for v in ev.to_mesh().vertices:
            w = ob.matrix_world @ v.co
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
        ev.to_mesh_clear()
    span = max(hi.x - lo.x, hi.z - lo.z)
    ortho = span / (1 - 2 * (OUTLINE_PX + 10) / SIZE)
    cam.data.ortho_scale = ortho
    cam.location = ((lo.x + hi.x) / 2, lo.y - 10, (lo.z + hi.z) / 2)
    thickness = ortho * OUTLINE_PX / SIZE
    om = outline_mat()
    for ob in icon.parts:
        if ob.get("noOutline"):
            continue
        ob.data.materials.append(om)
        mod = ob.modifiers.new("Outline", "SOLIDIFY")
        mod.thickness, mod.offset, mod.use_flip_normals, mod.use_rim = thickness, 1, True, False
        mod.material_offset = len(ob.data.materials) - 1
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("ICON", name, "ok")


wanted = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
for name, build in ICONS:
    if not wanted or name in wanted:
        render(name, build)
