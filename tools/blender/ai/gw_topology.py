# Weld the raw AI mesh by distance and report true topology (shells, manifoldness, per-region shell tri counts). Writes ~/Pictures/035_preview/gw/gw_welded.blend
import bpy, bmesh, os
import numpy as np
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.expanduser("~/Pictures/035_preview/concept/GatehouseWarden_AI.glb"))
o = next(o for o in bpy.data.objects if o.type == "MESH")
for thr in (0.00002, 0.0001, 0.0003):
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=thr)
    nm = sum(1 for e in bm.edges if not e.is_manifold)
    bnd = sum(1 for e in bm.edges if e.is_boundary)
    nonman = sum(1 for e in bm.edges if len(e.link_faces) > 2)
    seen = set(); shells = []
    for v in bm.verts:
        if v.index in seen: continue
        st = [v]; seen.add(v.index); vs = []
        while st:
            a = st.pop(); vs.append(a)
            for e in a.link_edges:
                b = e.other_vert(a)
                if b.index not in seen: seen.add(b.index); st.append(b)
        shells.append(vs)
    sz = sorted((len({f.index for v in vs for f in v.link_faces}) for vs in shells), reverse=True)
    print(f"WELD {thr}: verts {len(bm.verts)} tris {len(bm.faces)} boundary edges {bnd} >2-face edges {nonman} shells {len(shells)} top {sz[:12]} tiny(<50) {sum(1 for s in sz if s<50)}")
    if thr == 0.0001:
        # shell bbox listing for top shells
        info = []
        for vs in shells:
            if len(vs) < 400: continue
            c = np.array([tuple(v.co) for v in vs])
            info.append((len(vs), c.min(0).round(3), c.max(0).round(3)))
        info.sort(key=lambda t: -t[0])
        for i in info[:20]: print("  shell verts", i[0], "min", i[1], "max", i[2])
        me = bpy.data.meshes.new("welded"); bm.to_mesh(me)
        w = bpy.data.objects.new("welded", me); bpy.context.scene.collection.objects.link(w)
    bm.free()
