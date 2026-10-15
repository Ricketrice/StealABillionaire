# Assembles the Aquaris boss production tiles into one preview sheet (system Python + PIL).
import os
from PIL import Image, ImageDraw
OUT = os.path.expanduser("~/Pictures/035_preview/boss")
W = 620
rows = (
    ("FX OFF (= UI tier: model + static glow parts only)", (("off", "front"), ("off", "side"), ("off", "three-quarter"), ("sc", "icon"), ("sc", "icon_sil"))),
    ("WORLD FX (full aura, within ~80 studs)", (("w", "front"), ("w", "side"), ("w", "three-quarter"), ("w", "hero"), ("sc", "world"))),
    ("CAPTURED FX (subtle)   |   carried x1.3 and pad x1.6 next to a 5-stud noob", (("c", "front"), ("c", "side"), ("c", "three-quarter"), ("sc", "carried"), ("sc", "pad"))),
)
sheet = Image.new("RGB", (W * 5, (W + 40) * 3 + 40), (240, 243, 248))
d = ImageDraw.Draw(sheet)
d.text((16, 12), "Aquaris boss - production pass (128px icon + silhouette are shown enlarged without smoothing)", fill=(20, 40, 90))
for r, (label, tiles) in enumerate(rows):
    y0 = 40 + r * (W + 40)
    d.text((16, y0 + 4), label, fill=(20, 40, 90))
    for i, (pre, n) in enumerate(tiles):
        im = Image.open(os.path.join(OUT, "tiles", "%s_%s.png" % (pre, n))).convert("RGB")
        if im.width < W:
            im = im.resize((W, W), Image.NEAREST)
        sheet.paste(im, (W * i, y0 + 40))
        d.text((W * i + 14, y0 + 44), n, fill=(255, 255, 255) if pre == "w" else (20, 40, 90))
sheet.save(os.path.join(OUT, "aquaris_boss_sheet.png"))
print("SHEET_DONE")
