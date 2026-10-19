import json, math, sys
from PIL import Image, ImageDraw
polys = json.load(open('/home/ricketrice/sab_necro/base_polys.json'))
# plain parts in plot-local (same in every plot): (name, cx, cz, sx, sz, ybottom, ytop)
parts = [("WallW",-16,-1,4,50,-0.25,13.75),("WallE",16,-1,4,50,-0.25,13.75),("TowerW",-11,-24,7,4,-0.25,19.75),("TowerE",11,-24,7,4,-0.25,19.75),
         ("BackW",-10,22,8,4,-0.25,11.75),("BackE",10,22,8,4,-0.25,11.75),("PostW",-5.5,-17.7,1,1,0.1,9.1),("PostE",5.5,-17.7,1,1,0.1,9.1),("Sign",0,-17.7,12,0.4,8.5,9.7)]
def seg_d(px,pz,a,b):
    ax,az=a; bx,bz=b; dx,dz=bx-ax,bz-az; L=dx*dx+dz*dz
    t=0 if L==0 else max(0,min(1,((px-ax)*dx+(pz-az)*dz)/L))
    return math.hypot(px-ax-t*dx,pz-az-t*dz)
def inside(px,pz,poly):
    c=False
    for i in range(len(poly)):
        (x1,z1),(x2,z2)=poly[i],poly[i-1]
        if (z1>pz)!=(z2>pz) and px < (x2-x1)*(pz-z1)/(z2-z1+1e-12)+x1: c=not c
    return c
def clear(px,pz,sign=1,detail=False):
    best=(1e9,None)
    for p in polys:
        pts=[(sign*x,z) for x,z in p["xz"]]
        if len(pts)>=3 and inside(px,pz,pts): d=0
        else: d=min(seg_d(px,pz,pts[i],pts[(i+1)%len(pts)]) for i in range(len(pts)))
        if d<best[0]: best=(d,p["mesh"])
    for n,cx,cz,sx,sz,y0,y1 in parts:
        dx=max(abs(px-cx)-sx/2,0); dz=max(abs(pz-cz)-sz/2,0); d=math.hypot(dx,dz)
        if d<best[0]: best=(d,n)
    return best
if __name__=="__main__":
    spots=[(-9,15.5),(0,15.5),(9,15.5),(-9,7.75),(0,7.75),(9,7.75),(-9,0),(0,0),(9,0),(-9,-7.75),(0,-7.75),(9,-7.75),(-9,-15.5),(9,-15.5)]
    for i,(x,z) in enumerate(spots,1):
        a=clear(x,z,1); b=clear(x,z,-1)
        w=min(a,b)
        print(i,(x,z),"edge gap %.2f"%(w[0]-3.4),w[1])
    # map image
    S=12; W,H=40*S,52*S
    im=Image.new("RGB",(W,H),"white"); d=ImageDraw.Draw(im)
    tx=lambda x:(x+20)*S; tz=lambda z:(26-z)*S
    for p in polys:
        pts=[(tx(x),tz(z)) for x,z in p["xz"]]
        if len(pts)>=3: d.polygon(pts,fill=(120,120,120))
        else: d.line(pts,fill=(0,0,0))
    for n,cx,cz,sx,sz,y0,y1 in parts: d.rectangle([tx(cx-sx/2),tz(cz+sz/2),tx(cx+sx/2),tz(cz-sz/2)],outline=(200,0,0))
    for i,(x,z) in enumerate(spots,1):
        d.ellipse([tx(x-3.4),tz(z+3.4),tx(x+3.4),tz(z-3.4)],outline=(0,0,255),width=2); d.text((tx(x)-4,tz(z)-5),str(i),fill=(0,0,255))
    im.save('/home/ricketrice/sab_necro/padmap.png')
