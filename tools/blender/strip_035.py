# dev: python3 tools/blender/strip_035.py out.png in1.png in2.png ... [--scale 0.75]
import sys
from PIL import Image
a=sys.argv[1:]
sc=1.0
if "--scale" in a:
    i=a.index("--scale"); sc=float(a[i+1]); a=a[:i]+a[i+2:]
out,ins=a[0],a[1:]
ims=[Image.open(p).convert("RGBA") for p in ins]
w,h=ims[0].size
o=Image.new("RGBA",(w*len(ims),h),(150,160,175,255))
for i,im in enumerate(ims): o.alpha_composite(im,(i*w,0))
o=o.convert("RGB")
if sc!=1.0: o=o.resize((int(o.width*sc),int(o.height*sc)))
o.save(out)
