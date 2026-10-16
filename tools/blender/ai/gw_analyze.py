import bpy, bmesh, os, math, json
import numpy as np
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.expanduser("~/Pictures/035_preview/concept/GatehouseWarden_AI.glb"))
objs=[o for o in bpy.data.objects if o.type=='MESH']
print("MESH OBJECTS",[(o.name,len(o.data.polygons),len(o.data.vertices)) for o in objs])
o=objs[0]
me=o.data
print("dims",tuple(o.dimensions),"loc",tuple(o.location),"rot",tuple(o.rotation_euler),"scale",tuple(o.scale), "parent", o.parent.name if o.parent else None)
for m in bpy.data.materials:
    print("MAT",m.name,[ (n.type, getattr(n,'image',None) and (n.image.name,tuple(n.image.size))) for n in m.node_tree.nodes if n.type=='TEX_IMAGE'])
print("uv layers",[u.name for u in me.uv_layers],"color attrs",[a.name for a in me.color_attributes])
bm=bmesh.new(); bm.from_mesh(me)
tris=sum(len(f.verts)-2 for f in bm.faces)
print("polys",len(bm.faces),"tris",tris,"verts",len(bm.verts),"edges",len(bm.edges))
nm=[e for e in bm.edges if not e.is_manifold]
print("non-manifold edges",len(nm),"boundary",sum(1 for e in bm.edges if e.is_boundary))
# islands
seen=set();isl=[]
for v in bm.verts:
    if v.index in seen: continue
    st=[v];seen.add(v.index);c=0
    while st:
        a=st.pop();c+=1
        for e in a.link_edges:
            b=e.other_vert(a)
            if b.index not in seen: seen.add(b.index);st.append(b)
    isl.append(c)
isl.sort(reverse=True);print("islands",len(isl),isl[:15])
# profile: world co. glTF import converts Y-up to Z-up
co=np.array([tuple(o.matrix_world@v.co) for v in bm.verts])
mn,mx=co.min(0),co.max(0);print("bbox",mn,mx)
H=mx[2]-mn[2]
print("height",H,"width",mx[0]-mn[0],"depth",mx[1]-mn[1])
bins=40
print("z-slice: frac, xmin, xmax, width, ymin,ymax")
for i in range(bins):
    lo=mn[2]+H*i/bins;hi=mn[2]+H*(i+1)/bins
    s=co[(co[:,2]>=lo)&(co[:,2]<hi)]
    if len(s): print(f"{(i+0.5)/bins:.3f} {s[:,0].min():+.3f} {s[:,0].max():+.3f} w={s[:,0].max()-s[:,0].min():.3f} y {s[:,1].min():+.3f} {s[:,1].max():+.3f} n={len(s)}")
# symmetry
flip=co.copy();flip[:,0]*=-1
from collections import defaultdict
# nearest distance via grid hash
cell=0.004
g=defaultdict(list)
for i,p in enumerate(co): g[tuple((p//cell).astype(int))].append(i)
def near(p):
    k=(p//cell).astype(int);best=1e9
    for dx in(-1,0,1):
        for dy in(-1,0,1):
            for dz in(-1,0,1):
                for j in g.get((k[0]+dx,k[1]+dy,k[2]+dz),[]):
                    d=np.linalg.norm(co[j]-p);best=min(best,d)
    return best
rng=np.random.default_rng(1);idx=rng.choice(len(co),1500,replace=False)
ds=np.array([near(flip[i]) for i in idx])
print("symmetry: median dist",np.median(ds),"p90",np.percentile(ds,90),"frac<0.006",(ds<0.006).mean())
# face-size stats
areas=np.array([f.calc_area() for f in bm.faces]);print("tri area median",np.median(areas),"min",areas.min(),"max",areas.max())
# normals noise: mean edge angle
ang=[e.calc_face_angle(0) for e in bm.edges if len(e.link_faces)==2]
ang=np.degrees(np.array(ang));print("edge angle: mean",ang.mean(),"p90",np.percentile(ang,90),"frac>30deg",(ang>30).mean())
bm.free()
bpy.ops.wm.save_as_mainfile(filepath=os.path.expanduser("~/Pictures/035_preview/gw/gw_raw.blend"))
