# kit035.sk3 - Shield Knight v3 (copy of sk2 + the polish pass): the production-quality BENCHMARK for the roster rebuild (replaces the B1 box-and-shell method).
# The R15 rig is only the invisible skeleton (HERO joint heights, same group -> R15 weld mapping); every visible piece is a custom-contoured,
# layered, thick plate that follows a heroic body profile (V-torso, tapered waist, big shoulders, strong thighs), built with kit035.hs.
import math

from . import body, geo, hs, kit
from .geo import M, V, box, frustum, ellipsoid, lathe, tube, poly_slab, ellipse_slab, merge, cyl, cyl_between, spike, star, profile_slab, dome, loft
from .hs import Prof, band, patch, shell, smooth, lerp, stud, curve_z, frame_slab
from .char import Char
from .body import Head, face, jp, HERO

FRONT = -90.0  # the angle that faces the front (-Z)
K = HERO
AX = K.arm_x  # arm centre line x (1.68)
LX = K.leg_x

# heroic torso: (y, half width, front depth, back depth): V taper (shoulders 1.22 -> waist .86), barrel chest
TORSO = Prof([(2.75, 0.98, 0.52, 0.52), (3.1, 0.86, 0.5, 0.5), (3.5, 1.05, 0.62, 0.52), (3.95, 1.2, 0.74, 0.55), (4.4, 1.22, 0.66, 0.5), (4.72, 0.92, 0.48, 0.42)], p=2.8)
HIPS = Prof([(2.05, 1.22, 0.68, 0.64), (2.45, 1.16, 0.64, 0.62), (2.85, 1.02, 0.56, 0.55), (3.2, 0.88, 0.5, 0.5)], p=2.6)


def rel(a):
    return a - FRONT  # degrees from the front centre line


def mirror_add(ch, group_base, colour, m_right, **kw):
    ch.add("Right" + group_base, colour, m_right, **kw)
    ch.add("Left" + group_base, colour, m_right.copy().mirror_x(), **kw)


class ProfHead(Head):
    """A head modelled from a Prof (rounded skull, tapered jaw) instead of a bevelled box; same interface for face() and hats."""

    def __init__(self, hs_=1.08, y0=4.68):
        super().__init__(hs_, 1.0, y0)
        H = self.H
        self.prof = Prof([(y0 + H * k, rx * hs_, zf * hs_, zb * hs_) for k, rx, zf, zb in (
            (0.0, 0.46, 0.4, 0.34), (0.14, 0.64, 0.58, 0.5), (0.4, 0.73, 0.65, 0.6), (0.65, 0.75, 0.64, 0.62), (0.88, 0.68, 0.58, 0.58), (1.0, 0.46, 0.42, 0.44))], p=2.5)

    def zf(self, y):
        return -self.prof.at(y)[1] + 0.0


def shield_knight_v3():
    body.set_skel(HERO)
    ch = Char("ShieldKnight", "Epic", "Knight's Keep", scale=0.95)
    ch.sig_label = "shield bash with a flash"
    ch.sa = 30.0
    ch.sa_group = {"Head": 65.0}
    ch.rig = HERO.data()
    ch.colours(
        Skin="#EBB68E", Under="#141A33", Steel=("#8499C6", "Metal", 0.34, 0.6), SteelDark=("#3A4A7C", "Metal", 0.4, 0.6), Blue="#2457D6",
        BlueDark="#1A3680", Gold=("#EDB93C", "Metal", 0.3, 0.8), Leather="#5A3A28", Glow=("#FFF6B8", "Neon", 0.2, 0), Blush=("#FF9AA2", "SmoothPlastic", 0.6, 0),
    )
    hd = ProfHead(1.28, K.neck - 0.02)
    ch.hd = hd
    ch.add("Head", "Skin", hs.ring_loft(hd.prof, hd.y0, hd.top, 6, 10, 0.0, caps=True))
    ch.add("Head", "Skin", box(0.1, 0.16, 0.12, c=(0, hd.at(0.45), hd.zf(hd.at(0.45)) - 0.04)))  # a small nose
    face(ch, hd, "stern", eye_r=(0.13, 0.16), eye_dx=0.34, mouth_w=0.24, eye_n=12, blush=False, brow_scale=1.15, eye_k=0.5, brow_dy=0.24)
    torso(ch)
    helm(ch, hd)
    pauldrons(ch)
    arms(ch)
    legs(ch)
    cloth(ch)
    shield_and_sword(ch)
    animate(ch)
    for k in list(ch.parts):
        ch.parts[k] = hs.simplify(ch.parts[k], 4.0)
    return ch


def torso(ch):
    ch.add("UpperTorso", "SteelDark", hs.ring_loft(TORSO, 3.1, 4.72, 4, 8, 0.0), on="UpperTorso")
    ch.add("LowerTorso", "SteelDark", hs.ring_loft(HIPS, 2.75, 3.2, 3, 8, 0.0), on="LowerTorso")

    def hi(a):
        return 4.74 - 0.36 * smooth(52, 100, abs(rel(a)))

    def lo(a):
        return 3.58 - 0.34 * (1 - abs(rel(a)) / 100)

    def off(a, v):
        r = abs(rel(a))
        return 0.07 + 0.11 * max(0.0, 1 - r / 24.0) + 0.05 * math.exp(-((r - 48) / 20.0) ** 2) + 0.02 * v

    ch.add("UpperTorso", "Steel", band(TORSO, FRONT - 100, FRONT + 100, lo, lambda a: 4.42 - 0.2 * smooth(52, 100, abs(rel(a))), off, thick=0.1, nu=10, nv=2, chamfer=0.02), on="UpperTorso")
    # blue enamel yoke over the collar bones, gold-edged
    ch.add("UpperTorso", "Blue", band(TORSO, FRONT - 100, FRONT + 100, lambda a: 4.3 - 0.1 * smooth(40, 100, abs(rel(a))), hi, lambda a, v: off(a, 1.0) + 0.04, thick=0.08, nu=10, nv=1, chamfer=0.015))
    ch.add("UpperTorso", "Gold", band(TORSO, FRONT - 100, FRONT + 100, lambda a: 4.24 - 0.1 * smooth(40, 100, abs(rel(a))), lambda a: 4.31 - 0.1 * smooth(40, 100, abs(rel(a))), lambda a, v: off(a, 1.0) + 0.06, thick=0.04, nu=10, nv=1))
    # centre panel in blue enamel (gold-edged) + a large radiant medallion: the chest's focal point at gameplay distance
    ch.add("UpperTorso", "Blue", band(TORSO, FRONT - 34, FRONT + 34, lambda a: lo(a) + 0.04, 4.3, lambda a, v: off(a, 0.5) + 0.05, thick=0.06, nu=4, nv=2, chamfer=0.015))
    for sgn_ in (-1, 1):
        ch.add("UpperTorso", "Gold", band(TORSO, FRONT + sgn_ * 34 - 2.5, FRONT + sgn_ * 34 + 2.5, lambda a: lo(a) + 0.06, 4.3, lambda a, v: off(a, 0.5) + 0.075, thick=0.03, nu=1, nv=2))
    mz = -(0.74 + 0.07 + 0.11 + 0.16)
    ch.add("UpperTorso", "Gold", star(12, 0.62, 0.4, 0.09, c=(0, 3.95, mz)))
    ch.add("UpperTorso", "Blue", ellipse_slab(0.3, 0.3, 0.08, 12, (0, 3.95, mz - 0.05)))
    ch.add("UpperTorso", "Steel", merge([box(0.2, 0.2, 0.07, c=(0, 3.93, mz - 0.1)), merge([box(0.07, 0.07, 0.07, c=(k * 0.1, 4.08, mz - 0.1)) for k in (-1, 1)])]))
    # gold edge lines: the chevron lower edge
    ch.add("UpperTorso", "Gold", band(TORSO, FRONT - 100, FRONT + 100, lambda a: lo(a) - 0.1, lo, lambda a, v: off(a, 0.0) + 0.045, thick=0.05, nu=8, nv=1))
    # belly lames: each steps out a little more; alternate light / dark steel so the layering reads
    for k in range(3):
        top = 3.6 - 0.2 * k
        ch.add("UpperTorso", "SteelDark" if k % 2 else "Steel",
               band(TORSO, FRONT - 100, FRONT + 100, lambda a, t=top: t - 0.28 - 0.1 * (1 - abs(rel(a)) / 100), lambda a, t=top: t + 0.05,
                    lambda a, v, k=k: 0.07 + 0.03 * k + 0.05 * max(0.0, 1 - abs(rel(a)) / 40), thick=0.08, nu=7, nv=1))
    # gorget: three stepped neck rings
    for k, y in enumerate((4.88, 4.7)):
        pr = Prof([(y - 0.14, 0.66 + 0.12 * k, 0.5 + 0.1 * k, 0.5 + 0.1 * k), (y, 0.62 + 0.12 * k, 0.46 + 0.1 * k, 0.46 + 0.1 * k)], p=2.4)
        ch.add("UpperTorso", "Steel" if k == 0 else "SteelDark", band(pr, 0, 360, y - 0.14, y, 0.04, thick=0.06, nu=8, nv=1))
    ch.add("UpperTorso", "Gold", band(Prof([(4.92, 0.64, 0.5, 0.5), (4.96, 0.64, 0.5, 0.5)], p=2.4), 0, 360, 4.92, 4.97, 0.05, thick=0.04, nu=10, nv=1))
    # belt, buckle, studs, a pouch
    ch.add("LowerTorso", "Leather", band(HIPS, 0, 360, 3.0, 3.26, 0.05, thick=0.06, nu=10, nv=1), on="LowerTorso")
    ch.add("LowerTorso", "Gold", box(0.44, 0.32, 0.1, c=(0, 3.13, -0.62)))
    ch.add("LowerTorso", "Leather", box(0.34, 0.4, 0.22, bev=0.05, seg=1, c=(-0.92, 2.9, -0.2)))
    # tassets: a fan of hanging plates, longest at the centre; a blue enamel centre plate, steel / dark steel sides, gold hem lines
    for k, (ang, ln, col) in enumerate(((-90, 0.8, "Blue"), (-90 + 28, 0.72, "Steel"), (-90 - 28, 0.72, "Steel"), (-90 + 56, 0.58, "SteelDark"), (-90 - 56, 0.58, "SteelDark"))):
        ch.add("LowerTorso", col, band(HIPS, ang - 15, ang + 15, lambda a, ln=ln, ang=ang: 3.22 - ln + 0.12 * (1 - abs(a - ang) / 15), 3.22, lambda a, v: 0.05 + 0.08 * (1 - v), thick=0.06, nu=2, nv=1, chamfer=0.01))
        ch.add("LowerTorso", "Gold", band(HIPS, ang - 15, ang + 15, lambda a, ln=ln, ang=ang: 3.22 - ln - 0.07 + 0.12 * (1 - abs(a - ang) / 15), lambda a, ln=ln, ang=ang: 3.22 - ln + 0.02 + 0.12 * (1 - abs(a - ang) / 15), lambda a, v: 0.1, thick=0.03, nu=2, nv=1))


def helm(ch, hd):
    """Open-face knight's helm with ONE strong feature: a tall steel comb carrying a big swept enamel plume. Faceted dome, projecting brow flange,
    flared cheek guards framed in gold, lamed neck guard, rivets. The face stays free."""
    A = hd.at
    top = hd.top
    hsx = hd.hs
    rx, rz = 0.86 * hsx + 0.04, 0.74 * hsx + 0.06
    cap = hs.cap_lame(rx, 0.72 * hsx + 0.25, rz, 0, 74, 0, 360, 0.08, 10, 3)
    ch.add("Helmet", "Steel", cap.move(0, A(0.78) - (0.72 * hsx + 0.25) * math.cos(math.radians(74)), 0), on="Head", region="head")
    low = Prof([(A(0.05), rx * 0.74, rz * 0.7, rz * 0.7), (A(0.3), rx * 0.92, rz * 0.9, rz * 0.9), (A(0.55), rx, rz, rz), (A(0.78), rx, rz, rz)], p=2.6)
    ch.add("Helmet", "Steel", band(low, FRONT + 66, FRONT + 294, A(0.04), A(0.78), lambda a, v: 0.0 + 0.16 * (1 - v) ** 2, thick=0.08, nu=6, nv=2, chamfer=0.02))
    ch.add("Helmet", "Gold", band(low, FRONT + 66, FRONT + 294, A(0.0), A(0.05), lambda a, v: 0.16, thick=0.04, nu=6, nv=1))
    # gold framing the face opening: a strip down each side
    for sgn_ in (-1, 1):
        ang = FRONT + sgn_ * 66
        ch.add("Helmet", "Gold", tube([low.pt(A(k), ang, 0.03 + 0.16 * (1 - (A(k) - A(0.04)) / (A(0.78) - A(0.04))) ** 2) for k in (0.06, 0.3, 0.55, 0.78)], 0.032, seg=4, caps=(False, False)))
    # heavier brow flange, gold edge, nasal bar, rivets
    brow = Prof([(A(0.72), rx, rz, rz), (A(0.86), rx, rz, rz)], p=2.4)
    ch.add("Helmet", "Steel", band(brow, FRONT - 66, FRONT + 66, A(0.7), A(0.86), lambda a, v: 0.13 + 0.12 * (1 - abs(rel(a)) / 66) * (1 - v), thick=0.08, nu=6, nv=1, chamfer=0.015))
    ch.add("Helmet", "Gold", band(brow, FRONT - 66, FRONT + 66, A(0.66), A(0.71), lambda a, v: 0.15 + 0.12 * (1 - abs(rel(a)) / 66), thick=0.05, nu=6, nv=1))
    ch.add("Helmet", "SteelDark", box(0.13, hd.H * 0.42, 0.07, c=(0, A(0.5), -rz - 0.04)))
    ch.add("Helmet", "Gold", merge([stud((x * (rx + 0.03), A(0.5), 0.0), 0.06, 0.06).rot(0, 90 * x, 0, (x * (rx + 0.03), A(0.5), 0.0)) for x in (-1, 1)]))
    for k in range(2):
        y = A(0.16) - 0.14 * k
        pr = Prof([(y - 0.15, rx * (0.72 + 0.04 * k), rz * 0.74, rz * 0.74), (y, rx * (0.74 + 0.04 * k), rz * 0.76, rz * 0.76)], p=2.4)
        ch.add("Helmet", "SteelDark" if k % 2 == 0 else "Steel", band(pr, 12, 168, y - 0.15, y, 0.04 + 0.03 * k, thick=0.05, nu=4, nv=1))
    # the comb: a tall steel blade of a ridge (front to back over the dome) with a gold rail, then the plume rising out of it
    d0 = A(0.78)
    c0 = A(0.74) + 0.72 * hsx + 0.25
    comb = [(-rz - 0.05, d0), (-rz * 0.7, c0 - 0.05), (-0.2, c0 + 0.5), (0.3, c0 + 0.62), (rz * 0.8, c0 + 0.3), (rz + 0.05, d0 + 0.05), (rz * 0.6, c0 - 0.1), (0.0, c0 + 0.3), (-rz * 0.6, c0 - 0.12)]
    ch.add("Helmet", "SteelDark", profile_slab(comb, 0.26), on="Head", region="head")
    ch.add("Helmet", "Gold", tube([(0.0, y_, z_) for z_, y_ in comb[:6]], 0.05, seg=4, caps=(True, True)))
    plume_pts = [(0.0, c0 + 0.35, -0.5), (0.0, c0 + 1.05, -0.2), (0.0, c0 + 1.3, 0.45), (0.0, c0 + 1.0, 1.15), (0.0, c0 + 0.3, 1.65), (0.0, c0 - 0.6, 1.9)]
    ch.add("Plume", "Blue", tube(plume_pts, [0.14, 0.3, 0.4, 0.38, 0.3, 0.1], seg=5, sx=0.6), on="Head", region="head")
    ch.add("Helmet", "Gold", cyl_between((0.0, c0 + 0.2, -0.5), (0.0, c0 + 0.5, -0.35), 0.17, 0.2, 6))


def pauldrons(ch):
    """Layered shoulder guards: three overlapping dome lames (steel, blue enamel, dark steel) with flared lips, a gold rim and ridge, studs, a short fin."""
    cx, cy, tilt = AX + 0.1, K.shoulder_y + 0.08, 16
    meshes = []
    for col, t0, t1, rr, fl in (("Steel", 0, 40, 1.0, 0.0), ("Blue", 34, 64, 1.04, 0.05), ("SteelDark", 58, 88, 1.08, 0.08)):
        meshes.append((col, hs.cap_lame(0.98 * rr, 0.8 * rr, 0.9 * rr, t0, t1, -148, 148, 0.07, 7, 2, flare=fl)))
    meshes.append(("Gold", hs.cap_lame(1.01, 0.82, 0.93, 37, 42.5, -148, 148, 0.05, 7, 1)))
    meshes.append(("Gold", profile_slab([(-0.7, 0.0), (-0.45, 0.6), (0.0, 0.84), (0.45, 0.6), (0.7, 0.0), (0.45, 0.46), (0.0, 0.7), (-0.45, 0.46)], 0.09, bev=0.0).move(0.05, 0, 0)))
    meshes.append(("Gold", merge([stud((0.1, 0.6, -0.7), 0.07, 0.08), stud((0.1, 0.6, 0.7), 0.07, 0.08, axis_z=1)])))
    for col, m in meshes:
        mirror_add(ch, "UpperArm", col, m.copy().rot(0, 0, -tilt).move(cx, cy, 0))


def arms(ch):
    for side in (1, -1):
        pre = "Right" if side > 0 else "Left"
        X = AX

        def mk(m):
            return m if side > 0 else m.mirror_x()

        ch.add(pre + "UpperArm", "BlueDark", mk(hs.limb(X, 0, [(4.7, 0.4, 0.38), (4.1, 0.39, 0.38), (3.45, 0.33, 0.33)], seg=6)), on=pre + "UpperArm")
        ch.add(pre + "LowerArm", "BlueDark", mk(hs.limb(X, 0, [(3.55, 0.33, 0.33), (3.05, 0.3, 0.31), (2.55, 0.27, 0.28)], seg=6)), on=pre + "LowerArm")
        ch.add(pre + "UpperArm", "SteelDark", mk(hs.shell([(4.3, 0.56, 0.54), (3.9, 0.53, 0.5), (3.58, 0.48, 0.46)], -150, 150, 0.06, seg=6, cx=X)))
        ch.add(pre + "UpperArm", "Blue", mk(hs.shell([(4.3, 0.585, 0.565), (3.9, 0.555, 0.525), (3.58, 0.505, 0.485)], -14, 14, 0.05, seg=2, cx=X)))
        cop = dome(0.46, 0.38, (0, 0, 0), seg=6, rings=2).rot(90, 0, 0).move(X + 0.04, K.elbow, 0.28)
        ch.add(pre + "LowerArm", "Steel", mk(cop))
        wing = poly_slab([(0.0, 0.0), (0.34, 0.18), (0.08, 0.46), (-0.2, 0.18)], 0.06).rot(0, 90, 0).move(X + 0.3, K.elbow - 0.25, 0.15)
        ch.add(pre + "LowerArm", "Gold", mk(wing))
        ch.add(pre + "LowerArm", "Steel", mk(hs.shell([(3.4, 0.43, 0.41), (3.0, 0.4, 0.38), (2.72, 0.38, 0.36), (2.58, 0.46, 0.43)], -150, 150, 0.055, seg=6, cx=X)))
        ch.add(pre + "LowerArm", "Gold", mk(hs.shell([(2.6, 0.47, 0.44), (2.64, 0.47, 0.44)], 0, 360, 0.03, seg=8, cx=X, off=0.0)))
        palm = box(0.5, 0.36, 0.5, bev=0.08, seg=1, c=(X, 2.4, 0.0))
        fingers = merge([box(0.13, 0.28, 0.1, c=(X - 0.2 + 0.133 * k, 2.24, -0.3)) for k in range(4)])
        ch.add(pre + "Hand", "SteelDark", mk(merge([palm, fingers])), on=pre + "Hand")
        ch.add(pre + "Hand", "SteelDark", mk(box(0.54, 0.1, 0.22, c=(X, 2.52, -0.28))))


def legs(ch):
    """Strong shape hierarchy: big layered cuisses with side flanges, large knee cops with gold rings and wings, calf-shaped greaves with a blue ridge,
    gold ankle cuffs and pointed lamed sabatons."""
    for side in (1, -1):
        pre = "Right" if side > 0 else "Left"
        X = LX

        def mk(m):
            return m if side > 0 else m.mirror_x()

        ch.add(pre + "UpperLeg", "Steel", mk(hs.limb(X, 0, [(2.8, 0.46, 0.48), (2.2, 0.46, 0.46), (1.5, 0.38, 0.4)], seg=6)), on=pre + "UpperLeg")
        ch.add(pre + "LowerLeg", "Steel", mk(hs.limb(X, 0, [(1.6, 0.37, 0.39), (1.0, 0.4, 0.42), (0.45, 0.28, 0.3)], seg=6)), on=pre + "LowerLeg")
        # cuisse: two overlapping plates (upper wide steel, lower steel with a blue band), a gold ridge, an outer flange wing
        ch.add(pre + "UpperLeg", "Steel", mk(hs.shell([(2.74, 0.58, 0.6), (2.45, 0.57, 0.59), (2.1, 0.54, 0.56)], FRONT - 105, FRONT + 105, 0.06, seg=6, cx=X, p=2.8)))
        ch.add(pre + "UpperLeg", "SteelDark", mk(hs.shell([(2.2, 0.55, 0.57), (1.9, 0.5, 0.52), (1.62, 0.44, 0.46)], FRONT - 100, FRONT + 100, 0.06, seg=6, cx=X, p=2.8)))
        ch.add(pre + "UpperLeg", "Blue", mk(hs.shell([(2.22, 0.57, 0.59), (2.06, 0.55, 0.57)], FRONT - 100, FRONT + 100, 0.05, seg=6, cx=X, p=2.8)))
        ch.add(pre + "UpperLeg", "Gold", mk(poly_slab([(0.0, 0.0), (0.1, 0.18), (0.1, 0.5), (0.0, 0.64), (-0.1, 0.5), (-0.1, 0.18)], 0.07).rot(-8, 0, 0).move(X, 2.0, -0.6)))
        ch.add(pre + "UpperLeg", "Steel", mk(poly_slab([(0.0, 0.0), (0.4, -0.1), (0.5, -0.5), (0.0, -0.7)], 0.06).rot(0, 90, 0).move(X + 0.52, 2.55, 0.0)))
        # poleyn: big faceted knee cop, a gold ring around it, a large side wing
        kn = dome(0.47, 0.32, (0, 0, 0), seg=6, rings=2).rot(-90, 0, 0).move(X, K.knee, -0.4)
        ch.add(pre + "LowerLeg", "SteelDark", mk(kn))
        ch.add(pre + "LowerLeg", "Gold", mk(hs.shell([(K.knee + 0.04, 0.5, 0.52), (K.knee - 0.02, 0.5, 0.52)], FRONT - 110, FRONT + 110, 0.04, seg=6, cx=X, p=2.8)))
        ch.add(pre + "LowerLeg", "Gold", mk(poly_slab([(0.0, 0.0), (0.46, 0.2), (0.12, 0.62), (-0.26, 0.24)], 0.07).rot(0, 90, 0).move(X + 0.44, K.knee - 0.28, -0.08)))
        # greave: calf-shaped shin plate, blue front ridge, gold ankle cuff
        ch.add(pre + "LowerLeg", "Steel", mk(hs.shell([(1.42, 0.43, 0.45), (1.05, 0.5, 0.52), (0.75, 0.45, 0.47), (0.55, 0.33, 0.36)], FRONT - 120, FRONT + 120, 0.055, seg=6, cx=X, p=2.8)))
        ch.add(pre + "LowerLeg", "Gold", mk(poly_slab([(-0.1, 0.0), (0.1, 0.0), (0.08, 0.85), (0.0, 0.95), (-0.08, 0.85)], 0.07).move(X, 0.52, -0.55)))
        ch.add(pre + "LowerLeg", "Gold", mk(hs.shell([(0.6, 0.36, 0.39), (0.5, 0.35, 0.38)], 0, 360, 0.04, seg=8, cx=X, off=0.02)))
        ch.add(pre + "LowerLeg", "SteelDark", mk(hs.shell([(1.1, 0.5, 0.52), (0.7, 0.46, 0.48)], FRONT + 130, FRONT + 230, 0.05, seg=3, cx=X, p=2.8)))  # calf guard (back)
        # sabaton: arched, pointed toe, three lames, gold tip, heel guard
        rings = [[(X + w, 0.0, z), (X + w * 0.95, 0.3, z), (X, h, z), (X - w * 0.95, 0.3, z), (X - w, 0.0, z)] for z, w, h in ((-1.25, 0.08, 0.2), (-0.7, 0.34, 0.33), (-0.15, 0.46, 0.5), (0.5, 0.44, 0.44))]
        ch.add(pre + "Foot", "Steel", mk(loft(rings, caps=(True, True), closed_ring=True)), on=pre + "Foot")
        for k in range(3):
            ch.add(pre + "Foot", "SteelDark", mk(box(0.8 - 0.2 * k, 0.1, 0.2, c=(X, 0.5 - 0.1 * k, -0.15 - 0.28 * k))))
        ch.add(pre + "Foot", "Gold", mk(spike((X, 0.2, -1.1), (X, 0.2, -1.42), 0.09, 4)))
        ch.add(pre + "Foot", "Gold", mk(box(0.5, 0.08, 0.08, c=(X, 0.3, 0.5))))


def cloth(ch):
    def tab(u, v):
        w = lerp(0.34, 0.3, v)
        y = lerp(2.6, 1.95 + 0.25 * (1 - abs(u - 0.5) * 2), v)
        return ((u - 0.5) * 2 * w, y, -0.64 - 0.05 * v + 0.04 * math.sin(u * math.pi * 2) * v)

    ch.add("Tabard", "Blue", patch(tab, 4, 3, 0.04, flip=True), on="LowerTorso", region="static")

    def cape_fn(y_top, y_bot, w0, w1, z0, z1):
        def fn(u, v):
            y = lerp(y_top, y_bot, v)
            w = lerp(w0, w1, v)
            hem = 0.1 * abs(math.sin(u * math.pi * 5)) * smooth(0.8, 1.0, v)
            return ((u - 0.5) * w, y + hem, lerp(z0, z1, v) + math.sin(u * math.pi * 6) * (0.07 + 0.16 * v))

        return fn

    ch.add("Cape", "BlueDark", patch(cape_fn(4.7, 1.5, 1.8, 2.8, 0.7, 1.08), 10, 5, 0.05), on="UpperTorso", region="torso")
    f_all = cape_fn(4.7, 1.5, 1.8, 2.8, 0.7, 1.08)
    ch.add("Cape", "Gold", patch(lambda u, v: tuple(c + (0.04 if i == 2 else 0) for i, c in enumerate(f_all(0.45 + 0.1 * u, v))), 1, 5, 0.03))
    ch.add("Cape", "Gold", patch(lambda u, v: ((u - 0.5) * 2.7, 1.52 + 0.1 * abs(math.sin(u * math.pi * 5)) + v * 0.05, 1.08 + math.sin(u * math.pi * 6) * 0.23), 10, 1, 0.03))


def shield_and_sword(ch):
    """The signature shield: a tall horned heater with a thick steel rim and gold rivets, a radiant gold sunburst behind a steel tower
    (blue door and windows), a pointed foot; arm straps behind."""
    out = [(-1.15, 1.5), (-0.78, 1.72), (-0.42, 1.52), (0.42, 1.52), (0.78, 1.72), (1.15, 1.5), (1.15, 0.2), (0.55, -0.85), (0.0, -1.75), (-0.55, -0.85), (-1.15, 0.2)]
    sx, sy, sz = -(AX + 0.66), 3.1, -0.8
    field = poly_slab([(x * 0.93, y * 0.95) for x, y in out], 0.1)
    curve_z(field, 0.22, 1.1)
    rim = frame_slab(out, [(x * 0.89, y * 0.92) for x, y in out], 0.22)
    curve_z(rim, 0.18, 1.1)
    line = frame_slab([(x * 0.86, y * 0.88) for x, y in out], [(x * 0.83, y * 0.85) for x, y in out], 0.16)
    curve_z(line, 0.22, 1.1)
    sun = star(12, 0.95, 0.58, 0.07, c=(0, 0.35, -0.12))
    curve_z(sun, 0.22, 1.1)
    tower = merge([box(0.58, 0.8, 0.09, c=(0, 0.28, 0)), merge([box(0.16, 0.16, 0.09, c=(k * 0.21, 0.76, 0)) for k in (-1, 0, 1)])])
    curve_z(tower.move(0, 0, -0.16), 0.22, 1.1)
    door = merge([poly_slab([(-0.1, 0.0), (0.1, 0.0), (0.1, 0.22), (0.0, 0.32), (-0.1, 0.22)], 0.07).move(0, -0.02, -0.26), box(0.08, 0.14, 0.07, c=(0, 0.52, -0.26))])
    curve_z(door, 0.22, 1.1)
    studs = merge([stud((x, y, -0.23), 0.07, 0.07) for x, y in ((-1.0, 1.35), (1.0, 1.35), (-1.06, 0.4), (1.06, 0.4), (-0.78, -0.45), (0.78, -0.45), (0.0, 1.5))])
    curve_z(studs, 0.12, 1.1)
    foot = spike((0, -1.62, -0.06), (0, -2.05, -0.12), 0.11, 4)
    for col, m in (("Blue", field), ("Steel", rim), ("Gold", line), ("Gold", sun), ("Steel", tower), ("Blue", door), ("Gold", studs), ("Gold", foot)):
        ch.add("Shield", col, m.copy().move(sx, sy, sz), on="LeftLowerArm", region="armL")
    ch.add("Shield", "Steel", merge([box(0.18, 0.6, 0.08, c=(0, 0.5, 0.2)), box(0.18, 0.6, 0.08, c=(0, -0.5, 0.2))]).move(sx + 0.4, sy, sz))
    knight_sword(ch, (AX + 0.05, K.wrist + 0.1, -0.5), -32)
    ch.shield_at = (sx, sy, sz)
    ch.add("Flash", "Glow", star(8, 1.1, 0.45, 0.06, c=(sx, sy, sz - 0.7)), on="LeftLowerArm", region="armL")


def knight_sword(ch, at, tilt):
    """A slim double-edged blade (6-point section with a darker fuller strip), curved gold quillons, a wrapped leather grip with gold rings and a faceted pommel."""
    L, w, t = 2.7, 0.16, 0.06
    secs = [[(-w, 0, 0), (-w * 0.4, 0, -t), (w * 0.4, 0, -t), (w, 0, 0), (w * 0.4, 0, t), (-w * 0.4, 0, t)],
            [(-w * 0.92, L * 0.6, 0), (-w * 0.35, L * 0.6, -t * 0.9), (w * 0.35, L * 0.6, -t * 0.9), (w * 0.92, L * 0.6, 0), (w * 0.35, L * 0.6, t * 0.9), (-w * 0.35, L * 0.6, t * 0.9)],
            [(-w * 0.5, L * 0.93, 0), (-w * 0.2, L * 0.93, -t * 0.5), (w * 0.2, L * 0.93, -t * 0.5), (w * 0.5, L * 0.93, 0), (w * 0.2, L * 0.93, t * 0.5), (-w * 0.2, L * 0.93, t * 0.5)],
            [(0.0, L, 0.0)] * 6]
    blade = loft(secs, caps=(True, False))
    guard = merge([box(0.2, 0.14, 0.2, c=(0, -0.02, 0))] + [tube([(s_ * 0.1, -0.02, 0), (s_ * 0.38, -0.06, 0), (s_ * 0.6, 0.06, 0)], [0.05, 0.045, 0.03], seg=4) for s_ in (-1, 1)])
    grip = cyl(0.065, 0.065, 0.62, (0, -0.7, 0), 6)
    rings = merge([cyl(0.08, 0.08, 0.05, (0, -0.68 + 0.2 * k, 0), 6) for k in range(3)])
    pommel = lathe([(0.0001, -0.9), (0.1, -0.84), (0.12, -0.78), (0.0001, -0.7)], seg=6)
    for col, m in (("Steel", blade), ("Gold", guard), ("Leather", grip), ("Gold", rings), ("Gold", pommel)):
        ch.add("Sword", col, m.copy().rot(tilt, -30, 0).move(*at), on="RightHand", region="armR")


def animate(ch):
    sx, sy, sz = ch.shield_at
    sg = dict(period=5.0, start=1.2, dur=1.3)
    ch.joint("LshSig", jp("Shoulder", -1), "swing", "X", 22, sig=dict(sg, shape="snap"))
    ch.joint("LbashPush", (0, 0, 0), "push", "Z", -0.9, sig=dict(sg, shape="snap"))
    ch.joint("flashPop", (sx, sy, sz - 0.7), "pop", "X", 1.0, sig=dict(sg, shape="snap"))
    ch.group("Shield", "LeftLowerArm", "armL")
    ch.arm_sig(-1, groups_lower=["Shield"], sh="LshSig", el="LbashPush")
    ch.groups["Flash"]["extra"] = ["LshSig", "LbashPush", "flashPop"]
    ch.finish_anim()
