# Milestone 031 creature prototypes (D26), all original, built from code in headless Blender:
#   flatpak run org.blender.Blender -b -P tools/blender/build_031_creatures.py
# Writes assets/export/031/creatures/<Creature>.fbx (one FBX per creature, one mesh object per colour part,
# origin at the part's pivot so Studio can animate it), parts.json (part -> colour, pivot) and a preview PNG.
import bpy, bmesh, math, os, json
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "export", "031", "creatures")
os.makedirs(OUT, exist_ok=True)

C = {
    "slime": (0.35, 0.85, 0.35), "slimeDark": (0.18, 0.60, 0.25), "white": (0.97, 0.97, 0.99),
    "ink": (0.10, 0.09, 0.13), "pink": (1.0, 0.55, 0.65), "gold": (1.0, 0.74, 0.12),
    "dragon": (0.62, 0.32, 0.95), "dragonDark": (0.40, 0.18, 0.70), "belly": (1.0, 0.85, 0.45),
    "horn": (1.0, 0.92, 0.7), "wing": (1.0, 0.45, 0.30), "steel": (0.62, 0.66, 0.74),
    "steelDark": (0.30, 0.33, 0.40), "orange": (1.0, 0.52, 0.12), "cyan": (0.30, 0.90, 1.0),
}
parts = {}  # creature -> list of {name, colour, pivot}


def mat(name, rgb):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = 0.55
    m.diffuse_color = (*rgb, 1)
    return m


def bevel(o, w=0.04, seg=2):
    b = o.modifiers.new("b", "BEVEL")
    b.width = w
    b.segments = seg
    b.limit_method = "ANGLE"


def finish(o, creature, name, colour, pivot=None):
    """Name it, colour it, put the origin at the pivot, apply modifiers."""
    o.name = f"{creature}_{name}"
    o.data.materials.clear()
    o.data.materials.append(mat(colour, C[colour]))
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    for md in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.ops.object.shade_smooth()
    if pivot is None:
        pivot = o.location.copy()
    bpy.context.scene.cursor.location = pivot
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    o.select_set(False)
    parts.setdefault(creature, []).append({"name": o.name, "colour": colour, "pivot": [round(v, 3) for v in pivot]})
    return o


def sphere(loc, scale, seg=14, ring=9):
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


def cone(loc, r, h, rot=(0, 0, 0), verts=8, r2=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc, rotation=rot)
    return bpy.context.active_object


def cyl(loc, r, h, rot=(0, 0, 0), verts=10):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    o = bpy.context.active_object
    bevel(o, 0.03)
    return o


# Slime Rookie (Common look): a round, friendly blob with a leaf antenna --------------------------------
def slime():
    c = "SlimeRookie"
    finish(sphere((0, 0, 0.85), (1.0, 1.0, 1.0), 16, 10), c, "Body", "slime", Vector((0, 0, 0)))
    finish(sphere((0, -0.2, 0.2), (1.15, 1.15, 0.28)), c, "Base", "slimeDark", Vector((0, 0, 0)))
    for s, n in ((-1, "EyeL"), (1, "EyeR")):
        finish(sphere((s * 0.32, -0.82, 0.95), (0.2, 0.12, 0.26)), c, n, "white")
        finish(sphere((s * 0.32, -0.92, 0.93), (0.09, 0.06, 0.15)), c, n + "Pupil", "ink")
    finish(sphere((0, -0.9, 0.62), (0.2, 0.07, 0.1)), c, "Mouth", "ink")
    finish(sphere((-0.55, -0.72, 0.68), (0.14, 0.05, 0.09)), c, "CheekL", "pink")
    finish(sphere((0.55, -0.72, 0.68), (0.14, 0.05, 0.09)), c, "CheekR", "pink")
    finish(cone((0, 0, 1.55), 0.12, 0.5, verts=6), c, "Antenna", "slimeDark", Vector((0, 0, 1.3)))
    finish(sphere((0.0, 0, 1.85), (0.26, 0.1, 0.4)), c, "Leaf", "gold", Vector((0, 0, 1.6)))


# Dragon Pup (Epic look): chunky body, big head, stub wings, little horns, curled tail -----------------
def dragon():
    c = "DragonPup"
    finish(sphere((0, 0.1, 0.95), (0.85, 0.75, 0.8), 16, 10), c, "Body", "dragon", Vector((0, 0, 0.9)))
    finish(sphere((0, -0.35, 0.8), (0.55, 0.4, 0.6)), c, "Belly", "belly", Vector((0, 0, 0.9)))
    finish(sphere((0, -0.55, 1.75), (0.8, 0.7, 0.68), 16, 10), c, "Head", "dragon", Vector((0, -0.2, 1.4)))
    finish(sphere((0, -1.15, 1.6), (0.38, 0.28, 0.24)), c, "Snout", "dragonDark", Vector((0, -0.2, 1.4)))
    for s, n in ((-1, "EyeL"), (1, "EyeR")):
        finish(sphere((s * 0.38, -1.05, 1.95), (0.17, 0.1, 0.22)), c, n, "white", Vector((0, -0.2, 1.4)))
        finish(sphere((s * 0.38, -1.13, 1.93), (0.08, 0.05, 0.13)), c, n + "Pupil", "ink", Vector((0, -0.2, 1.4)))
        finish(cone((s * 0.4, -0.45, 2.45), 0.16, 0.55, (0, s * 0.35, 0), 6), c, "Horn" + n[-1], "horn", Vector((s * 0.4, -0.45, 2.25)))
        # wing: flat wedge pivoting at the shoulder
        w = sphere((s * 1.25, 0.35, 1.5), (0.8, 0.07, 0.5), 12, 8)
        w.rotation_euler = (0, s * 0.35, s * 0.25)
        bpy.ops.object.transform_apply(rotation=True)
        finish(w, c, "Wing" + n[-1], "wing", Vector((s * 0.75, 0.25, 1.25)))
        finish(sphere((s * 0.5, -0.45, 0.2), (0.28, 0.4, 0.2)), c, "Foot" + n[-1], "dragonDark", Vector((s * 0.5, -0.4, 0.4)))
    for i, (y, z, r) in enumerate(((0.95, 0.7, 0.34), (1.45, 0.62, 0.26), (1.85, 0.8, 0.18))):
        finish(sphere((0, y, z), (r, r, r)), c, f"Tail{i + 1}", "dragon" if i < 2 else "gold", Vector((0, 0.7, 0.75)))
    for i, z in enumerate((1.05, 1.5)):
        finish(cone((0, 0.75, z), 0.14, 0.32, (math.radians(-90), 0, 0), 4), c, f"Spike{i + 1}", "gold", Vector((0, 0.5, 1.0)))


# Mech Beast (Legendary look): four-legged robot cat/beast, glowing chest core, shoulder cannons ------------
def mech():
    c = "MechBeast"
    finish(box((0, 0.1, 1.35), (0.9, 1.35, 0.6), bw=0.3), c, "Body", "steel", Vector((0, 0, 1.3)))
    finish(box((0, -0.25, 1.9), (0.7, 0.9, 0.25), bw=0.15), c, "Armor", "steelDark", Vector((0, 0, 1.3)))
    finish(sphere((0, -0.2, 1.35), (0.34, 0.12, 0.34)), c, "Core", "cyan", Vector((0, 0, 1.3)))
    finish(box((0, -1.2, 1.8), (0.7, 0.62, 0.55), bw=0.28), c, "Head", "steel", Vector((0, -0.9, 1.6)))
    finish(box((0, -1.78, 1.7), (0.45, 0.2, 0.28), bw=0.1), c, "Muzzle", "steelDark", Vector((0, -0.9, 1.6)))
    for s, n in ((-1, "L"), (1, "R")):
        finish(box((s * 0.28, -1.78, 1.98), (0.18, 0.05, 0.1)), c, "Eye" + n, "orange", Vector((0, -0.9, 1.6)))
        finish(cone((s * 0.42, -1.1, 2.55), 0.2, 0.6, (0, s * 0.2, 0), 4), c, "Ear" + n, "steelDark", Vector((s * 0.4, -1.1, 2.3)))
        finish(cyl((s * 0.62, 0.35, 2.15), 0.17, 0.9, (math.radians(90), 0, 0)), c, "Cannon" + n, "steelDark", Vector((s * 0.62, 0.35, 1.95)))
        for fy, fn in ((-0.75, "F"), (0.9, "B")):
            top = 1.0
            finish(cyl((s * 0.75, fy, 0.7), 0.27, 0.9), c, f"Leg{fn}{n}", "steelDark", Vector((s * 0.75, fy, top)))
            finish(box((s * 0.75, fy - 0.1, 0.12), (0.34, 0.5, 0.14), bw=0.1), c, f"Paw{fn}{n}", "steel", Vector((s * 0.75, fy, top)))
    finish(cyl((0, 1.65, 1.5), 0.13, 1.1, (math.radians(55), 0, 0)), c, "Tail", "steelDark", Vector((0, 1.3, 1.4)))
    finish(sphere((0, 2.1, 2.0), (0.22, 0.22, 0.22)), c, "TailTip", "cyan", Vector((0, 1.3, 1.4)))


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export(creature):
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in bpy.data.objects if o.name.startswith(creature + "_")]
    for o in objs:
        o.select_set(True)
    tris = 0
    for o in objs:
        tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, creature + ".fbx"), use_selection=True, axis_forward="-Z", axis_up="Y",
                             global_scale=1.0, apply_unit_scale=True, bake_space_transform=False, mesh_smooth_type="FACE")
    return tris, len(objs)


def preview(creature):
    objs = [o for o in bpy.data.objects if o.name.startswith(creature + "_")]
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    sc.render.resolution_x = sc.render.resolution_y = 384
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.7, 0.8, 0.95, 1)
    bpy.ops.object.light_add(type="SUN", location=(3, -4, 6))
    bpy.context.active_object.data.energy = 2.2
    bpy.context.active_object.rotation_euler = (math.radians(50), 0, math.radians(30))
    bpy.ops.object.camera_add(location=(4.3, -6.2, 3.6))
    cam = bpy.context.active_object
    cam.rotation_euler = (math.radians(68), 0, math.radians(35))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 5.2
    cam.location = Vector((5, -6, 4.2))
    d = Vector((0, 0, 1.3)) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.filepath = os.path.join(OUT, creature + "_preview.png")
    bpy.ops.render.render(write_still=True)


report = {}
for fn, name in ((slime, "SlimeRookie"), (dragon, "DragonPup"), (mech, "MechBeast")):
    clear()
    fn()
    tris, n = export(name)
    preview(name)
    report[name] = {"tris": tris, "parts": n}
with open(os.path.join(OUT, "parts.json"), "w") as f:
    json.dump({"parts": parts, "report": report}, f, indent=1)
print("CREATURES", json.dumps(report))
