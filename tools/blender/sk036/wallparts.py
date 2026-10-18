import bpy, bmesh, sys, collections
path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
for name in ("Wall_Right_Stone_Sunken", "Wall_Right_Gold_Trim", "Reef_Scatter_Coral_Pink", "Statue_SeaDragon_Dragon_Scale", "NPC_SeaDragon_Dragon_Scale"):
    o = bpy.data.objects.get(name)
    if not o: continue
    bm = bmesh.new(); bm.from_mesh(o.data); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=float(sys.argv[-1])); bm.faces.ensure_lookup_table()
    seen = set(); islands = []
    for f in bm.faces:
        if f.index in seen: continue
        stack = [f]; seen.add(f.index); fs = []
        while stack:
            g = stack.pop(); fs.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen: seen.add(h.index); stack.append(h)
        vs = {v for g in fs for v in g.verts}
        xs = [v.co.x for v in vs]; ys = [v.co.y for v in vs]; zs = [v.co.z for v in vs]
        size = max(max(xs)-min(xs), max(ys)-min(ys), max(zs)-min(zs))
        t = sum(len(g.verts) - 2 for g in fs)
        islands.append((t, round(size, 2)))
    by = collections.defaultdict(lambda: [0, 0])
    for t, sz in islands:
        k = "<0.3" if sz < 0.3 else "<0.6" if sz < 0.6 else "<1.2" if sz < 1.2 else "<3" if sz < 3 else ">=3"
        by[k][0] += 1; by[k][1] += t
    tri_sizes = collections.Counter(t for t, _ in islands).most_common(6)
    print(name, "islands", len(islands), "tris", sum(t for t, _ in islands), dict(by), "common island tri counts", tri_sizes)
    bm.free()
