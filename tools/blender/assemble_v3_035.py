# Assembles the Aquaris v2 concept tiles into one sheet (system Python + PIL; Blender has no PIL).
import os
from PIL import Image, ImageDraw
OUT = os.path.expanduser("~/Pictures/035_preview/concept_v3")
names = ("front", "side", "three-quarter", "hero-head", "silhouette")
sheet = Image.new("RGB", (620 * 5, 620 + 50), (240, 243, 248))
d = ImageDraw.Draw(sheet)
d.text((16, 14), "Aquaris concept v3 (elegant, hand-sculpted, original)", fill=(20, 40, 90))
for i, n in enumerate(names):
    sheet.paste(Image.open(os.path.join(OUT, "tiles", "v3_%s.png" % n)).convert("RGB"), (620 * i, 50))
    d.text((620 * i + 14, 52), n, fill=(20, 40, 90))
sheet.save(os.path.join(OUT, "aquaris_concept_v3_sheet.png"))
print("SHEET_DONE")
