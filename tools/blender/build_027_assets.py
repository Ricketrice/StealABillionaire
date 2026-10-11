# Milestone 027 hero meshes, built from code in headless Blender (no downloads, all original):
#   flatpak run org.blender.Blender -b -P tools/blender/build_027_assets.py
# 1 BU = 1 stud, Y-up after export. Each asset is an Empty with one mesh object per material
# (Studio recolours them by object name). Low poly, flat shaded. Writes assets/export/027/<Asset>.fbx
# and assets/export/027/preview.png (Workbench render of every asset side by side).
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "export", "027")
os.makedirs(OUT, exist_ok=True)
random.seed(27)

COLOURS = {  # preview only; Studio sets the real colours from its palette
    "Trunk": (0.42, 0.27, 0.16), "Canopy": (0.36, 0.72, 0.30), "Counter": (0.96, 0.90, 0.78),
    "Posts": (0.95, 0.78, 0.25), "AwningA": (0.97, 0.95, 0.88), "AwningB": (0.90, 0.25, 0.30),
    "Base": (0.55, 0.50, 0.45), "Drum": (0.96, 0.90, 0.78), "Dome": (0.98, 0.75, 0.20),
    "Ribs": (0.85, 0.60, 0.10), "Lantern": (1.0, 0.85, 0.35), "Rock": (0.55, 0.47, 0.42),
    "Post": (0.18, 0.20, 0.24), "Head": (0.95, 0.75, 0.25), "Glass": (1.0, 0.95, 0.75),
}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (*COLOURS.get(name, (0.8, 0.8, 0.8)), 1)
    return mat


def obj_from_bmesh(bm, name, parent):
    mesh = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False
    ob = bpy.data.objects.new(name, mesh)
    ob.data.materials.append(material(name))
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent
    return ob


def empty(name):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    return e


# Blender is Z-up while modelling; export converts to Y-up. "Front" of every asset = -Y in Blender.
def add_blob(bm, centre, radius, squash=1.0, jitter=0.12, subdiv=2):
    ret = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    for v in ret["verts"]:
        v.co *= 1 + random.uniform(-jitter, jitter)
        v.co.z *= squash
        v.co += Vector(centre)


def add_box(bm, centre, size):
    ret = bmesh.ops.create_cube(bm, size=1.0)
    for v in ret["verts"]:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(centre)


def add_cyl(bm, centre, r1, r2, depth, segments=10):
    ret = bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=r1, radius2=r2, depth=depth)
    for v in ret["verts"]:
        v.co += Vector(centre)


def tree(name, trunk_h, trunk_r, blobs):
    root = empty(name)
    bm = bmesh.new()
    add_cyl(bm, (0, 0, trunk_h / 2), trunk_r, trunk_r * 0.7, trunk_h, 8)
    obj_from_bmesh(bm, "Trunk", root)
    bm = bmesh.new()
    for c, r, s in blobs:
        add_blob(bm, c, r, s)
    obj_from_bmesh(bm, "Canopy", root)
    return root


def stall():
    root = empty("Stall")
    w, d = 12.0, 7.0
    bm = bmesh.new()
    add_box(bm, (0, 0, 0.25), (w + 1, d + 1, 0.5))  # plinth
    obj_from_bmesh(bm, "Base", root)
    bm = bmesh.new()
    add_box(bm, (0, -d / 2 + 1.2, 2.0), (w - 0.6, 2.0, 3.0))  # front counter
    add_box(bm, (0, -d / 2 + 1.2, 3.6), (w - 0.2, 2.4, 0.3))  # counter top lip
    add_box(bm, (0, d / 2 - 0.4, 3.0), (w - 0.6, 0.6, 5.0))  # back wall
    obj_from_bmesh(bm, "Counter", root)
    bm = bmesh.new()
    for x in (-w / 2 + 0.4, w / 2 - 0.4):
        for y in (-d / 2 + 0.4, d / 2 - 0.4):
            add_cyl(bm, (x, y, 4.0), 0.3, 0.3, 7.0, 8)
    obj_from_bmesh(bm, "Posts", root)
    # Striped awning sloping toward the front, with a scalloped front edge.
    stripes = 8
    sw = (w + 1.2) / stripes
    for k, label in ((0, "AwningA"), (1, "AwningB")):
        bm = bmesh.new()
        for i in range(k, stripes, 2):
            x0 = -(w + 1.2) / 2 + i * sw
            verts = [bm.verts.new(p) for p in (
                (x0, d / 2 + 0.3, 8.2), (x0 + sw, d / 2 + 0.3, 8.2),
                (x0 + sw, -d / 2 - 1.0, 6.6), (x0, -d / 2 - 1.0, 6.6))]
            top = bm.faces.new(verts)
            ext = bmesh.ops.extrude_face_region(bm, geom=[top])
            for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
                v.co.z -= 0.2
            # scallop: a half-disc under the front edge
            n = 6
            cx, cy, cz = x0 + sw / 2, -d / 2 - 1.0, 6.5
            ring = [bm.verts.new((cx + math.cos(math.pi * j / n) * sw / 2, cy, cz - math.sin(math.pi * j / n) * sw * 0.45)) for j in range(n + 1)]
            bm.faces.new(ring)
        obj_from_bmesh(bm, label, root)
    return root


def vault():
    root = empty("Vault")
    r = 14.0
    bm = bmesh.new()
    add_cyl(bm, (0, 0, 5.0), r, r, 10.0, 24)  # drum
    add_cyl(bm, (0, 0, 10.4), r + 0.6, r + 0.6, 0.8, 24)  # cornice
    obj_from_bmesh(bm, "Drum", root)
    bm = bmesh.new()
    ret = bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=r)
    for v in ret["verts"]:
        v.co.z = max(v.co.z, 0) * 0.85 + 10.8
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.01)
    obj_from_bmesh(bm, "Dome", root)
    bm = bmesh.new()
    for i in range(8):
        a = math.tau * i / 8
        for j in range(6):
            t0, t1 = j / 6 * math.pi / 2, (j + 1) / 6 * math.pi / 2
            p0 = Vector((math.cos(a) * math.cos(t0) * (r + 0.25), math.sin(a) * math.cos(t0) * (r + 0.25), 10.8 + math.sin(t0) * r * 0.85))
            p1 = Vector((math.cos(a) * math.cos(t1) * (r + 0.25), math.sin(a) * math.cos(t1) * (r + 0.25), 10.8 + math.sin(t1) * r * 0.85))
            mid, length = (p0 + p1) / 2, (p1 - p0).length
            ret = bmesh.ops.create_cube(bm, size=1.0)
            rot = (p1 - p0).to_track_quat("Z", "Y").to_matrix()
            for v in ret["verts"]:
                v.co = rot @ Vector((v.co.x * 0.7, v.co.y * 0.7, v.co.z * length)) + mid
    obj_from_bmesh(bm, "Ribs", root)
    bm = bmesh.new()
    top = 10.8 + r * 0.85
    add_cyl(bm, (0, 0, top + 1.0), 2.2, 2.2, 2.0, 12)
    add_blob(bm, (0, 0, top + 3.0), 1.6, 1.0, 0.0, 2)
    obj_from_bmesh(bm, "Lantern", root)
    return root


def rock(name, length, width, depth, seed):
    random.seed(seed)
    root = empty(name)
    bm = bmesh.new()
    # An upside-down faceted cone, flat top at z = 0 (sits under the island's surface).
    rings = [(0.0, 1.0), (-depth * 0.25, 0.92), (-depth * 0.55, 0.65), (-depth * 0.8, 0.35), (-depth, 0.08)]
    segs = 12
    layers = []
    for z, s in rings:
        layer = []
        for i in range(segs):
            a = math.tau * i / segs
            j = 1 + random.uniform(-0.12, 0.12) if z < 0 else 1
            layer.append(bm.verts.new((math.cos(a) * length / 2 * s * j, math.sin(a) * width / 2 * s * j, z + (random.uniform(-0.8, 0.8) if z < 0 else 0))))
        layers.append(layer)
    bm.faces.new(layers[0][::-1])
    for a_layer, b_layer in zip(layers, layers[1:]):
        for i in range(segs):
            bm.faces.new((a_layer[i], a_layer[(i + 1) % segs], b_layer[(i + 1) % segs], b_layer[i]))
    tip = bm.verts.new((random.uniform(-1, 1), random.uniform(-1, 1), -depth - 2))
    for i in range(segs):
        bm.faces.new((layers[-1][i], layers[-1][(i + 1) % segs], tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj_from_bmesh(bm, "Rock", root)
    return root


def lamp():
    root = empty("Lamp")
    bm = bmesh.new()
    add_cyl(bm, (0, 0, 0.4), 0.9, 0.8, 0.8, 8)
    add_cyl(bm, (0, 0, 5.5), 0.35, 0.25, 10.0, 8)
    add_cyl(bm, (0, 0, 10.6), 0.6, 0.6, 0.3, 8)
    obj_from_bmesh(bm, "Post", root)
    bm = bmesh.new()
    add_cyl(bm, (0, 0, 11.0), 0.9, 0.9, 0.3, 8)  # lantern floor
    add_cyl(bm, (0, 0, 13.2), 1.2, 0.2, 1.0, 8)  # roof
    obj_from_bmesh(bm, "Head", root)
    bm = bmesh.new()
    add_cyl(bm, (0, 0, 12.0), 0.8, 0.95, 1.9, 8)
    obj_from_bmesh(bm, "Glass", root)
    return root


ASSETS = {
    "Tree_A": lambda: tree("Tree_A", 3.5, 0.55, [((0, 0, 6.0), 2.9, 0.9), ((1.4, 0.6, 5.2), 2.0, 0.9), ((-1.2, -0.8, 5.0), 1.9, 0.9)]),
    "Tree_B": lambda: tree("Tree_B", 5.0, 0.7, [((0, 0, 8.6), 3.6, 0.9), ((2.2, 0.4, 7.4), 2.6, 0.9), ((-2.0, 0.9, 7.6), 2.5, 0.9), ((0.2, -2.1, 7.2), 2.4, 0.9)]),
    "Tree_C": lambda: tree("Tree_C", 6.5, 0.8, [((0, 0, 9.4), 3.8, 0.95), ((0, 0, 13.2), 2.9, 0.95), ((1.8, 1.2, 10.8), 2.3, 0.9)]),
    "Stall": stall,
    "Vault": vault,
    "Rock_A": lambda: rock("Rock_A", 40, 22, 26, 1),
    "Rock_B": lambda: rock("Rock_B", 30, 30, 34, 2),
    "Lamp": lamp,
}


def export(name):
    bpy.ops.object.select_all(action="DESELECT")
    root = bpy.data.objects[name]
    root.select_set(True)
    for child in root.children:
        child.select_set(True)
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, name + ".fbx"), use_selection=True,
                             axis_forward="-Z", axis_up="Y", apply_unit_scale=True,
                             apply_scale_options="FBX_SCALE_UNITS", object_types={"EMPTY", "MESH"},
                             mesh_smooth_type="FACE", bake_space_transform=True)


def stats(name):
    root = bpy.data.objects[name]
    tris, lo, hi = 0, Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for child in root.children:
        child.data.calc_loop_triangles()
        tris += len(child.data.loop_triangles)
        for v in child.data.vertices:
            w = child.matrix_world @ v.co
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    size = hi - lo
    return f"{name}: {tris} tris, size {size.x:.1f} x {size.y:.1f} x {size.z:.1f} (x, y, z-up)"


def preview(names):
    scene = bpy.context.scene
    x = 0.0
    for name in names:
        root = bpy.data.objects[name]
        root.location.x = x + 22
        x += 50
    bpy.ops.object.camera_add(location=(x / 2, -150, 55), rotation=(math.radians(72), 0, 0))
    scene.camera = bpy.context.object
    scene.camera.data.type = "ORTHO"
    scene.camera.data.ortho_scale = x + 20
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(40), 0, math.radians(30)))
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.light = "STUDIO"
    scene.render.resolution_x, scene.render.resolution_y = 1800, 420
    scene.render.filepath = os.path.join(OUT, "preview.png")
    bpy.ops.render.render(write_still=True)


reset()
for name, build in ASSETS.items():
    build()
lines = []
for name in ASSETS:
    lines.append(stats(name))
    export(name)
preview(list(ASSETS))
with open(os.path.join(OUT, "stats.txt"), "w") as f:
    f.write("\n".join(lines) + "\n")
print("\n".join(lines))
print("EXPORTED", len(ASSETS))
