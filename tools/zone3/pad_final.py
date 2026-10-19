import sys; sys.path.insert(0,'/home/ricketrice/sab_necro/tools')
import pad_map
from pad_map import clear
from PIL import Image, ImageDraw
R=3.1
X=8.9; rows=[15.2,8.3,1.35,-5.6]
spots=[]
for z in rows: spots += [(-X,z),(0,z),(X,z)]
spots += [(-X,-12.6),(X,-12.6)]
worst=99
for i,(x,z) in enumerate(spots,1):
    a=clear(x,z,1); b=clear(x,z,-1); w=a if a[0]<b[0] else b
    worst=min(worst,w[0]-R); print(i,(x,z),"gap %.2f"%(w[0]-R),w[1])
mind=min(((spots[i][0]-spots[j][0])**2+(spots[i][1]-spots[j][1])**2)**0.5 for i in range(14) for j in range(i+1,14))
print("worst gap %.2f, min pad-to-pad edge gap %.2f"%(worst, mind-2*R))
S=12; W,H=40*S,52*S
im=Image.new("RGB",(W,H),"white"); d=ImageDraw.Draw(im)
tx=lambda x:(x+20)*S; tz=lambda z:(26-z)*S
for p in pad_map.polys:
    pts=[(tx(x),tz(z)) for x,z in p["xz"]]
    if len(pts)>=3: d.polygon(pts,fill=(120,120,120))
    else: d.line(pts,fill=(0,0,0))
for n,cx,cz,sx,sz,y0,y1 in pad_map.parts: d.rectangle([tx(cx-sx/2),tz(cz+sz/2),tx(cx+sx/2),tz(cz-sz/2)],outline=(200,0,0))
for i,(x,z) in enumerate(spots,1):
    d.ellipse([tx(x-R),tz(z+R),tx(x+R),tz(z-R)],outline=(0,0,255),width=2); d.text((tx(x)-4,tz(z)-5),str(i),fill=(0,0,255))
im.save('/home/ricketrice/sab_necro/padmap_new.png')
