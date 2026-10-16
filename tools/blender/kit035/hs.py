# kit035.hs - hard-surface modelling for armour that follows a body, not boxes: a parametric body PROFILE (torso / limb cross-sections,
# superellipses), armour PANELS cut out of it by angle and height with their own edge shapes (V chevrons, flared lips, raised keels),
# real THICKNESS (outer skin, inner skin, rim walls) and bevelled edges. The R15 rig stays an invisible skeleton: nothing here has to
# match its boxes, only its joints (pivots) so the weld animation still bends in the right places.
# Frame A as everywhere: +X = the character's right, +Y = up, front = -Z. Angles around a vertical axis: 0 = +X (right),
# -90 = FRONT, 90 = back, 180 = left.
import math

import bmesh
from mathutils import Vector

from . import geo
from .geo import M, V


def sgn(x):
    return 1.0 if x >= 0 else -1.0


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


class Prof:
    """Horizontal cross-sections of a body part stacked in y: rows of (y, half-width rx, front depth zf, back depth zb, centre x, centre z).
    The section is a superellipse of exponent p (2 = ellipse, 4 = rounded box)."""

    def __init__(self, rows, p=2.8, cx=0.0, cz=0.0):
        self.rows = [tuple(r) + (0.0,) * (6 - len(r)) for r in rows]
        self.p, self.cx, self.cz = p, cx, cz

    def at(self, y):
        rows = self.rows
        if y <= rows[0][0]:
            return rows[0][1:]
        if y >= rows[-1][0]:
            return rows[-1][1:]
        for a, b in zip(rows, rows[1:]):
            if a[0] <= y <= b[0]:
                t = (y - a[0]) / (b[0] - a[0])
                return tuple(lerp(a[i], b[i], t) for i in range(1, 6))

    def pt(self, y, a_deg, off=0.0):
        rx, zf, zb, cx, cz = self.at(y)
        a = math.radians(a_deg)
        c, s = math.cos(a), math.sin(a)
        e = 2.0 / self.p
        x = rx * sgn(c) * abs(c) ** e
        rz = zb if s > 0 else zf
        z = rz * sgn(s) * abs(s) ** e
        if off:  # push out along the section normal (gradient of the superellipse)
            nx = sgn(x) * abs(x / rx) ** (self.p - 1) / rx if rx else 0.0
            nz = sgn(z) * abs(z / rz) ** (self.p - 1) / rz if rz else 0.0
            n = math.hypot(nx, nz) or 1.0
            x += nx / n * off
            z += nz / n * off
        return (self.cx + cx + x, y, self.cz + cz + z)


def smooth_edges(m, off, seg=1, angle=40.0):
    """Bevel every edge sharper than `angle` degrees (turns rim walls into a lit chamfer)."""
    bm = bmesh.new()
    for p in m.v:
        bm.verts.new(p)
    bm.verts.ensure_lookup_table()
    for f in m.f:
        try:
            bm.faces.new([bm.verts[i] for i in f])
        except ValueError:
            pass
    bm.normal_update()
    lim = math.radians(angle)
    edges = [e for e in bm.edges if len(e.link_faces) == 2 and e.link_faces[0].normal.angle(e.link_faces[1].normal) > lim]
    if edges and off > 0:
        bmesh.ops.bevel(bm, geom=edges, offset=off, segments=seg, affect="EDGES", profile=0.5, clamp_overlap=True)
    out = geo._from_bm(bm)
    bm.free()
    return out


def patch(fn, nu, nv, thick=0.08, bev=0.0, bev_seg=1, bev_angle=40.0, flip=False, hollow=True, chamfer=0.0):
    """A plate from fn(u, v) -> point (u, v in 0..1; u runs with increasing angle, v runs up): the OUTER skin plus rim walls down to the inner
    boundary (`thick`, inward when the surface is a body wrap), so edges show real thickness but no hidden inner skin is spent on
    (hollow=True, about half the triangles of a closed slab). flip=True when du x dv points outward (domes). chamfer pulls the outer
    boundary ring in along the surface, which reads as a lit bevel without bevel geometry."""
    if not hollow:
        m = geo.sheet(fn, nu, nv, thick if not flip else -thick)
        return smooth_edges(m, bev, bev_seg, bev_angle) if bev > 0 else m
    G = [[V(fn(i / nu, j / nv)) for i in range(nu + 1)] for j in range(nv + 1)]
    N = [[None] * (nu + 1) for _ in range(nv + 1)]
    for j in range(nv + 1):
        for i in range(nu + 1):
            du = G[j][min(i + 1, nu)] - G[j][max(i - 1, 0)]
            dv = G[min(j + 1, nv)][i] - G[max(j - 1, 0)][i]
            n = du.cross(dv)
            N[j][i] = n.normalized() if n.length > 1e-9 else V((0, 0, -1))
    W = nu + 1
    verts = [tuple(G[j][i]) for j in range(nv + 1) for i in range(nu + 1)]
    if chamfer > 0:  # pull the boundary ring inward on the surface
        cen = sum((G[j][i] for j in range(nv + 1) for i in range(nu + 1)), V((0, 0, 0))) / ((nu + 1) * (nv + 1))
        for j in range(nv + 1):
            for i in range(nu + 1):
                if i in (0, nu) or j in (0, nv):
                    p = G[j][i]
                    d = cen - p
                    verts[j * W + i] = tuple(p + d.normalized() * min(chamfer, d.length * 0.4))
    sgn_in = 1.0 if not flip else -1.0
    bound = list(range(nu)) + [j * W + nu for j in range(nv)] + [nv * W + i for i in range(nu, 0, -1)] + [j * W for j in range(nv, 0, -1)]
    inner_start = len(verts)
    for idx in bound:
        j, i = divmod(idx, W)
        verts.append(tuple(G[j][i] + N[j][i] * thick * sgn_in))
    faces = []
    rev = not flip  # du x dv points inward for body wraps: reverse the winding so the outer skin faces out
    for j in range(nv):
        for i in range(nu):
            q = (j * W + i, j * W + i + 1, (j + 1) * W + i + 1, (j + 1) * W + i)
            faces.append(tuple(reversed(q)) if rev else q)
    nb = len(bound)
    for k in range(nb):
        k2 = (k + 1) % nb
        q = (bound[k], bound[k2], inner_start + k2, inner_start + k)
        faces.append(tuple(reversed(q)) if rev else q)
    return M(verts, faces, False)


def band(prof, a0, a1, y_lo, y_hi, off, thick=0.08, nu=8, nv=2, bev=0.0, bev_angle=40.0, hollow=True, chamfer=0.0):
    """An armour plate cut out of a Prof: angles a0..a1 (degrees), heights y_lo(a)..y_hi(a) (functions of the angle),
    surface offset off(a, v) outside the body (functions or numbers)."""
    f_lo = y_lo if callable(y_lo) else (lambda a, c=y_lo: c)
    f_hi = y_hi if callable(y_hi) else (lambda a, c=y_hi: c)
    f_off = off if callable(off) else (lambda a, v, c=off: c)

    def fn(u, v):
        a = lerp(a0, a1, u)
        y = lerp(f_lo(a), f_hi(a), v)
        return prof.pt(y, a, f_off(a, v))

    return patch(fn, nu, nv, thick, bev, 1, bev_angle, hollow=hollow, chamfer=chamfer)


def ring_loft(prof, y0, y1, n_rings, n_seg, off=0.0, a0=0.0, a1=360.0, caps=False):
    """A skin around the whole Prof between y0 and y1 (closed ring), e.g. the dark under-suit visible between plates. Outward-facing."""
    n = n_seg
    verts, faces = [], []
    for k in range(n_rings):
        y = lerp(y0, y1, k / (n_rings - 1))
        for j in range(n):
            verts.append(prof.pt(y, lerp(a0, a1, j / n), off))
    for k in range(n_rings - 1):
        for j in range(n):
            a, b = k * n + j, k * n + (j + 1) % n
            faces.append((a + n, b + n, b, a))  # u (angle) up x v (y) up points inward: reversed = outward
    if caps:
        faces.append(tuple(range(n)))
        faces.append(tuple(reversed(range((n_rings - 1) * n, n_rings * n))))
    return M(verts, faces, False)


def limb(cx, cz, rows, seg=8, p=2.4, caps=(False, False), off=0.0, a0=0.0, a1=360.0):
    """A tapered limb tube along y: rows (y, rx, rz) -> an elliptic skin."""
    rows = sorted(rows)
    pr = Prof([(y, rx, rz, rz) for y, rx, rz in rows], p=p, cx=cx, cz=cz)
    ys = [r[0] for r in rows]
    return ring_loft(pr, ys[0], ys[-1], len(rows), seg, off, a0, a1, caps)


def shell(rows, a0, a1, thick, seg=8, cx=0.0, cz=0.0, p=2.4, off=0.0, bev=0.0, bev_angle=40.0):
    """An open-sided armour shell around a limb: rows (y, rx, rz), wrapping angles a0..a1 (degrees), with thickness and bevelled rims."""
    rows = sorted(rows)
    pr = Prof([(y, rx, rz, rz) for y, rx, rz in rows], p=p, cx=cx, cz=cz)
    ys = [r[0] for r in rows]
    nv = len(rows) - 1

    def fn(u, v):
        y = lerp(ys[0], ys[-1], v)
        return pr.pt(y, lerp(a0, a1, u), off)

    # rows are few: place the v grid exactly on them
    return patch(fn, seg, nv, thick, bev, 1, bev_angle)


def stud(c, r=0.07, h=0.07, seg=4, axis_z=-1):
    """A small pyramid stud (diamond studs on pauldrons / belts) pointing along -Z (front) by default."""
    m = geo.lathe([(0.0001, 0.0), (r, 0.0), (0.0001, h)], seg=seg, closed=True)
    m.rot(-90 if axis_z < 0 else 90, 0, 0)
    return m.move(*c)


def rivets(points, r=0.045, seg=4):
    out = M()
    for p in points:
        out.add(stud(p, r, r * 0.8, seg))
    return out


def tilt_about(m, rx=0.0, ry=0.0, rz=0.0, about=(0, 0, 0)):
    return m.rot(rx, ry, rz, about)


def curve_z(m, k, hw, cx=0.0):
    """Bow a flat plate toward the front (-Z) so its centre is convex: z -= k * (1 - ((x - cx)/hw)^2). Shields, tabards, bucklers."""
    m.v = [(p[0], p[1], p[2] - k * max(0.0, 1 - ((p[0] - cx) / hw) ** 2)) for p in m.v]
    return m


def frame_slab(outer, inner, thick, bev=0.0):
    """A rim ring: the area between two outlines (same point count, counter-clockwise) extruded `thick` along Z (centred)."""
    n = len(outer)
    h = thick / 2
    verts = [(x, y, -h) for x, y in outer] + [(x, y, h) for x, y in outer] + [(x, y, -h) for x, y in inner] + [(x, y, h) for x, y in inner]
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, 2 * n + j, 2 * n + i))  # front ring (-Z)
        faces.append((n + i, 3 * n + i, 3 * n + j, n + j))  # back ring
        faces.append((i, n + i, n + j, j))  # outer wall
        faces.append((2 * n + i, 2 * n + j, 3 * n + j, 3 * n + i))  # inner wall
    m = M(verts, faces, True)
    geo._recalc(m)
    return smooth_edges(m, bev, 1, 35) if bev > 0 else m


def simplify(m, angle=3.0):
    """Dissolve coplanar splits (bevel / grid leftovers) into bigger faces: fewer triangles, same look."""
    bm = bmesh.new()
    for p in m.v:
        bm.verts.new(p)
    bm.verts.ensure_lookup_table()
    for f in m.f:
        try:
            bm.faces.new([bm.verts[i] for i in f])
        except ValueError:
            pass
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(angle), verts=list(bm.verts), edges=list(bm.edges), use_dissolve_boundaries=False)
    out = geo._from_bm(bm)
    out.closed = m.closed
    bm.free()
    return out


def cap_lame(R, ry, rz, t0, t1, az0, az1, thick, nu, nv, flare=0.0, bev=0.02):
    """A band of a dome (polar angle t0..t1 from the top, azimuth az0..az1; 0 = outward +X, -90 = front) with thickness; local origin = dome centre."""
    def fn(u, v):
        th = math.radians(lerp(t0, t1, v))
        az = math.radians(lerp(az0, az1, u))
        k = 1.0 + flare * smooth(0.6, 1.0, v)
        return (R * k * math.sin(th) * math.cos(az), ry * math.cos(th), rz * k * math.sin(th) * math.sin(az))

    return patch(fn, nu, nv, thick, bev, 1, 40.0, flip=True)
