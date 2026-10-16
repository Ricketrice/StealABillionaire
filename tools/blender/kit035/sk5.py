# kit035.sk5 - Shield Knight v5: the STYLISED ROBLOX correction (owner 2026-10-16). Keeps v4's layered-plate geometry, but:
#   * chunky avatar proportions: broader shoulder line (arm_x 2.05), thicker arms, a clear gap between thicker legs, big boots, a barrel chest;
#   * a distinctive helmet: a tall bucket helm with a beaked faceplate, an eye slit under a heavy brow flange, a notched crest and two big swept-back
#     blade wings; chest / shoulders / boots exaggerated for hierarchy; a smaller shield so the body and helm lead.
# v4 is reused, not forked: its builders run against the CHUNK skeleton and the results are re-proportioned (x/z scaling about each limb axis).
import math

from . import body, hs, sk4
from .geo import box, tube, poly_slab, merge, cyl_between, profile_slab, dome, star
from .hs import Prof, band, stud
from .char import Char
from .body import CHUNK

K = CHUNK
FRONT = -90.0
HY0 = K.neck - 0.02
HH = 2.05


def A(k):
    return HY0 + HH * k


def _xf(ch, groups, fn):
    for key in list(ch.parts):
        if key[0] in groups or any(key[0].endswith(g) for g in groups if g.startswith("*")):
            fn(ch.parts[key], key)


def _grp(ch, suffixes):
    return [g for g in ch.groups if any(g.endswith(s) for s in suffixes)]


def shield_knight_v5():
    body.set_skel(K)
    sk4.K, sk4.AX, sk4.LX, sk4.PS = K, K.arm_x, K.leg_x, 1.0
    ch = Char("ShieldKnight", "Epic", "Knight's Keep", scale=0.9)
    ch.sig_label = "shield bash"
    ch.sa = 32.0
    ch.rig = K.data()
    ch.colours(
        Plate=("#7F8794", "Metal", 0.38, 1.0), Dark=("#1B1E26", "Metal", 0.5, 1.0), Trim=("#B9C1CF", "Metal", 0.28, 1.0), Gold=("#B08A38", "Metal", 0.33, 1.0),
        Blue=("#2146C8", "SmoothPlastic", 0.45, 0.0), Cloth=("#16204A", "Fabric", 0.9, 0.0), Leather=("#3A2A20", "SmoothPlastic", 0.7, 0.0),
        Blade=("#C9D0DC", "Metal", 0.22, 1.0), Glow=("#9CC6FF", "Neon", 0.2, 0.0),
    )
    sk4.torso(ch)
    sk4.waist(ch)
    sk4.pauldrons(ch)
    sk4.arms(ch)
    sk4.legs(ch)
    sk4.cloth(ch)
    sk4.shield_and_sword(ch)
    # ---- chunky re-proportioning (about each limb's own axis, so joints and attachment stay where the rig has them)
    ax, lx = K.arm_x, K.leg_x
    for side, sgn in (("Right", 1), ("Left", -1)):
        for part in ("UpperArm", "LowerArm", "Hand"):
            _xf(ch, [side + part], lambda m, k, c=sgn * ax: m.scale(1.15, 1.0, 1.15, about=(c, 0, 0)))
        for part in ("UpperLeg", "LowerLeg"):
            _xf(ch, [side + part], lambda m, k, c=sgn * lx: m.scale(1.12, 1.0, 1.12, about=(c, 0, 0)))
        _xf(ch, [side + "Foot"], lambda m, k, c=sgn * lx: m.scale(1.28, 1.25, 1.22, about=(c, 0, -0.1)))
    _xf(ch, ["UpperTorso", "LowerTorso", "Tabard", "Sash"], lambda m, k: m.scale(1.1, 1.0, 1.08))
    # ---- the shield: smaller and tucked in, so the body and helm are the main attraction
    sx, sy, sz = ch.shield_at
    _xf(ch, ["Shield", "Flash"], lambda m, k: m.scale(0.7, 0.7, 0.7, about=(sx, sy, sz)).move(0.28, 0.35, -0.12))
    ch.shield_at = (sx + 0.28, sy + 0.35, sz - 0.12)
    helm(ch)
    chest_focus(ch)
    sk4.animate(ch)
    for k in list(ch.parts):
        ch.parts[k] = hs.simplify(ch.parts[k], 4.0)
    ch.meta = dict(arm_x=ax, leg_x=lx, helm_y0=HY0, helm_h=HH, shield=ch.shield_at)
    return ch


def helm(ch):
    hx, hz = 1.4, 1.22
    ch.add("Helmet", "Cloth", hs.ring_loft(Prof([(A(0.04), hx * 0.6, hz * 0.58, hz * 0.58), (A(0.5), hx * 0.84, hz * 0.8, hz * 0.8), (A(0.9), hx * 0.8, hz * 0.78, hz * 0.78)], p=2.4), A(0.04), A(0.9), 4, 10, 0.0, caps=True), on="Head", region="head")
    cap = hs.cap_lame(hx, 1.0, hz, 0, 84, 0, 360, 0.11, 12, 4)
    ch.add("Helmet", "Plate", cap.move(0, A(0.62) - 1.0 * math.cos(math.radians(84)), 0))
    shell_ = Prof([(A(0.02), hx * 0.74, hz * 0.7, hz * 0.74), (A(0.3), hx * 0.96, hz * 0.92, hz * 0.96), (A(0.62), hx, hz, hz)], p=2.5)
    ch.add("Helmet", "Plate", band(shell_, FRONT + 36, FRONT + 324, A(0.02), A(0.62), lambda a, v: 0.16 * (1 - v) ** 2, thick=0.11, nu=8, nv=3, chamfer=0.02))
    # beaked faceplate: bigger and pointier, the narrow gap above it (under the brow) is the eye slit
    fp = Prof([(A(0.02), 0.44, 0.84, 0.6), (A(0.22), 0.88, 1.08, 0.78), (A(0.5), 1.26, 1.2, 0.95)], p=1.7)
    ch.add("Helmet", "Dark", band(fp, FRONT - 80, FRONT + 80, A(0.02), A(0.5), 0.0, thick=0.11, nu=8, nv=3, chamfer=0.03))
    ch.add("Helmet", "Trim", poly_slab([(-0.07, 0.0), (0.07, 0.0), (0.05, 1.05), (-0.05, 1.05)], 0.09).move(0, A(0.04), -1.18).rot(16, 0, 0, (0, A(0.04), -1.0)))
    brow = Prof([(A(0.56), hx, hz, hz), (A(0.7), hx, hz, hz)], p=2.4)
    ch.add("Helmet", "Trim", band(brow, FRONT - 84, FRONT + 84, A(0.54), A(0.69), lambda a, v: 0.14 + 0.22 * (1 - abs(a - FRONT) / 84) * (1 - v), thick=0.12, nu=8, nv=1, chamfer=0.02))
    ch.add("Helmet", "Gold", merge([stud((math.sin(math.radians(t)) * (hx + 0.2), A(0.64), -math.cos(math.radians(t)) * (hz + 0.2)), 0.06, 0.06) for t in (-62, -40, -18, 18, 40, 62)]))
    # big neck protection: three stacked lames, wider than the old ones
    for k in range(3):
        y = A(0.0) - 0.16 * k
        pr = Prof([(y - 0.19, 0.78 + 0.17 * k, 0.66 + 0.13 * k, 0.66 + 0.13 * k), (y, 0.72 + 0.16 * k, 0.6 + 0.13 * k, 0.6 + 0.13 * k)], p=2.4)
        ch.add("UpperTorso", "Plate" if k != 1 else "Dark", band(pr, 0, 360, y - 0.19, y, 0.05, thick=0.08, nu=10, nv=1, chamfer=0.014), on="UpperTorso")
    # a tall notched crest and two big swept-back blade wings (original silhouette: a winged bucket helm)
    y0 = A(0.62) + 1.0
    comb = [(-1.0, y0 - 0.4), (-0.7, y0 + 0.3), (-0.5, y0 + 0.14), (-0.28, y0 + 0.62), (-0.06, y0 + 0.4), (0.2, y0 + 0.92), (0.46, y0 + 0.64), (0.74, y0 + 0.5), (1.1, y0 - 0.3), (0.46, y0 - 0.16), (-0.4, y0 - 0.16)]
    ch.add("Helmet", "Dark", profile_slab(comb, 0.24))
    yb = A(0.46)
    wing = [(-0.7, yb - 0.3), (-0.1, yb + 0.6), (0.7, yb + 1.25), (1.7, yb + 1.7), (1.5, yb + 0.9), (1.2, yb + 0.1), (0.5, yb - 0.3)]
    for s_ in (-1, 1):
        ch.add("Helmet", "Trim", profile_slab(wing, 0.34, x=s_ * (hx + 0.1)).rot(0, 0, -s_ * 20, (s_ * (hx + 0.1), yb, 0)).rot(0, s_ * 12, 0, (s_ * (hx + 0.1), yb, 0)))
        rib = [(-0.5, yb - 0.1), (0.0, yb + 0.5), (0.8, yb + 1.1), (1.5, yb + 1.45), (0.8, yb + 0.6), (0.2, yb + 0.0)]
        ch.add("Helmet", "Dark", profile_slab(rib, 0.2, x=s_ * (hx + 0.3)).rot(0, 0, -s_ * 20, (s_ * (hx + 0.1), yb, 0)).rot(0, s_ * 12, 0, (s_ * (hx + 0.1), yb, 0)))


def chest_focus(ch):
    """Chest hierarchy: a raised octagonal boss with a blue enamel eye, a collar ridge and bigger belly steps (all on the already scaled torso)."""
    zf = -1.22
    ch.add("UpperTorso", "Trim", star(8, 0.74, 0.62, 0.14, c=(0, 4.0, zf), rot=22.5))
    ch.add("UpperTorso", "Dark", star(8, 0.6, 0.5, 0.12, c=(0, 4.0, zf - 0.07), rot=22.5))
    ch.add("UpperTorso", "Blue", dome(0.34, 0.2, (0, 0, 0), seg=10, rings=2).rot(-90, 0, 0).move(0, 4.0, zf - 0.1))
    ch.add("UpperTorso", "Gold", merge([stud((math.cos(math.radians(a)) * 0.68, 4.0 + math.sin(math.radians(a)) * 0.68, zf - 0.1), 0.06, 0.06) for a in range(0, 360, 45)]))
