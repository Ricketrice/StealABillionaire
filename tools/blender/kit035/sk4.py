# kit035.sk4 - Shield Knight v4: the ART-DIRECTION RESET (owner 2026-10-16: v3 rejected as a cheerful cartoon knight).
# An intimidating, heavily armoured fantasy knight: closed visored armet with a beaked faceplate and a narrow eye slit, a stack of neck lames,
# massive four-lame pauldrons with swept fins, a gothic keeled breastplate with back plate, segmented arms, articulated waist and tassets,
# layered greaves and heavy sabatons, a thick heraldic kite shield and a longsword. Dark gunmetal as the base material; blue enamel and aged gold
# only as restrained faction accents. Surface detail (engraving, wear, crevices, polish) comes from baked PBR maps (kit035.pbr), not flat colour.
# Original design: nothing here copies the reference armour layout, markings or identity.
import math

from . import body, geo, hs
from .geo import M, V, box, ellipsoid, lathe, tube, poly_slab, ellipse_slab, merge, cyl, cyl_between, spike, star, profile_slab, dome, loft
from .hs import Prof, band, patch, shell, smooth, lerp, stud, curve_z, frame_slab
from .char import Char
from .body import jp, HERO

FRONT = -90.0
K = HERO
AX = K.arm_x
LX = K.leg_x
HY0 = K.neck - 0.02
HH = 1.55
PS = 1.0  # pauldron size factor (sk5 raises it)


def A(k):
    return HY0 + HH * k


def rel(a):
    return a - FRONT


TORSO = Prof([(2.75, 1.0, 0.55, 0.55), (3.1, 0.88, 0.5, 0.5), (3.55, 1.12, 0.66, 0.56), (4.0, 1.3, 0.78, 0.6), (4.45, 1.32, 0.7, 0.56), (4.74, 0.98, 0.5, 0.46)], p=2.8)
HIPS = Prof([(2.0, 1.28, 0.7, 0.66), (2.4, 1.2, 0.66, 0.64), (2.85, 1.04, 0.58, 0.57), (3.2, 0.9, 0.52, 0.52)], p=2.6)


def mirror_add(ch, group_base, kind, m_right, **kw):
    ch.add("Right" + group_base, kind, m_right, **kw)
    ch.add("Left" + group_base, kind, m_right.copy().mirror_x(), **kw)


def shield_knight_v4():
    body.set_skel(HERO)
    ch = Char("ShieldKnight", "Epic", "Knight's Keep", scale=0.95)
    ch.sig_label = "shield bash"
    ch.sa = 32.0
    ch.rig = HERO.data()
    # material KINDS (the PBR bake turns each into real maps); the colour here is only the flat-preview / fallback colour
    ch.colours(
        Plate=("#262A33", "Metal", 0.4, 1.0), Dark=("#101217", "Metal", 0.5, 1.0), Trim=("#4C525E", "Metal", 0.3, 1.0), Gold=("#8B6B2C", "Metal", 0.35, 1.0),
        Blue=("#1D3C8E", "SmoothPlastic", 0.5, 0.0), Cloth=("#14172A", "Fabric", 0.9, 0.0), Leather=("#2B1E17", "SmoothPlastic", 0.7, 0.0),
        Blade=("#B8BFCC", "Metal", 0.22, 1.0), Glow=("#9CC6FF", "Neon", 0.2, 0.0),
    )
    helm(ch)
    torso(ch)
    waist(ch)
    pauldrons(ch)
    arms(ch)
    legs(ch)
    cloth(ch)
    shield_and_sword(ch)
    animate(ch)
    for k in list(ch.parts):
        ch.parts[k] = hs.simplify(ch.parts[k], 4.0)
    return ch


# ------------------------------------------------------------------ helm
def helm(ch):
    hx, hz = 0.98, 0.92
    # dark padded lining seen through the eye slit and between plates
    ch.add("Helmet", "Cloth", hs.ring_loft(Prof([(A(0.04), hx * 0.62, hz * 0.6, hz * 0.6), (A(0.5), hx * 0.84, hz * 0.82, hz * 0.82), (A(0.9), hx * 0.8, hz * 0.8, hz * 0.8)], p=2.4), A(0.04), A(0.9), 4, 10, 0.0, caps=True), on="Head", region="head")
    # skull dome (closed all round) + side / back shell that flares into cheek and ear protection
    cap = hs.cap_lame(hx, 0.8, hz, 0, 82, 0, 360, 0.1, 12, 4)
    ch.add("Helmet", "Plate", cap.move(0, A(0.64) - 0.8 * math.cos(math.radians(82)), 0))
    low = Prof([(A(0.1), hx * 0.66, hz * 0.62, hz * 0.66), (A(0.35), hx * 0.92, hz * 0.88, hz * 0.92), (A(0.64), hx, hz, hz)], p=2.6)
    ch.add("Helmet", "Plate", band(low, FRONT + 66, FRONT + 294, A(0.1), A(0.64), lambda a, v: 0.12 * (1 - v) ** 2, thick=0.1, nu=8, nv=3, chamfer=0.02))
    # beaked faceplate (pointed section, p < 2): narrow gap above it is the eye slit
    fp = Prof([(A(0.04), 0.3, 0.7, 0.5), (A(0.25), 0.54, 0.9, 0.62), (A(0.55), 0.76, 1.0, 0.76)], p=1.5)
    ch.add("Helmet", "Plate", band(fp, FRONT - 76, FRONT + 76, A(0.04), A(0.55), 0.0, thick=0.1, nu=8, nv=3, chamfer=0.025))
    ch.add("Helmet", "Trim", poly_slab([(-0.05, 0.0), (0.05, 0.0), (0.04, 1.0), (-0.04, 1.0)], 0.07).rot(0, 0, 0).move(0, A(0.1), -1.0).rot(14, 0, 0, (0, A(0.1), -0.9)))  # raised nasal keel
    # brow flange overhanging the slit, with rivets
    brow = Prof([(A(0.62), hx, hz, hz), (A(0.74), hx, hz, hz)], p=2.4)
    ch.add("Helmet", "Trim", band(brow, FRONT - 80, FRONT + 80, A(0.6), A(0.73), lambda a, v: 0.12 + 0.12 * (1 - abs(rel(a)) / 80) * (1 - v), thick=0.1, nu=8, nv=1, chamfer=0.02))
    ch.add("Helmet", "Gold", merge([stud((math.sin(math.radians(t)) * (hx + 0.12), A(0.7), -math.cos(math.radians(t)) * (hz + 0.12)), 0.05, 0.05) for t in (-60, -38, -16, 16, 38, 60)]))
    # stacked neck lames (substantial neck protection) and a rear neck guard
    for k in range(3):
        y = A(0.02) - 0.15 * k
        pr = Prof([(y - 0.17, 0.66 + 0.16 * k, 0.56 + 0.12 * k, 0.56 + 0.12 * k), (y, 0.62 + 0.15 * k, 0.52 + 0.12 * k, 0.52 + 0.12 * k)], p=2.4)
        ch.add("UpperTorso", "Plate" if k != 1 else "Dark", band(pr, 0, 360, y - 0.17, y, 0.05, thick=0.07, nu=10, nv=1, chamfer=0.012), on="UpperTorso")
    # crest: a notched blade ridge over the dome, and two swept-back fins
    y0 = A(0.64) + 0.68
    comb = [(-0.9, y0 - 0.3), (-0.66, y0 + 0.2), (-0.5, y0 + 0.12), (-0.3, y0 + 0.5), (-0.1, y0 + 0.36), (0.14, y0 + 0.72), (0.36, y0 + 0.52), (0.62, y0 + 0.4), (0.92, y0 - 0.2), (0.4, y0 - 0.12), (-0.4, y0 - 0.12)]
    ch.add("Helmet", "Dark", profile_slab(comb, 0.2))


# ------------------------------------------------------------------ torso
def torso(ch):
    ch.add("UpperTorso", "Dark", hs.ring_loft(TORSO, 3.1, 4.72, 4, 8, 0.0), on="UpperTorso")

    def hi(a):
        return 4.76 - 0.36 * smooth(52, 100, abs(rel(a)))

    def lo(a):
        return 3.62 - 0.4 * (1 - abs(rel(a)) / 100)

    def off(a, v):
        r = abs(rel(a))
        return 0.08 + 0.15 * max(0.0, 1 - r / 22.0) + 0.05 * math.exp(-((r - 50) / 20.0) ** 2) + 0.02 * v

    # gothic keeled breastplate in two overlapping plates (upper bib and lower plate) with a raised keel and flared edge
    ch.add("UpperTorso", "Plate", band(TORSO, FRONT - 100, FRONT + 100, lo, lambda a: 4.4 - 0.2 * smooth(52, 100, abs(rel(a))), off, thick=0.1, nu=10, nv=2, chamfer=0.025), on="UpperTorso")
    ch.add("UpperTorso", "Plate", band(TORSO, FRONT - 100, FRONT + 100, lambda a: 4.22 - 0.1 * smooth(40, 100, abs(rel(a))), hi, lambda a, v: off(a, 1.0) + 0.05, thick=0.09, nu=10, nv=1, chamfer=0.02))
    ch.add("UpperTorso", "Trim", band(TORSO, FRONT - 100, FRONT + 100, lambda a: 4.18 - 0.1 * smooth(40, 100, abs(rel(a))), lambda a: 4.24 - 0.1 * smooth(40, 100, abs(rel(a))), lambda a, v: off(a, 1.0) + 0.075, thick=0.05, nu=10, nv=1))
    ch.add("UpperTorso", "Trim", band(TORSO, FRONT - 3, FRONT + 3, lambda a: lo(a) + 0.04, 4.2, lambda a, v: off(a, 0.5) + 0.04, thick=0.04, nu=1, nv=3))
    # two articulated belly lames (V cut) over the waist
    for k in range(2):
        top = 3.66 - 0.2 * k
        ch.add("UpperTorso", "Plate" if k == 0 else "Dark", band(TORSO, FRONT - 100, FRONT + 100, lambda a, t=top: t - 0.3 - 0.12 * (1 - abs(rel(a)) / 100), lambda a, t=top: t + 0.05, lambda a, v, k=k: 0.08 + 0.03 * k + 0.06 * max(0.0, 1 - abs(rel(a)) / 40), thick=0.08, nu=8, nv=1, chamfer=0.015))
    # back: spine-ridged plate and lames (the back is visible: no cape)
    ch.add("UpperTorso", "Plate", band(TORSO, 90 - 90, 90 + 90, lambda a: 3.55, lambda a: 4.76 - 0.34 * smooth(50, 90, abs(a - 90)), lambda a, v: 0.08 + 0.1 * max(0.0, 1 - abs(a - 90) / 20.0), thick=0.09, nu=8, nv=3, chamfer=0.02))
    for k in range(3):
        t = 3.7 - 0.2 * k
        ch.add("UpperTorso", "Dark" if k % 2 else "Plate", band(TORSO, 90 - 90, 90 + 90, t - 0.3, t + 0.06, 0.08 + 0.025 * k, thick=0.07, nu=8, nv=1, chamfer=0.012))


def waist(ch):
    ch.add("LowerTorso", "Dark", hs.ring_loft(HIPS, 2.75, 3.2, 3, 8, 0.0), on="LowerTorso")
    # three articulated fauld rings around the waist, then two rows of tassets
    for k in range(3):
        y1 = 3.2 - 0.15 * k
        pr = Prof([(y1 - 0.2, 1.06 + 0.07 * k, 0.6 + 0.05 * k, 0.58 + 0.05 * k), (y1, 0.98 + 0.07 * k, 0.55 + 0.05 * k, 0.54 + 0.05 * k)], p=2.6)
        ch.add("LowerTorso", "Plate" if k != 1 else "Dark", band(pr, 0, 360, y1 - 0.2, y1, 0.05 + 0.02 * k, thick=0.07, nu=12, nv=1, chamfer=0.012))
    ch.add("LowerTorso", "Leather", band(HIPS, 0, 360, 3.1, 3.3, 0.1, thick=0.05, nu=10, nv=1))
    ch.add("LowerTorso", "Trim", box(0.5, 0.36, 0.1, bev=0.03, seg=1, c=(0, 3.2, -0.74)))
    ch.add("LowerTorso", "Gold", merge([stud((x, 3.2, -0.76), 0.06, 0.06) for x in (-0.22, 0.22)]))
    # outer row of tassets (long) over a shorter inner row, alternating plate / dark
    for row, (angs, ln, off0) in enumerate((((-90 + 14, -90 - 14, -90 + 42, -90 - 42, -90 + 70, -90 - 70), 0.72, 0.1), ((-90, -90 + 28, -90 - 28, -90 + 56, -90 - 56), 0.5, 0.16))):
        for k, ang in enumerate(angs):
            kind = "Plate" if (k + row) % 2 == 0 else "Dark"
            ch.add("LowerTorso", kind, band(HIPS, ang - 14, ang + 14, lambda a, ln=ln, ang=ang: 2.96 - ln + 0.1 * (1 - abs(a - ang) / 14), 2.96, lambda a, v, o=off0: o + 0.07 * (1 - v), thick=0.06, nu=2, nv=1, chamfer=0.012))
    ch.add("LowerTorso", "Blue", band(HIPS, -90 - 8, -90 + 8, 2.5, 2.8, 0.22, thick=0.03, nu=1, nv=1))  # a blue enamel inlay on the centre tasset


# ------------------------------------------------------------------ pauldrons
def pauldrons(ch):
    """Massive four-lame shoulder guards, each lame stepped out with a flared lip, a raised ridge, rivet rows and two swept fins (original shapes)."""
    cx, cy, tilt = AX + 0.14, K.shoulder_y + 0.12, 14
    meshes = []
    for kind, t0, t1, rr, fl in (("Plate", 0, 34, 1.0, 0.0), ("Dark", 28, 52, 1.05, 0.04), ("Plate", 46, 68, 1.1, 0.07), ("Dark", 62, 88, 1.16, 0.1)):
        meshes.append((kind, hs.cap_lame(1.05 * rr, 0.82 * rr, 0.96 * rr, t0, t1, -150, 150, 0.08, 8, 2, flare=fl)))
    meshes.append(("Trim", hs.cap_lame(1.08, 0.84, 0.99, 33, 37, -150, 150, 0.06, 8, 1)))
    crest = [(-0.95, 0.12), (-0.78, 0.7), (-0.35, 1.18), (0.2, 1.26), (0.7, 0.95), (0.98, 0.15), (0.55, 0.6), (0.05, 0.86), (-0.45, 0.62)]
    meshes.append(("Dark", profile_slab(crest, 0.16).move(0.1, 0, 0)))
    studs = merge([stud((math.sin(math.radians(a)) * 0.8, 0.5 - 0.1 * (abs(a) / 60), -math.cos(math.radians(a)) * 0.9), 0.05, 0.05).rot(0, 0, 0) for a in (-60, -30, 0, 30, 60)])
    meshes.append(("Gold", studs))
    for kind, m in meshes:
        mirror_add(ch, "UpperArm", kind, m.copy().scale(PS).rot(0, 0, -tilt).move(cx, cy, 0))


# ------------------------------------------------------------------ arms
def arms(ch):
    for side in (1, -1):
        pre = "Right" if side > 0 else "Left"
        X = AX

        def mk(m):
            return m if side > 0 else m.mirror_x()

        ch.add(pre + "UpperArm", "Cloth", mk(hs.limb(X, 0, [(4.7, 0.4, 0.38), (4.1, 0.39, 0.38), (3.45, 0.33, 0.33)], seg=6)), on=pre + "UpperArm")
        ch.add(pre + "LowerArm", "Cloth", mk(hs.limb(X, 0, [(3.55, 0.33, 0.33), (3.05, 0.3, 0.31), (2.55, 0.27, 0.28)], seg=6)), on=pre + "LowerArm")
        # segmented rerebrace: two overlapping lames, then the couter (elbow cop) with a pointed rear fan
        ch.add(pre + "UpperArm", "Plate", mk(hs.shell([(4.25, 0.57, 0.55), (3.95, 0.55, 0.52), (3.72, 0.51, 0.49)], -150, 150, 0.07, seg=6, cx=X)))
        ch.add(pre + "UpperArm", "Dark", mk(hs.shell([(3.78, 0.54, 0.52), (3.55, 0.5, 0.48), (3.36, 0.46, 0.44)], -150, 150, 0.07, seg=6, cx=X)))
        ch.add(pre + "LowerArm", "Plate", mk(dome(0.48, 0.4, (0, 0, 0), seg=6, rings=2).rot(90, 0, 0).move(X + 0.04, K.elbow, 0.3)))
        ch.add(pre + "LowerArm", "Trim", mk(poly_slab([(0.0, 0.0), (0.4, 0.2), (0.55, 0.75), (0.0, 0.5), (-0.3, 0.2)], 0.07).rot(0, 90, 0).move(X + 0.32, K.elbow - 0.3, 0.2)))
        # vambrace: three articulated bands flaring toward the wrist
        for k, (y1, y0, rr) in enumerate(((3.4, 3.08, 0.43), (3.12, 2.82, 0.41), (2.86, 2.58, 0.4))):
            ch.add(pre + "LowerArm", "Plate" if k != 1 else "Dark", mk(hs.shell([(y1, rr, rr - 0.02), (y0, rr + 0.02 * k, rr)], -150, 150, 0.06, seg=6, cx=X, off=0.015 * k)))
        # gauntlet: back-of-hand plate, a knuckle guard, four finger lames, a thumb
        palm = box(0.5, 0.34, 0.5, bev=0.08, seg=1, c=(X, 2.42, 0.0))
        fing = merge([box(0.12, 0.3, 0.1, bev=0.02, seg=1, c=(X - 0.2 + 0.133 * k, 2.2, -0.3)) for k in range(4)])
        ch.add(pre + "Hand", "Dark", mk(merge([palm, fing, box(0.14, 0.28, 0.16, c=(X - 0.3, 2.34, -0.2))])), on=pre + "Hand")
        ch.add(pre + "Hand", "Plate", mk(box(0.56, 0.12, 0.24, bev=0.03, seg=1, c=(X, 2.56, -0.28))))


# ------------------------------------------------------------------ legs
def legs(ch):
    for side in (1, -1):
        pre = "Right" if side > 0 else "Left"
        X = LX

        def mk(m):
            return m if side > 0 else m.mirror_x()

        ch.add(pre + "UpperLeg", "Cloth", mk(hs.limb(X, 0, [(2.8, 0.46, 0.48), (2.2, 0.46, 0.46), (1.5, 0.38, 0.4)], seg=6)), on=pre + "UpperLeg")
        ch.add(pre + "LowerLeg", "Cloth", mk(hs.limb(X, 0, [(1.6, 0.37, 0.39), (1.0, 0.4, 0.42), (0.45, 0.28, 0.3)], seg=6)), on=pre + "LowerLeg")
        # cuisse: two overlapping plates with a raised centre ridge and an outer flange
        ch.add(pre + "UpperLeg", "Plate", mk(hs.shell([(2.5, 0.58, 0.6), (2.2, 0.57, 0.59), (1.95, 0.54, 0.56)], FRONT - 108, FRONT + 108, 0.07, seg=6, cx=X, p=2.8)))
        ch.add(pre + "UpperLeg", "Dark", mk(hs.shell([(2.05, 0.56, 0.58), (1.8, 0.5, 0.52), (1.6, 0.45, 0.47)], FRONT - 104, FRONT + 104, 0.07, seg=6, cx=X, p=2.8)))
        ch.add(pre + "UpperLeg", "Trim", mk(poly_slab([(0.0, 0.0), (0.1, 0.18), (0.1, 0.62), (0.0, 0.78), (-0.1, 0.62), (-0.1, 0.18)], 0.08).rot(-8, 0, 0).move(X, 1.8, -0.6)))
        ch.add(pre + "UpperLeg", "Plate", mk(poly_slab([(0.0, 0.0), (0.42, -0.08), (0.5, -0.5), (0.0, -0.7)], 0.07).rot(0, 90, 0).move(X + 0.54, 2.6, 0.0)))
        # poleyn: faceted knee cop with fan lames above and below, and a side wing
        ch.add(pre + "LowerLeg", "Plate", mk(dome(0.48, 0.36, (0, 0, 0), seg=6, rings=2).rot(-90, 0, 0).move(X, K.knee, -0.4)))
        ch.add(pre + "LowerLeg", "Dark", mk(hs.shell([(K.knee + 0.22, 0.46, 0.5), (K.knee + 0.1, 0.5, 0.54)], FRONT - 110, FRONT + 110, 0.05, seg=6, cx=X, p=2.8)))
        ch.add(pre + "LowerLeg", "Dark", mk(hs.shell([(K.knee - 0.1, 0.5, 0.52), (K.knee - 0.24, 0.46, 0.48)], FRONT - 110, FRONT + 110, 0.05, seg=6, cx=X, p=2.8)))
        ch.add(pre + "LowerLeg", "Trim", mk(poly_slab([(0.0, 0.0), (0.5, 0.2), (0.14, 0.7), (-0.3, 0.26)], 0.08).rot(0, 90, 0).move(X + 0.46, K.knee - 0.3, -0.08)))
        # greaves: shin plate with a ridge, calf shell behind, ankle cuff
        ch.add(pre + "LowerLeg", "Plate", mk(hs.shell([(1.2, 0.45, 0.47), (0.9, 0.5, 0.52), (0.68, 0.45, 0.47), (0.52, 0.33, 0.36)], FRONT - 120, FRONT + 120, 0.06, seg=6, cx=X, p=2.8)))
        ch.add(pre + "LowerLeg", "Trim", mk(poly_slab([(-0.09, 0.0), (0.09, 0.0), (0.07, 0.7), (0.0, 0.8), (-0.07, 0.7)], 0.08).move(X, 0.5, -0.56)))
        ch.add(pre + "LowerLeg", "Dark", mk(hs.shell([(1.2, 0.5, 0.52), (0.75, 0.46, 0.48)], FRONT + 125, FRONT + 235, 0.06, seg=4, cx=X, p=2.8)))
        ch.add(pre + "LowerLeg", "Trim", mk(hs.shell([(0.62, 0.36, 0.39), (0.5, 0.35, 0.38)], 0, 360, 0.04, seg=8, cx=X, off=0.025)))
        # sabaton: heavy arched boot, three toe lames, heel plate
        rings = [[(X + w, 0.0, z), (X + w * 0.95, 0.3, z), (X, h, z), (X - w * 0.95, 0.3, z), (X - w, 0.0, z)] for z, w, h in ((-1.2, 0.1, 0.22), (-0.7, 0.36, 0.34), (-0.15, 0.48, 0.52), (0.5, 0.46, 0.46))]
        ch.add(pre + "Foot", "Plate", mk(loft(rings, caps=(True, True), closed_ring=True)), on=pre + "Foot")
        for k in range(3):
            ch.add(pre + "Foot", "Dark", mk(box(0.82 - 0.2 * k, 0.1, 0.2, bev=0.02, seg=1, c=(X, 0.52 - 0.1 * k, -0.15 - 0.28 * k))))
        ch.add(pre + "Foot", "Trim", mk(box(0.54, 0.34, 0.1, bev=0.02, seg=1, c=(X, 0.25, 0.55))))


# ------------------------------------------------------------------ cloth: a long tabard front and a short rear sash (dark cloth, blue lining)
def cloth(ch):
    def tab(u, v):
        w = lerp(0.4, 0.34, v)
        y = lerp(2.9, 1.5 + 0.28 * (1 - abs(u - 0.5) * 2), v)
        return ((u - 0.5) * 2 * w, y, -0.7 - 0.06 * v + 0.05 * math.sin(u * math.pi * 3) * v)

    ch.add("Tabard", "Cloth", patch(tab, 4, 4, 0.04, flip=True, inside=lambda p: (p[0], p[1], 0.0)), on="LowerTorso", region="static")
    ch.add("Tabard", "Blue", patch(lambda u, v: ((u - 0.5) * 0.14, 2.8 - 1.2 * v, -0.76 - 0.06 * v), 1, 3, 0.02, flip=True, inside=lambda p: (p[0], p[1], 0.0)))
    ch.add("Sash", "Cloth", patch(lambda u, v: ((u - 0.5) * 0.9, lerp(2.95, 1.7 + 0.2 * abs(math.sin(u * 9)), v), 0.62 + 0.05 * v + 0.05 * math.sin(u * 8)), 6, 3, 0.04, inside=lambda p: (p[0], p[1], 0.0)), on="LowerTorso", region="static")


# ------------------------------------------------------------------ shield + sword
def shield_and_sword(ch):
    """A thick heraldic kite shield: domed face, a raised spine, two layered rim bands, iron cross-straps with rivets, a relief 'keep gate' device
    (arch between two towers); heraldry colours and wear come from the PBR maps. Plus a longsword."""
    out = [(-1.1, 1.55), (-0.5, 1.75), (0.0, 1.62), (0.5, 1.75), (1.1, 1.55), (1.1, 0.3), (0.62, -0.9), (0.0, -1.85), (-0.62, -0.9), (-1.1, 0.3)]
    sx, sy, sz = -(AX + 0.66), 3.0, -0.78
    sc = lambda k: [(x * k, y * k) for x, y in out]
    body_ = poly_slab(sc(0.94), 0.22)
    curve_z(body_, 0.26, 1.1)
    rim1 = frame_slab(out, sc(0.9), 0.3)
    curve_z(rim1, 0.22, 1.1)
    rim2 = frame_slab(sc(0.9), sc(0.84), 0.24)
    curve_z(rim2, 0.28, 1.1)
    spine = poly_slab([(-0.09, 1.5), (0.09, 1.5), (0.1, -1.7), (-0.1, -1.7)], 0.12)
    curve_z(spine, 0.34, 1.1)
    gate = merge([box(1.0, 1.15, 0.14, c=(0, 0.15, 0)), box(0.34, 1.5, 0.14, c=(-0.7, 0.3, 0)), box(0.34, 1.5, 0.14, c=(0.7, 0.3, 0)), merge([box(0.18, 0.2, 0.14, c=(x, 1.15, 0)) for x in (-0.7, 0.7)])])
    curve_z(gate.move(0, 0, -0.2), 0.3, 1.1)
    archway = poly_slab([(-0.28, -0.4), (0.28, -0.4), (0.28, 0.25), (0.14, 0.5), (0.0, 0.56), (-0.14, 0.5), (-0.28, 0.25)], 0.12).move(0, 0.05, -0.3)
    curve_z(archway, 0.3, 1.1)
    rivets = merge([stud((x, y, -0.36), 0.08, 0.08) for x, y in ((-0.95, 1.35), (0.95, 1.35), (-1.0, 0.2), (1.0, 0.2), (-0.55, -0.95), (0.55, -0.95))])
    curve_z(rivets, 0.2, 1.1)
    boss = dome(0.3, 0.2, (0, 0, 0), seg=8, rings=2).rot(-90, 0, 0).move(0, -0.1, -0.36)
    for kind, m in (("Plate", body_), ("Trim", rim1), ("Dark", rim2), ("Trim", spine), ("Trim", gate), ("Dark", archway), ("Gold", rivets), ("Plate", boss)):
        ch.add("Shield", kind, m.copy().move(sx, sy, sz), on="LeftLowerArm", region="armL")
    ch.add("Shield", "Leather", merge([box(0.2, 0.7, 0.1, c=(0, 0.55, 0.28)), box(0.2, 0.7, 0.1, c=(0, -0.55, 0.28))]).move(sx + 0.42, sy, sz))
    ch.shield_at = (sx, sy, sz)
    # longsword: slim double-edged blade with a fuller, down-curved quillons, wrapped grip, disc pommel
    L, w, t = 2.9, 0.15, 0.055
    secs = [[(-w, 0, 0), (-w * 0.4, 0, -t), (w * 0.4, 0, -t), (w, 0, 0), (w * 0.4, 0, t), (-w * 0.4, 0, t)],
            [(-w * 0.92, L * 0.6, 0), (-w * 0.35, L * 0.6, -t * 0.9), (w * 0.35, L * 0.6, -t * 0.9), (w * 0.92, L * 0.6, 0), (w * 0.35, L * 0.6, t * 0.9), (-w * 0.35, L * 0.6, t * 0.9)],
            [(-w * 0.5, L * 0.94, 0), (-w * 0.2, L * 0.94, -t * 0.5), (w * 0.2, L * 0.94, -t * 0.5), (w * 0.5, L * 0.94, 0), (w * 0.2, L * 0.94, t * 0.5), (-w * 0.2, L * 0.94, t * 0.5)],
            [(0.0, L, 0.0)] * 6]
    blade = loft(secs, caps=(True, False))
    guard = merge([box(0.2, 0.14, 0.2, c=(0, -0.02, 0))] + [tube([(s_ * 0.1, -0.02, 0), (s_ * 0.42, -0.1, 0), (s_ * 0.62, -0.02, 0)], [0.05, 0.045, 0.03], seg=4) for s_ in (-1, 1)])
    grip = cyl(0.065, 0.065, 0.62, (0, -0.7, 0), 6)
    pommel = lathe([(0.0001, -0.92), (0.12, -0.88), (0.14, -0.8), (0.0001, -0.72)], seg=8)
    for kind, m in (("Blade", blade), ("Trim", guard), ("Leather", grip), ("Trim", pommel)):
        ch.add("Sword", kind, m.copy().rot(-32, -30, 0).move(AX + 0.05, K.wrist + 0.1, -0.5), on="RightHand", region="armR")
    ch.add("Flash", "Glow", star(8, 1.1, 0.45, 0.06, c=(sx, sy, sz - 0.72)), on="LeftLowerArm", region="armL")


def animate(ch):
    sx, sy, sz = ch.shield_at
    sg = dict(period=5.0, start=1.2, dur=1.3)
    ch.joint("LshSig", jp("Shoulder", -1), "swing", "X", 22, sig=dict(sg, shape="snap"))
    ch.joint("LbashPush", (0, 0, 0), "push", "Z", -0.9, sig=dict(sg, shape="snap"))
    ch.joint("flashPop", (sx, sy, sz - 0.72), "pop", "X", 1.0, sig=dict(sg, shape="snap"))
    ch.group("Shield", "LeftLowerArm", "armL")
    ch.arm_sig(-1, groups_lower=["Shield"], sh="LshSig", el="LbashPush")
    ch.groups["Flash"]["extra"] = ["LshSig", "LbashPush", "flashPop"]
    ch.finish_anim()
