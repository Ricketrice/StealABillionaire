# Rig-feasibility proof: split the optimised AI knight (one mesh) into R15-style rigid parts by region, cap the cuts, pose it, render. Source untouched; writes ~/Pictures/035_preview/gw/seg/.
import bpy, bmesh, os, math
from mathutils import Vector, Matrix
src = os.path.expanduser("~/Pictures/035_preview/gw/opt8k_b/knight_lo.blend")
out = os.path.expanduser("~/Pictures/035_preview/gw/seg"); os.makedirs(out, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=src)
o = next(o for o in bpy.data.objects if o.type == "MESH")
sc = bpy.context.scene
def part_of(c):
    x, y, z = c.x, c.y, c.z + 0.5  # z' = 0..1 (crest tip = 1)
    ax = abs(x); s = "R" if x > 0 else "L"
    if z > 0.775 and ax < 0.2: return "Head"
    if z >= 0.50 and ax < 0.145: return "UpperTorso"
    if z >= 0.50 and ax >= 0.145: return s + "UpperArm"
    if z >= 0.33 and ax >= 0.145 and not (z < 0.5 and ax < 0.145):
        return s + ("UpperArm" if z >= 0.47 else "LowerArm")
    if z >= 0.25 and ax < 0.19: return "LowerTorso"
    if z >= 0.25: return s + "Hand"
    if z >= 0.13: return s + "UpperLeg"
    if z >= 0.06: return s + "LowerLeg"
    return s + "Foot"
mw = o.matrix_world
bm = bmesh.new(); bm.from_mesh(o.data)
groups = {}
for f in bm.faces: groups.setdefault(part_of(mw @ f.calc_center_median()), []).append(f.index)
print("PARTS", {k: len(v) for k, v in sorted(groups.items())})
bm.free()
parts = {}
mat = o.material_slots[0].material
for name, idx in groups.items():
    b = bmesh.new(); b.from_mesh(o.data); b.faces.ensure_lookup_table()
    keep = set(idx); bmesh.ops.delete(b, geom=[f for f in b.faces if f.index not in keep], context="FACES")
    # delete loose verts
    bmesh.ops.delete(b, geom=[v for v in b.verts if not v.link_faces], context="VERTS")
    open_edges = sum(1 for e in b.edges if e.is_boundary)
    # cap boundary loops (simple n-gon fill, then triangulate)
    bnd = [e for e in b.edges if e.is_boundary]
    res = bmesh.ops.holes_fill(b, edges=bnd, sides=64)
    bmesh.ops.triangulate(b, faces=[f for f in b.faces if len(f.verts) > 3])
    me = bpy.data.meshes.new(name); b.to_mesh(me)
    ob = bpy.data.objects.new(name, me); sc.collection.objects.link(ob); me.materials.append(mat)
    parts[name] = ob
    print(f"PART {name}: tris {len(me.polygons)} boundary edges before cap {open_edges}")
    b.free()
bpy.data.objects.remove(o, do_unlink=True)
# pose: pivots in world (blender z = z' - 0.5)
def pivot(x, z): return Vector((x, 0.0, z - 0.5))
def rot(names, piv, axis, deg):
    M = Matrix.Translation(piv) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-piv)
    for n in names:
        if n in parts: parts[n].matrix_world = M @ parts[n].matrix_world
# right arm chain swings forward 65deg about shoulder, elbow bends 55deg more; left arm raised sideways 40deg; left leg steps forward; head turns
rot(["RLowerArm", "RHand"], pivot(0.25, 0.47), "X", float(os.environ.get("GW_ELBOW", "55")))
rot(["RUpperArm", "RLowerArm", "RHand"], pivot(0.24, 0.66), "X", float(os.environ.get("GW_SH", "65")))
rot(["LUpperArm", "LLowerArm", "LHand"], pivot(-0.24, 0.66), "Y", float(os.environ.get("GW_ABD", "40")))
rot(["LUpperLeg", "LLowerLeg", "LFoot"], pivot(-0.12, 0.24), "X", -35)
rot(["LLowerLeg", "LFoot"], pivot(-0.12, 0.13), "X", 30)
rot(["Head"], pivot(0, 0.76), "Z", 25)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "knight_seg_posed.blend"))
