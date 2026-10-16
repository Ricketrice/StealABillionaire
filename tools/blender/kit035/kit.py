# kit035.kit - the shared knight / adventurer part library. Every function adds meshes to a Char in frame A (right = +X, front = -Z)
# using palette colour NAMES, so the same helmet, plate or sword gets a different look per character.
import math

from .geo import profile_slab, star, M, V, box, frustum, ellipsoid, lathe, tube, poly_slab, ellipse_slab, merge, cyl, cyl_between, spike, torus, dome, loft, sheet, dent
from .body import jp, Head


def both(ch, group_base, colour, mesh_right, **kw):
    """Add a right-side mesh to Right<group_base> and its mirror to Left<group_base>."""
    ch.add("Right" + group_base, colour, mesh_right, **kw)
    ch.add("Left" + group_base, colour, mesh_right.copy().mirror_x(), **kw)


# ------------------------------------------------------------------ torso
def belt(ch, main, buckle, y=2.42, h=0.3, w=2.0, d=1.08):
    ch.add("LowerTorso", main, frustum(y - h / 2, y + h / 2, w, d, w, d, bev=0.04, seg=1))
    ch.add("LowerTorso", buckle, box(0.46, h * 0.95, 0.1, bev=0.03, seg=1, c=(0, y, -d / 2 - 0.02)))


def chest_plate(ch, main, trim, ridge=True, flare=1.0, lames=2, bevseg=2):
    """Layered breastplate on the UpperTorso: shell, central ridge, collar and horizontal lames over the belly."""
    ch.add("UpperTorso", main, frustum(2.55, 4.02, 1.88, 1.02, 2.16 * flare, 1.14, bev=0.14, seg=bevseg))
    ch.add("UpperTorso", trim, frustum(3.84, 4.08, 1.55, 1.12, 1.55, 1.12, bev=0.05, seg=1))  # gorget ring
    if ridge:
        ch.add("UpperTorso", trim, box(0.17, 1.2, 0.1, bev=0.04, seg=1, c=(0, 3.35, -0.6)).rot(-6, 0, 0, (0, 3.35, -0.6)))
    for k in range(lames):
        y = 2.72 + 0.17 * k
        ch.add("UpperTorso", trim, box(1.9 - 0.04 * k, 0.09, 0.07, c=(0, y, -0.55)))


def tassets(ch, main, trim, n=5, reach=0.62, hang=0.85):
    """Hanging skirt plates around the hips (LowerTorso group)."""
    for k in range(n):
        a = math.radians(-70 + 140 * k / (n - 1))
        x, z = math.sin(a) * 1.05, -math.cos(a) * 0.62
        p = box(0.62, hang, 0.09, bev=0.03, seg=1, c=(0, -hang / 2, 0)).rot(8, 0, 0, (0, 0, 0)).rot(0, -math.degrees(a) * 0.75, 0).move(x, 2.5, z)
        ch.add("LowerTorso", main, p)
        ch.add("LowerTorso", trim, box(0.66, 0.06, 0.12, c=(0, -hang + 0.02, 0)).rot(8, 0, 0).rot(0, -math.degrees(a) * 0.75, 0).move(x, 2.5, z))


# ------------------------------------------------------------------ arms
def pauldron(ch, main, trim, size=1.0, lames=2, tilt=14, spikes=0, spike_col=None, bevseg=2, sides=(1, -1), depth=0.95, out=0.0):
    """Layered shoulder guard on both UpperArm groups: a dome, `lames` overlapping bands, a trim rim, optional spikes."""
    cx, cy = 1.56 + out, 3.84
    for side in sides:
        g = ("Right" if side > 0 else "Left") + "UpperArm"
        parts = []
        parts.append((main, dome(0.82 * size, 0.5 * size, (0, 0, 0), seg=10, rings=3).scale(1.0, 1.0, depth)))
        for k in range(lames):
            r = (0.9 + 0.06 * k) * size
            y0, y1 = -0.2 * (k + 1) * size, -0.2 * k * size + 0.02
            parts.append((main, lathe([(r - 0.05, y0), (r, y0), (r, y1), (r - 0.05, y1)], seg=10, sz=depth)))
        parts.append((trim, lathe([(0.86 * size, 0.04), (0.92 * size, 0.0), (0.9 * size, -0.07), (0.84 * size, -0.05)], seg=10, sz=depth)))
        for k in range(spikes):
            a = math.radians(-50 + 100 * k / max(spikes - 1, 1))
            parts.append((spike_col or trim, spike((math.sin(a) * 0.3, 0.4 * size, -math.cos(a) * 0.3), (math.sin(a) * 0.5, 0.4 * size + 0.55 * size, -math.cos(a) * 0.5), 0.09 * size, 4)))
        for col, m in parts:
            m = m.rot(0, 0, -tilt).move(cx, cy, 0)
            ch.add(g, col, m if side > 0 else m.mirror_x())


def gauntlets(ch, main, trim, long=True):
    """Vambrace over the lower arm + a knuckle guard over the hand."""
    for side in (1, -1):
        pre = "Right" if side > 0 else "Left"
        cuff = frustum(2.3 if long else 2.35, 3.0 if long else 2.75, 0.92, 0.92, 1.0, 1.0, bev=0.07, seg=1).move(1.5)
        ch.add(pre + "LowerArm", main, cuff if side > 0 else cuff.mirror_x())
        band = box(1.02, 0.1, 1.02, c=(1.5, 2.98 if long else 2.76, 0))
        ch.add(pre + "LowerArm", trim, band if side > 0 else band.mirror_x())
        kn = box(0.8, 0.34, 0.82, bev=0.1, seg=1, c=(1.5, 2.12, 0))
        ch.add(pre + "Hand", main, kn if side > 0 else kn.mirror_x())


# ------------------------------------------------------------------ legs
def leg_armor(ch, main, trim, knee=True, thigh=True, bevseg=1):
    for side in (1, -1):
        pre = "Right" if side > 0 else "Left"
        x = 0.5 * side
        if thigh:
            ch.add(pre + "UpperLeg", main, frustum(1.2, 2.0, 0.98, 1.0, 1.04, 1.04, bev=0.08, seg=bevseg, c=(x, 0, 0)))
        gv = frustum(0.42, 1.08, 0.9, 0.96, 0.98, 1.02, bev=0.07, seg=bevseg, c=(x, 0, 0))
        ch.add(pre + "LowerLeg", main, gv)
        if knee:
            kc = dome(0.42, 0.3, (0, 0, 0), seg=8, rings=3).rot(-90, 0, 0).move(x, 1.12, -0.46)
            ch.add(pre + "LowerLeg", trim, kc)
        ch.add(pre + "LowerLeg", trim, box(0.98, 0.08, 1.02, c=(x, 1.07, 0)))


def sabatons(ch, main, trim):
    for side in (1, -1):
        pre = "Right" if side > 0 else "Left"
        x = 0.5 * side
        ch.add(pre + "Foot", main, box(0.94, 0.4, 1.3, bev=0.14, seg=1, c=(x, 0.2, -0.14)))
        ch.add(pre + "Foot", trim, box(0.8, 0.12, 0.5, bev=0.04, seg=1, c=(x, 0.4, -0.52)))


# ------------------------------------------------------------------ capes
def cape(ch, main, trim, top=3.92, hem=0.9, w_top=1.7, w_hem=2.5, z=0.62, group="Cape", ripple=0.11, split=2.45, nu=5):
    """A two-segment cape (Cape + CapeLow on the UpperTorso) so it can bend; returns the two group names. Hinge pivots are
    (0, top, z) and (0, split, z+..)."""

    def surf(y_a, y_b, wa, wb, kick_a, kick_b):
        def f(u, v):
            y = y_a + (y_b - y_a) * v
            w = wa + (wb - wa) * v
            x = (u - 0.5) * w
            zz = z + kick_a + (kick_b - kick_a) * v + math.sin(u * math.pi * 3) * ripple * (0.3 + v)
            return (x, y, zz)

        return f

    tw = (w_top + (w_hem - w_top) * (top - split) / (top - hem))
    up = sheet(surf(top, split, w_top, tw, 0.0, 0.18), nu, 3, 0.05)
    lo = sheet(surf(split, hem, tw, w_hem, 0.18, 0.42), nu, 3, 0.05)
    ch.add(group, main, up, on="UpperTorso", region="torso")
    ch.add(group + "Low", main, lo, on="UpperTorso", region="torso")
    edge = box(w_hem, 0.12, 0.08, c=(0, hem + 0.04, z + 0.43))
    ch.add(group + "Low", trim, edge)
    ch.add(group + "Low", trim, box(0.2, split - hem - 0.2, 0.06, c=(0, (split + hem) / 2 - 0.05, z + 0.26)))  # centre stripe
    for s in (1, -1):
        ch.add(group, trim, ellipsoid((0.13, 0.13, 0.1), (0.62 * s, top - 0.05, z - 0.08), 6, 3))  # clasps
    return group, group + "Low"


# ------------------------------------------------------------------ weapons and shields
def sword(ch, group, on, blade, guard, grip, length=2.0, width=0.2, thick=0.07, region="armR", at=(1.5, 2.3, -0.5), tilt=-24, wing=0.0,
          fuller=None, glow_edge=None):
    """A sword standing up out of the fist at `at`, leaning forward by `tilt`. Blade is a diamond-section loft (pointed tip)."""
    w, t = width, thick
    secs = [
        [(-w, 0, 0), (0, 0, -t), (w, 0, 0), (0, 0, t)],
        [(-w * 0.95, length * 0.55, 0), (0, length * 0.55, -t * 0.9), (w * 0.95, length * 0.55, 0), (0, length * 0.55, t * 0.9)],
        [(-w * 0.55, length * 0.9, 0), (0, length * 0.9, -t * 0.6), (w * 0.55, length * 0.9, 0), (0, length * 0.9, t * 0.6)],
        [(-0.001, length, 0), (0, length, -0.001), (0.001, length, 0), (0, length, 0.001)],
    ]
    parts = [(blade, loft(secs, caps=(True, True))), (guard, box(w * 4.0, 0.12, 0.17, bev=0.04, seg=1, c=(0, -0.04, 0))),
             (grip, cyl(0.065, 0.065, 0.55, (0, -0.6, 0), 6)), (guard, ellipsoid((0.1, 0.1, 0.1), (0, -0.66, 0), 6, 3))]
    if wing > 0:
        for s in (1, -1):
            parts.append((guard, box(wing, 0.1, 0.1, c=(s * (w * 2 + wing / 2 - 0.05), 0.08, 0)).rot(0, 0, s * 18, (s * w * 2, 0, 0))))
    for col, m in parts:
        m = m.copy().rot(tilt, 0, 0).move(*at)
        ch.add(group, col, m, on=on, region=region)


def heater_outline(w, h, tip=0.5, top=0.12):
    """A heater / kite shield outline (x, y), origin at the centre, counter-clockwise."""
    pts = [(-w / 2, h / 2 - top), (-w / 2 + top, h / 2), (w / 2 - top, h / 2), (w / 2, h / 2 - top), (w / 2, h * 0.05), (w * 0.34, -h * 0.25), (w * 0.12, -h * 0.42), (0, -h / 2), (-w * 0.12, -h * 0.42), (-w * 0.34, -h * 0.25), (-w / 2, h * 0.05)]
    return pts


def shield(ch, group, face, rim, emblem, boss, w=2.3, h=3.2, tip=0.5, at=(-1.9, 2.75, -0.75), thick=0.16, on="LeftLowerArm", region="armL", tilt=0, yaw=0):
    out = heater_outline(w, h, tip)
    base = poly_slab(out, thick, bev=0.04, seg=1)
    rimm = poly_slab([(x * 1.07, y * 1.05) for x, y in out], thick * 0.7, bev=0.03, seg=1).move(0, 0, thick * 0.35)
    ins = poly_slab([(x * 0.84, y * 0.85) for x, y in out], thick * 1.25, bev=0.03, seg=1).move(0, 0, -0.02)
    b = ellipsoid((0.3, 0.3, 0.16), (0, 0.55, -thick * 0.7), 8, 4)
    for col, m in ((rim, rimm), (face, ins), (boss, b)):
        m = m.copy().rot(tilt, yaw, 0).move(*at)
        ch.add(group, col, m, on=on, region=region)
    return at


def tower_emblem(ch, group, colour, at, scale=1.0, on="LeftLowerArm", region="armL", z=-0.1):
    """An original crest: a three-merlon tower with a small door, over a star (faces forward, -Z)."""
    x, y, zz = at
    s = scale
    parts = [box(0.5 * s, 0.55 * s, 0.07, c=(0, -0.05 * s, 0))]
    for k in (-1, 0, 1):
        parts.append(box(0.14 * s, 0.14 * s, 0.07, c=(k * 0.18 * s, 0.3 * s, 0)))
    parts.append(ellipse_slab(0.12 * s, 0.12 * s, 0.07, 5, (0, 0.62 * s, 0), back=True, rot=90))
    for m in parts:
        ch.add(group, colour, m.move(x, y, zz + z), on=on, region=region)


def plume(ch, group, colour, base, length=1.2, lift=0.7, sweep=0.9, width=0.3, on="Head", region="head", n=6):
    """A curved crest feather running back over the helmet: path rises then sweeps back (+Z)."""
    bx, by, bz = base
    pts = [(bx, by + lift * math.sin(math.pi * 0.5 * k / (n - 1)) , bz + sweep * (k / (n - 1)) ** 1.6) for k in range(n)]
    rad = [width * (0.25 + 0.75 * math.sin(math.pi * (k + 0.5) / n)) for k in range(n)]
    m = tube(pts, rad, seg=4, caps=(True, True), sx=0.55, sz=1.0)
    ch.add(group, colour, m, on=on, region=region)


# ------------------------------------------------------------------ helmets
def helm_open(ch, hd, main, trim, crest=None, cheek=True, nasal=True, cap_base=0.9, crest_h=0.55, crest_len=1.5, group="Helmet", bevseg=2):
    """An open-face knight's cap: dome above the brow, ear/cheek guards, a nose bar, a neck guard and an optional crest ridge."""
    y0 = hd.at(cap_base)
    rx, rz = hd.w1 / 2 + 0.1, hd.d1 / 2 + 0.1
    cap = lathe([(0.0001, 0.0), (1.0, 0.0), (1.04, 0.18), (0.94, 0.5), (0.62, 0.78), (0.0001, 0.92)], seg=12, sx=rx, sz=rz).move(0, y0 - 0.05, 0.0)
    ch.add(group, main, cap, on="Head", region="head")
    ch.add(group, trim, lathe([(1.02, 0.0), (1.08, 0.04), (1.08, 0.2), (1.0, 0.22)], seg=12, sx=rx, sz=rz).move(0, y0 - 0.08, 0.0), on="Head", region="head")
    if cheek:
        for s in (1, -1):
            gh = hd.at(0.97) - hd.at(0.12)
            ch.add(group, main, box(0.13, gh, hd.d1 * 0.82, bev=0.04, seg=1, c=(s * (hd.hw(hd.at(0.5)) + 0.09), hd.at(0.12) + gh / 2, 0.08)))
    ch.add(group, main, frustum(hd.at(0.05), hd.at(0.9), hd.w1 * 0.92, 0.14, hd.w1 * 1.0, 0.14, bev=0.04, seg=1, c=(0, 0, hd.d1 / 2 + 0.06)))  # back plate
    if nasal:
        ch.add(group, trim, box(0.12, hd.H * 0.5, 0.08, bev=0.03, seg=1, c=(0, hd.at(0.7), hd.zf(hd.at(0.7)) - 0.04)))
    if crest:
        pts = [(-0.6, y0 + 0.25), (-0.5, y0 + 0.55 + crest_h * 0.4), (-0.1, y0 + 0.85 + crest_h), (0.5, y0 + 0.8 + crest_h * 0.9), (crest_len / 2 + 0.2, y0 + 0.45), (crest_len / 2 + 0.25, y0 + 0.2), (0.2, y0 + 0.3), (-0.2, y0 + 0.3)]
        ch.add(group, crest, profile_slab(pts, 0.3, bev=0.06, seg=1), on="Head", region="head")


def helm_great(ch, hd, main, trim, dark, glow, crown=None, spikes=5, group="Helmet", eye_tilt=20):
    """A full great helm (boss): rounded dome over the whole head, a dark visor slit with two angled glowing eyes, vents, an optional
    gold crown band with points. Returns nothing; groups: Helmet (+ Crown)."""
    rx, rz = hd.w1 / 2 + 0.16, hd.d1 / 2 + 0.16
    prof = [(0.0001, hd.at(-0.12)), (0.86, hd.at(-0.12)), (0.98, hd.at(0.2)), (1.0, hd.at(0.7)), (0.96, hd.at(1.0)), (0.74, hd.at(1.3)), (0.4, hd.at(1.46)), (0.0001, hd.at(1.52))]
    ch.add(group, main, lathe(prof, seg=14, sx=rx, sz=rz), on="Head", region="head")
    zf = hd.zf(hd.at(0.62)) - rz + hd.d1 / 2  # front of the helm at eye height (approx)
    fz = -(rz * 0.99)
    ey = hd.at(0.62)
    ch.add(group, dark, box(hd.w1 * 0.98, 0.26, 0.1, c=(0, ey, fz)))
    for s in (1, -1):
        ch.add(group, glow, box(0.34, 0.085, 0.07, c=(0.3 * s, ey, fz - 0.06)).rot(0, 0, -eye_tilt * s, (0.3 * s, ey, 0)))
    for k in range(3):
        ch.add(group, dark, box(0.12, 0.05, 0.06, c=(0, hd.at(0.18) + 0.14 * k, fz)))
    ch.add(group, trim, box(0.16, hd.H * 0.9, 0.09, bev=0.03, seg=1, c=(0, hd.at(0.5), fz - 0.02)))  # nasal ridge
    ch.add(group, trim, lathe([(rx * 0.99, hd.at(0.97)), (rx * 1.06, hd.at(0.99)), (rx * 1.06, hd.at(1.08)), (rx * 0.99, hd.at(1.1))], seg=14, sx=1.0, sz=rz / rx))
    if crown:
        for k in range(spikes):
            a = math.radians(-70 + 140 * k / (spikes - 1))
            x, z = math.sin(a) * rx * 0.9, -math.cos(a) * rz * 0.9
            ch.add(group + "Crown", crown, spike((x, hd.at(1.1), z), (x * 1.08, hd.at(1.1) + 0.5 + 0.1 * (1 - abs(a)), z * 1.08), 0.09, 4), on="Head", region="head")
