# Milestone 034 (Steal a Boss) meshes, all original, built from code in headless Blender:
#   flatpak run org.blender.Blender -b -P tools/blender/build_034_imports.py
# Writes assets/export/034/<Model>.fbx (one FBX per model, one mesh object per colour part, origin at the part's
# pivot), parts.json (part -> colour, pivot, size; tris per model) and <Model>_preview.png.
# Import each FBX with Studio's 3D Importer into ServerStorage.Imports034 (one Model per file, names kept).
# Front = -Y, ~1 unit = 1 stud / 3.6 for the boss (same rig as the 032 SecurityBot), kits ~1 unit = 1 stud / 4.
#   SirIronclad   the Knight's Keep boss: a big friendly cartoon knight. SAME part names and pivots as the 032
#                 SecurityBot so the heist code keeps working (groups Head / ArmL / ArmR / LegL / LegR / Light):
#                 Siren = his helmet plume (flashes), Searchlight + Lens = his shoulder crossbow + bolt tip (aims at
#                 you: arrow volley), Pack + Charge = cape + clasp. New: Sword/SwordHilt (ArmR: raised for the
#                 sword sweep), Shield/ShieldRim/ShieldCrest (ArmL: shield slam).
#   TreasuryDoor  replaces the VaultDoor: same part names (Frame, Trim, Rivets, Door, DoorStar, Hinges, Wheel), an
#                 oak-and-iron round door with a gold crown and an iron ring.
#   KeepTower, ShellPalace, Coral, Kelp, WizardTower, FireCrystal, Spellbook: zone props.
import bpy, bmesh, math, os, json
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "export", "034")
os.makedirs(OUT, exist_ok=True)

C = {
    "steel": (0.66, 0.70, 0.78), "steelDark": (0.30, 0.33, 0.40), "silver": (0.86, 0.89, 0.94),
    "gold": (1.0, 0.74, 0.12), "red": (0.78, 0.10, 0.12), "redDark": (0.45, 0.05, 0.07), "cream": (1.0, 0.95, 0.82),
    "ink": (0.10, 0.09, 0.13), "eye": (1.0, 0.92, 0.55), "wood": (0.42, 0.24, 0.10), "leather": (0.30, 0.17, 0.08),
    "stone": (0.60, 0.56, 0.50), "roof": (0.70, 0.12, 0.14), "pearl": (0.93, 0.92, 0.97), "shell": (1.0, 0.70, 0.66),
    "coral": (1.0, 0.42, 0.40), "kelp": (0.18, 0.52, 0.22), "teal": (0.10, 0.62, 0.66), "plum": (0.30, 0.15, 0.40),
    "brass": (0.80, 0.55, 0.18), "ember": (1.0, 0.45, 0.08), "pages": (0.97, 0.92, 0.78), "bookRed": (0.62, 0.12, 0.12),
}
parts = {}


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


def apply_mods(o):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    for md in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    o.select_set(False)


def join(objs):
    for o in objs:
        apply_mods(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    return objs[0]


def finish(o, model, name, colour, pivot=None, smooth=True):
    o.name = f"{model}_{name}"
    o.data.materials.clear()
    o.data.materials.append(mat(colour, C[colour]))
    apply_mods(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    if smooth:
        bpy.ops.object.shade_smooth()
    else:
        bpy.ops.object.shade_flat()
    if pivot is None:
        pivot = o.location.copy()
    bpy.context.scene.cursor.location = pivot
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    o.select_set(False)
    parts.setdefault(model, []).append({"name": o.name, "colour": colour, "pivot": [round(v, 3) for v in pivot], "size": [round(v, 3) for v in o.dimensions]})
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
    if bw > 0:
        bevel(o, bw, 3)
    return o


def cyl(loc, r, h, rot=(0, 0, 0), verts=16, bw=0.03):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    o = bpy.context.active_object
    bpy.ops.object.transform_apply(rotation=True)
    if bw > 0:
        bevel(o, bw)
    return o


def cone(loc, r, h, rot=(0, 0, 0), verts=12, r2=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc, rotation=rot)
    o = bpy.context.active_object
    bpy.ops.object.transform_apply(rotation=True)
    return o


def torus(loc, R, r, rot=(0, 0, 0), seg=24, ring=8):
    bpy.ops.mesh.primitive_torus_add(location=loc, rotation=rot, major_radius=R, minor_radius=r, major_segments=seg, minor_segments=ring)
    o = bpy.context.active_object
    bpy.ops.object.transform_apply(rotation=True)
    return o


def prism(points, depth, loc, rot=(math.radians(90), 0, 0), bw=0.02):
    """Extruded flat outline (x, y points), `depth` thick, stood up facing -Y by default."""
    bm = bmesh.new()
    front = [bm.verts.new((x, y, -depth / 2)) for x, y in points]
    back = [bm.verts.new((x, y, depth / 2)) for x, y in points]
    bm.faces.new(front[::-1])
    bm.faces.new(back)
    n = len(points)
    for i in range(n):
        bm.faces.new((front[i], front[(i + 1) % n], back[(i + 1) % n], back[i]))
    me = bpy.data.meshes.new("prism")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("prism", me)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.object.transform_apply(rotation=True)
    if bw > 0:
        bevel(o, bw, 2)
    return o


# Sir Ironclad -----------------------------------------------------------------------------------------------------
# Same pivots as the 032 SecurityBot: body/hips (0,0,2.2), neck (0,0,4.4), shoulders (+-1.4,0,3.75),
# hips (+-0.55,0,1.9), light mount (1.4,0,4.25). ~6.3 units tall (x3.6 in Studio = ~23 studs).
def ironclad():
    m = "SirIronclad"
    body = Vector((0, 0, 2.2))
    # torso: rounded steel breastplate, red tabard panel with a gold diamond crest, leather belt, steel skirt
    finish(box((0, 0, 3.2), (1.15, 0.9, 1.1), bw=0.42), m, "Torso", "steel", body)
    finish(box((0, -0.8, 3.15), (0.7, 0.14, 0.95), bw=0.16), m, "Chest", "red", body)
    finish(box((0, -0.97, 3.45), (0.26, 0.06, 0.26), rot=(0, math.radians(45), 0), bw=0.05), m, "Badge", "gold", body, smooth=False)
    finish(box((0, 0, 2.2), (1.2, 0.95, 0.16), bw=0.1), m, "Belt", "leather", body)
    finish(cone((0, 0, 1.85), 1.25, 0.6, verts=16, r2=1.0), m, "Hips", "steelDark", body)
    finish(cyl((0, -0.98, 2.2), 0.18, 0.08, (math.radians(90), 0, 0), verts=12, bw=0.02), m, "Buckle", "gold", body)
    # head: round great helm with a dark visor slit, two warm friendly eyes, a gold smile grille, gold rivets,
    # gold plume holder and a big red plume (the Siren: it flashes during a chase)
    neck = Vector((0, 0, 4.4))
    finish(cyl((0, 0, 4.5), 0.42, 0.35, verts=14), m, "Neck", "steelDark", neck)
    finish(sphere((0, 0, 5.15), (0.92, 0.88, 0.85), 22, 14), m, "Head", "steel", neck)
    finish(box((0, -0.8, 5.25), (0.7, 0.14, 0.13), bw=0.06), m, "Visor", "ink", neck)
    for s, n in ((-1, "L"), (1, "R")):
        finish(sphere((s * 0.3, -0.9, 5.26), (0.13, 0.04, 0.09), 12, 8), m, "Eye" + n, "eye", neck)
        finish(cyl((s * 0.9, 0, 5.15), 0.2, 0.1, (0, math.radians(90), 0), verts=14, bw=0.02), m, "Ear" + n, "gold", neck)
    grille = [cyl((x * 0.15, -0.86, 4.85 - abs(x) * 0.04), 0.035, 0.28, verts=8, bw=0) for x in (-2, -1, 0, 1, 2)]
    finish(join(grille), m, "Smile", "gold", neck)
    finish(cyl((0, 0.05, 5.98), 0.16, 0.18, verts=12), m, "SirenBase", "gold", neck)
    finish(sphere((0, 0.35, 6.25), (0.24, 0.62, 0.34), 16, 10), m, "Siren", "red", neck)
    # arms: round gold-trimmed pauldrons, steel arms, big gauntlets
    for s, n in ((-1, "L"), (1, "R")):
        sh = Vector((s * 1.4, 0, 3.75))
        finish(sphere((s * 1.42, 0, 3.85), (0.55, 0.52, 0.45), 16, 10), m, "Shoulder" + n, "steel", sh)
        finish(cyl((s * 1.5, 0, 3.05), 0.26, 1.2, verts=12), m, "Arm" + n, "steelDark", sh)
        finish(sphere((s * 1.52, -0.05, 2.25), (0.42, 0.4, 0.42), 14, 9), m, "Hand" + n, "steel", sh)
        hip = Vector((s * 0.55, 0, 1.9))
        finish(cyl((s * 0.55, 0, 1.15), 0.34, 1.3, verts=12), m, "Leg" + n, "steelDark", hip)
        finish(box((s * 0.58, -0.18, 0.26), (0.5, 0.72, 0.26), bw=0.18), m, "Foot" + n, "steel", hip)
        finish(box((s * 0.58, -0.78, 0.24), (0.42, 0.16, 0.2), bw=0.1), m, "Toe" + n, "gold", hip)
    # sword in the right gauntlet, pointing up and a little forward (ArmR group)
    shR = Vector((1.4, 0, 3.75))
    blade = prism([(-0.17, 0), (0.17, 0), (0.17, 2.45), (0, 2.85), (-0.17, 2.45)], 0.08, (1.52, -0.42, 2.45), rot=(math.radians(90 + 20), 0, 0))
    finish(blade, m, "Sword", "silver", shR, smooth=False)
    hilt = [box((1.52, -0.4, 2.42), (0.55, 0.1, 0.1), rot=(math.radians(20), 0, 0), bw=0.03), cyl((1.52, -0.3, 2.1), 0.08, 0.6, (math.radians(20), 0, 0), verts=8, bw=0)]
    finish(join(hilt), m, "SwordHilt", "gold", shR)
    # heater shield on the left forearm (ArmL group)
    shL = Vector((-1.4, 0, 3.75))
    pts = [(-0.75, 0.6), (0.75, 0.6), (0.75, -0.1), (0.4, -0.75), (0, -1.0), (-0.4, -0.75), (-0.75, -0.1)]
    finish(prism(pts, 0.14, (-1.85, -0.62, 2.85), rot=(math.radians(90), 0, math.radians(-25))), m, "Shield", "red", shL)
    rim = [(x * 1.12, y * 1.1 + 0.02) for x, y in pts]
    finish(prism(rim, 0.08, (-1.83, -0.57, 2.85), rot=(math.radians(90), 0, math.radians(-25))), m, "ShieldRim", "gold", shL)
    crest = box((-1.85, -0.72, 2.95), (0.26, 0.05, 0.26), rot=(0, math.radians(45), 0), bw=0.04)
    crest.rotation_euler = (0, 0, math.radians(-25))
    bpy.ops.object.transform_apply(rotation=True)
    finish(crest, m, "ShieldCrest", "gold", shL, smooth=False)
    # shoulder crossbow on the right pauldron (Light group: aims along -Y at its target)
    mount = Vector((1.4, 0, 4.25))
    finish(cyl((1.4, 0, 4.25), 0.12, 0.25, verts=8), m, "LightMount", "steelDark", mount)
    bow = [box((1.4, -0.2, 4.45), (0.12, 0.45, 0.1), bw=0.03), box((1.4, -0.55, 4.45), (0.6, 0.06, 0.06), bw=0.02)]
    finish(join(bow), m, "Searchlight", "wood", mount)
    finish(cone((1.4, -0.72, 4.45), 0.07, 0.2, (math.radians(90), 0, 0), verts=6), m, "Lens", "gold", mount)
    # back: a red cape with a gold clasp
    finish(box((0, 0.95, 2.9), (1.05, 0.08, 1.25), rot=(math.radians(-6), 0, 0), bw=0.06), m, "Pack", "red", body)
    finish(cyl((0, 0.9, 4.0), 0.16, 0.1, (math.radians(90), 0, 0), verts=12, bw=0.02), m, "Charge", "gold", body)


# Treasury door: same parts as the 032 VaultDoor (round door in a square frame, hinge at -X) -----------------------
def treasury():
    m = "TreasuryDoor"
    fr = box((0, 0.15, 2.4), (2.45, 0.3, 2.45), bw=0.12)
    hole = cyl((0, 0.15, 2.4), 1.9, 1.0, (math.radians(90), 0, 0), verts=40, bw=0)
    bo = fr.modifiers.new("hole", "BOOLEAN")
    bo.object = hole
    bo.operation = "DIFFERENCE"
    apply_mods(fr)
    bpy.data.objects.remove(hole)
    finish(fr, m, "Frame", "stone", Vector((0, 0, 0)), smooth=False)
    finish(torus((0, -0.18, 2.4), 2.0, 0.12, (math.radians(90), 0, 0), seg=40), m, "Trim", "gold", Vector((0, 0, 0)))
    rivets = []
    for i in range(12):
        a = 2 * math.pi * i / 12
        rivets.append(sphere((math.cos(a) * 2.25, -0.05, 2.4 + math.sin(a) * 2.25), (0.09, 0.06, 0.09), 8, 5))
    finish(join(rivets), m, "Rivets", "steelDark", Vector((0, 0, 0)))
    hinge = Vector((-1.85, 0, 2.4))
    door = [cyl((0, 0, 2.4), 1.82, 0.42, (math.radians(90), 0, 0), verts=40, bw=0.06)]
    for k in range(-3, 4):  # plank grooves read as ridges
        door.append(box((k * 0.5, -0.22, 2.4), (0.04, 0.03, math.sqrt(max(0.1, 1.75 ** 2 - (k * 0.5) ** 2))), bw=0))
    finish(join(door), m, "Door", "wood", hinge)
    crown = prism([(-0.36, 0), (0.36, 0), (0.36, 0.3), (0.22, 0.18), (0.12, 0.42), (0, 0.22), (-0.12, 0.42), (-0.22, 0.18), (-0.36, 0.3)], 0.08, (0, -0.32, 3.15))
    finish(crown, m, "DoorStar", "gold", hinge, smooth=False)
    hb = [box((-0.6, -0.26, 2.4 + dz), (1.25, 0.04, 0.11), bw=0.02) for dz in (-1.0, 1.0)] + [cyl((-1.95, -0.05, 2.4 + dz), 0.16, 0.5, verts=10) for dz in (-1.0, 1.0)]
    finish(join(hb), m, "Hinges", "steelDark", hinge)
    wc = Vector((0, -0.5, 2.4))
    finish(join([torus((0, -0.5, 2.4), 0.5, 0.08, (math.radians(90), 0, 0), seg=28), cyl((0, -0.4, 2.4), 0.16, 0.24, (math.radians(90), 0, 0), verts=12)]), m, "Wheel", "gold", wc)


# Zone props ------------------------------------------------------------------------------------------------------
def keep_tower():
    m = "KeepTower"  # ~22 studs: body with a merlon crown, red cone roof, gold finial (origin = base centre)
    o = Vector((0, 0, 0))
    body = [cyl((0, 0, 2.6), 1.25, 5.2, verts=20, bw=0.04), cyl((0, 0, 0.15), 1.45, 0.3, verts=20, bw=0.04), cyl((0, 0, 5.3), 1.5, 0.3, verts=20, bw=0.04)]
    for i in range(8):
        a = 2 * math.pi * i / 8
        body.append(box((math.cos(a) * 1.35, math.sin(a) * 1.35, 5.6), (0.22, 0.22, 0.25), rot=(0, 0, a), bw=0.03))
    finish(join(body), m, "Body", "stone", o)
    finish(join([box((math.cos(a) * 1.24, math.sin(a) * 1.24, h), (0.06, 0.1, 0.3), rot=(0, 0, a), bw=0) for a, h in ((math.radians(90), 3.2), (math.radians(90), 1.6), (math.radians(270), 2.4))]), m, "Slits", "ink", o)
    finish(cone((0, 0, 6.6), 1.6, 2.3, verts=20), m, "Roof", "roof", o)
    finish(sphere((0, 0, 7.85), (0.16, 0.16, 0.16), 10, 6), m, "Finial", "gold", o)


def shell_palace():
    m = "ShellPalace"  # pearl dome on a round base, a scallop fan behind it, two spiral-shell towers
    o = Vector((0, 0, 0))
    finish(join([cyl((0, 0, 0.6), 3.0, 1.2, verts=32, bw=0.08), sphere((0, 0, 1.2), (2.6, 2.6, 2.4), 28, 16)]), m, "Dome", "pearl", o)
    fan = []
    for i in range(9):
        a = math.radians(-80 + i * 20)
        fan.append(box((math.sin(a) * 2.0, 1.6, 2.2 + math.cos(a) * 2.0), (0.35, 0.12, 1.6), rot=(0, a, 0), bw=0.12))
    finish(join(fan), m, "Fan", "shell", o)
    for s in (-1, 1):
        spiral = [cyl((s * 3.6, 0, 0.9), 0.8, 1.8, verts=16, bw=0.05)]
        for k in range(6):
            spiral.append(torus((s * 3.6, 0, 1.9 + k * 0.45), 0.72 - k * 0.11, 0.18 - k * 0.015, seg=18, ring=6))
        spiral.append(cone((s * 3.6, 0, 4.7), 0.2, 0.6, verts=10))
        finish(join(spiral), m, "Tower" + ("L" if s < 0 else "R"), "shell", o)
    finish(cyl((0, -2.62, 1.0), 0.8, 0.12, (math.radians(90), 0, 0), verts=24, bw=0.02), m, "Door", "teal", o)
    finish(sphere((0, 0, 3.75), (0.35, 0.35, 0.35), 14, 8), m, "Pearl", "pearl", o)


def coral():
    m = "Coral"  # branching coral, ~3 units tall
    o = Vector((0, 0, 0))
    bits = [cyl((0, 0, 0.6), 0.22, 1.2, verts=10, bw=0)]
    for a, tilt, h in ((0, 30, 1.0), (120, 35, 0.9), (240, 28, 1.1), (60, 15, 0.7)):
        ra, rt = math.radians(a), math.radians(tilt)
        top = Vector((math.cos(ra) * math.sin(rt) * h, math.sin(ra) * math.sin(rt) * h, 1.1 + math.cos(rt) * h))
        mid = (Vector((0, 0, 1.1)) + top) / 2
        bits.append(cyl(mid, 0.15, h, tuple((top - Vector((0, 0, 1.1))).to_track_quat("Z", "Y").to_euler()), verts=8, bw=0))
        bits.append(sphere(top, (0.2, 0.2, 0.2), 10, 6))
    finish(join(bits), m, "Coral", "coral", o)


def kelp():
    m = "Kelp"  # one wavy strand with leaves, ~6 units
    o = Vector((0, 0, 0))
    bits = []
    for i in range(10):
        z = i * 0.6
        x = math.sin(i * 0.8) * 0.18
        bits.append(cyl((x, 0, z + 0.3), 0.07, 0.62, verts=6, bw=0))
        if i % 2 == 1:
            bits.append(sphere((x + 0.22, 0, z + 0.3), (0.28, 0.05, 0.12), 8, 5))
        elif i > 0:
            bits.append(sphere((x - 0.22, 0, z + 0.3), (0.28, 0.05, 0.12), 8, 5))
    finish(join(bits), m, "Kelp", "kelp", o)


def wizard_tower():
    m = "WizardTower"  # plum stone tower, brass band, tall witch-hat roof with a curl, floating crystal above (separate)
    o = Vector((0, 0, 0))
    finish(join([cyl((0, 0, 2.5), 1.0, 5.0, verts=18, bw=0.04), cyl((0, 0, 0.15), 1.2, 0.3, verts=18, bw=0.04)]), m, "Body", "plum", o)
    finish(join([torus((0, 0, 5.0), 1.05, 0.1, seg=24), torus((0, 0, 1.4), 1.02, 0.07, seg=24)]), m, "Bands", "brass", o)
    roof = cone((0, 0, 6.6), 1.45, 3.2, verts=18)
    roof.modifiers.new("bend", "SIMPLE_DEFORM").deform_method = "BEND"
    roof.modifiers["bend"].angle = math.radians(25)
    roof.modifiers["bend"].deform_axis = "Z"
    finish(roof, m, "Roof", "plum", o)
    finish(join([box((math.cos(a) * 0.98, math.sin(a) * 0.98, 3.3), (0.08, 0.22, 0.35), rot=(0, 0, a), bw=0.04) for a in (0.4, 2.5, 4.4)]), m, "Windows", "ember", o)


def fire_crystal():
    m = "FireCrystal"  # cluster of 3 faceted crystals (Studio makes it Neon)
    o = Vector((0, 0, 0))
    bits = []
    for x, y, h, r in ((0, 0, 1.6, 0.42), (0.38, 0.15, 1.0, 0.26), (-0.32, 0.2, 1.1, 0.28)):
        bits.append(cone((x, y, h * 0.3), r, h * 0.6, verts=6, r2=r * 0.95))
        bits.append(cone((x, y, h * 0.6 + h * 0.2), r * 0.95, h * 0.4, verts=6))
        bits.append(cone((x, y, -h * 0.12), r * 0.6, h * 0.24, (math.radians(180), 0, 0), verts=6))
    finish(join(bits), m, "Crystal", "ember", o, smooth=False)


def spellbook():
    m = "Spellbook"  # an open book, flat enough to stand on (Spell Run platforms too): 4 x 2.6 units
    o = Vector((0, 0, 0))
    finish(join([box((s * 1.0, 0, -0.12), (1.0, 1.3, 0.08), rot=(0, math.radians(-s * 6), 0), bw=0.04) for s in (-1, 1)] + [box((0, 0, -0.16), (0.12, 1.3, 0.1), bw=0.03)]), m, "Cover", "bookRed", o)
    finish(join([box((s * 0.95, 0, 0.02), (0.92, 1.22, 0.1), rot=(0, math.radians(-s * 6), 0), bw=0.05) for s in (-1, 1)]), m, "Pages", "pages", o)
    finish(join([torus((s * 0.95, 0, 0.14), 0.4, 0.035, seg=20, ring=4) for s in (-1, 1)]), m, "Rune", "ember", o)


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export(model):
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in bpy.data.objects if o.name.startswith(model + "_")]
    for o in objs:
        o.select_set(True)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, model + ".fbx"), use_selection=True, axis_forward="-Z", axis_up="Y",
                             global_scale=1.0, apply_unit_scale=True, bake_space_transform=False, mesh_smooth_type="FACE")
    return tris, len(objs)


def preview(model, target, ortho):
    sc = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    for e in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        if e in engines:
            sc.render.engine = e
            break
    sc.render.resolution_x = sc.render.resolution_y = 384
    sc.view_settings.view_transform = "Standard"
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.7, 0.8, 0.95, 1)
    bpy.ops.object.light_add(type="SUN", location=(3, -4, 6))
    bpy.context.active_object.data.energy = 2.4
    bpy.context.active_object.rotation_euler = (math.radians(50), 0, math.radians(30))
    bpy.ops.object.camera_add()
    cam = bpy.context.active_object
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    cam.location = Vector(target) + Vector((0.6, -1.0, 0.45)).normalized() * 20
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.filepath = os.path.join(OUT, model + "_preview.png")
    bpy.ops.render.render(write_still=True)


MODELS = (
    (ironclad, "SirIronclad", (0, 0, 3.1), 8.0),
    (treasury, "TreasuryDoor", (0, 0, 2.4), 6.0),
    (keep_tower, "KeepTower", (0, 0, 4.0), 9.5),
    (shell_palace, "ShellPalace", (0, 0, 2.2), 10.5),
    (coral, "Coral", (0, 0, 1.2), 3.6),
    (kelp, "Kelp", (0, 0, 3.0), 6.8),
    (wizard_tower, "WizardTower", (0, 0, 4.0), 9.5),
    (fire_crystal, "FireCrystal", (0, 0, 0.6), 2.6),
    (spellbook, "Spellbook", (0, 0, 0), 3.4),
)
report = {}
for fn, name, target, ortho in MODELS:
    clear()
    fn()
    tris, n = export(name)
    preview(name, target, ortho)
    report[name] = {"tris": tris, "parts": n}
with open(os.path.join(OUT, "parts.json"), "w") as f:
    json.dump({"parts": parts, "report": report}, f, indent=1)
print("IMPORTS034", json.dumps(report))
