# kit035.sk2 - Shield Knight v2: the production-quality BENCHMARK for the roster rebuild (replaces the B1 box-and-shell method).
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
            (0.0, 0.40, 0.34, 0.32), (0.16, 0.58, 0.52, 0.48), (0.4, 0.72, 0.64, 0.6), (0.65, 0.75, 0.64, 0.62), (0.88, 0.68, 0.58, 0.58), (1.0, 0.46, 0.42, 0.44))], p=2.5)

    def zf(self, y):
        return -self.prof.at(y)[1] + 0.0


def shield_knight_v2():
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
    face(ch, hd, "smirk", eye_r=(0.12, 0.17), eye_dx=0.34, mouth_w=0.24, eye_n=12, blush=False, smooth_mouth=True)
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
    ch.add("UpperTorso", "Under", hs.ring_loft(TORSO, 3.1, 4.72, 4, 8, 0.0), on="UpperTorso")
    ch.add("LowerTorso", "Under", hs.ring_loft(HIPS, 2.75, 3.2, 3, 8, 0.0), on="LowerTorso")

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
    # gold keel line down the sternum + a raised tower crest (the Keep's mark)
    ch.add("UpperTorso", "Gold", band(TORSO, FRONT - 3.5, FRONT + 3.5, lambda a: lo(a) + 0.06, 4.28, lambda a, v: off(a, 0.5) + 0.035, thick=0.03, nu=1, nv=3))
    em = merge([box(0.46, 0.42, 0.07, c=(0, 0.0, 0)), merge([box(0.12, 0.12, 0.07, c=(k * 0.17, 0.27, 0)) for k in (-1, 0, 1)])])
    ch.add("UpperTorso", "Gold", em.move(0, 3.88, -0.9).rot(-8, 0, 0, (0, 3.88, -0.8)))
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
    for k, (ang, ln, col) in enumerate(((-90, 1.0, "Blue"), (-90 + 28, 0.9, "Steel"), (-90 - 28, 0.9, "Steel"), (-90 + 56, 0.72, "SteelDark"), (-90 - 56, 0.72, "SteelDark"))):
        ch.add("LowerTorso", col, band(HIPS, ang - 15, ang + 15, lambda a, ln=ln, ang=ang: 3.22 - ln + 0.12 * (1 - abs(a - ang) / 15), 3.22, lambda a, v: 0.05 + 0.08 * (1 - v), thick=0.06, nu=2, nv=1, chamfer=0.01))
        ch.add("LowerTorso", "Gold", band(HIPS, ang - 15, ang + 15, lambda a, ln=ln, ang=ang: 3.22 - ln - 0.09 + 0.12 * (1 - abs(a - ang) / 15), lambda a, ln=ln, ang=ang: 3.22 - ln + 0.02 + 0.12 * (1 - abs(a - ang) / 15), lambda a, v: 0.1, thick=0.03, nu=2, nv=1))


def helm(ch, hd):
    """Open-face knight's helm: faceted dome with a raised comb, a projecting brow flange, flared cheek guards, a lamed neck guard, gold edge lines,
    rivets, an enamel crest fin and a swept plume. The face stays free."""
    A = hd.at
    top = hd.top
    hsx = hd.hs
    rx, rz = 0.86 * hsx + 0.04, 0.74 * hsx + 0.06
    cap = hs.cap_lame(rx, 0.72 * hsx + 0.25, rz, 0, 74, 0, 360, 0.08, 10, 3)
    ch.add("Helmet", "Steel", cap.move(0, A(0.78) - (0.72 * hsx + 0.25) * math.cos(math.radians(74)), 0), on="Head", region="head")
    # side shell + flared cheek guards (the lower edge flares out)
    low = Prof([(A(0.05), rx * 0.74, rz * 0.7, rz * 0.7), (A(0.3), rx * 0.92, rz * 0.9, rz * 0.9), (A(0.55), rx, rz, rz), (A(0.78), rx, rz, rz)], p=2.6)
    ch.add("Helmet", "Steel", band(low, FRONT + 66, FRONT + 294, A(0.04), A(0.78), lambda a, v: 0.0 + 0.1 * (1 - v) ** 2, thick=0.08, nu=6, nv=2, chamfer=0.02))
    ch.add("Helmet", "Gold", band(low, FRONT + 66, FRONT + 294, A(0.0), A(0.05), lambda a, v: 0.1, thick=0.04, nu=6, nv=1))
    # brow flange (projects forward, angled down) with a gold edge
    brow = Prof([(A(0.72), rx, rz, rz), (A(0.86), rx, rz, rz)], p=2.4)
    ch.add("Helmet", "Steel", band(brow, FRONT - 66, FRONT + 66, A(0.7), A(0.86), lambda a, v: 0.1 + 0.08 * (1 - abs(rel(a)) / 66) * (1 - v), thick=0.07, nu=6, nv=1, chamfer=0.015))
    ch.add("Helmet", "Gold", band(brow, FRONT - 66, FRONT + 66, A(0.67), A(0.71), lambda a, v: 0.12 + 0.08 * (1 - abs(rel(a)) / 66), thick=0.04, nu=6, nv=1))
    ch.add("Helmet", "SteelDark", box(0.12, hd.H * 0.42, 0.06, c=(0, A(0.5), -rz - 0.04)))  # nasal bar
    ch.add("Helmet", "Gold", merge([stud((x * (rx + 0.03), A(0.5), 0.0), 0.06, 0.06).rot(0, 90 * x, 0, (x * (rx + 0.03), A(0.5), 0.0)) for x in (-1, 1)]))
    for k in range(2):  # lamed neck guard at the back
        y = A(0.16) - 0.14 * k
        pr = Prof([(y - 0.15, rx * (0.72 + 0.04 * k), rz * 0.74, rz * 0.74), (y, rx * (0.74 + 0.04 * k), rz * 0.76, rz * 0.76)], p=2.4)
        ch.add("Helmet", "SteelDark" if k % 2 == 0 else "Steel", band(pr, 12, 168, y - 0.15, y, 0.04 + 0.03 * k, thick=0.05, nu=4, nv=1))
    # raised comb along the dome (steel) + a tall enamel crest fin and plume behind it
    c0 = A(0.74) + 0.72 * hsx + 0.25
    comb = [(-rz - 0.02, A(0.78)), (-rz * 0.6, A(0.74) + 0.62 * hsx + 0.3), (0.0, c0 + 0.12), (rz * 0.6, A(0.74) + 0.6 * hsx + 0.3), (rz + 0.02, A(0.8)), (rz * 0.6, A(0.74) + 0.55 * hsx + 0.26), (0.0, c0 - 0.02), (-rz * 0.6, A(0.74) + 0.56 * hsx + 0.26)]
    ch.add("Helmet", "SteelDark", profile_slab(comb, 0.16, bev=0.0), on="Head", region="head")
    fin = [(0.15, c0 - 0.1), (0.5, c0 + 0.55), (0.95, c0 + 0.62), (1.35, c0 + 0.2), (1.05, c0 - 0.2)]
    ch.add("Helmet", "Blue", profile_slab(fin, 0.14, bev=0.0), on="Head", region="head")
    ch.add("Plume", "Blue", tube([(0.0, c0 + 0.1, 0.5), (0.0, c0 + 0.2, 0.95), (0.0, c0 - 0.1, 1.4), (0.0, c0 - 0.7, 1.65), (0.0, c0 - 1.4, 1.7)], [0.12, 0.2, 0.22, 0.18, 0.05], seg=4, sx=0.5), on="Head", region="head")


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
        ch.add(pre + "Hand", "Steel", mk(box(0.54, 0.1, 0.22, c=(X, 2.52, -0.28))))


def legs(ch):
    for side in (1, -1):
        pre = "Right" if side > 0 else "Left"
        X = LX

        def mk(m):
            return m if side > 0 else m.mirror_x()

        ch.add(pre + "UpperLeg", "Under", mk(hs.limb(X, 0, [(2.8, 0.46, 0.48), (2.2, 0.46, 0.46), (1.5, 0.38, 0.4)], seg=6)), on=pre + "UpperLeg")
        ch.add(pre + "LowerLeg", "Under", mk(hs.limb(X, 0, [(1.6, 0.37, 0.39), (1.0, 0.4, 0.42), (0.45, 0.28, 0.3)], seg=6)), on=pre + "LowerLeg")
        ch.add(pre + "UpperLeg", "Steel", mk(hs.shell([(2.7, 0.55, 0.57), (2.15, 0.53, 0.55), (1.65, 0.46, 0.48)], FRONT - 105, FRONT + 105, 0.06, seg=6, cx=X, p=2.8)))
        ch.add(pre + "UpperLeg", "Gold", mk(poly_slab([(0.0, 0.0), (0.09, 0.15), (0.09, 0.6), (0.0, 0.7), (-0.09, 0.6), (-0.09, 0.15)], 0.07).rot(-8, 0, 0).move(X, 1.8, -0.56)))
        ch.add(pre + "UpperLeg", "Blue", mk(hs.shell([(2.12, 0.565, 0.585), (1.92, 0.55, 0.57)], FRONT - 100, FRONT + 100, 0.05, seg=6, cx=X, p=2.8)))
        ch.add(pre + "LowerLeg", "Blue", mk(poly_slab([(-0.09, 0.0), (0.09, 0.0), (0.07, 0.8), (-0.07, 0.8)], 0.06).move(X, 0.6, -0.55)))
        ch.add(pre + "LowerLeg", "Gold", mk(hs.shell([(1.42, 0.46, 0.48), (1.46, 0.46, 0.48)], FRONT - 120, FRONT + 120, 0.03, seg=6, cx=X, p=2.8)))
        kn = dome(0.46, 0.34, (0, 0, 0), seg=6, rings=2).rot(-90, 0, 0).move(X, K.knee, -0.4)
        ch.add(pre + "LowerLeg", "SteelDark", mk(kn))
        kw = poly_slab([(0.0, 0.0), (0.34, 0.18), (0.08, 0.5), (-0.22, 0.2)], 0.06).rot(0, 90, 0).move(X + 0.36, K.knee - 0.2, -0.1)
        ch.add(pre + "LowerLeg", "Gold", mk(kw))
        ch.add(pre + "LowerLeg", "Steel", mk(hs.shell([(1.4, 0.43, 0.45), (1.0, 0.47, 0.49), (0.65, 0.37, 0.4), (0.5, 0.4, 0.43)], FRONT - 120, FRONT + 120, 0.055, seg=6, cx=X, p=2.8)))
        rings = [[(X + w, 0.0, z), (X + w * 0.95, 0.3, z), (X, 0.4 - 0.07 * (z < -0.5), z), (X - w * 0.95, 0.3, z), (X - w, 0.0, z)] for z, w in ((-1.0, 0.12), (-0.6, 0.34), (-0.1, 0.46), (0.5, 0.44))]
        ch.add(pre + "Foot", "SteelDark", mk(loft(rings, caps=(True, True), closed_ring=True)), on=pre + "Foot")
        for k in range(2):
            ch.add(pre + "Foot", "Steel", mk(box(0.78 - 0.2 * k, 0.1, 0.18, c=(X, 0.42 - 0.04 * k, -0.2 - 0.22 * k))))


def cloth(ch):
    def tab(u, v):
        w = lerp(0.34, 0.3, v)
        y = lerp(2.6, 1.95 + 0.25 * (1 - abs(u - 0.5) * 2), v)
        return ((u - 0.5) * 2 * w, y, -0.64 - 0.05 * v + 0.04 * math.sin(u * math.pi * 2) * v)

    ch.add("Tabard", "Blue", patch(tab, 4, 3, 0.04, flip=True), on="LowerTorso", region="static")
    ch.add("Tabard", "Gold", patch(lambda u, v: ((u - 0.5) * 0.6, 1.95 + 0.25 * (1 - abs(u - 0.5) * 2) + 0.05 * v, -0.69), 4, 1, 0.03, flip=True))

    def cape_fn(y_top, y_bot, w0, w1, z0, z1):
        def fn(u, v):
            y = lerp(y_top, y_bot, v)
            w = lerp(w0, w1, v)
            hem = 0.1 * abs(math.sin(u * math.pi * 5)) * smooth(0.8, 1.0, v)
            return ((u - 0.5) * w, y + hem, lerp(z0, z1, v) + math.sin(u * math.pi * 6) * (0.07 + 0.16 * v))

        return fn

    ch.add("Cape", "BlueDark", patch(cape_fn(4.7, 3.3, 1.8, 2.3, 0.7, 0.86), 10, 2, 0.05), on="UpperTorso", region="torso")
    ch.add("CapeLow", "BlueDark", patch(cape_fn(3.3, 1.5, 2.3, 2.8, 0.86, 1.08), 10, 3, 0.05), on="UpperTorso", region="torso")
    f_up, f_lo = cape_fn(4.7, 3.3, 1.8, 2.3, 0.7, 0.86), cape_fn(3.3, 1.5, 2.3, 2.8, 0.86, 1.08)
    ch.add("Cape", "Gold", patch(lambda u, v: tuple(c + (0.04 if i == 2 else 0) for i, c in enumerate(f_up(0.45 + 0.1 * u, v))), 1, 2, 0.03))
    ch.add("CapeLow", "Gold", patch(lambda u, v: tuple(c + (0.04 if i == 2 else 0) for i, c in enumerate(f_lo(0.45 + 0.1 * u, v))), 1, 3, 0.03))
    ch.add("CapeLow", "Gold", patch(lambda u, v: ((u - 0.5) * 2.7, 1.52 + 0.1 * abs(math.sin(u * math.pi * 5)) + v * 0.05, 1.08 + math.sin(u * math.pi * 6) * 0.23), 12, 1, 0.03))


def shield_and_sword(ch):
    out = [(-1.05, 1.35), (-0.95, 1.55), (0.95, 1.55), (1.05, 1.35), (1.05, 0.1), (0.5, -0.8), (0.0, -1.55), (-0.5, -0.8), (-1.05, 0.1)]
    sx, sy, sz = -(AX + 0.62), 3.1, -0.8
    field = poly_slab([(x * 0.93, y * 0.95) for x, y in out], 0.1)
    curve_z(field, 0.2, 1.05)
    rim = frame_slab(out, [(x * 0.9, y * 0.92) for x, y in out], 0.2)
    curve_z(rim, 0.16, 1.05)
    boss = dome(0.34, 0.22, (0, 0, 0), seg=8, rings=2).rot(-90, 0, 0).move(0, -0.3, -0.25)
    crest = merge([box(0.62, 0.7, 0.08, c=(0, 0.6, 0)), merge([box(0.17, 0.17, 0.08, c=(k * 0.22, 1.05, 0)) for k in (-1, 0, 1)])])
    curve_z(crest, 0.2, 1.05)
    line = frame_slab([(x * 0.86, y * 0.88) for x, y in out], [(x * 0.82, y * 0.84) for x, y in out], 0.14)
    curve_z(line, 0.2, 1.05)
    for col, m in (("Blue", field), ("Steel", rim), ("Steel", boss), ("Gold", crest), ("Gold", line)):
        ch.add("Shield", col, m.copy().move(sx, sy, sz), on="LeftLowerArm", region="armL")
    ch.add("Shield", "Leather", merge([box(0.18, 0.6, 0.08, c=(0, 0.5, 0.2)), box(0.18, 0.6, 0.08, c=(0, -0.5, 0.2))]).move(sx + 0.4, sy, sz))
    knight_sword(ch, (AX, K.wrist - 0.05, -0.55), -26)
    ch.shield_at = (sx, sy, sz)
    ch.add("Flash", "Glow", star(8, 1.1, 0.45, 0.06, c=(sx, sy, sz - 0.65)), on="LeftLowerArm", region="armL")


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
        ch.add("Sword", col, m.copy().rot(tilt, 0, 0).move(*at), on="RightHand", region="armR")


def animate(ch):
    sx, sy, sz = ch.shield_at
    sg = dict(period=5.0, start=1.2, dur=1.3)
    ch.joint("LshSig", jp("Shoulder", -1), "swing", "X", 22, sig=dict(sg, shape="snap"))
    ch.joint("LbashPush", (0, 0, 0), "push", "Z", -0.9, sig=dict(sg, shape="snap"))
    ch.joint("flashPop", (sx, sy, sz - 0.65), "pop", "X", 1.0, sig=dict(sg, shape="snap"))
    ch.group("Shield", "LeftLowerArm", "armL")
    ch.arm_sig(-1, groups_lower=["Shield"], sh="LshSig", el="LbashPush")
    ch.groups["Flash"]["extra"] = ["LshSig", "LbashPush", "flashPop"]
    ch.finish_anim()
