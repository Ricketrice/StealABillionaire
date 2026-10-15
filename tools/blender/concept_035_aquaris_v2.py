# Aquaris CONCEPT v2 (design only; replaces the rejected skin/balloon concepts). Run headless:
#   flatpak run org.blender.Blender -b -P $PWD/tools/blender/concept_035_aquaris_v2.py && python3 tools/blender/assemble_v2_035.py
# Sculpted by hand with cross-section lofts (no Skin modifier, no subdivision, no ball joints): ONE continuous spine mesh runs
# tail -> hips -> waist -> chest (keeled) -> rising neck -> wedge skull -> long snout, with real non-round sections (squared,
# keeled, flat-sided). Legs are lofts with angular joint plates; wings grow from a shoulder-blade ridge with bone ribs and
# thick curved scalloped membrane panels. Water-dragon motifs: wave-scallop scales on the flank, fin crest, ribbon whiskers.
# Front = -Y, up = +Z, ground z = 0. Output: ~/Pictures/035_preview/concept_v2/
import bpy, bmesh, math, os
from mathutils import Vector
from mathutils.bvhtree import BVHTree

OUT = os.path.expanduser("~/Pictures/035_preview/concept_v2")
TMP = os.path.join(OUT, "tiles")
os.makedirs(TMP, exist_ok=True)


def hexc(h):
    h = h.lstrip("#")
    lin = lambda c: ((c / 255 + 0.055) / 1.055) ** 2.4 if c / 255 > 0.04045 else c / 255 / 12.92
    return (lin(int(h[0:2], 16)), lin(int(h[2:4], 16)), lin(int(h[4:6], 16)), 1)


BLUE, DEEP, ICE, GOLD, CYAN = "#1F5FD1", "#173F99", "#A8F0FF", "#FFC83D", "#3FE6FF"
V = Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
mats = {}


def mat(name, color, rough=0.3, emit=0.0, coat=0.5, metal=0.0, vcol=False):
    if name in mats:
        return mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = hexc(color)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if "Coat Weight" in b.inputs:
        b.inputs["Coat Weight"].default_value = coat
    if emit > 0:
        b.inputs["Emission Color"].default_value = hexc(color)
        b.inputs["Emission Strength"].default_value = emit
    if vcol:
        a = nt.nodes.new("ShaderNodeAttribute")
        a.attribute_name = "Col"
        nt.links.new(a.outputs["Color"], b.inputs["Base Color"])
    mats[name] = m
    return m


def link(name, me):
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def finish(o, m, smooth=False):
    o.data.materials.clear()
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = smooth
    return o


def sstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def catmull(vals, t):
    n = len(vals)
    i = min(int(t), n - 2)
    f = t - i
    p0, p1, p2, p3 = vals[max(i - 1, 0)], vals[i], vals[i + 1], vals[min(i + 2, n - 1)]
    return 0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (-p0 + 3 * p1 - 3 * p2 + p3) * f * f * f)


def loft(name, secs, m, side=12, ref=(0, 0, 1), up_ref=None, sub=1, caps=(True, True), smooth=False, vcolor=False):
    """secs: (x, y, z, halfwidth, halfheight, keel, exponent). sub>1 resamples with Catmull-Rom for a flowing form."""
    S = [list(s) for s in secs]
    if sub > 1:
        n = (len(S) - 1) * sub + 1
        S = [[catmull([s[k] for s in S], i / sub) for k in range(7)] for i in range(n)]
    bm = bmesh.new()
    rings = []
    for i, s in enumerate(S):
        c = V(s[:3])
        a = V(S[min(i + 1, len(S) - 1)][:3]) - V(S[max(i - 1, 0)][:3])
        t = a.normalized()
        r = t.cross(V(ref))
        if r.length < 0.05:
            r = t.cross(V((0, 1, 0)))
        r.normalize()
        u = r.cross(t).normalized()
        w, h, keel, p = s[3], s[4], s[5], s[6]
        ring = []
        for k in range(side):
            th = 2 * math.pi * k / side
            cx, sz = math.cos(th), math.sin(th)
            x = w * math.copysign(abs(cx) ** (2 / p), cx)
            z = h * math.copysign(abs(sz) ** (2 / p), sz)
            if z < 0:
                z *= 1 + keel
            ring.append(bm.verts.new(c + r * x + u * z))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(side):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % side], rings[i + 1][(k + 1) % side], rings[i + 1][k]))
    if caps[0]:
        bm.faces.new(rings[0][::-1])
    if caps[1]:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = link(name, me)
    finish(o, m, smooth)
    return o


def ribbon(name, pts, widths, m, thick=0.02, sub=3):
    secs = [(p[0], p[1], p[2], widths[i], thick, 0, 2) for i, p in enumerate(pts)]
    return loft(name, secs, m, side=6, ref=(0, 0, 1), sub=sub)


def spike(name, base, tip, r, m, side=5):
    return loft(name, [(base[0], base[1], base[2], r, r, 0, 2), (tip[0], tip[1], tip[2], 0.006, 0.006, 0, 2)], m, side=side, ref=(1, 0, 0.3))


def ell(name, loc, scale, rot, m, seg=8, rings=5):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = link(name, me)
    o.location, o.scale, o.rotation_euler = loc, scale, rot
    return finish(o, m)


body_m = mat("Body", BLUE, 0.4, coat=0.25, vcol=True)
deep_m = mat("Deep", DEEP, 0.4, coat=0.4)
ice_m = mat("Ice", ICE, 0.35, coat=0.4)
gold_m = mat("Gold", GOLD, 0.25, coat=0.4, metal=0.6)
glow_m = mat("Glow", CYAN, 0.2, emit=2.5, coat=0.0)
fin_m = mat("Fin", CYAN, 0.3, emit=0.8, coat=0.0)
ink_m = mat("Ink", "#071225", 0.2, coat=0.0)
mem_m = mat("Membrane", "#2B73DB", 0.45, coat=0.2)
white_m = mat("Tooth", "#F4FAFF", 0.3, coat=0.2)

# ---------------------------------------------------------------- spine: tail -> snout, one mesh
# (x, y, z, halfwidth, halfheight, keel, squareness)
SPINE = [
    (0, 8.9, 2.85, 0.05, 0.05, 0, 2), (0, 8.0, 2.0, 0.13, 0.14, 0, 2), (0, 7.0, 1.3, 0.25, 0.28, 0.05, 2.2), (0, 5.9, 1.0, 0.4, 0.46, 0.1, 2.3),
    (0, 4.8, 1.15, 0.58, 0.68, 0.15, 2.4), (0, 3.7, 1.7, 0.78, 0.92, 0.2, 2.5),
    (0, 2.7, 2.35, 1.0, 1.08, 0.2, 2.6), (0, 1.7, 2.3, 0.86, 1.0, 0.25, 2.5), (0, 0.8, 2.3, 0.8, 0.98, 0.32, 2.5),
    (0, -0.1, 2.5, 1.08, 1.22, 0.5, 2.7), (0, -1.0, 2.65, 1.3, 1.4, 0.6, 2.9), (0, -1.8, 2.9, 1.14, 1.28, 0.55, 2.7),
    (0, -2.4, 3.5, 0.84, 0.96, 0.3, 2.5), (0, -2.9, 4.2, 0.68, 0.8, 0.2, 2.5), (0, -3.25, 4.85, 0.62, 0.72, 0.15, 2.5),
    (0, -3.65, 5.15, 0.74, 0.74, 0.12, 2.9), (0, -4.15, 5.2, 0.8, 0.7, 0.1, 3.2), (0, -4.75, 5.05, 0.6, 0.55, 0.05, 3.6),
    (0, -5.35, 4.92, 0.5, 0.44, 0, 4.0), (0, -5.9, 4.82, 0.45, 0.38, 0, 4.4),
]
body = loft("Body", SPINE, body_m, side=14, sub=2, vcolor=True)
col = body.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
cb, cd, ci, cl = hexc(BLUE), hexc(DEEP), hexc(ICE), hexc("#74D2F0")
for v in body.data.vertices:
    p, n = v.co, v.normal
    belly = sstep(0.2, 0.7, -n.z) * sstep(-5.4, -3.2, p.y) * (1 - sstep(4.6, 6.5, p.y))
    back = sstep(0.2, 0.9, n.z) * 0.55
    k = [cb[i] * (1 - back) + cd[i] * back for i in range(3)]
    band = sstep(0.6, 1.0, 0.5 + 0.5 * math.cos(2 * math.pi * p.y / 0.5)) * 0.5 if -2.4 < p.y < 2.8 else 0.0
    ice = [ci[i] * (1 - band) + cl[i] * band for i in range(3)]
    col.data[v.index].color = [k[i] * (1 - belly) + ice[i] * belly for i in range(3)] + [1]
bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())


def ray(o, d):
    r = bvh.ray_cast(V(o), V(d))
    return (r[0], r[1]) if r[0] is not None else (None, None)


def top(x, y):
    return ray((x, y, 20), (0, 0, -1))[0]


# ---------------------------------------------------------------- head
for s, sd in ((1, "R"), (-1, "L")):
    # brow ridge: a heavy angled wedge over each eye
    loft("Brow" + sd, [(s * 0.2, -3.85, 5.56, 0.16, 0.1, 0, 3), (s * 0.5, -4.45, 5.5, 0.2, 0.11, 0, 3), (s * 0.55, -5.0, 5.28, 0.12, 0.07, 0, 3)], deep_m, side=8, ref=(0, 0, 1), sub=2)
    e, _ = ray((s * 4, -4.35, 5.18), (-s, 0, 0))
    ell("Eye" + sd, (e.x - s * 0.02, e.y, e.z), (0.085, 0.31, 0.11), (math.radians(-20), 0, 0), glow_m, seg=10, rings=6)
    ell("EyeRing" + sd, (e.x - s * 0.0, e.y, e.z), (0.05, 0.4, 0.17), (math.radians(-20), 0, 0), deep_m, seg=10, rings=6)
    ell("Pupil" + sd, (e.x - s * 0.02 + s * 0.05, e.y - 0.02, e.z), (0.05, 0.035, 0.1), (math.radians(-20), 0, 0), ink_m, seg=6, rings=4)
    n_, _ = ray((s * 0.17, -9, 4.9), (0, 1, 0))
    ell("Nostril" + sd, (n_.x, n_.y + 0.02, n_.z), (0.05, 0.05, 0.045), (0, 0, 0), ink_m, seg=6, rings=4)
    # horn: one long swept-back curved horn on a gold base cone, with a short brow prong
    b = top(s * 0.42, -3.9)
    tube = [(b.x, b.y, b.z - 0.1, 0.24, 0.22, 0, 3), (b.x + s * 0.1, b.y + 0.5, b.z + 0.45, 0.2, 0.19, 0, 3), (b.x + s * 0.3, b.y + 1.3, b.z + 0.85, 0.15, 0.14, 0, 3),
            (b.x + s * 0.55, b.y + 2.2, b.z + 0.85, 0.09, 0.08, 0, 3), (b.x + s * 0.75, b.y + 2.95, b.z + 0.5, 0.01, 0.01, 0, 2)]
    loft("Horn" + sd, tube, gold_m, side=7, ref=(1, 0, 0), sub=3)
    spike("HornProng" + sd, (b.x + s * 0.05, b.y + 0.55, b.z + 0.38), (b.x + s * 0.35, b.y + 0.95, b.z + 1.0), 0.09, gold_m)
    # cheek blades: three swept-back ice blades from the jaw hinge (reads as a dragon, not a pet)
    f0, _ = ray((s * 4, -4.0, 4.8), (-s, 0, 0))
    for j in range(3):
        o = V((f0.x, f0.y + 0.18 * j, f0.z - 0.12 * j))
        spike("Cheek%s%d" % (sd, j), o, o + V((s * 0.75, 1.5 - 0.2 * j, 0.3 - 0.45 * j)), 0.14, ice_m, side=4)
    # ribbon whiskers: flowing cyan ribbons from the snout
    w0, _ = ray((s * 4, -5.45, 4.85), (-s, 0, 0))
    ribbon("Whisker" + sd, [(w0.x, w0.y, w0.z), (w0.x + s * 0.5, w0.y + 0.7, w0.z - 0.35), (w0.x + s * 1.1, w0.y + 1.7, w0.z - 0.55), (w0.x + s * 1.9, w0.y + 2.8, w0.z - 0.35), (w0.x + s * 2.6, w0.y + 3.9, w0.z + 0.2)],
           [0.14, 0.12, 0.09, 0.06, 0.01], fin_m)
    # a few teeth along the upper lip
    for j in range(5):
        tt, _ = ray((s * 0.22, -9, 4.78), (0, 1, 0))
        spike("Tooth%s%d" % (sd, j), (s * 0.3, tt.y + 0.3 + 0.24 * j, tt.z - 0.08), (s * 0.3, tt.y + 0.3 + 0.24 * j, tt.z - 0.42), 0.055, white_m, side=4)
# bolder face: nose bridge ridge, nose-tip horn, nostril flares, chin spike, mouth line
loft("NoseBridge", [(0, -4.3, 5.52, 0.1, 0.08, 0, 3), (0, -5.0, 5.3, 0.14, 0.1, 0, 3), (0, -5.6, 5.12, 0.12, 0.09, 0, 3)], deep_m, side=6, sub=2)
spike("NoseHorn", (0, -5.78, 5.12), (0, -6.05, 5.55), 0.12, gold_m)
for s_ in (1, -1):
    ell("NostrilFlare%d" % s_, (s_ * 0.27, -5.7, 4.95), (0.12, 0.2, 0.12), (0, 0, 0), deep_m, seg=8, rings=5)
    mm, _ = ray((s_ * 4, -5.2, 4.7), (-s_, 0, 0))
    ribbon("MouthLine%d" % (1 if s_ > 0 else 2), [(mm.x + s_ * 0.01, -3.95, 4.78), (mm.x + s_ * 0.01, -4.6, 4.72), (mm.x + s_ * 0.01, -5.3, 4.74), (mm.x + s_ * 0.01, -5.8, 4.77)], [0.03, 0.03, 0.03, 0.02], ink_m, thick=0.03, sub=2)
# MANE: layered fin blades fanning back from the skull and down the neck (ice, gold-tipped outer row)
for ring_i, (y, zc, rad, ln) in enumerate(((-3.5, 5.0, 0.95, 2.0), (-2.7, 4.2, 0.95, 2.3))):
    for k in range(7):
        a = math.radians(-90 + k * 30)  # sweep over the top and both sides, never the underside
        d = V((math.sin(a), 0, math.cos(a)))
        h0, _ = ray(V((0, y, zc)) + d * 4, -d)
        if h0 is None:
            continue
        o = h0 - d * 0.03
        out = d * (0.55 + 0.05 * ring_i) + V((0, 1.0, 0)) * (0.9)
        mid = o + out * 0.5 * ln / 1.5 + V((0, 0.15, 0.1))
        tip = o + out * ln / 1.5 + V((0, 0.35, -0.15))
        m_ = ice_m if (k + ring_i) % 2 == 0 else fin_m
        ribbon("Mane%d_%d" % (ring_i, k), [(o.x, o.y, o.z), (mid.x, mid.y, mid.z), (tip.x, tip.y, tip.z)], [0.28, 0.34, 0.005], m_, thick=0.03, sub=2)
        if False:
            spike("ManeTip%d" % k, (tip.x, tip.y, tip.z), (tip.x + d.x * 0.35, tip.y + 0.35, tip.z + d.z * 0.25), 0.05, gold_m, side=4)
# lower jaw: strong wedge, ice-blue underside, hinged at the cheek
jaw = loft("Jaw", [(0, -3.9, 4.6, 0.42, 0.2, 0.25, 3), (0, -4.7, 4.5, 0.4, 0.18, 0.3, 3.2), (0, -5.4, 4.5, 0.33, 0.15, 0.25, 3.5), (0, -5.85, 4.55, 0.26, 0.12, 0.2, 3.5)], ice_m, side=10, sub=2)
spike("ChinSpike", (0, -5.3, 4.28), (0, -5.0, 3.78), 0.1, gold_m)
# crest: a row of back-swept gold blades on the skull, then a fin crest down neck, spine and tail
for i, y in enumerate((-3.5, -3.15, -2.8)):
    t = top(0, y)
    spike("Crest%d" % i, (t.x, t.y, t.z - 0.05), (t.x, t.y + 0.45, t.z + 0.5 - i * 0.08), 0.1, gold_m)
FIN = [(-3.0, 0.85), (-2.5, 0.8), (-1.9, 0.72), (-1.1, 0.66), (-0.2, 0.62), (0.7, 0.58), (1.6, 0.56), (2.5, 0.58), (3.5, 0.55), (4.5, 0.48), (5.5, 0.4), (6.5, 0.32), (7.4, 0.24)]
for i, (y, k) in enumerate(FIN):
    t = top(0, y)
    if t is None:
        continue
    ribbon("FinCrest%d" % i, [(t.x, t.y, t.z - 0.05), (t.x, t.y + 0.14 * k, t.z + 0.45 * k), (t.x, t.y + 0.5 * k, t.z + 0.9 * k)], [0.04, 0.05, 0.005], fin_m, thick=0.015).rotation_euler = (0, 0, 0)

# ---------------------------------------------------------------- legs: lofts with angular joint plates (no ball joints)
CLAW = []


def paw(s, y0, name):
    x = s * 1.18
    loft(name + "Paw", [(x, y0 + 0.35, 0.34, 0.3, 0.2, 0.0, 3), (x, y0 - 0.2, 0.26, 0.36, 0.17, 0.0, 3), (x, y0 - 0.7, 0.18, 0.32, 0.11, 0.0, 3.2)], body_m, side=8, sub=2)
    for k in (-1, 0, 1):
        tx = x + k * 0.2
        loft("%sToe%d" % (name, k + 1), [(tx, y0 - 0.55, 0.2, 0.1, 0.09, 0, 2.6), (tx, y0 - 0.95, 0.15, 0.09, 0.07, 0, 2.6)], body_m, side=6)
        spike("%sClaw%d" % (name, k + 1), (tx, y0 - 0.92, 0.17), (tx, y0 - 1.38, 0.04), 0.075, gold_m, side=4)


for s, sd in ((1, "R"), (-1, "L")):
    # front leg (lion-like: shoulder -> elbow back -> forearm -> wrist -> paw)
    loft("ForeLeg" + sd, [(s * 0.75, -1.0, 2.9, 0.62, 0.7, 0.1, 3), (s * 1.15, -0.85, 1.9, 0.5, 0.58, 0.1, 3), (s * 1.2, -1.15, 1.0, 0.31, 0.34, 0.05, 3.2), (s * 1.2, -1.4, 0.45, 0.27, 0.27, 0.05, 3.2)], body_m, side=10, sub=3, ref=(0, -1, 0))
    loft("ElbowPlate" + sd, [(s * 1.38, -0.55, 1.78, 0.14, 0.2, 0, 3), (s * 1.38, -0.2, 1.62, 0.1, 0.12, 0, 3)], deep_m, side=6)
    spike("ElbowSpike" + sd, (s * 1.4, -0.45, 1.75), (s * 1.5, 0.2, 1.7), 0.11, gold_m)
    paw(s, -1.55, "Fore" + sd)
    # hind leg (digitigrade: thigh forward, knee, shin back, hock, paw)
    loft("HindLeg" + sd, [(s * 0.95, 2.1, 2.7, 0.78, 0.9, 0.1, 3), (s * 1.38, 1.15, 1.7, 0.62, 0.72, 0.1, 3), (s * 1.3, 2.1, 1.0, 0.3, 0.36, 0.05, 3.2), (s * 1.22, 1.85, 0.45, 0.26, 0.28, 0.05, 3.2)], body_m, side=10, sub=3, ref=(0, -1, 0))
    loft("KneePlate" + sd, [(s * 1.62, 0.78, 1.8, 0.13, 0.22, 0, 3), (s * 1.62, 0.52, 1.6, 0.1, 0.13, 0, 3)], deep_m, side=6)
    spike("KneeSpike" + sd, (s * 1.66, 0.7, 1.72), (s * 1.78, 0.3, 1.5), 0.1, gold_m)
    paw(s, 1.3, "Hind" + sd)
    # shoulder-blade ridge: a blade-shaped plate over the shoulder, anchor for the wing
    loft("ShoulderBlade" + sd, [(s * 0.55, -1.7, 3.95, 0.25, 0.1, 0, 3), (s * 0.78, -0.9, 4.18, 0.3, 0.12, 0, 3), (s * 0.7, -0.1, 3.82, 0.2, 0.08, 0, 3)], deep_m, side=8, sub=2)
    # flank: seigaiha wave scallops (water motif) in ice
    for row, z in enumerate((2.3, 2.9, 3.5)):
        for i in range(7):
            y = -1.2 + i * 0.55 + (0.27 if row % 2 else 0)
            if y > 2.6:
                continue
            h, n = ray((s * 5, y, z), (-s, 0, 0))
            if h is None:
                continue
            q = n.to_track_quat("Z", "Y")
            o = ell("Scale%s%d%d" % (sd, row, i), h + n * 0.01, (0.3, 0.2, 0.045), (0, 0, 0), ice_m, seg=8, rings=3)
            o.rotation_mode = "QUATERNION"
            o.rotation_quaternion = q

# chest keel plates (overlapping belly armour) and belly plates
for i, y in enumerate((-1.9, -1.35, -0.8, -0.25, 0.3, 0.85, 1.4)):
    h, n = ray((0, y, -8), (0, 0, 1))
    if h is None:
        continue
    ell("BellyPlate%d" % i, h + V((0, 0, 0.03)), (0.6 - 0.03 * i, 0.3, 0.12), (math.radians(-12), 0, 0), ice_m, seg=8, rings=3)

# tail fin: a clean gold leaf pair
tip = V(SPINE[0][:3])
loft("TailLeaf", [(0, tip.y - 0.1, tip.z - 0.05, 0.03, 0.03, 0, 2), (0, tip.y + 0.35, tip.z + 0.3, 0.1, 0.28, 0, 2.5), (0, tip.y + 0.9, tip.z + 0.9, 0.04, 0.45, 0, 2.2), (0, tip.y + 1.25, tip.z + 1.55, 0.005, 0.01, 0, 2)], gold_m, side=6, sub=2)

# ---------------------------------------------------------------- wings: shoulder-blade root, bone ribs, thick curved scalloped panels
for s, sd in ((1, "R"), (-1, "L")):
    S0 = V((s * 0.7, -0.95, 4.05))
    E0 = S0 + V((s * 0.55, 0.1, 1.35))
    W0 = E0 + V((s * 0.55, 1.1, 0.95))
    BASE = V((s * 0.55, 2.2, 3.3))
    tips = [W0 + V((s * 0.7, 3.9, -1.2)), W0 + V((s * 1.0, 3.0, -0.2)), W0 + V((s * 1.05, 1.7, 0.55))]  # T1 (low/back) .. T3 (leading, up)
    ribs_to = [BASE] + tips

    def rib(i, u):
        T = ribs_to[i]
        return W0 + (T - W0) * u + V((0, 0, 0.4 * math.sin(math.pi * u) * (0 if i == 0 else 1)))

    bm = bmesh.new()
    NU, NV = 7, 5
    for pi_ in range(3):
        grid = []
        for iu in range(NU + 1):
            row = []
            for iv in range(NV + 1):
                u, v = iu / NU, iv / NV
                uu = u * (1 - 0.2 * math.sin(math.pi * v))  # scalloped trailing edge
                P = rib(pi_, uu).lerp(rib(pi_ + 1, uu), v)
                P += V((s * 0.3 * math.sin(math.pi * v) * (0.4 + 0.6 * u), 0, 0.12 * math.sin(math.pi * v)))  # bulge: not a flat sheet
                row.append(bm.verts.new(P))
            grid.append(row)
        for iu in range(NU):
            for iv in range(NV):
                f = (grid[iu][iv], grid[iu + 1][iv], grid[iu + 1][iv + 1], grid[iu][iv + 1])
                bm.faces.new(f if s > 0 else f[::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("Membrane" + sd)
    bm.to_mesh(me)
    bm.free()
    mo = link("Membrane" + sd, me)
    mod = mo.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = 0.14
    bpy.context.view_layer.objects.active = mo
    bpy.ops.object.modifier_apply(modifier="Solid")
    finish(mo, mem_m, smooth=False)
    # leading arm bone and ribs (bone structure carries the membrane)
    loft("WingArm" + sd, [(S0.x, S0.y, S0.z, 0.26, 0.24, 0, 3), (E0.x, E0.y, E0.z, 0.2, 0.19, 0, 3), (W0.x, W0.y, W0.z, 0.14, 0.14, 0, 3)], deep_m, side=8, sub=3, ref=(1, 0, 0))
    loft("WristKnuckle" + sd, [(W0.x, W0.y - 0.1, W0.z - 0.05, 0.19, 0.18, 0, 3), (W0.x, W0.y + 0.15, W0.z + 0.02, 0.17, 0.16, 0, 3)], gold_m, side=6)
    for i, T in enumerate(tips):
        pts = [rib(i + 1, u) for u in (0, 0.33, 0.66, 1.0)]
        loft("Rib%s%d" % (sd, i), [(p.x, p.y, p.z, r, r, 0, 3) for p, r in zip(pts, (0.11, 0.09, 0.06, 0.012))], deep_m, side=6, ref=(1, 0, 0), sub=2)
    spike("WingClaw" + sd, W0 + V((0, -0.1, 0.1)), W0 + V((s * 0.15, -0.65, 0.4)), 0.1, gold_m)
    # trim: light edge along the scalloped trailing edge
    trim_pts = []
    for pi_ in range(3):
        for iv in range(NV + 1):
            v = iv / NV
            uu = 1 - 0.2 * math.sin(math.pi * v)
            P = rib(pi_, uu).lerp(rib(pi_ + 1, uu), v) + V((s * 0.3 * math.sin(math.pi * v), 0, 0.12 * math.sin(math.pi * v)))
            trim_pts.append(P)
    ribbon("WingTrim" + sd, trim_pts, [0.06] * len(trim_pts), ice_m, thick=0.05)

# legs, paws, toes: same vertex-colour material (blue, darker on top, soft ice on the underside)
for o in bpy.data.objects:
    if o.type == "MESH" and o.data.materials and o.data.materials[0] == body_m and "Col" not in o.data.color_attributes:
        c2 = o.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for v in o.data.vertices:
            n = v.normal
            back = sstep(0.2, 0.9, n.z) * 0.5
            under = sstep(0.3, 0.8, -n.z) * 0.35
            c2.data[v.index].color = [cb[i] * (1 - back - under) + cd[i] * back + cl[i] * under for i in range(3)] + [1]
objs = [o for o in bpy.data.objects if o.type == "MESH"]
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
print("AQUARIS_V2 objects=%d tris=%d" % (len(objs), tris))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Aquaris_concept_v2.blend"))

# ---------------------------------------------------------------- renders
sc = bpy.context.scene
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
sc.render.resolution_x = sc.render.resolution_y = 620
sc.view_settings.view_transform = "Standard"
sc.world = bpy.data.worlds.new("w")
sc.world.use_nodes = True
bg = sc.world.node_tree.nodes["Background"].inputs
bg[0].default_value, bg[1].default_value = (0.93, 0.95, 0.98, 1), 1.0
for loc, en, rot in (((6, -8, 9), 1.7, (math.radians(50), 0, math.radians(35))), ((-7, -5, 5), 0.55, (math.radians(70), 0, math.radians(-50)))):
    bpy.ops.object.light_add(type="SUN", location=loc)
    L = bpy.context.active_object
    L.data.energy, L.rotation_euler = en, rot
bpy.ops.object.camera_add()
cam = bpy.context.active_object
cam.data.lens = 62
sc.camera = cam
for name, pos, tgt in (("front", (0, -24, 4.6), (0, 1.5, 3.4)), ("side", (36, 1.6, 3.6), (0, 1.6, 3.4)), ("three-quarter", (21, -23, 9.5), (0, 1.6, 3.2)), ("hero-head", (10.5, -16.5, 8.2), (0.5, -3.6, 4.8)), ("silhouette", (36, 1.6, 3.6), (0, 1.6, 3.4))):
    cam.location = V(pos)
    cam.data.lens = 90 if name == "hero-head" else 62
    cam.rotation_euler = (V(tgt) - cam.location).to_track_quat("-Z", "Y").to_euler()
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
    sc.render.filepath = os.path.join(TMP, "v2_%s.png" % name)
    bpy.ops.render.render(write_still=True)
print("AQUARIS_V2_DONE")
