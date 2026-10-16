# kit035.geo - mesh toolkit for the 035 character kits (Blender 5.x, run inside `blender -b -P`).
# All geometry is authored in the STUDIO frame ("frame A"): +X = the character's right, +Y = up, +Z = back, front = -Z,
# 1 unit = 1 stud at spec.scale 1, origin = ground under the feet. `to_blender` turns that into Blender's frame
# (bx, by, bz) = (-x, z, y): a pure rotation (no mirror) that the FBX exporter (forward -Z, up Y) maps back onto the same
# Studio frame, so a part modelled at +X arrives at +X and "Right" means the character's right.
import math
import bmesh
import bpy
from mathutils import Vector, Matrix

V = Vector


class M:
    """A polygon mesh in frame A. `closed` meshes get their normals recalculated outward."""

    def __init__(self, verts=None, faces=None, closed=True):
        self.v = [tuple(p) for p in (verts or [])]
        self.f = [tuple(f) for f in (faces or [])]
        self.closed = closed

    def copy(self):
        return M(list(self.v), list(self.f), self.closed)

    def xf(self, mat):
        self.v = [tuple(mat @ V(p)) for p in self.v]
        return self

    def move(self, x=0.0, y=0.0, z=0.0):
        self.v = [(p[0] + x, p[1] + y, p[2] + z) for p in self.v]
        return self

    def scale(self, sx=1.0, sy=None, sz=None, about=(0, 0, 0)):
        sy = sx if sy is None else sy
        sz = sx if sz is None else sz
        a = about
        self.v = [(a[0] + (p[0] - a[0]) * sx, a[1] + (p[1] - a[1]) * sy, a[2] + (p[2] - a[2]) * sz) for p in self.v]
        if sx * sy * sz < 0:
            self.f = [tuple(reversed(f)) for f in self.f]
        return self

    def rot(self, rx=0.0, ry=0.0, rz=0.0, about=(0, 0, 0)):
        """Euler degrees, applied X then Y then Z, about a point."""
        m = Matrix.Rotation(math.radians(rz), 4, "Z") @ Matrix.Rotation(math.radians(ry), 4, "Y") @ Matrix.Rotation(math.radians(rx), 4, "X")
        a = V(about)
        self.v = [tuple(a + m @ (V(p) - a)) for p in self.v]
        return self

    def mirror_x(self):
        self.v = [(-p[0], p[1], p[2]) for p in self.v]
        self.f = [tuple(reversed(f)) for f in self.f]
        return self

    def add(self, other):
        n = len(self.v)
        self.v += other.v
        self.f += [tuple(i + n for i in f) for f in other.f]
        self.closed = self.closed and other.closed
        return self

    def tris(self):
        return sum(len(f) - 2 for f in self.f)

    def bounds(self):
        xs, ys, zs = zip(*self.v)
        return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def merge(meshes):
    out = M()
    for m in meshes:
        out.add(m)
    return out


# ------------------------------------------------------------------ bmesh helpers
def _from_bm(bm, closed=True):
    bm.verts.ensure_lookup_table()
    return M([tuple(v.co) for v in bm.verts], [tuple(v.index for v in f.verts) for f in bm.faces], closed)


def _bevel(bm, offset, seg):
    if offset > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=offset, segments=seg, affect="EDGES", profile=0.5, clamp_overlap=True)


def box(sx, sy, sz, bev=0.0, seg=2, c=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = (v.co.x * sx + c[0], v.co.y * sy + c[1], v.co.z * sz + c[2])
    _bevel(bm, min(bev, 0.49 * min(sx, sy, sz)), seg)
    m = _from_bm(bm)
    bm.free()
    return m


def frustum(y0, y1, w0, d0, w1, d1, bev=0.0, seg=2, c=(0, 0, 0), zs=(0.0, 0.0)):
    """A box whose bottom (y0) is w0 x d0 and top (y1) is w1 x d1; zs = z shift of bottom/top centres (a lean)."""
    bm = bmesh.new()
    pts = []
    for y, w, d, zz in ((y0, w0, d0, zs[0]), (y1, w1, d1, zs[1])):
        for sx_, sz_ in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            pts.append(bm.verts.new((c[0] + sx_ * w / 2, c[1] + y, c[2] + sz_ * d / 2 + zz)))
    for f in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
        bm.faces.new([pts[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    _bevel(bm, min(bev, 0.49 * min(w0, w1, d0, d1, abs(y1 - y0))), seg)
    m = _from_bm(bm)
    bm.free()
    return m


def lathe(profile, seg=10, sx=1.0, sz=1.0, c=(0, 0, 0), closed=True):
    """Revolve [(radius, y), ...] about the Y axis. radius 0 at an end closes it to a point; closed=True also caps open rims."""
    verts, faces = [], []
    rings = []
    for r, y in profile:
        if r <= 1e-6:
            verts.append((c[0], c[1] + y, c[2]))
            rings.append(("pt", len(verts) - 1))
        else:
            idx = []
            for j in range(seg):
                a = 2 * math.pi * j / seg
                verts.append((c[0] + r * sx * math.cos(a), c[1] + y, c[2] + r * sz * math.sin(a)))
                idx.append(len(verts) - 1)
            rings.append(("ring", idx))
    for i in range(len(rings) - 1):
        (ta, a), (tb, b) = rings[i], rings[i + 1]
        if ta == "ring" and tb == "ring":
            for j in range(seg):
                faces.append((a[j], a[(j + 1) % seg], b[(j + 1) % seg], b[j]))
        elif ta == "pt":
            for j in range(seg):
                faces.append((a, b[(j + 1) % seg], b[j]))
        else:
            for j in range(seg):
                faces.append((a[j], a[(j + 1) % seg], b))
    if closed:
        for (t, idx), at_start in ((rings[0], True), (rings[-1], False)):
            if t == "ring":
                faces.append(tuple(reversed(idx)) if at_start else tuple(idx))
    m = M(verts, faces, closed)
    if closed:
        _recalc(m)
    return m


def ellipsoid(r, c=(0, 0, 0), seg=10, rings=6):
    prof = []
    for i in range(rings + 1):
        a = math.pi * i / rings
        prof.append((math.sin(a) * 1.0, -math.cos(a)))
    return lathe([(p[0] * r[0], p[1] * r[1]) for p in prof], seg, 1.0, r[2] / r[0] if r[0] else 1.0, c)


def dome(r, h, c=(0, 0, 0), seg=10, rings=4, base=0.0):
    """Half-ellipsoid dome standing on y=c.y: radius r, height h; open bottom is capped."""
    prof = [(r, base)] if base else []
    for i in range(rings + 1):
        a = (math.pi / 2) * i / rings
        prof.append((r * math.cos(a), base + h * math.sin(a)))
    if not base:
        prof = [(0.0001, 0)] + prof if False else prof
    return lathe(prof, seg, 1.0, 1.0, c)


def cyl(r0, r1, h, c=(0, 0, 0), seg=10, sx=1.0, sz=1.0):
    """A (tapered) cylinder standing on y=c.y."""
    return lathe([(r0, 0.0), (r1, h)], seg, sx, sz, c)


def cyl_between(p0, p1, r0, r1=None, seg=8):
    """A tapered cylinder from p0 to p1."""
    p0, p1 = V(p0), V(p1)
    d = p1 - p0
    ln = d.length
    m = cyl(r0, r0 if r1 is None else r1, ln, (0, 0, 0), seg)
    q = V((0, 1, 0)).rotation_difference(d.normalized())
    m.xf(Matrix.Translation(p0) @ q.to_matrix().to_4x4())
    return m


def spike(base, tip, r, seg=5):
    return cyl_between(base, tip, r, 0.0001, seg)


def torus(R, r, c=(0, 0, 0), seg=14, tseg=6, axis="Y"):
    verts, faces = [], []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        for j in range(tseg):
            b = 2 * math.pi * j / tseg
            rr = R + r * math.cos(b)
            verts.append((c[0] + rr * math.cos(a), c[1] + r * math.sin(b), c[2] + rr * math.sin(a)))
    for i in range(seg):
        for j in range(tseg):
            a0, a1 = i * tseg + j, ((i + 1) % seg) * tseg + j
            b0, b1 = i * tseg + (j + 1) % tseg, ((i + 1) % seg) * tseg + (j + 1) % tseg
            faces.append((a0, a1, b1, b0))
    m = M(verts, faces, True)
    _recalc(m)
    if axis == "X":
        m.rot(0, 0, 90, c)
    elif axis == "Z":
        m.rot(90, 0, 0, c)
    return m


def loft(sections, caps=(True, True), closed_ring=True):
    """Rings of points (all the same length) joined into a tube; caps = fan-cap the first/last ring."""
    n = len(sections[0])
    verts, faces = [], []
    for s in sections:
        verts += [tuple(p) for p in s]
    for i in range(len(sections) - 1):
        for j in range(n if closed_ring else n - 1):
            a, b = i * n + j, i * n + (j + 1) % n
            faces.append((a, b, b + n, a + n))
    if caps[0]:
        faces.append(tuple(reversed(range(n))))
    if caps[1]:
        faces.append(tuple(range((len(sections) - 1) * n, len(sections) * n)))
    m = M(verts, faces, True)
    _recalc(m)
    return m


def tube(path, radii, seg=6, caps=(True, True), up=(0, 1, 0), sx=1.0, sz=1.0):
    """A tube along a polyline; radii per point (number or list). Elliptical via sx/sz in the ring's local frame."""
    pts = [V(p) for p in path]
    if not isinstance(radii, (list, tuple)):
        radii = [radii] * len(pts)
    secs = []
    prev_n = None
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        ref = V(up) if abs(t.dot(V(up))) < 0.95 else V((1, 0, 0))
        n1 = (ref - t * ref.dot(t)).normalized()
        n2 = t.cross(n1)
        ring = []
        for j in range(seg):
            a = 2 * math.pi * j / seg
            ring.append(p + n1 * (radii[i] * sx * math.cos(a)) + n2 * (radii[i] * sz * math.sin(a)))
        secs.append(ring)
    return loft(secs, caps)


def poly_slab(pts, thick, bev=0.0, seg=1, plane="XY", c=(0, 0, 0), back=True):
    """A 2-D outline [(a, b), ...] (counter-clockwise) extruded `thick` and bevelled. plane XY: outline in X,Y, thickness along Z."""
    bm = bmesh.new()
    vs = [bm.verts.new((p[0], p[1], -thick / 2)) for p in pts]
    f = bm.faces.new(vs)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    for e in ext["geom"]:
        if isinstance(e, bmesh.types.BMVert):
            e.co.z += thick
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    _bevel(bm, min(bev, thick * 0.49), seg)
    if not back:  # drop the +Z (hidden, against the surface) cap
        bm.faces.ensure_lookup_table()
        caps = [f for f in bm.faces if f.normal.z > 0.9]
        if caps:
            bmesh.ops.delete(bm, geom=[max(caps, key=lambda f: f.calc_center_median().z)], context="FACES_ONLY")
    m = _from_bm(bm)
    bm.free()
    if plane == "XZ":
        m.rot(90, 0, 0)
    elif plane == "YZ":
        m.rot(0, 90, 0)
    return m.move(*c)


def ellipse_slab(rx, ry, thick, n=8, c=(0, 0, 0), back=False, rot=0.0):
    """A flat ellipse disc (a face feature) facing -Z; `back=False` leaves out the hidden underside."""
    pts = [(rx * math.cos(2 * math.pi * i / n + math.radians(rot)), ry * math.sin(2 * math.pi * i / n + math.radians(rot))) for i in range(n)]
    return poly_slab(pts, thick, c=c, back=back)


def sheet(fn, nu, nv, thick=0.05):
    """A closed thin cloth slab: fn(u, v) -> (x, y, z) for u, v in 0..1; the back face is offset by `thick` along the surface normal."""
    grid = [[V(fn(i / nu, j / nv)) for i in range(nu + 1)] for j in range(nv + 1)]
    nrm = [[None] * (nu + 1) for _ in range(nv + 1)]
    for j in range(nv + 1):
        for i in range(nu + 1):
            du = grid[j][min(i + 1, nu)] - grid[j][max(i - 1, 0)]
            dv = grid[min(j + 1, nv)][i] - grid[max(j - 1, 0)][i]
            n = du.cross(dv)
            nrm[j][i] = n.normalized() if n.length > 1e-9 else V((0, 0, -1))
    verts, faces = [], []
    W = nu + 1
    for j in range(nv + 1):
        for i in range(nu + 1):
            verts.append(tuple(grid[j][i]))
    for j in range(nv + 1):
        for i in range(nu + 1):
            verts.append(tuple(grid[j][i] + nrm[j][i] * thick))
    off = (nu + 1) * (nv + 1)
    for j in range(nv):
        for i in range(nu):
            a, b, c_, d = j * W + i, j * W + i + 1, (j + 1) * W + i + 1, (j + 1) * W + i
            faces.append((a, b, c_, d))
            faces.append((d + off, c_ + off, b + off, a + off))
    for i in range(nu):
        faces.append((i + off, i + 1 + off, i + 1, i))
        a = nv * W + i
        faces.append((a, a + 1, a + 1 + off, a + off))
    for j in range(nv):
        a = j * W
        faces.append((a, a + W, a + W + off, a + off))
        a = j * W + nu
        faces.append((a + off, a + W + off, a + W, a))
    m = M(verts, faces, True)
    _recalc(m)
    return m


def _recalc(m):
    bm = bmesh.new()
    for p in m.v:
        bm.verts.new(p)
    bm.verts.ensure_lookup_table()
    for f in m.f:
        try:
            bm.faces.new([bm.verts[i] for i in f])
        except ValueError:
            pass
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    out = _from_bm(bm)
    bm.free()
    m.v, m.f = out.v, out.f
    return m


def to_blender(p):
    return (-p[0], p[2], p[1])


A2B = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # frame A -> Blender (rotation, det +1)


def to_object(name, m, smooth_angle=50.0, collection=None):
    """A Blender object from an M: Blender-frame coordinates, smooth faces with sharp edges above `smooth_angle`."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([to_blender(p) for p in m.v], [], [list(f) for f in m.f])
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    lim = math.radians(smooth_angle)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if len(e.link_faces) == 2:
            e.smooth = e.link_faces[0].normal.angle(e.link_faces[1].normal) <= lim
        else:
            e.smooth = True
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    (collection or bpy.context.scene.collection).objects.link(ob)
    return ob


def dent(m, center, radius, depth, toward=None):
    """Push vertices within `radius` of `center` inward (toward `toward` or the mesh centroid) by up to `depth`, smoothly."""
    c = V(center)
    cen = V(toward) if toward is not None else V(tuple(sum(p[i] for p in m.v) / len(m.v) for i in range(3)))
    out = []
    for p in m.v:
        d = (V(p) - c).length
        if d < radius:
            k = (1 - d / radius) ** 2 * depth
            q = V(p) + (cen - V(p)).normalized() * k
            out.append(tuple(q))
        else:
            out.append(p)
    m.v = out
    return m


def profile_slab(zy_pts, thick, bev=0.0, seg=1, x=0.0):
    """A side-profile outline [(z, y), ...] extruded `thick` along X (centred on x): crests, plumes, fins, blades seen from the side."""
    m = poly_slab([(-z, y) for z, y in zy_pts], thick, bev, seg)
    return m.rot(0, 90, 0).move(x, 0, 0)


def star(n, r_out, r_in, thick, c=(0, 0, 0), rot=0.0, back=True):
    pts = []
    for i in range(2 * n):
        r = r_out if i % 2 == 0 else r_in
        a = math.pi * i / n + math.radians(rot)
        pts.append((r * math.cos(a), r * math.sin(a)))
    return poly_slab(pts, thick, c=c, back=back)


def lathe_arc(profile, seg=8, a0=0.0, a1=180.0, thick=0.08, sx=1.0, sz=1.0, c=(0, 0, 0)):
    """A thin solid shell: the profile [(radius, y), ...] revolved only from angle a0 to a1 (degrees; angle 0 = +X, 90 = +Z, -90 = FRONT -Z),
    with the inner skin `thick` smaller. Hoods, cowls, open helmets: open at the front, closed along its edges."""
    n = seg + 1
    verts, faces = [], []
    for k, (r, y) in enumerate(profile):
        for j in range(n):
            a = math.radians(a0 + (a1 - a0) * j / seg)
            verts.append((c[0] + r * sx * math.cos(a), c[1] + y, c[2] + r * sz * math.sin(a)))
    m_ = len(profile)
    off = n * m_
    for k, (r, y) in enumerate(profile):
        r2 = max(r - thick, 0.0)
        for j in range(n):
            a = math.radians(a0 + (a1 - a0) * j / seg)
            verts.append((c[0] + r2 * sx * math.cos(a), c[1] + y - (thick * 0.4 if k == m_ - 1 else 0), c[2] + r2 * sz * math.sin(a)))
    for k in range(m_ - 1):
        for j in range(seg):
            a, b, c_, d = k * n + j, k * n + j + 1, (k + 1) * n + j + 1, (k + 1) * n + j
            faces.append((a, b, c_, d))
            faces.append((d + off, c_ + off, b + off, a + off))
    for k in range(m_ - 1):  # the two cut edges
        for j in (0, seg):
            a, d = k * n + j, (k + 1) * n + j
            faces.append((a, d, d + off, a + off) if j == 0 else (a + off, d + off, d, a))
    for j in range(seg):  # bottom rim and top rim
        a, b = j, j + 1
        faces.append((b, a, a + off, b + off))
        a, b = (m_ - 1) * n + j, (m_ - 1) * n + j + 1
        faces.append((a, b, b + off, a + off))
    m = M(verts, faces, True)
    _recalc(m)
    return m


def bend(m, y0, k, axis="z"):
    """Curl the part of the mesh above y0 backward (+Z): z += k * (y - y0)^2 (hood tips, tails, plumes)."""
    m.v = [(p[0], p[1], p[2] + (k * (p[1] - y0) ** 2 if p[1] > y0 else 0.0)) if axis == "z" else p for p in m.v]
    return m
