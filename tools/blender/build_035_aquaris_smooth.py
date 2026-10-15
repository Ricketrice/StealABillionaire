# Aquaris, smooth glossy version (design-first, Studio not touched). Run headless:
#   flatpak run org.blender.Blender -b -P tools/blender/build_035_aquaris_smooth.py
# One organic body mesh (head, short neck, body, legs, curled tail) = Skin modifier on a stick skeleton + Subdivision Surface,
# shade smooth, 3 materials (blue / ice belly / belly plate lines). Separate objects: Jaw, WingR, WingL, eyes, horns, fins,
# crest, back spikes, claws, tail fin. Front = -Y, up = +Z, ground z = 0.
# Writes assets/blender/creatures/Aquaris_smooth.blend and ~/Pictures/035_preview/aquaris_{front,side,threequarter}.png
import bpy, bmesh, math, os, json
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLEND = os.path.join(ROOT, "assets", "blender", "creatures", "Aquaris_smooth.blend")
PREV = os.path.expanduser("~/Pictures/035_preview")
os.makedirs(os.path.dirname(BLEND), exist_ok=True)
os.makedirs(PREV, exist_ok=True)


def hexc(h):
    h = h.lstrip("#")
    lin = lambda c: ((c / 255 + 0.055) / 1.055) ** 2.4 if c / 255 > 0.04045 else c / 255 / 12.92
    return (lin(int(h[0:2], 16)), lin(int(h[2:4], 16)), lin(int(h[4:6], 16)), 1)


BLUE, ICE, GOLD, CYAN = "#1F5FD1", "#A8F0FF", "#FFC83D", "#3FE6FF"
bpy.ops.wm.read_factory_settings(use_empty=True)
root = bpy.data.objects.new("Aquaris", None)
bpy.context.scene.collection.objects.link(root)
mats = {}


def mat(name, color, rough=0.28, emit=0.0, coat=0.6, metal=0.0):
    if name in mats:
        return mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = hexc(color)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    for k, v in (("Coat Weight", coat), ("Clearcoat", coat)):
        if k in b.inputs:
            b.inputs[k].default_value = v
    if emit > 0:
        for k in ("Emission Color", "Emission"):
            if k in b.inputs:
                b.inputs[k].default_value = hexc(color)
        if "Emission Strength" in b.inputs:
            b.inputs["Emission Strength"].default_value = emit
    mats[name] = m
    return m


def finish(o, m, smooth=True, parent=True):
    o.data.materials.clear()
    if isinstance(m, (list, tuple)):
        for x in m:
            o.data.materials.append(x)
    else:
        o.data.materials.append(m)
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
    if parent:
        o.parent = root
    return o


def link(name, me):
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def ellipsoid(name, loc, scale, rot=(0, 0, 0), m=None, seg=14, rings=9):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = link(name, me)
    o.location, o.scale, o.rotation_euler = loc, scale, rot
    return finish(o, m)


def tube(name, pts, radii, m, sides=8, ref=(1, 0, 0)):
    pts = [Vector(p) for p in pts]
    bm = bmesh.new()
    rings = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        a = t.cross(Vector(ref))
        if a.length < 0.05:
            a = t.cross(Vector((0, 0, 1)))
        a.normalize()
        b = t.cross(a).normalized()
        rings.append([bm.verts.new(p + (a * math.cos(2 * math.pi * k / sides) + b * math.sin(2 * math.pi * k / sides)) * radii[i]) for k in range(sides)])
    for i in range(len(rings) - 1):
        for k in range(sides):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
    for ring, tip in ((rings[0], pts[0]), (rings[-1], pts[-1])):
        bm.faces.new(ring if ring is rings[-1] else ring[::-1])
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return finish(link(name, me), m)


# ---------------------------------------------------------------- body (one organic mesh)
# (x, y, z, rx, rz) -- skin radii; edges below
N = {
    "tail5": (0, 5.35, 2.35, 0.20, 0.20), "tail4": (0, 5.0, 1.65, 0.30, 0.30), "tail3": (0, 4.35, 1.2, 0.42, 0.42),
    "tail2": (0, 3.5, 1.15, 0.58, 0.56), "tail1": (0, 2.6, 1.4, 0.80, 0.78),
    "rump": (0, 1.5, 1.75, 1.05, 1.02), "belly": (0, 0.2, 1.8, 1.28, 1.2), "chest": (0, -1.0, 1.95, 1.22, 1.16),
    "neck": (0, -1.85, 2.45, 0.85, 0.85), "skull": (0, -2.55, 2.95, 1.0, 0.98), "face": (0, -3.2, 3.0, 1.0, 0.92),
    "snout": (0, -3.95, 2.85, 0.62, 0.5),
    "hipFR": (0.85, -0.9, 1.35, 0.5, 0.5), "footFR": (0.98, -1.15, 0.38, 0.42, 0.38),
    "hipFL": (-0.85, -0.9, 1.35, 0.5, 0.5), "footFL": (-0.98, -1.15, 0.38, 0.42, 0.38),
    "hipBR": (0.9, 1.2, 1.35, 0.55, 0.55), "footBR": (1.02, 1.4, 0.4, 0.45, 0.4),
    "hipBL": (-0.9, 1.2, 1.35, 0.55, 0.55), "footBL": (-1.02, 1.4, 0.4, 0.45, 0.4),
}
EDGES = [
    ("tail5", "tail4"), ("tail4", "tail3"), ("tail3", "tail2"), ("tail2", "tail1"), ("tail1", "rump"), ("rump", "belly"),
    ("belly", "chest"), ("chest", "neck"), ("neck", "skull"), ("skull", "face"), ("face", "snout"),
    ("chest", "hipFR"), ("hipFR", "footFR"), ("chest", "hipFL"), ("hipFL", "footFL"),
    ("rump", "hipBR"), ("hipBR", "footBR"), ("rump", "hipBL"), ("hipBL", "footBL"),
]
names = list(N)
me = bpy.data.meshes.new("Aquaris_Body")
me.from_pydata([N[n][:3] for n in names], [(names.index(a), names.index(b)) for a, b in EDGES], [])
body = link("Aquaris_Body", me)
body.parent = root
sk = body.modifiers.new("Skin", "SKIN")
sk.branch_smoothing = 1.0
sk.use_smooth_shade = True
body.data.skin_vertices[0].data  # create layer
bpy.context.view_layer.objects.active = body
bpy.ops.object.skin_root_mark() if False else None
for i, n in enumerate(names):
    d = body.data.skin_vertices[0].data[i]
    d.radius = (N[n][3], N[n][4])
    d.use_root = n == "belly"
ss = body.modifiers.new("Subsurf", "SUBSURF")
ss.levels = ss.render_levels = 2
bpy.context.view_layer.objects.active = body
body.select_set(True)
bpy.ops.object.modifier_apply(modifier="Skin")
bpy.ops.object.modifier_apply(modifier="Subsurf")
bpy.ops.object.shade_smooth()
BODY_TRIS_FULL = sum(len(p.vertices) - 2 for p in body.data.polygons)

# trim to budget: collapse-decimate the body if it is too dense (keeps the silhouette, triangles are hidden by smooth shading)
TARGET_BODY = 5200  # (the skin + subsurf body is ~3.6k, so normally no decimation)
if BODY_TRIS_FULL > TARGET_BODY:
    dm = body.modifiers.new("Dec", "DECIMATE")
    dm.ratio = TARGET_BODY / BODY_TRIS_FULL
    bpy.ops.object.modifier_apply(modifier="Dec")
    bpy.ops.object.shade_smooth()

m_belly = mat("AquarisIce", ICE, 0.3, coat=0.5)
# body colour = smooth per-vertex colours (blue back, ice belly with soft plate bands): exportable, no hard patches
m_body = mat("AquarisBody", BLUE, 0.25, coat=0.8)
nt = m_body.node_tree
attr = nt.nodes.new("ShaderNodeAttribute")
attr.attribute_name = "Col"
nt.links.new(attr.outputs["Color"], next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"])
finish(body, m_body)


def sstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


col = body.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
cb, ci, cl = hexc(BLUE), hexc(ICE), hexc("#6FC4E8")
for v in body.data.vertices:
    c, n = v.co, v.normal
    m = sstep(0.1, 0.5, -n.z) * sstep(-2.9, -2.3, c.y) * (1 - sstep(2.7, 3.7, c.y)) * (1 - sstep(0.55, 0.95, abs(c.x))) * sstep(0.3, 0.7, c.z)
    band = 0.0
    if -1.7 < c.y < 2.3:
        band = sstep(0.55, 1.0, 0.5 + 0.5 * math.cos(2 * math.pi * c.y / 0.5)) * 0.55
    k = [ci[i] * (1 - band) + cl[i] * band for i in range(3)]
    col.data[v.index].color = [cb[i] * (1 - m) + k[i] * m for i in range(3)] + [1]
bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())


def hit(origin, direction):
    r = bvh.ray_cast(Vector(origin), Vector(direction))
    return r[0], r[1]


def top(x, y):
    h = hit((x, y, 12), (0, 0, -1))
    return h[0]


# ---------------------------------------------------------------- head details
glow = mat("Glow", CYAN, 0.2, emit=3.0, coat=0.0)
ink = mat("Pupil", "#071225", 0.15, coat=0.0)
gold = mat("Gold", GOLD, 0.22, coat=0.4, metal=0.6)
ice = mat("IceTrim", ICE, 0.3, coat=0.3)
for s in (1, -1):
    h, _ = hit((s * 4, -3.45, 3.3), (-s, 0, 0))
    ellipsoid("Aquaris_Eye" + ("R" if s > 0 else "L"), (h.x - s * 0.22, h.y - 0.05, h.z), (0.38, 0.38, 0.42), m=glow, seg=14, rings=10)
    ellipsoid("Aquaris_Pupil" + ("R" if s > 0 else "L"), (h.x - s * 0.22 + s * 0.17, h.y - 0.3, h.z), (0.17, 0.2, 0.32), m=ink, seg=10, rings=8)
    nh, _ = hit((s * 0.2, -7, 2.98), (0, 1, 0))
    ellipsoid("Aquaris_Nostril" + ("R" if s > 0 else "L"), (nh.x, nh.y + 0.02, nh.z), (0.07, 0.05, 0.05), m=ink, seg=8, rings=6)
    ch, _ = hit((s * 4, -2.5, 2.8), (-s, 0, 0))
    ellipsoid("Aquaris_CheekFin" + ("R" if s > 0 else "L"), (ch.x + s * 0.12, ch.y + 0.35, ch.z), (0.05, 0.5, 0.26), (0, 0, s * math.radians(-28)), m=glow, seg=10, rings=7)
    b = top(s * 0.5, -2.45)
    tube("Aquaris_Horn" + ("R" if s > 0 else "L"), [b - Vector((0, 0, 0.1)), b + Vector((s * 0.12, 0.45, 0.4)), b + Vector((s * 0.32, 1.1, 0.62)), b + Vector((s * 0.5, 1.8, 0.5))], [0.22, 0.17, 0.1, 0.02], gold, sides=8)
for i, y in enumerate((-2.85, -2.5, -2.15)):
    t = top(0, y)
    tube("Aquaris_Crest%d" % (i + 1), [t - Vector((0, 0, 0.05)), t + Vector((0, 0.18, 0.4 - i * 0.07))], [0.13, 0.015], gold, sides=6)
# jaw (moves): ice-blue lower jaw with a lip
jaw = ellipsoid("Aquaris_Jaw", (0, -3.2, 2.15), (0.5, 0.55, 0.2), (math.radians(4), 0, 0), m=m_belly, seg=14, rings=8)

# ---------------------------------------------------------------- back spikes, claws, tail fin
for i, y in enumerate((-1.5, -0.75, 0.0, 0.75, 1.5, 2.2, 2.9, 3.6, 4.25)):
    t = top(0, y) if y < 4.5 else None
    if y > 2.5:  # tail curls: ray from above still lands on the top of the tail
        t = top(0, y)
    if t:
        k = max(0.35, 0.62 - i * 0.03)
        tube("Aquaris_Spike%d" % (i + 1), [t - Vector((0, 0, 0.06)), t + Vector((0, 0.1, k))], [0.12, 0.012], glow, sides=6)
for nm in ("FR", "FL", "BR", "BL"):
    n = N["foot" + nm]
    h, _ = hit((n[0], -7, 0.45), (0, 1, 0))
    for k in (-1, 0, 1):
        x = h.x + k * 0.2
        tube("Aquaris_Claw%s%d" % (nm, k + 1), [(x, h.y + 0.2, 0.3), (x, h.y - 0.22, 0.12)], [0.095, 0.012], gold, sides=6)
tip = Vector(N["tail5"][:3])
ellipsoid("Aquaris_TailFinV", tip + Vector((0, 0.45, 0.5)), (0.04, 0.72, 0.62), (math.radians(-35), 0, 0), m=gold)
ellipsoid("Aquaris_TailFinH", tip + Vector((0, 0.45, 0.5)), (0.7, 0.62, 0.04), (math.radians(-35), 0, 0), m=gold)

# ---------------------------------------------------------------- wings (folded up and back, solid membrane)
mem = mat("Membrane", "#2C7BE6", 0.35, coat=0.2)
bone = mat("WingBone", "#1748B0", 0.3, coat=0.4)
S0, E0, W0 = Vector((0.75, -0.3, 3.0)), Vector((1.5, 0.0, 4.0)), Vector((1.25, 1.0, 4.55))
TIPS = [Vector(v) for v in ((1.95, 2.7, 4.9), (1.75, 3.6, 4.1), (1.45, 4.2, 3.3), (1.05, 4.4, 2.6))]
BASE = Vector((0.55, 2.5, 2.75))


def wing(side):
    s = 1 if side == "R" else -1
    F = lambda v: Vector((v.x * s, v.y, v.z))
    edge = []
    for i, t in enumerate(TIPS):
        edge.append(t)
        nxt = TIPS[i + 1] if i + 1 < len(TIPS) else BASE
        edge.append((t + nxt) / 2 + (W0 - (t + nxt) / 2).normalized() * 0.45)
    edge.append(BASE)
    bm = bmesh.new()
    W = bm.verts.new(F(W0))
    ev = [bm.verts.new(F(p)) for p in edge]
    S = bm.verts.new(F(S0))
    E = bm.verts.new(F(E0))
    seq = [W] + ev
    for i in range(len(ev) - 1):
        bm.faces.new((W, ev[i], ev[i + 1]) if s > 0 else (W, ev[i + 1], ev[i]))
    bm.faces.new((W, ev[-1], S) if s > 0 else (W, S, ev[-1]))
    bm.faces.new((W, S, E) if s > 0 else (W, E, S))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("Aquaris_Wing" + side)
    bm.to_mesh(me)
    bm.free()
    o = link("Aquaris_Wing" + side, me)
    o.parent = root
    sd = o.modifiers.new("Solid", "SOLIDIFY")
    sd.thickness = 0.07
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier="Solid")
    finish(o, mem, smooth=False)
    # bones and glowing-ice edge trim
    tube("Aquaris_WingArm" + side, [F(S0), F(E0), F(W0)], [0.17, 0.14, 0.1], bone, sides=8)
    for i, t in enumerate(TIPS):
        tube("Aquaris_WingFinger%s%d" % (side, i + 1), [F(W0), F((W0 + t) / 2 + Vector((0, 0, 0.05))), F(t)], [0.085, 0.06, 0.03], bone, sides=6)
    tube("Aquaris_WingEdge" + side, [F(p) for p in edge], [0.05] * len(edge), ice, sides=6)
    tube("Aquaris_WingClaw" + side, [F(W0 + Vector((0, -0.05, 0.12))), F(W0 + Vector((0.1, -0.5, 0.35)))], [0.1, 0.012], gold, sides=6)


wing("R")
wing("L")

# ---------------------------------------------------------------- report, save, previews
objs = [o for o in bpy.data.objects if o.type == "MESH"]
tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs}
total = sum(tris.values())
print("AQUARIS_SMOOTH body_full=%d total_tris=%d objects=%d" % (BODY_TRIS_FULL, total, len(objs)))
bpy.ops.wm.save_as_mainfile(filepath=BLEND)

sc = bpy.context.scene
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "CYCLES"):
    if e in engines:
        sc.render.engine = e
        break
if sc.render.engine == "CYCLES":
    sc.cycles.samples = 48
sc.render.resolution_x, sc.render.resolution_y = 1100, 850
sc.view_settings.view_transform = "Standard"
sc.world = bpy.data.worlds.new("w")
sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.86, 0.9, 0.95, 1)
sc.world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
for loc, en, rot in (((6, -8, 9), 3.2, (math.radians(50), 0, math.radians(35))), ((-7, -5, 5), 1.2, (math.radians(70), 0, math.radians(-50)))):
    bpy.ops.object.light_add(type="SUN", location=loc)
    L = bpy.context.active_object
    L.data.energy, L.rotation_euler = en, rot
bpy.ops.object.camera_add()
cam = bpy.context.active_object
cam.data.lens = 55
sc.camera = cam
target = Vector((0, 0.5, 2.5))
for name, pos in (("front", (0, -15, 3.6)), ("side", (15, 0.4, 3.0)), ("threequarter", (9.5, -10.5, 5.6))):
    cam.location = pos
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(PREV, "aquaris_%s.png" % name)
    bpy.ops.render.render(write_still=True)
print("AQUARIS_SMOOTH_DONE", json.dumps({"engine": sc.render.engine, "tris": total}))
