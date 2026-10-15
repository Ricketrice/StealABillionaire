# Milestone 035 dragon meshes (Aquaris + Dragon Pup), all original, stylised low poly, flat colours, built from code in
# headless Blender:
#   flatpak run org.blender.Blender -b -P tools/blender/build_035_dragon.py
# Writes assets/export/035/<Model>.fbx (one FBX per model, one mesh object per colour part, named <Model>_<Part>),
# parts.json (tris per model) and <Model>_preview.png. Import each FBX with Studio's 3D Importer into
# ServerStorage.Imports035 (one Model per file, names kept).
#   DragonHead   long snout, nostrils, separate open Jaw (animates), teeth, swept-back Horns, CheekFins, eye Sockets + Eyes,
#                a small Crest. Origin = the neck joint (back/bottom of the skull). Front = -Y (Roblox -Z).
#   DragonWingR  right wing (+X): arm bone, 4 finger bones with a wrist claw, 5 membrane panels, glowing edge trim.
#   DragonWingL  the same wing mirrored to the left (-X). Origin = the shoulder joint.
#   DragonTail   the tail tip: 3 tapering segments, a crossed pair of leaf fins and gold spikes. Origin = where it joins the tail.
# Every model has a tiny "<Model>_Anchor" cube at its origin: CreatureBuilder places each part relative to it.
# Coordinates below are written Roblox-style (x right, y up, z back) and converted by V() to Blender (x, y back, z up);
# the FBX export uses the same axes as 034 (forward -Z, up Y), so the front ends up at -Z in Studio.
import bpy, bmesh, math, os, json
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "export", "035")
os.makedirs(OUT, exist_ok=True)

C = {
    "blue": (0.07, 0.30, 0.66), "blueLight": (0.16, 0.45, 0.82), "cyan": (0.45, 0.90, 0.98), "cyanDark": (0.10, 0.55, 0.75),
    "belly": (0.75, 0.96, 1.0), "gold": (1.0, 0.78, 0.18), "ink": (0.05, 0.07, 0.12), "eye": (0.55, 1.0, 1.0),
    "white": (0.96, 0.97, 1.0),
}
parts = {}


def V(x, y, z):
    return Vector((x, z, y))


def mat(name, rgb):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = 0.6
    m.diffuse_color = (*rgb, 1)
    return m


def to_obj(bm, name="m"):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def bar(p0, p1, w0, h0, w1, h1):
    """A tapered four-sided bar from p0 to p1 (Blender-space points); w/h = width/height at each end."""
    d = (p1 - p0).normalized()
    ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    a = d.cross(ref).normalized()
    b = d.cross(a).normalized()
    bm = bmesh.new()
    rings = []
    for p, w, h in ((p0, w0, h0), (p1, w1, h1)):
        rings.append([bm.verts.new(p + a * sx * w / 2 + b * sy * h / 2) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[1])
    for i in range(4):
        bm.faces.new((rings[0][i], rings[0][(i + 1) % 4], rings[1][(i + 1) % 4], rings[1][i]))
    return to_obj(bm, "bar")


def panel(pts, thick=0.03):
    """A thin flat panel (3+ Blender-space points on one plane), `thick` thick."""
    n = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
    bm = bmesh.new()
    top = [bm.verts.new(p + n * thick / 2) for p in pts]
    bot = [bm.verts.new(p - n * thick / 2) for p in pts]
    bm.faces.new(top)
    bm.faces.new(bot[::-1])
    k = len(pts)
    for i in range(k):
        bm.faces.new((top[i], bot[i], bot[(i + 1) % k], top[(i + 1) % k]))
    return to_obj(bm, "panel")


def sphere(loc, scale, seg=10, ring=7):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ring, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return o


def cone(loc, r, h, rot=(0, 0, 0), verts=6, r2=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc, rotation=rot)
    o = bpy.context.active_object
    bpy.ops.object.transform_apply(rotation=True)
    return o


def spike(base, tip, r=0.1, verts=5):
    """A four-sided spike from `base` to `tip` (a tapering bar: no rotation maths, so it lands exactly)."""
    return bar(base, tip, r * 2, r * 2, 0.02, 0.02)


def join(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    return objs[0]


def finish(o, model, name, colour):
    o.name = f"{model}_{name}"
    o.data.materials.clear()
    o.data.materials.append(mat(colour, C[colour]))
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.shade_flat()
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    o.select_set(False)
    parts.setdefault(model, []).append({"name": o.name, "colour": colour})
    return o


def anchor(model):
    bpy.ops.mesh.primitive_cube_add(size=0.04, location=(0, 0, 0))
    finish(bpy.context.active_object, model, "Anchor", "ink")


# ---------------------------------------------------------------------------------------------------------------------
def head():
    m = "DragonHead"
    anchor(m)
    # skull + brow ridge
    finish(join([sphere(V(0, 0.55, -0.55), (0.62, 0.95, 0.55), 12, 8), bar(V(0, 0.95, -0.55), V(0, 0.95, -1.05), 1.0, 0.18, 0.95, 0.14)]), m, "Skull", "blue")
    # long boxy snout, tapering to the nose
    finish(join([bar(V(0, 0.5, -1.0), V(0, 0.42, -3.0), 0.78, 0.62, 0.52, 0.42), bar(V(0, 0.76, -2.0), V(0, 0.7, -2.95), 0.3, 0.1, 0.26, 0.1)]), m, "Snout", "blueLight")
    # lower jaw hangs from the back of the skull so it can open (the builder swings it about the origin end)
    finish(join([bar(V(0, 0.12, -0.35), V(0, 0.08, -2.8), 0.62, 0.22, 0.34, 0.14), bar(V(0, 0.2, -2.7), V(0, 0.2, -2.8), 0.4, 0.2, 0.3, 0.18)]), m, "Jaw", "belly")
    # teeth: upper row under the snout, lower row on the jaw
    teeth = []
    for i in range(5):
        z = -1.5 - i * 0.3
        for s in (-1, 1):
            teeth.append(spike(V(s * (0.3 - i * 0.03), 0.2, z), V(s * (0.3 - i * 0.03), -0.04, z), 0.05, 4))
    finish(join(teeth), m, "Teeth", "white")
    finish(join([sphere(V(s * 0.14, 0.68, -2.95), (0.09, 0.08, 0.07), 6, 4) for s in (-1, 1)]), m, "Nostrils", "ink")
    # swept-back horns: two tapering segments each, gold
    horns = []
    for s in (-1, 1):
        horns.append(bar(V(s * 0.33, 1.0, -0.15), V(s * 0.55, 1.45, 0.85), 0.26, 0.26, 0.17, 0.17))
        horns.append(bar(V(s * 0.55, 1.45, 0.85), V(s * 0.72, 1.35, 1.9), 0.17, 0.17, 0.04, 0.04))
    finish(join(horns), m, "Horns", "gold")
    # cheek fins: flat triangles flaring back from the jaw hinge
    fins = []
    for s in (-1, 1):
        fins.append(panel([V(s * 0.62, 0.35, -0.5), V(s * 1.55, 0.55, 0.35), V(s * 1.2, -0.05, 0.55), V(s * 0.62, -0.1, -0.1)], 0.05))
    finish(join(fins), m, "CheekFins", "cyan")
    # eye sockets (dark) with big glowing eyes
    finish(join([sphere(V(s * 0.46, 0.78, -0.82), (0.24, 0.2, 0.2), 8, 6) for s in (-1, 1)]), m, "Sockets", "ink")
    finish(join([sphere(V(s * 0.49, 0.8, -0.9), (0.17, 0.12, 0.15), 8, 6) for s in (-1, 1)]), m, "Eyes", "eye")
    # small crest of spikes down the skull
    finish(join([spike(V(0, 1.05, -0.1 + i * 0.4), V(0, 1.6 - i * 0.12, 0.05 + i * 0.4), 0.11, 5) for i in range(3)]), m, "Crest", "gold")


def wing(model, sx):
    anchor(model)
    S = V(0, 0, 0)
    E, W = V(sx * 1.9, 1.4, 0.6), V(sx * 3.8, 2.1, -0.5)
    T = [V(sx * 6.0, 1.7, -1.3), V(sx * 5.8, 0.2, 0.9), V(sx * 4.5, -0.9, 2.1), V(sx * 2.7, -1.1, 2.5)]
    bones = [sphere(S, (0.34, 0.34, 0.34), 8, 6), bar(S, E, 0.34, 0.3, 0.26, 0.24), bar(E, W, 0.26, 0.24, 0.2, 0.2)]
    for t in T:
        bones.append(bar(W, t, 0.16, 0.14, 0.05, 0.05))
    finish(join(bones), model, "Bones", "blue")
    finish(spike(W, W + V(sx * 0.2, 0.55, -0.55) - V(0, 0, 0), 0.1, 5), model, "Claw", "gold")

    def inset(pts, k=0.1):
        c = sum(pts, Vector()) / len(pts)
        return [p + (c - p) * k for p in pts]

    tris = [(W, T[0], T[1]), (W, T[1], T[2]), (W, T[2], T[3]), (E, W, T[3]), (S, E, T[3])]
    finish(join([panel(inset(list(t), 0.07), 0.035) for t in tris]), model, "Membrane", "cyan")
    # glowing trailing edge between the fingertips
    finish(join([bar(T[i], T[i + 1], 0.07, 0.07, 0.07, 0.07) for i in range(3)] + [bar(T[3], E, 0.07, 0.07, 0.07, 0.07)]), model, "Edge", "cyanDark")


def tail():
    m = "DragonTail"
    anchor(m)
    pts = [V(0, 0, 0), V(0, -0.05, 0.9), V(0, -0.1, 1.7), V(0, -0.1, 2.4)]
    sizes = [0.62, 0.48, 0.36, 0.26]
    finish(join([bar(pts[i], pts[i + 1], sizes[i], sizes[i] * 0.85, sizes[i + 1], sizes[i + 1] * 0.85) for i in range(3)]), m, "Segments", "blue")
    fin_v = [V(0, -0.1, 2.3), V(0, 1.0, 3.2), V(0, 0.15, 4.3), V(0, -1.2, 3.2)]
    fin_h = [V(0, -0.1, 2.3), V(1.1, -0.1, 3.2), V(0, -0.1, 4.3), V(-1.1, -0.1, 3.2)]
    finish(join([panel(fin_v, 0.07), panel(fin_h, 0.07)]), m, "Fin", "cyan")
    finish(join([spike(V(0, 0.25, 0.4 + i * 0.7), V(0, 0.95 - i * 0.12, 0.6 + i * 0.7), 0.13, 5) for i in range(3)] + [spike(V(0, -0.1, 4.2), V(0, -0.1, 5.0), 0.16, 5)]), m, "Spikes", "gold")


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


def preview(model, target, ortho, view):
    sc = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    for e in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        if e in engines:
            sc.render.engine = e
            break
    sc.render.resolution_x = sc.render.resolution_y = 420
    sc.view_settings.view_transform = "Standard"
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.85, 0.95, 1)
    bpy.ops.object.light_add(type="SUN", location=(3, -4, 6))
    bpy.context.active_object.data.energy = 2.6
    bpy.context.active_object.rotation_euler = (math.radians(50), 0, math.radians(30))
    bpy.ops.object.camera_add()
    cam = bpy.context.active_object
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    cam.location = Vector(target) + Vector(view).normalized() * 25
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.filepath = os.path.join(OUT, model + "_preview.png")
    bpy.ops.render.render(write_still=True)


MODELS = (
    (head, "DragonHead", V(0, 0.6, -1.4), 4.4, (1.0, 0.05, 0.25)),
    (lambda: wing("DragonWingR", 1), "DragonWingR", V(3.2, 0.8, 0.5), 8.2, (0.0, 0.05, 1.0)),
    (lambda: wing("DragonWingL", -1), "DragonWingL", V(-3.2, 0.8, 0.5), 8.2, (0.0, 0.05, 1.0)),
    (tail, "DragonTail", V(0, 0.6, 2.4), 6.2, (1.0, 0.1, 0.35)),
)
report = {}
for fn, name, target, ortho, view in MODELS:
    clear()
    fn()
    tris, n = export(name)
    preview(name, target, ortho, view)
    report[name] = {"tris": tris, "parts": n}
with open(os.path.join(OUT, "parts.json"), "w") as f:
    json.dump({"parts": parts, "report": report}, f, indent=1)
print("DRAGON035", json.dumps(report))
