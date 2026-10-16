# proof/hs2 - subdivision-surface / solidify / bevel hard-surface helpers (modifier-based modelling, the way a Blender artist builds armour).
# Differences from kit035.hs (procedural flat patches): dense smooth base shells cut by planes, real wall thickness (Solidify), real edge bevels (Bevel,
# 3 segments), tapered curve horns (Bezier + point radius), booleans for slits / vents, then baked to plain meshes with angle-based smooth shading.
import math
import bmesh
import bpy
from mathutils import Vector as V

COLL = None


def coll():
    global COLL
    if COLL is None:
        COLL = bpy.context.scene.collection
    return COLL


def obj_from_bm(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    coll().objects.link(ob)
    return ob


def superellipse_shell(rows, seg=48, p=2.6, cap_top=False, cap_bottom=False, name="shell"):
    """rows: (z, rx, zf, zb, cx, cy): half width, front depth (toward -Y), back depth (+Y), centre offsets. Returns a smooth dense shell object
    (an open tube) in Blender coordinates: x right-left, y front(-)/back(+), z up."""
    bm = bmesh.new()
    rings = []
    for z, rx, zf, zb, cx, cy in rows:
        ring = []
        for j in range(seg):
            a = 2 * math.pi * j / seg
            c, s = math.cos(a), math.sin(a)
            e = 2.0 / p
            x = rx * math.copysign(abs(c) ** e, c)
            rz = zf if s < 0 else zb
            y = rz * math.copysign(abs(s) ** e, s)
            ring.append(bm.verts.new((cx + x, cy + y, z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for j in range(seg):
            a, b = rings[i][j], rings[i][(j + 1) % seg]
            c, d = rings[i + 1][(j + 1) % seg], rings[i + 1][j]
            bm.faces.new((a, b, c, d))
    if cap_top:
        bm.faces.new(rings[-1])
    if cap_bottom:
        bm.faces.new(list(reversed(rings[0])))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return obj_from_bm(bm, name)


def keep(ob, co, no):
    """Keep the side of the plane (through co) that `no` points to; cuts open edges."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=V(co), plane_no=V(no), clear_inner=True)
    # drop loose verts/edges left by the cut
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return ob


def displace(ob, fn):
    """fn(co: Vector) -> Vector (new position)."""
    for v in ob.data.vertices:
        v.co = fn(V(v.co))
    ob.data.update()
    return ob


def add_mod(ob, kind, **kw):
    m = ob.modifiers.new(kind, kind)
    for k, v in kw.items():
        setattr(m, k, v)
    return m


def solid(ob, t, offset=-1.0):
    return add_mod(ob, "SOLIDIFY", thickness=t, offset=offset, use_even_offset=True, use_rim=True)


def bevel(ob, w, seg=3, angle=35.0):
    return add_mod(ob, "BEVEL", width=w, segments=seg, limit_method="ANGLE", angle_limit=math.radians(angle), harden_normals=False)


def subsurf(ob, lv=1):
    return add_mod(ob, "SUBSURF", levels=lv, render_levels=lv)


_ORIGIN = None


def mirror_x(ob):
    """Mirror across the WORLD x = 0 plane (an empty at the origin is the mirror object, so offset parts mirror correctly)."""
    global _ORIGIN
    if _ORIGIN is None or _ORIGIN.name not in bpy.data.objects:
        _ORIGIN = bpy.data.objects.new("origin", None)
        coll().objects.link(_ORIGIN)
    return add_mod(ob, "MIRROR", use_axis=(True, False, False), use_clip=False, use_mirror_merge=False, mirror_object=_ORIGIN)


def bake(ob, smooth_angle=38.0):
    """Apply all modifiers (evaluated mesh), then smooth shading with sharp edges above the angle."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    bpy.data.meshes.remove(old)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    lim = math.radians(smooth_angle)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if len(e.link_faces) == 2:
            n0, n1 = e.link_faces[0].normal, e.link_faces[1].normal
            e.smooth = True if (n0.length < 1e-9 or n1.length < 1e-9) else n0.angle(n1) <= lim
    bm.to_mesh(me)
    bm.free()
    return ob


def cut_box(ob, center, size, rot=(0, 0, 0)):
    """Boolean-difference a box from ob (exact solver)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = (v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])
    cutter = obj_from_bm(bm, "cutter")
    cutter.location = center
    cutter.rotation_euler = rot
    m = ob.modifiers.new("cut", "BOOLEAN")
    m.operation = "DIFFERENCE"
    m.object = cutter
    m.solver = "EXACT"
    return cutter


def tapered_curve(points, radii, bevel_depth=0.2, name="horn", resolution=6, tilt=None):
    """A smooth tapered horn: Bezier through points, bevel round with a per-point radius."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = bevel_depth
    cu.bevel_resolution = 4
    cu.resolution_u = resolution
    cu.use_fill_caps = True
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(points) - 1)
    for i, (p, r) in enumerate(zip(points, radii)):
        bp = sp.bezier_points[i]
        bp.co = p
        bp.radius = r
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    ob = bpy.data.objects.new(name, cu)
    coll().objects.link(ob)
    return ob


def curve_to_mesh(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    new = bpy.data.objects.new(ob.name + "_m", me)
    coll().objects.link(new)
    bpy.data.objects.remove(ob)
    return new


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    return o
