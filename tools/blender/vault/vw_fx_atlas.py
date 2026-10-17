# Malgrave: crop the GLB's own FX atlas (1024 px, emissive red sprites: original art) into single sprites for Roblox emitters / beams.
# Run: python3 -I tools/blender/vault/vw_fx_atlas.py (VW_CHAR=malgrave)   -> assets/export/malgrave/fx/MalgraveFx_<Name>.png
import io, os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vw_common as C
G = C.Glb()
armor_tex = G.j["materials"][[m["name"] for m in G.j["materials"]].index("FX_Atlas")]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
img = Image.open(io.BytesIO(G.image_bytes(G.j["textures"][armor_tex]["source"]))).convert("RGBA")
em = np.array(img).astype(np.float32)
OUT = os.path.join(C.EXPORT, "fx"); os.makedirs(OUT, exist_ok=True)
BOX = dict(Zigzag=(0, 0, 112, 520), Helix=(150, 0, 262, 470), Glow=(260, 380, 380, 500), Ring=(515, 0, 1024, 520), Sigil=(0, 520, 510, 1024), Arc=(515, 520, 1024, 1024))
for name, (x0, y0, x1, y1) in BOX.items():
    t = em[y0:y1, x0:x1]
    a = t[..., 3] > 4
    ys, xs = np.where(a)
    if not len(ys): print(name, "EMPTY"); continue
    t = t[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = t.shape[:2]
    if name in ("Ring", "Sigil", "Arc", "Glow", "Helix"):                 # square, centred (Zigzag stays a tall strip for Beams)
        s = max(h, w); sq = np.zeros((s, s, 4), np.float32); sq[(s - h) // 2:(s - h) // 2 + h, (s - w) // 2:(s - w) // 2 + w] = t; t = sq
    # keep colour (red/white), alpha as authored; an emitter recolours via its ColorSequence, so also store a white-RGB copy for tinting
    out = Image.fromarray(np.clip(t, 0, 255).astype(np.uint8), "RGBA")
    out.save(os.path.join(OUT, "MalgraveFx_%s.png" % name)); print(name, out.size)
