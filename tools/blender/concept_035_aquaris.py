# Aquaris CONCEPT pass (design sheet only, not production). Three variations, each rendered front / side / 3-4 / silhouette:
#   A balanced dragon, B fiercer dragon, C younger but still cool dragon.
#   flatpak run org.blender.Blender -b -P $PWD/tools/blender/concept_035_aquaris.py
# Then: python3 tools/blender/assemble_concept_035.py  (Blender has no PIL).
# Output: ~/Pictures/035_preview/concept/aquaris_concept_{A,B,C}.png (one sheet each) + aquaris_concept_all.png.
# Anatomy: chest-forward torso with a waist, raised tapered neck, wedge head (brow ridges, long snout, jaw, slit-pupil eyes),
# bent legs with elbows/knees/hocks and flat clawed feet, long tapered tail, shoulder-mounted thick-membrane wings.
import bpy, bmesh, math, os
from mathutils import Vector
from mathutils.bvhtree import BVHTree

OUT = os.path.expanduser("~/Pictures/035_preview/concept")
TMP = os.path.join(OUT, "tiles")
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)


def hexc(h):
    h = h.lstrip("#")
    lin = lambda c: ((c / 255 + 0.055) / 1.055) ** 2.4 if c / 255 > 0.04045 else c / 255 / 12.92
    return (lin(int(h[0:2], 16)), lin(int(h[2:4], 16)), lin(int(h[4:6], 16)), 1)


BLUE, ICE, GOLD, CYAN = "#1F5FD1", "#A8F0FF", "#FFC83D", "#3FE6FF"
# variation knobs
VARS = {
    "A": dict(label="A  balanced", chest=1.0, head=1.0, horn=1.0, wing=0.85, spike=1.0, brow=0.0, teeth=False, tilt=0.0, blue="#1F5FD1", horns2=False, stance=1.0),
    "B": dict(label="B  fiercer", chest=1.2, head=1.1, horn=1.8, wing=1.15, spike=2.0, brow=1.0, teeth=True, tilt=1.0, blue="#1B54C0", horns2=True, stance=1.0),
    "C": dict(label="C  younger, still cool", chest=0.9, head=1.35, horn=0.55, wing=0.6, spike=0.6, brow=0.4, teeth=False, tilt=0.5, blue="#2467DB", horns2=False, stance=0.9),
}


def build(v):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = {}

    def mat(name, color, rough=0.3, emit=0.0, coat=0.5, metal=0.0):
        if name in mats:
            return mats[name]
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        b.inputs["Base Color"].default_value = hexc(color)
        b.inputs["Roughness"].default_value = rough
        b.inputs["Metallic"].default_value = metal
        if "Coat Weight" in b.inputs:
            b.inputs["Coat Weight"].default_value = coat
        if emit > 0:
            b.inputs["Emission Color"].default_value = hexc(color)
            b.inputs["Emission Strength"].default_value = emit
        mats[name] = m
        return m

    def link(name, me):
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        return o

    def finish(o, m, smooth=True):
        o.data.materials.clear()
        o.data.materials.append(m)
        for p in o.data.polygons:
            p.use_smooth = smooth
        return o

    def ell(name, loc, scale, rot, m, seg=14, rings=9):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        o = link(name, me)
        o.location, o.scale, o.rotation_euler = loc, scale, rot
        return finish(o, m)

    def tube(name, pts, radii, m, sides=8, smooth=True):
        pts = [Vector(p) for p in pts]
        bm = bmesh.new()
        rings = []
        for i, p in enumerate(pts):
            t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
            a = t.cross(Vector((1, 0, 0)))
            if a.length < 0.05:
                a = t.cross(Vector((0, 0, 1)))
            a.normalize()
            b = t.cross(a).normalized()
            rings.append([bm.verts.new(p + (a * math.cos(2 * math.pi * k / sides) + b * math.sin(2 * math.pi * k / sides)) * radii[i]) for k in range(sides)])
        for i in range(len(rings) - 1):
            for k in range(sides):
                bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])
        bm.normal_update()
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        return finish(link(name, me), m, smooth)

    # ---------------------------------------------------------------- body: one skinned mesh with real anatomy
    c, h, st = v["chest"], v["head"], v["stance"]
    N = {
        # tail (long, tapered, gentle S, rising tip)
        "t6": (0, 7.3, 2.25, 0.15, 0.14), "t5": (0, 6.65, 1.65, 0.23, 0.21), "t4": (0, 5.8, 1.25, 0.33, 0.3), "t3": (0, 4.85, 1.2, 0.46, 0.42),
        "t2": (0, 3.9, 1.45, 0.62, 0.58), "t1": (0, 2.95, 1.85, 0.82, 0.78),
        # torso: heavy chest, narrower waist, strong hips
        "hips": (0, 1.9, 2.15, 1.2, 1.15), "waist": (0, 0.7, 2.1, 1.1, 1.05), "chest": (0, -0.7, 2.35, 1.5 * c, 1.5 * c),
        # neck: raised, tapering into the head
        "n1": (0, -1.7, 3.05, 1.05, 1.08), "n2": (0, -2.25, 3.7, 0.82, 0.84),
        # head: skull, long wedge snout
        "skull": (0, -2.8, 4.15, 0.95 * h, 0.88 * h), "snout1": (0, -3.7, 4.02, 0.66 * h, 0.54 * h), "snout2": (0, -4.45, 3.9, 0.5 * h, 0.4 * h),
    }
    EDG = [("t6", "t5"), ("t5", "t4"), ("t4", "t3"), ("t3", "t2"), ("t2", "t1"), ("t1", "hips"), ("hips", "waist"), ("waist", "chest"),
           ("chest", "n1"), ("n1", "n2"), ("n2", "skull"), ("skull", "snout1"), ("snout1", "snout2")]
    for s, sd in ((1, "R"), (-1, "L")):
        # front leg: shoulder, elbow, wrist, paw
        N["fs" + sd] = (s * 1.15, -0.8, 1.8, 0.78, 0.78)
        N["fe" + sd] = (s * 1.3, -0.95, 1.05, 0.62, 0.62)
        N["fw" + sd] = (s * 1.25, -1.2, 0.5, 0.5, 0.5)
        N["fp" + sd] = (s * 1.25, -1.75, 0.24, 0.55, 0.24)
        EDG += [("chest", "fs" + sd), ("fs" + sd, "fe" + sd), ("fe" + sd, "fw" + sd), ("fw" + sd, "fp" + sd)]
        # hind leg: thigh, knee, hock (digitigrade), foot
        N["ht" + sd] = (s * 1.3, 1.7, 1.9, 0.95, 0.95)
        N["hk" + sd] = (s * 1.45, 1.2, 1.1, 0.65, 0.65)
        N["hh" + sd] = (s * 1.35, 1.9, 0.6, 0.5, 0.5)
        N["hf" + sd] = (s * 1.35, 1.65, 0.24, 0.56, 0.24)
        EDG += [("hips", "ht" + sd), ("ht" + sd, "hk" + sd), ("hk" + sd, "hh" + sd), ("hh" + sd, "hf" + sd)]
    names = list(N)
    me = bpy.data.meshes.new("Body")
    me.from_pydata([N[n][:3] for n in names], [(names.index(a), names.index(b)) for a, b in EDG], [])
    body = link("Body", me)
    sk = body.modifiers.new("Skin", "SKIN")
    sk.branch_smoothing = 1.0
    sk.use_smooth_shade = True
    body.data.skin_vertices[0].data
    for i, n in enumerate(names):
        d = body.data.skin_vertices[0].data[i]
        d.radius = (N[n][3], N[n][4])
        d.use_root = n == "waist"
    ss = body.modifiers.new("Subsurf", "SUBSURF")
    ss.levels = ss.render_levels = 2
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier="Skin")
    bpy.ops.object.modifier_apply(modifier="Subsurf")
    bpy.ops.object.shade_smooth()

    bm_ = mat("Body", v["blue"], 0.25, coat=0.8)
    nt = bm_.node_tree
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Col"
    nt.links.new(attr.outputs["Color"], next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"])
    finish(body, bm_)

    def sstep(a, b, x):
        t = max(0.0, min(1.0, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)

    col = body.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    cb, ci, cl = hexc(v["blue"]), hexc(ICE), hexc("#6FC4E8")
    for vt in body.data.vertices:
        p, n = vt.co, vt.normal
        m = sstep(0.05, 0.45, -n.z) * sstep(-3.4, -2.4, p.y) * (1 - sstep(3.0, 4.2, p.y)) * (1 - sstep(0.6, 1.0, abs(p.x))) * sstep(0.45, 0.9, p.z)
        band = sstep(0.55, 1.0, 0.5 + 0.5 * math.cos(2 * math.pi * p.y / 0.55)) * 0.5 if -1.9 < p.y < 2.6 else 0.0
        k = [ci[i] * (1 - band) + cl[i] * band for i in range(3)]
        col.data[vt.index].color = [cb[i] * (1 - m) + k[i] * m for i in range(3)] + [1]
    bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())

    def ray(o, d):
        r = bvh.ray_cast(Vector(o), Vector(d))
        return r[0]

    def top(x, y):
        return ray((x, y, 14), (0, 0, -1))

    gold = mat("Gold", GOLD, 0.22, coat=0.4, metal=0.6)
    glow = mat("Glow", CYAN, 0.2, emit=3.0, coat=0.0)
    ink = mat("Ink", "#071225", 0.15, coat=0.0)
    white = mat("Tooth", "#F4FAFF", 0.3, coat=0.2)
    horn_m = gold
    blue = mat("Blue", v["blue"], 0.25, coat=0.8)

    # ---------------------------------------------------------------- head
    hz, hy = 4.1, -3.0
    for s, sd in ((1, "R"), (-1, "L")):
        # brow ridge: angled blue wedge over the eye gives the fierce / confident look
        ell("Brow" + sd, (s * 0.46 * h, hy - 0.5, hz + 0.34 * h), (0.34 * h, 0.5 * h, 0.14 * h), (math.radians(-10 - 8 * v["brow"]), 0, s * math.radians(-18 - 14 * v["tilt"])), blue)
        # almond eye, slanted, with slit pupil
        e = ray((s * 4, hy - 0.45, hz + 0.08 * h), (-s, 0, 0))
        ell("Eye" + sd, (e.x - s * 0.08, e.y, e.z), (0.12, 0.3 * h, 0.15 * h), (0, 0, 0), glow, seg=12, rings=8).rotation_euler = (math.radians(-14 * (1 + v["tilt"])), 0, 0)
        ell("Pupil" + sd, (e.x - s * 0.08 + s * 0.1, e.y - 0.04, e.z), (0.07, 0.07 * h, 0.14 * h), (math.radians(-14 * (1 + v["tilt"])), 0, 0), ink, seg=8, rings=6)
        # nostril
        nh = ray((s * 0.2, -8, hz - 0.2), (0, 1, 0))
        ell("Nostril" + sd, (nh.x, nh.y + 0.02, nh.z), (0.06, 0.05, 0.05), (0, 0, 0), ink, seg=8, rings=6)
        # cheek frills (two swept fins)
        for j, (dy, ds) in enumerate(((0.1, 1.0), (0.55, 0.75))):
            f = ray((s * 4, hy + dy, hz - 0.15), (-s, 0, 0))
            ell("Frill%s%d" % (sd, j), (f.x + s * 0.12, f.y + 0.35 * ds, f.z - 0.02 - 0.1 * j), (0.04, 0.5 * ds * h, 0.2 * ds * h), (0, 0, s * math.radians(-28)), glow)
        # horn: thick conical base blending into the skull, long sweep back and up
        b = ray((s * 0.42, hy + 0.15, 9), (0, 0, -1))
        k = v["horn"]
        pts = [b - Vector((0, 0, 0.12)), b + Vector((s * 0.1, 0.35 * k, 0.28 * k)), b + Vector((s * 0.28, 1.0 * k, 0.55 * k)), b + Vector((s * 0.5, 1.75 * k, 0.55 * k)), b + Vector((s * 0.62, 2.35 * k, 0.32 * k))]
        tube("Horn" + sd, pts, [0.28 * h, 0.22 * h, 0.15 * h, 0.08, 0.015], horn_m, sides=8)
        ell("HornRing" + sd, b, (0.3 * h, 0.3 * h, 0.14), (0, 0, 0), gold, seg=10, rings=6)
        if v["horns2"]:
            b2 = ray((s * 0.6, hy + 0.95, 9), (0, 0, -1))
            tube("HornB" + sd, [b2 - Vector((0, 0, 0.1)), b2 + Vector((s * 0.15, 0.35, 0.22)), b2 + Vector((s * 0.3, 0.8, 0.3))], [0.16, 0.11, 0.015], horn_m, sides=6)
        if v["teeth"]:
            for j in range(3):
                t = ray((s * 0.3, -9, 3.72), (0, 1, 0))
                tube("Tooth%s%d" % (sd, j), [(s * (0.2 + 0.0), t.y + 0.3 + 0.28 * j, t.z - 0.08), (s * 0.2, t.y + 0.3 + 0.28 * j, t.z - 0.32)], [0.045, 0.005], white, sides=5)
    # lower jaw: strong wedge, ice blue; crest of small spikes on the skull
    ell("Jaw", (0, -3.55, 3.6), (0.5 * h, 1.0 * h, 0.2 * h), (math.radians(6), 0, 0), mat("Ice", ICE, 0.3, coat=0.5))
    for i, y in enumerate((-2.55, -2.2, -1.85)):
        t = top(0, y)
        tube("Crest%d" % i, [t - Vector((0, 0, 0.05)), t + Vector((0, 0.2, 0.42 * v["spike"]))], [0.13, 0.015], gold, sides=6)

    # ---------------------------------------------------------------- spikes down the back, claws, tail fin
    for i, y in enumerate((-1.2, -0.45, 0.3, 1.05, 1.8, 2.6, 3.4, 4.2, 5.0)):
        t = top(0, y)
        k = max(0.3, (0.62 - i * 0.03)) * v["spike"]
        tube("Spike%d" % i, [t - Vector((0, 0, 0.06)), t + Vector((0, 0.14, k))], [0.12, 0.012], glow, sides=6)
    for sd, s in (("R", 1), ("L", -1)):
        for pre, foot in (("f", N["fp" + sd]), ("h", N["hf" + sd])):
            fy = foot[1]
            for kx in (-1, 0, 1):
                x = foot[0] + kx * 0.22
                tube("Claw%s%s%d" % (pre, sd, kx + 1), [(x, fy - 0.3, 0.3), (x, fy - 0.78, 0.1)], [0.1, 0.012], gold, sides=6)
    tip = Vector(N["t6"][:3])
    ell("TailFinV", tip + Vector((0, 0.5, 0.45)), (0.04, 0.55, 0.42), (math.radians(-35), 0, 0), gold)
    ell("TailFinH", tip + Vector((0, 0.5, 0.45)), (0.45, 0.45, 0.04), (math.radians(-35), 0, 0), gold)

    # ---------------------------------------------------------------- wings: grow from shoulder blades, strong bones, thick membrane
    mem = mat("Membrane", "#2A74DE", 0.4, coat=0.25)
    bone = mat("Bone", "#143F9C", 0.3, coat=0.4)
    trim = mat("Trim", ICE, 0.3, coat=0.3)
    w = v["wing"]
    for s, sd in ((1, "R"), (-1, "L")):
        base = top(s * 0.55, -0.35)
        S0 = Vector((s * 0.55, -0.35, base.z - 0.15))
        E0 = S0 + Vector((s * 0.55 * w, 0.0, 1.2 * w))
        W0 = E0 + Vector((s * 0.3 * w, 0.95 * w, 0.7 * w))
        tips = [W0 + Vector((s * dx * w, dy * w, dz * w)) for dx, dy, dz in ((0.55, 1.4, 0.8), (0.65, 2.4, 0.15), (0.5, 3.1, -0.6), (0.25, 3.3, -1.3))]
        baseP = Vector((s * 0.45, 2.0, 3.0))
        # shoulder muscle so the wing is mounted, not glued on
        ell("Shoulder" + sd, S0 + Vector((s * 0.12, 0, -0.05)), (0.7, 0.75, 0.6), (0, 0, 0), blue)
        edge = []
        for i, t in enumerate(tips):
            edge.append(t)
            nxt = tips[i + 1] if i + 1 < len(tips) else baseP
            edge.append((t + nxt) / 2 + (W0 - (t + nxt) / 2).normalized() * 0.3)
        edge.append(baseP)
        bmw = bmesh.new()
        Wv = bmw.verts.new(W0)
        ev = [bmw.verts.new(p) for p in edge]
        Sv, Ev = bmw.verts.new(S0), bmw.verts.new(E0)
        o = 1 if s > 0 else -1
        for i in range(len(ev) - 1):
            bmw.faces.new((Wv, ev[i], ev[i + 1]) if o > 0 else (Wv, ev[i + 1], ev[i]))
        bmw.faces.new((Wv, ev[-1], Sv) if o > 0 else (Wv, Sv, ev[-1]))
        bmw.faces.new((Wv, Sv, Ev) if o > 0 else (Wv, Ev, Sv))
        bmesh.ops.recalc_face_normals(bmw, faces=bmw.faces)
        wm = bpy.data.meshes.new("Wing" + sd)
        bmw.to_mesh(wm)
        bmw.free()
        wo = link("Wing" + sd, wm)
        sd_ = wo.modifiers.new("Solid", "SOLIDIFY")
        sd_.thickness = 0.22
        bpy.context.view_layer.objects.active = wo
        bpy.ops.object.modifier_apply(modifier="Solid")
        bv = wo.modifiers.new("Bevel", "BEVEL")
        bv.width = 0.04
        bv.segments = 2
        bpy.ops.object.modifier_apply(modifier="Bevel")
        finish(wo, mem, smooth=False)
        tube("WingArm" + sd, [S0, E0, W0], [0.3, 0.24, 0.17], bone, sides=8)
        for i, t in enumerate(tips):
            tube("Finger%s%d" % (sd, i), [W0, (W0 + t) / 2, t], [0.15, 0.1, 0.045], bone, sides=6)
        tube("Edge" + sd, edge, [0.06] * len(edge), trim, sides=6)
        tube("WingClaw" + sd, [W0 + Vector((0, -0.1, 0.1)), W0 + Vector((s * 0.1, -0.6, 0.4))], [0.12, 0.012], gold, sides=6)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == "MESH")
    return tris


def render_set(key, v):
    sc = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
    sc.render.resolution_x = sc.render.resolution_y = 620
    sc.view_settings.view_transform = "Standard"
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes["Background"].inputs
    bg[0].default_value, bg[1].default_value = (0.93, 0.95, 0.98, 1), 1.0
    for loc, en, rot in (((6, -8, 9), 3.2, (math.radians(50), 0, math.radians(35))), ((-7, -5, 5), 1.2, (math.radians(70), 0, math.radians(-50)))):
        bpy.ops.object.light_add(type="SUN", location=loc)
        L = bpy.context.active_object
        L.data.energy, L.rotation_euler = en, rot
    bpy.ops.object.camera_add()
    cam = bpy.context.active_object
    cam.data.lens = 62
    sc.camera = cam
    target = Vector((0, 1.4, 3.0))
    views = (("front", (0, -20, 4.8)), ("side", (31, 1.4, 3.9)), ("three-quarter", (14.5, -16.5, 7.6)), ("silhouette", (31, 1.4, 3.9)))
    for name, pos in views:
        cam.location = pos
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        if name == "silhouette":
            black = bpy.data.materials.new("blk")
            black.use_nodes = True
            nt = black.node_tree
            nt.nodes.clear()
            em = nt.nodes.new("ShaderNodeEmission")
            em.inputs["Color"].default_value = (0, 0, 0, 1)
            outn = nt.nodes.new("ShaderNodeOutputMaterial")
            nt.links.new(em.outputs[0], outn.inputs[0])
            bpy.context.view_layer.material_override = black
            bg[0].default_value = (1, 1, 1, 1)
            sc.view_settings.look = "None"
        sc.render.filepath = os.path.join(TMP, "%s_%s.png" % (key, name))
        bpy.ops.render.render(write_still=True)
    bpy.context.view_layer.material_override = None


for key, v in VARS.items():
    t = build(v)
    print("CONCEPT", key, "tris", t)
    render_set(key, v)

print("CONCEPT_TILES_DONE (then: python3 tools/blender/assemble_concept_035.py)")
