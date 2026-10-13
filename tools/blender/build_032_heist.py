# Milestone 032 Boss Heist meshes (D22/D24), all original, built from code in headless Blender:
#   flatpak run org.blender.Blender -b -P tools/blender/build_032_heist.py
# Writes assets/export/032/heist/<Model>.fbx (one FBX per model, one mesh object per colour part, origin at
# the part's pivot so Studio can animate it), parts.json (part -> colour, pivot, size) and a preview PNG.
# Models: SecurityBot (giant, friendly security robot), VaultDoor (round vault door + frame + wheel),
# BossCapsule (the capsule players carry). Built at ~1 unit = 1 stud / 4 (Studio scales them up).
# Front = -Y (same as the 031 creatures).
import bpy, bmesh, math, os, json
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "export", "032", "heist")
os.makedirs(OUT, exist_ok=True)

# Our palette (hub navy/gold/cream, steel, cyan glow, amber siren). Linear-ish values like the 031 script.
C = {
    "navy": (0.10, 0.16, 0.36), "navyDark": (0.06, 0.09, 0.22), "gold": (1.0, 0.74, 0.12),
    "goldDark": (0.85, 0.48, 0.05), "cream": (1.0, 0.95, 0.82), "steel": (0.62, 0.66, 0.74),
    "steelDark": (0.30, 0.33, 0.40), "ink": (0.10, 0.09, 0.13), "cyan": (0.30, 0.90, 1.0),
    "amber": (1.0, 0.58, 0.10), "white": (0.97, 0.97, 0.99), "pink": (1.0, 0.55, 0.65),
    "purple": (0.60, 0.32, 0.95), "glass": (0.75, 0.90, 1.0),
}
parts = {}  # model -> list of {name, colour, pivot, size}


def mat(name, rgb):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = 0.5
    m.diffuse_color = (*rgb, 1)
    return m


def bevel(o, w=0.04, seg=2):
    b = o.modifiers.new("b", "BEVEL")
    b.width = w
    b.segments = seg
    b.limit_method = "ANGLE"


def join(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        for md in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=md.name)
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    return objs[0]


def finish(o, model, name, colour, pivot=None, smooth=True):
    """Name it, colour it, put the origin at the pivot, apply modifiers."""
    o.name = f"{model}_{name}"
    o.data.materials.clear()
    o.data.materials.append(mat(colour, C[colour]))
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    for md in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    if smooth:
        bpy.ops.object.shade_smooth()
    else:
        bpy.ops.object.shade_flat()
    if pivot is None:
        pivot = o.location.copy()
    bpy.context.scene.cursor.location = pivot
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    o.select_set(False)
    dims = [round(v, 3) for v in o.dimensions]
    parts.setdefault(model, []).append({"name": o.name, "colour": colour, "pivot": [round(v, 3) for v in pivot], "size": dims})
    return o


def sphere(loc, scale, seg=16, ring=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ring, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return o


def box(loc, scale, rot=(0, 0, 0), bw=0.05):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    bevel(o, bw, 3)
    return o


def cyl(loc, r, h, rot=(0, 0, 0), verts=16, bw=0.03):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    o = bpy.context.active_object
    bpy.ops.object.transform_apply(rotation=True)
    bevel(o, bw)
    return o


def cone(loc, r, h, rot=(0, 0, 0), verts=8, r2=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc, rotation=rot)
    o = bpy.context.active_object
    bpy.ops.object.transform_apply(rotation=True)
    return o


def torus(loc, R, r, rot=(0, 0, 0), seg=24, ring=8):
    bpy.ops.mesh.primitive_torus_add(location=loc, rotation=rot, major_radius=R, minor_radius=r, major_segments=seg, minor_segments=ring)
    o = bpy.context.active_object
    bpy.ops.object.transform_apply(rotation=True)
    return o


def star(loc, outer, inner, depth, rot=(math.radians(90), 0, 0)):
    bm = bmesh.new()
    pts = []
    for i in range(10):
        a = math.radians(90 + 36 * i)
        r = outer if i % 2 == 0 else inner
        pts.append((math.cos(a) * r, math.sin(a) * r))
    front = [bm.verts.new((x, y, -depth / 2)) for x, y in pts]
    back = [bm.verts.new((x, y, depth / 2)) for x, y in pts]
    bm.faces.new(front[::-1])
    bm.faces.new(back)
    for i in range(10):
        bm.faces.new((front[i], front[(i + 1) % 10], back[(i + 1) % 10], back[i]))
    me = bpy.data.meshes.new("star")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("star", me)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.object.transform_apply(rotation=True)
    bevel(o, 0.02, 2)
    return o


# Security Bot: a big round friendly guard robot -----------------------------------------------------------
# ~6 units tall (Studio scales x3.6 -> ~22 studs). Pivots: hips for legs, shoulders for arms, neck for the
# head, the shoulder mount for the searchlight.
def robot():
    m = "SecurityBot"
    # torso: rounded barrel, navy, cream chest plate, gold belt + star badge
    finish(box((0, 0, 3.25), (1.25, 0.95, 1.15), bw=0.45), m, "Torso", "navy", Vector((0, 0, 2.2)))
    finish(box((0, -0.82, 3.35), (0.85, 0.2, 0.75), bw=0.22), m, "Chest", "cream", Vector((0, 0, 2.2)))
    finish(star((0, -1.05, 3.45), 0.42, 0.19, 0.12), m, "Badge", "gold", Vector((0, 0, 2.2)), smooth=False)
    finish(box((0, 0, 2.25), (1.32, 1.02, 0.18), bw=0.12), m, "Belt", "gold", Vector((0, 0, 2.2)))
    finish(box((0, 0, 1.95), (0.9, 0.7, 0.3), bw=0.15), m, "Hips", "steelDark", Vector((0, 0, 2.2)))
    # head: rounded cream box with a dark visor, two big happy cyan eyes, amber siren dome on top
    neck = Vector((0, 0, 4.4))
    finish(cyl((0, 0, 4.5), 0.35, 0.35, verts=12), m, "Neck", "steelDark", neck)
    finish(box((0, 0, 5.15), (0.95, 0.8, 0.62), bw=0.32), m, "Head", "cream", neck)
    finish(box((0, -0.72, 5.15), (0.78, 0.12, 0.38), bw=0.12), m, "Visor", "ink", neck)
    for s, n in ((-1, "L"), (1, "R")):
        finish(sphere((s * 0.34, -0.84, 5.2), (0.17, 0.05, 0.2), 12, 8), m, "Eye" + n, "cyan", neck)
        finish(sphere((s * 0.9, 0, 5.15), (0.12, 0.28, 0.28), 12, 8), m, "Ear" + n, "gold", neck)
    finish(sphere((0, -0.84, 4.95), (0.18, 0.04, 0.05), 10, 6), m, "Smile", "cyan", neck)
    finish(cyl((0, 0, 5.82), 0.32, 0.12, verts=16), m, "SirenBase", "steelDark", neck)
    finish(sphere((0, 0, 5.9), (0.28, 0.28, 0.3), 14, 8), m, "Siren", "amber", neck)
    # arms: gold shoulder balls, steel tubes, big cream mitten hands
    for s, n in ((-1, "L"), (1, "R")):
        sh = Vector((s * 1.4, 0, 3.75))
        finish(sphere((s * 1.4, 0, 3.75), (0.45, 0.45, 0.45), 14, 9), m, "Shoulder" + n, "gold", sh)
        finish(cyl((s * 1.5, 0, 3.05), 0.27, 1.2, verts=12), m, "Arm" + n, "steelDark", sh)
        finish(sphere((s * 1.52, -0.05, 2.25), (0.5, 0.45, 0.48), 14, 9), m, "Hand" + n, "cream", sh)
        # legs: thick steel tubes, navy boots with gold toe caps (the stomp foot)
        hip = Vector((s * 0.55, 0, 1.9))
        finish(cyl((s * 0.55, 0, 1.2), 0.36, 1.25, verts=12), m, "Leg" + n, "steelDark", hip)
        finish(box((s * 0.58, -0.18, 0.28), (0.5, 0.72, 0.28), bw=0.18), m, "Foot" + n, "navy", hip)
        finish(box((s * 0.58, -0.78, 0.25), (0.42, 0.18, 0.22), bw=0.12), m, "Toe" + n, "gold", hip)
    # searchlight on the right shoulder: lamp body + yellow lens (pivot = mount, aims along -Y)
    mount = Vector((1.4, 0, 4.25))
    finish(cyl((1.4, 0, 4.2), 0.12, 0.25, verts=8), m, "LightMount", "steelDark", mount)
    finish(cyl((1.4, -0.15, 4.45), 0.28, 0.6, (math.radians(90), 0, 0), verts=14), m, "Searchlight", "steel", mount)
    finish(cyl((1.4, -0.47, 4.45), 0.23, 0.06, (math.radians(90), 0, 0), verts=14, bw=0.01), m, "Lens", "gold", mount)
    # back: a little battery pack with a cyan charge strip (docks into the bay)
    finish(box((0, 1.05, 3.3), (0.7, 0.25, 0.75), bw=0.15), m, "Pack", "steel", Vector((0, 0, 2.2)))
    finish(box((0, 1.31, 3.3), (0.12, 0.05, 0.5), bw=0.03), m, "Charge", "cyan", Vector((0, 0, 2.2)))


# Vault Door: round door (separate so it can swing), spoked wheel (spins), thick frame ---------------------
# ~4 units across (Studio scales x4 -> 16 studs). Door hinge on the left (-X) edge. Faces -Y.
def vault():
    m = "VaultDoor"
    # frame: a square surround with a round hole, plus a gold ring trim
    fr = box((0, 0.15, 2.4), (2.45, 0.3, 2.45), bw=0.12)
    hole = cyl((0, 0.15, 2.4), 1.9, 1.0, (math.radians(90), 0, 0), verts=40, bw=0.0)
    hole.modifiers.clear()
    bo = fr.modifiers.new("hole", "BOOLEAN")
    bo.object = hole
    bo.operation = "DIFFERENCE"
    bpy.context.view_layer.objects.active = fr
    bpy.ops.object.modifier_apply(modifier="hole")
    bpy.data.objects.remove(hole)
    finish(fr, m, "Frame", "steelDark", Vector((0, 0, 0)), smooth=False)
    finish(torus((0, -0.18, 2.4), 2.0, 0.12, (math.radians(90), 0, 0), seg=40), m, "Trim", "gold", Vector((0, 0, 0)))
    for i in range(12):
        a = 2 * math.pi * i / 12
        if i == 0:
            rivets = []
        rivets.append(sphere((math.cos(a) * 2.25, -0.05, 2.4 + math.sin(a) * 2.25), (0.09, 0.06, 0.09), 8, 5))
    finish(join(rivets), m, "Rivets", "gold", Vector((0, 0, 0)))
    # door: thick disc with a stepped face and 8 locking bolts around the edge (one mesh); hinge at -X
    hinge = Vector((-1.85, 0, 2.4))
    door = [cyl((0, 0.0, 2.4), 1.82, 0.42, (math.radians(90), 0, 0), verts=40, bw=0.06),
            cyl((0, -0.26, 2.4), 1.4, 0.12, (math.radians(90), 0, 0), verts=40, bw=0.04)]
    for i in range(8):
        a = 2 * math.pi * i / 8 + math.pi / 8
        door.append(cyl((math.cos(a) * 1.6, -0.26, 2.4 + math.sin(a) * 1.6), 0.13, 0.12, (math.radians(90), 0, 0), verts=10, bw=0.03))
    finish(join(door), m, "Door", "steel", hinge)
    finish(star((0, -0.36, 2.4 + 0.9), 0.26, 0.12, 0.08), m, "DoorStar", "gold", hinge, smooth=False)
    hb = [cyl((-1.95, -0.05, 2.4 + dz), 0.16, 0.5, verts=10) for dz in (-1.1, 1.1)]
    finish(join(hb), m, "Hinges", "steelDark", hinge)
    # wheel: hub + ring + 4 spokes with knobs, spins about its own centre (axis Y)
    wc = Vector((0, -0.5, 2.4))
    w = [torus((0, -0.5, 2.4), 0.62, 0.07, (math.radians(90), 0, 0), seg=28, ring=8), cyl((0, -0.48, 2.4), 0.2, 0.2, (math.radians(90), 0, 0), verts=14)]
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        w.append(cyl((math.cos(a) * 0.32, -0.5, 2.4 + math.sin(a) * 0.32), 0.05, 0.62, (0, -a + math.pi / 2, 0), verts=8, bw=0.01))
        w.append(sphere((math.cos(a) * 0.72, -0.5, 2.4 + math.sin(a) * 0.72), (0.11, 0.11, 0.11), 10, 6))
    finish(join(w), m, "Wheel", "gold", wc)


# Boss Capsule: chunky pill with a gold base, purple stripe and a see-through dome (Studio sets transparency) --
def capsule():
    m = "BossCapsule"
    c = Vector((0, 0, 0))
    finish(sphere((0, 0, 0), (0.8, 0.8, 0.62), 18, 12), m, "Base", "gold", c)
    finish(sphere((0, 0, 0.2), (0.78, 0.78, 0.82), 18, 12), m, "Dome", "glass", c)
    finish(torus((0, 0, 0.12), 0.8, 0.1, seg=32), m, "Band", "purple", c)
    finish(star((0, -0.83, -0.2), 0.22, 0.1, 0.06), m, "Star", "cream", c, smooth=False)


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export(model):
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in bpy.data.objects if o.name.startswith(model + "_")]
    for o in objs:
        o.select_set(True)
    tris = 0
    for o in objs:
        tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, model + ".fbx"), use_selection=True, axis_forward="-Z", axis_up="Y",
                             global_scale=1.0, apply_unit_scale=True, bake_space_transform=False, mesh_smooth_type="FACE")
    return tris, len(objs)


def preview(model, target, dist, ortho):
    sc = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x = sc.render.resolution_y = 384
    sc.view_settings.view_transform = "Standard"
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.7, 0.8, 0.95, 1)
    bpy.ops.object.light_add(type="SUN", location=(3, -4, 6))
    bpy.context.active_object.data.energy = 2.2
    bpy.context.active_object.rotation_euler = (math.radians(50), 0, math.radians(30))
    bpy.ops.object.camera_add()
    cam = bpy.context.active_object
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    cam.location = Vector(target) + Vector((0.6, -1.0, 0.45)).normalized() * dist
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.filepath = os.path.join(OUT, model + "_preview.png")
    bpy.ops.render.render(write_still=True)


report = {}
for fn, name, target, ortho in ((robot, "SecurityBot", (0, 0, 3.0), 7.5), (vault, "VaultDoor", (0, 0, 2.4), 6.0), (capsule, "BossCapsule", (0, 0, 0.1), 2.6)):
    clear()
    fn()
    tris, n = export(name)
    preview(name, target, 20, ortho)
    report[name] = {"tris": tris, "parts": n}
with open(os.path.join(OUT, "parts.json"), "w") as f:
    json.dump({"parts": parts, "report": report}, f, indent=1)
print("HEIST", json.dumps(report))
