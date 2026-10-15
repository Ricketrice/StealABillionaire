# Aquaris CONCEPT v5 = the ultra-rare capturable ZONE BOSS (design only, no Studio/import): v4 polished with references 6-8 - signature gold fan crown (halo removed), sculpted angular gold plates instead of round pauldrons, kite chest shield + gem, cobra-style neck plates and chin tendrils, pale big claws, dark dorsal shards, stronger wings, leaner mesh. FX has two tiers: world (full water aura) and captured (light). Previews: world scale, carried (x1.3) and pad (x1.6) next to a 5-stud noob, plus a 128px icon test.. Run headless:
#   flatpak run org.blender.Blender -b -P $PWD/tools/blender/concept_035_aquaris_v2.py && python3 tools/blender/assemble_v5_035.py
# Sculpted by hand with cross-section lofts (no Skin modifier, no subdivision, no ball joints): ONE continuous spine mesh runs
# tail -> hips -> waist -> chest (keeled) -> rising neck -> wedge skull -> long snout, with real non-round sections (squared,
# keeled, flat-sided). Legs are lofts with angular joint plates; wings grow from a shoulder-blade ridge with bone ribs and
# thick curved scalloped membrane panels. Water-dragon motifs: wave-scallop scales on the flank, fin crest, ribbon whiskers.
# Front = -Y, up = +Z, ground z = 0. Output: ~/Pictures/035_preview/concept_v5/
import bpy, bmesh, math, os
from mathutils import Vector
from mathutils.bvhtree import BVHTree

OUT = os.path.expanduser("~/Pictures/035_preview/concept_v5")
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


def ribbon(name, pts, widths, m, thick=0.02, sub=2):
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
claw_m = mat("Claw", "#E4F2FF", 0.3, coat=0.3)
gold_m = mat("Gold", GOLD, 0.25, coat=0.4, metal=0.6)
glow_m = mat("Glow", CYAN, 0.2, emit=2.5, coat=0.0)
fin_m = mat("Fin", CYAN, 0.3, emit=0.8, coat=0.0)
ink_m = mat("Ink", "#071225", 0.2, coat=0.0)
mem_m = mat("Membrane", "#3B86E6", 0.45, coat=0.2)
fx_m = mat("FX", CYAN, 0.2, emit=4.0, coat=0.0)
fxw_m = mat("FXWhite", "#EAFBFF", 0.3, emit=2.0, coat=0.0)
white_m = mat("Tooth", "#F4FAFF", 0.3, coat=0.2)

# v3: built in a frame where the (unchanged, refined) head sits at its v2 position; everything is moved up at the end.
# Elegant proportions from the references: long S-curved neck with the head held high, slim torso with a deep keeled chest,
# tall digitigrade legs, long sinuous tail, large bone-structured wings, wave-arc scale pattern and flame-fringe fins.
DY, DZ = 0.35, -3.05


def PT(x, y, z):
    return V((x, y + DY, z + DZ))


# ---------------------------------------------------------------- spine: tail -> snout, one mesh
def Q(*a):
    x, y, z, w, hh, k, p = a
    return (x, y + DY, z + DZ, w, hh, k, p)


SPINE = [Q(*t) for t in (
    (0, 12.4, 3.2, 0.04, 0.04, 0, 2), (0, 11.4, 2.3, 0.1, 0.11, 0, 2), (0, 10.2, 1.55, 0.19, 0.21, 0.05, 2.2), (0, 9.0, 1.3, 0.29, 0.33, 0.08, 2.3),
    (0, 7.8, 1.55, 0.4, 0.46, 0.1, 2.4), (0, 6.6, 2.15, 0.52, 0.6, 0.12, 2.4), (0, 5.4, 2.8, 0.66, 0.78, 0.15, 2.5), (0, 4.4, 3.35, 0.82, 0.95, 0.2, 2.6),
    (0, 3.3, 3.6, 0.92, 1.05, 0.2, 2.6), (0, 2.2, 3.55, 0.8, 0.95, 0.25, 2.5), (0, 1.1, 3.5, 0.72, 0.9, 0.32, 2.5),
    (0, 0.1, 3.7, 1.0, 1.2, 0.5, 2.7), (0, -0.9, 3.9, 1.18, 1.35, 0.6, 2.9), (0, -1.7, 4.15, 1.04, 1.2, 0.55, 2.7),
    (0, -2.3, 4.8, 0.74, 0.86, 0.3, 2.5), (0, -2.55, 5.7, 0.58, 0.7, 0.25, 2.5), (0, -2.55, 6.6, 0.5, 0.6, 0.2, 2.5), (0, -2.85, 7.4, 0.47, 0.55, 0.15, 2.5),
    (0, -3.4, 8.0, 0.5, 0.56, 0.12, 2.6),
)] + [
    (0, -3.65, 5.15, 0.8, 0.8, 0.12, 2.9), (0, -4.15, 5.2, 0.88, 0.76, 0.1, 3.2), (0, -4.75, 5.05, 0.66, 0.6, 0.05, 3.6),
    (0, -5.35, 4.92, 0.54, 0.47, 0, 4.0), (0, -5.9, 4.82, 0.47, 0.4, 0, 4.4),
]

body = loft("Body", SPINE, body_m, side=14, sub=2, vcolor=True)
col = body.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
cb, cd, ci, cl = hexc(BLUE), hexc(DEEP), hexc(ICE), hexc("#74D2F0")
for v in body.data.vertices:
    p, n = v.co, v.normal
    belly = sstep(0.2, 0.7, -n.z) * sstep(-6.5, -3.0, p.y) * (1 - sstep(7.0, 9.5, p.y))
    back = sstep(0.2, 0.9, n.z) * 0.55
    k = [cb[i] * (1 - back) + cd[i] * back for i in range(3)]
    band = sstep(0.6, 1.0, 0.5 + 0.5 * math.cos(2 * math.pi * p.y / 0.5)) * 0.5 if -1.5 < p.y < 4.2 else 0.0
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
chin = spike("ChinSpike", (0, -5.3, 4.28), (0, -5.0, 3.78), 0.1, gold_m)
ell("MouthInside", (0, -4.85, 4.78), (0.33, 0.85, 0.07), (0, 0, 0), mat("Mouth", "#0A1A38", 0.5, coat=0.0), seg=8, rings=4)
from mathutils import Matrix
HINGE = V((0, -3.95, 4.65))
RM = Matrix.Rotation(math.radians(11), 4, "X")
for ob in (jaw, chin):
    for vt in ob.data.vertices:
        vt.co = HINGE + (RM @ (vt.co - HINGE))
# crest: a row of back-swept gold blades on the skull, then a fin crest down neck, spine and tail
for i, y in enumerate((-3.5, -3.15, -2.8)):
    t = top(0, y)
    spike("Crest%d" % i, (t.x, t.y, t.z - 0.05), (t.x, t.y + 0.6, t.z + 0.85 - i * 0.12), 0.13, gold_m)
FIN = [(y + DY, k) for y, k in ((-2.5, 0.8), (-1.6, 0.75), (-0.7, 0.7), (0.2, 0.66), (1.2, 0.62), (2.2, 0.6), (3.4, 0.58), (4.6, 0.56), (5.8, 0.5), (7.0, 0.44), (8.2, 0.38), (9.4, 0.3), (10.6, 0.24))]
for i, (y, k) in enumerate(FIN):
    t = top(0, y)
    if t is None:
        continue
    kk = k * 1.35
    spike("Shard%d" % i, (t.x, t.y - 0.1, t.z - 0.08), (t.x, t.y + 0.4 * kk, t.z + 0.95 * kk), 0.2 * min(1.0, kk + 0.2), deep_m, side=4)

# ---------------------------------------------------------------- legs: tall, lean, angular (no ball joints)
def paw(s, y0, name):
    x, g = s * 1.2, DZ
    loft(name + "Paw", [(x, y0 + 0.35, 0.34 + g, 0.3, 0.2, 0.0, 3), (x, y0 - 0.2, 0.26 + g, 0.36, 0.17, 0.0, 3), (x, y0 - 0.7, 0.18 + g, 0.32, 0.11, 0.0, 3.2)], body_m, side=8, sub=2)
    for k in (-1, 0, 1):
        tx = x + k * 0.2
        loft("%sToe%d" % (name, k + 1), [(tx, y0 - 0.55, 0.2 + g, 0.1, 0.09, 0, 2.6), (tx, y0 - 0.95, 0.15 + g, 0.09, 0.07, 0, 2.6)], body_m, side=6)
        spike("%sClaw%d" % (name, k + 1), (tx, y0 - 0.9, 0.17 + g), (tx, y0 - 1.6, 0.03 + g), 0.095, claw_m, side=4)


def lg(name, pts, sizes, ref=(0, -1, 0)):
    return loft(name, [(p.x, p.y, p.z, w, hh, k, e) for p, (w, hh, k, e) in zip(pts, sizes)], body_m, side=8, sub=2, ref=ref)


for s, sd in ((1, "R"), (-1, "L")):
    # front leg (shoulder -> elbow back -> forearm -> wrist -> paw)
    lg("ForeLeg" + sd, [PT(s * 0.8, -1.2, 3.9), PT(s * 1.2, -0.6, 2.5), PT(s * 1.2, -1.3, 1.05), PT(s * 1.2, -1.55, 0.5)], [(0.55, 0.68, 0.1, 3), (0.45, 0.52, 0.1, 3), (0.28, 0.32, 0.05, 3.2), (0.25, 0.25, 0.05, 3.2)])
    e0 = PT(s * 1.42, -0.2, 2.55)
    loft("ElbowPlate" + sd, [(e0.x, e0.y - 0.3, e0.z, 0.14, 0.2, 0, 3), (e0.x, e0.y + 0.15, e0.z - 0.1, 0.1, 0.12, 0, 3)], deep_m, side=6)
    spike("ElbowSpike" + sd, e0 + V((0, 0.0, 0.0)), e0 + V((s * 0.1, 0.75, -0.05)), 0.11, gold_m)
    paw(s, -1.8, "Fore" + sd)
    # hind leg (digitigrade)
    lg("HindLeg" + sd, [PT(s * 0.95, 2.6, 3.6), PT(s * 1.35, 1.4, 2.35), PT(s * 1.28, 2.9, 1.2), PT(s * 1.22, 2.45, 0.5)], [(0.72, 0.85, 0.1, 3), (0.55, 0.65, 0.1, 3), (0.27, 0.32, 0.05, 3.2), (0.24, 0.26, 0.05, 3.2)])
    k0 = PT(s * 1.65, 1.0, 2.4)
    loft("KneePlate" + sd, [(k0.x, k0.y + 0.25, k0.z, 0.13, 0.22, 0, 3), (k0.x, k0.y - 0.25, k0.z - 0.15, 0.1, 0.13, 0, 3)], deep_m, side=6)
    spike("KneeSpike" + sd, k0 + V((0, -0.1, 0.0)), k0 + V((s * 0.1, -0.7, -0.15)), 0.1, gold_m)
    paw(s, 2.15, "Hind" + sd)
    # shoulder-blade ridge: the anchor for the wing
    loft("ShoulderBlade" + sd, [(PT(s * 0.55, -2.0, 5.2).x, PT(0, -2.0, 5.2).y, PT(0, -2.0, 5.2).z, 0.25, 0.1, 0, 3), (PT(s * 0.8, -1.2, 5.45).x, PT(0, -1.2, 5.45).y, PT(0, -1.2, 5.45).z, 0.3, 0.12, 0, 3), (PT(s * 0.7, -0.3, 5.0).x, PT(0, -0.3, 5.0).y, PT(0, -0.3, 5.0).z, 0.2, 0.08, 0, 3)], deep_m, side=8, sub=2)
    # flank: wave-arc scale pattern (thin ice crescents following the surface, like the scalloped arcs on the reference)
    for row, zd in enumerate((3.4, 4.1)):
        for i in range(6):
            y = -1.0 + DY + i * 0.8 + (0.4 if row % 2 else 0)
            if y > 3.4:
                continue
            h0, n0 = ray((s * 6, y, zd + DZ), (-s, 0, 0))
            if h0 is None:
                continue
            ty = (V((0, 1, 0)) - n0 * n0.y).normalized()
            tz = n0.cross(ty).normalized()
            if tz.z < 0:
                tz = -tz
            pts = []
            for ph in (20, 55, 90, 125, 160):
                a = math.radians(ph)
                q = h0 + ty * (0.34 * math.cos(a)) + tz * (0.3 * math.sin(a) - 0.15)
                hh_, _ = ray(q + n0 * 1.0, -n0)
                if hh_ is not None:
                    pts.append(hh_ + n0 * 0.03)
            if len(pts) >= 4:
                ribbon("Arc%s%d%d" % (sd, row, i), [(p.x, p.y, p.z) for p in pts], [0.055] * len(pts), ice_m, thick=0.03, sub=2)
    # flame-fringe fins on the back of each hind thigh and the shoulder (gold / ice, like the fringe on the reference)
    for j, zd in enumerate((3.7, 3.3, 2.9, 2.5)):
        fh, _ = ray((s * 1.15, 9, zd + DZ), (0, -1, 0))
        if fh is None:
            continue
        L2 = 1.5 - 0.15 * j
        ribbon("Fringe%s%d" % (sd, j), [(fh.x, fh.y, fh.z), (fh.x + s * 0.5, fh.y + 0.7 * L2, fh.z + 0.05), (fh.x + s * 1.0, fh.y + 1.3 * L2, fh.z - 0.2 - 0.1 * j)], [0.2, 0.22, 0.005], gold_m if j % 2 == 0 else ice_m, thick=0.03, sub=2)


# chest keel plates (overlapping belly armour) and belly plates
for i, y in enumerate([y + DY for y in (-1.5, -0.9, -0.3, 0.3, 0.9, 1.5, 2.1, 2.7)]):
    h, n = ray((0, y, -8), (0, 0, 1))
    if h is None:
        continue
    ell("BellyPlate%d" % i, h + V((0, 0, 0.03)), (0.62 - 0.03 * i, 0.3, 0.12), (math.radians(-12), 0, 0), ice_m, seg=8, rings=3)

# tail fin: a clean gold leaf pair
tip = V(SPINE[0][:3])
loft("TailLeaf", [(0, tip.y - 0.1, tip.z - 0.05, 0.03, 0.03, 0, 2), (0, tip.y + 0.35, tip.z + 0.3, 0.1, 0.28, 0, 2.5), (0, tip.y + 0.9, tip.z + 0.9, 0.04, 0.45, 0, 2.2), (0, tip.y + 1.25, tip.z + 1.55, 0.005, 0.01, 0, 2)], gold_m, side=6, sub=2)

# ---------------------------------------------------------------- wings: shoulder-blade root, bone ribs, thick curved scalloped panels
for s, sd in ((1, "R"), (-1, "L")):
    S0 = PT(s * 0.7, -1.2, 5.35)
    E0 = S0 + V((s * 0.6, 0.2, 1.6))
    W0 = E0 + V((s * 0.7, 1.4, 1.0))
    BASE = PT(s * 0.55, 3.2, 4.4)
    tips = [W0 + V((s * 1.0, 5.8, -2.4)), W0 + V((s * 1.6, 4.6, -0.9)), W0 + V((s * 1.8, 2.9, 0.5))]  # T1 (low/back) .. T3 (leading, up)
    ribs_to = [BASE] + tips

    def rib(i, u):
        T = ribs_to[i]
        return W0 + (T - W0) * u + V((0, 0, 0.4 * math.sin(math.pi * u) * (0 if i == 0 else 1)))

    bm = bmesh.new()
    NU, NV = 7, 4
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
    spike("WingClaw" + sd, W0 + V((0, -0.1, 0.1)), W0 + V((s * 0.15, -0.65, 0.4)), 0.12, gold_m)
    loft("WingBand" + sd, [(E0.x, E0.y - 0.12, E0.z - 0.02, 0.27, 0.26, 0, 2.5), (E0.x, E0.y + 0.12, E0.z + 0.02, 0.27, 0.26, 0, 2.5)], gold_m, side=8, ref=(1, 0, 0))
    hk = tips[2]
    loft("WingHook" + sd, [(hk.x, hk.y, hk.z, 0.1, 0.1, 0, 2.5), (hk.x + s * 0.1, hk.y - 0.5, hk.z + 0.5, 0.07, 0.07, 0, 2.5), (hk.x + s * 0.2, hk.y - 1.0, hk.z + 1.1, 0.01, 0.01, 0, 2)], gold_m, side=5, ref=(1, 0, 0), sub=2)
    # trim: light edge along the scalloped trailing edge
    trim_pts = []
    for pi_ in range(3):
        for iv in range(NV + 1):
            v = iv / NV
            uu = 1 - 0.2 * math.sin(math.pi * v)
            P = rib(pi_, uu).lerp(rib(pi_ + 1, uu), v) + V((s * 0.3 * math.sin(math.pi * v), 0, 0.12 * math.sin(math.pi * v)))
            trim_pts.append(P)
    ribbon("WingTrim" + sd, trim_pts, [0.06] * len(trim_pts), ice_m, thick=0.05)

# ---------------------------------------------------------------- boss details (part of the model, FX OFF)
gem_m = mat("Gem", CYAN, 0.15, emit=2.2, coat=0.0)
# kite-shaped gold chest shield with a cyan gem (follows the chest front)
zs = (2.15, 1.75, 1.35, 0.95, 0.55)
kw = (0.2, 0.5, 0.56, 0.34, 0.07)
ksec, ghit = [], None
for z_, w_ in zip(zs, kw):
    h_, _ = ray((0, -9, z_), (0, 1, 0))
    if h_ is not None:
        ksec.append((h_.x, h_.y - 0.05, h_.z, w_, 0.07, 0, 3))
        if abs(z_ - 1.35) < 0.01:
            ghit = h_
if len(ksec) >= 3:
    loft("ChestShield", ksec, gold_m, side=8, ref=(0, -1, 0), sub=2)
if ghit is not None:
    ell("ChestGem", ghit + V((0, -0.16, 0)), (0.24, 0.09, 0.42), (0, 0, 0), gem_m, seg=4, rings=2)
# sculpted shoulder plates: a long swept horn-plate with two shorter layers beneath (no round pads)
for s_, sd_ in ((1, "R"), (-1, "L")):
    ph, _ = ray((s_ * 0.95, -0.55, 20), (0, 0, -1))
    if ph is None:
        continue
    for j, (off, ln, wd) in enumerate(((0.0, 1.0, 0.42), (-0.12, 0.7, 0.46), (-0.22, 0.45, 0.5))):
        p0 = ph + V((s_ * (0.05 + 0.1 * j), -0.95 + 0.25 * j, off))
        p1 = ph + V((s_ * (0.35 + 0.05 * j), -0.35 + 0.15 * j, 0.42 * ln + off))
        p2 = ph + V((s_ * (0.62 + 0.04 * j), 0.5 * ln, 0.9 * ln + off))
        p3 = ph + V((s_ * (0.72 + 0.03 * j), 1.45 * ln, 1.0 * ln + off))
        loft("Pauldron%s%d" % (sd_, j), [(p0.x, p0.y, p0.z, wd * 0.7, 0.07, 0, 3), (p1.x, p1.y, p1.z, wd, 0.065, 0, 3), (p2.x, p2.y, p2.z, wd * 0.7, 0.05, 0, 3), (p3.x, p3.y, p3.z, 0.015, 0.02, 0, 2)], gold_m, side=6, ref=(0, 0, 1), sub=2)
    # gold bracers on the wrist and the hock
    for nm, pt in (("Wrist", PT(s_ * 1.2, -1.3, 1.05)), ("Hock", PT(s_ * 1.28, 2.9, 1.2))):
        loft("Bracer%s%s" % (nm, sd_), [(pt.x, pt.y, pt.z - 0.14, 0.36, 0.36, 0, 2.5), (pt.x, pt.y, pt.z + 0.14, 0.36, 0.36, 0, 2.5)], gold_m, side=8, ref=(0, -1, 0))
# signature crown: a fan of swept-back gold blades from the brow (replaces the halo ring), with a forehead gem
cb_, _ = ray((0, -3.95, 20), (0, 0, -1))
if cb_ is not None:
    for j, (sx, by, bz, pts_) in enumerate((
        (0, 0.0, -0.05, ((0, 0.45, 0.65), (0, 1.0, 1.5), (0, 1.7, 2.1))),
        (1, 0.15, -0.1, ((0.45, 0.5, 0.55), (0.9, 1.1, 1.2), (1.35, 1.8, 1.6))),
        (1, 0.5, -0.2, ((0.9, 0.7, 0.3), (1.5, 1.3, 0.55), (2.1, 2.0, 0.65))),
    )):
        for s_ in ((1, -1) if sx else (1,)):
            b0 = cb_ + V((s_ * (0.0 if not sx else 0.4 + 0.3 * (j - 1)), by, bz))
            ps = [b0] + [b0 + V((s_ * p[0], p[1], p[2])) for p in pts_]
            loft("Crown%d%s" % (j, "R" if s_ > 0 else "L"), [(p.x, p.y, p.z, 0.24 - 0.05 * k, 0.045, 0, 3) for k, p in enumerate(ps[:3])] + [(ps[3].x, ps[3].y, ps[3].z, 0.01, 0.02, 0, 2)], gold_m, side=6, ref=(0, 0, 1), sub=2)
    ell("ForeheadGem", cb_ + V((0, -0.35, 0.2)), (0.11, 0.09, 0.2), (math.radians(-20), 0, 0), gem_m, seg=4, rings=2)
# cobra-style plated neck front and two chin tendrils
for z_ in (2.3, 2.7, 3.1, 3.5, 3.9, 4.3):
    h_, _ = ray((0, -9, z_), (0, 1, 0))
    if h_ is not None:
        ell("NeckPlate%d" % int(z_ * 10), h_ + V((0, 0.0, 0)), (0.42, 0.12, 0.13), (0, 0, 0), ice_m, seg=8, rings=3)
for s_ in (1, -1):
    ribbon("Tendril%s" % ("R" if s_ > 0 else "L"), [(s_ * 0.15, -5.15, 4.25), (s_ * 0.45, -4.7, 3.6), (s_ * 0.6, -4.2, 2.7), (s_ * 0.55, -3.7, 1.8)], [0.09, 0.08, 0.06, 0.005], fx_m if False else fin_m, thick=0.02, sub=2)
tipp = V(SPINE[0][:3])
for k_, (dz_, dx_) in enumerate(((0.9, 0.0), (0.5, 0.35), (0.5, -0.35))):
    ribbon("TailFan%d" % k_, [(tipp.x, tipp.y + 0.2, tipp.z + 0.1), (tipp.x + dx_ * 0.6, tipp.y + 0.8, tipp.z + dz_ * 0.5 + 0.3), (tipp.x + dx_ * 1.4, tipp.y + 1.6, tipp.z + dz_ * 1.1 + 0.4), (tipp.x + dx_ * 2.0, tipp.y + 2.3, tipp.z + dz_ * 1.0 + 0.1)], [0.06, 0.14, 0.12, 0.005], fin_m if k_ % 2 else ice_m, thick=0.02, sub=2)

# legs, paws, toes: same vertex-colour material (blue, darker on top, soft ice on the underside)
for o in bpy.data.objects:
    if o.type == "MESH" and o.data.materials and o.data.materials[0] == body_m and "Col" not in o.data.color_attributes:
        c2 = o.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for v in o.data.vertices:
            n = v.normal
            back = sstep(0.2, 0.9, n.z) * 0.5
            under = sstep(0.3, 0.8, -n.z) * 0.35
            c2.data[v.index].color = [cb[i] * (1 - back - under) + cd[i] * back + cl[i] * under for i in range(3)] + [1]

# ---------------------------------------------------------------- FX: two tiers, both separate from the mesh
import random

random.seed(35)
model_objs = [o for o in bpy.data.objects if o.type == "MESH"]
before = set(bpy.data.objects)


def topz(y):
    h_ = top(0, y)
    return h_.z if h_ is not None else None


def botz(y):
    h_, _ = ray((0, y, -9), (0, 0, 1))
    return h_.z if h_ is not None else None


def collect(name):
    global before
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    for ob in set(bpy.data.objects) - before:
        for c_ in ob.users_collection:
            c_.objects.unlink(ob)
        col.objects.link(ob)
    before = set(bpy.data.objects)
    return col


# captured tier (kept on the captured copy, cheap): one spine energy line, glowing orbs on the horn tips and wing tips
pts = []
for y in [-3.0 + 0.7 * i for i in range(0, 20)]:
    z_ = topz(y)
    if z_ is not None:
        pts.append((0, y, z_ + 0.2))
if len(pts) > 3:
    ribbon("FXc_SpineLine", pts, [0.09] * len(pts), fx_m, thick=0.02, sub=1)
for ob in list(model_objs):
    if ob.name.startswith(("HornR", "HornL", "WingHook")):
        far = max((ob.matrix_world @ v.co for v in ob.data.vertices), key=lambda p: (p - V((0, 3, 4))).length)
        ell("FXc_Orb", far, (0.15, 0.15, 0.15), (0, 0, 0), fx_m, seg=8, rings=5)
fx_cap = collect("FX_captured")

# world tier (on top of the captured tier): one flowing water ribbon, paw swirls, wave splashes, a small pool, few droplets
pts, wid = [], []
for i in range(0, 46):
    t_ = i / 45
    y = 10.5 - t_ * 12.0
    zt, zb = topz(y), botz(y)
    if zt is None or zb is None:
        continue
    zc, rr = (zt + zb) / 2, (zt - zb) / 2 + 0.9 + 0.3 * math.sin(t_ * 8)
    ang = t_ * 2 * math.pi * 1.5
    pts.append((rr * 1.15 * math.cos(ang), y, zc + rr * math.sin(ang)))
    wid.append(0.1 + 0.4 * math.sin(math.pi * t_) + 0.02)
if len(pts) > 4:
    ribbon("FXw_Flow", pts, wid, mat("FXWater", "#7FD8FF", 0.2, emit=1.6, coat=0.0), thick=0.03, sub=1)
for s_ in (1, -1):
    for (py, pz, rr, tilt) in ((-1.45 + DY, 1.0 + DZ, 1.0, 25), (2.45 + DY, 1.0 + DZ, 0.9, 20)):
        ring = []
        for k in range(0, 25):
            a_ = 2 * math.pi * k / 24
            rad = rr * (0.85 + 0.15 * math.sin(a_ * 3))
            ring.append((s_ * 1.2 + rad * math.cos(a_), py + rad * math.sin(a_) * math.cos(math.radians(tilt)), pz + rad * math.sin(a_) * math.sin(math.radians(tilt)) + 0.15 * math.sin(a_ * 2)))
        ribbon("FXw_Ring", ring, [0.08] * len(ring), fxw_m, thick=0.02, sub=1)
for ob in list(model_objs):
    if ob.name.startswith("Rib"):
        far = max((ob.matrix_world @ v.co for v in ob.data.vertices), key=lambda p: (p - V((0, 3, 4))).length)
        sg = 1 if far.x > 0 else -1
        ribbon("FXw_Wisp", [(far.x, far.y, far.z), (far.x + sg * 0.5, far.y + 0.9, far.z - 0.2), (far.x + sg * 0.9, far.y + 1.9, far.z - 0.7), (far.x + sg * 1.1, far.y + 3.0, far.z - 1.6)], [0.07, 0.07, 0.04, 0.005], fx_m, thick=0.015, sub=1)
for i in range(16):
    p_ = V((random.uniform(-6, 6), random.uniform(-5, 12), DZ + random.uniform(0.6, 9.0)))
    if abs(p_.x) < 1.6 and 0 < p_.y < 8:
        continue
    r_ = random.uniform(0.06, 0.15)
    ell("FXw_Drop", p_, (r_, r_, r_), (0, 0, 0), fxw_m, seg=6, rings=4)
pool_m = mat("Pool", CYAN, 0.2, emit=0.8, coat=0.0)
try:
    pool_m.surface_render_method = "BLENDED"
    next(n for n in pool_m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Alpha"].default_value = 0.5
except Exception:
    pass
ell("FXw_Pool", V((0, 3.0 + DY, DZ + 0.03)), (5.2, 9.0, 0.03), (0, 0, 0), pool_m, seg=20, rings=4)
for k in range(14):
    th = 2 * math.pi * k / 14
    p0 = V((4.6 * math.cos(th), 3.0 + DY + 8.2 * math.sin(th), DZ + 0.05))
    inw = -V((p0.x / 4.6, (p0.y - 3.0 - DY) / 8.2, 0)).normalized()
    pp = []
    for u, hz, ins in ((0, 0.0, 0.0), (0.3, 0.45, 0.1), (0.6, 0.7, 0.35), (1.0, 0.4, 0.95)):
        q = p0 + inw * ins * 1.1
        pp.append((q.x, q.y, q.z + hz))
    ribbon("FXw_Wave%d" % k, pp, [0.16, 0.18, 0.14, 0.03], fxw_m if k % 2 else fx_m, thick=0.03, sub=1)
fx_world = collect("FX_world")

# ---------------------------------------------------------------- group everything under one boss root (scalable), move up
for o in bpy.data.objects:
    if o.parent is None:
        o.location += V((0, -DY, -DZ))
boss = bpy.data.objects.new("AquarisRoot", None)
boss.location = V((0, 3.0, 0))
bpy.context.scene.collection.objects.link(boss)
bpy.context.view_layer.update()
for o in bpy.data.objects:
    if o is not boss and o.parent is None:
        mw = o.matrix_world.copy()
        o.parent = boss
        o.matrix_parent_inverse = boss.matrix_world.inverted()
        o.matrix_world = mw
bpy.context.view_layer.update()
# a 5-stud "noob" scale reference (hidden in the model renders)
bpy.ops.mesh.primitive_cube_add()
noob_parts = []
for nm, loc, sc_, colr in (("NoobLegs", (0, 0, 1.0), (1.9, 1.0, 2.0), "#3A8A3A"), ("NoobTorso", (0, 0, 3.0), (2.0, 1.0, 2.0), "#3B6FD0"), ("NoobHead", (0, 0, 4.55), (1.2, 1.2, 1.1), "#F5CD30"), ("NoobArmL", (-1.5, 0, 3.0), (1.0, 1.0, 2.0), "#F5CD30"), ("NoobArmR", (1.5, 0, 3.0), (1.0, 1.0, 2.0), "#F5CD30")):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    me = bpy.data.meshes.new(nm)
    bm.to_mesh(me)
    bm.free()
    o = link(nm, me)
    o.location, o.scale = loc, sc_
    finish(o, mat("N" + nm, colr, 0.6, coat=0.0))
    noob_parts.append(o)
bpy.data.objects.remove(bpy.context.active_object) if bpy.context.active_object and bpy.context.active_object.name.startswith("Cube") else None
noob = bpy.data.objects.new("Noob", None)
bpy.context.scene.collection.objects.link(noob)
for o in noob_parts:
    o.parent = noob
refcol = bpy.data.collections.new("REF")
bpy.context.scene.collection.children.link(refcol)
for o in [noob] + noob_parts:
    for c_ in o.users_collection:
        c_.objects.unlink(o)
    refcol.objects.link(o)

# ---------------------------------------------------------------- mesh budget by group
GROUPS = {
    "body (tail+hips+chest+neck+head, 1 mesh)": ("Body",),
    "head details (jaw, brow, eyes, teeth, horn bits, whiskers, mane, tendrils)": ("Jaw", "Brow", "Eye", "Pupil", "Nostril", "NoseBridge", "NoseHorn", "Tooth", "MouthInside", "ChinSpike", "Cheek", "Whisker", "Tendril", "Mane", "Crest", "ForeheadGem", "NeckPlate"),
    "horns + crown": ("Horn", "Crown"),
    "armour (shield, plates, bracers, joint plates, belly plates)": ("ChestShield", "ChestGem", "Pauldron", "Bracer", "ElbowPlate", "ElbowSpike", "KneePlate", "KneeSpike", "ShoulderBlade", "BellyPlate"),
    "legs + paws + claws": ("ForeLeg", "HindLeg", "ForeRPaw", "ForeLPaw", "HindRPaw", "HindLPaw", "ForeRToe", "ForeLToe", "HindRToe", "HindLToe", "ForeRClaw", "ForeLClaw", "HindRClaw", "HindLClaw"),
    "wings (membrane, bones, ribs, hooks, trim)": ("Membrane", "WingArm", "WingClaw", "WingBand", "WingHook", "WingTrim", "Rib", "WristKnuckle"),
    "tail finish + dorsal shards + flank/hip details": ("TailLeaf", "TailFan", "Shard", "Arc", "Fringe", "Scale"),
}
rep = {k: 0 for k in GROUPS}
rep["other"] = 0
fx_tris = {"FX_captured": 0, "FX_world": 0}
for o in bpy.data.objects:
    if o.type != "MESH":
        continue
    t_ = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if o.name.startswith("FX"):
        fx_tris["FX_captured" if o.name.startswith("FXc") else "FX_world"] += t_
        continue
    if o.name.startswith("Noob"):
        continue
    for g, pre in GROUPS.items():
        if o.name.startswith(pre):
            rep[g] += t_
            break
    else:
        rep["other"] += t_
import json

total = sum(rep.values())
print("AQUARIS_V5_BUDGET", json.dumps({"model_tris": total, "groups": rep, "fx": fx_tris, "objects_model": sum(1 for o in bpy.data.objects if o.type == "MESH" and not o.name.startswith(("FX", "Noob")))}))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Aquaris_concept_v5.blend"))

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
sc.camera = cam
VIEWS = (("front", (0, -27, 5.5), (0, 2.0, 4.6), 62), ("side", (40, 3.2, 4.8), (0, 3.2, 4.4), 62), ("three-quarter", (24, -26, 12), (0, 3.0, 4.4), 62), ("hero", (13, -21, 10), (0.4, -2.4, 6.2), 75))


def shoot(prefix, name, pos, tgt, lens, res=620):
    sc.render.resolution_x = sc.render.resolution_y = res
    cam.location = V(pos)
    cam.data.lens = lens
    cam.rotation_euler = (V(tgt) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(TMP, "%s_%s.png" % (prefix, name))
    bpy.ops.render.render(write_still=True)


def black_pass(on):
    if on:
        blk = bpy.data.materials.new("blk")
        blk.use_nodes = True
        n_ = blk.node_tree
        n_.nodes.clear()
        e_ = n_.nodes.new("ShaderNodeEmission")
        e_.inputs["Color"].default_value = (0, 0, 0, 1)
        o_ = n_.nodes.new("ShaderNodeOutputMaterial")
        n_.links.new(e_.outputs[0], o_.inputs[0])
        bpy.context.view_layer.material_override = blk
    else:
        bpy.context.view_layer.material_override = None


refcol.hide_render = True
fx_cap.hide_render = True
fx_world.hide_render = True
for name, pos, tgt, lens in VIEWS:
    shoot("off", name, pos, tgt, lens)
black_pass(True)
bg[0].default_value = (1, 1, 1, 1)
shoot("off", "silhouette", (40, 3.2, 4.8), (0, 3.2, 4.4), 62)
black_pass(False)
# FX ON = world spawn (both tiers)
fx_cap.hide_render = False
fx_world.hide_render = False
bg[0].default_value, bg[1].default_value = (0.02, 0.09, 0.2, 1), 1.0
for name, pos, tgt, lens in VIEWS:
    shoot("on", name, pos, tgt, lens)
shoot("on", "wide", (22, -24, 7), (0, 3.0, 3.6), 40)
# scale previews with a 5-stud noob: world spawn (scale 3 = model as built), carried (x1.3 -> 1.3/3), on a pad (x1.6 -> 1.6/3)
refcol.hide_render = False
bg[0].default_value, bg[1].default_value = (0.93, 0.95, 0.98, 1), 1.0
noob.location = V((-9, -1, 0))
shoot("sc", "world", (34, -38, 16), (-2, 3.0, 4.2), 40)
fx_world.hide_render = True
for tag, k in (("carried", 1.3 / 3.0), ("pad", 1.6 / 3.0)):
    boss.scale = (k, k, k)
    boss.location = V((0, 3.0 * k, 0))
    noob.location = V((-4.2, -0.5, 0))
    shoot("sc", tag, (14, -17, 7), (-1.0, 1.2, 2.4), 45)
# icon test (128 px, the Index / reveal card size): colour and silhouette of the carried copy
boss.scale = (1.3 / 3.0,) * 3
boss.location = V((0, 1.3, 0))
refcol.hide_render = True
shoot("sc", "icon", (13, -13, 6.5), (0, 1.0, 2.6), 62, res=128)
black_pass(True)
bg[0].default_value = (1, 1, 1, 1)
shoot("sc", "icon_sil", (13, -13, 6.5), (0, 1.0, 2.6), 62, res=128)
black_pass(False)
print("AQUARIS_V5_DONE")
