import json, itertools
from PIL import Image, ImageDraw
B = json.load(open('/home/ricketrice/sab_necro/boxes.json'))
OVER = 2.0   # m: boxes starting higher than this don't block walking (s=3 -> 6 studs)
boxes = []
for b in B:
    lo, hi = b["lo"], b["hi"]
    if lo[2] > OVER: continue
    d = [hi[i]-lo[i] for i in range(3)]
    if max(d[0], d[1]) < 0.12 or d[2] < 0.05: continue
    g = b["mesh"].split("_")[0]
    if g == "Ground" and (d[0] > 3 and d[1] > 3): continue  # L-shaped corner walls: covered by the perimeter guards
    if g == "Ground" and (lo[0] < -24.3 or hi[0] > 24.3 or lo[1] < -18.8 or hi[1] > 18.9) and d[2] > 0.8: continue  # wall line: guards
    boxes.append({"g": "B" if g in ("Houses", "Spire") else g, "lo": lo[:], "hi": hi[:]})
def ov(a, b, t=0.05):
    return all(a["lo"][i] <= b["hi"][i]+t and b["lo"][i] <= a["hi"][i]+t for i in (0,1))
def area(lo, hi): return max(hi[0]-lo[0],0.01)*max(hi[1]-lo[1],0.01)
changed = True
while changed:
    changed = False
    for i in range(len(boxes)):
        for j in range(i+1, len(boxes)):
            a, b = boxes[i], boxes[j]
            if a["g"] != b["g"] or not ov(a, b): continue
            lo = [min(a["lo"][k], b["lo"][k]) for k in range(3)]; hi = [max(a["hi"][k], b["hi"][k]) for k in range(3)]
            olo=[max(a["lo"][k],b["lo"][k]) for k in (0,1)]; ohi=[min(a["hi"][k],b["hi"][k]) for k in (0,1)]
            oa=max(ohi[0]-olo[0],0)*max(ohi[1]-olo[1],0)
            if a["g"] == "B":
                ok = oa >= 0.6*min(area(a["lo"],a["hi"]),area(b["lo"],b["hi"]))
            else:
                ok = area(lo, hi) <= 1.15*(area(a["lo"],a["hi"])+area(b["lo"],b["hi"])) or \
               (area(a["lo"],a["hi"]) >= 0.97*area(lo,hi)) or (area(b["lo"],b["hi"]) >= 0.97*area(lo,hi))
            if ok:
                a["lo"], a["hi"] = lo, hi; boxes.pop(j); changed = True; break
        if changed: break
print("merged boxes", len(boxes))
json.dump(boxes, open('/home/ricketrice/sab_necro/boxes_merged.json','w'))
S=20; W,H=int(56*S),int(44*S)
im=Image.new("RGB",(W,H),"white"); d=ImageDraw.Draw(im)
tx=lambda x:(x+28)*S; ty=lambda y:(22-y)*S
col={"B":(90,60,160),"Ground":(80,80,80),"Gate":(200,0,0),"Plaza":(0,140,0),"Ruins":(0,0,200),"Props":(200,120,0)}
for b in boxes:
    d.rectangle([tx(b["lo"][0]),ty(b["hi"][1]),tx(b["hi"][0]),ty(b["lo"][1])],outline=col[b["g"]],width=2)
for x in range(-25,26,5): d.text((tx(x),ty(21)),str(x),fill=(0,0,0))
for y in range(-20,21,5): d.text((tx(-27.5),ty(y)),str(y),fill=(0,0,0))
im.save('/home/ricketrice/sab_necro/boxes_top.png')
