# Probe: per-mesh stats after weld, UV swatch layout, palette image content. Read-only (imports the GLB into an empty scene).
import bpy, bmesh, os, numpy as np
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.expanduser("~/Pictures/035_preview/concept/Vault.glb"))
def isfx(o):
    while o:
        if o.name.startswith("FX_"): return True
        o = o.parent
    return False
rows = []
for o in bpy.data.objects:
    if o.type != "MESH": continue
    bm = bmesh.new(); bm.from_mesh(o.data); t0 = len(bm.faces); v0 = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    nm = sum(1 for e in bm.edges if not e.is_manifold)
    uv = bm.loops.layers.uv.active
    uvs = np.array([l[uv].uv[:] for f in bm.faces for l in f.loops]) if uv else np.zeros((0, 2))
    rows.append((o.name, t0, v0, len(bm.verts), nm, o.parent.name, isfx(o), uvs, [s.material.name for s in o.material_slots]))
    bm.free()
print("name tris verts->welded nonmanifold-edges parent fx mats")
for r in sorted(rows, key=lambda r: -r[1]):
    print("%-22s %5d %6d->%5d nm=%4d %-22s fx=%s %s" % (r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[8]))
pal = [r for r in rows if "Vaultbane_Palette" in r[8]]
allu = np.concatenate([r[7] for r in pal])
print("palette meshes", len(pal), "uv u range", allu[:, 0].min(), allu[:, 0].max(), "v range", allu[:, 1].min(), allu[:, 1].max())
u = np.unique(np.round(allu, 5), axis=0); print("unique palette uvs", len(u)); print(u[:40].tolist())
for im in bpy.data.images:
    a = np.array(im.pixels[:]).reshape(im.size[1], im.size[0], 4); print(im.name, im.size, "unique colours", len(np.unique(a.reshape(-1, 4).round(3), axis=0)))
    cols = np.unique(a.reshape(-1, 4).round(2), axis=0); print(cols[:24].tolist())
# does every neon mesh use a single flat material and what are its UVs?
ne = [r for r in rows if r[0].endswith("_Neon")]; print("neon uv unique", np.unique(np.round(np.concatenate([r[7] for r in ne]), 4), axis=0)[:6].tolist())
