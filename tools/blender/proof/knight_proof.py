# Upper-body proof-of-quality (helmet, shoulders, chest) built with MODIFIER-BASED hard-surface modelling (Solidify / Bevel / Boolean / tapered curves),
# NOT the kit035 procedural patch method. Stylised Roblox proportions (chunky, big head, huge shoulders). Original design.
#   flatpak run org.blender.Blender -b -P $PWD/tools/blender/proof/knight_proof.py -- [--out DIR] [--res 900]
import math
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "blender", "proof"))
import bpy
from mathutils import Vector as V
import hs2

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[argv.index("--out") + 1] if "--out" in argv else os.path.expanduser("~/Pictures/035_preview/proof")
RES = int(argv[argv.index("--res") + 1]) if "--res" in argv else 900
EXPORT = os.path.join(ROOT, "assets", "export", "035", "proof")
os.makedirs(OUT, exist_ok=True)
os.makedirs(EXPORT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
parts = {}  # material kind -> [objects]


def tag(ob, kind):
    parts.setdefault(kind, []).append(ob)
    return ob


def lerp(a, b, t):
    return a + (b - a) * t


def sstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def table_rows(tab, n):
    """tab: [(z, rx, zf, zb), ...] -> n smoothly interpolated rows (z, rx, zf, zb, 0, 0)."""
    z0, z1 = tab[0][0], tab[-1][0]
    out = []
    for i in range(n):
        z = lerp(z0, z1, i / (n - 1))
        for a, b in zip(tab, tab[1:]):
            if a[0] <= z <= b[0]:
                t = sstep(0.0, 1.0, (z - a[0]) / (b[0] - a[0]))
                out.append((z, lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t), 0.0, 0.0))
                break
    return out


# =============================================================== chest
TORSO = [(0.0, 1.08, 0.62, 0.6), (0.45, 0.98, 0.56, 0.55), (0.95, 1.3, 0.78, 0.62), (1.4, 1.58, 0.94, 0.66), (1.75, 1.48, 0.72, 0.56), (1.98, 1.04, 0.54, 0.5)]


def chest():
    rows = table_rows(TORSO, 28)
    # dark under-layer
    u = hs2.superellipse_shell(rows, seg=40, p=2.7, cap_bottom=True, name="under")
    hs2.solid(u, 0.08)
    hs2.bake(u)
    tag(u, "Dark")
    # breastplate: keeled, front half, V-cut lower edge, shoulder-top cut
    b = hs2.superellipse_shell(table_rows(TORSO, 36), seg=72, p=2.7, name="breast")

    def keel(c):
        if c.y < 0:
            f = math.exp(-(c.x / 0.4) ** 2) * sstep(0.35, 1.25, c.z) * (1 - sstep(1.7, 1.98, c.z))
            c.y -= 0.22 * f
            side = sstep(0.55, 1.2, abs(c.x)) * sstep(0.7, 1.3, c.z) * (1 - sstep(1.5, 1.95, c.z))
            c.y -= 0.06 * side
        return c

    hs2.displace(b, keel)
    hs2.keep(b, (0, 0.06, 0), (0, -1, 0))
    s = 0.34
    n = math.hypot(s, 1)
    hs2.keep(b, (0, 0, 0.62), (-s / n, 0, 1 / n))
    hs2.keep(b, (0, 0, 0.62), (s / n, 0, 1 / n))
    hs2.keep(b, (0, 0, 1.97), (0, 0, -1))
    hs2.solid(b, 0.12, offset=-1)
    hs2.bevel(b, 0.045, 3, 32)
    hs2.bake(b, 36)
    tag(b, "Plate")
    # blue enamel keel panel (inlay following the chest) + steel keel rail
    inl = hs2.superellipse_shell(table_rows(TORSO, 36), seg=72, p=2.7, name="inlay")
    hs2.displace(inl, lambda c: hs2.V((c.x, c.y - (0.27 * math.exp(-(c.x / 0.34) ** 2) * sstep(0.35, 1.25, c.z) * (1 - sstep(1.7, 1.98, c.z)) if c.y < 0 else 0) - (0.02 if c.y < 0 else 0), c.z)))
    hs2.keep(inl, (0.0, 0.06, 0), (0, -1, 0))
    hs2.keep(inl, (0.19, 0, 0), (-1, 0, 0))
    hs2.keep(inl, (-0.19, 0, 0), (1, 0, 0))
    hs2.keep(inl, (0, 0, 0.9), (0, 0, 1))
    hs2.keep(inl, (0, 0, 1.62), (0, 0, -1))
    hs2.solid(inl, 0.05, offset=-1)
    hs2.bevel(inl, 0.02, 2, 35)
    hs2.bake(inl, 36)
    tag(inl, "Blue")
    # lames over the belly: three overlapping bands, each a little bigger and lower, with flared lower lip
    for k in range(3):
        top = 0.78 - 0.17 * k
        rows_l = [(top - 0.34, 1.04 + 0.05 * k + 0.06, 0.62 + 0.06 * k + 0.06, 0.6 + 0.05 * k + 0.06, 0, 0), (top - 0.1, 0.9 + 0.05 * k, 0.55 + 0.05 * k, 0.53 + 0.05 * k, 0, 0), (top + 0.06, 0.88 + 0.04 * k, 0.53 + 0.04 * k, 0.52 + 0.04 * k, 0, 0)]
        lam = hs2.superellipse_shell(rows_l, seg=56, p=2.6, name="lame%d" % k)
        hs2.solid(lam, 0.07)
        hs2.bevel(lam, 0.03, 2, 35)
        hs2.bake(lam, 36)
        tag(lam, "Plate" if k % 2 == 0 else "Dark")
    # gorget: three stepped collar rings
    for k in range(3):
        z = 1.98 + 0.13 * k
        rr = 0.78 + 0.18 * (2 - k)
        gr = hs2.superellipse_shell([(z, rr * 1.15, rr * 0.9, rr * 0.9, 0, 0), (z + 0.2, rr, rr * 0.8, rr * 0.8, 0, 0)], seg=48, p=2.4, name="gorget%d" % k)
        hs2.solid(gr, 0.07)
        hs2.bevel(gr, 0.03, 2, 35)
        hs2.bake(gr, 36)
        tag(gr, "Plate" if k != 1 else "Dark")
    # chest medallion: a raised steel octagon with a blue gem
    bm = hs2.bmesh.new()
    hs2.bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.62, radius2=0.5, depth=0.16)
    med = hs2.obj_from_bm(bm, "medal")
    med.rotation_euler = (math.pi / 2, 0, math.radians(22.5))
    med.location = (0, -1.14, 1.1)
    hs2.bevel(med, 0.025, 2, 35)
    hs2.bake(med, 40)
    tag(med, "Trim")
    bm = hs2.bmesh.new()
    hs2.bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=0.3)
    gem = hs2.obj_from_bm(bm, "gem")
    gem.scale = (1, 0.55, 1)
    gem.location = (0, -1.27, 1.1)
    hs2.bake(gem, 60)
    tag(gem, "Blue")


# =============================================================== pauldrons
def pauldrons():
    cx, cz = 1.95, 1.55
    S = 0.84
    for k, (t0, t1, R, flare, kind) in enumerate(((2, 40, 1.0, 0.0, "Plate"), (34, 64, 1.1, 0.05, "Dark"), (58, 88, 1.2, 0.1, "Plate"))):
        rows = []
        for i in range(10):
            t = math.radians(lerp(t0, t1, i / 9))
            r = S * R * math.sin(t) * (1 + flare * sstep(0.6, 1.0, i / 9))
            rows.append((0.95 * S * R * math.cos(t) - 0.36 * k, r * 1.05, r * 0.95, r * 0.95, 0, 0))
        rows.sort()
        pl = hs2.superellipse_shell(rows, seg=44, p=2.3, name="pauld%d" % k)
        hs2.solid(pl, 0.1)
        hs2.bevel(pl, 0.04, 3, 32)
        pl.location = (cx, 0, cz)
        pl.rotation_euler = (0, math.radians(-22), 0)
        hs2.mirror_x(pl)
        hs2.bake(pl, 38)
        tag(pl, kind)
    # rim ridge along the lowest lame (a bevelled steel bar following the edge)
    ring = hs2.tapered_curve([(math.cos(a) * 1.28, math.sin(a) * 1.2, 0) for a in [i * math.pi / 6 for i in range(12)]], [1.0] * 12, bevel_depth=0.07, name="rimring")
    ring.data.splines[0].use_cyclic_u = True
    ring.location = (cx, 0, cz - 0.4)
    # spikes: three big curved tapered horns rising from the top lame (the shoulder's signature)
    for i, (yo, hgt, bend) in enumerate(((-0.35, 1.2, 0.5), (0.0, 1.45, 0.65), (0.35, 1.2, 0.5))):
        p0 = V((-0.05, yo * 0.9, 0.62))
        pts = [p0, p0 + V((0.12, yo * 0.2 + 0.05, hgt * 0.4)), p0 + V((0.32, yo * 0.3 + bend * 0.45, hgt * 0.78)), p0 + V((0.58, yo * 0.3 + bend, hgt))]
        hn = hs2.tapered_curve(pts, [1.0, 0.8, 0.5, 0.06], bevel_depth=0.17, name="spike%d" % i)
        hn.location = (cx, 0, cz)
        hn.rotation_euler = (0, math.radians(-22), 0)
        m = hs2.curve_to_mesh(hn)
        m.location = (cx, 0, cz)
        m.rotation_euler = (0, math.radians(-22), 0)
        hs2.mirror_x(m)
        hs2.bake(m, 50)
        tag(m, "Dark")
    # keep the (unused) ring out of the model
    bpy.data.objects.remove(ring)


# =============================================================== helmet
ZC = 3.0  # helm centre height
H = 1.05


def helm():
    W, D = 1.3, 1.16

    def row(z):
        t = (z - ZC) / H
        s = math.sqrt(max(0.0, 1 - t * t)) if t > -0.78 else 0.6
        # jaw: a little narrower low down
        return s

    zs = [lerp(ZC - 0.92 * H, ZC + 0.98 * H, i / 27) for i in range(28)]
    rows = []
    for z in zs:
        t = (z - ZC) / H
        s = math.sqrt(max(0.0, 1 - t * t * 0.97))
        low = 1.0 - 0.16 * sstep(0.1, -0.9, t)
        rows.append((z, W * s * low, D * s * low, D * s * low * 0.96, 0, 0.04))
    sk = hs2.superellipse_shell(rows, seg=72, p=2.55, name="skull", cap_top=True)

    def beak(c):
        if c.y < 0:
            f = sstep(ZC + 0.45, ZC - 0.9, c.z)
            c.y -= 0.62 * f * max(0.0, 1 - abs(c.x) / 1.15) ** 1.25
        return c

    hs2.displace(sk, beak)
    hs2.solid(sk, 0.13, offset=-1)
    # eye slits (two narrow openings beside a central nasal bar), cheek vents, breathing slots
    cutters = []
    for sx in (-1, 1):
        cutters.append(hs2.cut_box(sk, (sx * 0.62, -1.4, ZC + 0.1), (0.62, 1.2, 0.15), (0, 0, math.radians(-8 * sx))))
        for i in range(4):
            cutters.append(hs2.cut_box(sk, (sx * (0.35 + 0.2 * i), -1.7, ZC - 0.5), (0.07, 1.2, 0.34)))
    hs2.bevel(sk, 0.04, 3, 32)
    hs2.bake(sk, 36)
    for c in cutters:
        bpy.data.objects.remove(c)
    tag(sk, "Plate")
    # dark lining so the slits are dark
    lin_rows = [(z, W * 0.9 * math.sqrt(max(0, 1 - ((z - ZC) / H) ** 2 * 0.97)) + 0.01, D * 0.88 * math.sqrt(max(0, 1 - ((z - ZC) / H) ** 2 * 0.97)) + 0.01, D * 0.88 * math.sqrt(max(0, 1 - ((z - ZC) / H) ** 2 * 0.97)) + 0.01, 0, 0.04) for z in zs]
    li = hs2.superellipse_shell(lin_rows, seg=40, p=2.5, name="lining", cap_top=True)
    tag(li, "Dark")
    # brow flange: a heavy bevelled bar arcing over the slits, overhanging
    pts = []
    for i in range(11):
        x = lerp(-1.36, 1.36, i / 10)
        y = -(D * 0.99) * math.sqrt(max(0.0, 1 - (x / (W * 1.0)) ** 2)) - 0.2 - 0.12 * (1 - abs(x) / 1.36)
        pts.append((x, y + 0.04, ZC + 0.34))
    br = hs2.tapered_curve(pts, [1.0] * 11, bevel_depth=0.17, name="brow")
    brm = hs2.curve_to_mesh(br)
    hs2.bake(brm, 50)
    tag(brm, "Trim")
    # nasal bar
    bm = hs2.bmesh.new()
    hs2.bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = (v.co.x * 0.16, v.co.y * 0.1, v.co.z * 0.95)
    nb = hs2.obj_from_bm(bm, "nasal")
    nb.location = (0, -1.52, ZC - 0.35)
    nb.rotation_euler = (math.radians(14), 0, 0)
    hs2.bevel(nb, 0.03, 2, 35)
    hs2.bake(nb, 40)
    tag(nb, "Trim")
    # neck guard: three stacked lames wider than the neck
    for k in range(3):
        z = ZC - 0.92 * H - 0.02 - 0.17 * k
        rr = 1.0 + 0.2 * k
        ng = hs2.superellipse_shell([(z - 0.22, rr * 1.1, rr * 0.95, rr * 0.95, 0, 0), (z + 0.1, rr * 0.95, rr * 0.82, rr * 0.82, 0, 0)], seg=48, p=2.4, name="neck%d" % k)
        hs2.solid(ng, 0.07)
        hs2.bevel(ng, 0.03, 2, 35)
        hs2.bake(ng, 36)
        tag(ng, "Plate" if k != 1 else "Dark")
    # crest: a tall notched blade over the dome (profile slab with thickness and bevel)
    bm = hs2.bmesh.new()
    prof = [(-1.15, ZC + 0.7), (-0.8, ZC + 1.25), (-0.5, ZC + 1.1), (-0.28, ZC + 1.65), (0.0, ZC + 1.35), (0.3, ZC + 1.95), (0.6, ZC + 1.5), (0.95, ZC + 1.35), (1.3, ZC + 0.7), (0.5, ZC + 0.95), (-0.5, ZC + 0.95)]
    vs = [bm.verts.new((0, y, z)) for y, z in prof]
    bm.faces.new(vs)
    cr = hs2.obj_from_bm(bm, "crest")
    hs2.solid(cr, 0.26, offset=0)
    hs2.bevel(cr, 0.05, 3, 35)
    hs2.bake(cr, 40)
    tag(cr, "Dark")
    # two big swept-back horns from the temples: smooth tapered curves (the helmet's identity)
    for sx in (1, -1):
        p0 = V((sx * 1.3, -0.05, ZC + 0.35))
        pts = [p0, p0 + V((sx * 0.6, 0.2, 0.35)), p0 + V((sx * 1.2, 0.8, 0.8)), p0 + V((sx * 1.45, 1.6, 1.15)), p0 + V((sx * 1.3, 2.4, 1.1))]
        hn = hs2.tapered_curve(pts, [1.0, 0.95, 0.75, 0.45, 0.05], bevel_depth=0.34, name="horn")
        hm = hs2.curve_to_mesh(hn)
        hs2.bake(hm, 50)
        tag(hm, "Trim")
    # steel studs along the brow
    for i in range(7):
        x = lerp(-1.1, 1.1, i / 6)
        bm = hs2.bmesh.new()
        hs2.bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=0.07)
        st = hs2.obj_from_bm(bm, "stud")
        st.location = (x, -(D * 0.99) * math.sqrt(max(0.0, 1 - (x / W) ** 2)) - 0.36 - 0.1 * (1 - abs(x) / 1.1), ZC + 0.5)
        hs2.bake(st, 60)
        tag(st, "Gold")


chest()
pauldrons()
helm()

# =============================================================== materials (restrained: plain colours, modest metal, no wear maps)
MAT = {
    "Plate": ((0.075, 0.085, 0.105, 1), 0.85, 0.36),
    "Dark": ((0.022, 0.024, 0.032, 1), 0.7, 0.45),
    "Trim": ((0.36, 0.38, 0.43, 1), 1.0, 0.24),
    "Gold": ((0.55, 0.38, 0.1, 1), 1.0, 0.3),
    "Blue": ((0.03, 0.1, 0.55, 1), 0.2, 0.28),
    "Cloth": ((0.018, 0.028, 0.09, 1), 0.0, 0.85),
}
for kind, objs in parts.items():
    col, met, rough = MAT[kind]
    m = bpy.data.materials.new(kind)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = col
    b.inputs["Metallic"].default_value = met
    b.inputs["Roughness"].default_value = rough
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(m)

everything = [o for objs in parts.values() for o in objs]
tris = 0
for o in everything:
    tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
print("PROOF objects", len(everything), "tris", tris)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(EXPORT, "knight_upper_proof.blend"))

# =============================================================== neutral studio render
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
sc.render.resolution_x = sc.render.resolution_y = RES
sc.render.film_transparent = False
sc.view_settings.view_transform = "Standard"
try:
    sc.eevee.taa_render_samples = 64
except Exception:
    pass
w = bpy.data.worlds.new("w")
sc.world = w
w.use_nodes = True
wn = w.node_tree
wn.nodes.clear()
outn = wn.nodes.new("ShaderNodeOutputWorld")
bg = wn.nodes.new("ShaderNodeBackground")
grad = wn.nodes.new("ShaderNodeTexGradient")
mp = wn.nodes.new("ShaderNodeMapping")
tc = wn.nodes.new("ShaderNodeTexCoord")
ramp = wn.nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].color = (0.30, 0.31, 0.33, 1)
ramp.color_ramp.elements[1].color = (0.9, 0.92, 0.95, 1)
mp.inputs["Rotation"].default_value = (0, math.radians(90), 0)
wn.links.new(tc.outputs["Generated"], mp.inputs["Vector"])
wn.links.new(mp.outputs["Vector"], grad.inputs["Vector"])
wn.links.new(grad.outputs["Fac"], ramp.inputs["Fac"])
wn.links.new(ramp.outputs["Color"], bg.inputs["Color"])
bg.inputs["Strength"].default_value = 0.9
wn.links.new(bg.outputs["Background"], outn.inputs["Surface"])
for loc, en, rot in (((6, -9, 10), 2.6, (math.radians(52), 0, math.radians(32))), ((-8, -4, 6), 1.0, (math.radians(70), 0, math.radians(-55))), ((0, 9, 7), 1.4, (math.radians(125), 0, math.radians(180)))):
    bpy.ops.object.light_add(type="SUN", location=loc)
    L = bpy.context.active_object
    L.data.energy, L.rotation_euler = en, rot
# a big soft white panel in front/above so polished metal has something to reflect
bpy.ops.mesh.primitive_plane_add(size=14, location=(0, -9, 8))
pn = bpy.context.active_object
pn.rotation_euler = (math.radians(-40), 0, 0)
pm = bpy.data.materials.new("panel")
pm.use_nodes = True
nt = pm.node_tree
nt.nodes.clear()
em = nt.nodes.new("ShaderNodeEmission")
em.inputs["Strength"].default_value = 3.0
nto = nt.nodes.new("ShaderNodeOutputMaterial")
nt.links.new(em.outputs["Emission"], nto.inputs["Surface"])
pn.data.materials.append(pm)
pn.visible_camera = False
bpy.ops.object.camera_add()
cam = bpy.context.active_object
sc.camera = cam


def shoot(name, az, el, tgt, dist, lens=70, clay=False):
    a, e = math.radians(az), math.radians(el)
    d = V((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    cam.location = V(tgt) + d * dist
    cam.data.lens = lens
    cam.rotation_euler = (V(tgt) - cam.location).to_track_quat("-Z", "Y").to_euler()
    if clay:
        cm = bpy.data.materials.new("clay")
        cm.use_nodes = True
        bb = next(n for n in cm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bb.inputs["Base Color"].default_value = (0.55, 0.56, 0.6, 1)
        bb.inputs["Roughness"].default_value = 0.7
        bpy.context.view_layer.material_override = cm
    else:
        bpy.context.view_layer.material_override = None
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)


# upper body spans x -3.4..3.4, z 0..5.5 (helmet horns to ~5.6)
CT = (0, 0, 2.55)
for nm, az, el, dist in (("front", 0, 5, 19), ("tq", -35, 12, 19), ("back", 180, 8, 19), ("side", -90, 6, 19)):
    shoot("proof_" + nm, az, el, CT, dist)
shoot("proof_clay_front", 0, 5, CT, 19, clay=True)
shoot("proof_clay_tq", -35, 12, CT, 19, clay=True)
shoot("proof_helm", -28, 8, (0, -0.2, 3.1), 11, 60)
shoot("proof_shoulder", -42, 14, (2.2, 0, 1.9), 11, 60)
shoot("proof_chest", -22, 8, (0, -0.4, 1.2), 11, 60)
# export model files
bpy.ops.object.select_all(action="DESELECT")
for o in everything:
    o.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, "knight_upper_proof.fbx"), use_selection=True, axis_forward="-Z", axis_up="Y", global_scale=0.01, apply_unit_scale=True, bake_space_transform=False, mesh_smooth_type="FACE", object_types={"MESH"})
print("PROOF done")
