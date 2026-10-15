# Aquaris boss, PRODUCTION pass (v5 direction). Art only; nothing is imported into Studio from here.
#   flatpak run org.blender.Blender -b -P $PWD/tools/blender/build_035_aquaris_boss.py && python3 tools/blender/assemble_boss_035.py
# Output:
#   assets/blender/creatures/AquarisBoss.blend           the model (design units) + preview rig
#   ~/Documents/035/AquarisBoss.fbx, AquarisBossFX.fbx   (also copied to assets/export/035/) + AquarisBoss_parts.json
#   ~/Pictures/035_preview/boss/                         tiles + sheet
# One MeshPart per (moving piece x colour), named AquarisBoss_<Piece>_<Colour>; pieces never merge across a joint:
#   Head, Jaw, Neck, Body, TailA, TailB, TailC, WingR, WingL, LegFR, LegFL, LegHR, LegHL.
# Colours (= part Color/Material in Studio, no textures): Blue Deep Ice Gold Glow(Neon) Claw Ink Membrane Tooth.
# Export units: 1 unit = 1 stud at spec.scale 1 (the model is built 3x bigger = the world size, spec.scale 3). Origin = ground under the
# waist. Same FBX axes as the earlier 034/035 exports (front = -Z in Studio; Blender's X arrives mirrored, so ...L files reach +X).
import bpy, bmesh, math, os, json, random, shutil
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

V = Vector
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLEND = os.path.join(ROOT, "assets", "blender", "creatures", "AquarisBoss.blend")
EXPORT_REPO = os.path.join(ROOT, "assets", "export", "035")
EXPORT_DOCS = os.path.expanduser("~/Documents/035")
PREV = os.path.expanduser("~/Pictures/035_preview/boss")
TMP = os.path.join(PREV, "tiles")
for d in (os.path.dirname(BLEND), EXPORT_REPO, EXPORT_DOCS, TMP):
    os.makedirs(d, exist_ok=True)
K = 1.0 / 3.0  # export scale: design (world) size -> spec.scale 1 size
DY, DZ = 0.35, -3.05  # head detail coordinates are written in this shifted frame, everything is moved at the end
ORIGIN = V((0, 1.1 + DY - DY, 0))  # ground under the waist, design frame after the final shift


def hexc(h):
    h = h.lstrip("#")
    lin = lambda c: ((c / 255 + 0.055) / 1.055) ** 2.4 if c / 255 > 0.04045 else c / 255 / 12.92
    return (lin(int(h[0:2], 16)), lin(int(h[2:4], 16)), lin(int(h[4:6], 16)), 1)


COL = {
    "Blue": ("#1F5FD1", 0.4, 0, 0.25), "Deep": ("#173F99", 0.45, 0, 0.2), "Ice": ("#A8F0FF", 0.4, 0, 0.3), "Gold": ("#FFC83D", 0.3, 0, 0.3),
    "Glow": ("#3FE6FF", 0.2, 3.0, 0), "Claw": ("#E4F2FF", 0.35, 0, 0.2), "Ink": ("#071225", 0.3, 0, 0), "Membrane": ("#3B86E6", 0.45, 0, 0.2),
    "Tooth": ("#F4FAFF", 0.35, 0, 0.1), "Pool": ("#3FE6FF", 0.3, 1.0, 0), "Noob": ("#888888", 0.7, 0, 0),
}
bpy.ops.wm.read_factory_settings(use_empty=True)
mats = {}


def mat(name, color=None):
    if name in mats:
        return mats[name]
    c = COL.get(name)
    hx, rough, emit, coat = c if c else (color, 0.5, 0, 0)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = hexc(hx)
    b.inputs["Roughness"].default_value = rough
    if "Coat Weight" in b.inputs:
        b.inputs["Coat Weight"].default_value = coat
    if emit > 0:
        b.inputs["Emission Color"].default_value = hexc(hx)
        b.inputs["Emission Strength"].default_value = emit
    mats[name] = m
    return m


REG = []  # (object, piece, colour)
CUR = {"piece": "Body", "skip": False}


def piece(name):
    CUR["piece"] = name


def link(name, me):
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def finish(o, colour):
    m = mat(colour)
    o.data.materials.clear()
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = False
    if not CUR["skip"]:
        REG.append([o, CUR["piece"], colour])
    return o


def catmull(vals, t):
    n = len(vals)
    i = min(int(t), n - 2)
    f = t - i
    p0, p1, p2, p3 = vals[max(i - 1, 0)], vals[i], vals[i + 1], vals[min(i + 2, n - 1)]
    return 0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (-p0 + 3 * p1 - 3 * p2 + p3) * f * f * f)


def loft(name, secs, colour, side=10, ref=(0, 0, 1), sub=1, caps=(True, True)):
    """secs: (x, y, z, halfwidth, halfheight, keel, squareness); sub>1 resamples with Catmull-Rom."""
    S = [list(s) for s in secs]
    if sub > 1:
        n = (len(S) - 1) * sub + 1
        S = [[catmull([s[k] for s in S], i / sub) for k in range(7)] for i in range(n)]
    bm = bmesh.new()
    rings = []
    for i, s in enumerate(S):
        c = V(s[:3])
        t = (V(S[min(i + 1, len(S) - 1)][:3]) - V(S[max(i - 1, 0)][:3])).normalized()
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
    return finish(link(name, me), colour)


def ribbon(name, pts, widths, colour, thick=0.05, sub=2):
    return loft(name, [(p[0], p[1], p[2], widths[i], thick, 0, 2) for i, p in enumerate(pts)], colour, side=6, sub=sub)


def spike(name, base, tip, r, colour, side=5):
    return loft(name, [(base[0], base[1], base[2], r, r, 0, 2), (tip[0], tip[1], tip[2], 0.006, 0.006, 0, 2)], colour, side=side, ref=(1, 0, 0.3))


def ell(name, loc, scale, rot, colour, seg=8, rings=5):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = link(name, me)
    o.location, o.scale, o.rotation_euler = loc, scale, rot
    return finish(o, colour)


def split_classes(o, classify, base_name, piece_name):
    """Splits a loft into one object per colour class (by polygon centre + normal)."""
    me = o.data
    groups = {}
    for p in me.polygons:
        groups.setdefault(classify(p.center, p.normal), []).append(p)
    for cls, polys in groups.items():
        bm = bmesh.new()
        vm = {}
        for p in polys:
            bm.faces.new([vm.setdefault(vi, bm.verts.new(me.vertices[vi].co)) for vi in p.vertices])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        nm = bpy.data.meshes.new("%s_%s" % (base_name, cls))
        bm.to_mesh(nm)
        bm.free()
        CUR["piece"] = piece_name
        finish(link("%s_%s" % (base_name, cls), nm), cls)
    for i, r in enumerate(REG):
        if r[0] is o:
            REG.pop(i)
            break
    bpy.data.objects.remove(o)


# ================================================================ spine (tail -> snout): 6 pieces that share their end sections
def Q(x, y, z, w, hh, k, p):
    return (x, y + DY, z + DZ, w, hh, k, p)


SPINE = [Q(*t) for t in (
    (0, 12.4, 3.2, 0.04, 0.04, 0, 2), (0, 11.4, 2.3, 0.1, 0.11, 0, 2), (0, 10.2, 1.55, 0.19, 0.21, 0.05, 2.2), (0, 9.0, 1.3, 0.29, 0.33, 0.08, 2.3),
    (0, 7.8, 1.55, 0.4, 0.46, 0.1, 2.4), (0, 6.6, 2.15, 0.52, 0.6, 0.12, 2.4), (0, 5.4, 2.8, 0.66, 0.78, 0.15, 2.5), (0, 4.4, 3.35, 0.82, 0.95, 0.2, 2.6),
    (0, 3.3, 3.6, 0.92, 1.05, 0.2, 2.6), (0, 2.2, 3.55, 0.8, 0.95, 0.25, 2.5), (0, 1.1, 3.5, 0.72, 0.9, 0.32, 2.5),
    (0, 0.1, 3.7, 1.0, 1.2, 0.5, 2.7), (0, -0.9, 3.9, 1.18, 1.35, 0.6, 2.9), (0, -1.7, 4.15, 1.04, 1.2, 0.55, 2.7),
    (0, -2.3, 4.8, 0.74, 0.86, 0.3, 2.5), (0, -2.55, 5.7, 0.58, 0.7, 0.25, 2.5), (0, -2.55, 6.6, 0.5, 0.6, 0.2, 2.5), (0, -2.85, 7.4, 0.47, 0.55, 0.15, 2.5),
    (0, -3.4, 8.0, 0.5, 0.56, 0.12, 2.6),
)] + [
    # head: strong brow + jaw line, ROUND snout front (squareness ~2.3-2.6, domed tip), no box helmet
    (0, -3.65, 5.15, 0.82, 0.8, 0.12, 2.6), (0, -4.15, 5.2, 0.94, 0.8, 0.12, 2.7), (0, -4.75, 5.03, 0.74, 0.62, 0.1, 2.5),
    (0, -5.35, 4.9, 0.6, 0.5, 0.1, 2.4), (0, -5.9, 4.8, 0.5, 0.42, 0.05, 2.3), (0, -6.15, 4.78, 0.26, 0.22, 0, 2.0),
]
PIECE_RANGES = (("TailC", 0, 3), ("TailB", 3, 5), ("TailA", 5, 8), ("Body", 8, 13), ("Neck", 13, 18), ("Head", 18, 24))
Y_EDGES = [SPINE[3][1], SPINE[5][1], SPINE[8][1], SPINE[13][1], SPINE[18][1]]


def piece_for_y(y):
    for nm, e in zip(("TailC", "TailB", "TailA", "Body", "Neck"), Y_EDGES):
        if y > e:
            return nm
    return "Head"


def spine_class(c, n):
    if n.z < -0.25 and abs(c.x) < (0.95 if c.y < 5.5 else 0.45) and -5.9 < c.y < 7.6:
        return "Ice"
    if n.z > 0.72:
        return "Deep"
    return "Blue"


CUR["skip"] = True
full = loft("SpineFull", SPINE, "Blue", side=14, sub=2)  # only for raycasts, deleted at the end
CUR["skip"] = False
bvh = BVHTree.FromObject(full, bpy.context.evaluated_depsgraph_get())


def ray(o, d):
    r = bvh.ray_cast(V(o), V(d))
    return (r[0], r[1]) if r[0] is not None else (None, None)


def top(x, y):
    return ray((x, y, 20), (0, 0, -1))[0]


for nm, a, b in PIECE_RANGES:
    piece(nm)
    o = loft("Spine_" + nm, SPINE[a : b + 1], "Blue", side=14, sub=2)
    split_classes(o, spine_class, "Spine_" + nm, nm)

# ================================================================ head (piece Head): strong brow, confident friendly-fierce face
piece("Head")
for s in (1, -1):
    loft("Brow", [(s * 0.2, -3.85, 5.62, 0.2, 0.12, 0, 3), (s * 0.5, -4.5, 5.55, 0.27, 0.15, 0, 3), (s * 0.58, -5.05, 5.3, 0.17, 0.09, 0, 3)], "Deep", side=8, sub=2)
    e, _ = ray((s * 4, -4.4, 5.15), (-s, 0, 0))
    ell("Eye", (e.x - s * 0.04, e.y, e.z), (0.1, 0.3, 0.15), (math.radians(-18), 0, 0), "Glow", seg=10, rings=6)
    ell("Pupil", (e.x - s * 0.04 + s * 0.07, e.y - 0.02, e.z), (0.06, 0.05, 0.12), (math.radians(-18), 0, 0), "Ink", seg=6, rings=4)
    n_, _ = ray((s * 0.17, -9, 4.85), (0, 1, 0))
    ell("Nostril", (n_.x, n_.y + 0.02, n_.z), (0.06, 0.05, 0.05), (0, 0, 0), "Ink", seg=6, rings=4)
    mm, _ = ray((s * 4, -5.3, 4.72), (-s, 0, 0))
    ribbon("Smile", [(mm.x + s * 0.01, -3.95, 4.88), (mm.x + s * 0.01, -4.5, 4.7), (mm.x + s * 0.01, -5.2, 4.68), (mm.x + s * 0.01, -5.8, 4.74)], [0.05] * 4, "Ink", thick=0.04)
    for j, yy in enumerate((-5.15, -4.7)):
        tt, _ = ray((s * 0.3, -9, 4.78), (0, 1, 0))
        spike("Fang", (s * 0.3, yy, 4.88), (s * 0.3, yy, 4.52), 0.065, "Tooth", side=4)
    f0, _ = ray((s * 4, -4.0, 4.8), (-s, 0, 0))
    for j in range(2):
        o0 = V((f0.x, f0.y + 0.2 * j, f0.z - 0.14 * j))
        spike("Cheek", o0, o0 + V((s * 0.7, 1.2 - 0.2 * j, 0.25 - 0.4 * j)), 0.17, "Ice", side=4)
    w0, _ = ray((s * 4, -5.6, 4.8), (-s, 0, 0))
    ribbon("Whisker", [(w0.x, w0.y, w0.z), (w0.x + s * 0.6, w0.y + 0.9, w0.z - 0.4), (w0.x + s * 1.3, w0.y + 2.1, w0.z - 0.6), (w0.x + s * 2.1, w0.y + 3.4, w0.z - 0.2)], [0.2, 0.2, 0.14, 0.02], "Glow", thick=0.05)
    ribbon("Tendril", [(s * 0.18, -5.35, 4.3), (s * 0.5, -4.8, 3.55), (s * 0.65, -4.2, 2.65), (s * 0.6, -3.7, 1.8)], [0.16, 0.14, 0.1, 0.01], "Glow", thick=0.05)
loft("NoseBridge", [(0, -4.3, 5.55, 0.12, 0.1, 0, 3), (0, -5.0, 5.32, 0.16, 0.11, 0, 3), (0, -5.7, 5.1, 0.14, 0.1, 0, 3)], "Deep", side=6, sub=2)
ell("MouthInside", (0, -4.85, 4.78), (0.33, 0.85, 0.07), (0, 0, 0), "Ink", seg=8, rings=4)
# five horns: a long swept pair, a tall centre crown horn and two shorter side crown horns (all thick, read at 128 px)
for s in (1, -1):
    b = top(s * 0.42, -3.9)
    loft("Horn", [(b.x, b.y, b.z - 0.1, 0.32, 0.3, 0, 3), (b.x + s * 0.1, b.y + 0.5, b.z + 0.45, 0.27, 0.25, 0, 3), (b.x + s * 0.3, b.y + 1.3, b.z + 0.85, 0.2, 0.19, 0, 3), (b.x + s * 0.55, b.y + 2.2, b.z + 0.85, 0.12, 0.11, 0, 3), (b.x + s * 0.75, b.y + 2.95, b.z + 0.5, 0.015, 0.015, 0, 2)], "Gold", side=7, ref=(1, 0, 0), sub=2)
    b2 = top(s * 0.66, -4.2)
    loft("CrownSide", [(b2.x, b2.y, b2.z - 0.08, 0.22, 0.2, 0, 3), (b2.x + s * 0.12, b2.y + 0.3, b2.z + 0.5, 0.17, 0.16, 0, 3), (b2.x + s * 0.3, b2.y + 0.75, b2.z + 1.0, 0.1, 0.1, 0, 3), (b2.x + s * 0.55, b2.y + 1.3, b2.z + 1.3, 0.012, 0.012, 0, 2)], "Gold", side=6, ref=(1, 0, 0), sub=2)
b0 = top(0, -4.0)
loft("CrownCenter", [(b0.x, b0.y, b0.z - 0.1, 0.32, 0.3, 0, 3), (b0.x, b0.y + 0.35, b0.z + 0.65, 0.25, 0.24, 0, 3), (b0.x, b0.y + 0.9, b0.z + 1.35, 0.16, 0.15, 0, 3), (b0.x, b0.y + 1.6, b0.z + 1.8, 0.012, 0.012, 0, 2)], "Gold", side=7, ref=(1, 0, 0), sub=2)
ell("ForeheadGem", b0 + V((0, -0.35, 0.18)), (0.12, 0.1, 0.22), (math.radians(-20), 0, 0), "Glow", seg=4, rings=2)
# mane: thick layered fin blades
for ri, (y, zc, ln) in enumerate(((-3.5, 5.0, 2.0), (-2.7, 4.2, 2.3))):
    for k in range(5):
        a = math.radians(-80 + k * 40)
        d = V((math.sin(a), 0, math.cos(a)))
        h0, _ = ray(V((0, y, zc)) + d * 4, -d)
        if h0 is None:
            continue
        o0 = h0 - d * 0.03
        out = d * (0.55 + 0.05 * ri) + V((0, 1.0, 0)) * 0.9
        mid = o0 + out * 0.5 * ln / 1.5 + V((0, 0.15, 0.1))
        tip = o0 + out * ln / 1.5 + V((0, 0.35, -0.15))
        piece(piece_for_y(y))
        ribbon("Mane", [(o0.x, o0.y, o0.z), (mid.x, mid.y, mid.z), (tip.x, tip.y, tip.z)], [0.4, 0.48, 0.02], "Ice" if (k + ri) % 2 == 0 else "Glow", thick=0.05, sub=1)

# ================================================================ jaw (piece Jaw): stronger, wider; hinge-rotated open a little at the end
piece("Jaw")
loft("JawBone", [(0, -3.9, 4.55, 0.5, 0.22, 0.3, 2.6), (0, -4.7, 4.45, 0.5, 0.2, 0.3, 2.6), (0, -5.4, 4.43, 0.42, 0.17, 0.3, 2.4), (0, -5.9, 4.45, 0.3, 0.13, 0.2, 2.2), (0, -6.05, 4.5, 0.12, 0.08, 0, 2)], "Ice", side=10, sub=2)
ell("ChinKnob", (0, -5.75, 4.3), (0.2, 0.2, 0.15), (0, 0, 0), "Gold", seg=8, rings=4)
for s in (1, -1):
    spike("LowerFang", (s * 0.28, -5.45, 4.5), (s * 0.28, -5.45, 4.85), 0.06, "Tooth", side=4)

# ================================================================ neck (piece Neck): cobra-style plated front
piece("Neck")
for z_ in (2.3, 2.75, 3.2, 3.65, 4.1):
    h_, _ = ray((0, -9, z_), (0, 1, 0))
    if h_ is not None:
        ell("NeckPlate", h_, (0.42, 0.12, 0.14), (0, 0, 0), "Ice", seg=8, rings=3)

# ================================================================ body (piece Body): chest shield, layered shoulder scales, belly plates, shards
piece("Body")
ksec, ghit = [], None
for z_, w_ in zip((2.15, 1.75, 1.35, 0.95, 0.55), (0.2, 0.5, 0.56, 0.34, 0.07)):
    h_, _ = ray((0, -9, z_), (0, 1, 0))
    if h_ is not None:
        ksec.append((h_.x, h_.y - 0.05, h_.z, w_, 0.07, 0, 3))
        if abs(z_ - 1.35) < 0.01:
            ghit = h_
if len(ksec) >= 3:
    loft("ChestShield", ksec, "Gold", side=8, ref=(0, -1, 0), sub=2)
if ghit is not None:
    ell("ChestGem", ghit + V((0, -0.16, 0)), (0.24, 0.09, 0.42), (0, 0, 0), "Glow", seg=4, rings=2)
# layered scale plates over the shoulders: rows of overlapping shingles that follow the body's side (no separate leaf pads)
for s in (1, -1):
    for row, (zz, colr) in enumerate(((1.95, "Gold"), (1.45, "Gold"), (0.95, "Deep"))):
        for col in range(4):
            y = -1.45 + col * 0.62 + (0.3 if row % 2 else 0)
            h_, n_ = ray((s * 6, y, zz), (-s, 0, 0))
            if h_ is None:
                continue
            q = (n_ + V((0, 0, 0.18))).normalized().to_track_quat("Z", "Y")
            o = ell("Scale", h_ + n_ * 0.02, (0.4, 0.46, 0.07), (0, 0, 0), colr, seg=6, rings=3)
            o.rotation_mode = "QUATERNION"
            o.rotation_quaternion = q
for i, y in enumerate([y + DY for y in (-1.3, -0.7, -0.1, 0.5, 1.1, 1.7, 2.3)]):
    h_, _ = ray((0, y, -8), (0, 0, 1))
    if h_ is not None:
        ell("BellyPlate", h_ + V((0, 0, 0.03)), (0.6 - 0.03 * i, 0.3, 0.12), (math.radians(-12), 0, 0), "Ice", seg=6, rings=3)
for y, k in ((-2.5, 0.8), (-1.6, 0.75), (-0.7, 0.7), (0.2, 0.66), (1.2, 0.62), (2.2, 0.6), (3.4, 0.58), (4.6, 0.56), (5.8, 0.5), (7.0, 0.44), (8.2, 0.38), (9.4, 0.3), (10.6, 0.24)):
    y += DY
    t = top(0, y)
    if t is None:
        continue
    piece(piece_for_y(y))
    kk = k * 1.35
    spike("Shard", (t.x, t.y - 0.1, t.z - 0.08), (t.x, t.y + 0.4 * kk, t.z + 0.95 * kk), 0.2 * min(1.0, kk + 0.2), "Deep", side=4)
piece("TailC")
tipp = V(SPINE[0][:3])
loft("TailLeaf", [(0, tipp.y - 0.1, tipp.z - 0.05, 0.04, 0.04, 0, 2), (0, tipp.y + 0.35, tipp.z + 0.3, 0.12, 0.28, 0, 2.5), (0, tipp.y + 0.9, tipp.z + 0.9, 0.05, 0.45, 0, 2.2), (0, tipp.y + 1.25, tipp.z + 1.55, 0.006, 0.012, 0, 2)], "Gold", side=6, sub=2)
for k_, (dz_, dx_) in enumerate(((0.9, 0.0), (0.5, 0.35), (0.5, -0.35))):
    ribbon("TailFan", [(tipp.x, tipp.y + 0.2, tipp.z + 0.1), (tipp.x + dx_ * 0.6, tipp.y + 0.8, tipp.z + dz_ * 0.5 + 0.3), (tipp.x + dx_ * 1.4, tipp.y + 1.6, tipp.z + dz_ * 1.1 + 0.4), (tipp.x + dx_ * 2.0, tipp.y + 2.3, tipp.z + dz_ * 1.0 + 0.1)], [0.12, 0.24, 0.2, 0.01], "Glow", thick=0.05)


# ================================================================ legs: 4 pieces (leg + paw + claws + gold bracer + joint plate)
def PT(x, y, z):
    return V((x, y + DY, z + DZ))


def leg_class(c, n):
    return "Deep" if n.z > 0.85 else "Blue"


def paw(s, y0):
    x, g = s * 1.2, DZ
    loft("Paw", [(x, y0 + 0.35, 0.34 + g, 0.3, 0.2, 0, 3), (x, y0 - 0.2, 0.26 + g, 0.36, 0.17, 0, 3), (x, y0 - 0.7, 0.18 + g, 0.32, 0.11, 0, 3.2)], "Blue", side=8, sub=2)
    for k in (-1, 0, 1):
        tx = x + k * 0.2
        loft("Toe", [(tx, y0 - 0.55, 0.2 + g, 0.1, 0.09, 0, 2.6), (tx, y0 - 0.95, 0.15 + g, 0.09, 0.07, 0, 2.6)], "Blue", side=6)
        spike("Claw", (tx, y0 - 0.9, 0.17 + g), (tx, y0 - 1.6, 0.03 + g), 0.1, "Claw", side=4)


def leg(name, pts, sizes, plate, spk):
    o = loft("LegBone", [(p.x, p.y, p.z, w, hh, k, e) for p, (w, hh, k, e) in zip(pts, sizes)], "Blue", side=8, ref=(0, -1, 0), sub=2)
    split_classes(o, leg_class, "LegBone", name)


for s, sd in ((1, "R"), (-1, "L")):
    piece("LegF" + sd)
    leg("LegF" + sd, [PT(s * 0.8, -1.2, 3.9), PT(s * 1.2, -0.6, 2.5), PT(s * 1.2, -1.3, 1.05), PT(s * 1.2, -1.55, 0.5)], [(0.55, 0.68, 0.1, 3), (0.45, 0.52, 0.1, 3), (0.28, 0.32, 0.05, 3.2), (0.25, 0.25, 0.05, 3.2)], None, None)
    piece("LegF" + sd)
    e0 = PT(s * 1.42, -0.2, 2.55)
    loft("ElbowPlate", [(e0.x, e0.y - 0.3, e0.z, 0.15, 0.22, 0, 3), (e0.x, e0.y + 0.15, e0.z - 0.1, 0.11, 0.13, 0, 3)], "Gold", side=6)
    spike("ElbowSpike", e0, e0 + V((s * 0.1, 0.75, -0.05)), 0.12, "Gold")
    bp = PT(s * 1.2, -1.3, 1.05)
    loft("Bracer", [(bp.x, bp.y, bp.z - 0.14, 0.36, 0.36, 0, 2.5), (bp.x, bp.y, bp.z + 0.14, 0.36, 0.36, 0, 2.5)], "Gold", side=8, ref=(0, -1, 0))
    paw(s, -1.8)
    piece("LegH" + sd)
    leg("LegH" + sd, [PT(s * 0.95, 2.6, 3.6), PT(s * 1.35, 1.4, 2.35), PT(s * 1.28, 2.9, 1.2), PT(s * 1.22, 2.45, 0.5)], [(0.72, 0.85, 0.1, 3), (0.55, 0.65, 0.1, 3), (0.27, 0.32, 0.05, 3.2), (0.24, 0.26, 0.05, 3.2)], None, None)
    piece("LegH" + sd)
    k0 = PT(s * 1.65, 1.0, 2.4)
    loft("KneePlate", [(k0.x, k0.y + 0.25, k0.z, 0.14, 0.23, 0, 3), (k0.x, k0.y - 0.25, k0.z - 0.15, 0.11, 0.14, 0, 3)], "Gold", side=6)
    spike("KneeSpike", k0, k0 + V((s * 0.1, -0.7, -0.15)), 0.11, "Gold")
    hb = PT(s * 1.28, 2.9, 1.2)
    loft("Bracer", [(hb.x, hb.y, hb.z - 0.14, 0.34, 0.34, 0, 2.5), (hb.x, hb.y, hb.z + 0.14, 0.34, 0.34, 0, 2.5)], "Gold", side=8, ref=(0, -1, 0))
    paw(s, 2.15)

# ================================================================ wings: 2 pieces (bones Deep, membrane Membrane, trim Ice, gold joints)
for s, sd in ((1, "R"), (-1, "L")):
    piece("Wing" + sd)
    S0 = PT(s * 0.7, -1.2, 5.35)
    E0 = S0 + V((s * 0.6, 0.2, 1.6))
    W0 = E0 + V((s * 0.7, 1.4, 1.0))
    BASE = PT(s * 0.55, 3.2, 4.4)
    tips = [W0 + V((s * 1.0, 5.8, -2.4)), W0 + V((s * 1.6, 4.6, -0.9)), W0 + V((s * 1.8, 2.9, 0.5))]
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
                uu = u * (1 - 0.2 * math.sin(math.pi * v))
                Pp = rib(pi_, uu).lerp(rib(pi_ + 1, uu), v)
                Pp += V((s * 0.3 * math.sin(math.pi * v) * (0.4 + 0.6 * u), 0, 0.12 * math.sin(math.pi * v)))
                row.append(bm.verts.new(Pp))
            grid.append(row)
        for iu in range(NU):
            for iv in range(NV):
                f = (grid[iu][iv], grid[iu + 1][iv], grid[iu + 1][iv + 1], grid[iu][iv + 1])
                bm.faces.new(f if s > 0 else f[::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("Membrane")
    bm.to_mesh(me)
    bm.free()
    mo = link("Membrane", me)
    md = mo.modifiers.new("Solid", "SOLIDIFY")
    md.thickness = 0.14
    bpy.context.view_layer.objects.active = mo
    bpy.ops.object.modifier_apply(modifier="Solid")
    finish(mo, "Membrane")
    loft("WingArm", [(S0.x, S0.y, S0.z, 0.28, 0.26, 0, 3), (E0.x, E0.y, E0.z, 0.22, 0.21, 0, 3), (W0.x, W0.y, W0.z, 0.16, 0.16, 0, 3)], "Deep", side=8, sub=2, ref=(1, 0, 0))
    for i, T in enumerate(tips):
        pts = [rib(i + 1, u) for u in (0, 0.33, 0.66, 1.0)]
        loft("Rib", [(p.x, p.y, p.z, r, r, 0, 3) for p, r in zip(pts, (0.13, 0.11, 0.08, 0.02))], "Deep", side=6, ref=(1, 0, 0), sub=1)
    trim = []
    for pi_ in range(3):
        for iv in range(NV + 1):
            v = iv / NV
            uu = 1 - 0.2 * math.sin(math.pi * v)
            trim.append(rib(pi_, uu).lerp(rib(pi_ + 1, uu), v) + V((s * 0.3 * math.sin(math.pi * v), 0, 0.12 * math.sin(math.pi * v))))
    ribbon("WingTrim", trim, [0.1] * len(trim), "Ice", thick=0.06, sub=1)
    spike("WingClaw", W0 + V((0, -0.1, 0.1)), W0 + V((s * 0.15, -0.65, 0.4)), 0.13, "Gold")
    loft("WingBand", [(E0.x, E0.y - 0.12, E0.z - 0.02, 0.3, 0.29, 0, 2.5), (E0.x, E0.y + 0.12, E0.z + 0.02, 0.3, 0.29, 0, 2.5)], "Gold", side=8, ref=(1, 0, 0))
    hk = tips[2]
    loft("WingHook", [(hk.x, hk.y, hk.z, 0.11, 0.11, 0, 2.5), (hk.x + s * 0.1, hk.y - 0.5, hk.z + 0.5, 0.08, 0.08, 0, 2.5), (hk.x + s * 0.2, hk.y - 1.0, hk.z + 1.1, 0.012, 0.012, 0, 2)], "Gold", side=5, ref=(1, 0, 0), sub=2)

bpy.data.objects.remove(full)

# ================================================================ merge: one mesh per (piece, colour), final frame, jaw opened
JAW_HINGE = V((0, -3.95, 4.65))
RM = Matrix.Rotation(math.radians(9), 4, "X")
SHIFT = V((0, -DY, -DZ))
groups = {}
for o, pc, cl in REG:
    groups.setdefault((pc, cl), []).append(o)
MERGED = {}
for (pc, cl), objs in groups.items():
    verts, faces = [], []
    for o in objs:
        off = len(verts)
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            if pc == "Jaw":
                p = JAW_HINGE + RM @ (p - JAW_HINGE)
            verts.append(p + SHIFT)
        for p in o.data.polygons:
            faces.append([off + i for i in p.vertices])
    me = bpy.data.meshes.new("AquarisBoss_%s_%s" % (pc, cl))
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    ob = link("AquarisBoss_%s_%s" % (pc, cl), me)
    CUR["skip"] = True
    finish(ob, cl)
    MERGED[(pc, cl)] = ob
    CUR["skip"] = False
for o, pc, cl in REG:
    bpy.data.objects.remove(o)
REG.clear()


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


# ================================================================ FX meshes (separate FBX) + bubbles (plain parts in Studio)
random.seed(35)
CUR["skip"] = True
fx_objs_world, fx_objs_cap = [], []


def fx_loft(name, pts, widths, thick):
    o = loft(name, [(p[0], p[1], p[2], widths[i], thick, 0, 2) for i, p in enumerate(pts)], "Pool", side=6, sub=1)
    return o


ring_pts = []
for k in range(0, 41):
    a = 2 * math.pi * k / 40
    ring_pts.append((4.9 * math.cos(a), 3.0 + 8.4 * math.sin(a), 0.12 + 0.12 * math.sin(a * 6)))
fx_ring = fx_loft("AquarisBossFX_Ring", ring_pts, [0.45] * 41, 0.1)
streams = []
for s, nm in ((1, "StreamR"), (-1, "StreamL")):
    pts, wid = [], []
    for i in range(0, 16):
        t_ = i / 15
        pts.append((s * (4.0 + 0.9 * math.sin(t_ * 3.0)), 9.5 - t_ * 12.5, 0.6 + 4.8 * math.sin(t_ * math.pi * 0.9) + 0.4 * math.sin(t_ * 9)))
        wid.append(0.12 + 0.34 * math.sin(math.pi * t_) + 0.02)
    streams.append(fx_loft("AquarisBossFX_" + nm, pts, wid, 0.08))
bubbles_world = [(round(random.uniform(-5.5, 5.5), 2), round(random.uniform(-4, 11), 2), round(random.uniform(0.8, 8.0), 2), round(random.uniform(0.1, 0.24), 2)) for _ in range(14)]
bubbles_world = [b for b in bubbles_world if not (abs(b[0]) < 1.8 and 0 < b[1] < 8)]
bubbles_cap = [(1.8, -2.4, 6.0, 0.1), (-2.0, 1.0, 4.6, 0.12), (1.6, 4.5, 4.0, 0.09), (-1.6, 7.5, 3.0, 0.1), (0.2, -3.0, 8.2, 0.08)]
bub_world_objs, bub_cap_objs = [], []
for b in bubbles_world:
    o = ell("Bubble", V((b[0], b[1], b[2])), (b[3],) * 3, (0, 0, 0), "Glow", seg=6, rings=4)
    bub_world_objs.append(o)
for b in bubbles_cap:
    o = ell("BubbleC", V((b[0], b[1], b[2])), (b[3],) * 3, (0, 0, 0), "Glow", seg=6, rings=4)
    bub_cap_objs.append(o)
CUR["skip"] = False
fx_world_objs = [fx_ring] + streams + bub_world_objs
fx_cap_objs = bub_cap_objs

# ================================================================ budget + joints report
model_objs = list(MERGED.values())
per_mesh = {o.name: tris(o) for o in model_objs}
total = sum(per_mesh.values())
by_piece = {}
for (pc, cl), o in MERGED.items():
    by_piece[pc] = by_piece.get(pc, 0) + tris(o)
fx_mesh_tris = {o.name: tris(o) for o in [fx_ring] + streams}
n_mesh = len(model_objs)
parts_world = n_mesh + 3 + len(bubbles_world)
parts_cap = n_mesh + len(bubbles_cap)
mx = [max(v.co[i] for o in model_objs for v in o.data.vertices) for i in range(3)]
mn = [min(v.co[i] for o in model_objs for v in o.data.vertices) for i in range(3)]


def jt(p):  # design frame -> export frame (stud at scale 1, origin under the waist)
    q = (V(p) + V((0, -DY, -DZ)) - ORIGIN) * K
    return [round(q.x, 3), round(q.y, 3), round(q.z, 3)]


joints = {
    "Neck (Body->Neck)": jt(SPINE[13][:3]), "Head (Neck->Head)": jt(SPINE[18][:3]), "Jaw hinge": jt(tuple(JAW_HINGE + V((0, DY, DZ)) * 0)),
    "TailA (Body->TailA)": jt(SPINE[8][:3]), "TailB (TailA->TailB)": jt(SPINE[5][:3]), "TailC (TailB->TailC)": jt(SPINE[3][:3]),
    "WingR shoulder": jt(tuple(PT(0.7, -1.2, 5.35))), "WingL shoulder": jt(tuple(PT(-0.7, -1.2, 5.35))),
    "LegFR hip": jt(tuple(PT(0.8, -1.2, 3.9))), "LegFL hip": jt(tuple(PT(-0.8, -1.2, 3.9))), "LegHR hip": jt(tuple(PT(0.95, 2.6, 3.6))), "LegHL hip": jt(tuple(PT(-0.95, 2.6, 3.6))),
}
report = {
    "model_tris": total, "meshparts": n_mesh, "parts_with_world_fx": parts_world, "parts_with_captured_fx": parts_cap,
    "tris_by_piece": by_piece, "tris_per_mesh": per_mesh, "fx_mesh_tris": fx_mesh_tris,
    "bubbles_world": [list(b) for b in bubbles_world], "bubbles_captured": [list(b) for b in bubbles_cap],
    "size_at_scale1_studs": [round((mx[i] - mn[i]) * K, 2) for i in (0, 1, 2)], "joints_export_frame": joints,
    "export_scale": "1 unit = 1 stud at spec.scale 1; world = x3", "naming": "AquarisBoss_<Piece>_<Colour>; anchor AquarisBoss_Anchor at the origin (ground under the waist)",
}
print("AQUARIS_BOSS_BUDGET", json.dumps({k: report[k] for k in ("model_tris", "meshparts", "parts_with_world_fx", "parts_with_captured_fx", "tris_by_piece", "fx_mesh_tris", "size_at_scale1_studs")}))
print("AQUARIS_BOSS_MAXMESH", max(per_mesh.values()))

# ================================================================ FBX export (scaled copies in their own collection)
exp_col = bpy.data.collections.new("EXPORT")
bpy.context.scene.collection.children.link(exp_col)


def export_copy(o, name, shift):
    me = o.data.copy()
    for v in me.vertices:
        v.co = (v.co + shift) * K
    c = bpy.data.objects.new(name, me)
    exp_col.objects.link(c)
    return c


def anchor(name):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=0.02)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    c = bpy.data.objects.new(name, me)
    exp_col.objects.link(c)
    return c


def export_fbx(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, axis_forward="-Z", axis_up="Y", global_scale=1.0, apply_unit_scale=True, bake_space_transform=False, mesh_smooth_type="FACE")


mexp = [export_copy(o, o.name, -ORIGIN) for o in model_objs] + [anchor("AquarisBoss_Anchor")]
fexp = [export_copy(o, o.name, -ORIGIN + V((0, 0, 0))) for o in [fx_ring] + streams] + [anchor("AquarisBossFX_Anchor")]
for c in mexp + fexp:
    c.hide_render = True
export_fbx(mexp, os.path.join(EXPORT_REPO, "AquarisBoss.fbx"))
export_fbx(fexp, os.path.join(EXPORT_REPO, "AquarisBossFX.fbx"))
with open(os.path.join(EXPORT_REPO, "AquarisBoss_parts.json"), "w") as f:
    json.dump(report, f, indent=1)
for fn in ("AquarisBoss.fbx", "AquarisBossFX.fbx", "AquarisBoss_parts.json"):
    shutil.copy(os.path.join(EXPORT_REPO, fn), os.path.join(EXPORT_DOCS, fn))
for c in mexp + fexp:
    exp_col.objects.unlink(c)

# ================================================================ preview rig
boss = bpy.data.objects.new("AquarisRoot", None)
boss.location = V((0, 3.0, 0))
bpy.context.scene.collection.objects.link(boss)
bpy.context.view_layer.update()
cols = {}
for nm in ("FX_world", "FX_captured", "REF"):
    cols[nm] = bpy.data.collections.new(nm)
    bpy.context.scene.collection.children.link(cols[nm])


def adopt(o, parent=boss):
    for c_ in o.users_collection:
        c_.objects.unlink(o)
    mw = o.matrix_world.copy()
    o.parent = parent
    o.matrix_parent_inverse = parent.matrix_world.inverted()
    o.matrix_world = mw


for o in model_objs:
    o.parent = boss
    o.matrix_parent_inverse = boss.matrix_world.inverted()
for o in fx_world_objs:
    o.location += V((0, 0, 0))
    for c_ in o.users_collection:
        c_.objects.unlink(o)
    cols["FX_world"].objects.link(o)
    o.parent = boss
    o.matrix_parent_inverse = boss.matrix_world.inverted()
for o in fx_cap_objs:
    for c_ in o.users_collection:
        c_.objects.unlink(o)
    cols["FX_captured"].objects.link(o)
    o.parent = boss
    o.matrix_parent_inverse = boss.matrix_world.inverted()
noob = bpy.data.objects.new("Noob", None)
cols["REF"].objects.link(noob)
for nm, loc, sc_, colr in (("NoobLegs", (0, 0, 1.0), (1.9, 1.0, 2.0), "#3A8A3A"), ("NoobTorso", (0, 0, 3.0), (2.0, 1.0, 2.0), "#3B6FD0"), ("NoobHead", (0, 0, 4.55), (1.2, 1.2, 1.1), "#F5CD30"), ("NoobArmL", (-1.5, 0, 3.0), (1.0, 1.0, 2.0), "#F5CD30"), ("NoobArmR", (1.5, 0, 3.0), (1.0, 1.0, 2.0), "#F5CD30")):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    me = bpy.data.meshes.new(nm)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(nm, me)
    cols["REF"].objects.link(o)
    o.location, o.scale = loc, sc_
    m = bpy.data.materials.new(nm)
    m.use_nodes = True
    next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = hexc(colr)
    o.data.materials.append(m)
    o.parent = noob
bpy.ops.wm.save_as_mainfile(filepath=BLEND)

sc = bpy.context.scene
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
sc.view_settings.view_transform = "Standard"
sc.world = bpy.data.worlds.new("w")
sc.world.use_nodes = True
bg = sc.world.node_tree.nodes["Background"].inputs
bg[0].default_value, bg[1].default_value = (0.93, 0.95, 0.98, 1), 1.0
for loc, en, rot in (((6, -8, 9), 1.9, (math.radians(50), 0, math.radians(35))), ((-7, -5, 5), 0.6, (math.radians(70), 0, math.radians(-50)))):
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


def fx(world, cap):
    cols["FX_world"].hide_render = not world
    cols["FX_captured"].hide_render = not cap


cols["REF"].hide_render = True
fx(False, False)
for name, pos, tgt, lens in VIEWS[:3]:
    shoot("off", name, pos, tgt, lens)
black_pass(True)
bg[0].default_value = (1, 1, 1, 1)
shoot("off", "silhouette", (40, 3.2, 4.8), (0, 3.2, 4.4), 62)
black_pass(False)
bg[0].default_value = (0.93, 0.95, 0.98, 1)
fx(True, True)
bg[0].default_value, bg[1].default_value = (0.04, 0.14, 0.27, 1), 1.0
for name, pos, tgt, lens in VIEWS:
    shoot("w", name, pos, tgt, lens)
fx(False, True)
for name, pos, tgt, lens in VIEWS[:3]:
    shoot("c", name, pos, tgt, lens)
bg[0].default_value, bg[1].default_value = (0.93, 0.95, 0.98, 1), 1.0
cols["REF"].hide_render = False
fx(True, True)
noob.location = V((-9, -1, 0))
shoot("sc", "world", (34, -38, 16), (-2, 3.0, 4.2), 40)
fx(False, True)
for tag, k in (("carried", 1.3 / 3.0), ("pad", 1.6 / 3.0)):
    boss.scale = (k, k, k)
    boss.location = V((0, 3.0 * k, 0))
    noob.location = V((-4.2, 1.0 + 0.2, 0))
    shoot("sc", tag, (14, -17, 7), (-1.0, 1.2, 2.4), 45)
boss.scale = (1.3 / 3.0,) * 3
boss.location = V((0, 1.3, 0))
cols["REF"].hide_render = True
fx(False, False)
shoot("sc", "icon", (13, -13, 6.5), (0, 1.0, 2.6), 62, res=128)
black_pass(True)
bg[0].default_value = (1, 1, 1, 1)
shoot("sc", "icon_sil", (13, -13, 6.5), (0, 1.0, 2.6), 62, res=128)
black_pass(False)
print("AQUARIS_BOSS_DONE")
