# Assembles the Aquaris v4 concept tiles into one sheet: row 1 = FX OFF (front, side, 3/4, hero, silhouette), row 2 = FX ON.
import os
from PIL import Image, ImageDraw
OUT = os.path.expanduser("~/Pictures/035_preview/concept_v4")
rows = (("FX OFF  (model only)", "off", ("front", "side", "three-quarter", "hero", "silhouette")), ("FX ON  (water aura)", "on", ("front", "side", "three-quarter", "hero", "wide")))
W = 620
sheet = Image.new("RGB", (W * 5, (W + 40) * 2 + 40), (240, 243, 248))
d = ImageDraw.Draw(sheet)
d.text((16, 12), "Aquaris concept v4 (boss direction, original)", fill=(20, 40, 90))
for r, (label, pre, names) in enumerate(rows):
    y0 = 40 + r * (W + 40)
    d.text((16, y0 + 4), label, fill=(20, 40, 90))
    for i, n in enumerate(names):
        sheet.paste(Image.open(os.path.join(OUT, "tiles", "%s_%s.png" % (pre, n))).convert("RGB"), (W * i, y0 + 40))
        d.text((W * i + 14, y0 + 44), n, fill=(255, 255, 255) if pre == "on" else (20, 40, 90))
sheet.save(os.path.join(OUT, "aquaris_concept_v4_sheet.png"))
print("SHEET_DONE")
