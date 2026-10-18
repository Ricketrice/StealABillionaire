# Headless cleanup of the owner's Sunken Kingdom map for Roblox (036, D48 part 2). Writes a new GLB; never touches the source.
#   flatpak run org.blender.Blender -b --factory-startup -P clean.py -- <in.glb> <out.glb> [maxTris] [tinyWallPiece m, default 0.25]
# 1. drops the 16 placeholder mer-folk figures (NPC_Guard/Vendor/Farmer/Performer/Citizen: skin tones, read as creatures; the game
#    spawns its own) and NPC_Markers; NPC_SeaDragon* becomes Statue_SeaDragon* (landmark on the tower).
# 2. welds duplicate vertices, deletes downward faces lying on or under the seabed top (never seen).
# 3. joins small props (< 2.5 m) per material per 24 m cell, so each cell is one MeshPart per colour.
# 4. dissolves flat splits (5 deg structure, 1 deg props), then ONE collapse pass on props (>= 35%) toward maxTris (default 60k).
# Prints objects + triangles before / after. Materials (colour-only) are kept; the GLB keeps Blender's +Y-up export.
import bpy, bmesh, sys, math, collections, mathutils

args = sys.argv[sys.argv.index("--") + 1:]
src, dst = args[0], args[1]
MAX_TRIS = int(args[2]) if len(args) > 2 else 60000
TINY = float(args[3]) if len(args) > 3 else 0.25  # wall detail pieces smaller than this (m) are dropped
FIGURES = ("NPC_Guard", "NPC_Vendor", "NPC_Farmer", "NPC_Performer", "NPC_Citizen", "NPC_Markers")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
sc = bpy.context.scene


def meshes():
    return [o for o in sc.objects if o.type == "MESH"]


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def total():
    return sum(tris(o) for o in meshes())


before = (len(meshes()), total())

# 1. figures out, dragon renamed
removed = 0
for o in list(meshes()):
    if o.name.startswith(FIGURES):
        bpy.data.objects.remove(o, do_unlink=True)
        removed += 1
for o in meshes():
    if o.name.startswith("NPC_SeaDragon"):
        o.name = o.name.replace("NPC_SeaDragon", "Statue_SeaDragon")

# bake transforms into the meshes, unparent (Roblox gets one flat set of MeshParts)
for o in meshes():
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw
bpy.ops.object.select_all(action="DESELECT")
for o in meshes():
    o.data = o.data.copy() if o.data.users > 1 else o.data
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes()[0]
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
for o in [o for o in sc.objects if o.type == "EMPTY"]:
    bpy.data.objects.remove(o, do_unlink=True)

# seabed top height (world Z)
seabed = next(o for o in meshes() if o.name.startswith("Seabed_Top"))
ground = max((seabed.matrix_world @ v.co).z for v in seabed.data.vertices)

# 2. weld + drop hidden bottoms
dropped = 0
for o in meshes():
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    mw = o.matrix_world
    nm = mw.to_3x3().inverted().transposed()
    dead = []
    for f in bm.faces:
        n = (nm @ f.normal).normalized()
        if n.z < -0.95 and (mw @ f.calc_center_median()).z <= ground + 0.05 and o is not seabed:
            dead.append(f)
    dropped += len(dead)
    bmesh.ops.delete(bm, geom=dead, context="FACES_ONLY")
    bm.to_mesh(o.data)
    bm.free()

# 2b. box contact culling + tiny wall details. The source is box-built (a side wall = ~730 boxes). A face is hidden when ALL its corners,
#     nudged 1 cm outwards, lie inside ONE other box (fully covered by a neighbour, any object): delete it. Full coverage only, so no holes.
#     On walls / trim (names starting "Wall"), loose pieces under 0.25 m are dropped (rivets on a 100 m wall).
def islands_of(bm):
    seen, out = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, fs = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            fs.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        out.append(fs)
    return out
boxes = []  # (objName, islandId, lo, hi) world AABBs of 12-tri (box) pieces
pieces = {}
for o in meshes():
    bm = bmesh.new(); bm.from_mesh(o.data); bm.faces.ensure_lookup_table()
    isl = islands_of(bm)
    pieces[o.name] = isl and len(isl)
    for i, fs in enumerate(isl):
        if sum(len(g.verts) - 2 for g in fs) == 12:
            ws = [o.matrix_world @ v.co for g in fs for v in g.verts]
            lo = mathutils.Vector((min(w.x for w in ws), min(w.y for w in ws), min(w.z for w in ws)))
            hi = mathutils.Vector((max(w.x for w in ws), max(w.y for w in ws), max(w.z for w in ws)))
            boxes.append((o.name, i, lo, hi))
    bm.free()
GRID = 4.0
grid = collections.defaultdict(list)
for b in boxes:
    for gx in range(math.floor(b[2].x / GRID), math.floor(b[3].x / GRID) + 1):
        for gy in range(math.floor(b[2].y / GRID), math.floor(b[3].y / GRID) + 1):
            grid[(gx, gy)].append(b)
def inside(p, b, eps=0.002):
    return b[2].x - eps <= p.x <= b[3].x + eps and b[2].y - eps <= p.y <= b[3].y + eps and b[2].z - eps <= p.z <= b[3].z + eps
culled, tiny = 0, 0
for o in meshes():
    bm = bmesh.new(); bm.from_mesh(o.data); bm.faces.ensure_lookup_table()
    mw = o.matrix_world
    nm = mw.to_3x3().inverted().transposed()
    dead = set()
    for i, fs in enumerate(islands_of(bm)):
        ws = [mw @ v.co for g in fs for v in g.verts]
        size = max(max(w[k] for w in ws) - min(w[k] for w in ws) for k in range(3))
        if o.name.startswith("Wall") and size < TINY:
            dead.update(fs); tiny += 1
            continue
        for f in fs:
            n = (nm @ f.normal).normalized()
            c = mw @ f.calc_center_median()
            probes = [(mw @ v.co).lerp(c, 0.01) + n * 0.01 for v in f.verts] + [c + n * 0.01]
            cands = grid.get((math.floor(c.x / GRID), math.floor(c.y / GRID)), [])
            for b in cands:
                if (b[0] != o.name or b[1] != i) and all(inside(p, b) for p in probes):
                    dead.add(f); culled += 1
                    break
    bmesh.ops.delete(bm, geom=list(dead), context="FACES")
    bm.to_mesh(o.data); bm.free()
print(f"box contact faces culled {culled}; tiny wall pieces dropped {tiny}; box pieces indexed {len(boxes)}")

# 3. join small props per material per cell
CELL = 24.0
groups = collections.defaultdict(list)
for o in meshes():
    if max(o.dimensions) < 2.5 and len(o.material_slots) == 1 and o.material_slots[0].material:
        c = o.matrix_world @ (sum((mathutils.Vector(b) for b in o.bound_box), mathutils.Vector()) / 8)
        groups[(o.material_slots[0].material.name, math.floor(c.x / CELL), math.floor(c.y / CELL))].append(o)
joined = 0
for (mat, cx, cy), objs in groups.items():
    if len(objs) < 2:
        continue
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = f"Props_{mat}_{cx}_{cy}"
    joined += len(objs) - 1

# 4a. dissolve flat splits: 1 deg on props, 5 deg on structure (walls, palace, gate, bridge, seabed, island, towers) - silhouettes stay,
#     no holes (structure is never collapsed)
STRUCT = ("Wall", "Palace", "Gate", "Bridge", "Seabed", "Island", "Tower")
def structural(o):
    return o.name.startswith(STRUCT)
for o in meshes():
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(5.0 if structural(o) else 1.0), verts=bm.verts, edges=bm.edges, delimit={"MATERIAL"})
    bm.to_mesh(o.data)
    bm.free()
after_dissolve = total()

# 4b. ONE collapse pass on non-structural meshes over 600 tris, one shared ratio (never below 35%) sized to the budget
rounds = 0
props = [o for o in meshes() if not structural(o) and tris(o) > 600]
pool = sum(tris(o) for o in props)
excess = total() - MAX_TRIS
if excess > 0 and pool > 0:
    rounds = 1
    ratio = max(0.35, 1 - excess / pool)
    for o in props:
        m = o.modifiers.new("dec", "DECIMATE")
        m.decimate_type = "COLLAPSE"
        m.ratio = ratio
        m.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=m.name)
    print(f"collapse ratio {ratio:.2f} on {len(props)} prop meshes ({pool} tris)")

after = (len(meshes()), total())
print(f"BEFORE objects {before[0]} tris {before[1]}")
print(f"removed figures/markers {removed}; hidden bottom faces dropped {dropped}; props joined {joined}; tris after flat-dissolve {after_dissolve}; collapse rounds {rounds}")
print(f"AFTER objects {after[0]} tris {after[1]}")
print("SEABED_TOP_Z", round(ground, 3))
big = sorted(((tris(o), o.name) for o in meshes()), reverse=True)[:12]
print("HEAVIEST", big)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_apply=True, export_materials="EXPORT", export_yup=True)
print("WROTE", dst)
